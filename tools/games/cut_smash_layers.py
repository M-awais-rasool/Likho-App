#!/usr/bin/env python3
"""Cuts Monster Smash's background layers (design/games/monster-smash/layers/,
made in Gemini, prompts in design/games/monster-smash-layers-prompts.md)
into the pictures the app scrolls behind the game: app/assets/games/smash/.

* the sky: kept whole (it covers the screen)
* the far hills, the near hills, the ground: the white around them cut
  away (only the white joined to the top, so a light patch inside stays),
  the soft edge unmixed from the white, the empty top cropped off
* the windmill is taken off the far hills: the app draws it with turning
  sails at the same place

It also measures, for the app (ms_layer_lines.dart), each picture's
shape, where its hill tops or grass top run (the line the app puts on
the screen), and where the windmill stood.

    python3 tools/games/cut_smash_layers.py      # needs pillow, numpy, scipy
"""

import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "monster-smash" / "layers"
OUT = ROOT / "app" / "assets" / "games" / "smash"
LINES = ROOT / "app" / "lib" / "screens" / "games" / "monster_smash" / "ms_layer_lines.dart"

WORLDS = ["meadow"]


def cut_white(rgb, pockets=False):
    """RGBA: the near-white joined to the top made clear, the edge unmixed;
    with [pockets], the white shut in between trees and hills too (not on
    the ground: its daisies are white)."""
    a = rgb.astype(float)
    whiteish = (a.min(axis=2) > 236) & (a.max(axis=2) - a.min(axis=2) < 14)
    labels, n = ndimage.label(whiteish)
    top = set(np.unique(labels[0])) - {0}
    if pockets:
        index = np.arange(1, n + 1)
        size = ndimage.sum(whiteish, labels, index)
        light = ndimage.mean(a.min(axis=2), labels, index)
        top |= {int(i) for i, s, m in zip(index, size, light) if s >= 6 and m > 243}
    clear = np.isin(labels, list(top))
    # the soft edge: two pixels around the clear part, unmixed from white
    # with the colour of the nearest solid pixel
    band = ndimage.binary_dilation(clear, iterations=2) & ~clear
    solid = ~clear & ~band
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    fg = a[iy, ix]
    alpha = np.ones(a.shape[:2])
    alpha[clear] = 0
    cover = (255 - a).mean(axis=2) / np.maximum((255 - fg).mean(axis=2), 1)
    alpha[band] = np.clip(cover[band], 0, 1)
    out = a.copy()
    keep = band & (alpha > .02)
    out[keep] = np.clip((a[keep] - (1 - alpha[keep, None]) * 255) / alpha[keep, None], 0, 255)
    out[band & (alpha <= .02)] = fg[band & (alpha <= .02)]
    out[clear] = fg[clear]  # no white fringe when it is scaled
    return np.dstack([out, alpha * 255]).round().astype(np.uint8)


def take_off_windmill(rgba):
    """Clears the windmill above its hill; returns its foot (x, y) and size
    (foot to roof top, pixels)."""
    a = rgba[..., :3].astype(int)
    roof = (a[..., 0] > 200) & (a[..., 1] < 150) & (a[..., 2] < 150) & (rgba[..., 3] > 200)
    ys, xs = np.nonzero(roof)
    cx, cy, roof_top = int(np.median(xs)), int(np.median(ys)), ys.min()
    foot = None
    for x in range(cx - 42, cx + 43):
        y = cy + 85
        # up through the hill (green over red, the outline too)
        while y > 0 and rgba[y, x, 3] > 0 and a[y, x, 1] >= a[y, x, 0] + 4:
            y -= 1
        if x == cx:
            foot = y
        rgba[: y + 1, x, 3] = np.where(np.arange(y + 1) >= cy - 60, 0, rgba[: y + 1, x, 3])
    return (cx, foot + 2), foot + 2 - roof_top


def top_line(rgba):
    """Where the hill tops or the grass top run: the median first solid row."""
    solid = rgba[..., 3] > 128
    first = solid.argmax(axis=0)
    return float(np.median(first[solid.any(axis=0)]))


def main():
    lines = [
        "// Made by tools/games/cut_smash_layers.py: do not edit.",
        "import 'dart:ui';",
        "",
        "/// A background layer picture: its width over its height, and where",
        "/// its hill tops (or the grass top) run, a fraction of its height.",
        "class MsLayerLine {",
        "  const MsLayerLine(this.aspect, this.line);",
        "  final double aspect, line;",
        "}",
        "",
    ]
    for world in WORLDS:
        sky = Image.open(SRC / f"{world}_sky.png").convert("RGB")
        sky.save(OUT / f"{world}_sky.webp", quality=88, method=6)
        boxes = {"sky": (sky.width / sky.height, 0.0)}
        mill = None
        for layer in ["far", "near", "ground"]:
            rgba = cut_white(np.asarray(Image.open(SRC / f"{world}_{layer}.png").convert("RGB")), pockets=layer != "ground")
            if layer == "far":
                (mx, my), msize = take_off_windmill(rgba)
            solid_rows = np.nonzero((rgba[..., 3] > 8).any(axis=1))[0]
            y0 = max(int(solid_rows.min()) - 4, 0)
            if layer == "far":
                y0 = min(y0, my - int(msize * 1.4))  # room for the sails
                mill = (mx / rgba.shape[1], (my - y0) / (rgba.shape[0] - y0), msize / (rgba.shape[0] - y0))
            rgba = rgba[y0:]
            h, w = rgba.shape[:2]
            Image.fromarray(rgba).save(OUT / f"{world}_{layer}.webp", quality=88, method=6)
            boxes[layer] = (w / h, top_line(rgba) / h)
            print(f"{world}_{layer}: {w}x{h}, line {boxes[layer][1]:.3f}")
        name = world[0].upper() + world[1:]
        lines.append(f"/// {name}: the sky, far hills, near hills and the ground.")
        for layer, (aspect, line) in boxes.items():
            lines.append(f"const ms{name}{layer[0].upper()}{layer[1:]} = MsLayerLine({aspect:.4f}, {line:.4f});")
        lines += [
            "",
            f"/// Where the windmill stood on {world}'s far hills: its foot and its",
            "/// height (foot to roof top), fractions of the picture.",
            f"const ms{name}Mill = Offset({mill[0]:.4f}, {mill[1]:.4f});",
            f"const ms{name}MillSize = {mill[2]:.4f};",
        ]
    LINES.write_text("\n".join(lines) + "\n")
    print(f"wrote {LINES.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
