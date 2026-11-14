#!/usr/bin/env python3
"""Renders the Likho Instagram reel: 1080x1920, 30 fps, 30 s, frames as JPEG."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BUILD = os.path.join(ROOT, "media", "reel", "build")
ART = os.path.join(BUILD, "art")
SHOTS = f"{ROOT}/design/store-screenshots/screens"
FONTS = f"{ROOT}/app/tool/store_screenshots/.fonts"
OUT = os.path.join(BUILD, "frames")

W, H, FPS = 1080, 1920, 30
DUR = 30.0
N = int(DUR * FPS)

CREAM = (255, 248, 236)
GLOW = (255, 240, 204)
YELLOW = (255, 200, 61)
YELLOW_DEEP = (224, 162, 26)
BLUE = (77, 157, 224)
GREEN = (59, 178, 115)
ORANGE = (255, 138, 91)
INK = (43, 45, 66)
PINK = (252, 153, 156)
WHITE = (255, 255, 255)
CONFETTI = [YELLOW, BLUE, GREEN, ORANGE, PINK, (155, 120, 230), (90, 200, 190)]


def f(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


TITLE = lambda s: f("Baloo2_800.ttf", s)
BODY = lambda s: f("Nunito_700.ttf", s)
BODY9 = lambda s: f("Nunito_900.ttf", s)

# ---------------------------------------------------------------- easing
def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def ease_out(t):
    return 1 - (1 - clamp(t)) ** 3


def ease_in_out(t):
    t = clamp(t)
    return 3 * t * t - 2 * t * t * t


def back_out(t, s=1.70158):
    t = clamp(t) - 1
    return t * t * ((s + 1) * t + s) + 1


def seg(t, a, b):
    """progress of t inside [a,b]"""
    return clamp((t - a) / (b - a)) if b > a else 1.0


# ---------------------------------------------------------------- canvas
def radial_bg(w, h, inner, outer, cy=0.38):
    small = Image.new("RGB", (120, 213), outer)
    d = ImageDraw.Draw(small)
    cx, cyy = 60, int(213 * cy)
    rmax = 150
    for i in range(rmax, 0, -2):
        k = i / rmax
        col = tuple(int(outer[j] * k + inner[j] * (1 - k)) for j in range(3))
        d.ellipse([cx - i, cyy - i * 1.0, cx + i, cyy + i * 1.0], fill=col)
    return small.resize((w, h), Image.LANCZOS)


BG = radial_bg(W, H, GLOW, CREAM)


def new_frame():
    return BG.copy()


def paste(base, img, cx, cy, scale=1.0, alpha=1.0, rot=0.0, anchor="c"):
    if scale <= 0 or alpha <= 0:
        return
    w = max(1, int(img.width * scale))
    h = max(1, int(img.height * scale))
    im = img.resize((w, h), Image.LANCZOS)
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    if alpha < 1.0:
        a = im.split()[3].point(lambda v: int(v * alpha))
        im.putalpha(a)
    x = int(cx - im.width / 2)
    y = int(cy - im.height / 2) if anchor == "c" else int(cy - im.height)
    base.paste(im, (x, y), im)


def text(base, s, cx, y, font, fill=INK, alpha=1.0, shadow=None, anchor="mt", spacing=10, align="center"):
    if alpha <= 0:
        return
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    lines = s.split("\n")
    lh = font.getbbox("Ag")[3] - font.getbbox("Ag")[1]
    step = lh + spacing
    for k, line in enumerate(lines):
        yy = y + k * step
        if shadow:
            d.text((cx + shadow[0], yy + shadow[1]), line, font=font, fill=shadow[2], anchor=anchor)
        d.text((cx, yy), line, font=font, fill=fill, anchor=anchor)
    if alpha < 1.0:
        a = layer.split()[3].point(lambda v: int(v * alpha))
        layer.putalpha(a)
    base.paste(layer, (0, 0), layer)


def pill(base, s, cx, cy, font, bg=YELLOW, fg=INK, padx=46, pady=24, radius=99, alpha=1.0, deep=None):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bb = d.textbbox((0, 0), s, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    w, h = tw + padx * 2, th + pady * 2
    x0, y0 = cx - w / 2, cy - h / 2
    if deep:
        d.rounded_rectangle([x0, y0 + 10, x0 + w, y0 + h + 10], radius=radius, fill=deep)
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=radius, fill=bg)
    d.text((cx, cy), s, font=font, fill=fg, anchor="mm")
    if alpha < 1.0:
        a = layer.split()[3].point(lambda v: int(v * alpha))
        layer.putalpha(a)
    base.paste(layer, (0, 0), layer)


# ---------------------------------------------------------------- assets
def load_pose(name):
    return Image.open(f"{ART}/pencil_{name}.png").convert("RGBA")


POSES = {n: load_pose(n) for n in ("idle", "wave", "cheer", "run", "thumb", "wow", "sleepy")}

PHONE_W = 700
SCREEN_W = PHONE_W - 28
SCREEN_H = int(SCREEN_W * 2532 / 1170)


def load_shot(name, zoom=1.16):
    im = Image.open(f"{SHOTS}/{name}.png").convert("RGB")
    w = int(SCREEN_W * zoom)
    h = int(SCREEN_H * zoom)
    return im.resize((w, h), Image.LANCZOS)


SHOT_CACHE = {}


def shot(name):
    if name not in SHOT_CACHE:
        SHOT_CACHE[name] = load_shot(name)
    return SHOT_CACHE[name]


def phone(screen_img, zoom=1.0, pan=0.0):
    """Phone mock-up with screen_img inside; zoom>=1 crops in, pan 0..1 scrolls."""
    big = screen_img
    cw = int(SCREEN_W * 1.16 / zoom)
    ch = int(SCREEN_H * 1.16 / zoom)
    cw = min(cw, big.width)
    ch = min(ch, big.height)
    x = (big.width - cw) // 2
    y = int((big.height - ch) * clamp(pan))
    crop = big.crop((x, y, x + cw, y + ch)).resize((SCREEN_W, SCREEN_H), Image.LANCZOS)

    ph = Image.new("RGBA", (PHONE_W + 40, SCREEN_H + 68), (0, 0, 0, 0))
    d = ImageDraw.Draw(ph)
    d.rounded_rectangle([20, 32, 20 + PHONE_W, 32 + SCREEN_H + 28], radius=64, fill=(28, 30, 48, 255))
    mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SCREEN_W, SCREEN_H], radius=50, fill=255)
    ph.paste(crop, (34, 46), mask)
    d.rounded_rectangle([20, 32, 20 + PHONE_W, 32 + SCREEN_H + 28], radius=64, outline=(28, 30, 48, 255), width=6)
    d.rounded_rectangle([PHONE_W / 2 - 60, 56, PHONE_W / 2 + 80, 86], radius=16, fill=(28, 30, 48, 255))
    return ph


# ---------------------------------------------------------------- confetti
random.seed(7)
PIECES = []
for i in range(90):
    PIECES.append({
        "x": random.uniform(-0.1, 1.1), "vx": random.uniform(-0.09, 0.09),
        "y0": random.uniform(-0.25, 0.05), "vy": random.uniform(0.22, 0.52),
        "w": random.randint(14, 30), "h": random.randint(20, 40),
        "rot": random.uniform(0, 360), "spin": random.uniform(-220, 220),
        "c": random.choice(CONFETTI), "delay": random.uniform(0, 0.5),
    })


def confetti(base, t, fade=1.0, count=90, spread=1.0):
    if fade <= 0:
        return
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for p in PIECES[:count]:
        tt = t - p["delay"]
        if tt < 0:
            continue
        x = (p["x"] + p["vx"] * tt) * W
        y = (p["y0"] + p["vy"] * tt + 0.06 * tt * tt) * H * spread
        if y > H + 60:
            continue
        a = p["rot"] + p["spin"] * tt
        w2, h2 = p["w"] / 2, p["h"] / 2
        pts = []
        for dx, dy in ((-w2, -h2), (w2, -h2), (w2, h2), (-w2, h2)):
            r = math.radians(a)
            pts.append((x + dx * math.cos(r) - dy * math.sin(r),
                        y + dx * math.sin(r) + dy * math.cos(r)))
        d.polygon(pts, fill=p["c"] + (int(255 * fade),))
    base.paste(layer, (0, 0), layer)


def sparkle(base, t, cx, cy, n=10, r0=90, fade=1.0, seed=3):
    if fade <= 0:
        return
    rnd = random.Random(seed)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(n):
        ang = rnd.uniform(0, math.tau)
        rr = r0 + 260 * ease_out(clamp(t * 1.3)) + rnd.uniform(-40, 40)
        x = cx + math.cos(ang) * rr
        y = cy + math.sin(ang) * rr * 0.8
        s = 10 + 16 * (1 - clamp(t))
        a = int(255 * fade * (1 - clamp(t)))
        d.polygon([(x, y - s), (x + s * 0.32, y - s * 0.32), (x + s, y),
                   (x + s * 0.32, y + s * 0.32), (x, y + s),
                   (x - s * 0.32, y + s * 0.32), (x - s, y),
                   (x - s * 0.32, y - s * 0.32)], fill=YELLOW + (a,))
    base.paste(layer, (0, 0), layer)


# ---------------------------------------------------------------- scene 1
def paper_card(w, h):
    card = Image.new("RGBA", (w, h), WHITE + (255,))
    d = ImageDraw.Draw(card)
    for i in range(1, 5):
        y = h * i / 5
        d.line([(50, y), (w - 50, y)], fill=(206, 224, 244, 255), width=4)
    d.line([(50, h * 2 / 5), (w - 50, h * 2 / 5)], fill=(150, 190, 235, 255), width=5)
    return card


def wobbly_A(d, cx, cy, scale, prog, seed=11, colour=(60, 62, 86)):
    """Three shaky strokes of a capital A, revealed by prog 0..1."""
    rnd = random.Random(seed)
    strokes = [
        [(-1.0, 1.0), (0.0, -1.0)],
        [(0.0, -1.0), (1.0, 1.0)],
        [(-0.52, 0.08), (0.52, 0.08)],
    ]
    lens = [math.dist(s[0], s[1]) for s in strokes]
    total = sum(lens)
    done = prog * total
    for k, s in enumerate(strokes):
        if done <= 0:
            break
        part = clamp(done / lens[k])
        (x0, y0), (x1, y1) = s
        pts = []
        steps = 26
        for i in range(steps + 1):
            u = (i / steps) * part
            px = x0 + (x1 - x0) * u + rnd.uniform(-0.035, 0.035)
            py = y0 + (y1 - y0) * u + rnd.uniform(-0.035, 0.035)
            pts.append((cx + px * scale, cy + py * scale))
        if len(pts) > 1:
            d.line(pts, fill=colour, width=max(6, int(scale * 0.075)), joint="curve")
        done -= lens[k]


def scene_hook(fr, t):
    """0.0 - 2.9  the problem"""
    card_w, card_h = 820, 780
    card = paper_card(card_w, card_h)
    d = ImageDraw.Draw(card)
    wobbly_A(d, card_w / 2, card_h / 2 - 10, 240, seg(t, 0.15, 1.5))
    if t > 1.45:
        a = clamp((t - 1.45) * 3)
        layer = Image.new("RGBA", card.size, (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.line([(card_w / 2 - 220, card_h / 2 + 205), (card_w / 2 + 220, card_h / 2 + 205)],
                fill=ORANGE + (int(220 * a),), width=10)
        card.paste(layer, (0, 0), layer)
    shake = math.sin(t * 26) * (3 if 0.2 < t < 1.5 else 0)
    y = 620 + (1 - ease_out(seg(t, 0.0, 0.7))) * 120
    paste(fr, card, W / 2 + shake, y, scale=0.94, alpha=ease_out(seg(t, 0.0, 0.5)))

    paste(fr, POSES["sleepy"], 880, 1245, scale=0.88,
          alpha=ease_out(seg(t, 0.85, 1.4)), anchor="b")

    a = ease_out(seg(t, 1.35, 1.95))
    dy = (1 - a) * 40
    text(fr, "WRITING PRACTICE", W / 2, 1300 + dy, TITLE(92), INK, a)
    text(fr, "SHOULDN'T BE A FIGHT", W / 2, 1410 + dy, TITLE(92), ORANGE, a)
    text(fr, "Ages 5 to 8", W / 2, 1565 + dy, BODY(44), (120, 118, 130), a * 0.9)


# ---------------------------------------------------------------- scene 2
def scene_pencil(fr, t):
    """2.9 - 6.6  meet Pencil"""
    u = t - 2.9
    rise = back_out(seg(u, 0.0, 0.75))
    bob = math.sin(u * 3.4) * 14
    paste(fr, POSES["wave"], W / 2, 1150 + (1 - rise) * 520 + bob, scale=1.72 * (0.9 + 0.1 * rise))
    if u < 1.6:
        sparkle(fr, u / 1.6, W / 2, 900, n=14, r0=190, fade=1 - clamp(u / 1.6))
    confetti(fr, max(0.0, u - 0.3), fade=clamp(1.9 - u) * 0.9, count=55)

    a = ease_out(seg(u, 0.45, 1.0))
    text(fr, "Meet Pencil", W / 2, 300 + (1 - a) * 40, TITLE(140), INK, a)
    text(fr, "Your child's writing buddy", W / 2, 470 + (1 - a) * 40, BODY(50), (110, 108, 122), a)
    a2 = ease_out(seg(u, 1.5, 2.1))
    text(fr, "He reads every instruction out loud,\nso kids who can't read yet play on their own.",
         W / 2, 1530 + (1 - a2) * 30, BODY(42), (104, 102, 118), a2, spacing=16)


# ---------------------------------------------------------------- scene 3
def scene_trace(fr, t):
    """6.6 - 12.6  tracing"""
    u = t - 6.6
    a_in = ease_out(seg(u, 0.0, 0.55))
    if u < 3.0:
        sc, sub = shot("trace-A"), "Start at the blue dot, follow the arrows"
    else:
        sc, sub = shot("trace-l"), "Join the dots, then write it all alone"
    zoom = 1.0 + 0.10 * ease_in_out(seg(u % 3.0, 0.0, 3.0))
    ph = phone(sc, zoom=zoom, pan=0.5)
    fade = 1.0
    if 2.85 < u < 3.15:
        fade = abs(u - 3.0) / 0.15
    paste(fr, ph, W / 2, 1120 + (1 - a_in) * 240, scale=0.80, alpha=a_in * fade)

    a = ease_out(seg(u, 0.3, 0.9))
    text(fr, "Trace. Join. Write.", W / 2, 215 + (1 - a) * 36, TITLE(112), INK, a)
    sa = ease_out(seg(u, 0.6, 1.2)) * (1 if u < 2.85 or u > 3.15 else 0.2)
    text(fr, sub, W / 2, 365, BODY(44), (110, 108, 122), sa)

    if u > 4.0:
        b = ease_out(seg(u, 4.0, 4.6))
        pill(fr, "Likho checks every stroke", W / 2, 1810, BODY9(40), bg=WHITE, fg=INK, alpha=b)


# ---------------------------------------------------------------- scene 4
def scene_worlds(fr, t):
    """12.6 - 17.6  the map"""
    u = t - 12.6
    a_in = ease_out(seg(u, 0.0, 0.5))
    pan = 0.78 - 0.68 * ease_in_out(seg(u, 0.2, 4.4))
    ph = phone(shot("map"), zoom=1.02, pan=pan)
    paste(fr, ph, 330, 1140, scale=0.72, alpha=a_in)

    a = ease_out(seg(u, 0.25, 0.85))
    text(fr, "14 worlds", W / 2, 205 + (1 - a) * 34, TITLE(112), INK, a)
    text(fr, "210 levels", W / 2, 330 + (1 - a) * 34, TITLE(112), YELLOW_DEEP, a)

    worlds = ["Letter Land", "Alphabet Jungle", "Small Letter Beach", "Letter Forest",
              "Phonics Island", "Word Garden", "Sound Castle", "Blend Mountain",
              "Sight Word Town", "Sentence Sky", "Action Cove", "Question River",
              "Reading Bay", "Story Space"]
    x0 = 660
    for i, w in enumerate(worlds):
        appear = 0.8 + i * 0.15
        aa = ease_out(seg(u, appear, appear + 0.5))
        if aa <= 0:
            continue
        y = 640 + i * 84 - ease_out(seg(u, 2.4, 4.6)) * 420
        if y > 1760:
            continue
        aa *= clamp((y - 520) / 110)
        if aa <= 0.02:
            continue
        col = GREEN if i < 2 else INK
        text(fr, w, x0, y, BODY9(44), col, aa * 0.96, anchor="lm")
    text(fr, "Worlds 1 & 2 are free", x0, 1790, BODY9(38), GREEN,
         ease_out(seg(u, 1.4, 2.0)), anchor="lm")

    paste(fr, POSES["run"], 250, 1870, scale=0.52, alpha=ease_out(seg(u, 1.2, 1.8)), anchor="b")


# ---------------------------------------------------------------- scene 5
def scene_rewards(fr, t):
    """17.6 - 22.2  stars, stickers, hats"""
    u = t - 17.6
    for name, start in (("complete", 0.0), ("stickers", 1.45), ("room", 2.9)):
        local = u - start
        if local < -0.2 or local > 1.75:
            continue
        a = ease_out(seg(local, 0.0, 0.28)) * (1 - ease_in_out(seg(local, 1.45, 1.72)))
        dx = (1 - ease_out(seg(local, 0.0, 0.45))) * 420
        ph = phone(shot(name), zoom=1.0 + 0.07 * seg(local, 0, 1.7), pan=0.5)
        paste(fr, ph, W / 2 + dx, 1130, scale=0.80, alpha=a)

    a = ease_out(seg(u, 0.15, 0.7))
    text(fr, "Stars, stickers, hats", W / 2, 215 + (1 - a) * 32, TITLE(104), INK, a)
    text(fr, "Rewards that keep them coming back", W / 2, 360, BODY(44), (110, 108, 122),
         ease_out(seg(u, 0.4, 0.95)))
    confetti(fr, max(0.0, u - 0.1), fade=clamp(1.5 - u * 0.8) * 0.8, count=70)


# ---------------------------------------------------------------- scene 6
def scene_parents(fr, t):
    """22.2 - 26.0  parents"""
    u = t - 22.2
    a_in = ease_out(seg(u, 0.0, 0.5))
    ph = phone(shot("dashboard"), zoom=1.0 + 0.09 * ease_in_out(seg(u, 0.2, 3.4)), pan=0.26)
    paste(fr, ph, W / 2, 1080, scale=0.80, alpha=a_in)

    a = ease_out(seg(u, 0.2, 0.8))
    text(fr, "You see every letter", W / 2, 215 + (1 - a) * 32, TITLE(100), INK, a)
    text(fr, "Strong, needs practice, not learned yet", W / 2, 352, BODY(42),
         (110, 108, 122), ease_out(seg(u, 0.45, 1.0)))
    for i, (s, c) in enumerate((("No ads", GREEN), ("Parent lock", BLUE), ("Works offline", ORANGE))):
        ca = ease_out(seg(u, 0.9 + i * 0.22, 1.4 + i * 0.22))
        pill(fr, s, 215 + i * 325, 1790, BODY9(40), bg=c, fg=WHITE, alpha=ca, padx=34, pady=20)


# ---------------------------------------------------------------- scene 7
def scene_end(fr, t):
    """26.0 - 30.0  end card"""
    u = t - 26.0
    confetti(fr, u, fade=clamp(2.4 - u * 0.7) * 0.85, count=80)
    sc = back_out(seg(u, 0.0, 0.7))
    bob = math.sin(u * 3.0) * 10
    paste(fr, POSES["cheer"], W / 2, 1065 + bob + (1 - sc) * 160, scale=1.88 * (0.85 + 0.15 * sc))
    sparkle(fr, clamp(u / 1.3), W / 2, 1000, n=16, r0=230, fade=1 - clamp(u / 1.3), seed=9)

    a = ease_out(seg(u, 0.35, 0.95))
    text(fr, "Likho", W / 2, 290 + (1 - a) * 40, TITLE(190), INK, a)
    text(fr, "Likhna seekho, khel khel mein.", W / 2, 515 + (1 - a) * 40, BODY(50), YELLOW_DEEP, a)
    b = ease_out(seg(u, 1.0, 1.6))
    pill(fr, "Get it free on Google Play", W / 2, 1580, BODY9(50), bg=YELLOW, fg=INK,
         alpha=b, deep=YELLOW_DEEP)
    text(fr, "Worlds 1 & 2 free  ·  No ads  ·  Ages 5-8", W / 2, 1700, BODY(38),
         (120, 118, 130), ease_out(seg(u, 1.4, 2.0)))


SCENES = [
    (0.0, 2.9, scene_hook),
    (2.9, 6.6, scene_pencil),
    (6.6, 12.6, scene_trace),
    (12.6, 17.6, scene_worlds),
    (17.6, 22.2, scene_rewards),
    (22.2, 26.0, scene_parents),
    (26.0, 30.01, scene_end),
]


def wipe(fr, t):
    """Yellow circle wipe at the scene-1 -> scene-2 cut."""
    c0, c1 = 2.64, 3.06
    if not (c0 <= t <= c1):
        return
    p = seg(t, c0, c1)
    r = ease_in_out(p) * 1500
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if p < 0.5:
        rr = ease_out(p * 2) * 1500
        d.ellipse([W / 2 - rr, 1180 - rr, W / 2 + rr, 1180 + rr], fill=YELLOW + (255,))
    else:
        rr = (1 - ease_in_out((p - 0.5) * 2)) * 1500
        mask = Image.new("L", (W, H), 255)
        ImageDraw.Draw(mask).ellipse([W / 2 - rr, 1180 - rr, W / 2 + rr, 1180 + rr], fill=0)
        yel = Image.new("RGBA", (W, H), YELLOW + (255,))
        yel.putalpha(mask.point(lambda v: 255 - v))
        layer = yel
    fr.paste(layer, (0, 0), layer)


def render_frame(i):
    t = i / FPS
    fr = new_frame()
    for a, b, fn in SCENES:
        if a <= t < b:
            fn(fr, t)
            break
    wipe(fr, t)
    return fr


def main():
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    if args and args[0] == "probe":
        for ts in [float(x) for x in args[1:]]:
            fr = render_frame(int(ts * FPS))
            fr.resize((W // 2, H // 2), Image.LANCZOS).save(f"{BUILD}/probe_{ts:05.2f}.png")
            print("probe", ts)
        return
    for i in range(N):
        render_frame(i).save(f"{OUT}/f{i:05d}.jpg", quality=93, subsampling=0)
        if i % 60 == 0:
            print(i, "/", N, flush=True)
    print("done", N)


main()
