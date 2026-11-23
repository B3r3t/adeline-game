"""Fits the saddle picture onto Spirit's body. The result is a layer the same size as
Spirit's body picture, so the game can lay one exactly over the other.
Run: python3 build_saddle.py props/saddle_src.png ../art/spirit"""
import sys
import numpy as np
from PIL import Image, ImageDraw

WIDTH, CENTRE_X, TOP = 84, 84, 84  # where the saddle sits, in pixels of the body picture
GIRTH = (74, 81, 150, 200)  # the strap carried on down and under the belly

src, out = sys.argv[1], sys.argv[2]
body = Image.open(out + "/body.png").convert("RGBA")
art = Image.open(src).convert("RGBA")
art = art.crop(art.getbbox()).transpose(Image.FLIP_LEFT_RIGHT)  # drawn facing left; Spirit faces right
k = WIDTH / art.width
art = art.resize((round(art.width * k), round(art.height * k)), Image.LANCZOS)
layer = Image.new("RGBA", body.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(layer)
x0, x1, y0, y1 = GIRTH
draw.rectangle([x0, y0, x1, y1], fill=(38, 20, 12, 255))
draw.rectangle([x0 + 1, y0, x1 - 1, y1], fill=(150, 78, 38, 255))
layer.alpha_composite(art, (round(CENTRE_X - art.width / 2), TOP))
# Below the back, straps only show where there is horse behind them.
pixels = np.array(layer)
behind = np.array(body)[:, :, 3].astype(np.float32) / 255.0
rows = np.arange(pixels.shape[0])[:, None]
pixels[:, :, 3] = (pixels[:, :, 3] * np.where(rows > 135, behind, 1.0)).astype(np.uint8)
Image.fromarray(pixels).save(out + "/saddle.png")
print("saddle layer", layer.size)
