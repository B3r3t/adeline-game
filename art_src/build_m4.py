"""Pictures for Mission 4, "The Littlest Hero".

    python3 build_m4.py m4 ../art

Two painted scenes (the burrow tunnel and the chief's den) are fitted to the size every
farm-game scene has, and two drawn sheets are cut into single pictures, all into art/mini:
  goblins.webp  the sentry asleep, yawning, looking and shouting
  chief.webp    the chief asleep in his armchair, and stirring
  props.webp    four things to hide behind, the key, the padlock, the spell book and a medal
The pictures are kept at the size they were drawn. The game draws each kind at its own
scale (the constants at the top of scripts/mini_sneak.gd and scripts/mini_key.gd).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SCENE = (1344, 752)
GOBLINS = (3, ["sentry_sleep", "sentry_yawn", "sentry_look", "sentry_shout"])
CHIEF = (2, ["chief_sleep", "chief_stir"])  # drawn again without the key on his belt, which is a thing of its own
PROPS = (4, ["hide_mushrooms", "hide_barrels", "hide_sacks", "hide_rock", "key", "padlock", "spellbook", "medal"])


def solid(img):
    return img.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()


def alone(cell, least=0.002):
    """A cell of a sheet with only its own drawing left in it: a neighbour that leans over
    the line leaves a sliver at the edge, and anything small touching the edge is rubbed out."""
    data = np.array(cell)
    marks, count = ndimage.label(data[:, :, 3] > 24)
    if count > 1:
        sizes = ndimage.sum(np.ones_like(marks), marks, range(1, count + 1))
        biggest = sizes.max()
        for i in range(1, count + 1):
            where = marks == i
            at_edge = where[0, :].any() or where[-1, :].any() or where[:, 0].any() or where[:, -1].any()
            if sizes[i - 1] < biggest * (0.25 if at_edge else least):
                data[where] = 0
    cell = Image.fromarray(data)
    return cell.crop(solid(cell))


def cells(sheet, cols, count):
    rows = (count + cols - 1) // cols
    cw, ch = sheet.width / cols, sheet.height / rows
    for i in range(count):
        yield sheet.crop((round((i % cols) * cw), round((i // cols) * ch), round((i % cols + 1) * cw), round((i // cols + 1) * ch)))


src, art = sys.argv[1], sys.argv[2]
out = os.path.join(art, "mini")
made = 0
for name in ["burrow", "den"]:
    img = Image.open(os.path.join(src, name + ".jpg")).convert("RGB")
    tall = round(img.height * SCENE[0] / img.width)
    img = img.resize((SCENE[0], tall), Image.LANCZOS)
    top = (tall - SCENE[1]) // 2
    img.crop((0, top, SCENE[0], top + SCENE[1])).save(os.path.join(out, name + ".jpg"), quality=90)
    made += 1
for file, (cols, names) in [("goblins.webp", GOBLINS), ("chief.webp", CHIEF), ("props.webp", PROPS)]:
    sheet = Image.open(os.path.join(src, file)).convert("RGBA")
    for cell, name in zip(cells(sheet, cols, len(names)), names):
        piece = alone(cell, 0.03 if name.startswith("chief") else 0.002)
        if name.startswith("chief"):  # drawn on a bigger sheet than the rest: brought down to match
            piece = piece.resize((piece.width // 2, piece.height // 2), Image.LANCZOS)
        piece.save(os.path.join(out, name + ".png"), optimize=True)
        made += 1
print(made, "pictures made")
