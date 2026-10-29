#!/usr/bin/env python3
"""Cuts Spell Runner's second set of art (design/games/spell-runner/v2/, made
in Gemini, prompts in design/games/spell-runner-v2-prompts.md) into the
pictures the app uses: app/assets/games/runner/.

* the rider sheet (rows of 4, 4 and 3 poses): push, ride, carve_left,
  carve_right, crouch, jump, slide, trick, stumble, land, cheer. Every pose
  in one frame size, at one scale, the board's wheels in the middle of the
  frame (so turning or jumping never shifts him sideways).
* the new road things (2 x 3): barrier, banner, branch (high: he slides
  under them), cart (it fills a lane), bench, flowerbox (he jumps them).
* Gloop chasing, from behind (3 poses): hop, land, reach; one frame.
* where the wheels are in each rider pose, and how high the open gap under
  each high thing is (sr_v2_boxes.dart).

The sheets are not on a grid, so each thing is found by its shape. The white
and the grey shadows go (tools/stories/cut_art.py), loose strokes beside a
pose (motion marks) are left out, and the white closed in between Pencil's
legs and the board is cleared.

    python3 tools/games/cut_runner_v2.py      # needs pillow, numpy, scipy
"""

import importlib.util
import pathlib

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SRC = ROOT / "design" / "games" / "spell-runner" / "v2"
OUT = ROOT / "app" / "assets" / "games" / "runner"
BOXES = ROOT / "app" / "lib" / "screens" / "games" / "spell_runner" / "sr_v2_boxes.dart"

_spec = importlib.util.spec_from_file_location("story_cut", ROOT / "tools" / "stories" / "cut_art.py")
story_cut = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(story_cut)

WORK = 2752  # px: the sheets are brought to this width first (the shape finder's scale)
RIDER = ["push", "ride", "carve_left", "carve_right", "crouch", "jump", "slide", "trick", "stumble", "land", "cheer"]
PROPS = ["barrier", "banner", "branch", "cart", "bench", "flowerbox"]
HIGH = {"barrier", "banner", "branch"}
GLOOP = ["hop", "land", "reach"]
RIDER_HEIGHT = 600  # px of the frame (Pencil is at most ~240 dp tall on a 3x phone, ~720 px)
GLOOP_HEIGHT = 520
PROP_SIDE = 600


def load(name):
    img = Image.open(SRC / name).convert("RGB")
    img = img.resize((WORK, round(img.height * WORK / img.width)), Image.LANCZOS)
    # the sheets are small: a little sharpening after the upscale
    img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    return np.asarray(img)


