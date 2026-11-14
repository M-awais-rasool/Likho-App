#!/usr/bin/env python3
"""Builds the reel's soundtrack: synthesised music bed + SFX + macOS voice-over."""
import array, math, os, random, subprocess, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BUILD = os.path.join(ROOT, "media", "reel", "build")
AUD = os.path.join(BUILD, "audio")
os.makedirs(AUD, exist_ok=True)

SR = 44100
DUR = 30.0
N = int(SR * DUR)
VOICE = os.environ.get("REEL_VOICE", "Samantha")
RATE = os.environ.get("REEL_RATE", "172")

left = array.array("d", bytes(8 * N))
right = array.array("d", bytes(8 * N))


def add(buf, start, samples, gain=1.0, pan=0.0):
    i = int(start * SR)
    gl = gain * (1.0 - max(0.0, pan))
    gr = gain * (1.0 + min(0.0, pan))
    for k, v in enumerate(samples):
        j = i + k
        if 0 <= j < N:
            left[j] += v * gl
            right[j] += v * gr


# ------------------------------------------------------------------ synth
def marimba(freq, dur, amp=0.25):
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    w = 2 * math.pi * freq / SR
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 9.0) * (1 - math.exp(-t * 400))
        s = math.sin(w * i) + 0.35 * math.sin(2 * w * i) * math.exp(-t * 16) \
            + 0.12 * math.sin(4 * w * i) * math.exp(-t * 26)
        out[i] = s * env * amp
    return out


def uke(freq, dur, amp=0.16):
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    w = 2 * math.pi * freq / SR
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 4.2) * (1 - math.exp(-t * 600))
        s = 0.7 * math.sin(w * i) + 0.5 * math.sin(2 * w * i) + 0.25 * math.sin(3 * w * i) \
            + 0.12 * math.sin(5 * w * i)
        out[i] = s * env * amp
    return out


def bass(freq, dur, amp=0.3):
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    w = 2 * math.pi * freq / SR
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 5.0) * (1 - math.exp(-t * 300))
        out[i] = (math.sin(w * i) + 0.18 * math.sin(2 * w * i)) * env * amp
    return out


def kick(amp=0.5):
    n = int(0.16 * SR)
    out = array.array("d", bytes(8 * n))
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 125 * math.exp(-t * 32) + 48
        ph += 2 * math.pi * f / SR
        out[i] = math.sin(ph) * math.exp(-t * 17) * amp
    return out


def shaker(amp=0.08, dur=0.07, seed=1):
    rnd = random.Random(seed)
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    last = 0.0
    for i in range(n):
        t = i / SR
        v = rnd.uniform(-1, 1)
        last = 0.55 * last + 0.45 * v
        out[i] = (v - last) * math.exp(-t * 46) * amp
    return out


def chime(base=1046.5, amp=0.17, dur=1.0, steps=(0, 4, 7, 12)):
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    for k, st in enumerate(steps):
        f = base * (2 ** (st / 12))
        d = k * 0.055
        w = 2 * math.pi * f / SR
        for i in range(int(d * SR), n):
            t = (i - d * SR) / SR
            out[i] += math.sin(w * i) * math.exp(-t * 5.5) * amp
    return out


def whoosh(dur=0.42, amp=0.22, seed=5):
    rnd = random.Random(seed)
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    lp = 0.0
    for i in range(n):
        t = i / SR
        p = t / dur
        a = 0.03 + 0.5 * p
        lp = (1 - a) * lp + a * rnd.uniform(-1, 1)
        env = math.sin(math.pi * p) ** 1.6
        out[i] = lp * env * amp
    return out


def pop(f=760, amp=0.24, dur=0.12):
    n = int(dur * SR)
    out = array.array("d", bytes(8 * n))
    ph = 0.0
    for i in range(n):
        t = i / SR
        ff = f * (1 + 1.9 * math.exp(-t * 46))
        ph += 2 * math.pi * ff / SR
        out[i] = math.sin(ph) * math.exp(-t * 26) * amp
    return out


# ------------------------------------------------------------------ music bed
NOTE = {"C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00,
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00,
        "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99,
        "A5": 880.00, "C6": 1046.5}

BPM = 112.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
PROG = [("C", "C3", ["C4", "E4", "G4", "C5"]),
        ("G", "G3", ["G3", "B4", "D5", "G4"]),
        ("A", "A3", ["A3", "C5", "E5", "A4"]),
        ("F", "F3", ["F3", "A4", "C5", "F4"])]

