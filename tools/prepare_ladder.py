"""Makes art/props/rope_ladder.png: a 32x32 piece of rope ladder that tiles up and down, cut from the "Rope Ladder" tileset by AntumDeluge
(opengameart.org/content/rope-ladder, CC-BY 3.0 / OGA-BY 3.0: credit required), the brown ladder, darkened to old tarred rope.
Run with: python -I tools/prepare_ladder.py <rope_ladder_2.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
sheet = Image.open(sys.argv[1]).convert("RGBA")
tile = sheet.crop((0, 64, 32, 96))  # two rungs, 16 rows apart: the same at the top and the bottom, so it tiles
for x in range(tile.width):
    for y in range(tile.height):
        r, g, b, a = tile.getpixel((x, y))
        if a:
            grey = (r + g + b) / 3.0
            tile.putpixel((x, y), (int((r * 0.5 + grey * 0.5) * 0.62), int((g * 0.5 + grey * 0.5) * 0.55), int((b * 0.5 + grey * 0.5) * 0.5), a))
tile.save(os.path.join(ROOT, "art", "props", "rope_ladder.png"))
print("wrote rope ladder", tile.size)
