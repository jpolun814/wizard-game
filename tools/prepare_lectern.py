"""Builds the lectern's two sprites.

    python -I tools/prepare_lectern.py <download>/DungeonSetPieces.png art/aseprite/plaque.aseprite

The stand is the stone tomb in nikllamadev's Dungeon Castle pixel art pack (CC-BY 4.0), made wider and taller by repeating one column and one row of its own body, so a book and a plaque fit it. The plaque is the owner's own pixel art
(plaque.aseprite, 64x64, one layer): it is cropped to its edges, and the black scribble that stood for writing is filled with the plate's gold, so the
words can be lettered over it by scripts/screens/lectern.gd.
"""
import struct
import sys
import zlib

import numpy as np
from PIL import Image


def read_aseprite(path: str) -> Image.Image:
    """The first frame of an .aseprite file, with its cels laid over each other."""
    data = open(path, "rb").read()
    _, magic, frames, w, h, depth = struct.unpack_from("<IHHHHH", data, 0)
    assert magic == 0xA5E0 and depth == 32, "only RGBA files are read"
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pos = 128
    _, _, old, _, _, new = struct.unpack_from("<IHHHHI", data, pos)
    at = pos + 16
    for _ in range(new or old):
        size, kind = struct.unpack_from("<IH", data, at)
        if kind == 0x2005:
            x, y = struct.unpack_from("<hh", data, at + 8)
            storage = struct.unpack_from("<H", data, at + 13)[0]
            cw, ch = struct.unpack_from("<HH", data, at + 22)
            if storage == 2:
                out.alpha_composite(Image.frombytes("RGBA", (cw, ch), zlib.decompress(data[at + 26: at + size])), (x, y))
        at += size
    return out


sheet = Image.open(sys.argv[1]).convert("RGBA")
tomb = sheet.crop((194, 100, 238, 120))  # 44 x 20: the lid, the panels and the foot
WIDEN, RAISE, SEAM_COL, SEAM_ROW = 24, 43, 22, 13  # the column and row (of the panels) that are repeated, and how often
cols = list(range(SEAM_COL)) + [SEAM_COL] * WIDEN + list(range(SEAM_COL, tomb.width))
rows = list(range(SEAM_ROW)) + [SEAM_ROW] * RAISE + list(range(SEAM_ROW, tomb.height))
stand = Image.new("RGBA", (len(cols), len(rows)))
for y, sy in enumerate(rows):
    for x, sx in enumerate(cols):
        stand.putpixel((x, y), tomb.getpixel((sx, sy)))
stand.save("art/props/lectern_stand.png")

plaque = read_aseprite(sys.argv[2])
plaque = plaque.crop(plaque.getbbox())
px = np.array(plaque)
solid = px[:, :, 3] > 0
dark = solid & (px[:, :, :3].sum(axis=2) < 60)
edge = np.pad(~solid, 1, constant_values=True)  # outside the plaque, and a rim round the picture
outline = dark & (edge[:-2, 1:-1] | edge[2:, 1:-1] | edge[1:-1, :-2] | edge[1:-1, 2:])
writing = dark & ~outline
plate = px[solid & ~dark][:, :3]
colour = np.median(plate, axis=0).astype(np.uint8)
px[writing, :3] = colour
# the gold of the corners of the spellbook, in place of the plaque's own yellow, so the two belong to one place
for old, new in {tuple(colour): (222, 158, 65), (255, 228, 0): (245, 196, 112), (0, 0, 0): (84, 50, 24)}.items():
    px[solid & (px[:, :, :3] == old).all(axis=2), :3] = new
Image.fromarray(px).save("art/props/lectern_plaque.png")
print("plaque", plaque.size, "plate", tuple(colour), "filled", int(writing.sum()))
