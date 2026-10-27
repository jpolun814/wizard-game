"""Makes art/tiles/castle_brick.png: the wall of the castle, a running bond of dark blue-violet bricks in the palette of the
church hall's stonework (art/backgrounds/church/hall.png, Gothicvania Church by ansimuz, CC0). The tile repeats in both
directions. Run with: python -I tools/prepare_castle_brick.py"""
import os
import random
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
HALL = os.path.join(ROOT, "art", "backgrounds", "church", "hall.png")
OUT = os.path.join(ROOT, "art", "tiles", "castle_brick.png")

SIZE = 64
BRICK_W = 16
BRICK_H = 8

# The stone of the hall's columns: its most common mid-tones, darkest to lightest.
hall = Image.open(HALL).convert("RGBA")
counts = {}
for x in range(215, 255):
    for y in range(90, 190):
        r, g, b, a = hall.getpixel((x, y))
        if a == 255 and 40 < r + g + b < 520 and b > r + 8:
            counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
palette = sorted(counts, key=lambda c: -counts[c])[:8]
palette.sort(key=sum)
mortar = tuple(max(0, int(v * 0.45)) for v in palette[0])

rng = random.Random(7)
image = Image.new("RGBA", (SIZE, SIZE), mortar + (255,))
for course in range(SIZE // BRICK_H):
    shift = (BRICK_W // 2) if course % 2 else 0
    for index in range(SIZE // BRICK_W):
        x0 = index * BRICK_W + shift
        y0 = course * BRICK_H
        base = palette[rng.randrange(1, max(2, len(palette) - 2))]
        for dx in range(BRICK_W - 1):
            for dy in range(BRICK_H - 1):
                colour = list(base)
                if dy == 0:
                    colour = [min(255, int(v * 1.25) + 6) for v in base]  # a lit top edge
                elif dy >= BRICK_H - 2:
                    colour = [int(v * 0.8) for v in base]  # a shaded foot
                elif rng.random() < 0.12:
                    shade = rng.choice([0.88, 1.12])
                    colour = [min(255, int(v * shade)) for v in base]
                image.putpixel(((x0 + dx) % SIZE, (y0 + dy) % SIZE), tuple(colour) + (255,))
image.save(OUT)
print("wrote", OUT, "palette", palette)
