"""The water of the Water Jet and the Geyser (scripts/fx/water_pixels.gd), in the colors of the ponds (Pond.WATER_*): short tiles of a stream, cut across it, in widths
from 4 to 48 pixels in steps of 4, four frames each (the bright streaks run along it), the mound the Geyser wells up from, and the curling wave of Tide Surf.
Run it from anywhere:

    python tools/wizard_parts/water.py

It writes art/fx/water_stream.png, water_mound.png and water_wave.png. Never edit the PNGs by hand: change this file and run it.

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
STREAK = (205, 228, 240)
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
            # bright streaks racing along it: a few pixels that move a little each frame
            if 0 < edge < width - 1 and width >= 8 and ((x + frame * 2 + (y // 4) * 3) % LEN < 3) and (y % 4 == 1):
                c = STREAK
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


def make_wave():
    """The wave of Tide Surf: 176 wide and 56 tall, four frames one under another (flecks of bright water run up it). The tail is on the left, low, and it swells to a crest
    on the right that leans over and curls, with a hollow under the lip. The outline is laid out as points and filled; the shading is by how deep each pixel is in it."""
    from PIL import ImageDraw
    w, h, frames = 176, 56, 4
    foam = (236, 247, 255)
    outline = [(0, 55), (0, 51), (18, 47), (44, 40), (70, 30), (96, 18), (116, 10), (134, 6), (150, 7), (160, 12), (165, 20), (163, 28), (157, 32), (156, 27), (151, 22),
               (144, 21), (138, 26), (136, 36), (140, 46), (147, 55)]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    m = mask.load()

    def inside(x, y):
        return 0 <= x < w and 0 <= y < h and m[x, y] > 0

    depth = {}
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            d = 0
            while d < 6 and all(inside(x + dx * (d + 1), y + dy * (d + 1)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                d += 1
            depth[(x, y)] = d
    sheet = Image.new("RGBA", (w, h * frames), (0, 0, 0, 0))
    for f in range(frames):
        for (x, y), d in depth.items():
            top_edge = not inside(x, y - 1)
            if d == 0:
                c = foam if top_edge and x > 60 else RIM
            elif d == 1:
                c = RIM if y < 40 else mix(RIM, LIGHT, 0.6)
            elif d == 2:
                c = mix(RIM, LIGHT, 0.7)
            else:
                c = mix(LIGHT, BOTTOM, min(max(y - 6, 0) / 50.0, 1.0))
            sheet.putpixel((x, f * h + y), c + (255,))
        # flecks of bright water running up the face, a few pixels at a time
        for k in range(7):
            x0 = 14 + k * 21
            run = (k * 5 + f * 5) % 20
            for t in range(4):
                x, y = x0 + run + t, 50 - (x0 + run + t) * 0.28 - (k % 3) * 5
                if (int(x), int(y)) in depth and depth[(int(x), int(y))] >= 3:
                    sheet.putpixel((int(x), f * h + int(y)), STREAK + (255,))
    # the foot of the wave is not a straight line: its last rows break up into spray, a dither that thins toward the ground, with foam where it breaks
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for f in range(frames):
        for y in range(h - 16, h):
            fade = ((y - (h - 16)) / 15.0) ** 1.4  # 0 at the top of the break, 1 at the ground
            for x in range(w):
                if sheet.getpixel((x, f * h + y))[3] == 0:
                    continue
                if bayer[(y + f) % 4][(x + f * 2) % 4] / 16.0 < fade * 1.05:
                    sheet.putpixel((x, f * h + y), (0, 0, 0, 0))
                elif fade > 0.2 and y > 0 and sheet.getpixel((x, f * h + y + 1))[3] == 0 if y + 1 < h else False:
                    sheet.putpixel((x, f * h + y), foam + (255,))
    sheet.save(os.path.join(ROOT, "art", "fx", "water_wave.png"))


make_stream()
make_mound()
make_wave()
