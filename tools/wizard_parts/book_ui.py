"""Redresses the spellbook's opening animation (art/ui/book.png, 7 frames of 190 x 160) to match the new closed book (props.py make_book): the cover
becomes the black-red leather with a gilt border, an eye and a strap and lock. The cover is drawn flat once, then laid onto the cover of the closed
frame and of the half-open frame (which shows it swinging), so both carry the same picture. The open frames only get the new leather colors.

    python tools/wizard_parts/book_ui.py            (restores from art_source/props/before/book_ui.png first, so it can be rerun)
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(GAME, "art_source", "props", "before", "book_ui.png")
OUT = os.path.join(GAME, "art", "ui", "book.png")
OLD_COVER, OLD_DARK = (65, 29, 49), (36, 21, 39)
LEATHER_MID, LEATHER_HI, LEATHER_DK = (106, 38, 52), (154, 68, 80), (66, 20, 34)
GILT = [(244, 210, 124), (219, 168, 76), (176, 128, 44), (110, 74, 24)]
PALE, IRIS = (214, 206, 176), (138, 90, 208)
IRON = [(164, 164, 184), (108, 108, 132), (68, 68, 90)]
W, H = 190, 160


def flat_cover(w, h):
    px = np.zeros((h, w, 3), np.uint8)
    px[:] = LEATHER_MID
    px[:, :3] = LEATHER_HI  # a lit left edge
    yy, xx = np.mgrid[0:h, 0:w]
    px[((xx * 5 + yy * 3) % 23 == 0)] = LEATHER_DK  # worn flecks
    for inset in (7, 9):  # a double gilt border
        c = GILT[1] if inset == 7 else GILT[2]
        px[inset, inset:w - inset] = c
        px[h - 1 - inset, inset:w - inset] = c
        px[inset:h - inset, inset] = c
        px[inset:h - inset, w - 1 - inset] = c
    cx, cy = w / 2, h * 0.36
    def ell(rx, ry):
        return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1
    r_out = w * 0.3
    dist = np.hypot((xx - cx) / 1.0, (yy - cy) / 1.0)
    ang = np.arctan2(yy - cy, xx - cx)
    px[(dist <= r_out) & (dist >= r_out - 3)] = GILT[1]  # a ring, and inside it an eight-pointed star: a seal
    reach = r_out * (0.42 + 0.5 * np.abs(np.cos(4 * ang)) ** 1.6)
    star = dist <= reach
    px[star] = GILT[2]
    px[star & (xx < cx) & (yy < cy)] = GILT[0]
    px[(dist <= r_out - 3) & ~star & (dist >= r_out - 5)] = LEATHER_DK
    px[dist <= w * 0.07] = IRIS
    px[(dist <= w * 0.07) & (dist >= w * 0.07 - 1.5)] = GILT[1]
    px[int(cy) - 3:int(cy) - 1, int(cx) - 3:int(cx) - 1] = (240, 230, 255)
    strap_y = int(h * 0.66)  # the strap and its lock
    px[strap_y:strap_y + 9, 9:w - 9] = LEATHER_DK
    px[strap_y, 9:w - 9] = LEATHER_HI
    lx, ly = int(cx), strap_y + 4
    px[((abs(xx - lx) < w * 0.07) & (abs(yy - ly) < h * 0.055))] = IRON[1]
    px[(abs(xx - lx) < w * 0.07) & (abs(yy - ly) < 2) & (abs(xx - lx) >= 0)] = IRON[1]
    px[(abs(xx - lx) <= 1) & (abs(yy - ly) <= 4)] = IRON[2]
    return px


def cover_box(frame):
    """The columns the cover is in, and for each its first and last row."""
    mask = np.all(frame[..., :3] == OLD_COVER, axis=-1) & (frame[..., 3] == 255)
    cols = np.nonzero(mask.any(axis=0))[0]
    return mask, cols


def main():
    sheet = np.array(Image.open(SRC).convert("RGBA"))
    out = sheet.copy()
    for k in range(7):
        f = out[:, k * W:(k + 1) * W]
        f[np.all(f[..., :3] == OLD_DARK, axis=-1) & (f[..., 3] == 255), :3] = LEATHER_DK
    base = sheet[:, 0:W]
    m0, c0 = cover_box(base)
    x0, x1 = c0.min(), c0.max()
    ys = np.nonzero(m0[:, x0:x1 + 1].any(axis=1))[0]
    y0, y1 = ys.min(), ys.max()
    art = flat_cover(x1 - x0 + 1, y1 - y0 + 1)
    for k in (0, 1):
        f = sheet[:, k * W:(k + 1) * W]
        mask, cols = cover_box(f)
        xl, xr = cols.min(), cols.max()
        dst = out[:, k * W:(k + 1) * W]
        for x in cols:
            rows = np.nonzero(mask[:, x])[0]
            top, bot = rows.min(), rows.max()
            u = int(round((x - xl) / max(xr - xl, 1) * (art.shape[1] - 1)))
            for y in rows:
                v = int(round((y - top) / max(bot - top, 1) * (art.shape[0] - 1)))
                dst[y, x, :3] = art[v, u]
    for k in range(2, 7):  # the covers around the open pages
        f = out[:, k * W:(k + 1) * W]
        f[np.all(f[..., :3] == OLD_COVER, axis=-1) & (f[..., 3] == 255), :3] = LEATHER_MID
    Image.fromarray(out, "RGBA").save(OUT)
    print("redressed the book's frames")


main()
