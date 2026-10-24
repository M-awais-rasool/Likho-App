#!/usr/bin/env python3
"""Stand-in pictures for Letter Slice (app/assets/games/slice/), drawn here
until the Gemini art (prompts in design/games/letter-slice-prompts.md) is
made and cut into the same file names.

* each fruit whole (a cute face) and its cut face (the inside), 512 px
* the specials: a golden star fruit, a banana (fruit party), an ice berry
  (slow motion)
* the wooden board behind them (9:16) and the Games card's cover

    python3 tools/games/make_slice_placeholders.py      # needs pillow
"""

import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "app" / "assets" / "games" / "slice"
S = 512  # the picture's side
K = 3  # drawn this many times bigger, then made smaller (smooth edges)

# name -> skin, darker skin (outline), inside, inside's edge, seeds
FRUITS = {
    "apple": ((235, 72, 72), (150, 34, 40), (255, 244, 214), (235, 72, 72), (90, 52, 30)),
    "orange": ((255, 156, 40), (186, 96, 16), (255, 190, 80), (255, 236, 190), (255, 236, 190)),
    "watermelon": ((92, 178, 74), (40, 104, 40), (246, 82, 98), (230, 250, 210), (40, 30, 30)),
    "lemon": ((255, 222, 64), (190, 150, 20), (255, 240, 140), (255, 252, 220), (255, 252, 220)),
    "plum": ((150, 82, 196), (88, 40, 128), (255, 214, 110), (190, 120, 220), (150, 90, 40)),
    "kiwi": ((160, 116, 70), (98, 66, 34), (140, 200, 70), (220, 240, 180), (40, 40, 30)),
    "peach": ((255, 168, 140), (200, 100, 84), (255, 206, 120), (255, 160, 120), (180, 90, 50)),
}


def canvas():
    return Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))


def done(img):
    return img.resize((S, S), Image.LANCZOS)


def shade(d, box, col, edge, w):
    """A filled ellipse with a soft lighter top-left and an outline."""
    x0, y0, x1, y1 = box
    d.ellipse(box, fill=edge)
    d.ellipse((x0 + w, y0 + w, x1 - w, y1 - w), fill=col)
    # the light: a few lighter ellipses towards the top left
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2 - w, (y1 - y0) / 2 - w
    for k in range(6):
        t = (k + 1) / 7
        c = tuple(min(255, int(v + (255 - v) * .07 * (k + 1))) for v in col)
        sx, sy = rx * (1 - t * .55), ry * (1 - t * .55)
        ox, oy = cx - rx * .18 * t, cy - ry * .2 * t
        d.ellipse((ox - sx, oy - sy, ox + sx, oy + sy), fill=c)
    # one soft highlight
    d.ellipse((cx - rx * .55, cy - ry * .62, cx - rx * .2, cy - ry * .38), fill=tuple(int(v + (255 - v) * .6) for v in col))


def face(d, cx, cy, r, dark):
    """Two eyes, a smile, pink cheeks."""
    for sx in (-1, 1):
        ex, ey = cx + sx * r * .3, cy - r * .02
        d.ellipse((ex - r * .09, ey - r * .12, ex + r * .09, ey + r * .12), fill=(40, 28, 24))
        d.ellipse((ex - r * .035, ey - r * .09, ex + r * .03, ey - r * .03), fill=(255, 255, 255))
        d.ellipse((ex - r * .14 + sx * r * .06, ey + r * .14, ex + r * .14 + sx * r * .06, ey + r * .26), fill=(255, 130, 140, 150))
    d.arc((cx - r * .2, cy, cx + r * .2, cy + r * .3), 20, 160, fill=(40, 28, 24), width=int(r * .055))


def leaf(d, cx, top, r):
    d.line((cx, top + r * .05, cx + r * .06, top - r * .22), fill=(110, 70, 36), width=int(r * .08))
    d.ellipse((cx + r * .05, top - r * .3, cx + r * .42, top - r * .1), fill=(46, 120, 46))
    d.ellipse((cx + r * .09, top - r * .27, cx + r * .38, top - r * .14), fill=(96, 180, 74))


