#!/usr/bin/env python3
"""Cuts the Stationery Squad (design/games/monster-smash/heroes/*_sheet.jpeg,
made in Gemini, prompts in design/games/monster-smash-heroes-prompts.md) into
the pictures the app uses: app/assets/games/smash/hero_<name>_<pose>.webp.

Each sheet is 2 rows x 3 poses: idle, aim, fly / power, bonked, happy.

* The white and the grey shadows go (the same cutting as the stories).
* Only the hero is kept: the loose strokes Gemini drew around a pose (speed
  lines, wobble lines) are left out, the app draws its own.
* Every pose of a hero is drawn at one scale: the idle pose's size (the
  radius of a circle with the same area) is the hero's radius in the game.
* Where each pose's middle is, how far down its feet are and which way a
  long pose points go to ms_hero_frames.dart, so the app puts the picture
  on the ball the physics moves.

    python3 tools/games/cut_smash_heroes.py      # needs pillow, numpy, scipy
"""

import importlib.util
import math
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "monster-smash" / "heroes"
OUT = ROOT / "app" / "assets" / "games" / "smash"
FRAMES = ROOT / "app" / "lib" / "screens" / "games" / "monster_smash" / "ms_hero_frames.dart"

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)

HEROES = ["rubby", "inky", "crayo"]
POSES = ["idle", "aim", "fly", "power", "bonked", "happy"]
# Poses Gemini drew wrong, shown with another pose until the sheet is made again
SUBSTITUTE = {"crayo": {"aim": "idle"}}
UNIT = 96  # px of the hero's radius in the pictures (at most ~30 dp on a 3x phone)
NEAR = 14  # px: a part this close to the body is the hero's (a foot), further is a stroke


def hero_masks(fg):
    """The six heroes on a sheet, in reading order: the six biggest shapes
    (a pose may reach past its grid cell) and the parts touching each."""
    labels, n = ndimage.label(fg)
    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, n + 1))
    bodies = [int(k) + 1 for k in np.argsort(sizes)[::-1][: len(POSES)]]
    middles = ndimage.center_of_mass(fg, labels, bodies)
    half = fg.shape[0] / 2
    bodies = [b for _, b in sorted(zip(middles, bodies), key=lambda e: (e[0][0] > half, e[0][1]))]
    masks = []
    for b in bodies:
        body = labels == b
        ys, xs = np.nonzero(body)
        y0, y1, x0, x1 = max(0, ys.min() - 60), ys.max() + 60, max(0, xs.min() - 60), xs.max() + 60
        near = np.zeros_like(body)
        near[y0:y1, x0:x1] = ndimage.binary_dilation(body[y0:y1, x0:x1], iterations=NEAR)
        keep = body.copy()
        for k in np.unique(labels[near]):
            if k and k not in bodies and sizes[k - 1] > 400:
                keep |= labels == k
        masks.append(keep)
    return masks


def tilt(mask):
    """Which way a pose's long side points (radians, y down), towards the right."""
    ys, xs = np.nonzero(mask)
    cov = np.cov(np.stack([xs - xs.mean(), ys - ys.mean()]))
    vals, vecs = np.linalg.eigh(cov)
    vx, vy = vecs[:, int(np.argmax(vals))]
    if vx < 0:
        vx, vy = -vx, -vy
    return math.atan2(vy, vx)


def cut_hero(name, manifest, lines):
    rgb = np.asarray(Image.open(SRC / f"{name}_sheet.jpeg").convert("RGB"))
    bg = story_cut.background_mask(rgb)
    cells = [(pose, rgb, keep) for pose, keep in zip(POSES, hero_masks(~bg))]
    idle = cells[0][2]
    scale = UNIT / math.sqrt(idle.sum() / math.pi)
    for pose, sub_rgb, keep in cells:
        if pose in SUBSTITUTE.get(name, {}):
            _, sub_rgb, keep = next(c for c in cells if c[0] == SUBSTITUTE[name][pose])
        ys, xs = np.nonzero(keep)
        x0, y0, x1, y1 = xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5
        pic = story_cut.cut(sub_rgb[y0:y1, x0:x1], ~keep[y0:y1, x0:x1])
        size = (round((x1 - x0) * scale), round((y1 - y0) * scale))
        pic.resize(size, Image.LANCZOS).save(OUT / f"hero_{name}_{pose}.webp", quality=90, method=6)
        cx, cy = (xs.mean() - x0) * scale / UNIT, (ys.mean() - y0) * scale / UNIT
        wr, hr = size[0] / UNIT, size[1] / UNIT
        foot = (ys.max() - ys.mean()) * scale / UNIT
        lines.append(
            f"  '{name}_{pose}': MsHeroFrame(Offset({cx:.3f}, {cy:.3f}), Size({wr:.3f}, {hr:.3f}), foot: {foot:.3f}, tilt: {tilt(keep):.3f}),"
        )
        manifest[f"hero_{name}_{pose}"] = size
    print(f"{name}: {len(POSES)} poses, scale {scale:.3f}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest, lines = {}, []
    for name in HEROES:
        cut_hero(name, manifest, lines)
    FRAMES.write_text(
        "// Made by tools/games/cut_smash_heroes.py: do not edit.\n"
        "import 'dart:ui';\n\n"
        "/// A hero's pose picture, in hero radii: where the ball's middle is (from\n"
        "/// the top left), the picture's size, how far below the middle the feet\n"
        "/// are and which way a long pose points (radians, y down).\n"
        "class MsHeroFrame {\n"
        "  const MsHeroFrame(this.middle, this.size, {required this.foot, required this.tilt});\n"
        "  final Offset middle;\n"
        "  final Size size;\n"
        "  final double foot, tilt;\n"
        "}\n\n"
        "const msHeroFrames = <String, MsHeroFrame>{\n" + "\n".join(lines) + "\n};\n"
    )
    for k, (w, h) in manifest.items():
        print(f"  {k}: {w}x{h}")


if __name__ == "__main__":
    main()
