"""Drop the flat grey ground shadow that sits under each pose."""
import glob, os
from PIL import Image

for f in sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "media", "reel", "build", "art", "pencil_*.png"))):
    im = Image.open(f).convert("RGBA")
    w, h = im.size
    px = im.load()
    start = int(h * 0.72)
    n = 0
    for y in range(start, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            if mx - mn < 16 and mx > 198:
                px[x, y] = (r, g, b, 0)
                n += 1
    bb = im.split()[3].getbbox()
    if bb:
        im = im.crop(bb)
    im.save(f)
    print(os.path.basename(f), im.size, "shadow px", n)
