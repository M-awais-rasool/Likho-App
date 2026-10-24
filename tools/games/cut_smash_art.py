#!/usr/bin/env python3
"""Cuts the Monster Smash art (design/games/monster-smash/*.jpeg, made in
Gemini in Pencil's style, prompts in design/games/monster-smash-prompts.md)
into the pictures the app uses: app/assets/games/smash/.

The same cutting as the stories and the other games (tools/stories/cut_art.py):

* Pencil seen from the side: the master (stand) and the sheet (2 rows x 3
  poses): ready, pull, throw, cheer, oops, point
* the slingshot sheet (2 x 3) and the blocks sheet (3 x 3): each trimmed
* the three wide backgrounds: resized
* where Pencil is in each pose picture, for the app (ms_art_boxes.dart)

The monsters on the towers are Monster Defense's (assets/games/monsters).

    python3 tools/games/cut_smash_art.py      # needs pillow, numpy, scipy
"""

import importlib.util
import json
import pathlib
import tempfile

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "monster-smash"
OUT = ROOT / "app" / "assets" / "games" / "smash"
BOXES = ROOT / "app" / "lib" / "screens" / "games" / "monster_smash" / "ms_art_boxes.dart"

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)
story_cut.OUT = OUT  # sheet() and props() write there
story_cut.POSE_HEIGHT = 440  # Pencil is at most ~200 dp tall here
story_cut.PROP_SIDE = 600  # a plank spans a third of the screen

POSES = ["ready", "pull", "throw", "cheer", "oops", "point"]
SLING = ("props_sling.jpeg", 2, 3, ["sling", "hill", "sign", "ball_eraser", "ball_water", "ball_star"], set())
BLOCKS = (
    "props_blocks.jpeg",
    3,
    3,
    ["wood_square", "wood_plank", "wood_triangle", "ice_square", "ice_plank", "ice_triangle", "stone_square", "stone_plank", "stone_disc"],
    set(),
)
BACKGROUNDS = ["bg_meadow.jpeg", "bg_beach.jpeg", "bg_snow.jpeg"]
BG_WIDTH = 1920  # landscape: the picture spans the phone's long side


def things(sheet, manifest):
    """A sheet of things, brought to the size the shape finder expects."""
    f, rows, cols, names, holes = sheet
    with tempfile.TemporaryDirectory() as tmp:
        img = Image.open(SRC / f).convert("RGB")
        big = pathlib.Path(tmp) / f
        img.resize((2752, round(img.height * 2752 / img.width)), Image.LANCZOS).save(big, quality=95)
        story_cut.props(big, rows, cols, names, manifest, holes)


def content_boxes():
    """Where Pencil is in each pose picture, and where he stands: the x of
    his dark pencil tip and the line of his feet (when he jumps for joy,
    the line of the poses beside him on the sheet)."""
    lines, feet = [], []
    for pose in ["stand"] + POSES:
        im = np.asarray(Image.open(OUT / f"pencil_{pose}.webp").convert("RGBA")).astype(int)
        h, w = im.shape[:2]
        solid = im[..., 3] > 40
        ys, xs = np.nonzero(solid)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        lines.append(f"  'pencil_{pose}': Rect.fromLTRB({x0 / w:.3f}, {y0 / h:.3f}, {x1 / w:.3f}, {y1 / h:.3f}),")
        tip = (im[..., 3] > 200) & (im[..., :3].max(axis=2) < 90)
        tip[: int(y0 + (y1 - y0) * .6)] = False
        tx = np.nonzero(tip)[1].mean() / w
        feet.append((pose, tx, y1 / h))
    ground = {p: y for p, _, y in feet}
    ground["cheer"] = ground["oops"]  # he jumps: his row's feet line
    BOXES.parent.mkdir(parents=True, exist_ok=True)
    BOXES.write_text(
        "// Made by tools/games/cut_smash_art.py: do not edit.\n"
        "import 'dart:ui';\n\n"
        "/// Where Pencil is in each pose picture (fractions of the picture).\n"
        "const msArtBoxes = <String, Rect>{\n" + "\n".join(lines) + "\n};\n\n"
        "/// Where he stands in each pose picture: his pencil tip's x and the\n"
        "/// ground line (fractions of the picture).\n"
        "const msPencilFeet = <String, Offset>{\n"
        + "\n".join(f"  'pencil_{p}': Offset({x:.3f}, {ground[p]:.3f})," for p, x, _ in feet)
        + "\n};\n"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    story_cut.sheet(SRC / "pencil_side_master.jpeg", "pencil", 1, 1, ["stand"], manifest)
    stand = manifest.pop("pencil")
    story_cut.sheet(SRC / "pencil_side_sheet.jpeg", "pencil", 2, 3, POSES, manifest)
    manifest["pencil_stand"] = {"size": stand["size"]}
    things(SLING, manifest)
    things(BLOCKS, manifest)
    for f in BACKGROUNDS:
        img = Image.open(SRC / f).convert("RGB")
        img = img.resize((BG_WIDTH, round(img.height * BG_WIDTH / img.width)), Image.LANCZOS)
        name = f.replace(".jpeg", "")
        img.save(OUT / f"{name}.webp", quality=86, method=6)
        manifest[name] = {"size": img.size}
    (OUT / "art.json").write_text(json.dumps(manifest, indent=1) + "\n")
    content_boxes()
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
