#!/usr/bin/env python3
"""Records Pencil's voice for the course: every level intro and round prompt.

Reads the course in backend/content, speaks each line with the Kokoro text-to-
speech model (Apache-2.0, runs on this computer) and writes, per line:

    media/voice/line-<hash>.m4a   the recording (AAC, mono)
    media/voice/line-<hash>.lip   mouth movement: loudness, 100 bytes a
                                  second (the app's LipSyncEnvelope reads
                                  it next to the .m4a)

and puts the recording's path in the content (`intro.audio`, `prompt.audio`).
Pencil's lines outside the course (APP_LINES: onboarding) go into the app
itself, app/assets/voice/<id>.m4a + .lip, so they play before anything is
downloaded; app/lib/feedback/pencil_lines.dart names them.
Lines are `intro.say` and `prompt.say`, or the prompt's `text`, and the lines
said inside a game (sound buttons, the word read, a beats hint, what the dots
made). A
pronunciation is written {shown|IPA}: "Trace small {a|ˈeɪ}" says the letter,
not the article. A recording is named after what it says (voice, speed and
phonemes), so a line used in many levels is one file, renumbering levels
records nothing, and only new words are recorded. tools/voice/voice.lock.json
lists what every file says.

    python3 -m venv .venv && .venv/bin/pip install -r tools/voice/requirements.txt   # Python 3.10+
    .venv/bin/python tools/voice/generate_voice.py            # new and changed lines
    .venv/bin/python tools/voice/generate_voice.py --all      # every line
    .venv/bin/python tools/voice/generate_voice.py --print    # show the phonemes, record nothing
    .venv/bin/python tools/voice/generate_voice.py --app      # only the app's own lines

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
OUT = ROOT / "media" / "voice"  # served by the API at /media/voice/ (MEDIA_DIR); not in git
LOCK = HERE / "voice.lock.json"
APP_OUT = ROOT / "app" / "assets" / "voice"  # bundled with the app
APP_LOCK = HERE / "app_lines.lock.json"
CACHE = HERE / ".cache"

# {shown|IPA}
PRON = re.compile(r"\{([^{}|]+)\|([^{}|]+)\}")


# ---------------------------------------------------------------- lines

# Pencil's lines in the app's own screens (id -> words), kept in the app.
# Change one and run --app: only that line is recorded again.
APP_LINES = {
    # onboarding (Add child): name -> age -> colour, then placement done
    "onb_name": "Hi, I'm Pencil! What's your name? Ask a grown-up to type it.",
    "onb_age": "Nice to meet you! How old are you? Tap your birthday cake.",
    "onb_colour": "Now pick my colour! Which one do you like?",
    "lets_start": "Let's get started!",
}

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
            # lines Pencil says inside a game: each sound button, the word read,
            # the hint after a wrong count of beats, the picture the dots made
            t = r["type"]
            inner = []
            if t == "sounds":
                inner = [(("sounds", "parts", j), f"s{j + 1}") for j in range(len(r["sounds"]["parts"]))] + [(("sounds", "blend"), "word")]
            elif t == "beats" and r["beats"].get("hint"):
                inner = [(("beats", "hint"), "hint")]
            elif t == "connect" and r["connect"].get("done"):
                inner = [(("connect", "done"), "done")]
            for where, tag in inner:
                node = r
                for k in where:
                    node = node[k]
                out.append((f"{r['id']}-{tag}", node.get("say") or node["text"], f, ("rounds", i) + where))
    return out


def spoken(words):
    """The words with each {shown|IPA} as shown."""
    return PRON.sub(lambda m: m.group(1), words)


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


def app_lines(voice, args):
    """Records APP_LINES into the app (by id; the lock says what each says)."""
    lock = json.loads(APP_LOCK.read_text(encoding="utf-8")) if APP_LOCK.exists() else {}
    out, recorded = {}, 0
    APP_OUT.mkdir(parents=True, exist_ok=True)
    for key, words in APP_LINES.items():
        ph = voice.phonemes(words)
        if args.print:
            print(f"{key:22} {words!r}\n{'':22} {ph}")
            continue
        made = hashlib.sha1(json.dumps([VOICE, SPEED, ph]).encode()).hexdigest()[:16]
        m4a, lipf = APP_OUT / f"{key}.m4a", APP_OUT / f"{key}.lip"
        if args.all or lock.get(key, {}).get("made") != made or not m4a.exists() or not lipf.exists():
            x = polish(voice.speak(ph))
            encode(x, m4a)
            lipf.write_bytes(lip(x))
            recorded += 1
            print(f"recorded {key:22} {len(x) / RATE:4.1f} s  {words}")
        out[key] = {"says": spoken(words), "made": made}
    if args.print:
        return
    for old in APP_OUT.iterdir():  # lines the app no longer has
        if old.stem not in APP_LINES and old.suffix in (".m4a", ".lip"):
            old.unlink()
    APP_LOCK.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{recorded} app lines recorded, {len(out)} in the app")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="record every line again")
    ap.add_argument("--print", action="store_true", help="print each line's phonemes, record nothing")
    ap.add_argument("--app", action="store_true", help="only the app's own lines (APP_LINES)")
    args = ap.parse_args()

    voice = Voice()
    OUT.mkdir(parents=True, exist_ok=True)
    said, recorded, linked, done = {}, 0, 0, set()
    try:
        app_lines(voice, args)
        if args.app:
            return
        for where_id, words, f, where in lines():
            ph = voice.phonemes(words)
            if args.print:
                print(f"{where_id:22} {words!r}\n{'':22} {ph}")
                continue
            clip = "line-" + hashlib.sha1(json.dumps([VOICE, SPEED, ph]).encode()).hexdigest()[:16]
            m4a, lipf = OUT / f"{clip}.m4a", OUT / f"{clip}.lip"
            said.setdefault(clip, spoken(words))
            if clip not in done and (args.all or not m4a.exists() or not lipf.exists()):
                x = polish(voice.speak(ph))
                encode(x, m4a)
                lipf.write_bytes(lip(x))
                recorded += 1
                print(f"recorded {where_id:22} {len(x) / RATE:4.1f} s  {words}")
            done.add(clip)
            if set_audio(f, where, f"voice/{clip}.m4a"):
                linked += 1
    finally:
        voice.close()
    if args.print:
        return
    for old in OUT.iterdir():  # lines no level says any more
        if old.stem not in said and old.suffix in (".m4a", ".lip"):
            old.unlink()
    LOCK.write_text(json.dumps(dict(sorted(said.items())), indent=1, ensure_ascii=False) + "\n")
    print(f"{recorded} recorded, {linked} linked in the content, {len(said)} different lines")


if __name__ == "__main__":
    main()
