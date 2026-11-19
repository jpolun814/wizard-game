"""The water of the Water Jet and the Geyser (scripts/fx/water_pixels.gd), in the colors of the ponds (Pond.WATER_*): short tiles of a stream, cut across it, in widths
from 4 to 48 pixels in steps of 4, four frames each , the mound the Geyser wells up from, and the curling wave of Tide Surf.
Run it from anywhere:

    python tools/wizard_parts/water.py

It writes art/fx/water_stream.png and water_mound.png. Never edit the PNGs by hand: change this file and run it.

water_stream.png: tiles 8 along by 48 across, frame k at x = k*8. Rows 0-11 are the widths, lit on one side (the jet: light above, dark below); rows 12-23 are lit on both
sides (the Geyser's column).
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
TOP = (38, 87, 128)
BOTTOM = (13, 26, 61)
RIM = (153, 199, 224)
LIGHT = (58, 110, 150)
LEN, MAXW, FRAMES = 8, 48, 4


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def stream_tile(width, frame, both):
    tile = Image.new("RGBA", (LEN, MAXW), (0, 0, 0, 0))
    top = (MAXW - width) // 2
    for y in range(width):
        t = y / max(width - 1, 1)
        edge = min(y, width - 1 - y) if both else y
        if edge == 0:
            color, alpha = RIM, 255
        elif both:
            color, alpha = mix(LIGHT, TOP, min(edge / (width / 2), 1.0) * 0.9), 255
            if edge == 1:
                color = mix(RIM, LIGHT, 0.5)
        else:
            color = mix(LIGHT, BOTTOM, t)
            alpha = 255
            if y == width - 1:
                color, alpha = mix(RIM, BOTTOM, 0.6), 255
        for x in range(LEN):
            c = color
            tile.putpixel((x, top + y), c + (alpha,))
    return tile


def make_stream():
    widths = list(range(4, MAXW + 1, 4))
    sheet = Image.new("RGBA", (LEN * FRAMES, MAXW * len(widths) * 2), (0, 0, 0, 0))
    for group, both in enumerate((False, True)):
        for row, width in enumerate(widths):
            for frame in range(FRAMES):
                sheet.paste(stream_tile(width, frame, both), (frame * LEN, (group * len(widths) + row) * MAXW))
    sheet.save(os.path.join(ROOT, "art", "fx", "water_stream.png"))


def make_mound():
    """Water welling up on the ground: three sizes of a low mound, 24, 48 and 72 wide, side by side."""
    sizes = [(24, 5), (48, 9), (72, 12)]
    sheet = Image.new("RGBA", (sum(s[0] for s in sizes), 14), (0, 0, 0, 0))
    x0 = 0
    for w, h in sizes:
        for x in range(w):
            u = (x - (w - 1) / 2) / (w / 2)
            height = h * (1 - u * u) ** 0.7
            for k in range(int(round(height))):
                y = 13 - k
                c = RIM if k == int(round(height)) - 1 else mix(LIGHT, BOTTOM, k / max(h, 1) * -1 + 0.4)
                sheet.putpixel((x0 + x, y), c + (255,))
        x0 += w
    sheet.save(os.path.join(ROOT, "art", "fx", "water_mound.png"))


make_stream()
make_mound()
