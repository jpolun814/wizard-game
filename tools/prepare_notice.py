"""Makes art/props/notice.png, the notice pinned to the pedestal in the opening cut-scene (scripts/screens/intro.gd): the loose page's art with the
lines of writing painted out, so words can be set on it. Run from the game folder: python -I tools/prepare_notice.py"""
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BASE = (215, 181, 148, 255)
WRITING = [(74, 44, 40, 255), (122, 72, 65, 255), (120, 40, 40, 255), (231, 213, 179, 255)]
INSET = 5  # the page's rim and corners are kept


def main():
    image = Image.open(os.path.join(ROOT, "art", "props", "page.png")).convert("RGBA")
    pixels = image.load()
    for x in range(INSET, image.width - INSET):
        for y in range(INSET, image.height - INSET):
            if pixels[x, y] in WRITING:
                pixels[x, y] = BASE
    image.save(os.path.join(ROOT, "art", "props", "notice.png"))


if __name__ == "__main__":
    main()
