"""Draws the Flaming Sphere: a round ball of blazing fire with swirls of heat in it, so that its roll can be seen. Our own work, drawn pixel by pixel.
The flames that lick up from it are the game's own pixel flames (see FlamingSphere), so the ball is not a hard shape.

    python tools/make_sun_art.py

Writes art/fx/sun.png (32x32, one art pixel to a world pixel, so the game does not scale it).
"""
import math
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "fx", "sun.png")
SIZE = 32
MID = (SIZE - 1) / 2.0
RAMP = [(120, 24, 10), (190, 50, 12), (240, 100, 20), (255, 150, 36), (255, 200, 80), (255, 238, 170)]  # cool to hot


def heat(x, y):
    dx, dy = x - MID, y - MID
    r = math.hypot(dx, dy)
    angle = math.atan2(dy, dx)
    edge = 13.6 + 1.1 * math.sin(3.0 * angle + 0.6) + 0.7 * math.sin(7.0 * angle)  # a rim that is not quite round, as fire is not
    if r > edge + 1.6:
        return None, r, edge
    # hottest at the heart, with arms of cooler fire curling round it
    base = 1.0 - r / edge
    arms = 0.5 + 0.5 * math.sin(2.0 * angle + r * 0.55)  # two curling arms: they turn with the ball
    return base * 0.85 + (arms - 0.5) * 0.45, r, edge


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            h, r, edge = heat(x, y)
            if h is None:
                continue
            if r > edge:
                if (x + y) % 2 == 0 and r < edge + 1.0:
                    img.putpixel((x, y), RAMP[0] + (255,))  # the rim breaks up into a dither
                continue
            level = max(0.0, min(0.999, h)) * len(RAMP)
            idx = int(level)
            if (x + y) % 2 == 0 and level - idx > 0.65 and idx + 1 < len(RAMP):
                idx += 1  # a dither where two bands meet
            img.putpixel((x, y), RAMP[idx] + (255,))
    img.save(OUT)
    big = img.resize((SIZE * 8, SIZE * 8), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (20, 8, 24, 255))
    bg.alpha_composite(big)
    bg.save(os.path.join(os.environ.get("TEMP", "."), "lib", "sun_preview.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
