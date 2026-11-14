"""Builds the ocean world's art (handoff chapter 20) from two downloaded packs, darkened to the game's night:

  python -I tools/prepare_ocean_art.py <underwater-fantasy layers dir> <wrecked-ship layers dir>

- art/backgrounds/ocean/{far,sand,rocks,weeds}.png: ansimuz's "Underwater Fantasy" layers (CC-BY 3.0,
  opengameart.org/content/underwater-fantasy): far.png, sand.png, foreground-1.png and foreground-2.png.
- art/props/shipwreck.png: the broken galleon on its bank of sand, layer 3_145.png of CraftPix's "Wrecked and Sunken
  Ship Pixel Background" (OGA-BY 3.0, opengameart.org/content/wrecked-and-sunken-ship-pixel-background), cut to the
  ship, with the sand fading out at both sides so it lies on any floor.

The layers are bright and blue as they come: they are grayed a little, darkened and turned toward the sea's teal, so they
sit in the dark with the rest of the game. The ship is all greens: its hull is given the colors of the driftwood (the town pack's
planks as the game tints them, carried a little lighter so the planks and holes still show) and its bank of sand the sea floor's
sand (tools/prepare_earth.py), each shade by its brightness, so it reads as a solid thing in the water and not as scenery (owner,
2026-11-12). Nothing is drawn here: every pixel is the packs' own, in other colors.
"""
import os
import sys
from PIL import Image


WOOD = [(16, 10, 18), (24, 13, 21), (34, 19, 20), (48, 26, 21), (64, 36, 26), (84, 50, 34)]  # dark to light: the driftwood's, and two steps past it
SAND = [(46, 43, 34), (67, 62, 48), (87, 80, 64), (107, 98, 76), (133, 122, 94)]  # the sea floor's sand ramp
SAND_GREEN = 140  # in the pack's picture, the bank's greens are at least this green, and the hull's are less


def recolor_ship(im: Image.Image) -> Image.Image:
    """Each of the picture's colors goes to the shade of wood or sand that is as far up its own ramp as it is up the picture's."""
    px = im.load()
    colors = sorted({px[x, y][:3] for y in range(im.size[1]) for x in range(im.size[0]) if px[x, y][3] > 0}, key=lambda c: c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11)
    mapping = {}
    for group, ramp in [([c for c in colors if c[1] < SAND_GREEN], WOOD), ([c for c in colors if c[1] >= SAND_GREEN], SAND)]:
        for k, c in enumerate(group):
            mapping[c] = ramp[min(len(ramp) - 1, k * len(ramp) // max(len(group), 1))]
    out = im.copy()
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            p = px[x, y]
            if p[3] > 0:
                po[x, y] = mapping[p[:3]] + (p[3],)
    return out


SAND_TOP = 150  # rows of the cut picture above the sand bank


def darken(im: Image.Image, k: float, tint: tuple) -> Image.Image:
    out = im.copy()
    src, dst = im.load(), out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = src[x, y]
            gray = r * 0.3 + g * 0.59 + b * 0.11
            dst[x, y] = tuple(int((c * 0.5 + gray * 0.5) * k * t) for c, t in zip((r, g, b), tint)) + (a,)
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
    ship = recolor_ship(ship)
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
