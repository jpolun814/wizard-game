"""Makes the small pixel pictures of the biomes' living scenery, drawn by hand here as maps of pixels (own work, CC0):
art/props/bat_0..1.png (a bat, wings up and down), bird_0..1.png (a bird, wings up and down) and crystal_1..3.png (cave crystals).
Run from the project folder:  python -I tools/prepare_biome_critters.py"""
from PIL import Image

BAT = ["#15101c"]
BAT_UP = ["#.......#", "##.#.#.##", "#########", ".###.###.", "..#...#.."]
BAT_DOWN = ["....#....", ".#.###.#.", "###...###", "#.#####.#", "#.......#"]
BIRD = ["#e0703a"]
BIRD_UP = ["#.......#", ".##...##.", "..#####..", "...###...", "....#...."]
BIRD_DOWN = ["....#....", "...###...", ".#######.", "##.....##", "#.......#"]
SHARD = ["...#...", "..#h#..", "..#hb#.", ".#hhb#.", ".#hhbb#", ".#hbbb#", "#hhbbb#", "#hbbbd#", "#hbbdd#", "#bbbdd#", "#bbddd#", ".bdddd.", "..ddd.."]
COLOURS = {"#": (18, 58, 90, 255), "h": (216, 251, 255, 255), "b": (90, 215, 232, 255), "d": (42, 127, 168, 255), ".": (0, 0, 0, 0)}


def draw(rows, colour_of, path):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            im.putpixel((x, y), colour_of(ch))
    im.save(path)
    return im


def solid(colour):
    c = tuple(int(colour[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    return lambda ch: c if ch == "#" else (0, 0, 0, 0)


for i, rows in enumerate([BAT_UP, BAT_DOWN]):
    draw(rows, solid(BAT[0]), "art/props/bat_%d.png" % i)
for i, rows in enumerate([BIRD_UP, BIRD_DOWN]):
    draw(rows, solid(BIRD[0]), "art/props/bird_%d.png" % i)
one = draw(SHARD, lambda ch: COLOURS[ch], "art/props/crystal_1.png")
two = draw([row[::-1] for row in SHARD[3:]], lambda ch: COLOURS[ch], "art/props/crystal_2.png")
three = Image.new("RGBA", (13, 13), (0, 0, 0, 0))
three.paste(two, (0, 3), two)
three.paste(one, (6, 0), one)
three.save("art/props/crystal_3.png")
