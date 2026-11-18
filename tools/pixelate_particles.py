"""Turns the soft particle textures (art/particles, Kenney's Particle Pack, CC0) into chunky pixel art, so glows, smoke, rings and sparks match the rest of the game:
each is cut down to a 32 by 32 grid of flat blocks, with only a few levels of opacity and of each color, and drawn back at the same size. Run it from anywhere:

    python tools/pixelate_particles.py

It writes art/particles_px/, which is what `Fx.tex` loads. Never edit those by hand: change this file and run it.
"""
import glob
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GRID = 32
ALPHA_LEVELS = 4    # opacity in this many steps (0 is clear)
COLOR_LEVELS = 6


def snap(value: int, levels: int) -> int:
    step = 255.0 / (levels - 1)
    return int(round(round(value / step) * step))


def main() -> None:
    out = os.path.join(ROOT, "art", "particles_px")
    os.makedirs(out, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(ROOT, "art", "particles", "*.png"))):
        image = Image.open(path).convert("RGBA")
        size = image.size
        # premultiply so the clear edges do not drag their color into the blocks
        px = image.load()
        small = Image.new("RGBA", (GRID, GRID))
        for gy in range(GRID):
            for gx in range(GRID):
                bx, by = gx * size[0] // GRID, gy * size[1] // GRID
                w, h = size[0] // GRID, size[1] // GRID
                r = g = b = a = 0.0
                for y in range(by, by + h):
                    for x in range(bx, bx + w):
                        pr, pg, pb, pa = px[x, y]
                        r += pr * pa
                        g += pg * pa
                        b += pb * pa
                        a += pa
                count = w * h
                if a <= 0:
                    small.putpixel((gx, gy), (0, 0, 0, 0))
                    continue
                alpha = snap(int(a / count), ALPHA_LEVELS)
                if alpha == 0:
                    small.putpixel((gx, gy), (0, 0, 0, 0))
                    continue
                small.putpixel((gx, gy), (snap(int(r / a), COLOR_LEVELS), snap(int(g / a), COLOR_LEVELS), snap(int(b / a), COLOR_LEVELS), alpha))
        small.resize(size, Image.NEAREST).save(os.path.join(out, os.path.basename(path)))


main()
