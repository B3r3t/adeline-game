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


# Adeline's little sister: a five-year-old, so a big head, a short body and short limbs.
SISTER = {
    "name": "sister", "sheet": "sister_a", "height": 72.0, "measure": ["leg_near_lower", "head"],
    "parts": [
        ("torso", 2, 0.86, (77, 205), None, None, 3),
        ("leg_far_upper", 4, 0.8, (50, 18), "torso", (88, 200), 2, above(112)),
        ("leg_far_lower", 4, 0.8, (50, 100), "leg_far_upper", (50, 100), 1, below(88)),
        ("leg_near_upper", 3, 0.8, (50, 18), "torso", (70, 200), 5, above(112)),
        ("leg_near_lower", 3, 0.8, (50, 100), "leg_near_upper", (50, 100), 4, below(88)),
        ("cloak_back", 6, 0.8, (133, 10), "torso", (46, 34), 0),
        # Her arm is drawn in front of everything, so a wave shows in front of her face.
        ("arm_upper", 5, 0.8, (48, 22), "torso", (60, 56), 12, lambda x, y: (x < 78) & (y < 100)),
        ("arm_lower", 5, 0.8, (40, 92), "arm_upper", (40, 92), 11, lambda x, y: (x >= 78) | (y > 72)),
        ("hood", 7, 0.56, (128, 62), "torso", (84, 30), 8),
        ("head", 0, 0.8, (128, 216), "torso", (86, 20), 9),
        ("ponytail", 1, 0.8, (120, 50), "head", (42, 74), 10),
    ],
}

# Her pony: a round body, a big head and short sturdy legs. Not a small horse.
PONY = {
    "name": "pony", "sheet": "pony_a", "height": 92.0, "measure": ["leg_front_near_lower", "body"],
    "parts": [
        ("body", 0, 1.0, (231, 318), None, None, 5),
        ("tail", 5, 0.85, (182, 26), "body", (40, 212), 0),
        ("leg_hind_far_upper", 4, 0.82, (105, 45), "body", (98, 296), 2, above(162)),
        ("leg_hind_far_lower", 4, 0.82, (50, 150), "leg_hind_far_upper", (50, 150), 1, below(138)),
        ("leg_front_far_upper", 2, 0.82, (55, 40), "body", (306, 296), 4, above(140)),
        ("leg_front_far_lower", 2, 0.82, (58, 128), "leg_front_far_upper", (58, 128), 3, below(116)),
        ("leg_hind_near_upper", 3, 0.82, (105, 45), "body", (74, 304), 7, above(162)),
        ("leg_hind_near_lower", 3, 0.82, (50, 150), "leg_hind_near_upper", (50, 150), 6, below(138)),
        ("leg_front_near_upper", 1, 0.82, (55, 40), "body", (286, 304), 9, above(140)),
        ("leg_front_near_lower", 1, 0.82, (58, 128), "leg_front_near_upper", (58, 128), 8, below(116)),
    ],
}


# The ogre: the goblin's shape of puppet, drawn big. He is exported at his real size so he
# stays sharp, and the goblin script moves him.
OGRE = {
    "name": "ogre", "sheet": "ogre_a", "height": 150.0, "measure": ["leg_near", "head"],
    "parts": [
        ("body", 2, 1.0, (178, 326), None, None, 2),
        ("leg_far", 4, 1.0, (105, 24), "body", (218, 306), 0),
        ("leg_near", 3, 1.0, (105, 24), "body", (146, 310), 1),
        ("arm", 1, 0.95, (42, 215), "body", (236, 104), 4),
        ("head", 0, 0.92, (150, 250), "body", (196, 34), 3),
    ],
}


# The unicorn: drawn on Spirit's pattern of sheet, so she is put together the same way.
# Her wings are separate pictures, added by build_wings.py.
UNICORN = {
    "name": "unicorn", "sheet": "unicorn_a", "height": 150.0, "measure": ["leg_front_near_lower", "body"],
    "parts": [
        ("body", 0, 1.0, (246, 303), None, None, 5),
        ("tail", 5, 1.0, (150, 24), "body", (22, 200), 0),
        ("leg_hind_far_upper", 4, 1.0, (86, 30), "body", (86, 297), 2, above(162)),
        ("leg_hind_far_lower", 4, 1.0, (20, 150), "leg_hind_far_upper", (20, 150), 1, below(138)),
        ("leg_front_far_upper", 2, 1.0, (42, 28), "body", (322, 289), 4, above(168)),
        ("leg_front_far_lower", 2, 1.0, (37, 156), "leg_front_far_upper", (37, 156), 3, below(144)),
        ("leg_hind_near_upper", 3, 1.0, (86, 30), "body", (60, 303), 7, above(162)),
        ("leg_hind_near_lower", 3, 1.0, (20, 150), "leg_hind_near_upper", (20, 150), 6, below(138)),
        ("leg_front_near_upper", 1, 1.0, (42, 28), "body", (300, 295), 9, above(168)),
        ("leg_front_near_lower", 1, 1.0, (37, 156), "leg_front_near_upper", (37, 156), 8, below(144)),
    ],
}


