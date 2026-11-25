"""The farm games' pictures: five painted scenes and everything that goes in them.
Run: python3 build_mini.py mini ../art/mini"""
import json, os, sys
from PIL import Image

SHARP = 1.6  # pixels kept for each pixel a thing is drawn at, so it stays crisp on a big screen
SCENES = ["orchard", "meadow", "hut", "yard", "wash"]
# name: (slice, how wide it is drawn in the scene). Scenes are 1344 across.
THINGS = {
    "apple_red": ("apples_0", 62), "apple_green": ("apples_1", 62), "apple_gold": ("apples_2", 62), "apple_worm": ("apples_3", 72),
    "leaf": ("apples_4", 38), "basket": ("apples_5", 128), "basket_full": ("apples_6", 128), "card": ("apples_7", 300),
    "fox_1": ("fox_0", 0.36), "fox_2": ("fox_1", 0.36), "fox_scared": ("fox_2", 0.36), "bramble": ("fox_3", 190),
    "lamb_stand": ("lamb_0", 0.42), "lamb_walk_1": ("lamb_1", 0.42), "lamb_walk_2": ("lamb_2", 0.42), "lamb_jump": ("lamb_3", 0.42),
    "lamb_sit": ("lamb_4", 0.42), "lamb_sleep": ("lamb_5", 0.42),
    "mushroom": ("potion_0", 84), "moonflower": ("potion_1", 92), "feather": ("potion_2", 80), "crystal": ("potion_3", 88),
    "shell": ("potion_4", 90), "acorn": ("potion_5", 76), "cauldron": ("potion_6", 300), "frog": ("potion_7", 104),
    "hen": ("critters_0", 120), "cat": ("critters_1", 130), "rabbit": ("critters_2", 86), "mouse": ("critters_3", 92),
    "bottle_pink": ("critters_4", 66), "bottle_blue": ("critters_5", 66), "bottle_green": ("critters_6", 66), "bottle_gold": ("critters_7", 66),
    "bales": ("hiding_0", 250), "barrel": ("hiding_1", 176), "bush": ("hiding_2", 240), "barrow": ("hiding_3", 262),
    "well": ("hiding_4", 206), "sheet": ("hiding_5", 232), "kennel": ("hiding_6", 226), "crates": ("hiding_7", 248),
    "sponge": ("tools_0", 112), "hose": ("tools_1", 136), "brush": ("tools_2", 112), "bucket": ("tools_3", 104),
    "towel": ("tools_5", 130), "bow": ("tools_6", 84), "mud_1": ("tools_7", 104), "mud_2": ("tools_8", 150), "mud_3": ("tools_9", 68),
    "pony": ("pony_0", 560),
}

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for name in SCENES:
    Image.open(os.path.join(src, name + ".jpg")).convert("RGB").save(os.path.join(out, name + ".jpg"), quality=90)
sizes = {}
for name, (file, wide) in THINGS.items():
    img = Image.open(os.path.join(src, "seg_%s.png" % file)).convert("RGBA")
    img = img.crop(img.getbbox())
    if wide < 5:
        wide = round(img.width * wide)  # a share of its drawn size, so every pose of an animal matches
    w = min(round(wide * SHARP), img.width)
    img = img.resize((w, max(1, round(img.height * w / img.width))), Image.LANCZOS)
    img.save(os.path.join(out, name + ".png"))
    sizes[name] = wide
    print(name, img.size, wide)
json.dump(sizes, open(os.path.join(out, "sizes.json"), "w"), indent=1)
