"""Builds art/props/magic_mirror.png: the animated oval mirror of "Magic Mirror/Portal Pixel Sprite" (That One Annoying Pub Player, CC0,
https://opengameart.org/content/magic-mirrorportal-pixel-sprite), recoloured to the game's look: a gold rim with a dark edge round it, and violet glass
with a glint that sweeps across it. Only the still frames are used (16 to 39 of the sheet: the glass, and its glints), not the opening or the cracking.

    python -I tools/prepare_mirror.py path/to/MagicMirror.png

The frames come out side by side in one strip, each 18 by 32 pixels.
"""
import os
import sys

from PIL import Image

FIRST, LAST = 16, 39  # the frames of the sheet that are kept (8 to a row, each 32 by 32)
BOX = (8, 1, 24, 31)  # the mirror inside a frame
RIM = (222, 158, 65, 255)   # the plaque's gold
EDGE = (84, 50, 24, 255)    # the dark edge round the rim
GLASS = (104, 80, 168, 255)
GLINT = (150, 128, 210, 255)
SHINE = (250, 240, 255, 255)
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "props", "magic_mirror.png")


def recolour(frame):
    out = Image.new("RGBA", (frame.width + 2, frame.height + 2), (0, 0, 0, 0))
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = frame.getpixel((x, y))
            if a == 0:
                continue
            if (r, g, b) == (34, 217, 80):
                new = RIM
            elif (r, g, b) == (0, 255, 255):
                new = GLASS
            elif (r, g, b) == (61, 229, 229):
                new = GLINT
            else:
                new = SHINE
            out.putpixel((x + 1, y + 1), new)
    solid = out.copy()
    for y in range(out.height):  # a dark edge on every empty pixel that touches the mirror
        for x in range(out.width):
            if solid.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < out.width and 0 <= ny < out.height and solid.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), EDGE)
                        break
    return out


def main():
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    frames = []
    for k in range(FIRST, LAST + 1):
        col, row = k % 8, k // 8
        cell = sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32)).crop(BOX)
        frames.append(recolour(cell))
    strip = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for k, frame in enumerate(frames):
        strip.paste(frame, (k * frame.width, 0))
    strip.save(OUT, optimize=True)
    print("saved", OUT, strip.size, len(frames), "frames")


main()