print("music…", flush=True)
bar = 0
t = 0.0
while t < DUR:
    name, root, arp = PROG[bar % 4]
    # bass on 1 and 3
    add(left, t, bass(NOTE[root], 0.9, 0.26))
    add(left, t + 2 * BEAT, bass(NOTE[root], 0.9, 0.2))
    # ukulele chord strum on 1 and 2.5
    for off, g in ((0.0, 1.0), (1.5 * BEAT, 0.75), (2.5 * BEAT, 0.9), (3.5 * BEAT, 0.6)):
        for k, nn in enumerate(arp):
            add(left, t + off + k * 0.012, uke(NOTE[nn], 1.1, 0.075 * g), pan=-0.25 + 0.16 * k)
    # marimba eighth-note melody
    mel = [0, 2, 1, 3, 2, 3, 1, 2]
    for e in range(8):
        nn = arp[mel[e] % len(arp)]
        f = NOTE[nn] * 2
        add(left, t + e * BEAT / 2, marimba(f, 0.55, 0.13 if e % 2 == 0 else 0.085), pan=0.22)
    # drums
    add(left, t, kick(0.42))
    add(left, t + 2 * BEAT, kick(0.38))
    for e in range(8):
        add(left, t + e * BEAT / 2, shaker(0.055 if e % 2 else 0.085, seed=bar * 8 + e), pan=0.3)
    bar += 1
    t += BAR

# ------------------------------------------------------------------ sfx
print("sfx…", flush=True)
SFX = [
    (0.30, pop(520, 0.16)),              # pencil touches paper
    (2.66, whoosh(0.44, 0.30)),          # circle wipe
    (3.02, pop(880, 0.26)),
    (3.25, chime(1046.5, 0.14, 1.1)),    # Pencil appears
    (6.62, whoosh(0.30, 0.18, seed=9)),
    (9.60, pop(700, 0.18)),
    (12.62, whoosh(0.30, 0.18, seed=11)),
    (17.62, chime(1318.5, 0.15, 1.2, (0, 4, 7, 11))),   # stars
    (19.05, pop(820, 0.2)),
    (20.50, pop(640, 0.2)),
    (22.22, whoosh(0.28, 0.15, seed=13)),
    (26.02, chime(1046.5, 0.18, 1.6, (0, 4, 7, 12, 16))),
    (27.05, pop(900, 0.22)),
]
for at, s in SFX:
    add(left, at, s)

# ------------------------------------------------------------------ voice-over
LINES = [
    (0.35, "Every evening, the same fight."),
    (3.25, "Meet Pencil. He teaches your child to write."),
    (6.95, "Every letter, step by step. Trace it, join the dots, then write it all alone."),
    (12.95, "Fourteen worlds. Two hundred and ten levels, from capitals to full sentences."),
    (17.95, "Stars, stickers, and new hats for Pencil."),
    (22.50, "And you see which letters your child has mastered. No ads."),
    (26.45, "Likho. Download it free on Google Play."),
]

print("voice…", flush=True)
vo = array.array("d", bytes(8 * N))
duck = array.array("d", [1.0] * N)
for idx, (at, txt) in enumerate(LINES):
    wav = f"{AUD}/vo{idx}.wav"
    subprocess.run(["say", "-v", VOICE, "-r", RATE, "-o", wav,
                    "--file-format=WAVE", "--data-format=LEI16@44100", txt], check=True)
    with wave.open(wav) as w:
        frames = w.readframes(w.getnframes())
        ch = w.getnchannels()
    pcm = array.array("h")
    pcm.frombytes(frames)
    if ch == 2:
        pcm = array.array("h", pcm[0::2])
    start = int(at * SR)
    n = len(pcm)
    print(f"  line {idx}: {n / SR:5.2f}s at {at}s  -> ends {at + n / SR:5.2f}s")
    for i in range(n):
        j = start + i
        if 0 <= j < N:
            vo[j] += pcm[i] / 32768.0 * 1.0
    # duck the music while the line plays (with 0.12 s ramps)
    ramp = int(0.12 * SR)
    for i in range(-ramp, n + ramp):
        j = start + i
        if not (0 <= j < N):
            continue
        if i < 0:
            k = (i + ramp) / ramp
        elif i > n:
            k = max(0.0, 1 - (i - n) / ramp)
        else:
            k = 1.0
        duck[j] = min(duck[j], 1.0 - 0.58 * k)

# ------------------------------------------------------------------ mix
print("mix…", flush=True)
peak = 0.0
for i in range(N):
    d = duck[i]
    l = left[i] * 0.85 * d + vo[i] * 0.92
    r = right[i] * 0.85 * d + vo[i] * 0.92
    left[i] = l
    right[i] = r
    peak = max(peak, abs(l), abs(r))
print("peak", round(peak, 3))
g = 0.92 / peak if peak > 0 else 1.0
# fade in / out
fi, fo = int(0.25 * SR), int(0.6 * SR)
out = array.array("h", bytes(2 * 2 * N))
for i in range(N):
    k = g
    if i < fi:
        k *= i / fi
    if i > N - fo:
        k *= (N - i) / fo
    for c, buf in ((0, left), (1, right)):
        v = buf[i] * k
        v = math.tanh(v * 1.08)
        out[2 * i + c] = int(max(-32767, min(32767, v * 32767)))

path = f"{AUD}/reel_mix.wav"
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print("wrote", path)
subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "192000", path, f"{AUD}/reel_mix.m4a"], check=True)
print("wrote", f"{AUD}/reel_mix.m4a")
