"""Scenery for the sky ride and the unicorn mission: the backdrop, storm pillars, clouds,
stars, the rainbow arch, the cloud castle, the hay heap, the net, and a rainbow ring made
from the riding course's golden one. Run: python3 build_sky.py sky ../art"""
import colorsys, json, math, os, sys
import numpy as np
from PIL import Image

QUALITY = 2.2
# name: (slice, how tall it stands in the world)
THINGS = {
    "pillar_cloud": ("seg_pillars_0.png", 640.0), "pillar_storm": ("seg_pillars_1.png", 640.0),
    "storm": ("seg_skyprops_0.png", 150.0), "star": ("seg_skyprops_1.png", 54.0), "hay": ("seg_skyprops_2.png", 190.0),
    "cloud_0": ("seg_skyprops_3.png", 100.0), "cloud_1": ("seg_skyprops_4.png", 88.0), "cloud_2": ("seg_skyprops_5.png", 84.0),
    "castle": ("seg_gates_0.png", 760.0), "arch": ("seg_gates_1.png", 430.0),
}

src, art = sys.argv[1], sys.argv[2]
out = os.path.join(art, "sky")
os.makedirs(out, exist_ok=True)
sizes = {}
for name, (file, height) in THINGS.items():
    img = Image.open(os.path.join(src, file)).convert("RGBA")
    img = img.crop(img.getbbox())
    h = min(round(height * QUALITY), img.height)  # never blown up: the game scales it instead
    img = img.resize((round(img.width * h / img.height), h), Image.LANCZOS)
    img.save(os.path.join(out, name + ".png"))
    sizes[name] = height
    print(name, img.size, "stands", height)

Image.open(os.path.join(src, "sky.png")).convert("RGB").save(os.path.join(out, "back.jpg"), quality=90)

# The rainbow ring: the golden ring with its colours turned round the wheel, a different
# amount at each point of the loop. Outlines and white flowers keep their colour.
ring = np.array(Image.open(os.path.join(art, "props", "ring.png")).convert("RGBA")).astype(np.float32) / 255.0
h, w = ring.shape[:2]
ys, xs = np.mgrid[0:h, 0:w]
turn = (np.arctan2((ys - h / 2) / h, (xs - w / 2) / w) / (2 * math.pi)) % 1.0
r, g, b = ring[..., 0], ring[..., 1], ring[..., 2]
mx, mn = ring[..., :3].max(-1), ring[..., :3].min(-1)
sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
rainbow = np.zeros_like(ring[..., :3])
for y in range(h):
    for x in range(w):
        hh, ss, vv = colorsys.rgb_to_hsv(r[y, x], g[y, x], b[y, x])
        gold = 0.07 < hh < 0.2
        rainbow[y, x] = colorsys.hsv_to_rgb(turn[y, x], min(ss * 1.05, 1.0), vv) if gold else (r[y, x], g[y, x], b[y, x])
ring[..., :3] = rainbow
Image.fromarray((ring * 255).astype(np.uint8)).save(os.path.join(out, "ring.png"))
sizes["ring"] = 170.0

net = Image.open(os.path.join(src, "seg_net_0.png")).convert("RGBA")
net = net.crop(net.getbbox())
nh = round(185.0 * QUALITY)
net.resize((round(net.width * nh / net.height), nh), Image.LANCZOS).save(os.path.join(art, "props", "net.png"))
json.dump(sizes, open(os.path.join(out, "sizes.json"), "w"), indent=1)
