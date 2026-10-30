"""Makes art/tiles/ash.png: the ground of the ashlands. It is the graveyard's tile set (art/tiles/cemetery.png, from the Gothicvania
Cemetery tiles by ansimuz, CC0) turned: the green turf becomes a crust of glowing embers and the brown earth becomes dark basalt, so
every tile keeps its place in the atlas. Run with: python -I tools/prepare_ash_tiles.py"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
SOURCE = os.path.join(ROOT, "art", "tiles", "cemetery.png")
OUT = os.path.join(ROOT, "art", "tiles", "ash.png")

EMBER_HUE = 14 / 360.0  # an orange-red


def turned(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    degrees = h * 360.0
    if 55.0 <= degrees <= 175.0 and s > 0.25:  # turf: the grass, yellow-green to green
        h, s, v = EMBER_HUE + (degrees - 100.0) / 360.0 * 0.06, min(1.0, s * 1.05), min(1.0, v * 0.95 + 0.05)
    elif (0.0 <= degrees <= 45.0 or degrees >= 340.0) and s > 0.25:  # earth: brown and rust
        h, s, v = 0.02, s * 0.28, v * 0.8
    r2, g2, b2 = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return int(round(r2 * 255)), int(round(g2 * 255)), int(round(b2 * 255))


image = Image.open(SOURCE).convert("RGBA")
pixels = image.load()
for x in range(image.width):
    for y in range(image.height):
        r, g, b, a = pixels[x, y]
        if a:
            pixels[x, y] = turned(r, g, b) + (a,)
image.save(OUT)
print("wrote", OUT)
