"""Cut Pencil's poses out of the Gemini sheets (white background -> alpha)."""
import os, sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "media", "reel", "build", "art")
os.makedirs(OUT, exist_ok=True)

SENT = (255, 0, 255)


def cut(im):
    """Flood-fill the white background from every border pixel, return RGBA."""
    im = im.convert("RGB")
    w, h = im.size
    work = im.copy()
    seeds = []
    for x in range(0, w, 6):
        seeds += [(x, 0), (x, h - 1)]
    for y in range(0, h, 6):
        seeds += [(0, y), (w - 1, y)]
    px = work.load()
    for s in seeds:
        r, g, b = px[s]
        if r > 238 and g > 238 and b > 238:
            ImageDraw.floodfill(work, s, SENT, thresh=22)
    wp = work.load()
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if wp[x, y] == SENT:
                ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            v = ap[x, y]
            ap[x, y] = 0 if v < 110 else (255 if v > 200 else int((v - 110) * 255 / 90))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def trim(im, pad=6):
    bb = im.split()[3].getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad); y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


POSES = {  # name -> (col, row) on the 4x2 expression sheet
    "idle": (0, 0), "wave": (1, 0), "shy": (2, 0), "cheer": (3, 0),
    "thumb": (0, 1), "wow": (1, 1), "run": (2, 1), "sleepy": (3, 1),
}

sheet = Image.open(f"{ROOT}/design/mascot/Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg")
cw, ch = sheet.width // 4, sheet.height // 2
for name, (c, r) in POSES.items():
    cell = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
    img = trim(cut(cell))
    img.save(f"{OUT}/pencil_{name}.png")
    print("pencil_" + name, img.size)

master = Image.open(f"{ROOT}/design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg")
img = trim(cut(master))
img.save(f"{OUT}/pencil_master.png")
print("pencil_master", img.size)