def whole(name):
    skin, dark, *_ = FRUITS[name]
    img = canvas()
    d = ImageDraw.Draw(img)
    r = S * K * .4
    c = S * K / 2
    w = int(r * .06)
    if name == "lemon":
        box = (c - r, c - r * .78, c + r, c + r * .78)
        shade(d, box, skin, dark, w)
        for sx in (-1, 1):  # the pointy ends
            d.ellipse((c + sx * r * .93 - r * .12, c - r * .1, c + sx * r * .93 + r * .12, c + r * .1), fill=dark)
        face(d, c, c, r * .9, dark)
    else:
        box = (c - r, c - r, c + r, c + r)
        shade(d, box, skin, dark, w)
        if name == "watermelon":
            for k in range(-2, 3):  # dark stripes, inside the outline
                x = c + k * r * .34
                half = math.sqrt(max(0, 1 - (k * .34) ** 2)) * r * .9
                d.arc((x - r * .2, c - half, x + r * .2, c + half), 100, 260, fill=(52, 128, 50), width=int(r * .07))
        if name == "kiwi":
            for k in range(60):  # little hairs
                a = k * 2.4
                rr = r * (.3 + .6 * ((k * 37) % 100) / 100)
                x, y = c + math.cos(a) * rr, c + math.sin(a) * rr
                d.line((x, y, x + r * .03, y + r * .03), fill=(120, 84, 48), width=int(r * .02))
        face(d, c, c + r * .05, r, dark)
        if name in ("apple", "peach", "plum", "orange"):
            leaf(d, c, c - r * .92, r)
    return done(img)


def inside(name):
    skin, dark, flesh, rim, seed = FRUITS[name]
    img = canvas()
    d = ImageDraw.Draw(img)
    r = S * K * .4
    c = S * K / 2
    w = int(r * .06)
    sy = .78 if name == "lemon" else 1
    d.ellipse((c - r, c - r * sy, c + r, c + r * sy), fill=dark)
    d.ellipse((c - r + w, c - r * sy + w, c + r - w, c + r * sy - w), fill=skin)
    rr = r - w * 2.4
    d.ellipse((c - rr, c - rr * sy, c + rr, c + rr * sy), fill=rim)
    rr2 = rr * .9
    d.ellipse((c - rr2, c - rr2 * sy, c + rr2, c + rr2 * sy), fill=flesh)
    if name in ("orange", "lemon"):  # segments
        for k in range(10):
            a = k * math.pi / 5
            d.line((c, c, c + math.cos(a) * rr2, c + math.sin(a) * rr2 * sy), fill=rim, width=int(r * .035))
        d.ellipse((c - r * .1, c - r * .1 * sy, c + r * .1, c + r * .1 * sy), fill=rim)
    elif name in ("apple", "peach", "plum"):
        d.ellipse((c - r * .28, c - r * .32, c + r * .28, c + r * .32), fill=tuple(max(0, v - 18) for v in flesh))
        for sx in (-1, 1):
            d.ellipse((c + sx * r * .1 - r * .06, c - r * .1, c + sx * r * .1 + r * .06, c + r * .08), fill=seed)
    else:  # watermelon, kiwi: a ring of seeds
        for k in range(14):
            a = k * 2 * math.pi / 14
            x, y = c + math.cos(a) * rr2 * .55, c + math.sin(a) * rr2 * .55
            d.ellipse((x - r * .035, y - r * .055, x + r * .035, y + r * .055), fill=seed)
        if name == "kiwi":
            d.ellipse((c - r * .2, c - r * .2, c + r * .2, c + r * .2), fill=rim)
    # a shine of juice
    d.ellipse((c - rr2 * .6, c - rr2 * .65 * sy, c - rr2 * .25, c - rr2 * .45 * sy), fill=tuple(int(v + (255 - v) * .5) for v in flesh))
    return done(img)


def star():
    img = canvas()
    d = ImageDraw.Draw(img)
    c, r = S * K / 2, S * K * .44
    for col, rr in (((196, 132, 16), r), ((255, 200, 50), r * .9), ((255, 226, 110), r * .6)):
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            q = rr if k % 2 == 0 else rr * .5
            pts.append((c + math.cos(a) * q, c + math.sin(a) * q * .98))
        d.polygon(pts, fill=col)
    face(d, c, c + r * .06, r * .62, (196, 132, 16))
    img = done(img)
    glow = img.filter(ImageFilter.GaussianBlur(14))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(img)
    return out


