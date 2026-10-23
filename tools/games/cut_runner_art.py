#!/usr/bin/env python3
"""Cuts the Spell Runner art (design/games/spell-runner/*.jpeg, made in Gemini
in Pencil's style, prompts in design/games/spell-runner-prompts.md) into the
pictures the app uses: app/assets/games/runner/.

The same cutting as the stories and Monster Defense (tools/stories/cut_art.py):

* Pencil's skateboard sheet (2 rows x 3 poses): ride, lean_left, lean_right,
  jump, wobble, cheer; all the same size, the board on the same line
* the road things (2 x 4) and the roadside things (2 x 5): each trimmed
* the two road backgrounds (9:16) and the cover (1:1): resized
* where Pencil is in each pose picture, for the app (sr_art_boxes.dart)

    python3 tools/games/cut_runner_art.py      # needs pillow, numpy, scipy
"""

import importlib.util
import json
import pathlib
import tempfile

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "spell-runner"
OUT = ROOT / "app" / "assets" / "games" / "runner"
BOXES = ROOT / "app" / "lib" / "screens" / "games" / "spell_runner" / "sr_art_boxes.dart"

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)
story_cut.OUT = OUT  # sheet() and props() write there
story_cut.POSE_HEIGHT = 520  # Pencil is at most ~260 dp tall

POSES = ["ride", "lean_right", "lean_left", "jump", "wobble", "cheer"]  # the sheet leans right first
ROAD = ("props_road.jpeg", 2, 4, ["puddle", "log", "rock", "hay", "ramp", "cone", "banana", "finish"], {"finish"})
ROADSIDE = ("props_roadside.jpeg", 2, 5, ["tree", "pine", "bush", "flowers", "sunflower", "fence", "lamp", "mushrooms", "signpost", "apple_tree"], {"fence"})
BACKGROUNDS = ["bg_road_day.jpeg", "bg_road_sunset.jpeg"]
COVER = ("cover_spell_runner.jpeg", 720)


def things(sheet, manifest):
    """A sheet of things, brought to the size the shape finder expects."""
    f, rows, cols, names, holes = sheet
    with tempfile.TemporaryDirectory() as tmp:
        img = Image.open(SRC / f).convert("RGB")
        big = pathlib.Path(tmp) / f
        img.resize((2752, round(img.height * 2752 / img.width)), Image.LANCZOS).save(big, quality=95)
        story_cut.props(big, rows, cols, names, manifest, holes)


def clear_gaps():
    """The paper closed in between Pencil's legs and the board (and his arms
    and body when he jumps) is background too: white patches ringed by his
    yellow below his face. The metal band's shine (ringed by grey-blue) and
    small eye shines stay."""
    for pose in POSES:
        path = OUT / f"pencil_{pose}.webp"
        im = np.asarray(Image.open(path).convert("RGBA")).astype(int)
        r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
        white = (a > 200) & (r > 232) & (g > 232) & (b > 232)
        lab, n = ndimage.label(white)
        h = a.shape[0]
        gone = np.zeros_like(white)
        for k in range(1, n + 1):
            part = lab == k
            ys, xs = np.nonzero(part)
            if len(xs) < 100 or ys.mean() / h < .35:
                continue
            ring = ndimage.binary_dilation(part, iterations=3) & ~part & (a > 200)
            if (b[ring] - r[ring]).mean() < 5:  # yellow around it: a gap
                gone |= part
        if not gone.any():
            continue
        # soften the cut edge like the outside one
        gone = ndimage.binary_dilation(gone, iterations=1)
        alpha = np.asarray(Image.fromarray(np.where(gone, 0, a).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.6)), dtype=int)
        out = im.copy()
        out[..., 3] = np.minimum(a, np.where(gone | ndimage.binary_dilation(gone, iterations=2), alpha, a))
        Image.fromarray(out.astype(np.uint8), "RGBA").save(path, quality=90, method=6)


def content_boxes():
    """Where Pencil is in each pose picture (the poses share a frame)."""
    lines = []
    for pose in POSES:
        img = Image.open(OUT / f"pencil_{pose}.webp").convert("RGBA")
        a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
        x0, y0, x1, y1 = a.getbbox()
        w, h = img.size
        lines.append(f"  'pencil_{pose}': Rect.fromLTRB({x0 / w:.3f}, {y0 / h:.3f}, {x1 / w:.3f}, {y1 / h:.3f}),")
    BOXES.parent.mkdir(parents=True, exist_ok=True)
    BOXES.write_text(
        "// Made by tools/games/cut_runner_art.py: do not edit.\n"
        "import 'dart:ui';\n\n"
        "/// Where Pencil is in each pose picture (fractions of the picture).\n"
        "const srArtBoxes = <String, Rect>{\n" + "\n".join(lines) + "\n};\n"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    story_cut.sheet(SRC / "pencil_skate_sheet.jpeg", "pencil", 2, 3, POSES, manifest)
    clear_gaps()
    things(ROAD, manifest)
    things(ROADSIDE, manifest)
    for f in BACKGROUNDS:
        img = Image.open(SRC / f).convert("RGB")
        img = img.resize((story_cut.BG_WIDTH, round(img.height * story_cut.BG_WIDTH / img.width)), Image.LANCZOS)
        name = f.replace(".jpeg", "")
        img.save(OUT / f"{name}.webp", quality=86, method=6)
        manifest[name] = {"size": img.size}
    f, side = COVER
    img = Image.open(SRC / f).convert("RGB").resize((side, side), Image.LANCZOS)
    img.save(OUT / "cover.webp", quality=86, method=6)
    manifest["cover"] = {"size": img.size}
    (OUT / "art.json").write_text(json.dumps(manifest, indent=1) + "\n")
    content_boxes()
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
