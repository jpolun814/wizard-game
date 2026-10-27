"""Makes art/props/page.png: a loose page of the spellbook lying flat on the ground. The parchment, its ragged cream edge and its shading are
cut from the open book (art/ui/book.png, frame 3, top-left corner of the left page, mirrored to make a whole sheet); a few lines of ink are
added, and the sheet is laid down, seen from a little above and slightly turned. Run with: python -I tools/prepare_page.py"""
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

# Laid down: squashed to a third of its height, and the far edge pushed a little to one side.
flat = page.resize((44, 28), Image.NEAREST)
out = Image.new("RGBA", (52, 28))
for y in range(28):
    shift = int(round((27 - y) * 8 / 27))
    out.paste(flat.crop((0, y, 44, y + 1)), (shift, y))
edge = Image.new("RGBA", (out.width + 2, out.height + 2))
edge.paste(out, (1, 1))
for x in range(edge.width):  # a dark line round the sheet, so it reads against the stone
    for y in range(edge.height):
        if edge.getpixel((x, y))[3] == 0 and any(0 <= x + dx < edge.width and 0 <= y + dy < edge.height and edge.getpixel((x + dx, y + dy))[3] > 0
                                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            edge.putpixel((x, y), (36, 22, 30, 255))
out = edge.crop(edge.getbbox())
out.save(os.path.join(ROOT, "art", "props", "page.png"))
print("wrote page", out.size)
