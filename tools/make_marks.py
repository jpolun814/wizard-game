"""Draws the small pixel-art marks that float over a wizard, and the Moonbeam's column of light, as real PNGs in art/fx.

These were made for this game (nothing in the free packs is a pentagram, a rage flame, wings or a dithered beam), pixel by pixel, so the
spells need no code-drawn shapes. Run it from the project folder:  python -I tools/make_marks.py
"""
import math
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "fx")


def hexa(code: str, alpha: int = 255) -> tuple:
    code = code.lstrip("#")
    return (int(code[0:2], 16), int(code[2:4], 16), int(code[4:6], 16), alpha)


def from_rows(rows: list, key: dict) -> Image.Image:
    """A picture from rows of characters; a space is clear, any other letter is a colour in key."""
    width = max(len(r) for r in rows)
    image = Image.new("RGBA", (width, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != " ":
                image.putpixel((x, y), hexa(key[ch]))
    return image


def line(points: set, a: tuple, b: tuple) -> None:
    """The pixels of a straight line (Bresenham)."""
    x0, y0 = a
    x1, y1 = b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        points.add((x0, y0))
        if (x0, y0) == (x1, y1):
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def hex_mark() -> Image.Image:
    """A pentagram in one stroke, the same star the Hex is drawn as: a pale violet line, with a brighter point at each tip."""
    size = 21
    centre = size // 2
    tips = [(round(centre + 9.5 * math.cos(-math.pi / 2 + math.tau * k / 5)), round(centre + 9.5 * math.sin(-math.pi / 2 + math.tau * k / 5))) for k in range(5)]
    pixels = set()
    for step in range(5):
        line(pixels, tips[(step * 2) % 5], tips[((step + 1) * 2) % 5])
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for x, y in pixels:
        image.putpixel((x, y), hexa("#c8a8ff"))
    for x, y in tips:
        image.putpixel((x, y), hexa("#ffffff"))
    return image


def question_mark() -> Image.Image:
    """A question mark, pale with a dark edge, for the one who has lost their mind: the spell tints it by what they have turned to."""
    rows = [
        " wwwww ",
        "wwwwwww",
        "ww   ww",
        "ww   ww",
        "     ww",
        "    ww ",
        "   ww  ",
        "   ww  ",
        "       ",
        "   ww  ",
        "   ww  ",
    ]
    inner = from_rows(rows, {"w": "#ffffff"})
    image = Image.new("RGBA", (inner.width + 2, inner.height + 2), (0, 0, 0, 0))
    for y in range(inner.height):
        for x in range(inner.width):
            if inner.getpixel((x, y))[3]:
                for ox in (-1, 0, 1):
                    for oy in (-1, 0, 1):
                        if image.getpixel((x + 1 + ox, y + 1 + oy))[3] == 0:
                            image.putpixel((x + 1 + ox, y + 1 + oy), hexa("#2a1030"))
    image.paste(inner, (1, 1), inner)
    return image


def moon_beam() -> Image.Image:
    """A soft column of pale light falling to the ground: it fades to nothing going up, widens a little toward the foot, and its edges are feathered."""
    width, height = 64, 260
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for y in range(height):
        rise = y / (height - 1)  # 0 at the top, 1 at the foot
        reach = 0.45 + 0.55 * rise  # the column is narrower high up
        for x in range(width):
            across = abs((x + 0.5) / width * 2.0 - 1.0) / reach
            if across >= 1.0:
                continue
            soft = math.exp(-3.2 * across * across)  # brightest down the middle, feathered at the edges
            streak = 0.88 + 0.12 * math.sin(x * 0.7 + 2.0 * math.sin(y * 0.02))  # faint shafts in the light
            alpha = (rise ** 1.3) * soft * streak * 0.6
            image.putpixel((x, y), (200, 218, 255, int(255 * min(alpha, 1.0))))
    return image


if __name__ == "__main__":
    for name, image in (("hex_mark", hex_mark()), ("question_mark", question_mark()), ("moon_beam", moon_beam())):
        image.save(os.path.join(OUT, name + ".png"))
        print(name, image.size)
