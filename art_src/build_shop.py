"""Pictures for Merlin's shop, and for Spirit's foal.

    python3 build_shop.py shop ../art

Cuts the drawn sheets in art_src/shop into single pictures:
  wear.webp       hats for the girls and things for the horses' necks -> art/shop
  furniture.webp  furniture that can be bought                        -> art/room
  foal.webp       the foal in each of its poses, and a milk bottle    -> art/foal, art/room
and makes the little pictures the shop shows for each colour of cloak and saddle blanket,
by turning the colour of the real cloak and saddle the same way the game does
(scripts/look.gd), so what is on the card is what she will wear.
"""
import colorsys
import json
import os
import sys

from PIL import Image

SHARP = 2.2  # pictures are kept this many times bigger than they are drawn in the world

# sheet -> columns, then for each cell: name, how wide it is kept, where it goes
WEAR = (3, [["flower_crown", 150], ["tiara", 130], ["cowgirl", 170], ["garland", 200], ["rosette", 200], ["stars", 200]])
FURNITURE = (4, [["aquarium", 300], ["piano", 350], ["fireplace", 350], ["globe", 190], ["dollhouse", 310], ["telescope", 270], ["plush_unicorn", 290], ["star_lights", 380]])
FOAL = (4, [["sleep", 0], ["lie", 0], ["stand", 0], ["walk_1", 0], ["walk_2", 0], ["eat", 0], ["buck", 0], ["bottle", 150]])
FOAL_SCALE = 0.62  # every pose is shrunk by the same amount, so the foal stays one size

# The colours of cloak and blanket. These must match CLOAKS and BLANKETS in scripts/look.gd:
# how far round the colour wheel, how rich, how bright.
COLOURS = {"purple": (0.0, 1.0, 1.0), "red": (0.215, 1.0, 1.18), "green": (-0.375, 0.92, 1.02), "blue": (-0.195, 0.95, 1.22), "pink": (0.145, 0.7, 1.62)}
BLANKET_TURN = -0.045  # the blanket's purple is a little pinker than the cloak's, so it is turned a little less
CLOAK_BAND = (0.70, 0.86)
BLANKET_BAND = (0.76, 0.93)


def solid(img):
    return img.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()


def alone(cell):
    """A cell of a sheet with only its own drawing left in it. A neighbour that leans over
    the line leaves a sliver at the edge; anything small that touches the edge is rubbed out."""
    import numpy as np
    from scipy import ndimage
    data = np.array(cell)
    marks, count = ndimage.label(data[:, :, 3] > 24)
    if count > 1:
        sizes = ndimage.sum(np.ones_like(marks), marks, range(1, count + 1))
        biggest = sizes.max()
        for i in range(1, count + 1):
            where = marks == i
            at_edge = where[0, :].any() or where[-1, :].any() or where[:, 0].any() or where[:, -1].any()
            if sizes[i - 1] < biggest * (0.25 if at_edge else 0.002):
                data[where] = 0
    cell = Image.fromarray(data)
    return cell.crop(solid(cell))


def cells(sheet, cols, count):
    rows = (count + cols - 1) // cols
    cw, ch = sheet.width / cols, sheet.height / rows
    for i in range(count):
        yield sheet.crop((round((i % cols) * cw), round((i // cols) * ch), round((i % cols + 1) * cw), round((i // cols + 1) * ch)))


def smooth(edge0, edge1, x):
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def recolour(img, band, turn, rich, bright):
    """The same sum as the shader in look.gd, done here once for the shop's pictures."""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            pick = smooth(band[0], band[0] + 0.03, h) * (1.0 - smooth(band[1] - 0.03, band[1], h)) * smooth(0.18, 0.3, s) * smooth(0.1, 0.2, v)
            if pick <= 0.0:
                continue
            nr, ng, nb = colorsys.hsv_to_rgb((h + turn) % 1.0, min(s * rich, 1.0), min(v * bright, 1.0))
            px[x, y] = (round(r + (nr * 255 - r) * pick), round(g + (ng * 255 - g) * pick), round(b + (nb * 255 - b) * pick), a)
    return img


def keep(img, wide, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    w = min(wide, img.width)
    img.resize((w, max(1, round(img.height * w / img.width))), Image.LANCZOS).save(path, optimize=True)


src, art = sys.argv[1], sys.argv[2]
made = 0
sheet = Image.open(os.path.join(src, "wear.webp")).convert("RGBA")
for cell, (name, wide) in zip(cells(sheet, WEAR[0], len(WEAR[1])), WEAR[1]):
    keep(alone(cell), round(wide * SHARP), os.path.join(art, "shop", name + ".png"))
    made += 1
sheet = Image.open(os.path.join(src, "furniture.webp")).convert("RGBA")
for cell, (name, wide) in zip(cells(sheet, FURNITURE[0], len(FURNITURE[1])), FURNITURE[1]):
    keep(alone(cell), wide, os.path.join(art, "room", name + ".png"))
    made += 1
sheet = Image.open(os.path.join(src, "foal.webp")).convert("RGBA")
for cell, (name, wide) in zip(cells(sheet, FOAL[0], len(FOAL[1])), FOAL[1]):
    piece = alone(cell)
    if name == "bottle":
        keep(piece, wide, os.path.join(art, "room", "bottle.png"))
    else:
        keep(piece, round(piece.width * FOAL_SCALE), os.path.join(art, "foal", name + ".png"))
    made += 1

# The cloak and the saddle in each colour, for the cards in the shop.
cloak = Image.open(os.path.join(art, "adeline", "cloak_back.png")).convert("RGBA")
hood = Image.open(os.path.join(art, "adeline", "hood.png")).convert("RGBA")
both = Image.new("RGBA", (cloak.width + 10, cloak.height + 34), (0, 0, 0, 0))
both.alpha_composite(cloak, (0, 34))
both.alpha_composite(hood, (cloak.width - hood.width + 2, 0))
saddle = Image.open(os.path.join(art, "spirit", "saddle.png")).convert("RGBA")
saddle = saddle.crop(solid(saddle))
for name, (turn, rich, bright) in COLOURS.items():
    recolour(both, CLOAK_BAND, turn, rich, bright).save(os.path.join(art, "shop", "cloak_%s.png" % name), optimize=True)
    recolour(saddle, BLANKET_BAND, turn + (BLANKET_TURN if turn != 0.0 else 0.0), rich, bright).save(os.path.join(art, "shop", "blanket_%s.png" % name), optimize=True)
    made += 2
print(made, "pictures made")
