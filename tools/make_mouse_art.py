"""Draws art/ui/mouse/: the little mouse shown on a spell's page to say which buttons cast it. `mouse.png` is the body, seen from above, and
`button_left.png`, `button_middle.png` and `button_right.png` are the pixels of each button alone (the game tints a button in the school's color when the
spell needs it). All four are 15 x 19 pixels, the grain of the book's own art, and are shown at `Spellbook.SCALE / Spellbook.DETAIL` screen pixels to a pixel
with no smoothing. They replace Kenney's Input Prompts mouse (34 x 44, which had to be scaled down smooth to fit the page).
Run with: python -I tools/make_mouse_art.py"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 15, 19
INK = (58, 29, 26, 255)
FILL = (238, 222, 194, 255)
SHADE = (214, 190, 160, 255)
WHEEL = (190, 160, 128, 255)


def body_mask() -> np.ndarray:
    yy, xx = np.mgrid[0:H, 0:W]
    return (np.abs((xx - 7.0) / 6.8) ** 3.2 + np.abs((yy - 9.0) / 8.8) ** 3.2) <= 1.0


def build() -> tuple:
    body = body_mask()
    padded = np.pad(body, 1)   # (outside the picture counts as empty, so a body touching its edge still gets an outline)
    inner = body & padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:]
    edge = body & ~inner
    px = np.zeros((H, W, 4), np.uint8)
    px[inner] = FILL
    px[inner & (np.mgrid[0:H, 0:W][1] >= 11)] = SHADE   # the right side turns away from the light
    px[inner & (np.mgrid[0:H, 0:W][0] >= 15)] = SHADE   # and so does the heel
    px[edge] = INK
    px[8, 2:13][inner[8, 2:13]] = INK                      # the line under the buttons
    px[1:8, 7][inner[1:8, 7]] = INK                        # the split between the two buttons
    for y in range(2, 6):                                  # the wheel, a small ridged block over the split
        px[y, 6:9] = (*INK[:3], 255)
        px[y, 7] = WHEEL
    # Each button alone: the pixels inside its own outline.
    left = np.zeros((H, W), bool)
    right = np.zeros((H, W), bool)
    middle = np.zeros((H, W), bool)
    for y in range(1, 8):
        for x in range(W):
            if inner[y, x] and not (px[y, x][:3] == np.array(INK[:3])).all():
                if x < 7:
                    left[y, x] = True
                elif x > 7:
                    right[y, x] = True
    middle[2:6, 7] = True
    masks = {"left": left, "middle": middle, "right": right}
    out = {}
    for name, m in masks.items():
        img = np.zeros((H, W, 4), np.uint8)
        img[m] = (255, 255, 255, 255)   # white: the game tints it
        out[name] = img
    return px, out


body, buttons = build()
folder = os.path.join(ROOT, "art", "ui", "mouse")
Image.fromarray(body, "RGBA").save(os.path.join(folder, "mouse.png"))
for name, img in buttons.items():
    Image.fromarray(img, "RGBA").save(os.path.join(folder, "button_%s.png" % name))
print("wrote the mouse", (W, H))
