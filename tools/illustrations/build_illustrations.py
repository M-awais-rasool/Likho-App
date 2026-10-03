#!/usr/bin/env python3
"""Builds the course illustrations: app/assets/illustrations/<key>.png.

Every picture in the course content (`picture.key` in backend/content) gets an
image here. The art is Microsoft's Fluent Emoji, 3D style (MIT licence, see
app/assets/licenses/fluent-emoji.txt), downloaded from a pinned commit. Most keys
are one emoji; scenes the course needs ("cat on box", "fish in bowl", "many
cats") are made from several, and a few are recoloured ("red bus").

Every image is 256 x 256 with a transparent background, the drawing trimmed
and centred with the same margin, so pictures sit on any card or shape in the
app and look the same size.

    pip install -r tools/illustrations/requirements.txt     # pillow, numpy
    python3 tools/illustrations/build_illustrations.py           # missing ones
    python3 tools/illustrations/build_illustrations.py --all     # every one
    python3 tools/illustrations/build_illustrations.py --sheet   # + a preview sheet

Add a picture: add its key to SINGLE (one emoji) or SCENES (a function), run
the script, and use the key in the content JSON.
"""

import argparse
import colorsys
import json
import pathlib
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

FLUENT_COMMIT = "1ffb34c752ecf5d402f04cfb4b392c77f57c54bc"  # microsoft/fluentui-emoji, 2026-08-24
FLUENT_RAW = f"https://raw.githubusercontent.com/microsoft/fluentui-emoji/{FLUENT_COMMIT}/assets/"
SIZE = 256
MARGIN = 0.07  # empty border around every drawing, of the size
TONE = "Medium"  # skin tone for people

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # the repository
OUT = ROOT / "app" / "assets" / "illustrations"
CACHE = HERE / ".cache"

# key -> Fluent emoji folder name, or (name, skin tone) for people
SINGLE = {
    "alien": "Alien",
    "ant": "Ant",
    "apple": "Red apple",
    "ball": "Soccer ball",
    "balloon": "Balloon",
    "banana": "Banana",
    "bear": "Bear",
    "bed": "Bed",
    "bee": "Honeybee",
    "bread": "Bread",
    "blue_car": "Sport utility vehicle",
    "box": "Package",
    "bubble": "Bubbles",
    "bun": "Bread",
    "bus": "Bus",
    "butterfly": "Butterfly",
    "cake": "Birthday cake",
    "car": "Automobile",
    "cat": "Cat",
    "chick": "Baby chick",
    "cloud": "Cloud",
    "crack": "Hatching chick",
    "cow": "Cow face",
    "crab": "Crab",
    "cup": "Hot beverage",
    "cupcake": "Cupcake",
    "doctor": ("Health worker", TONE),
    "dog": "Dog face",
    "dough": "Bowl with spoon",
    "dragon": "Dragon",
    "duck": "Duck",
    "eat": "Fork and knife with plate",
    "egg": "Egg",
    "family_baby": ("Baby", TONE),
    "family_brother": ("Boy", TONE),
    "family_father": ("Man", TONE),
    "family_mother": ("Woman", TONE),
    "family_sister": ("Girl", TONE),
    "fish": "Tropical fish",
    "flower": "Sunflower",
    "frog": "Frog",
    "goat": "Goat",
    "hat": "Top hat",
    "hen": "Chicken",
    "kite": "Kite",
    "lion": "Lion",
    "log": "Wood",
    "moon": "Crescent moon",
    "orange": "Tangerine",
    "oven": "Fire",
    "owl": "Owl",
    "paint": "Artist palette",
    "pencil": "Pencil",
    "pig": "Pig face",
    "planet": "Ringed planet",
    "play": "Playground slide",
    "rain": "Cloud with rain",
    "rain_cloud": "Cloud with rain",
    "rainbow": "Rainbow",
    "red_car": "Automobile",
    "robot": "Robot",
    "run": ("Person running", TONE),
    "sand": "Beach with umbrella",
    "school": "School",
    "sea": "Water wave",
    "seed": "Beans",
    "shell": "Spiral shell",
    "snail": "Snail",
    "sprout": "Seedling",
    "star": "Star",
    "story": "Open book",
    "storybook": "Books",
    "sun": "Sun",
    "tiger": "Tiger face",
    "train": "Locomotive",
    "tree": "Deciduous tree",
    "umbrella": "Umbrella",
    "wake_up": "Alarm clock",
    "warm-up": ("Writing hand", TONE),
}


