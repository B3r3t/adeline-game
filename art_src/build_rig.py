"""Turns sliced character parts into game textures plus a rig file.

Each character is a small tree of parts. Every part has a pivot (the point it
rotates around) and an attach point on its parent. Numbers are in pixels of
the original sliced part images. Run: python3 build_rig.py <parts_dir> <out_dir> [preview_dir]
"""
import json, math, os, sys
from PIL import Image

QUALITY = 2.2  # texture pixels per world pixel, so art stays sharp on a phone

# name, slice index, scale, pivot, parent, attach point on parent, draw order
ADELINE = {
    "name": "adeline", "sheet": "adeline_a", "height": 104.0, "measure": ["leg_near", "head"],
    "parts": [
        ("torso", 2, 1.0, (69, 228), None, None, 2),
        ("leg_far", 4, 1.0, (55, 20), "torso", (78, 226), 1),
        ("leg_near", 3, 1.0, (55, 20), "torso", (62, 226), 3),
        ("cloak_back", 6, 1.3, (137, 8), "torso", (45, 20), 0),
        ("arm", 5, 1.0, (45, 72), "torso", (60, 50), 4),
        ("hood", 7, 0.85, (144, 59), "torso", (75, 22), 5),
        ("head", 0, 0.7, (112, 200), "torso", (62, 10), 6),
        ("ponytail", 1, 0.7, (186, 34), "head", (60, 60), 7),
    ],
}

SPIRIT = {
    "name": "spirit", "sheet": "spirit_a", "height": 150.0, "measure": ["leg_front_near", "body"],
    "parts": [
        ("body", 0, 1.0, (242, 300), None, None, 2),
        ("tail", 5, 1.0, (140, 14), "body", (14, 196), 0),
        ("leg_hind_far", 4, 1.0, (86, 30), "body", (82, 294), 1),
        ("leg_front_far", 2, 1.0, (40, 28), "body", (318, 286), 1),
        ("leg_hind_near", 3, 1.0, (86, 30), "body", (56, 300), 3),
        ("leg_front_near", 1, 1.0, (40, 28), "body", (296, 292), 3),
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
    for name, idx, scale, pivot, parent, attach, z in spec["parts"]:
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
        img = Image.open(os.path.join(parts_dir, "seg_%s_%d.png" % (spec["sheet"], idx)))
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
    for name, idx, scale, pivot, parent, attach, z in spec["parts"]:
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
    for spec in (ADELINE, SPIRIT):
        export(spec, parts_dir, os.path.join(out_root, spec["name"]))
    if preview:
        render(ADELINE, parts_dir, [
            {},
            {"leg_near": 24, "leg_far": -24, "arm": 8, "ponytail": 8, "cloak_back": 6},
            {"arm": -95, "cloak_back": 14},
            {"arm": 35, "torso": 6},
        ], os.path.join(preview, "adeline_poses.png"))
        render(SPIRIT, parts_dir, [
            {},
            {"leg_front_near": -32, "leg_front_far": 28, "leg_hind_near": 30, "leg_hind_far": -26, "tail": -18},
        ], os.path.join(preview, "spirit_poses.png"), px_per_world=2.6, cell=(640, 520))
