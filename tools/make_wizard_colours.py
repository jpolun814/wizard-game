"""Makes the color variants of the wizards' sprites: a copy of a wizard's folder in art/chars with the hue of its robes, staff light and trim turned
to another color. Skin, hair, wood, and the near-black and near-white of the art are left as they are, so each variant is still the same figure
in the same shading, in a color theme of its own. Run from the game folder:

    python -I tools/make_wizard_colors.py

Then `godot --headless --import` makes the .import files. The variants are used by the opening cut-scene (scripts/screens/intro.gd): ten wizards, no two alike.
"""
import colorsys
import glob
import os
import shutil

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CHARS = os.path.join(ROOT, "art", "chars")

# folder to make: (the folder it is copied from, how far the hue turns: 1.0 is all the way round)
VARIANTS = {
    "wizard_emerald": ("wizard", 0.56),
    "wizard_amber": ("wizard", 0.36),
    "dark_wizard_teal": ("dark_wizard", -0.17),
    "bone_wizard_ice": ("bone_wizard", 0.58),
    "pyre_wizard_green": ("pyre_wizard", 0.30),
    "pyre_wizard_magenta": ("pyre_wizard", 0.82),
}


def turned(pixel, turn, cache):
    key = (pixel, turn)
    if key in cache:
        return cache[key]
    r, g, b, a = pixel
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    skin = 0.0 <= h <= 0.12 and s < 0.62 and v > 0.5  # pale skin and hands
    wood = 0.03 <= h <= 0.13 and v < 0.5               # the staff and the belt
    if a == 0 or s < 0.3 or v < 0.12 or skin or wood:
        out = pixel
    else:
        r2, g2, b2 = colorsys.hsv_to_rgb((h + turn) % 1.0, s, v)
        out = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    cache[key] = out
    return out


def main():
    for name, (source, turn) in VARIANTS.items():
        target = os.path.join(CHARS, name)
        if os.path.exists(target):
            shutil.rmtree(target)
        os.makedirs(target)
        cache = {}
        for path in glob.glob(os.path.join(CHARS, source, "*.png")):
            image = Image.open(path).convert("RGBA")
            pixels = image.load()
            for x in range(image.width):
                for y in range(image.height):
                    pixels[x, y] = turned(pixels[x, y], turn, cache)
            image.save(os.path.join(target, os.path.basename(path)))
        print("made", name)


if __name__ == "__main__":
    main()