# ---------------------------------------------------------------- sources

_tree = None


def _fluent_paths():
    """Every 3D PNG of the pinned commit (downloaded once, cached)."""
    global _tree
    if _tree is None:
        f = CACHE / f"tree-{FLUENT_COMMIT[:12]}.json"
        if not f.exists():
            CACHE.mkdir(parents=True, exist_ok=True)
            url = f"https://api.github.com/repos/microsoft/fluentui-emoji/git/trees/{FLUENT_COMMIT}?recursive=1"
            with urllib.request.urlopen(url) as r:
                tree = json.load(r)
            paths = [x["path"] for x in tree["tree"] if x["path"].endswith(".png") and "/3D/" in x["path"]]
            f.write_text(json.dumps(paths))
        _tree = json.loads(f.read_text())
    return _tree


def emoji(name, tone=None):
    """A Fluent 3D emoji as an RGBA image, trimmed to its drawing."""
    candidates = [p for p in _fluent_paths() if p.split("/")[1] == name]
    if not candidates:
        raise SystemExit(f"no Fluent emoji called {name!r}")
    path = next((p for p in candidates if f"/{tone or 'Default'}/" in p), candidates[0])
    f = CACHE / path.replace("/", "__")
    if not f.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(FLUENT_RAW + urllib.parse.quote(path[len("assets/"):]), f)
    return trim(Image.open(f).convert("RGBA"))


# ---------------------------------------------------------------- drawing

def trim(im):
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    return im.crop(box) if box else im


def canvas():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def scaled(im, height=None, width=None):
    """[im] resized to a height or width in pixels (keeps its shape)."""
    if height is not None:
        width = round(im.width * height / im.height)
    else:
        height = round(im.height * width / im.width)
    return im.resize((max(1, width), max(1, height)), Image.LANCZOS)


def put(base, im, cx, cy, alpha=1.0):
    """Pastes [im] centred at (cx, cy) (0..1 of the canvas)."""
    if alpha < 1:
        a = np.asarray(im).copy()
        a[..., 3] = (a[..., 3] * alpha).astype(np.uint8)
        im = Image.fromarray(a)
    x = round(cx * base.width - im.width / 2)
    y = round(cy * base.height - im.height / 2)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, (x, y), im)
    return Image.alpha_composite(base, layer)


def finish(im):
    """Trims the drawing and centres it in SIZE x SIZE with the margin."""
    im = trim(im)
    room = SIZE * (1 - 2 * MARGIN)
    k = min(room / im.width, room / im.height)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = canvas()
    out.paste(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2), im)
    return out


def recolor(im, hues, to_hue, sat=None):
    """Moves pixels whose hue is within [hues] (degrees) to [to_hue]."""
    a = np.asarray(im).astype(np.float32) / 255
    rgb = a[..., :3]
    hsv = np.vectorize(colorsys.rgb_to_hsv, otypes=[np.float32] * 3)(rgb[..., 0], rgb[..., 1], rgb[..., 2])
    h, s, v = hsv
    lo, hi = hues[0] / 360, hues[1] / 360
    sel = (h >= lo) & (h <= hi) & (s > 0.15)
    h = np.where(sel, to_hue / 360, h)
    if sat is not None:
        s = np.where(sel, np.clip(s * sat, 0, 1), s)
    r, g, b = np.vectorize(colorsys.hsv_to_rgb, otypes=[np.float32] * 3)(h, s, v)
    out = np.stack([r, g, b, a[..., 3]], axis=-1)
    return Image.fromarray((out * 255).round().astype(np.uint8))


