"""Makes art/props/spellbook.png: the closed spellbook, standing upright, for the book a fallen wizard leaves lying where it fell.
It is the first frame of the book's own sheet (art/ui/book.png), cut to its edges, made half size like the page, with a clear margin for the glow the game draws
round it. Run with: python -I tools/prepare_spellbook.py"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sheet = Image.open(os.path.join(ROOT, "art", "ui", "book.png")).convert("RGBA")
frame = sheet.crop((0, 0, 190, sheet.height))
edges = frame.getbbox()
book = frame.crop(edges)
book = book.resize((book.width // 2, book.height // 2), Image.NEAREST)  # about the size of a page
out = Image.new("RGBA", (book.width + 6, book.height + 6))
out.paste(book, (3, 3))
out.save(os.path.join(ROOT, "art", "props", "spellbook.png"))
print(out.size)
