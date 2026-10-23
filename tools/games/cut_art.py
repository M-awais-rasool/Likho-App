#!/usr/bin/env python3
"""Cuts the Monster Defense art (design/games/monster-defense/*.jpeg, made in
Gemini in Pencil's style, prompts in design/games/monster-defense-prompts.md)
into the pictures the app uses: app/assets/games/monsters/.

The same cutting as the stories (tools/stories/cut_art.py, reused here):

* monster pose sheets (2 rows x 3 poses): every pose on a transparent
  background, all poses of a monster the same size with their feet on the
  same line, so the game swaps poses without a jump. The poses are named
  the same for every monster: walk_a, walk_b, roar, bonked, surprised,
  friendly
* monster masters: `<monster>_idle`, trimmed (results and the Games card)
* the things sheet (2 rows x 5): each thing trimmed
* backgrounds (9:16) and the cover (1:1): resized
* the pictures of the words its questions use (app/assets/games/monster_words.json),
  from the course's pictures (media/pictures, made by tools/illustrations), into
  app/assets/games/words/: the game plays offline

    python3 tools/games/cut_art.py            # needs pillow, numpy, scipy
"""

import importlib.util
import json
import pathlib
import tempfile

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "monster-defense"
OUT = ROOT / "app" / "assets" / "games" / "monsters"
WORDS = ROOT / "app" / "assets" / "games" / "monster_words.json"
WORD_OUT = ROOT / "app" / "assets" / "games" / "words"
PICTURES = ROOT / "media" / "pictures"
WORD_SIDE = 220  # px; a picture shows at most ~110 dp

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)
story_cut.OUT = OUT  # sheet() and props() write there
story_cut.POSE_HEIGHT = 420  # a monster is at most ~200 dp tall on the path

POSES = ["walk_a", "walk_b", "roar", "bonked", "surprised", "friendly"]
MONSTERS = ["gloop", "fuzz", "bonk", "boo"]
PROPS = ("props_game.jpeg", 2, 5, ["wand", "heart", "star", "ice", "potion", "chest", "chest_open", "trophy", "sign", "books"], {"trophy"})
BACKGROUNDS = ["bg_path_day.jpeg", "bg_path_sunset.jpeg"]
COVER = ("cover_monster_defense.jpeg", 720)
BOXES = ROOT / "app" / "lib" / "screens" / "games" / "monster_defense" / "md_art_boxes.dart"
MASTER_HEIGHT = 360


def master(name, manifest):
    """The monster standing, on its own (cut and trimmed)."""
    rgb = story_cut.np.asarray(Image.open(SRC / f"{name}_master.jpeg").convert("RGB"))
    thing = story_cut.cut(rgb, story_cut.background_mask(rgb))
    thing = thing.crop(thing.getbbox())
    thing = thing.resize((round(thing.width * MASTER_HEIGHT / thing.height), MASTER_HEIGHT), Image.LANCZOS)
    thing.save(OUT / f"{name}_idle.webp", quality=90, method=6)
    manifest[f"{name}_idle"] = {"size": thing.size}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for m in MONSTERS:
        story_cut.sheet(SRC / f"{m}_sheet.jpeg", m, 2, 3, POSES, manifest)
        master(m, manifest)
    f, rows, cols, names, holes = PROPS
    with tempfile.TemporaryDirectory() as tmp:
        # the things sheet came out small (1376 px): at the size of the other
        # sheets the things keep apart when they are found by their shape
        img = Image.open(SRC / f).convert("RGB")
        big = pathlib.Path(tmp) / f
        img.resize((2752, round(img.height * 2752 / img.width)), Image.LANCZOS).save(big, quality=95)
        story_cut.props(big, rows, cols, names, manifest, holes)
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
    content_boxes()
    word_pictures()


def content_boxes():
    """Where the monster is inside each pose picture (the pictures share a
    frame, so a pose can sit off-centre in it): the app puts the sign over
    the head, aims the magic and takes taps there."""
    lines = []
    for m in MONSTERS:
        for pose in POSES:
            img = Image.open(OUT / f"{m}_{pose}.webp").convert("RGBA")
            a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
            x0, y0, x1, y1 = a.getbbox()
            w, h = img.size
            lines.append(f"    '{m}_{pose}': Rect.fromLTRB({x0 / w:.3f}, {y0 / h:.3f}, {x1 / w:.3f}, {y1 / h:.3f}),")
    BOXES.write_text(
        "// Made by tools/games/cut_art.py: do not edit.\n"
        "import 'dart:ui';\n\n"
        "/// Where the monster is in each pose picture (fractions of the picture).\n"
        "const mdArtBoxes = <String, Rect>{\n" + "\n".join(lines) + "\n};\n"
    )
    print(f"{len(lines)} content boxes in {BOXES.relative_to(ROOT)}")


def word_pictures():
    words = json.loads(WORDS.read_text())
    keep = sorted(set(words["first"]) | set(words["read"]) | set(words.get("long", [])))
    WORD_OUT.mkdir(parents=True, exist_ok=True)
    for old in WORD_OUT.glob("*.webp"):
        if old.stem not in keep:
            old.unlink()
    for w in keep:
        img = Image.open(PICTURES / f"{w}.png").convert("RGBA")
        img.thumbnail((WORD_SIDE, WORD_SIDE), Image.LANCZOS)
        img.save(WORD_OUT / f"{w}.webp", quality=88, method=6)
    print(f"{len(keep)} word pictures in {WORD_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