def find(rgb, n, rows):
    """The [n] things on a sheet, in reading order ([rows] rows): each the
    mask of its biggest shape and the parts touching it."""
    bg = story_cut.background_mask(rgb)
    fg = ~bg
    groups, count = ndimage.label(ndimage.binary_dilation(fg, iterations=12))
    sizes = ndimage.sum(fg, groups, range(1, count + 1))
    keep = [int(k) + 1 for k in np.argsort(sizes)[::-1][:n]]
    h = rgb.shape[0]
    found = []
    labels, _ = ndimage.label(fg)
    for g in keep:
        inside = fg & (groups == g)
        ys, xs = np.nonzero(inside)
        found.append(((ys.mean() // (h / rows), xs.mean()), inside))
    found.sort(key=lambda e: e[0])
    masks = []
    for _, inside in found:
        lab = np.where(inside, labels, 0)
        ids, counts = np.unique(lab[lab > 0], return_counts=True)
        body = lab == ids[np.argmax(counts)]
        near = ndimage.binary_dilation(body, iterations=10)
        mask = body.copy()
        for k, c in zip(ids, counts):
            if c > 600 and (near & (lab == k)).any():
                mask |= lab == k
        masks.append(mask)
    return masks


def clear_gaps(rgb, mask):
    """White closed in by Pencil (between his legs and the board) in the
    lower part: background too. Shines (ringed by grey or blue) stay."""
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    white = mask & (r > 232) & (g > 232) & (b > 232)
    lab, n = ndimage.label(white)
    ys, _ = np.nonzero(mask)
    top, bottom = ys.min(), ys.max()
    out = mask.copy()
    for k in range(1, n + 1):
        part = lab == k
        py, _ = np.nonzero(part)
        if len(py) < 150 or (py.mean() - top) / (bottom - top) < .45:
            continue
        ring = ndimage.binary_dilation(part, iterations=3) & ~part & mask
        if (b[ring] - r[ring]).mean() < 5:  # yellow around it: a gap
            out &= ~part
    return out


def crop(rgb, mask):
    ys, xs = np.nonzero(mask)
    x0, y0, x1, y1 = xs.min() - 6, ys.min() - 6, xs.max() + 7, ys.max() + 7
    pic = story_cut.cut(rgb[y0:y1, x0:x1], ~mask[y0:y1, x0:x1])
    return pic, (x0, y0)


def wheels_x(pic):
    """The middle of the orange wheels (the lowest orange in the picture)."""
    a = np.asarray(pic).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    orange = (al > 200) & (r > 200) & (g > 80) & (g < 170) & (b < 90)
    ys, xs = np.nonzero(orange)
    if len(xs) == 0:
        return pic.width / 2, pic.height
    low = ys > np.percentile(ys, 40)
    return xs[low].mean(), ys.max()


def framed(pics, height, anchor_of):
    """Every picture in one frame, its anchor (x, bottom) on the frame's
    middle and bottom line, all scaled alike to [height]."""
    anchors = [anchor_of(p) for p in pics]
    left = max(ax for (ax, _), _ in zip(anchors, pics))
    right = max(p.width - ax for (ax, _), p in zip(anchors, pics))
    half = max(left, right)
    up = max(ay for _, ay in anchors)
    down = max(p.height - ay for (_, ay), p in zip(anchors, pics))
    w, h = round(half * 2), round(up + down)
    scale = height / h
    out = []
    for p, (ax, ay) in zip(pics, anchors):
        frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        frame.paste(p, (round(half - ax), round(up - ay)), p)
        out.append(frame.resize((round(w * scale), height), Image.LANCZOS))
    return out, up / h


def gap(pic):
    """How high the open space under a high thing is: in its middle, from
    the bottom up to the first solid row (a fraction of its height)."""
    a = np.asarray(pic)[..., 3]
    h, w = a.shape
    mid = a[:, int(w * .35):int(w * .65)]
    solid = (mid > 120).mean(axis=1) > .5
    rows = np.nonzero(solid)[0]
    return (h - rows.max()) / h if len(rows) else 0.0


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lines = []
    # the rider
    rgb = load("rider_sheet.png")
    pics = [crop(rgb, clear_gaps(rgb, m))[0] for m in find(rgb, len(RIDER), 3)]
    frames, foot = framed(pics, RIDER_HEIGHT, wheels_x)
    for name, f in zip(RIDER, frames):
        f.save(OUT / f"rider_{name}.webp", quality=90, method=6)
    lines.append(f"/// The wheels' line in every rider picture (the wheels are in its middle).\nconst srRiderFoot = {foot:.3f};\n")
    # how tall he is when he slides (high things leave more room than this)
    slide = np.asarray(frames[RIDER.index("slide")])[..., 3]
    top = np.nonzero((slide > 60).any(axis=1))[0].min() / slide.shape[0]
    lines.append(f"/// The top of Pencil in the slide picture (a fraction of its height).\nconst srSlideTop = {top:.3f};\n")
    # the road things
    rgb = load("props_road_v2.png")
    gaps = {}
    for name, m in zip(PROPS, find(rgb, len(PROPS), 2)):
        pic, _ = crop(rgb, m)
        pic.thumbnail((PROP_SIDE, PROP_SIDE), Image.LANCZOS) if max(pic.size) > PROP_SIDE else None
        pic.save(OUT / f"{name}.webp", quality=90, method=6)
        if name in HIGH:
            gaps[name] = gap(pic)
    lines.append(
        "/// How high the open space under each high thing is (a fraction of its\n/// picture's height).\nconst srGaps = <String, double>{\n"
        + "\n".join(f"  '{k}': {v:.3f}," for k, v in gaps.items())
        + "\n};\n"
    )
    # Gloop, from behind
    rgb = load("gloop_chase.png")
    pics = [crop(rgb, m)[0] for m in find(rgb, len(GLOOP), 1)]
    frames, gfoot = framed(pics, GLOOP_HEIGHT, lambda p: (p.width / 2, p.height))
    for name, f in zip(GLOOP, frames):
        f.save(OUT / f"gloop_{name}.webp", quality=90, method=6)
    lines.append(f"/// Gloop's feet line in its chase pictures.\nconst srGloopFoot = {gfoot:.3f};\n")
    BOXES.write_text("// Made by tools/games/cut_runner_v2.py: do not edit.\n\n" + "\n".join(lines))
    print(BOXES.read_text())


if __name__ == "__main__":
    main()
