#!/usr/bin/env python3
"""Records Pencil's voice for the course: every level intro and round prompt.

Reads the course in backend/content, speaks each line with the Kokoro text-to-
speech model (Apache-2.0, runs on this computer) and writes, per line:

    app/assets/voice/<id>.m4a   the recording (AAC, mono)
    app/assets/voice/<id>.lip   mouth movement: loudness, 100 bytes a second (the
                                app's LipSyncEnvelope reads it next to the .m4a)

and puts the recording's path in the content (`intro.audio`, `prompt.audio`).
Lines are `intro.say` and `prompt.say`, or the prompt's `text`. A
pronunciation is written {shown|IPA}: "Trace small {a|ˈeɪ}" says the letter,
not the article. Only lines that changed are recorded again
(tools/voice/voice.lock.json).

    python3 -m venv .venv && .venv/bin/pip install -r tools/voice/requirements.txt   # Python 3.10+
    .venv/bin/python tools/voice/generate_voice.py            # new and changed lines
    .venv/bin/python tools/voice/generate_voice.py --all      # every line
    .venv/bin/python tools/voice/generate_voice.py --print    # show the phonemes, record nothing

The model (~350 MB) is downloaded once into tools/voice/.cache. macOS: needs
afconvert (built in). onnxruntime 1.23.2 is the last with Intel Mac builds.
"""

import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import urllib.request

import numpy as np
import soundfile as sf

VOICE = "af_heart"  # Kokoro voice (af_bella, af_sky, bf_emma …); change it and run with --all
SPEED = 0.92  # a little slower than normal, for children
LANG = "en-us"
RATE = 24000  # Kokoro's sample rate
BITRATE = 40000  # AAC, mono
LIP_FPS = 100
COURSE = "english-handwriting"

MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
MODEL_FILES = ("kokoro-v1.0.onnx", "voices-v1.0.bin")

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # the repository
CONTENT = ROOT / "backend" / "content" / "courses" / COURSE
OUT = ROOT / "app" / "assets" / "voice"
LOCK = HERE / "voice.lock.json"
CACHE = HERE / ".cache"

# {shown|IPA}
PRON = re.compile(r"\{([^{}|]+)\|([^{}|]+)\}")


# ---------------------------------------------------------------- lines

def level_files():
    return sorted(CONTENT.glob("worlds/*/levels/*.json")) + [CONTENT / "placement.json"]


def lines():
    """(clip id, words, file, where in the file) for every spoken line."""
    out = []
    for f in level_files():
        d = json.loads(f.read_text(encoding="utf-8"))
        if d["intro"].get("say"):
            out.append((f"{d['id']}-intro", d["intro"]["say"], f, ("intro",)))
        for i, r in enumerate(d["rounds"]):
            words = r["prompt"].get("say") or r["prompt"]["text"]
            out.append((r["id"], words, f, ("rounds", i, "prompt")))
    return out


# ---------------------------------------------------------------- speech

class Voice:
    def __init__(self):
        import espeakng_loader
        from kokoro_onnx import EspeakConfig, Kokoro

        CACHE.mkdir(parents=True, exist_ok=True)
        for name in MODEL_FILES:
            if not (CACHE / name).exists():
                print("downloading", name)
                urllib.request.urlretrieve(MODEL_URL + name, CACHE / name)
        # espeak-ng keeps its data path in a short buffer: a long path (a
        # virtualenv deep in a project) is silently ignored, so use a copy
        # in a short temporary folder
        self._tmp = tempfile.mkdtemp(prefix="espk")
        data = pathlib.Path(self._tmp) / "d"
        shutil.copytree(espeakng_loader.get_data_path(), data)
        cfg = EspeakConfig(lib_path=espeakng_loader.get_library_path(), data_path=str(data))
        self.k = Kokoro(str(CACHE / MODEL_FILES[0]), str(CACHE / MODEL_FILES[1]), espeak_config=cfg)

    def phonemes(self, words):
        """The line as phonemes: text through espeak, {shown|IPA} as written."""
        parts, last = [], 0
        for m in PRON.finditer(words):
            parts.append(self.k.tokenizer.phonemize(words[last:m.start()], LANG) if words[last:m.start()].strip() else "")
            parts.append(m.group(2))
            last = m.end()
        tail = words[last:]
        parts.append(self.k.tokenizer.phonemize(tail, LANG) if tail.strip() else "")
        joined = " ".join(p.strip() for p in parts if p.strip())
        # no space before punctuation after an IPA part ("ˈeɪ ," -> "ˈeɪ,")
        return re.sub(r"\s+([,.!?;:…])", r"\1", re.sub(r"\s+", " ", joined)).strip()

    def speak(self, phonemes):
        samples, rate = self.k.create(phonemes, voice=VOICE, speed=SPEED, lang=LANG, is_phonemes=True)
        assert rate == RATE
        return np.asarray(samples, np.float32)

    def close(self):
        shutil.rmtree(self._tmp, ignore_errors=True)


