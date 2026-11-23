"""Turns sliced character parts into game textures plus a rig file.

Each character is a small tree of parts. Every part has a pivot (the point it
rotates around) and an attach point on its parent. Numbers are in pixels of
the original sliced part images. Run: python3 build_rig.py <parts_dir> <out_dir> [preview_dir]
"""
import json, math, os, sys
import numpy as np
from PIL import Image

QUALITY = 2.2  # texture pixels per world pixel, so art stays sharp on a phone

# name, slice index, scale, pivot, parent, attach point on parent, draw order, optional clip.
# A clip keeps only part of a slice, so one drawn leg can become a thigh and a shin
# that bend at the knee. The two halves overlap a little so the joint never shows a gap.
def above(v): return lambda x, y: y < v
def below(v): return lambda x, y: y > v

ADELINE = {
    "name": "adeline", "sheet": "adeline_a", "height": 104.0, "measure": ["leg_near_lower", "head"],
    "parts": [
        ("torso", 2, 1.0, (69, 228), None, None, 3),
        ("leg_far_upper", 4, 1.0, (55, 20), "torso", (78, 226), 2, above(160)),
        ("leg_far_lower", 4, 1.0, (40, 148), "leg_far_upper", (40, 148), 1, below(136)),
        ("leg_near_upper", 3, 1.0, (55, 20), "torso", (62, 226), 5, above(160)),
        ("leg_near_lower", 3, 1.0, (40, 148), "leg_near_upper", (40, 148), 4, below(136)),
        ("cloak_back", 6, 1.3, (137, 8), "torso", (45, 20), 0),
        ("arm_upper", 5, 1.0, (45, 72), "torso", (60, 50), 7, lambda x, y: (x < 80) & (y < 158)),
        ("arm_lower", 5, 1.0, (38, 152), "arm_upper", (38, 152), 6, lambda x, y: (x >= 80) | (y > 134)),
        ("hood", 7, 0.85, (144, 59), "torso", (75, 22), 8),
        ("head", 0, 0.7, (112, 200), "torso", (62, 10), 9),
        ("ponytail", 1, 0.7, (186, 34), "head", (60, 60), 10),
    ],
}

SPIRIT = {
    "name": "spirit", "sheet": "spirit_a", "height": 150.0, "measure": ["leg_front_near_lower", "body"],
    "parts": [
        ("body", 0, 1.0, (242, 300), None, None, 5),
        ("tail", 5, 1.0, (140, 14), "body", (14, 196), 0),
        ("leg_hind_far_upper", 4, 1.0, (86, 30), "body", (82, 294), 2, above(162)),
        ("leg_hind_far_lower", 4, 1.0, (20, 150), "leg_hind_far_upper", (20, 150), 1, below(138)),
        ("leg_front_far_upper", 2, 1.0, (40, 28), "body", (318, 286), 4, above(168)),
        ("leg_front_far_lower", 2, 1.0, (35, 156), "leg_front_far_upper", (35, 156), 3, below(144)),
        ("leg_hind_near_upper", 3, 1.0, (86, 30), "body", (56, 300), 7, above(162)),
        ("leg_hind_near_lower", 3, 1.0, (20, 150), "leg_hind_near_upper", (20, 150), 6, below(138)),
        ("leg_front_near_upper", 1, 1.0, (40, 28), "body", (296, 292), 9, above(168)),
        ("leg_front_near_lower", 1, 1.0, (35, 156), "leg_front_near_upper", (35, 156), 8, below(144)),
    ],
}

GOBLIN = {
    "name": "goblin", "sheet": "goblin_a", "height": 76.0, "measure": ["leg_near", "head"],
    "parts": [
        ("body", 2, 1.0, (125, 262), None, None, 2),
        ("leg_far", 4, 1.0, (66, 14), "body", (150, 250), 0),
        ("leg_near", 3, 1.0, (66, 14), "body", (104, 252), 1),
        ("arm", 1, 0.9, (22, 182), "body", (150, 100), 4),
        ("head", 0, 0.8, (215, 240), "body", (112, 52), 3),
    ],
}


def rot(v, deg):
    r = math.radians(deg)
    return (v[0] * math.cos(r) - v[1] * math.sin(r), v[0] * math.sin(r) + v[1] * math.cos(r))


def solve(spec, parts_dir, pose=None):
    """Returns part placements in design pixels: pivot position and total angle."""
    pose = pose or {}
    info = {p[0]: p for p in spec["parts"]}
    placed = {}
    for part in spec["parts"]:
        name, idx, scale, pivot, parent, attach, z = part[:7]
        clip = part[7] if len(part) > 7 else None
        angle = pose.get(name, 0.0)
        if parent is None:
            pos = pose.get("_root", (0.0, 0.0))
            total = angle
        else:
            pp = placed[parent]
            pinfo = info[parent]
            local = ((attach[0] - pinfo[3][0]) * pinfo[2], (attach[1] - pinfo[3][1]) * pinfo[2])
            off = rot(local, pp["angle"])
            pos = (pp["pos"][0] + off[0], pp["pos"][1] + off[1])
            total = pp["angle"] + angle
        img = Image.open(os.path.join(parts_dir, "seg_%s_%d.png" % (spec["sheet"], idx))).convert("RGBA")
        if clip is not None:
            arr = np.array(img)
            ys, xs = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
            arr[~clip(xs, ys)] = 0
            img = Image.fromarray(arr)
        placed[name] = {"pos": pos, "angle": total, "scale": scale, "pivot": pivot, "z": z, "img": img}
    return placed


