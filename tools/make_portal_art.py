"""Draws art/fx/portal_purple.png: a ring of violet light, 24 frames of 64 x 64 in one strip. It replaces a download whose licence was never confirmed.
`portal.gd` cuts the strip into the ring's states:
  frames 0-7    open: the ring swirls on (a loop)
  frame 8       closed: a thin level line
  frames 8-15   opening: the line grows upward into the ring (the last frame runs straight into frame 0)
  frames 16-23  closing: the ring shuts down to the line, which fades in a puff of dust (the last frame is empty); played backward it is "appearing"
The ring is a tall ellipse: a bright rim with a glint that runs round it, and inside it three arms of a spiral turning in toward a pale core. The spiral turns
one arm's width each loop, so the loop joins up without a jump. A dark line is put round the whole shape and a few motes of light ride the rim.
Run with: python -I tools/make_portal_art.py"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SIZE = 64
FRAMES = 24
CX, CY = 32.0, 35.5   # the ring's middle (the old art's, so the portal stays where the game puts it)
RX, RY = 8.5, 23.0   # half its width and height when open

VOID = (34, 20, 46)
SHADE = [(52, 34, 66), (105, 73, 116), (120, 83, 132), (142, 106, 154), (190, 171, 196), (232, 220, 238)]  # dark to light
OUTLINE = (22, 12, 30)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DUST = [(142, 106, 154), (105, 73, 116), (190, 171, 196)]


def tone(value: float, x: int, y: int) -> tuple:
    """A shade from the ramp, 0 the darkest and 1 the lightest, with an ordered dither between the steps."""
    v = min(max(value, 0.0), 0.999) * (len(SHADE) - 1)
    base = int(v)
    if v - base > (BAYER[y % 4][x % 4] + 0.5) / 16.0:
        base += 1
    return SHADE[min(base, len(SHADE) - 1)] + (255,)


def ring(ph: float, ry: float, glow: float = 0.0) -> Image.Image:
    """The ring `ry` high (`RY` when open) with its swirl at phase `ph` (a fraction of a loop); `glow` is a flash that brightens all of it."""
    img = Image.new("RGBA", (SIZE, SIZE))
    thick = min(3.0, 1.0 + ry * 0.12)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = (x + 0.5 - CX) / RX, (y + 0.5 - CY) / max(ry, 0.5)
            rho = math.hypot(dx, dy)
            if rho > 1.0:
                continue
            phi = math.atan2(dy, dx)
            edge = (1.0 - rho) * min(ry, RY) * 0.6  # how many pixels in from the rim (shrinks with the ring)
            if edge < thick:
                # The rim, with a glint that runs round it once a loop.
                glint = 0.5 + 0.5 * math.cos(phi - ph * math.tau)
                value = 0.45 + 0.4 * glint + (0.1 if edge < 1.0 else 0.0)
            else:
                # The spiral: three arms turning in; dark between them, brighter toward the middle, a pale core.
                arm = math.sin(3.0 * phi - 6.0 * rho + ph * math.tau)
                value = 0.06 + 0.5 * (0.5 + 0.5 * arm) ** 1.5 + 0.3 * (1.0 - rho) ** 2
                if rho < 0.2:
                    value = 0.75 + 0.2 * math.sin(ph * math.tau * 2)
            img.putpixel((x, y), tone(value + glow, x, y))
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


def motes(img: Image.Image, ph: float, ry: float) -> None:
    """Specks of light that ride the rim, each going round a whole number of times a loop and drifting a little out and back."""
    for i, (a0, turns) in enumerate([(0.2, 1), (1.7, 1), (3.0, 2), (4.4, 1), (5.5, 2)]):
        a = a0 + ph * math.tau * turns
        out = 1.0 + 0.2 + 0.12 * math.sin(ph * math.tau * 2 + i)
        x = int(round(CX + RX * out * math.cos(a)))
        y = int(round(CY + max(ry, 0.5) * out * math.sin(a)))
        if 0 <= x < SIZE and 0 <= y < SIZE and ry > 3.0:
            img.putpixel((x, y), SHADE[5] + (255,) if i % 2 == 0 else SHADE[4] + (255,))


def puff(img: Image.Image, t: float) -> None:
    """The line's last dust: grains thrown out from the middle of it, fading as they go (t from 0, just begun, to 1, gone)."""
    if t >= 1.0:
        return
    for i in range(22):
        a = math.tau * i / 22.0
        reach = (3.0 + 11.0 * t) * (0.6 + 0.4 * ((i * 5) % 7) / 7.0)
        if (i * 3) % 10 < int(10 * t) * 0.6:
            continue  # grains drop away as it fades
        x = int(round(CX + reach * 1.5 * math.cos(a)))
        y = int(round(CY + reach * 0.9 * math.sin(a) - 3.0 * t))
        if 0 <= x < SIZE and 0 <= y < SIZE:
            img.putpixel((x, y), DUST[i % 3] + (255,))


def eased(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def frame(f: int) -> Image.Image:
    if f < 8:  # open
        ph = f / 8.0
        img = outlined(ring(ph, RY))
        motes(img, ph, RY)
        return img
    if f < 16:  # opening, from the line (8) to the ring (15)
        t = (f - 8) / 7.0
        ry = 0.6 + (RY - 0.6) * eased(t)
        ph = (f - 16) / 8.0  # the swirl is already turning as it opens, and the last frame (-1/8) leads into frame 0
        img = outlined(ring(ph, ry, glow=0.25 * (1.0 - t)))
        motes(img, ph, ry)
        return img
    # closing: the ring shuts to the line over 16-20, the line fades in a puff 20-22, and nothing is left at 23
    if f <= 20:
        t = (f - 16) / 4.0
        ry = RY - (RY - 0.6) * eased(t)
        ph = (f - 8) / 8.0  # it carries on from the open loop
        img = outlined(ring(ph, ry, glow=0.2 * t))
        motes(img, ph, ry)
        return img
    if f <= 22:
        t = (f - 20) / 3.0
        img = Image.new("RGBA", (SIZE, SIZE))
        if f == 21:
            img = outlined(ring(0.0, 0.6, glow=0.3))
        puff(img, t)
        return img
    return Image.new("RGBA", (SIZE, SIZE))


strip = Image.new("RGBA", (SIZE * FRAMES, SIZE))
for f in range(FRAMES):
    strip.paste(frame(f), (f * SIZE, 0))
strip.save(os.path.join(ROOT, "art", "fx", "portal_purple.png"))
print("wrote portal", strip.size)
