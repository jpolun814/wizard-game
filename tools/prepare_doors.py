"""Makes art/props/door.png: a plain wooden door seen from the front, cut to its edges, from "LPC Animated Doors" by Lanea Zimmerman
(Sharm) (opengameart.org/content/lpc-animated-doors), CC-BY 3.0. The game swings it open by squeezing it toward its hinge.
Run with: python -I tools/prepare_doors.py <lpc-doors-animated-1.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
sheet = Image.open(sys.argv[1]).convert("RGBA")
door = sheet.crop((0, 288, 64, 336))  # the plain wooden door, front on
door = door.crop(door.getbbox())
door.save(os.path.join(ROOT, "art", "props", "door.png"))
print("wrote door", door.size)
