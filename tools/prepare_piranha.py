"""Makes art/mobs/piranha/frame_0..3.png: the swimming fish of the piranha pit, from the red fish of "Cute Fish Sprites" by chips8688
(opengameart.org/content/cute-fish-sprites, OGA-BY 3.0: credit required), the swim row of the 64-pixel sheet, darkened a little to sit in
the game's gloom. Run with: python -I tools/prepare_piranha.py <fish_sprite_sheet_64.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
OUT = os.path.join(ROOT, "art", "mobs", "piranha")
os.makedirs(OUT, exist_ok=True)
sheet = Image.open(sys.argv[1]).convert("RGBA")
COLUMN, ROW = 12, 17  # the red fish, and the swim animation
frames = [sheet.crop(((COLUMN + k) * 64, ROW * 64, (COLUMN + k) * 64 + 64, ROW * 64 + 64)) for k in range(4)]
box = None
for f in frames:
    b = f.getbbox()
    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
for i, f in enumerate(frames):
    f = f.crop(box)
    for x in range(f.width):
        for y in range(f.height):
            r, g, b, a = f.getpixel((x, y))
            if a:
                f.putpixel((x, y), (int(r * 0.78), int(g * 0.7), int(b * 0.7), a))
    f.save(os.path.join(OUT, "frame_%d.png" % i))
print("wrote 4 frames", frames[0].crop(box).size)
