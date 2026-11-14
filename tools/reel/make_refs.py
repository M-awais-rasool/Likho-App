"""Build Pencil reference images for AI video tools (cream square + transparent PNG)."""
import os, glob
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ART  = f"{ROOT}/media/reel/build/art"
OUT  = f"{ROOT}/media/reel/ref"
CUT  = f"{OUT}/transparent"
os.makedirs(OUT, exist_ok=True)
os.makedirs(CUT, exist_ok=True)

CREAM = (255, 248, 236, 255)
SIZE  = 1024
TARGET_H = 780          # character height on the canvas
BASELINE = 940          # where the feet sit

for f in sorted(glob.glob(f"{ART}/pencil_*.png")):
    name = os.path.basename(f)
    im = Image.open(f).convert("RGBA")
    # upscale to target height
    s = TARGET_H / im.height
    big = im.resize((max(1, round(im.width * s)), TARGET_H), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=3))

    canvas = Image.new("RGBA", (SIZE, SIZE), CREAM)
    canvas.alpha_composite(big, ((SIZE - big.width) // 2, BASELINE - big.height))
    canvas.convert("RGB").save(f"{OUT}/{name.replace('.png', '.jpg')}", quality=94)
    big.save(f"{CUT}/{name}")
    print(name, "->", big.size)
