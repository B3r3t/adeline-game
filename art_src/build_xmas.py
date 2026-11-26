"""The Christmas pictures. From 1 December to 1 January the game uses a winter version of
any picture that has one; this script makes them all, into `art/xmas`, each at the same
place under it as the picture it stands in for and exactly the same size.

Run: python3 build_xmas.py xmas ../art

Three kinds of thing are made:
- Redrawn pictures. The house, Merlin's hut, the rooms, the title painting and so on were
  redrawn for winter by an image generator shown the originals. Whole scenes are simply
  resized to match. Loose objects were redrawn a sheet at a time, in a grid; each is cut
  from its cell and stood where the original stood, at the original's width.
- Recoloured pictures. The ground and the hills are the summer ones with their green
  turned to snow (`snowify`).
- New things, which have no summer original: hats, the tree, the nativity, robins,
  Christmas dinner. These go to `art/xmas/extra` (and the food to `art/room/kitchen`)
  at the sizes listed here."""
import json, os, sys
import numpy as np
from PIL import Image

SHARP = 1.7  # pixels kept for each pixel a new thing is drawn at

# Whole scenes: source file -> the picture it replaces.
SCENES = {
    "title.jpg": "ui/title.jpg", "sky_back.jpg": "sky/back.jpg",
    "room_room.jpg": "room/room.jpg", "room_bedroom.jpg": "room/bedroom.jpg", "room_bathroom.jpg": "room/bathroom.jpg",
    "room_kitchen.jpg": "room/kitchen.jpg", "room_stable.jpg": "room/stable.jpg",
    "mini_orchard.jpg": "mini/orchard.jpg", "mini_meadow.jpg": "mini/meadow.jpg", "mini_hut.jpg": "mini/hut.jpg",
    "mini_yard.jpg": "mini/yard.jpg", "mini_wash.jpg": "mini/wash.jpg",
}
# Single objects redrawn on their own.
SINGLES = {"house.webp": "props/house.png", "hut.webp": "props/hut.png", "logo.webp": "ui/logo.png"}
EXACT = ["props/ring.png", "sky/ring.png"]  # redrawn things that must keep their exact shape
SKIP = ["sky/pillar_cloud.png", "sky/pillar_storm.png"]  # redrawn but not used: the cloud pillars are flown between and stay as they are
# Green turned to snow: picture -> how far toward yellow counts as green (lower takes in more).
SNOWED = {"props/ground.png": 0.7, "props/hills_far.png": 1.05, "props/hills_near.png": 1.05, "nature/grass.png": 0.7, "nature/mushrooms.png": 0.9}
# New things cut from their sheets: sheet -> columns, then [name, drawn width] in reading order.
EXTRA = {
    "wear.webp": (3, [["hat", 60], ["elf_hat", 60], ["collar", 110], ["scarf", 70], ["flake_a", 40], ["flake_b", 40]]),
    "decor.webp": (4, [["tree", 250], ["presents", 170], ["nativity", 190], ["snowman", 120], ["robin_up", 40], ["robin_down", 40], ["hare_sit", 40], ["hare_leap", 52]]),
}
FOOD = (4, [["turkey", 132], ["pudding", 92], ["gingerbread", 100], ["cookies", 104], ["cocoa", 38], ["yule_log", 104], ["candle", 78], ["oranges", 86]])
# Small things that stand in for summer ones: summer picture -> the new thing that takes its place.
STAND_INS = {
    "nature/butterfly_a.png": "flake_a", "nature/butterfly_b.png": "flake_b",
    "nature/bird_a.png": "robin_up", "nature/bird_b.png": "robin_down",
    "nature/rabbit_a.png": "hare_sit", "nature/rabbit_b.png": "hare_leap",
    "nature/daisies.png": "presents", "nature/lavender.png": "snowman",
}


