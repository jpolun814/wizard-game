"""Draws art/particles/rain_streak.png: one streak of rain, a thin pixel line that fades in towards its head, on the same 128 px
canvas as the other weather particles (Fx.TEX_SIZE), so Weather scales it the same way. No download: it is a few squares of pixels,
like the pixel snowflakes, and made here so the file can be remade.

    python -I tools/prepare_rain.py
"""
from PIL import Image

SIZE = 128
image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
top, bottom = 40, 88  # the streak's rows
for y in range(top, bottom):
    alpha = int(255 * (y - top + 1) / (bottom - top))  # faint at the tail, bright at the head
    for x in (62, 63, 64, 65):
        image.putpixel((x, y), (255, 255, 255, alpha))
image.save("art/particles/rain_streak.png")
print("art/particles/rain_streak.png")
