"""Resizes scenery and standing characters to their in-game size.
Run: python3 build_props.py props ../art/props"""
import os, sys
from PIL import Image

QUALITY = 2.2  # texture pixels per world pixel, same as the character rigs
HEIGHTS = {"house": 420.0, "hut": 300.0, "boat": 216.0, "merlin": 160.0, "sign": 130.0, "camp": 150.0,
           "fence": 62.0, "bale": 60.0, "log": 40.0, "ring": 170.0, "finish": 250.0}  # world pixels tall

# Long strips that repeat sideways: which rows of the full picture to keep.
# Each is saved next to its mirror image, so the two ends always match up.
BANDS = {"ground": (338, 576), "hills_far": (368, 576), "hills_near": (176, 576)}
# How far each background strip is faded toward the sky colour, so the
# characters stand out in front of it. 0 leaves it alone.
FADE = {"ground": 0.0, "hills_far": 0.45, "hills_near": 0.38}
SKY = (140, 209, 242)

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name, height in HEIGHTS.items():
    img = Image.open(os.path.join(src, name + ".png")).convert("RGBA")
    h = round(height * QUALITY)
    w = round(img.width * h / img.height)
    img.resize((w, h), Image.LANCZOS).save(os.path.join(out, name + ".png"))
    print(name, "world size %.0f x %.0f" % (w / QUALITY, height))

for name, (top, bottom) in BANDS.items():
    full = Image.open(os.path.join(src, name + "_full.png")).convert("RGBA")
    img = full.crop((0, top, full.width, bottom))
    if FADE[name] > 0.0:
        alpha = img.getchannel("A")
        sky = Image.new("RGB", img.size, SKY)
        img = Image.blend(img.convert("RGB"), sky, FADE[name]).convert("RGBA")
        img.putalpha(alpha)
    pair = Image.new("RGBA", (img.width * 2, img.height), (0, 0, 0, 0))
    pair.paste(img, (0, 0))
    pair.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (img.width, 0))
    pair.save(os.path.join(out, name + ".png"))
    print(name, "strip", pair.size)
