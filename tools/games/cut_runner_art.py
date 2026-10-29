#!/usr/bin/env python3
"""Cuts the Spell Runner art (design/games/spell-runner/*.jpeg, made in Gemini
in Pencil's style, prompts in design/games/spell-runner-prompts.md) into the
pictures the app uses: app/assets/games/runner/.

The same cutting as the stories and Monster Defense (tools/stories/cut_art.py):

* the road things (2 x 4) and the roadside things (2 x 5): each trimmed
* the two road backgrounds (9:16) and the cover (1:1): resized

Pencil's rider poses, the new road things and Gloop come from the second
set of art: tools/games/cut_runner_v2.py.

    python3 tools/games/cut_runner_art.py      # needs pillow, numpy, scipy
"""

import importlib.util
import json
import pathlib
import tempfile

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "spell-runner"
OUT = ROOT / "app" / "assets" / "games" / "runner"

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)
story_cut.OUT = OUT  # sheet() and props() write there
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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
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
    print(f"{len(list(OUT.iterdir()))} files in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
