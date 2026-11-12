"""Builds the plain earth that fills the rock under every world (art/tiles/earth_<tiles>.png).

The atlases from the packs only have a thin lit band and then black, so the rock read as bare navy with stripes of
pattern. Here every biome gets one seamless, hand-ramped piece of rock of its own: stones with dark seams, a lit top
edge and a shaded underside, all from the same four-step ramp so that every world's ground looks like part of one game.
Art pixels are drawn 2x2 in the world, like the rest of the tiles.
"""
import random
from PIL import Image

SIZE = 64        # art pixels along a side; drawn at 2x, so 128 world pixels, before it repeats
CELLS = 5        # stones along a side

# seam, shade, mid, light, glint
RAMPS = {
    "cemetery": ["#0d0811", "#1a1115", "#2a1d1c", "#3d2b26", "#54392d"],
    "stone": ["#0a0711", "#161224", "#241d38", "#352c4f", "#4a3f6a"],
    "swamp": ["#110c07", "#231910", "#382818", "#51392a", "#74543a"],  # soil, not rock: see dirt()
    "ash": ["#080505", "#130d0d", "#201515", "#33201e", "#522b22"],
    "church": ["#0a0813", "#14121f", "#1f1d33", "#2e2c48", "#423f62"],
    "seabed": ["#050c10", "#0b1a1f", "#13282d", "#1c3a3c", "#2a4f4d"],  # the ocean's floor: rock gone dark teal under the sea
}

# the grassy lip along every surface: blade dark, blade, blade light, and the moss under it
LIPS = {
    "cemetery": ["#1d2a14", "#33481c", "#566c2a", "#7c8a38"],
    "stone": ["#1c1a2c", "#2c2a44", "#434063", "#6a668f"],
    "swamp": ["#101c14", "#1d3322", "#33513a", "#5a7a4a"],
    "ash": ["#2a1010", "#4a1a14", "#7a2c1c", "#b0502a"],
    "church": ["#14121f", "#22203a", "#37345a", "#55527f"],
    "seabed": ["#0f2422", "#1a3a32", "#2c5446", "#4a7460"],  # weed on the sea floor
}


def make(name: str, ramp: list[str], seed: int) -> None:
    rng = random.Random(seed)
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in ramp]
    step = SIZE / CELLS
    sites = []
    for gy in range(CELLS):
        for gx in range(CELLS):
            sites.append(((gx + 0.5 + rng.uniform(-0.32, 0.32)) * step, (gy + 0.5 + rng.uniform(-0.32, 0.32)) * step, rng.choice([1, 2, 2, 3])))
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            best = []
            for (sx, sy, tone) in sites:
                best_d = None
                for ox in (-SIZE, 0, SIZE):
                    for oy in (-SIZE, 0, SIZE):
                        d = ((x - sx - ox) ** 2 * 1.0 + (y - sy - oy) ** 2 * 1.25) ** 0.5
                        if best_d is None or d < best_d[0]:
                            best_d = (d, sx + ox, sy + oy)
                best.append((best_d[0], best_d[1], best_d[2], tone))
            best.sort()
            d1, cx, cy, tone = best[0]
            d2 = best[1][0]
            edge = d2 - d1
            if edge < 1.6:
                px[x, y] = cols[0]
                continue
            # lit from above and the left: the top-left of a stone is lighter, its underside darker
            lit = ((cx - x) * 0.5 + (cy - y) * 1.0) / step
            level = tone + (1 if lit > 0.28 else 0) - (1 if lit < -0.3 else 0)
            if edge < 3.0 and lit > 0:
                level += 1
            if rng.random() < 0.05:
                level += rng.choice([-1, 1])
            px[x, y] = cols[max(1, min(4, level))]
    img = img.resize((SIZE * 2, SIZE * 2), Image.NEAREST)
    img.save(f"art/tiles/earth_{name}.png")
    print("wrote", name)


def lip(name: str, ramp: list[str], seed: int) -> None:
    """A strip 64 art pixels wide and 12 tall: tufts standing up from a band of moss with a ragged lower edge."""
    rng = random.Random(seed)
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for c in ramp]
    w, h = 64, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    base = 4                       # first row of the solid moss
    heights = [base] * w
    x = 0
    while x < w:                   # tufts: a blade rises a few rows over two or three columns
        run = rng.randint(2, 3)
        rise = rng.randint(0, 4)
        for k in range(run):
            heights[(x + k) % w] = base - rise + (1 if k == run - 1 and rise > 1 else 0)
        x += run
    for x in range(w):
        drip = base + 4 + rng.choice([0, 1, 2, 3, 3])
        for y in range(max(0, heights[x]), min(h, drip)):
            depth = y - heights[x]
            c = 2 if depth == 0 else (1 if depth < 3 else 0)
            if y < base and depth == 0:
                c = 3
            if y >= base + 2 and rng.random() < 0.3:
                c = 0
            px[x, y] = cols[c]
    img = img.resize((w * 2, h * 2), Image.NEAREST)
    img.save(f"art/tiles/lip_{name}.png")
    print("wrote lip", name)