def polish(x):
    """Same loudness for every line, no clipping, a breath of silence around."""
    x = x - x.mean()
    rms = np.sqrt(np.mean(x ** 2)) or 1
    x = x * (10 ** (-18 / 20) / rms)  # -18 dBFS RMS
    peak = np.abs(x).max()
    if peak > 0.89:  # -1 dBFS
        x = x * (0.89 / peak)
    pad = lambda s: np.zeros(int(RATE * s), np.float32)
    return np.concatenate([pad(0.05), x, pad(0.12)])


def lip(x):
    """Loudness per 1/100 s, 0..255, normalised like the app's
    LipSyncEnvelope (95th percentile = fully open)."""
    win = RATE // LIP_FPS
    n = len(x) // win
    rms = np.sqrt(np.mean(x[: n * win].reshape(n, win) ** 2, axis=1))
    ref = max(np.percentile(rms, 95), 1e-4)
    return (np.clip(rms / ref, 0, 1) * 255).round().astype(np.uint8).tobytes()


def encode(x, out):
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / "line.wav"
        sf.write(wav, x, RATE, subtype="PCM_16")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", str(BITRATE), "-q", "127", str(wav), str(out)], check=True)


# ---------------------------------------------------------------- content

def set_audio(f, where, path):
    d = json.loads(f.read_text(encoding="utf-8"))
    node = d
    for k in where:
        node = node[k]
    if node.get("audio") == path:
        return False
    if where == ("intro",):
        # keep the field order of the files: text, word, say, audio, picture
        node = {**{k: v for k, v in node.items() if k != "picture" and k != "audio"}, "audio": path, "picture": node["picture"]}
        d["intro"] = node
    else:
        node["audio"] = path
    f.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="record every line again")
    ap.add_argument("--print", action="store_true", help="print each line's phonemes, record nothing")
    args = ap.parse_args()

    voice = Voice()
    lock = json.loads(LOCK.read_text()) if LOCK.exists() else {}
    OUT.mkdir(parents=True, exist_ok=True)
    keep, recorded, linked = set(), 0, 0
    try:
        for clip, words, f, where in lines():
            ph = voice.phonemes(words)
            if args.print:
                print(f"{clip:22} {words!r}\n{'':22} {ph}")
                continue
            key = hashlib.sha1(json.dumps([VOICE, SPEED, ph]).encode()).hexdigest()[:16]
            m4a, lipf = OUT / f"{clip}.m4a", OUT / f"{clip}.lip"
            keep |= {m4a.name, lipf.name}
            if args.all or lock.get(clip) != key or not m4a.exists() or not lipf.exists():
                x = polish(voice.speak(ph))
                encode(x, m4a)
                lipf.write_bytes(lip(x))
                lock[clip] = key
                recorded += 1
                print(f"recorded {clip:22} {len(x) / RATE:4.1f} s  {words}")
            if set_audio(f, where, f"assets/voice/{clip}.m4a"):
                linked += 1
    finally:
        voice.close()
    if args.print:
        return
    for old in OUT.iterdir():  # lines that no longer exist
        if old.name not in keep and old.suffix in (".m4a", ".lip"):
            old.unlink()
            lock.pop(old.stem, None)
    LOCK.write_text(json.dumps(dict(sorted(lock.items())), indent=1) + "\n")
    print(f"{recorded} recorded, {linked} linked in the content, {len(keep) // 2} lines")


if __name__ == "__main__":
    main()