def tinted(im, color, strength, where=None):
    """Mixes [color] into [im] (only where [where](rgb array) is true)."""
    a = np.asarray(im).astype(np.float32)
    mask = np.ones(a.shape[:2], bool) if where is None else where(a[..., :3])
    c = np.array(color, np.float32)
    a[..., :3] = np.where(mask[..., None], a[..., :3] * (1 - strength) + c * strength, a[..., :3])
    return Image.fromarray(a.round().astype(np.uint8))


def mirrored(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def glow(base, cx, cy, radius, color):
    """A soft round light behind what comes next. The layer is the light's
    colour everywhere (only alpha changes), so blurring it cannot mix in
    black at the edges."""
    layer = Image.new("RGBA", base.size, color[:3] + (0,))
    d = ImageDraw.Draw(layer)
    x, y, r = cx * base.width, cy * base.height, radius * base.width
    d.ellipse((x - r, y - r, x + r, y + r), fill=color)
    return Image.alpha_composite(base, layer.filter(ImageFilter.GaussianBlur(r * 0.45)))


# ---------------------------------------------------------------- scenes

def three(name, tone=None, h=0.46):
    """Many of one thing: two at the back, one in front."""
    one = scaled(emoji(name, tone), height=round(SIZE * h))
    im = canvas()
    im = put(im, one, 0.30, 0.38)
    im = put(im, one, 0.70, 0.38)
    return put(im, one, 0.50, 0.64)


def on_box(animal):
    # the animal is what tells the pictures apart: big, on a small box
    im = put(canvas(), scaled(emoji("Package"), width=round(SIZE * 0.46)), 0.5, 0.78)
    return put(im, scaled(emoji(animal), height=round(SIZE * 0.58)), 0.5, 0.34)


def running(animal):
    # the animals face left: the dust trails behind them, on the right
    im = put(canvas(), mirrored(scaled(emoji("Dashing away"), height=round(SIZE * 0.34))), 0.80, 0.58, alpha=0.9)
    return put(im, scaled(emoji(animal), height=round(SIZE * 0.6)), 0.42, 0.5)


def in_bed(animal, face, zzz=False):
    """Tucked in: the head on the pillow, the blanket over the rest."""
    bed = scaled(emoji("Bed"), width=round(SIZE * 0.9))
    im = put(canvas(), bed, 0.5, 0.62)
    im = put(im, scaled(emoji(face), height=round(SIZE * 0.42)), 0.30, 0.44)
    # the bed's blanket (blue) back on top, so it covers the animal's chin
    blanket = tinted(bed, (0, 0, 0), 0, None)
    a = np.asarray(blanket).copy()
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    keep = (b > r + 40) & (b > g + 20) & (np.arange(a.shape[0])[:, None] > a.shape[0] * 0.30)
    a[..., 3] = np.where(keep, a[..., 3], 0)
    im = put(im, Image.fromarray(a), 0.5, 0.62)
    if zzz:
        im = put(im, scaled(emoji("Zzz"), height=round(SIZE * 0.24)), 0.80, 0.22)
    return im


def jar(fill=None, strength=0.55):
    j = emoji("Jar")
    if fill is not None:
        # the glass below the lid takes the colour of what is inside
        a = np.asarray(j).astype(np.float32)
        rows = np.arange(a.shape[0])[:, None]
        body = (rows > a.shape[0] * 0.22) & (a[..., 3] > 0)
        light = a[..., :3].mean(axis=-1) > 150
        c = np.array(fill, np.float32)
        mix = np.where((body & light)[..., None], a[..., :3] * (1 - strength) + c * strength, a[..., :3])
        a[..., :3] = mix
        j = Image.fromarray(a.round().astype(np.uint8))
    return j


def message_in_bottle():
    j = scaled(jar(), height=round(SIZE * 0.86))
    im = put(canvas(), j, 0.5, 0.5)
    scroll = scaled(emoji("Scroll"), height=round(SIZE * 0.38)).rotate(-14, expand=True, resample=Image.BICUBIC)
    return put(im, scroll, 0.5, 0.60, alpha=0.92)


def fish_in_bowl():
    j = scaled(jar(fill=(120, 190, 240)), height=round(SIZE * 0.86))
    im = put(canvas(), j, 0.5, 0.5)
    return put(im, scaled(emoji("Tropical fish"), width=round(SIZE * 0.40)), 0.5, 0.60, alpha=0.95)


def jam():
    j = scaled(jar(fill=(196, 18, 48), strength=0.78), height=round(SIZE * 0.82))
    im = put(canvas(), j, 0.44, 0.48)
    return put(im, scaled(emoji("Strawberry"), height=round(SIZE * 0.36)), 0.74, 0.74)


def puddle():
    """Flat water on the ground with drops falling in (no emoji for it)."""
    w, h = round(SIZE * 0.86), round(SIZE * 0.34)
    pool = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = np.zeros((h, w, 4), np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    nx, ny = (xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)
    r = np.sqrt(nx ** 2 + ny ** 2)
    inside = r <= 1
    # water: light at the far edge, deeper towards the front, like the wave emoji
    top, front = np.array([150, 205, 255], np.float32), np.array([45, 120, 235], np.float32)
    t = np.clip((ny + 1) / 2, 0, 1)[..., None]
    a[..., :3] = top * (1 - t) + front * t
    a[..., 3] = np.clip((1 - r) * 18, 0, 1) * 255 * inside
    pool = Image.fromarray(a.round().astype(np.uint8))
    shine = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    ImageDraw.Draw(shine).ellipse((w * 0.18, h * 0.22, w * 0.58, h * 0.48), fill=(255, 255, 255, 120))
    pool = Image.alpha_composite(pool, shine.filter(ImageFilter.GaussianBlur(h * 0.08)))
    im = put(canvas(), pool, 0.5, 0.72)
    drop = emoji("Droplet")
    im = put(im, scaled(drop, height=round(SIZE * 0.30)), 0.36, 0.30)
    return put(im, scaled(drop, height=round(SIZE * 0.22)), 0.66, 0.40)


def fish_in_sea():
    im = put(canvas(), scaled(emoji("Water wave"), width=round(SIZE * 0.92)), 0.5, 0.5)
    return put(im, scaled(emoji("Tropical fish"), width=round(SIZE * 0.48)), 0.42, 0.66)


def bird_in_sky():
    im = put(canvas(), scaled(emoji("Cloud"), width=round(SIZE * 0.64)), 0.33, 0.30)
    im = put(im, scaled(emoji("Cloud"), width=round(SIZE * 0.56)), 0.70, 0.76)
    return put(im, scaled(emoji("Bird"), height=round(SIZE * 0.44)), 0.54, 0.50)


def hot_sun():
    im = put(canvas(), scaled(emoji("Sun with face"), height=round(SIZE * 0.82)), 0.46, 0.54)
    return put(im, scaled(emoji("Sweat droplets"), height=round(SIZE * 0.32)), 0.82, 0.18)


def family():
    im = canvas()
    im = put(im, scaled(emoji("Man", TONE), height=round(SIZE * 0.52)), 0.30, 0.36)
    im = put(im, scaled(emoji("Woman", TONE), height=round(SIZE * 0.52)), 0.70, 0.36)
    return put(im, scaled(emoji("Girl", TONE), height=round(SIZE * 0.44)), 0.50, 0.70)


def firefly():
    """A beetle whose tail glows. The light is added after the drawing is
    sized (so its soft edge is not part of the drawing's box)."""
    beetle = scaled(emoji("Beetle"), height=round(SIZE * 0.62)).rotate(-28, expand=True, resample=Image.BICUBIC)
    im = put(canvas(), beetle, 0.50, 0.50)
    im = put(im, scaled(emoji("Sparkles"), height=round(SIZE * 0.26)), 0.82, 0.20)
    im = finish(put(im, scaled(emoji("Sparkles"), height=round(SIZE * 0.18)), 0.16, 0.80, alpha=0.9))
    light = glow(canvas(), 0.60, 0.64, 0.20, (255, 222, 70, 210))
    light = glow(light, 0.61, 0.65, 0.10, (255, 248, 190, 255))
    return Image.alpha_composite(light, im)


def forest():
    im = canvas()
    im = put(im, scaled(emoji("Evergreen tree"), height=round(SIZE * 0.62)), 0.24, 0.42)
    im = put(im, scaled(emoji("Evergreen tree"), height=round(SIZE * 0.56)), 0.78, 0.46)
    return put(im, scaled(emoji("Deciduous tree"), height=round(SIZE * 0.70)), 0.50, 0.60)


def red_bus():
    return recolor(emoji("Bus"), (18, 62), 356, sat=1.15)


def red_crayon():
    return recolor(emoji("Crayon"), (40, 180), 356, sat=1.1)


def zoo_bus():
    im = put(canvas(), scaled(emoji("Giraffe"), height=round(SIZE * 0.78)), 0.74, 0.40)
    return put(im, scaled(emoji("Bus"), width=round(SIZE * 0.78)), 0.42, 0.66)


def robot_bus():
    im = put(canvas(), scaled(emoji("Bus"), width=round(SIZE * 0.86)), 0.5, 0.64)
    return put(im, scaled(emoji("Robot"), height=round(SIZE * 0.42)), 0.5, 0.26)


SCENES = {
    "birds": lambda: three("Bird"),
    "bird_in_sky": bird_in_sky,
    "bottle": message_in_bottle,
    "bottle_message": message_in_bottle,
    "cat_in_bed": lambda: in_bed("Cat", "Cat face"),
    "cat_on_box": lambda: on_box("Cat"),
    "cat_running": lambda: running("Cat"),
    "dog_asleep": lambda: in_bed("Dog", "Dog face", zzz=True),
    "dog_on_box": lambda: on_box("Dog"),
    "dog_running": lambda: running("Dog"),
    "family": family,
    "firefly": firefly,
    "fish_in_bowl": fish_in_bowl,
    "fish_in_sea": fish_in_sea,
    "forest": forest,
    "hot": hot_sun,
    "hot_sun": hot_sun,
    "jam": jam,
    "many_birds": lambda: three("Bird"),
    "many_cats": lambda: three("Cat"),
    "many_cups": lambda: three("Hot beverage", h=0.40),
    "many_dogs": lambda: three("Dog face", h=0.42),
    "many_hats": lambda: three("Top hat", h=0.40),
    "puddle": puddle,
    "red": red_crayon,
    "red_bus": red_bus,
    "robot-bus": robot_bus,
    "zoo_bus": zoo_bus,
}


# scenes that size themselves (finish() inside)
SIZED = {"firefly"}


def build(key):
    if key in SCENES:
        im = SCENES[key]()
        return im if key in SIZED else finish(im)
    spec = SINGLE[key]
    name, tone = spec if isinstance(spec, tuple) else (spec, None)
    return finish(emoji(name, tone))


def keys():
    return sorted(set(SINGLE) | set(SCENES))


def sheet(path):
    """Every illustration on the app's cream background, with its key."""
    from PIL import ImageFont

    ks = keys()
    cols, cell, label = 10, 132, 18
    rows = (len(ks) + cols - 1) // cols
    im = Image.new("RGB", (cols * cell, rows * (cell + label)), (255, 248, 236))
    d = ImageDraw.Draw(im)
    font = ImageFont.load_default()
    for i, k in enumerate(ks):
        pic = Image.open(OUT / f"{k}.png").resize((cell - 12, cell - 12), Image.LANCZOS)
        x, y = (i % cols) * cell, (i // cols) * (cell + label)
        im.paste(pic, (x + 6, y + 4), pic)
        d.text((x + 6, y + cell - 4), k, fill=(43, 45, 66), font=font)
    im.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="rebuild every illustration")
    ap.add_argument("--sheet", metavar="PNG", help="also write a preview sheet")
    ap.add_argument("only", nargs="*", help="just these keys")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    todo = args.only or [k for k in keys() if args.all or not (OUT / f"{k}.png").exists()]
    for k in todo:
        build(k).save(OUT / f"{k}.png", optimize=True)
        print("built", k)
    if args.sheet:
        sheet(args.sheet)
        print("sheet", args.sheet)


if __name__ == "__main__":
    main()
