"""Draws art/fx/bolt_segments.png (Jolt's lightning) and art/fx/beam_segments.png (the Eldritch Blast).

Each sheet is a row of 48 x 48 pieces. A piece runs from the middle of its left edge to the middle of its right edge, so any pieces set end to end join up.
A bolt piece is a forked, jagged line of lightning; a beam piece is a rope of dark energy with a bright core, a strand winding round it and sparks flying off.
Run it from the project folder: python tools/make_bolt_art.py
"""
import math
import random
from PIL import Image, ImageDraw

SIZE = 48
MID = 24


def sheet(count):
    return Image.new("RGBA", (SIZE * count, SIZE), (0, 0, 0, 0))


def lightning(rng):
    """One piece of lightning: a jagged line from edge to edge, with a fork or two."""
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # (owner, 2026-11-22: it was too back-and-forth.) Few, longer strokes that lean one way for a stretch, so it reads as a bolt and not a zigzag.
    xs = [0, 13, 25, 36, 47]
    ys = [MID, MID + rng.randint(-5, 5), MID + rng.randint(-7, 7), MID + rng.randint(-5, 5), MID]
    line = list(zip(xs, ys))
    forks = []
    for k in rng.sample(range(1, len(line) - 1), 1):
        x, y = line[k]
        angle = rng.choice([-1, 1]) * rng.uniform(0.5, 1.1)  # off to one side, going on the way the bolt goes
        reach = rng.randint(8, 15)
        mid = (x + int(math.cos(angle) * reach * 0.5) + 2, y + int(math.sin(angle) * reach * 0.5))
        end = (min(SIZE - 1, x + int(math.cos(angle) * reach) + 3), y + int(math.sin(angle) * reach))
        forks.append([(x, y), mid, end])
    for path, width_scale in [(line, 1.0)] + [(f, 0.6) for f in forks]:
        d.line(path, fill=(255, 190, 40, 90), width=int(7 * width_scale) | 1)   # the glow round it
        d.line(path, fill=(255, 226, 80, 255), width=int(3 * width_scale) | 1)  # the bolt
    for path in [line] + forks:
        d.line(path, fill=(255, 255, 235, 255), width=1)  # white-hot at the middle
    for k in range(5):  # specks thrown off it
        x, y = rng.randint(2, SIZE - 3), MID + rng.choice([-1, 1]) * rng.randint(8, 18)
        d.point((x, y), fill=(255, 245, 160, 255))
    return im


def beam(rng, phase):
    """One piece of the Eldritch Blast: a rope of dark energy with a white core, a bright strand winding round it, and sparks."""
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def at(x, amp, turns, shift):
        return MID + amp * math.sin(2 * math.pi * (x / SIZE * turns) + shift)

    core = [(x, at(x, 3.0, 1, 0.0)) for x in range(SIZE)]
    d.line(core, fill=(70, 20, 120, 110), width=11)    # the dark glow
    d.line(core, fill=(130, 70, 200, 255), width=7)    # the body
    d.line(core, fill=(200, 160, 255, 255), width=3)   # a brighter inside
    d.line(core, fill=(250, 240, 255, 255), width=1)   # the core
    for shift, color in [(phase, (215, 175, 255, 255)), (phase + math.pi, (170, 110, 240, 255))]:  # two strands wind round it
        strand = [(x, at(x, 9.0, 2, shift)) for x in range(SIZE)]
        d.line(strand, fill=color, width=1)
    for k in range(7):  # sparks flying off the rope
        x = rng.randint(1, SIZE - 2)
        y = MID + rng.choice([-1, 1]) * rng.randint(8, 19)
        d.point((x, y), fill=(235, 215, 255, 255))
        if rng.random() < 0.5:
            d.point((x + rng.choice([-1, 1]), y), fill=(150, 90, 220, 255))
    return im


def build() -> None:
    rng = random.Random(7)
    bolts = sheet(8)
    for i in range(8):
        bolts.paste(lightning(rng), (i * SIZE, 0))
    bolts.save("art/fx/bolt_segments.png")
    beams = sheet(4)
    for i in range(4):
        beams.paste(beam(rng, i * math.pi / 2), (i * SIZE, 0))
    beams.save("art/fx/beam_segments.png")
    print("drew art/fx/bolt_segments.png and art/fx/beam_segments.png")


if __name__ == "__main__":
    build()
