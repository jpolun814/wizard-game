"""Makes art/props/dusk_vine.png: the swamp vine recoloured to the great oak's own colours (a dark teal stem with green-teal leaf
light on it), instead of the pack's acid green, which clashed with the trees it climbs. Then makes art/props/jungle_vine.png from it, as
tools/prepare_jungle.py did from the original. Run from the project folder: python -I tools/prepare_vines.py"""
from PIL import Image, ImageOps

RAMP = [(0.0, (12, 20, 24)), (0.35, (26, 52, 50)), (0.65, (48, 104, 88)), (1.0, (110, 172, 134))]


def ramp(t: float):
    for (a, ca), (b, cb) in zip(RAMP, RAMP[1:]):
        if t <= b:
            f = (t - a) / (b - a)
            return tuple(round(ca[i] + (cb[i] - ca[i]) * f) for i in range(3))
    return RAMP[-1][1]


src = Image.open("art/props/swamp_vine.png").convert("RGBA")
out = Image.new("RGBA", src.size)
px, po = src.load(), out.load()
for y in range(src.height):
    for x in range(src.width):
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
        po[x, y] = (*ramp(min(1.0, lum * 1.25)), a)
out.save("art/props/dusk_vine.png", optimize=True)
up = out.rotate(90, expand=True)
tall = Image.new("RGBA", (up.width, up.height * 2))
tall.paste(up, (0, 0))
tall.paste(ImageOps.flip(up), (0, up.height))
tall.save("art/props/jungle_vine.png", optimize=True)
print("wrote dusk_vine and jungle_vine")


# A lily pad, seen from the side as it floats: a flat leaf with a notch and a pale lit rim, in the oak's teal. 26 by 7 art pixels, drawn 2x.
import math
pad = Image.new("RGBA", (26, 7), (0, 0, 0, 0))
pp = pad.load()
for y in range(7):
    for x in range(26):
        dx = (x - 12.5) / 12.5
        dy = (y - 3.0) / 3.0
        if dx * dx + dy * dy * 1.1 > 1.0:
            continue
        if y >= 3 and abs(x - 17) <= (y - 2):  # the notch, on the lower right
            continue
        edge = dx * dx + dy * dy * 1.1 > 0.7
        top = y <= 2
        if edge and not top:
            pp[x, y] = (20, 42, 40, 255)
        elif top and (dy < -0.4):
            pp[x, y] = (96, 150, 130, 255)
        elif top:
            pp[x, y] = (62, 112, 98, 255)
        else:
            pp[x, y] = (38, 78, 72, 255)
pad.resize((52, 14), Image.NEAREST).save("art/props/lily_pad.png")
print("wrote lily_pad")
