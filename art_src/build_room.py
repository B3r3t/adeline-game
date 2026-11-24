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
    "bath_a": ["duck", "cup", "toothbrush", "toothpaste"],
}
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name in ["room", "stable", "bedroom", "bathroom"]:
    Image.open(os.path.join(src, name + "_src.png")).convert("RGB").save(os.path.join(out, name + ".jpg"), quality=90)
# The tooth-brushing close-up: the smile, the plaque that covers it, and a mask saying where
# the teeth are (bright, colourless patches in the middle of the picture).
mouth = Image.open(os.path.join(src, "mouth_src.png")).convert("RGB").resize((900, 600), Image.LANCZOS)
mouth.save(os.path.join(out, "mouth.jpg"), quality=92)
Image.open(os.path.join(src, "plaque_src.png")).convert("RGB").resize((900, 600), Image.LANCZOS).save(os.path.join(out, "plaque.jpg"), quality=90)
rgb = np.array(mouth).astype(np.float32) / 255.0
bright, dull = rgb.max(2), rgb.min(2)
white = ndimage.binary_opening((bright > 0.8) & ((bright - dull) / (bright + 1e-6) < 0.2))
labels, _ = ndimage.label(white)
teeth = np.zeros_like(white)
for i, box in enumerate(ndimage.find_objects(labels)):
    cy, cx = (box[0].start + box[0].stop) / 2, (box[1].start + box[1].stop) / 2
    if (labels[box] == i + 1).sum() > 700 and 120 < cy < 520 and 120 < cx < 780:
        teeth |= labels == i + 1
soft = ndimage.gaussian_filter(teeth.astype(np.float32), 1.2)
Image.fromarray((soft * 255).astype(np.uint8)).resize((450, 300), Image.LANCZOS).save(os.path.join(out, "teeth_mask.png"))
print("teeth found:", ndimage.label(teeth)[1])

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
