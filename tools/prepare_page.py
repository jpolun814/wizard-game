"""Makes art/props/page.png: the left-hand page of the open spellbook (art/ui/book.png, frame 3), cut out as it is, to lie on the ground
as a pickup. Run with: python -I tools/prepare_page.py"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
sheet = Image.open(os.path.join(ROOT, "art", "ui", "book.png")).convert("RGBA")
page = sheet.crop((3 * 190 + 26, 32, 3 * 190 + 84, 124))
page.save(os.path.join(ROOT, "art", "props", "page.png"))
print("wrote page", page.size, page.getbbox())
