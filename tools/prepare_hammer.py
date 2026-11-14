"""Cuts the iron hammer for the cut-scene after a win from FacadeGaikan's tool icons (CC0, see art/CREDITS.md).

    python -I tools/prepare_hammer.py <tool-facadegaikan.png>

The sheet is 3 x 4 icons of 32 px. The iron hammer is the middle one of the second row: its head is at the top left and its handle runs down to the
right. It is trimmed to its edges, and the point where the handle ends, where a hand would hold it, is printed for scripts/screens/epilogue.gd.
"""
import sys
from PIL import Image

icon = Image.open(sys.argv[1]).convert("RGBA").crop((32, 32, 64, 64))
box = icon.getbbox()
hammer = icon.crop(box)
hammer.save("art/props/hammer.png")
print("size", hammer.size)
