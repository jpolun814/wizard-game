"""Makes art/mobs/piranha/frame_0..3.png: the swimming fish of the piranha pit, from the red fish in the top row of
"Swimming Fish" by Mepavi @ You're Perfect Studio (opengameart.org/content/swimming-fish, CC0 / CC-BY 4.0), recoloured
to a dark gothic palette: a murky slate-teal body, blood-red fins, the pale eye kept. Run with:
python -I tools/prepare_piranha.py <fish_full_0.png>"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "..")
OUT = os.path.join(ROOT, "art", "mobs", "piranha")
os.makedirs(OUT, exist_ok=True)

sheet = Image.open(sys.argv[1]).convert("RGBA")
frames = [sheet.crop((i * 50, 0, i * 50 + 50, 100)) for i in range(4)]
box = None
for f in frames:
    b = f.getbbox()
    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
for i, f in enumerate(frames):
    f = f.crop(box)
    for x in range(f.width):
        for y in range(f.height):
            r, g, b, a = f.getpixel((x, y))
            if a == 0:
                continue
            lum = 0.3 * r + 0.59 * g + 0.11 * b
            if lum > 215:  # the eye
                f.putpixel((x, y), (200, 200, 190, a))
            elif lum >= 100:  # the fins and the belly: blood red
                f.putpixel((x, y), (int(lum * 0.75), int(lum * 0.2), int(lum * 0.2), a))
            else:  # the body: slate-teal
                f.putpixel((x, y), (int(lum * 0.42 + 8), int(lum * 0.62 + 12), int(lum * 0.66 + 14), a))
    f.save(os.path.join(OUT, "frame_%d.png" % i))
print("wrote", OUT, box)
