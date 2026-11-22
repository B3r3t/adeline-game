"""Resizes scenery and standing characters to their in-game size.
Run: python3 build_props.py props ../art/props"""
import os, sys
from PIL import Image

QUALITY = 2.2  # texture pixels per world pixel, same as the character rigs
HEIGHTS = {"house": 420.0, "hut": 300.0, "boat": 216.0, "merlin": 160.0}  # world pixels tall

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name, height in HEIGHTS.items():
    img = Image.open(os.path.join(src, name + ".png")).convert("RGBA")
    h = round(height * QUALITY)
    w = round(img.width * h / img.height)
    img.resize((w, h), Image.LANCZOS).save(os.path.join(out, name + ".png"))
    print(name, "world size %.0f x %.0f" % (w / QUALITY, height))
