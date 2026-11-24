"""Scenery for the island and the riding course: trees, bushes, flowers, farmyard things
and small animals. Also the title picture and the logo.
Run: python3 build_nature.py nature ui ../art"""
import json, os, sys
from PIL import Image

QUALITY = 2.2
# name: (slice, how tall it stands in the world)
THINGS = {
    "oak": ("seg_trees_0.png", 330.0), "pine": ("seg_trees_1.png", 350.0), "apple_tree": ("seg_trees_2.png", 300.0),
    "bush": ("seg_trees_3.png", 84.0), "blossom": ("seg_trees_4.png", 90.0),
    "daisies": ("seg_small_0.png", 44.0), "tulips": ("seg_small_1.png", 48.0), "lavender": ("seg_small_2.png", 54.0),
    "sunflowers": ("seg_small_3.png", 84.0), "grass": ("seg_small_4.png", 46.0), "mushrooms": ("seg_small_5.png", 44.0),
    "barrel": ("seg_small_6.png", 66.0), "boulder": ("seg_small_7.png", 56.0), "stump": ("seg_small_8.png", 50.0),
    "fence": ("seg_small_9.png", 62.0),
    "well": ("seg_big_0.png", 160.0), "scarecrow": ("seg_big_1.png", 150.0), "cart": ("seg_big_2.png", 110.0),
    "lamp": ("seg_big_3.png", 190.0), "birdhouse": ("seg_big_4.png", 160.0), "dock": ("seg_big_5.png", 76.0),
    "butterfly_a": ("seg_critters_0.png", 20.0), "butterfly_b": ("seg_critters_1.png", 24.0),
    "bird_a": ("seg_critters_2.png", 30.0), "bird_b": ("seg_critters_3.png", 24.0),
    "rabbit_a": ("seg_critters_4.png", 36.0), "rabbit_b": ("seg_critters_5.png", 30.0),
    "lily": ("seg_critters_6.png", 26.0), "frog": ("seg_critters_7.png", 28.0),
}

src, ui, art = sys.argv[1], sys.argv[2], sys.argv[3]
out = os.path.join(art, "nature")
os.makedirs(out, exist_ok=True)
sizes = {}
for name, (file, height) in THINGS.items():
    img = Image.open(os.path.join(src, file)).convert("RGBA")
    img = img.crop(img.getbbox())
    h = min(round(height * QUALITY), img.height)
    img = img.resize((round(img.width * h / img.height), h), Image.LANCZOS)
    img.save(os.path.join(out, name + ".png"))
    sizes[name] = height
json.dump(sizes, open(os.path.join(out, "sizes.json"), "w"), indent=1)
print(len(sizes), "scenery pictures")

os.makedirs(os.path.join(art, "ui"), exist_ok=True)
Image.open(os.path.join(ui, "title.png")).convert("RGB").save(os.path.join(art, "ui", "title.jpg"), quality=90)
logo = Image.open(os.path.join(ui, "logo.png")).convert("RGBA")
logo = logo.crop(logo.getbbox())
logo.resize((800, round(logo.height * 800 / logo.width)), Image.LANCZOS).save(os.path.join(art, "ui", "logo.png"))
print("title and logo")
