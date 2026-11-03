"""Cuts the new fire bolt and fire breath strips from pimen's "Fire Spell Effect 01" (see art/CREDITS.md).

    python -I tools/prepare_pimen_fire.py "<folder the rar was unpacked into>/Fire Effect 1"

Every source frame is 48x48. Each strip written here is those frames side by side, in the order they play. One frame of the breath sheet is a white
silhouette of the first full flame, a flash and not a flame, so it is left out.
"""
import sys
from PIL import Image

SIZE = 48
folder = sys.argv[1]
parts = {
    "pimen_breath": ("Fire Breath SpriteSheet.png", [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (3, 1)] + [(c, 2) for c in range(7)]),
    "pimen_breath_hit": ("Fire Breath hit effect SpriteSheet.png", [(c, 0) for c in range(1, 5)]),
    "pimen_firebolt": ("Firebolt SpriteSheet.png", [(c, 0) for c in range(0, 4)]),
    "pimen_firebolt_hit": ("Firebolt SpriteSheet.png", [(c, 0) for c in range(5, 10)]),
}
for name, (source, cells) in parts.items():
    sheet = Image.open(f"{folder}/{source}").convert("RGBA")
    strip = Image.new("RGBA", (SIZE * len(cells), SIZE))
    for i, (col, row) in enumerate(cells):
        strip.paste(sheet.crop((col * SIZE, row * SIZE, (col + 1) * SIZE, (row + 1) * SIZE)), (i * SIZE, 0))
    strip.save(f"art/fx/{name}.png")
    print(name, len(cells), "frames")
