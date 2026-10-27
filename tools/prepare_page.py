"""Makes art/props/page.png: a loose page of the spellbook lying flat on the ground. The parchment, its ragged cream edge and its shading are
cut from the open book (art/ui/book.png, frame 3, top-left corner of the left page, mirrored to make a whole sheet); a few lines of ink are
added, and the sheet is made small, stood upright and given a dark line and a margin. Run with: python -I tools/prepare_page.py"""
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sheet = Image.open(os.path.join(ROOT, "art", "ui", "book.png")).convert("RGBA")
frame = sheet.crop((3 * 190, 0, 4 * 190, sheet.height))
quarter = frame.crop((20, 25, 20 + 32, 25 + 46))  # the top-left corner of the left page, ragged edges and all
page = Image.new("RGBA", (64, 92))
page.paste(quarter, (0, 0))
page.paste(quarter.transpose(Image.FLIP_LEFT_RIGHT), (32, 0))
page.paste(quarter.transpose(Image.FLIP_TOP_BOTTOM), (0, 46))
page.paste(quarter.transpose(Image.ROTATE_180), (32, 46))

# Lines of ink, as a hand would write them, and a rune at the head of the page.
rng = random.Random(7)
ink = (74, 44, 40, 255)
for row in range(7):
    y = 28 + row * 8
    x = 9
    end = 55 - rng.randint(0, 14)
    while x < end:
        word = rng.randint(4, 9)
        for k in range(min(word, end - x)):
            page.putpixel((x + k, y), ink)
            page.putpixel((x + k, y + 1), ink)
            if rng.random() < 0.3:
                page.putpixel((x + k, y - 1), ink)
        x += word + 3
for dx, dy in [(0, 0), (1, 0), (2, 0), (0, 1), (2, 1), (1, 2), (0, 3), (2, 3), (1, 4), (0, 5), (2, 5), (0, 6), (1, 6), (2, 6)]:
    page.putpixel((30 + dx, 8 + dy), (120, 40, 40, 255))

# Stood upright, small, with a dark line round it and a clear margin for the glow the game draws round it.
flat = page.resize((40, 58), Image.NEAREST)
edge = Image.new("RGBA", (flat.width + 6, flat.height + 6))
edge.paste(flat, (3, 3))
dark = Image.new("RGBA", edge.size)
for x in range(edge.width):
    for y in range(edge.height):
        if edge.getpixel((x, y))[3] == 0 and any(0 <= x + dx < edge.width and 0 <= y + dy < edge.height and edge.getpixel((x + dx, y + dy))[3] > 0
                                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            dark.putpixel((x, y), (36, 22, 30, 255))
edge.alpha_composite(dark)
out = Image.new("RGBA", (edge.width + 4, edge.height + 4))
out.paste(edge, (2, 2))
out.save(os.path.join(ROOT, "art", "props", "page.png"))
print("wrote page", out.size)
