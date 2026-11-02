"""Makes art/props/bonfire_logs.png: the pile of firewood a bonfire burns on, seen from the side, cut from "FREE Platformer Assets" by
GandalfHardcore (gandalfhardcore.itch.io/free-pixel-art-sidescroller-asset-pack-32x32-overworld): the stack of logs in Decor.png. Run with:
python -I tools/prepare_bonfire.py <Decor.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
sheet = Image.open(sys.argv[1]).convert("RGBA")
logs = sheet.crop((198, 72, 252, 100))
logs = logs.crop(logs.getbbox())
pixels = logs.load()
for x in range(logs.width):
    for y in range(logs.height):
        r, g, b, a = pixels[x, y]
        if a > 0:  # weathered: darker, and the pale cut ends are pulled toward the brown of the bark, so it sits in the dark world
            light = (0.3 * r + 0.59 * g + 0.11 * b) * 0.7
            pixels[x, y] = (int(0.5 * r * 0.7 + 0.5 * light * 1.08), int(0.5 * g * 0.7 + 0.5 * light * 0.8), int(0.5 * b * 0.7 + 0.5 * light * 0.58), a)
logs.save(os.path.join(ROOT, "art", "props", "bonfire_logs.png"))
print("wrote logs", logs.size)
