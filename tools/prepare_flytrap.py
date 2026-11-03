"""Cuts the Flytrap's frames from the "Pixel Predator Plant Mob Character" pack (OGA-BY 3.0, see art/CREDITS.md).

    python -I tools/prepare_flytrap.py <folder holding Attack/Plant3_Attack_full.png>

The pack's attack sheet is 64 px frames, seven to a row. The third row is the plant side-on, facing left: its first four frames are the mouth
open and swaying, the last three the lunge that shuts it. Writes art/props/flytrap.png, six frames side by side: three of waiting, three of the snap.
"""
import os
import sys

from PIL import Image

FRAME = 64
WAITING = [1, 2, 3]
SNAP = [4, 5, 6]
ROW = 2

source = os.path.join(sys.argv[1], "Attack", "Plant3_Attack_full.png")
sheet = Image.open(source).convert("RGBA")
out = Image.new("RGBA", (FRAME * 6, FRAME), (0, 0, 0, 0))
for slot, column in enumerate(WAITING + SNAP):
    frame = sheet.crop((column * FRAME, ROW * FRAME, (column + 1) * FRAME, (ROW + 1) * FRAME))
    out.paste(frame, (slot * FRAME, 0))
target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "props", "flytrap.png")
out.save(target)
print("wrote", target)
