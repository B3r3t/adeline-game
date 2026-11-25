"""The kitchen table and everything that goes on it: the table itself (drawn so its top
can be seen), chairs, place settings and three meals' worth of serving dishes.
Run: python3 build_kitchen.py kitchen ../art/room/kitchen"""
import json, os, sys
from PIL import Image

SHARP = 1.7  # pixels kept for each pixel it is drawn at in the room, so it stays crisp
# name: (slice, how wide it is drawn in the room, squash)
# Plates were drawn from straight above; squashing them lays them flat on the table top.
THINGS = {
    "table": ("seg_table_0.png", 780.0, 1.0), "chair": ("seg_chair_0.png", 126.0, 1.0),
    "plate": ("seg_ware_0.png", 96.0, 0.5), "plate_roast": ("seg_ware_1.png", 96.0, 0.5), "plate_done": ("seg_ware_2.png", 82.0, 0.5),
    "bowl_soup": ("seg_ware_3.png", 66.0, 0.78), "plate_pancakes": ("seg_ware_4.png", 100.0, 0.5), "bowl_done": ("seg_ware_5.png", 62.0, 0.78),
    "mug": ("seg_ware_6.png", 34.0, 1.0), "milk": ("seg_ware_7.png", 26.0, 1.0),
    "chicken": ("seg_roast_0.png", 124.0, 1.0), "mash": ("seg_roast_1.png", 84.0, 1.0), "peas": ("seg_roast_2.png", 100.0, 1.0),
    "gravy": ("seg_roast_3.png", 78.0, 1.0), "rolls": ("seg_roast_4.png", 92.0, 1.0), "pie": ("seg_roast_5.png", 104.0, 1.0),
    "tureen": ("seg_soup_0.png", 104.0, 1.0), "loaf": ("seg_soup_1.png", 112.0, 1.0), "cheese": ("seg_soup_2.png", 98.0, 1.0),
    "salad": ("seg_soup_3.png", 92.0, 1.0), "fruit": ("seg_soup_4.png", 94.0, 1.0), "jug": ("seg_soup_5.png", 66.0, 1.0),
    "pancakes": ("seg_breakfast_0.png", 86.0, 1.0), "berries": ("seg_breakfast_1.png", 68.0, 1.0), "juice": ("seg_breakfast_2.png", 60.0, 1.0),
    "eggs": ("seg_breakfast_3.png", 104.0, 1.0), "toast": ("seg_breakfast_4.png", 72.0, 1.0), "jam": ("seg_breakfast_5.png", 70.0, 1.0),
    "vase": ("seg_breakfast_6.png", 62.0, 1.0), "salt": ("seg_breakfast_7.png", 50.0, 1.0),
}

# The table was drawn almost side on. Its top is stretched so there is room to lay things
# out in rows, and its legs shortened so it stands at the height of a real table.
TOP_ENDS, LEGS_START = 158, 259  # rows of the drawing
TOP_STRETCH, LEG_SQUASH = 1.4, 0.55


def reshape(img):
    parts = [(0, TOP_ENDS, TOP_STRETCH), (TOP_ENDS, LEGS_START, 1.0), (LEGS_START, img.height, LEG_SQUASH)]
    strips = [img.crop((0, a, img.width, b)).resize((img.width, round((b - a) * k)), Image.LANCZOS) for a, b, k in parts]
    out = Image.new("RGBA", (img.width, sum(s.height for s in strips)))
    y = 0
    for s in strips:
        out.paste(s, (0, y))
        y += s.height
    return out


src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
sizes = {}
for name, (file, wide, squash) in THINGS.items():
    img = Image.open(os.path.join(src, file)).convert("RGBA")
    img = img.crop(img.getbbox())
    if name == "table":
        img = reshape(img)
    w = min(round(wide * SHARP), img.width)
    img = img.resize((w, max(1, round(img.height * w / img.width * squash))), Image.LANCZOS)
    img.save(os.path.join(out, name + ".png"))
    sizes[name] = wide
    print(name, img.size)
json.dump(sizes, open(os.path.join(out, "sizes.json"), "w"), indent=1)
