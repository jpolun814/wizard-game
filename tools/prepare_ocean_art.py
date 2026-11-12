"""Builds the ocean world's art (handoff chapter 20) from two downloaded packs, darkened to the game's night:

  python -I tools/prepare_ocean_art.py <underwater-fantasy layers dir> <wrecked-ship layers dir>

- art/backgrounds/ocean/{far,sand,rocks,weeds}.png: ansimuz's "Underwater Fantasy" layers (CC-BY 3.0,
  opengameart.org/content/underwater-fantasy): far.png, sand.png, foreground-1.png and foreground-2.png.
- art/props/shipwreck.png: the broken galleon on its bank of sand, layer 3_145.png of CraftPix's "Wrecked and Sunken
  Ship Pixel Background" (OGA-BY 3.0, opengameart.org/content/wrecked-and-sunken-ship-pixel-background), cut to the
  ship, with the sand fading out at both sides so it lies on any floor.

Both are bright and blue as they come: they are greyed a little, darkened and turned toward the sea's teal, so they
sit in the dark with the rest of the game. Nothing is drawn here: every pixel is the packs' own.
"""
import os
import sys
from PIL import Image


SAND_TOP = 150  # rows of the cut picture above the sand bank


def darken(im: Image.Image, k: float, tint: tuple) -> Image.Image:
    out = im.copy()
    src, dst = im.load(), out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = src[x, y]
            grey = r * 0.3 + g * 0.59 + b * 0.11
            dst[x, y] = tuple(int((c * 0.5 + grey * 0.5) * k * t) for c, t in zip((r, g, b), tint)) + (a,)
    return out


def main() -> None:
    layers, ship_dir = sys.argv[1], sys.argv[2]
    os.makedirs("art/backgrounds/ocean", exist_ok=True)
    for source, name in [("far", "far"), ("sand", "sand"), ("foreground-1", "rocks"), ("foreground-2", "weeds")]:
        im = Image.open(os.path.join(layers, source + ".png")).convert("RGBA")
        darken(im, 0.5, (0.75, 0.95, 1.0)).save(f"art/backgrounds/ocean/{name}.png")
        print("wrote", name)
    ship = Image.open(os.path.join(ship_dir, "3_145.png")).convert("RGBA")
    ship = ship.crop(ship.getbbox())
    ship = darken(ship, 0.55, (0.72, 0.85, 0.95))
    px = ship.load()
    fade = 70
    for y in range(SAND_TOP, ship.size[1]):  # only the sand fades: the bow of the near half reaches the edge above it
        for x in range(ship.size[0]):
            edge = min(x, ship.size[0] - 1 - x)
            if edge < fade:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, int(a * edge / fade))
    ship.save("art/props/shipwreck.png")
    print("wrote shipwreck", ship.size)


main()
