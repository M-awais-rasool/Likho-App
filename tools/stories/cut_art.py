#!/usr/bin/env python3
"""Cuts the story art (design/town/*.jpeg, made in Gemini in Pencil's style)
into the pictures the app uses: app/assets/stories/<episode>/.

* character sheets (2 rows x 4 poses, or one row): every pose on a
  transparent background, all poses of a character the same size and with
  their feet on the same line, so the app can swap poses without a jump
* prop sheets (2 rows x 5 things): each thing trimmed, on a transparent
  background
* backgrounds (9:16): resized

All WebP (small, with transparency), so the app stays small.

The white background (and the grey shadow under the feet: the app draws its
own) is cut away from the outside in, so white clothes and beards inside the
outlines stay. Edges are softened and their white fringe taken out.

    python3 tools/stories/cut_art.py            # needs pillow, numpy, scipy
"""

import json
import pathlib

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "design" / "town"
OUT = ROOT / "app" / "assets" / "stories" / "a"

POSE_HEIGHT = 560  # px of a character pose (the app shows it at most ~280 dp)
PROP_SIDE = 360
BG_WIDTH = 1080

# sheet file -> (name, rows, cols, pose names in reading order)
SHEETS = {
    "ayan_sheet.jpeg": ("ayan", 2, 4, ["idle", "talk", "wave", "happy", "point", "thumbs", "surprised", "basket"]),
    "dada_sheet.jpeg": ("dada", 2, 4, ["idle", "talk", "worried", "happy", "point", "thumbs", "give", "wave"]),
    "aunty_sheet.jpeg": ("aunty", 2, 4, ["idle", "talk", "think", "happy", "pay", "apples", "surprised", "wave"]),
    "aunt_sheet.jpeg": ("ant", 1, 4, ["idle", "wave", "happy", "surprised"]),  # the little ant
}
PROPS = {
    "props_garden.jpeg": (2, 5, ["apple_leaf", "apple", "basket", "basket_full", "leaf", "airplane", "cloud", "flower", "bird", "sun"], {"basket", "basket_full"}),
    "props_shop.jpeg": (2, 5, ["sign", "sign_old", "crate", "crate_apples", "crate_bananas", "crate_mangoes", "coin", "coins", "apple_bag", "golden_apple"], set()),
}
BACKGROUNDS = ["bg_house.jpeg", "bg_garden.jpeg", "bg_market.jpeg"]


def background_mask(rgb):
    """True where the picture is the white (or grey shadow) background,
    reached from the edges without crossing an outline."""
    lo, hi = rgb.min(axis=2).astype(int), rgb.max(axis=2).astype(int)
    paper = (lo > 200) & (hi - lo < 22)  # white, light grey: no colour
    labels, _ = ndimage.label(paper)
    edge = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    return np.isin(labels, list(edge))


