"""Cuts the indoor art into game files: three backgrounds, the furniture and the horse-care items.
Run: python3 build_room.py room ../art/room"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SHEETS = {
    "furn_a": ["sofa", "armchair", "rug", "bookshelf", "lamp", "table"],
    "furn_b": ["plant", "painting", "clock", "flowers", "rocking_horse", "cushion"],
    "care": ["apple", "carrot", "brush", "hay", "heart", "oats"],
    "bed_a": ["bed", "wardrobe", "nightstand", "mirror", "desk", "chest"],
    "bed_b": ["heart_rug", "bedside_lamp", "teddy", "toy_horse", "poster", "bunting"],
}
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name in ["room", "stable", "bedroom"]:
    Image.open(os.path.join(src, name + "_src.png")).convert("RGB").save(os.path.join(out, name + ".jpg"), quality=90)
for sheet, names in SHEETS.items():
    im = Image.open(os.path.join(src, sheet + ".png")).convert("RGBA")
    pixels = np.array(im)
    mask = ndimage.binary_closing(pixels[:, :, 3] > 40, iterations=2)
    labels, _ = ndimage.label(mask)
    found = []
    for i, box in enumerate(ndimage.find_objects(labels)):
        if (labels[box] == i + 1).sum() >= 600:
            found.append((box, i + 1))
    # Read the sheet like a page: top row first, left to right.
    found.sort(key=lambda f: (f[0][0].start // 150, f[0][1].start))
    assert len(found) == len(names), (sheet, len(found))
    for (box, label), name in zip(found, names):
        piece = pixels[box].copy()
        piece[labels[box] != label] = 0
        Image.fromarray(piece).save(os.path.join(out, name + ".png"))
        print(name, piece.shape[1], "x", piece.shape[0])
