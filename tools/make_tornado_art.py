"""Draws art/fx/tornado.png: a funnel of wind, 60 frames of 96 x 96 in one strip (frames 0-15 its birth out of the ground, frames 16-59 its loop;
`tornado.gd` plays them in that order and the birth backwards when it dies). Drawn here, pixel by pixel, so the game owns it: it replaces a download whose
licence was never stated, which had also been scaled down smooth and so was not true pixel art.

How it is built: the funnel is a stack of rows, each a band of cloud that is wide at the top and narrow at the ground. Every row is shaded across (light on
the left, dark on the right) and crossed by swirl bands that turn as the frames go on; an ordered dither lays the shades. Rims of the discs the cloud is
stacked from are drawn over the body, and a dark line is put round the whole shape. Stones and leaves ride round it, behind it and in front, and dust boils
at its foot. Every motion in the loop turns a whole number of times over its 44 frames, so the loop joins up without a jump.
Run with: python -I tools/make_tornado_art.py"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SIZE = 96
FRAMES = 60
BIRTH = 16        # frames 0-15 are the birth; the loop is the rest
LOOP = FRAMES - BIRTH
MARGIN = 3       # nothing is drawn this close to a frame's left or right edge, or it bleeds into the next frame's cell
GROUND = 93       # the row the funnel stands on
HEIGHT = 83       # how tall it is when grown

# Light to dark, wind-grey with a blue cast (the world's cloud colors).
RAMP = [(226, 238, 250), (186, 208, 230), (146, 172, 204), (106, 128, 160), (74, 90, 118), (50, 62, 86)]
OUTLINE = (24, 30, 44)
RIM_LIGHT = (238, 246, 255)
RIM_DARK = (58, 72, 98)
DUST = [(150, 148, 160), (118, 116, 130), (88, 86, 100)]
STONE = [(128, 112, 96), (78, 68, 62), (196, 188, 172)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def radius(h: float, grown: float) -> float:
    """Half the funnel's width at a height (0 on the ground, 1 at the top)."""
    return (2.5 + 27.0 * h ** 1.3) * (0.5 + 0.5 * grown)


def lean(h: float, ph: float) -> float:
    """How far the column is bent to the side at a height: the funnel sways about, more toward the top, and ends on the same bend each loop."""
    return 12.0 * h * math.sin(ph * math.tau + h * 3.2) + 5.0 * h * h * math.sin(ph * 2 * math.tau + 1.0) - 1.0 * h * h


def funnel(ph: float, grown: float) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE))
    top = GROUND - int(HEIGHT * grown)
    for y in range(max(top, 0), GROUND + 1):
        h = (GROUND - y) / HEIGHT
        r = radius(h, grown) * (1.0 + 0.1 * math.sin(y * 0.9 + ph * math.tau * 2) + 0.07 * math.sin(y * 2.3 - ph * math.tau * 3) * min(1.0, h * 3.0))
        cx = SIZE * 0.5 + lean(h, ph)
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            u = (x + 0.5 - cx) / r
            if abs(u) > 1.0 or not MARGIN <= x < SIZE - MARGIN:
                continue
            theta = math.asin(u)
            swirl = math.sin(2.0 * theta + ph * math.tau * 2 + h * 6.0) * 0.6 + math.sin(3.0 * theta - ph * math.tau + h * 4.0 + 1.0) * 0.4
            light = 0.52 - 0.34 * u + 0.3 * swirl - 0.12 * h
            if abs(u) > 0.86:
                light -= 0.18  # the edge, turning away
            tone = (1.0 - min(max(light, 0.0), 0.999)) * (len(RAMP) - 1)  # 0 is the lightest
            base = int(tone)
            if tone - base > (BAYER[y % 4][x % 4] + 0.5) / 16.0:
                base += 1
            img.putpixel((x, y), RAMP[min(base, len(RAMP) - 1)] + (255,))
    # The rims of the discs the cloud is stacked from: a light line on the near side and a dark one on the far.
    step = 9.0
    k = 0
    while GROUND - k * step > top:
        yc = GROUND - k * step - (ph * step * 2 % step if grown >= 1.0 else 0.0)  # the discs climb as the cloud turns
        k += 1
        h = (GROUND - yc) / HEIGHT
        if h <= 0 or yc < top:
            continue
        r = radius(h, grown)
        cx = SIZE * 0.5 + lean(h, ph)
        b = max(1.2, r * 0.17)
        for x in range(int(cx - r), int(cx + r) + 1):
            u = (x + 0.5 - cx) / r
            if abs(u) >= 1.0 or not MARGIN <= x < SIZE - MARGIN:
                continue
            depth = b * math.sqrt(1.0 - u * u)
            near = int(round(yc + depth + math.sin(x * 0.7 + k) * 0.8))
            if -0.95 < u < 0.45 and 0 <= near < SIZE and img.getpixel((x, near))[3] and (x + k) % 5 != 0:
                img.putpixel((x, near), RAMP[0] + (255,) if u < 0.1 else RAMP[1] + (255,))
    # The storm cloud the funnel hangs from: a lumpy dark cap that is a little wider than the column at its top and thins out over it, so it joins the funnel
    # and does not sit on it like a lid.
    spread = (radius(1.0, grown) * 1.12 + 3.0) * min(1.0, max(0.0, (grown - 0.5) / 0.4))
    if spread >= 7.0:
        cx = SIZE * 0.5 + lean((GROUND - top) / HEIGHT, ph)
        for x in range(int(cx - spread), int(cx + spread) + 1):
            if not MARGIN <= x < SIZE - MARGIN:
                continue
            u = (x - cx) / spread
            lump = 0.72 + 0.28 * math.sin(x * 0.55 + ph * math.tau * 2) * math.cos(x * 0.21 - ph * math.tau)  # the cloud is thicker in places
            above = 5.0 * math.sqrt(max(0.0, 1.0 - u * u)) * lump
            below = 3.0 * (1.0 - abs(u)) * lump + 1.0
            for y in range(int(top - above), int(top + below) + 1):
                if not 0 <= y < SIZE:
                    continue
                v = (y - top) / max(above, 1.0) if y < top else (y - top) / max(below, 1.0)
                light = 0.6 - 0.3 * u - 0.35 * v + 0.15 * math.sin(x * 0.6 + ph * math.tau * 2 + y * 0.4)
                t = (1.0 - min(max(light, 0.0), 0.999)) * (len(RAMP) - 1)
                base = int(t)
                if t - base > (BAYER[y % 4][x % 4] + 0.5) / 16.0:
                    base += 1
                img.putpixel((x, y), RAMP[min(base + 1, len(RAMP) - 1)] + (255,))
    return img


