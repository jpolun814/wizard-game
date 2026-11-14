"""Makes the snowy peaks' two ranges of distant mountains, far.png and near.png in art/backgrounds/mountains.

The ground the player walks on climbs in flanks of every steepness, with ledges and crags; these ranges now do the same, so no layer is
a smooth hill. Each is a ridge made of straight runs of different slopes (some steep, some shallow, some a flat tread) with the odd ledge
and a ragged edge, lit from the left, and the far one is capped with snow. Both repeat at their edges, as the scenery is laid side by side.
Colors are those of tools/prepare_biome_backdrops.py. Run it from the project folder: python tools/make_mountain_ranges.py
"""
import os
import numpy as np
from PIL import Image

OUT = "art/backgrounds/mountains"


def hexcolor(code):
    return np.array([int(code[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)


def ridge(width, low, high, run_least, run_most, rng, ledge_chance):
    """The height of the top edge in each column (the lower the number the higher the rock), made of straight runs and ledges, and
    returning to where it began so that it repeats."""
    points = [(0, rng.uniform(low, high))]
    x = 0
    while x < width:
        x += int(rng.integers(run_least, run_most + 1))
        if x >= width:
            break
        level = rng.uniform(low, high)
        points.append((x, level))
        if rng.random() < ledge_chance and x + 8 < width:  # a flat tread, then the climb goes on
            x += int(rng.integers(3, 8))
            points.append((x, level))
    points.append((width, points[0][1]))
    xs = np.array([p[0] for p in points], dtype=np.float32)
    ys = np.array([p[1] for p in points], dtype=np.float32)
    clean = np.interp(np.arange(width), xs, ys)
    top = clean + np.round(rng.normal(0, 0.6, width))  # the rock is ragged along its edge
    return np.round(top).astype(int), clean


def paint(width, height, top, clean, rock_top, rock_bottom, snow=None, snow_line=0.0, dark=1.0, rng=None):
    image = np.zeros((height, width, 4), dtype=np.float32)
    slope = np.roll(clean, -3) - np.roll(clean, 3)  # positive: the edge falls away to the right, which is the lit side
    cracks = rng.random((height, width)) < 0.012
    for x in range(width):
        lit = 1.2 if slope[x] > 0.6 else 0.72 if slope[x] < -0.6 else 0.96
        for y in range(max(top[x], 0), height):
            depth = (y - top[x]) / max(height - top[x], 1)
            color = hexcolor(rock_top) * (1 - depth) + hexcolor(rock_bottom) * depth
            color = color * lit * dark
            if cracks[y, x] or cracks[(y + 1) % height, (x + 1) % width]:  # a crack in the face, a few pixels long
                color = color * 0.78
            if snow is not None and top[x] < snow_line:
                reach = (snow_line - top[x]) * 0.55 + 2 * np.sin(x / 2.3) + rng.integers(-1, 2)
                if y - top[x] < reach:
                    shade = 1.0 - 0.45 * (y - top[x]) / max(reach, 1)
                    color = hexcolor(snow[0]) * shade + hexcolor(snow[1]) * (1 - shade)
            image[y, x, :3] = np.clip(color, 0, 255) / 255.0
            image[y, x, 3] = 1.0
    return image


def save(array, name):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(array, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name))


rng = np.random.default_rng(11)
# The far range: tall peaks, steep and shallow flanks, ledges, snow on the highest.
top, clean = ridge(192, 6, 130, 4, 26, rng, 0.35)
save(paint(192, 179, top, clean, "#6f82a6", "#171d30", snow=("#f2f7ff", "#a9bdd9"), snow_line=70, rng=rng), "far.png")
# The near range: lower, darker, as craggy.
top, clean = ridge(384, 4, 62, 4, 22, rng, 0.4)
save(paint(384, 123, top, clean, "#53668c", "#080b14", dark=0.62, rng=rng), "near.png")
print("done")
