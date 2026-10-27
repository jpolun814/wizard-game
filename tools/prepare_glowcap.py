"""Makes art/props/glowcap.png: the purple mushroom of Peter Field's Mushroom Sprite Pack (OpenGameArt, free to use), cropped to its pixels and
turned from purple to a pale green, so its cyan spots and stem glow against the cap. Run with: python -I tools/prepare_glowcap.py <Purple Mushroom-1.png.png>"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = Image.open(sys.argv[1]).convert("RGBA")
src = src.crop(src.getbbox())
out = Image.new("RGBA", src.size)
for x in range(src.width):
    for y in range(src.height):
        r, g, b, a = src.getpixel((x, y))
        if a == 0:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if 0.65 < h < 0.85:  # the purple cap and its outline turn to a deep forest green
            h = 0.38
        elif 0.45 < h <= 0.6:  # the cyan spots and stem turn to a pale glowing green-white
            h = 0.30
            s *= 0.55
            v = min(1.0, v * 1.15)
        r, g, b = colorsys.hsv_to_rgb(h, s, v)
        out.putpixel((x, y), (int(r * 255), int(g * 255), int(b * 255), a))
out.save(os.path.join(ROOT, "art", "props", "glowcap.png"))
print("wrote glowcap", out.size)