def dirt(name: str, ramp: list[str], seed: int) -> None:
    """Soil for the jungle: loose clumps of earth in the ramp's browns, flecked with pebbles and roots. Seamless: every random value is
    taken on a wrapped grid."""
    rng = random.Random(seed)
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in ramp]
    grid = {}

    def at(cells, ix, iy):
        key = (cells, ix % cells, iy % cells)
        if key not in grid:
            grid[key] = rng.random()
        return grid[key]

    def noise(x, y, cells):
        gx, gy = x / SIZE * cells, y / SIZE * cells
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        top = at(cells, x0, y0) * (1 - fx) + at(cells, x0 + 1, y0) * fx
        bottom = at(cells, x0, y0 + 1) * (1 - fx) + at(cells, x0 + 1, y0 + 1) * fx
        return top * (1 - fy) + bottom * fy

    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = 0.5 * noise(x, y, 4) + 0.3 * noise(x, y, 8) + 0.2 * noise(x, y, 16)
            level = int((v - 0.2) * 7.5)
            if rng.random() < 0.07:
                level += rng.choice([-1, 1])
            px[x, y] = cols[max(0, min(4, level))]
    for _ in range(SIZE // 2):  # pebbles: a lit pixel pair with a shadow beside it
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        px[x, y] = cols[4]
        px[(x + 1) % SIZE, y] = cols[3]
        px[(x + 1) % SIZE, (y + 1) % SIZE] = cols[0]
    for _ in range(SIZE // 6):  # roots: a short dark thread
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        way = rng.choice([-1, 1])
        for k in range(rng.randint(4, 9)):
            px[(x + k * way) % SIZE, (y + k // 3) % SIZE] = cols[0]
    img = img.resize((SIZE * 2, SIZE * 2), Image.NEAREST)
    img.save(f"art/tiles/earth_{name}.png")
    print("wrote dirt", name)


SNOW = ["#7f98bd", "#b0c7de", "#cfdfee", "#e8f2f9", "#f8fcff"]  # deep shade, shade, snow, lit snow, glint


def snowpack(seed: int) -> None:
    """Snow over the high rock: soft drifts of the snow ramp with the odd glint, seamless. Made the way dirt() is, with no seams or stones."""
    rng = random.Random(seed)
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in SNOW]
    grid = {}

    def at(cells, ix, iy):
        key = (cells, ix % cells, iy % cells)
        if key not in grid:
            grid[key] = rng.random()
        return grid[key]

    def noise(x, y, cells):
        gx, gy = x / SIZE * cells, y / SIZE * cells
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        top = at(cells, x0, y0) * (1 - fx) + at(cells, x0 + 1, y0) * fx
        bottom = at(cells, x0, y0 + 1) * (1 - fx) + at(cells, x0 + 1, y0 + 1) * fx
        return top * (1 - fy) + bottom * fy

    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = 0.3 * noise(x, y, 4) + 0.3 * noise(x, y, 8) + 0.25 * noise(x, y, 16) + 0.15 * noise(x, y, 32)
            level = 2 + (1 if v > 0.6 else 0) - (1 if v < 0.4 else 0)  # mostly plain snow, with a little shade and a little light
            if rng.random() < 0.03:
                level -= 1
            px[x, y] = cols[max(1, min(3, level))]
    for _ in range(SIZE // 3):  # glints
        px[rng.randrange(SIZE), rng.randrange(SIZE)] = cols[4]
    img = img.resize((SIZE * 2, SIZE * 2), Image.NEAREST)
    img.save("art/tiles/earth_snow.png")
    print("wrote snowpack")


def snow_lip(seed: int) -> None:
    """The edge of the snow along a ridge: rounded drifts piled over the rock, lit on top, blue in their shade, with a ragged lower edge."""
    rng = random.Random(seed)
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for c in SNOW]
    w, h = 64, 14
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    heights = [5.0] * w
    for _ in range(7):  # rounded mounds of drift, wrapped round the strip
        centre, radius, rise = rng.uniform(0, w), rng.uniform(4, 9), rng.uniform(1.5, 4.5)
        for x in range(w):
            d = min(abs(x - centre), w - abs(x - centre))
            if d < radius:
                heights[x] = min(heights[x], 5.0 - rise * (1 - (d / radius) ** 2) ** 0.5)
    for x in range(w):
        drip = 9 + rng.choice([0, 1, 1, 2, 3])
        top = int(round(heights[x]))
        for y in range(max(0, top), min(h, drip)):
            depth = y - top
            if depth == 0:
                c = 4 if rng.random() < 0.25 else 3
            elif depth < 3:
                c = 2
            elif depth < 5:
                c = 1
            else:
                c = 0
            px[x, y] = cols[c]
    img = img.resize((w * 2, h * 2), Image.NEAREST)
    img.save("art/tiles/lip_snow.png")
    print("wrote lip snow")


snowpack(90)
snow_lip(91)
for i, (n, r) in enumerate(RAMPS.items()):
    if n == "swamp":
        dirt(n, r, 7 + i)
    else:
        make(n, r, 7 + i)
    lip(n, LIPS[n], 40 + i)
