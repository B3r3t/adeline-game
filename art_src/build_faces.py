"""Round portraits for the speech box: Adeline, her little sister, Merlin, Mom and Dad.
Each is cut from the character's own drawing, so they always match.
Run: python3 build_faces.py parts props ../art/ui"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import build_rig

SIZE = 144

def standing(spec, parts_dir, k):
    """A character put together from its parts, standing still, at k pixels per design pixel."""
    placed = build_rig.solve(spec, parts_dir)
    canvas = Image.new("RGBA", (int(900 * k), int(1100 * k)), (0, 0, 0, 0))
    ox, oy = canvas.width // 2, int(canvas.height * 0.6)
    for name in sorted(placed, key=lambda n: placed[n]["z"]):
        p = placed[name]
        s = p["scale"] * k
        img = p["img"].resize((max(1, round(p["img"].width * s)), max(1, round(p["img"].height * s))), Image.LANCZOS)
        canvas.alpha_composite(img, (round(ox + p["pos"][0] * k - p["pivot"][0] * s), round(oy + p["pos"][1] * k - p["pivot"][1] * s)))
    return canvas.crop(canvas.getbbox())

def figures(path):
    """The separate people in a sheet, left to right."""
    img = Image.open(path).convert("RGBA")
    lab, n = ndimage.label(ndimage.binary_closing(np.array(img)[:, :, 3] > 40, iterations=2))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if (lab[sl] == i + 1).sum() > 4000:
            out.append((sl[1].start, img.crop((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))))
    return [im for _, im in sorted(out, key=lambda t: t[0])]

def face(img, centre, span, tint):
    """A round portrait: the part of `img` around `centre` (as shares of its size), `span` wide."""
    w = span * img.width
    cx, cy = centre[0] * img.width, centre[1] * img.height
    crop = img.crop((round(cx - w / 2), round(cy - w / 2), round(cx + w / 2), round(cy + w / 2))).resize((SIZE * 2, SIZE * 2), Image.LANCZOS)
    disc = Image.new("RGBA", (SIZE * 2, SIZE * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(disc)
    d.ellipse([4, 4, SIZE * 2 - 5, SIZE * 2 - 5], fill=tint)
    disc.alpha_composite(crop)
    mask = Image.new("L", (SIZE * 2, SIZE * 2), 0)
    ImageDraw.Draw(mask).ellipse([4, 4, SIZE * 2 - 5, SIZE * 2 - 5], fill=255)
    disc.putalpha(Image.fromarray(np.minimum(np.array(disc)[:, :, 3], np.array(mask))))
    ring = ImageDraw.Draw(disc)
    ring.ellipse([4, 4, SIZE * 2 - 5, SIZE * 2 - 5], outline=(60, 34, 12, 255), width=12)
    ring.ellipse([8, 8, SIZE * 2 - 9, SIZE * 2 - 9], outline=(255, 214, 110, 255), width=7)
    return disc.resize((SIZE, SIZE), Image.LANCZOS)

parts, props, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
adeline = standing(build_rig.ADELINE, parts, 1.0)
sister = standing(build_rig.SISTER, parts, 1.0)
merlin = Image.open(os.path.join(props, "merlin.png")).convert("RGBA")
merlin = merlin.crop(merlin.getbbox())
people = figures(os.path.join(props, "m2_parents.png"))
print("sheets:", adeline.size, sister.size, merlin.size, [p.size for p in people])
adeline.save("/tmp/face_src_adeline.png"); sister.save("/tmp/face_src_sister.png"); merlin.save("/tmp/face_src_merlin.png")
for i, p in enumerate(people): p.save("/tmp/face_src_parent_%d.png" % i)
# who: (picture, where the face is, how much of the picture to show, background)
WHO = {
    "adeline": (adeline, (0.50, 0.15), 0.74, (196, 170, 235, 255)),
    "sister": (sister, (0.50, 0.21), 1.0, (255, 226, 150, 255)),
    "merlin": (merlin, (0.47, 0.19), 0.6, (160, 200, 240, 255)),
    "mom": (people[0], (0.61, 0.17), 0.8, (250, 190, 200, 255)),
    "dad": (people[1], (0.52, 0.15), 0.44, (180, 220, 170, 255)),
}
for name, (img, centre, span, tint) in WHO.items():
    face(img, centre, span, tint).save(os.path.join(out, "face_%s.png" % name))
print("faces", list(WHO))