def snowify(img, low=1.05):
    """Grass, leaves and hills go white with a blue shade, keeping their light and dark and
    their outlines. Anything that is not green is left as it was."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a[..., :3].max(-1), a[..., :3].min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    d = np.maximum(mx - mn, 1e-6)
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4))
    green = np.clip((hue - low) / 0.3, 0, 1) * np.clip((3.25 - hue) / 0.35, 0, 1)
    green *= np.clip((sat - 0.12) / 0.2, 0, 1) * np.clip((mx - 0.16) / 0.2, 0, 1)
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    shade = np.clip((lum - 0.15) / 0.6, 0, 1)
    snow = np.stack([0.62 + 0.38 * shade, 0.72 + 0.28 * shade, 0.88 + 0.12 * shade], -1)
    out = a.copy()
    out[..., :3] = a[..., :3] * (1 - green[..., None]) + snow * green[..., None]
    return Image.fromarray((out * 255).round().astype(np.uint8), "RGBA")


# The stable's window looked out on summer bushes. Inside this box anything green is
# turned to snow, and the sky to a pale winter one.
FROST = {"room/stable.jpg": (236, 132, 456, 304)}


def frost(img, box):
    img = img.convert("RGB")
    px = img.load()
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            r, g, b = px[x, y]
            if g > r + 18 and g > b + 18:  # leaves
                k = min(1.0, (0.3 * r + 0.6 * g + 0.1 * b) / 190.0)
                px[x, y] = (int(150 + 100 * k), int(175 + 78 * k), int(215 + 40 * k))
            elif b > r + 40 and b > g:  # summer sky
                px[x, y] = (int(r * 0.5 + 105), int(g * 0.55 + 95), int(b * 0.6 + 96))
    return img


def solid(img):
    """The part of a picture that is really there: faint specks at its edges are not."""
    return img.split()[3].point(lambda a: 255 if a > 40 else 0).getbbox()


def stand_in(new, old, exact=False):
    """`new` on a canvas the size of `old`, as wide as what was there and standing on the
    same spot, so that it can simply take its place. With `exact` it is pulled to exactly
    the old shape, for things the game measures, like the hoops that are ridden through."""
    new = new.crop(solid(new))
    box = old.getbbox()
    if exact:
        new = new.resize((box[2] - box[0], box[3] - box[1]), Image.LANCZOS)
    else:
        k = min((box[2] - box[0]) / new.width, box[3] / new.height)
        new = new.resize((max(1, round(new.width * k)), max(1, round(new.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", old.size, (0, 0, 0, 0))
    out.paste(new, (round((box[0] + box[2]) / 2 - new.width / 2), box[3] - new.height), new)
    return out


def cells(sheet, cols, count):
    rows = (count + cols - 1) // cols
    cw, ch = sheet.width / cols, sheet.height / rows
    for i in range(count):
        yield sheet.crop((round((i % cols) * cw), round((i // cols) * ch), round((i % cols + 1) * cw), round((i // cols + 1) * ch)))


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if path.endswith(".jpg") else img).save(path, quality=90)


src, art = sys.argv[1], sys.argv[2]
out = os.path.join(art, "xmas")
made = 0
for file, target in SCENES.items():
    old = Image.open(os.path.join(art, target))
    new = Image.open(os.path.join(src, file)).resize(old.size, Image.LANCZOS)
    if target in FROST:
        new = frost(new, FROST[target])
    save(new, os.path.join(out, target))
    made += 1
for file, target in SINGLES.items():
    old = Image.open(os.path.join(art, target)).convert("RGBA")
    save(stand_in(Image.open(os.path.join(src, file)).convert("RGBA"), old), os.path.join(out, target))
    made += 1
for name, info in json.load(open(os.path.join(src, "sheets.json"))).items():
    sheet = Image.open(os.path.join(src, name + ".webp")).convert("RGBA")
    for cell, target in zip(cells(sheet, info["cols"], len(info["files"])), info["files"]):
        if target in SKIP:
            continue
        old = Image.open(os.path.join(art, target)).convert("RGBA")
        save(stand_in(cell, old, target in EXACT), os.path.join(out, target))
        made += 1
for target, low in SNOWED.items():
    save(snowify(Image.open(os.path.join(art, target)), low), os.path.join(out, target))
    made += 1
sizes = {}
pieces = {}
for file, (cols, things) in EXTRA.items():
    sheet = Image.open(os.path.join(src, file)).convert("RGBA")
    for cell, (name, wide) in zip(cells(sheet, cols, len(things)), things):
        piece = cell.crop(solid(cell))
        pieces[name] = piece
        w = min(round(wide * SHARP), piece.width)
        save(piece.resize((w, max(1, round(piece.height * w / piece.width))), Image.LANCZOS), os.path.join(out, "extra", name + ".png"))
        sizes[name] = wide
        made += 1
json.dump(sizes, open(os.path.join(out, "extra", "sizes.json"), "w"), indent=1)
for target, name in STAND_INS.items():
    old = Image.open(os.path.join(art, target)).convert("RGBA")
    save(stand_in(pieces[name], old), os.path.join(out, target))
    made += 1
# Christmas dinner goes in with the rest of the kitchen's food, and its sizes on that list.
kitchen = os.path.join(art, "room", "kitchen")
kitchen_sizes = json.load(open(os.path.join(kitchen, "sizes.json")))
sheet = Image.open(os.path.join(src, "food.webp")).convert("RGBA")
for cell, (name, wide) in zip(cells(sheet, FOOD[0], len(FOOD[1])), FOOD[1]):
    piece = cell.crop(solid(cell))
    w = min(round(wide * SHARP), piece.width)
    save(piece.resize((w, max(1, round(piece.height * w / piece.width))), Image.LANCZOS), os.path.join(kitchen, name + ".png"))
    kitchen_sizes[name] = float(wide)
    made += 1
json.dump(kitchen_sizes, open(os.path.join(kitchen, "sizes.json"), "w"), indent=1)
print(made, "pictures made")
