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
    """The wave of Tide Surf, seen from the side as it travels right: 200 wide and 80 tall, six frames one under another. A swell rises behind the rider to a crest that
    leans over and curls forward, and under the lip there is a hollow, a barrel, where the rider stands (x 118 of the picture is the rider's feet, and the bottom of the
    picture is a little below them). The water is see-through, thicker toward its surface and thinning toward the bottom and the back; the surface is lit and rimmed with
    foam, foam clots along the lip, drops fly off its tip, and bright streaks run up the wall. The crest differs a little in each frame. The foot breaks up into spray.
    The outline is laid out as points and filled; the shading is by how deep each pixel is in it."""
    import math
    import random
    from PIL import ImageDraw
    w, h, frames = 200, 80, 6
    foam = (236, 247, 255)
    foam_shade = (190, 222, 240)
    base = [(0, 79), (0, 75), (18, 71), (38, 62), (56, 46), (70, 30), (84, 16), (100, 8), (116, 8), (128, 13), (136, 21), (139, 30), (134, 33), (131, 27), (124, 22),
            (115, 21), (106, 26), (100, 36), (98, 50), (102, 64), (110, 75), (116, 79)]

    def dense(points):
        out = []
        for i in range(len(points) - 1):
            (x0, y0), (x1, y1) = points[i], points[i + 1]
            n = max(int(math.hypot(x1 - x0, y1 - y0) / 3), 1)
            for k in range(n):
                out.append((x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n))
        out.append(points[-1])
        return out

    sheet = Image.new("RGBA", (w, h * frames), (0, 0, 0, 0))
    for f in range(frames):
        rng = random.Random(300 + f)
        swing = math.sin(f / frames * 2 * math.pi)
        ragged = []
        for (x, y) in dense(base):
            lip = max(0.0, min(1.0, (x - 84) / 40.0)) if y < 44 else 0.0
            ragged.append((x + rng.uniform(-1, 1) * 2.0 * lip + 1.5 * swing * lip, y + rng.uniform(-1, 1) * 2.0 * lip + 1.0 * swing * lip))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).polygon(ragged, fill=255)
        m = mask.load()

        def inside(x, y):
            return 0 <= x < w and 0 <= y < h and m[x, y] > 0

        depth = {}
        for y in range(h):
            for x in range(w):
                if not inside(x, y):
                    continue
                d = 0
                while d < 7 and all(inside(x + dx * (d + 1), y + dy * (d + 1)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    d += 1
                depth[(x, y)] = d
        for (x, y), d in depth.items():
            near_lip = 84 < x < 142 and y < 50
            clot = near_lip and d <= 4 and rng.random() < (0.85 - d * 0.17)
            if d == 0:
                c = foam if (not inside(x, y - 1) and x > 50) or clot else RIM
                alpha = 255
            elif clot:
                c, alpha = (foam if d < 3 else foam_shade), 235
            elif d == 1:
                c, alpha = (RIM if y < 50 else mix(RIM, LIGHT, 0.6)), 235
            elif d == 2:
                c, alpha = mix(RIM, LIGHT, 0.7), 215
            else:
                # see-through: thicker toward the surface and the lip, thinning toward the bottom and the back of the swell
                c = mix(LIGHT, BOTTOM, min(max(y - 8, 0) / 70.0, 1.0))
                alpha = int(max(120, 215 - (y - 8) * 1.1 - max(0, 60 - x) * 0.6))
            sheet.putpixel((x, f * h + y), c + (alpha,))
        # drops flying off the tip of the lip and the top of the crest
        for k in range(10):
            ang = rng.uniform(-2.2, 0.8)
            dist = rng.uniform(4, 16)
            x, y = int(138 + math.cos(ang) * dist), int(24 + math.sin(ang) * dist)
            if 0 <= x < w and 0 <= y < h and not inside(x, y):
                sheet.putpixel((x, f * h + y), foam + (255,))
                if rng.random() < 0.4 and x + 1 < w:
                    sheet.putpixel((x + 1, f * h + y), foam_shade + (255,))
        # bright streaks running up the back of the swell and the wall of the barrel
        for k in range(8):
            t0 = (k * 0.125 + f / frames * 0.5) % 1.0
            x = 20 + t0 * 80
            y = 72 - (x - 20) * 0.62 - (k % 3) * 4
            for t in range(4):
                px, py = int(x + t), int(y - t * 0.6)
                if (px, py) in depth and depth[(px, py)] >= 3:
                    sheet.putpixel((px, f * h + py), STREAK + (230,))
    # the foot of the wave is not a straight line: its last rows break up into spray, a dither that thins toward the ground, with foam where it breaks
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for f in range(frames):
        for y in range(h - 14, h):
            fade = ((y - (h - 14)) / 13.0) ** 1.4
            for x in range(w):
                if sheet.getpixel((x, f * h + y))[3] == 0:
                    continue
                if bayer[(y + f) % 4][(x + f * 2) % 4] / 16.0 < fade * 1.05:
                    sheet.putpixel((x, f * h + y), (0, 0, 0, 0))
                elif fade > 0.2 and y + 1 < h and sheet.getpixel((x, f * h + y + 1))[3] == 0:
                    sheet.putpixel((x, f * h + y), foam + (255,))
    sheet.save(os.path.join(ROOT, "art", "fx", "water_wave.png"))


make_stream()
make_mound()
make_wave()
