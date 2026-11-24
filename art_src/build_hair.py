"""Builds the little sister's other hairstyles.

Each is one picture that takes the place of her ponytail. They are scaled the same way
as the rest of her (see build_rig.py) and saved with where their joint is and where on her
head they sit, so the game can swap one for another.

Run from art_src:  python3 build_hair.py
"""
import json
import shutil
from PIL import Image

QUALITY = 2.2  # picture pixels for each pixel of the game world, as in build_rig.py
rig = json.load(open("../art/sister/rig.json"))
tail = next(p for p in rig["parts"] if p["name"] == "ponytail")
# Her ponytail is drawn at 0.8 of its sheet size with its joint at (120, 50) on its slice,
# which tells us how big one sheet pixel is in the game.
world = tail["pivot"][0] / (120.0 * 0.8 * QUALITY)
HEAD_PIVOT, HEAD_SCALE = (128.0, 216.0), 0.8

# name: (slice, size, joint on the slice, where it sits on her head slice, how floppy it is)
STYLES = {
    "braid": (0, 0.56, (150, 60), (42, 74), 0.8),
    "bun": (1, 0.44, (150, 112), (52, 52), 0.15),
    "pigtails": (2, 0.55, (228, 45), (46, 62), 0.8),
}

out = {"ponytail": {"pivot": tail["pivot"], "pos": tail["pos"], "soft": 1.0}}
shutil.copy("../art/sister/ponytail.png", "../art/sister/hair_ponytail.png")
for name, (index, size, joint, sits, soft) in STYLES.items():
    img = Image.open("parts/seg_sister_hair_%d.png" % index).convert("RGBA")
    s = size * world * QUALITY
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    img.save("../art/sister/hair_%s.png" % name)
    out[name] = {
        "pivot": [round(joint[0] * s, 2), round(joint[1] * s, 2)],
        "pos": [round((sits[0] - HEAD_PIVOT[0]) * HEAD_SCALE * world, 2), round((sits[1] - HEAD_PIVOT[1]) * HEAD_SCALE * world, 2)],
        "soft": soft,
    }
    print(name, img.size, out[name])
json.dump(out, open("../art/sister/hair.json", "w"), indent=1)
