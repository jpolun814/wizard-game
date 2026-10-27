"""Makes art/props/bonfire_logs.png: the stone hearth a bonfire burns on, seen from the side, cut from the bottom of the first frame of
"Campfire pixel art animated" by ArlanTR (opengameart.org/content/campfire-pixel-art-animated, CC0). Run with:
python -I tools/prepare_bonfire.py <campfire-sprite-sheet.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
frame = Image.open(sys.argv[1]).convert("RGBA").crop((0, 0, 32, 32))
hearth = frame.crop((3, 21, 29, 26))  # the stone slab and its shadowed underside, under the flames
hearth.save(os.path.join(ROOT, "art", "props", "bonfire_logs.png"))
print("wrote hearth", hearth.size)
