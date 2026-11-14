"""Draws the library's bookcase and the spines of its books, pixel by pixel (our own work, no outside pack).

    python tools/make_library_art.py

Writes art/ui/library/: bookcase.png (empty, 300x180), tome_<school>.png (the eight named tomes) and filler_<n>.png
(the other books that stand on the shelves), plus stack_<n>.png (books lying flat). Everything is drawn at one pixel to the
art pixel, and the game scales it up whole (3x), like the rest of its pixel art. The names on the tomes are written by
the game itself, in the title lettering, turned to run down the spine.
"""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "ui", "library")
GOLD = (201, 162, 74)
GOLD_LIGHT = (240, 210, 130)
OUTLINE = (12, 6, 10)

SCHOOLS = {
    "Fire": "#ff6a2a", "Water": "#7fd8ff", "Air": "#d8e4ee", "Earth": "#b8864a",
    "Flora": "#6fcf6a", "Shadow": "#7a5aa0", "Blood": "#c4162f", "chants": "#d9c98a", "chronicle": "#8a7a5a",
}


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c + (255,))


def spine(w, h, base, rng, tome):
    """One book seen from its spine: leather with worn speckle, a darker left edge and lit ridge, bands, a gold panel for a tome."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            k = 1.0
            if x <= 1:
                k = 0.62
            elif x == 2:
                k = 1.25
            elif x >= w - 3:
                k = 0.72
            k *= 1.0 + rng.uniform(-0.07, 0.07)
            if rng.random() < 0.05:
                k *= 0.8
            put(img, x, y, shade(base, k))
    # the head and tail: a band with a ridge below it
    for y in range(0, 3):
        for x in range(w):
            put(img, x, y, shade(base, 0.62 + 0.05 * y))
    for y in range(h - 3, h):
        for x in range(w):
            put(img, x, y, shade(base, 0.6))
    for x in range(1, w - 1):
        put(img, x, 3, GOLD if tome else shade(base, 1.3))
        put(img, x, h - 4, GOLD if tome else shade(base, 1.3))
    if tome:
        # two gold rings under the head and above the tail, and a darker panel for the name
        for y in (6, h - 7):
            for x in range(1, w - 1):
                put(img, x, y, GOLD)
            for x in range(1, w - 1):
                put(img, x, y - 1, shade(GOLD, 0.55))
        for y in range(10, h - 11):
            for x in range(4, w - 4):
                put(img, x, y, shade(base, 0.5))
        for y in (9, h - 10):
            for x in range(4, w - 4):
                put(img, x, y, GOLD_LIGHT)
        for y in range(9, h - 9):
            put(img, 3, y, shade(GOLD, 0.8))
            put(img, w - 4, y, shade(GOLD, 0.7))
    else:
        for _ in range(rng.randint(1, 3)):
            y = rng.randint(7, h - 9)
            for x in range(1, w - 1):
                put(img, x, y, shade(base, 1.35))
                put(img, x, y + 1, shade(base, 0.7))
        if rng.random() < 0.6:  # a worn title, a few dashes down the spine
            y = rng.randint(h // 3, h // 2)
            for k in range(rng.randint(3, 6)):
                put(img, w // 2, y + k * 2, shade(base, 1.5))
    # outline
    out = img.copy()
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3] and (x in (0, w - 1) or y in (0, h - 1)):
                put(out, x, y, OUTLINE)
    return out


def flat_stack(count, rng):
    """Books lying one on another, their page-edges to the front."""
    w = 30
    img = Image.new("RGBA", (w + 4, count * 8), (0, 0, 0, 0))
    for i in range(count):
        top = i * 8
        cover = shade(hexc(rng.choice(["#4a1c24", "#1f3a3a", "#3a2a4a", "#4a3a1c", "#243a24"])), 1.0)
        shift = rng.randint(0, 3)
        for y in range(8):
            for x in range(w):
                if y in (0, 7):
                    c = shade(cover, 0.75)
                elif y in (1, 6):
                    c = shade(cover, 1.0)
                else:
                    c = (222, 204, 164) if x > 2 else shade(cover, 0.7)  # the pages, with the spine at the left
                    if (x + y) % 4 == 0 and x > 2:
                        c = (196, 176, 136)
                put(img, x + shift, top + y, c)
        for x in range(w):
            put(img, x + shift, top, OUTLINE)
            put(img, x + shift, top + 7, OUTLINE)
        for y in range(8):
            put(img, shift, top + y, OUTLINE)
            put(img, shift + w - 1, top + y, OUTLINE)
    return img


def grain(img, box, base, rng, horizontal=True, strength=0.1):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        for x in range(x0, x1):
            k = 1.0 + rng.uniform(-strength, strength)
            put(img, x, y, shade(base, k))
    for _ in range(int((x1 - x0) * (y1 - y0) / 14)):
        x = rng.randint(x0, x1 - 1)
        y = rng.randint(y0, y1 - 1)
        run = rng.randint(3, 9)
        for k in range(run):
            if horizontal:
                put(img, x + k, y, shade(base, 0.78))
            else:
                put(img, x, y + k, shade(base, 0.78))


def bookcase(w, h, boards, rng):
    """An empty case: a dark back of planks, two posts, a moulded top and the boards the books stand on."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wood = (86, 52, 36)
    # back
    grain(img, (8, 8, w - 8, h - 10), (46, 29, 25), rng, horizontal=False, strength=0.12)
    for x in range(20, w - 8, 28):  # the joins between the back planks
        for y in range(8, h - 10):
            put(img, x, y, (28, 16, 15))
    # posts
    for x0 in (0, w - 8):
        grain(img, (x0, 0, x0 + 8, h), wood, rng, horizontal=False, strength=0.1)
        for y in range(h):
            put(img, x0, y, OUTLINE)
            put(img, x0 + 7, y, OUTLINE)
            put(img, x0 + (1 if x0 == 0 else 6), y, shade(wood, 1.3 if x0 == 0 else 0.7))
    # top moulding
    grain(img, (0, 0, w, 8), wood, rng, strength=0.1)
    for x in range(w):
        put(img, x, 0, OUTLINE)
        put(img, x, 1, shade(wood, 1.35))
        put(img, x, 6, shade(wood, 0.7))
        put(img, x, 7, OUTLINE)
    # boards: the lit top edge, the face, and the shadow it throws on the back below it
    for top, thick in boards:
        for k in range(1, 4):
            for x in range(8, w - 8):
                put(img, x, top + thick + k - 1, (14 - 3 * k + 14, 8 + 4, 8 + 4))
        grain(img, (0, top, w, top + thick), wood, rng, strength=0.09)
        for x in range(w):
            put(img, x, top, shade(wood, 1.4))
            put(img, x, top + thick - 1, OUTLINE)
            put(img, x, top - 1, OUTLINE) if x < 8 or x >= w - 8 else None
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(7)
    boards = [(70, 6), (138, 6), (206, 10)]
    bookcase(420, 216, boards, rng).save(os.path.join(OUT, "bookcase.png"))
    for name, color in SCHOOLS.items():
        r = random.Random(sum(map(ord, name)))
        spine(24, 60, shade(hexc(color), 0.5), r, True).save(os.path.join(OUT, "tome_%s.png" % name))
    palette = ["#4a1c24", "#1f3a3a", "#3a2a4a", "#4a3a1c", "#243a24", "#2a2a3a", "#5a2a1a", "#33241c", "#1c2a3a", "#4a2a3a"]
    for n in range(14):
        r = random.Random(100 + n)
        spine(r.randint(11, 19), r.randint(34, 56), hexc(r.choice(palette)), r, False).save(os.path.join(OUT, "filler_%d.png" % n))
    for n, count in enumerate([2, 3, 4]):
        flat_stack(count, random.Random(300 + n)).save(os.path.join(OUT, "stack_%d.png" % n))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
