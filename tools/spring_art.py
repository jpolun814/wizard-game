"""The basin of the Healing Spring spell: a low rim of stones round clear water, seen from the side, standing on the ground. Drawn pixel by pixel, lit from the upper
left, no outlines. Run it from anywhere:

    python tools/spring_art.py

It writes art/props/healing_spring.png (the feet of the picture are its bottom edge, its middle is the middle of the pool). Never edit the PNG by hand: change this
file and run it again.
"""
import os

from PIL import Image

W, H = 80, 22
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

STONE = ["#a9a6a0", "#837f7c", "#5e5a60", "#3a3640"]   # lit, mid, shade, deep shade
WATER = ["#d8f4ff", "#8fd4f0", "#56a8d8", "#2f6fa8", "#1f4a80"]  # glint, top, mid, deep, floor
MOSS = "#5d8a4c"


def hexa(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    # The water: a long lens, its surface a little below the rim, light at the top and deeper below.
    for y in range(6, 18):
        for x in range(4, W - 4):
            t = (x - W / 2) / (W / 2 - 4)
            depth = (y - 6) / 11.0
            lens = 1.0 - t * t
            if depth > lens * 1.05:
                continue
            band = 1 if depth < 0.2 else 2 if depth < 0.55 else 3 if depth < 0.85 else 4
            px[x, y] = hexa(WATER[band])
    # Glints on the surface.
    for gx, gy in [(14, 7), (15, 7), (30, 8), (46, 7), (47, 7), (60, 8), (24, 9), (54, 9)]:
        px[gx, gy] = hexa(WATER[0])
    # The rim: stones along the front and at both ends, each a small lit block with a shaded foot.
    stones = [(0, 12, 9, 10), (8, 15, 9, 7), (17, 17, 9, 5), (26, 18, 10, 4), (35, 18, 10, 4), (44, 18, 10, 4), (53, 18, 10, 4), (62, 17, 9, 5), (70, 15, 9, 7), (71, 12, 9, 10)]
    for k, (x0, y0, w, h) in enumerate(stones):
        for y in range(y0, min(y0 + h, H)):
            for x in range(x0, min(x0 + w, W)):
                edge_top = y == y0
                edge_left = x == x0
                edge_right = x == x0 + w - 1
                edge_bottom = y == min(y0 + h, H) - 1
                if edge_bottom or edge_right:
                    col = STONE[3 if edge_bottom else 2]
                elif edge_top or edge_left:
                    col = STONE[0]
                else:
                    col = STONE[1] if (x + y + k) % 5 else STONE[2]
                px[x, y] = hexa(col)
    # A little moss where a stone meets the next.
    for mx, my in [(9, 16), (18, 18), (36, 19), (63, 18), (70, 16)]:
        px[mx, my] = hexa(MOSS)
        px[mx + 1, my] = hexa(MOSS)
    out = os.path.join(ROOT, "art", "props", "healing_spring.png")
    img.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