def cut(rgb, bg):
    """RGBA: the background clear, soft edges without a white fringe."""
    fg = ~bg
    # tiny white specks closed in by the outline stay (bigger closed-in
    # background, such as under a basket's handle, was marked by the caller)
    specks, n = ndimage.label(ndimage.binary_fill_holes(fg) & ~fg & ~bg)
    if n:
        small = np.nonzero(ndimage.sum(np.ones_like(specks), specks, range(1, n + 1)) < 300)[0] + 1
        fg |= np.isin(specks, small)
    alpha = np.asarray(Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float32) / 255
    alpha[fg & (ndimage.binary_erosion(fg, iterations=2))] = 1
    a = alpha[..., None]
    col = rgb.astype(np.float32)
    # un-mix the white the edge pixels were blended with
    safe = np.clip(a, 0.05, 1)
    col = np.where(a < 1, (col - (1 - safe) * 255) / safe, col)
    out = np.concatenate([np.clip(col, 0, 255), alpha[..., None] * 255], axis=2).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def sheet(path, name, rows, cols, poses, manifest):
    img = Image.open(path).convert("RGB")
    rgb = np.asarray(img)
    bg = background_mask(rgb)
    rgba = cut(rgb, bg)
    h, w = bg.shape
    cw, ch = w // cols, h // rows
    cells, boxes = [], []
    for i, pose in enumerate(poses):
        r, c = divmod(i, cols)
        box = (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
        fg = ~bg[box[1]:box[3], box[0]:box[2]]
        ys, xs = np.nonzero(fg)
        cells.append((pose, box))
        boxes.append((xs.min(), ys.min(), xs.max(), ys.max()))
    # one frame for every pose of the character: the union of their boxes,
    # feet on the bottom edge
    x0 = min(b[0] for b in boxes) - 8
    y0 = min(b[1] for b in boxes) - 8
    x1 = max(b[2] for b in boxes) + 8
    y1 = max(b[3] for b in boxes) + 4
    scale = POSE_HEIGHT / (y1 - y0)
    size = (round((x1 - x0) * scale), POSE_HEIGHT)
    for pose, box in cells:
        frame = rgba.crop((box[0] + x0, box[1] + y0, box[0] + x1, box[1] + y1)).resize(size, Image.LANCZOS)
        frame.save(OUT / f"{name}_{pose}.webp", quality=90, method=6)
    manifest[name] = {"poses": poses, "size": size}
    print(f"{name}: {len(poses)} poses {size[0]}x{size[1]}")


def props(path, rows, cols, names, manifest, holes=()):
    """Each thing on the sheet, found by its shape (things are not evenly
    spaced, so a grid would cut them): parts close together (the sun and
    its rays) are one thing; reading order, row by row. [holes]: things
    whose closed-in white is background too (the space under a basket's
    handle)."""
    rgb = np.asarray(Image.open(path).convert("RGB"))
    bg = background_mask(rgb)
    h, w = bg.shape
    groups, n = ndimage.label(ndimage.binary_dilation(~bg, iterations=24))
    found = []
    for g in range(1, n + 1):
        ys, xs = np.nonzero(groups == g)
        if len(xs) < 4000:
            continue  # a speck
        found.append((xs.min(), ys.min(), xs.max(), ys.max()))
    assert len(found) == len(names), f"{path.name}: found {len(found)} things, expected {len(names)}"
    found.sort(key=lambda b: (int((b[1] + b[3]) / 2 / (h / rows)), b[0]))
    for name, (x0, y0, x1, y1) in zip(names, found):
        box = (max(0, x0 + 18), max(0, y0 + 18), min(w, x1 - 18), min(h, y1 - 18))  # undo the dilation, keep a margin
        sub_rgb = rgb[box[1]:box[3], box[0]:box[2]]
        sub_bg = bg[box[1]:box[3], box[0]:box[2]].copy()
        if name in holes:
            lo, hi = sub_rgb.min(axis=2).astype(int), sub_rgb.max(axis=2).astype(int)
            white, _ = ndimage.label((lo > 236) & (hi - lo < 14))
            sizes = ndimage.sum(np.ones_like(white), white, range(1, white.max() + 1))
            for k, size in enumerate(sizes, start=1):
                if size > 1500:
                    sub_bg |= white == k
        thing = cut(sub_rgb, sub_bg)
        thing = thing.crop(thing.getbbox())
        thing.thumbnail((PROP_SIDE, PROP_SIDE), Image.LANCZOS)
        thing.save(OUT / f"{name}.webp", quality=90, method=6)
        manifest[name] = {"size": thing.size}
    print(f"{path.name}: {len(names)} things")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for f, (name, rows, cols, poses) in SHEETS.items():
        sheet(SRC / f, name, rows, cols, poses, manifest)
    for f, (rows, cols, names, holes) in PROPS.items():
        if (SRC / f).exists():
            props(SRC / f, rows, cols, names, manifest, holes)
        else:
            print(f"{f}: not made yet (skipped)")
    for f in BACKGROUNDS:
        img = Image.open(SRC / f).convert("RGB")
        img = img.resize((BG_WIDTH, round(img.height * BG_WIDTH / img.width)), Image.LANCZOS)
        name = f.replace(".jpeg", "")
        img.save(OUT / f"{name}.webp", quality=86, method=6)
        manifest[name] = {"size": img.size}
    (OUT / "art.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