def extent(placed, names):
    ys = []
    for n in names:
        p = placed[n]
        w, h = p["img"].size
        ys += [p["pos"][1] - p["pivot"][1] * p["scale"], p["pos"][1] + (h - p["pivot"][1]) * p["scale"]]
    return min(ys), max(ys)


def render(spec, parts_dir, poses, out_path, px_per_world=3.0, cell=(520, 520)):
    neutral = solve(spec, parts_dir)
    top, bottom = extent(neutral, spec["measure"])
    world = spec["height"] / (bottom - top)  # world pixels per design pixel
    sheet = Image.new("RGBA", (cell[0] * len(poses), cell[1]), (70, 120, 170, 255))
    for i, pose in enumerate(poses):
        placed = solve(spec, parts_dir, pose)
        k = world * px_per_world
        ox, oy = cell[0] * i + cell[0] // 2, cell[1] - 40
        for name in sorted(placed, key=lambda n: placed[n]["z"]):
            p = placed[name]
            s = p["scale"] * k
            img = p["img"].resize((max(1, round(p["img"].width * s)), max(1, round(p["img"].height * s))), Image.LANCZOS)
            px = ox + p["pos"][0] * k
            py = oy + (p["pos"][1] - bottom) * k
            layer = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            layer.paste(img, (round(px - p["pivot"][0] * s), round(py - p["pivot"][1] * s)))
            layer = layer.rotate(-p["angle"], center=(px, py), resample=Image.BICUBIC)
            sheet.alpha_composite(layer)
        # ground line
        for x in range(cell[0] * i, cell[0] * (i + 1)):
            sheet.putpixel((x, oy), (255, 255, 255, 255))
    sheet.convert("RGB").save(out_path)


def export(spec, parts_dir, out_dir):
    neutral = solve(spec, parts_dir)
    top, bottom = extent(neutral, spec["measure"])
    world = spec["height"] / (bottom - top)
    info = {p[0]: p for p in spec["parts"]}
    os.makedirs(out_dir, exist_ok=True)
    rig = {"tex_scale": 1.0 / QUALITY, "parts": []}
    for part in spec["parts"]:
        name, idx, scale, pivot, parent, attach, z = part[:7]
        img = neutral[name]["img"]
        s = scale * world * QUALITY
        out = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
        out.save(os.path.join(out_dir, name + ".png"))
        if parent is None:
            pos = (0.0, (neutral[name]["pos"][1] - bottom) * world)
        else:
            pinfo = info[parent]
            pos = ((attach[0] - pinfo[3][0]) * pinfo[2] * world, (attach[1] - pinfo[3][1]) * pinfo[2] * world)
        rig["parts"].append({
            "name": name, "parent": parent or "", "z": z,
            "pos": [round(pos[0], 2), round(pos[1], 2)],
            "pivot": [round(pivot[0] * s, 2), round(pivot[1] * s, 2)],
        })
    json.dump(rig, open(os.path.join(out_dir, "rig.json"), "w"), indent=1)
    print(spec["name"], "world px per design px %.4f" % world, "parts", len(rig["parts"]))


if __name__ == "__main__":
    parts_dir, out_root = sys.argv[1], sys.argv[2]
    preview = sys.argv[3] if len(sys.argv) > 3 else None
    for spec in (ADELINE, SPIRIT, GOBLIN):
        export(spec, parts_dir, os.path.join(out_root, spec["name"]))
    if preview:
        render(ADELINE, parts_dir, [
            {},
            {"leg_near_upper": -26, "leg_near_lower": 6, "leg_far_upper": 22, "leg_far_lower": 30, "arm_upper": 8},
            {"leg_near_upper": 4, "leg_near_lower": 44, "leg_far_upper": -4, "leg_far_lower": 2},
            {"arm_upper": -120, "arm_lower": -40, "torso": -6},
            {"arm_upper": 30, "arm_lower": 45, "torso": 8},
        ], os.path.join(preview, "adeline_poses.png"), px_per_world=3.0, cell=(420, 440))
        render(SPIRIT, parts_dir, [
            {},
            {"leg_front_near_upper": -36, "leg_front_near_lower": 10, "leg_front_far_upper": -10, "leg_front_far_lower": 70,
             "leg_hind_near_upper": 30, "leg_hind_near_lower": 10, "leg_hind_far_upper": -24, "leg_hind_far_lower": -30, "tail": 20},
        ], os.path.join(preview, "spirit_poses.png"), px_per_world=2.6, cell=(640, 520))
        render(GOBLIN, parts_dir, [
            {},
            {"leg_near": 28, "leg_far": -28},
            {"arm": -70, "body": -8},
            {"arm": 75, "body": 8},
            {"body": 20, "head": 10},
        ], os.path.join(preview, "goblin_poses.png"), px_per_world=5.0, cell=(420, 440))