def outlined(img: Image.Image) -> Image.Image:
    out = img.copy()
    for x in range(SIZE):
        for y in range(SIZE):
            if img.getpixel((x, y))[3] == 0 and any(
                    0 <= x + dx < SIZE and 0 <= y + dy < SIZE and img.getpixel((x + dx, y + dy))[3]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), OUTLINE + (255,))
    return out


# Things the wind carries: height (0-1), how far out from the column, the angle it starts at, how many times it goes round per loop, and what it is.
DEBRIS = [(0.12, 1.5, 0.3, 2, 0), (0.2, 1.3, 2.4, 1, 1), (0.28, 1.45, 4.1, 2, 2), (0.36, 1.25, 1.2, 1, 0), (0.44, 1.4, 5.0, 2, 1),
          (0.52, 1.3, 3.1, 1, 2), (0.6, 1.5, 0.9, 2, 0), (0.66, 1.25, 4.4, 1, 1), (0.74, 1.4, 2.0, 2, 2), (0.8, 1.3, 5.6, 1, 0),
          (0.88, 1.45, 3.6, 2, 1), (0.95, 1.2, 1.5, 1, 2), (0.3, 1.7, 3.9, 1, 1), (0.58, 1.75, 0.2, 1, 0)]


def debris(ph: float, grown: float, front: bool) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE))
    for h, out, a0, turns, kind in DEBRIS:
        if h > grown:
            continue
        h2 = h * (0.4 + 0.6 * grown)
        a = a0 + ph * math.tau * turns
        if (math.sin(a) > 0) != front:
            continue
        r = radius(h2, grown) * out
        cx = SIZE * 0.5 + lean(h2, ph) + r * math.cos(a)
        y = GROUND - h2 * HEIGHT + radius(h2, grown) * 0.17 * math.sin(a) * out
        x, y = int(round(cx)), int(round(y))
        for dx in range(3 if kind != 2 else 2):
            for dy in range(2 if kind != 1 else 3):
                if MARGIN <= x + dx < SIZE - MARGIN and 0 <= y + dy < SIZE:
                    img.putpixel((x + dx, y + dy), STONE[kind] + (255,))
    return img


def dust(ph: float, grown: float, front: bool, birth: float) -> Image.Image:
    """Dust boiling out at the foot; more of it, and wider, while the tornado is being born."""
    img = Image.new("RGBA", (SIZE, SIZE))
    spread = 16.0 + 18.0 * (1.0 - grown) + 8.0 * birth
    for i in range(30):
        a = math.tau * i / 30.0 + ph * math.tau * (1 if i % 2 else 2) * 0.5
        if (math.sin(a) > 0) != front:
            continue
        rr = spread * (0.45 + 0.55 * ((i * 7) % 10) / 10.0 + 0.12 * math.sin(ph * math.tau * 2 + i))
        x = int(round(SIZE * 0.5 + rr * math.cos(a)))
        y = int(round(GROUND + 1 + 0.17 * rr * math.sin(a) * 1.4 - 2.0 * ((i * 3) % 4) * (0.5 + 0.5 * math.sin(ph * math.tau * 2 + i * 1.3))))
        tone = DUST[(i + int(ph * 8)) % 3 if birth > 0.0 else i % 3]
        for dx in range(2):
            if MARGIN <= x + dx < SIZE - MARGIN and 0 <= y < SIZE:
                img.putpixel((x + dx, y), tone + (255,))
                if i % 3 == 0 and 0 <= y - 1 < SIZE:
                    img.putpixel((x + dx, y - 1), tone + (255,))
    return img


def frame(f: int) -> Image.Image:
    ph = (f - BIRTH) / LOOP  # the loop starts at phase 0 on frame 16, so the birth runs into it
    if f < BIRTH:
        t = (f + 1) / BIRTH
        grown = t * t * (3.0 - 2.0 * t)  # it rises, slowly at first
        birth = 1.0 - t
    else:
        grown = 1.0
        birth = 0.0
    out = Image.new("RGBA", (SIZE, SIZE))
    out.alpha_composite(dust(ph, grown, False, birth))
    out.alpha_composite(debris(ph, grown, False))
    out.alpha_composite(outlined(funnel(ph, grown)))
    out.alpha_composite(debris(ph, grown, True))
    out.alpha_composite(dust(ph, grown, True, birth))
    return out


strip = Image.new("RGBA", (SIZE * FRAMES, SIZE))
for f in range(FRAMES):
    strip.paste(frame(f), (f * SIZE, 0))
strip.save(os.path.join(ROOT, "art", "fx", "tornado.png"))
print("wrote tornado", strip.size)