def banana():
    img = canvas()
    d = ImageDraw.Draw(img)
    c, r = S * K / 2, S * K * .42
    # a crescent: a big yellow disc minus a shifted one
    body = Image.new("L", img.size, 0)
    b = ImageDraw.Draw(body)
    b.ellipse((c - r, c - r * .9, c + r, c + r * 1.1), fill=255)
    b.ellipse((c - r * .95, c - r * 1.45, c + r * .95, c + r * .45), fill=0)
    edge = body.filter(ImageFilter.MaxFilter(int(r * .1) | 1))
    img.paste((178, 128, 20, 255), mask=edge)
    img.paste((255, 214, 60, 255), mask=body)
    d.ellipse((c - r * 1.02, c + r * .02, c - r * .84, c + r * .2), fill=(110, 70, 30))
    d.ellipse((c + r * .84, c + r * .02, c + r * 1.02, c + r * .2), fill=(110, 70, 30))
    face(d, c, c + r * .62, r * .45, (178, 128, 20))
    return done(img)


def berry():
    img = canvas()
    d = ImageDraw.Draw(img)
    c, r = S * K / 2, S * K * .38
    shade(d, (c - r, c - r, c + r, c + r), (110, 170, 255), (50, 100, 190), int(r * .06))
    for k in range(8):  # frost
        a = k * math.pi / 4
        d.line((c + math.cos(a) * r * .55, c + math.sin(a) * r * .55, c + math.cos(a) * r * .85, c + math.sin(a) * r * .85), fill=(235, 248, 255), width=int(r * .06))
    face(d, c, c + r * .05, r, (50, 100, 190))
    return done(img)


def board():
    """A wooden board: planks, soft grain, darker edges."""
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), (196, 132, 78))
    d = ImageDraw.Draw(img)
    planks = 6
    for k in range(planks):
        x0 = k * w // planks
        tone = [(204, 140, 84), (190, 126, 72), (210, 148, 92)][k % 3]
        d.rectangle((x0, 0, x0 + w // planks, h), fill=tone)
        for g in range(14):  # grain
            gx = x0 + 18 + (g * 53 + k * 29) % (w // planks - 36)
            d.line((gx, 0, gx + 12, h), fill=tuple(v - 14 for v in tone), width=3)
        d.line((x0, 0, x0, h), fill=(140, 88, 46), width=8)
    vignette = Image.new("L", (w, h), 0)
    ImageDraw.Draw(vignette).ellipse((-w * .25, -h * .12, w * 1.25, h * 1.12), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGB", (w, h), (92, 56, 30))
    return Image.composite(img, dark, vignette)


def cover(pics):
    img = board().crop((0, 420, 1080, 1500)).resize((720, 720))
    for name, x, y, s in [("watermelon", 170, 230, 300), ("apple", 520, 200, 250), ("orange", 380, 470, 270), ("lemon", 130, 520, 200)]:
        p = pics[name].resize((s, s))
        img.paste(p, (x - s // 2, y - s // 2), p)
    d = ImageDraw.Draw(img)
    d.line((60, 640, 680, 80), fill=(255, 255, 255), width=10)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pics = {}
    for name in FRUITS:
        pics[name] = whole(name)
        pics[name].save(OUT / f"{name}.webp", quality=90, method=6)
        inside(name).save(OUT / f"{name}_cut.webp", quality=90, method=6)
    for name, make in (("star", star), ("banana", banana), ("berry", berry)):
        p = make()
        p.save(OUT / f"{name}.webp", quality=90, method=6)
    # the specials' cut faces: the star's and the banana's golden inside, the berry's ice
    inside_like = {"star": "lemon", "banana": "lemon", "berry": "plum"}
    for name, like in inside_like.items():
        inside(like).save(OUT / f"{name}_cut.webp", quality=90, method=6)
    board().save(OUT / "bg_board.webp", quality=86, method=6)
    cover(pics).save(OUT / "cover.webp", quality=86, method=6)
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
