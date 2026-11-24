"""Adds the unicorn's wings to her rig: a spread wing for flying and a folded one for the
ground, on each side. Run after build_rig.py: python3 build_wings.py parts <rig_out_root>"""
import json, os, sys
from PIL import Image

QUALITY = 2.2
# picture, slice, how tall it stands in the world, and its root (the knob that joins her
# shoulder) in pixels of the slice
SPREAD = ("seg_wings_0.png", 132.0, (417, 563))
FOLDED = ("seg_wings_1.png", 28.0, (393, 74))
# Where the root sits, measured in the world from her body joint, and the draw order.
SIDES = {"wing_far": ((9.0, -33.0), -1), "wing_near": ((1.0, -29.0), 10)}

parts_dir, out_root = sys.argv[1], sys.argv[2]
out = os.path.join(out_root, "unicorn")
rig = json.load(open(os.path.join(out, "rig.json")))
rig["parts"] = [p for p in rig["parts"] if not p["name"].startswith("wing")]
extra = {}
for key, (file, height, root) in {"spread": SPREAD, "folded": FOLDED}.items():
    img = Image.open(os.path.join(parts_dir, file)).convert("RGBA")
    k = height * QUALITY / img.height
    img = img.resize((round(img.width * k), round(img.height * k)), Image.LANCZOS)
    pivot = [round(root[0] * k, 2), round(root[1] * k, 2)]
    extra[key] = pivot
    if key == "spread":
        for name in SIDES:
            img.save(os.path.join(out, name + ".png"))
    else:
        img.save(os.path.join(out, "wing_folded.png"))
for name, (pos, z) in SIDES.items():
    rig["parts"].append({"name": name, "parent": "body", "z": z, "pos": list(pos), "pivot": extra["spread"]})
rig["wings"] = extra  # the pivots of the two wing pictures, for swapping between them
json.dump(rig, open(os.path.join(out, "rig.json"), "w"), indent=1)
print("wings", extra)