def rider(name, height, torso, legs, cloak, shoulder, elbow, arm_at, split, hood_at, head, head_at, tail):
    """One of the riders in a race. They are drawn on Adeline's pattern of sheet, so they are
    put together the same way, each with their own joints."""
    upper = lambda x, y: (x < split[0]) & (y < split[1])
    lower = lambda x, y: (x >= split[0]) | (y > split[2])
    return {
        "name": "rider_" + name, "sheet": "rider_%s_a" % name, "height": height, "measure": ["leg_near_lower", "head"],
        "parts": [
            ("torso", 2, 1.0, torso, None, None, 3),
            ("leg_far_upper", 4, 1.0, (55, 20), "torso", legs[0], 2, above(160)),
            ("leg_far_lower", 4, 1.0, (40, 148), "leg_far_upper", (40, 148), 1, below(136)),
            ("leg_near_upper", 3, 1.0, (55, 20), "torso", legs[1], 5, above(160)),
            ("leg_near_lower", 3, 1.0, (40, 148), "leg_near_upper", (40, 148), 4, below(136)),
            ("cloak_back", 6, 1.15, (141, 8), "torso", cloak, 0),
            ("arm_upper", 5, 1.0, shoulder, "torso", arm_at, 7, upper),
            ("arm_lower", 5, 1.0, elbow, "arm_upper", elbow, 6, lower),
            ("hood", 7, 0.8, (146, 60), "torso", hood_at, 8),
            ("head", 0, 0.7, head, "torso", head_at, 9),
            ("ponytail", 1, 0.7, tail[0], "head", tail[1], 10),
        ],
    }


RIDERS = [
    rider("finn", 100.0, (72, 236), [(82, 234), (64, 234)], (58, 28), (55, 48), (38, 135), (62, 56), (85, 142, 118),
          (92, 30), (128, 218), (92, 16), [(205, 32), (62, 96)]),
    rider("rosa", 100.0, (92, 232), [(102, 230), (84, 230)], (62, 36), (52, 72), (40, 150), (66, 66), (80, 158, 134),
          (106, 32), (138, 222), (108, 16), [(212, 48), (66, 104)]),
    rider("baron", 116.0, (84, 240), [(94, 238), (76, 238)], (56, 46), (55, 80), (32, 165), (58, 84), (80, 172, 148),
          (94, 46), (130, 246), (96, 34), [(200, 52), (62, 150)]),
]


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
    for spec in [ADELINE, SPIRIT, GOBLIN, SISTER, PONY, OGRE, UNICORN] + RIDERS:
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
        render(SISTER, parts_dir, [
            {},
            {"leg_near_upper": -26, "leg_near_lower": 6, "leg_far_upper": 22, "leg_far_lower": 30, "arm_upper": 8},
            {"leg_near_upper": -55, "leg_near_lower": 60, "leg_far_upper": -55, "leg_far_lower": 60, "arm_upper": -14, "arm_lower": 8, "torso": 6, "cloak_back": 20, "ponytail": 14},
            {"arm_upper": -105, "arm_lower": -20},
        ], os.path.join(preview, "sister_poses.png"), px_per_world=4.5, cell=(420, 440))
        render(PONY, parts_dir, [
            {},
            {"leg_front_near_upper": -23, "leg_front_near_lower": 6, "leg_front_far_upper": -6, "leg_front_far_lower": 46,
             "leg_hind_near_upper": 19, "leg_hind_near_lower": 6, "leg_hind_far_upper": -15, "leg_hind_far_lower": -20, "tail": 14},
            {"leg_front_near_upper": -54, "leg_front_near_lower": 88, "leg_front_far_upper": -49, "leg_front_far_lower": 83,
             "leg_hind_near_upper": 36, "leg_hind_near_lower": 10, "leg_hind_far_upper": 31, "leg_hind_far_lower": 10, "tail": 30, "body": -10},
        ], os.path.join(preview, "pony_poses.png"), px_per_world=4.0, cell=(640, 520))
        render(UNICORN, parts_dir, [
            {},
            {"leg_front_near_upper": -36, "leg_front_near_lower": 10, "leg_front_far_upper": -10, "leg_front_far_lower": 70,
             "leg_hind_near_upper": 30, "leg_hind_near_lower": 10, "leg_hind_far_upper": -24, "leg_hind_far_lower": -30, "tail": 20},
            {"leg_front_near_upper": -54, "leg_front_near_lower": 88, "leg_front_far_upper": -49, "leg_front_far_lower": 83,
             "leg_hind_near_upper": 36, "leg_hind_near_lower": 10, "leg_hind_far_upper": 31, "leg_hind_far_lower": 10, "tail": 30, "body": -10},
        ], os.path.join(preview, "unicorn_poses.png"), px_per_world=2.6, cell=(640, 520))
        render(OGRE, parts_dir, [
            {},
            {"leg_near": 28, "leg_far": -28},
            {"arm": -70, "body": -8, "leg_near": 8, "leg_far": 8},
            {"arm": 75, "body": 8, "leg_near": -8, "leg_far": -8},
        ], os.path.join(preview, "ogre_poses.png"), px_per_world=2.6, cell=(520, 480))
        for spec in RIDERS:
            render(spec, parts_dir, [
                {},
                {"leg_near_upper": -55, "leg_near_lower": 60, "leg_far_upper": -55, "leg_far_lower": 60, "arm_upper": -14, "arm_lower": 8, "torso": 8, "cloak_back": 24, "ponytail": 18},
            ], os.path.join(preview, spec["name"] + "_poses.png"), px_per_world=3.4, cell=(420, 460))
