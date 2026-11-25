"""Draws art/ui/book.png: the spellbook's frames (7 of 475 x 400) in one strip:
  frame 0       closed, standing: the cover seen from the front (the book's spine is at the middle of the frame, the book to the right of it)
  frames 1-2    the cover swinging open to the left
  frame 3       open, the two pages the writing is laid on
  frames 4-7    a leaf turning over, right to left (played backward to turn the other way)
It is drawn at 2.5 times the detail of the book it replaced (190 x 160 frames), so one pixel of it is one pixel of the world's own art when it is shown at
`Spellbook.SCALE`; the book used to be drawn with pixels two and a half times as big as the sprites round it. The leather, the gilt and the shading come
from the same kit as the other drawn props (tools/wizard_parts/props.py); the paper, its ragged edges, the page edges and the turning leaf are drawn here.
Run with: python -I tools/make_book_art.py
(The old art, cut from a download and recolored by tools/wizard_parts/book_ui.py, is no longer used.)"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "wizard_parts"))
import props  # noqa: E402
import rig  # noqa: E402

ROOT = os.path.join(HERE, "..")
W, H = 475, 400
CENTER_X = 226            # the fold: the middle of the open book (90.5 old pixels x 2.5)
BOOK_X0, BOOK_X1 = 30, 422  # the open book's outer edges
BOOK_Y0, BOOK_Y1 = 52, 365
PAPER_Y0, PAPER_Y1 = 66, 338   # the top and bottom of the paper
LEFT_X0, RIGHT_X1 = 50, 402    # the outer edges of the two pages
STACK = 13                     # how deep the page block shows under the paper

PAPER = np.array([216, 182, 149], float)
PAPER_LIGHT = np.array([230, 205, 170], float)
PAPER_SHADE = np.array([190, 148, 116], float)
PAPER_RIM = np.array([236, 218, 184], float)
EDGE_BROWN = np.array([150, 108, 84], float)
FOLD = np.array([70, 26, 38], float)


def noise1d(n: int, seed: int, octaves=((9, 1.0), (23, 0.5), (5, 0.25))) -> np.ndarray:
    """A wandering value along a line, between about -1 and 1: the raggedness of a page's edge."""
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    for period, amp in octaves:
        knots = rng.uniform(-1, 1, n // period + 3)
        x = np.arange(n) / period
        i = x.astype(int)
        f = x - i
        f = f * f * (3 - 2 * f)
        out += amp * (knots[i] * (1 - f) + knots[i + 1] * f)
    return out / sum(a for _, a in octaves)


def paper_page(side: int) -> tuple:
    """One page of the open book (side -1 left, +1 right): the color of it and where it is, drawn flat. Returns (rgb float array H x W x 3, mask H x W)."""
    yy, xx = np.mgrid[0:H, 0:W]
    outer = LEFT_X0 if side < 0 else RIGHT_X1
    seed = 3 if side < 0 else 8
    # The outline: the outer, top and bottom edges wander a few pixels, as torn and handled parchment does; the fold edge is straight.
    top = PAPER_Y0 + 3.2 * noise1d(W, seed) + 4.0 * np.sin(np.clip(np.abs(np.arange(W) - CENTER_X) / 180.0, 0, 1) * math.pi * 0.5)  # a slight bow to the leaf
    bottom = PAPER_Y1 + 3.0 * noise1d(W, seed + 1) - 3.0 * np.sin(np.clip(np.abs(np.arange(W) - CENTER_X) / 180.0, 0, 1) * math.pi * 0.5)
    edge_x = outer + side * 0.0 + 3.4 * noise1d(H, seed + 2)
    if side < 0:
        inside = (xx >= edge_x[yy] - 0) & (xx < CENTER_X - 2)
    else:
        inside = (xx <= edge_x[yy]) & (xx > CENTER_X + 1)
    inside &= (yy >= top[xx]) & (yy <= bottom[xx])
    # How far in from the nearest ragged edge each pixel is, for the cream rim.
    d_out = np.abs(xx - edge_x[yy]) if True else 0
    d_top = yy - top[xx]
    d_bot = bottom[xx] - yy
    depth = np.minimum(np.minimum(d_out, d_top), d_bot)
    # The paper: a soft gradient that darkens toward the fold, a little grain, and a few faint stains.
    to_fold = np.abs(xx - CENTER_X)
    shade = np.clip(1.0 - to_fold / 46.0, 0, 1) ** 1.6
    rgb = PAPER[None, None, :] * (1 - shade[..., None]) + PAPER_SHADE[None, None, :] * shade[..., None]
    rng = np.random.default_rng(seed + 10)
    grain = rng.integers(-3, 4, (H, W)).astype(float)
    rgb += grain[..., None] * np.array([1.0, 1.0, 1.2])
    stain = np.zeros((H, W))
    for _ in range(7):
        cx, cy, r = rng.uniform(LEFT_X0 + 20, RIGHT_X1 - 20), rng.uniform(PAPER_Y0 + 20, PAPER_Y1 - 20), rng.uniform(14, 36)
        stain += np.clip(1.0 - np.hypot(xx - cx, yy - cy) / r, 0, 1) ** 2
    rgb -= (stain * 4.5)[..., None] * np.array([1.0, 1.4, 1.9])
    # Fibers: short lighter and darker dashes along the page.
    for _ in range(260):
        fx, fy = int(rng.integers(LEFT_X0, RIGHT_X1)), int(rng.integers(PAPER_Y0, PAPER_Y1))
        for k in range(int(rng.integers(3, 9))):
            if 0 <= fx + k < W:
                rgb[fy, fx + k] += rng.choice([-5.0, 5.0])
    # The rim: lighter where the paper is thin at its edge, then the edge line.
    rim = depth < 5.0
    rgb = np.where(rim[..., None], PAPER_RIM[None, None, :] + grain[..., None] * 0.8 - shade[..., None] * 12.0, rgb)
    line = depth < 1.5
    rgb = np.where(line[..., None], EDGE_BROWN[None, None, :], rgb)
    return rgb, inside


def build_open() -> Image.Image:
    cv = props.canvas(W, H)
    # The cover: black-red leather, lit from the upper left.
    cover = cv.poly([(BOOK_X0 + 12, BOOK_Y0), (BOOK_X1 - 12, BOOK_Y0), (BOOK_X1, BOOK_Y0 + 12), (BOOK_X1, BOOK_Y1 - 12), (BOOK_X1 - 12, BOOK_Y1),
                     (BOOK_X0 + 12, BOOK_Y1), (BOOK_X0, BOOK_Y1 - 12), (BOOK_X0, BOOK_Y0 + 12)])
    # Leather: a soft gradient (lighter at the upper left), a lit top and left edge and a shaded bottom and right edge, and a grain of worn flecks.
    mask = cover[0]
    yy0, xx0 = np.mgrid[0:H, 0:W]
    lit = np.clip(1.0 - ((xx0 - BOOK_X0) / (BOOK_X1 - BOOK_X0) * 0.55 + (yy0 - BOOK_Y0) / (BOOK_Y1 - BOOK_Y0) * 0.45), 0, 1)
    base = np.array(props.LEATHER[1], float)[None, None, :] + (np.array(props.LEATHER[0], float) - np.array(props.LEATHER[1], float))[None, None, :] * (lit[..., None] * 0.55 - 0.1)
    rng = np.random.default_rng(1)
    base += rng.integers(-5, 6, (H, W))[..., None] * np.array([1.0, 0.5, 0.6])
    for _ in range(900):  # the grain: tiny creases
        fx, fy = int(rng.integers(BOOK_X0, BOOK_X1)), int(rng.integers(BOOK_Y0, BOOK_Y1))
        n = int(rng.integers(2, 6))
        sgn = rng.choice([-14.0, 12.0])
        for k in range(n):
            if fx + k < W:
                base[fy, fx + k] += sgn
    edge_lit = (np.minimum(xx0 - BOOK_X0, yy0 - BOOK_Y0) < 3)
    edge_dark = (np.minimum(BOOK_X1 - xx0, BOOK_Y1 - yy0) < 3)
    base[edge_lit] += 24.0
    base[edge_dark] -= 26.0
    cv.px[mask, :3] = np.clip(base[mask], 0, 255).astype(np.uint8)
    cv.px[mask, 3] = 255
    cv.edge[mask] = props.LEATHER[3]
    cv.edge2[mask] = props.LEATHER[2]
    # A fine gilt line inset from the edge of the cover.
    for a, b in (((BOOK_X0 + 7, BOOK_Y0 + 6), (BOOK_X1 - 7, BOOK_Y0 + 6)), ((BOOK_X0 + 7, BOOK_Y1 - 6), (BOOK_X1 - 7, BOOK_Y1 - 6)),
                 ((BOOK_X0 + 6, BOOK_Y0 + 7), (BOOK_X0 + 6, BOOK_Y1 - 7)), ((BOOK_X1 - 6, BOOK_Y0 + 7), (BOOK_X1 - 6, BOOK_Y1 - 7))):
        props.line(cv, a, b, props.GILT[2], 0.7)
    # The paper, its page block, and the fold.
    px = cv.px.astype(float)
    for side in (-1, 1):
        rgb, inside = paper_page(side)
        px[inside, :3] = rgb[inside]
        px[inside, 3] = 255
    # The leaves under the paper: lines of page edges along the bottom, following the paper's own ragged line.
    yy, xx = np.mgrid[0:H, 0:W]
    bottom_line = PAPER_Y1 + 3.0 * noise1d(W, 4)
    for side, seed in ((-1, 4), (1, 9)):
        x0, x1 = (LEFT_X0 + 2, CENTER_X - 2) if side < 0 else (CENTER_X + 2, RIGHT_X1 - 2)
        for x in range(x0, x1):
            base = PAPER_Y1 + 3.0 * noise1d(W, seed + 1)[x] - 3.0 * math.sin(min(abs(x - CENTER_X) / 180.0, 1.0) * math.pi * 0.5)
            for k in range(STACK):
                y = int(base) + 1 + k
                if y >= H:
                    continue
                tone = PAPER_RIM if k % 3 != 2 else EDGE_BROWN
                shade = 14.0 * max(0.0, 1.0 - abs(x - CENTER_X) / 46.0)
                px[y, x, :3] = np.clip(tone - shade, 0, 255)
                px[y, x, 3] = 255
    # The fold: a dark seam with a lit lip either side.
    for x in range(CENTER_X - 2, CENTER_X + 3):
        px[PAPER_Y0 - 2:PAPER_Y1 + STACK + 2, x, :3] = FOLD if abs(x - CENTER_X) < 2 else FOLD * 1.5
        px[PAPER_Y0 - 2:PAPER_Y1 + STACK + 2, x, 3] = 255
    cv.px = np.clip(px, 0, 255).astype(np.uint8)
    # Gilt corners on the cover, each a small bracket with a rivet.
    for x, y, fx, fy in ((BOOK_X0, BOOK_Y0, 1, 1), (BOOK_X1, BOOK_Y0, -1, 1), (BOOK_X0, BOOK_Y1, 1, -1), (BOOK_X1, BOOK_Y1, -1, -1)):
        s = 27
        cv.paint(cv.poly([(x - 3 * fx, y - 3 * fy), (x + s * fx, y - 3 * fy), (x + s * fx, y + 5 * fy), (x + 5 * fx, y + 5 * fy), (x + 5 * fx, y + s * fy), (x - 3 * fx, y + s * fy)]),
                 props.GILT, hi=0.75, lo=-0.1, inner_outline=False)
        cv.px[y + 11 * fy, x + 11 * fx, :3] = props.GILT[3]
        cv.px[y + 3 * fy, x + 3 * fx, :3] = props.GILT[0]
    cv.selout()
    return Image.fromarray(cv.px, "RGBA")


# ------------------------------------------------------------------------------------------------ the closed cover
CLOSED_X0, CLOSED_X1 = 230, 420   # the closed book: from its spine to its fore-edge
CLOSED_Y1 = 357                    # the cover's bottom; the page block shows under it to BOOK_Y1


def seal(cv, cx: float, cy: float) -> None:
    """The gilt seal on the cover: a ring round an eight-pointed star with a small violet gem at its heart."""
    cv.paint(cv.ellipse((cx, cy), 50, 50), props.GILT, hi=0.5, lo=-0.1)
    cv.paint(cv.ellipse((cx, cy), 41, 41), props.LEATHER, hi=0.2, lo=-0.4)
    star = [(cx + math.cos(k * math.pi / 8 - math.pi / 2) * (38.0 if k % 2 == 0 else 15.0), cy + math.sin(k * math.pi / 8 - math.pi / 2) * (38.0 if k % 2 == 0 else 15.0))
            for k in range(16)]
    cv.paint(cv.poly(star), props.GILT, hi=0.4, lo=-0.1)
    cv.paint(cv.ellipse((cx, cy), 10, 10), props.ramp("#c8a0ff", "#8a5ad0", "#5a2e98", "#2a1060"), hi=0.4, lo=-0.1)


def build_cover_front(with_block: bool) -> Image.Image:
    """The front of the cover, standing: leather, a gilt border and corner brackets, the seal, and a strap with an iron lock across the lower third.
    With `with_block`, the page block shows along the fore-edge and the foot, as in the closed book."""
    cv = props.canvas(W, H)
    x0, x1, y0, y1 = CLOSED_X0, CLOSED_X1, BOOK_Y0, CLOSED_Y1
    cover = cv.poly([(x0, y0 + 6), (x0 + 6, y0), (x1 - 6, y0), (x1, y0 + 6), (x1, y1 - 6), (x1 - 6, y1), (x0 + 6, y1), (x0, y1 - 6)])
    yy, xx = np.mgrid[0:H, 0:W]
    lit = np.clip(1.0 - ((xx - x0) / (x1 - x0) * 0.6 + (yy - y0) / (y1 - y0) * 0.4), 0, 1)
    base = np.array(props.LEATHER[1], float)[None, None, :] + (np.array(props.LEATHER[0], float) - np.array(props.LEATHER[1], float))[None, None, :] * (lit[..., None] * 0.55 - 0.1)
    rng = np.random.default_rng(5)
    base += rng.integers(-5, 6, (H, W))[..., None] * np.array([1.0, 0.5, 0.6])
    for _ in range(700):
        fx, fy = int(rng.integers(x0, x1)), int(rng.integers(y0, y1))
        sgn = rng.choice([-14.0, 12.0])
        for k in range(int(rng.integers(2, 6))):
            if fx + k < W:
                base[fy, fx + k] += sgn
    base[(xx - x0) < 18] -= 14.0   # the spine side rolls away into shadow
    base[((xx - x0) >= 18) & ((xx - x0) < 21)] += 20.0  # with a lit ridge where the cover begins
    mask = cover[0]
    cv.px[mask, :3] = np.clip(base[mask], 0, 255).astype(np.uint8)
    cv.px[mask, 3] = 255
    cv.edge[mask] = props.LEATHER[3]
    cv.edge2[mask] = props.LEATHER[2]
    mid = (x0 + 18 + x1) / 2.0
    # A double gilt border inside the cover.
    for inset, tone in ((14, props.GILT[1]), (19, props.GILT[2])):
        left, right, top, bottom = x0 + 18 + inset, x1 - inset, y0 + inset, y1 - inset
        for a, b in (((left, top), (right, top)), ((left, bottom), (right, bottom)), ((left, top), (left, bottom)), ((right, top), (right, bottom))):
            props.line(cv, a, b, tone, 0.8)
    seal(cv, mid, 170)
    # The strap and its lock.
    strap = cv.poly([(x0 + 18, 262), (x1, 262), (x1, 282), (x0 + 18, 282)])
    cv.paint(strap, props.LEATHER, hi=0.5, lo=0.0, bias=-0.35)
    props.line(cv, (x0 + 18, 263), (x1 - 1, 263), props.GILT[2], 0.6)
    props.line(cv, (x0 + 18, 281), (x1 - 1, 281), props.GILT[3], 0.6)
    cv.paint(cv.ellipse((mid, 272), 13, 15), props.IRONP, hi=0.4, lo=-0.1)
    cv.px[266:279, int(mid) - 1:int(mid) + 1, :3] = props.IRONP[3]
    cv.paint(cv.ellipse((mid, 272), 4, 4), props.IRONP, hi=0.9, lo=0.5)
    # Gilt brackets on the four corners of the cover.
    for x, y, fx, fy in ((x0 + 18, y0, 1, 1), (x1, y0, -1, 1), (x0 + 18, y1, 1, -1), (x1, y1, -1, -1)):
        s_ = 26
        cv.paint(cv.poly([(x - 3 * fx, y - 3 * fy), (x + s_ * fx, y - 3 * fy), (x + s_ * fx, y + 5 * fy), (x + 5 * fx, y + 5 * fy), (x + 5 * fx, y + s_ * fy), (x - 3 * fx, y + s_ * fy)]),
                 props.GILT, hi=0.75, lo=-0.1, inner_outline=False)
        cv.px[y + 10 * fy, x + 10 * fx, :3] = props.GILT[3]
    px = cv.px
    if with_block:
        out = px.astype(float)
        for k in range(BOOK_Y1 - CLOSED_Y1 + 1):  # the foot: page edges under the cover
            y = CLOSED_Y1 + 1 + k
            out[y, x0 + 10:x1 - 4, :3] = PAPER_RIM if k % 3 != 2 else EDGE_BROWN
            out[y, x0 + 10:x1 - 4, 3] = 255
        for k in range(6):  # the fore-edge
            x = x1 + 1 + k
            out[y0 + 8:CLOSED_Y1 - 2, x, :3] = PAPER_RIM if k % 3 != 2 else EDGE_BROWN
            out[y0 + 8:CLOSED_Y1 - 2, x, 3] = 255
        px = out.astype(np.uint8)
    cv.px = px
    cv.selout()
    return Image.fromarray(cv.px, "RGBA")


# ------------------------------------------------------------------------------------------------ a leaf in the air
LIFT = 0.2   # how much of a height off the table shows as a rise up the screen (little, or a lifted sheet would leave the top of the frame)


def leaf(base: np.ndarray, source: np.ndarray, spine_x: int, length: int, alphas, lift: float = LIFT) -> np.ndarray:
    """Lays a stiff sheet of paper, bent along its length, over `base`. `source` is the sheet seen flat (full frame, its spine at `spine_x`, running out to the
    right by `length` columns); `alphas(s)` is the angle the sheet makes with the table at each column s along it (0 lying out flat to the right, pi/2
    standing, pi lying flat to the left). The columns are laid down one by one, the highest last, and lit by how they face."""
    out = base.copy()
    cols = []
    X = Z = 0.0
    for s in range(length):
        a = alphas(s)
        X += math.cos(a)
        Z += math.sin(a)
        cols.append((Z, X, s, a))
    cy = (BOOK_Y0 + BOOK_Y1) / 2.0
    for Z, X, s, a in sorted(cols):
        x_src = spine_x + s
        if not 0 <= x_src < W:
            continue
        col = source[:, x_src]
        rows = np.nonzero(col[:, 3] > 0)[0]
        if rows.size == 0:
            continue
        scale = 1.0 + Z * 0.0007
        if a < math.pi / 2:
            face = 0.76 + 0.24 * math.cos(a)
        else:
            face = 0.7 + 0.22 * (-math.cos(a))
        xt = int(round(spine_x + X))
        ys = np.round(cy + (rows - cy) * scale - Z * lift).astype(int)
        for k in range(2 if abs(math.cos(a)) < 0.5 else 1):  # a column laid on a steep stretch is laid twice, so no gap shows
            xs = xt + k
            if not 0 <= xs < W:
                continue
            for rr, yy_ in zip(rows, ys):
                for dy in ((0, 1) if scale > 1.0 else (0,)):
                    if 0 <= yy_ + dy < H:
                        out[yy_ + dy, xs, :3] = np.clip(col[rr, :3].astype(float) * face, 0, 255)
                        out[yy_ + dy, xs, 3] = 255
    return out


def paper_leaf_source(side: int) -> np.ndarray:
    """One page seen flat, alone, as the sheet that turns."""
    rgb, inside = paper_page(side)
    img = np.zeros((H, W, 4), np.uint8)
    img[inside, :3] = np.clip(rgb[inside], 0, 255).astype(np.uint8)
    img[inside, 3] = 255
    return img


def frames_turn(open_img: np.ndarray) -> list:
    src = paper_leaf_source(1)
    length = RIGHT_X1 - CENTER_X - 1
    frac = lambda s: s / float(length)
    curl = lambda s: 0.12 + 1.1 * frac(s) ** 2.2        # lying on the right with its outer edge peeling up
    lifted = lambda s: 0.5 + 0.95 * frac(s)             # standing up, leaning over to the right
    f4 = curl
    f5 = lifted
    f6 = lambda s: math.pi - lifted(s)                  # over to the left, leaning
    f7 = lambda s: math.pi - curl(s)                    # laid down on the left, its outer edge still lifting
    return [leaf(open_img, src, CENTER_X + 2, length, fn) for fn in (f4, f5, f6, f7)]


def frames_swing(open_img: np.ndarray, front: np.ndarray) -> list:
    """The cover swinging open on its spine: seen from the front until it stands, then from inside. Under it, the right half of the open book."""
    right = open_img.copy()
    right[:, :CENTER_X - 1] = 0   # the left half of the book is the cover's own inside
    inside = np.zeros_like(open_img)
    for s in range(CENTER_X - BOOK_X0):  # the inside of the cover, mirrored so that its spine is at the left of the sheet
        inside[:, CENTER_X + s] = open_img[:, CENTER_X - 1 - s]
    length = CLOSED_X1 - CENTER_X
    out = []
    for theta, src in ((0.9, front), (2.25, inside)):
        alphas = lambda s, th=theta: th + 0.18 * math.sin(math.pi * s / length)
        out.append(leaf(right, src, CENTER_X, length, alphas, 0.08))
    return out


def assemble() -> Image.Image:
    open_img = np.array(build_open())
    front = np.array(build_cover_front(False))
    closed = np.array(build_cover_front(True))
    sheet = [closed] + frames_swing(open_img, front) + [open_img] + frames_turn(open_img)
    strip = Image.new("RGBA", (W * len(sheet), H))
    for i, f in enumerate(sheet):
        strip.paste(Image.fromarray(f, "RGBA"), (i * W, 0))
    return strip


# ------------------------------------------------------------------------------------------------ the frame of the stroke's box
FRAME_W, FRAME_H = 144, 112  # art pixels; the game shows it at `Spellbook.CELL` screen pixels to a pixel, so it is as wide as a page's writing
FRAME_INK = (122, 80, 64)      # the ink of the writing, a shade lighter so the ornament stays behind the stroke
FRAME_SOFT = (164, 126, 104)   # the same ink, fainter, for the fine vine
CORNER = 30                   # the size of a corner scroll


class Pen:
    """Plots single pixels and lines of them (Bresenham), so every stroke of the frame is a clean line of pixels."""

    def __init__(self, w: int, h: int):
        self.px = np.zeros((h, w, 4), np.uint8)
        self.w, self.h = w, h

    def dot(self, x, y, col=FRAME_INK):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y, x] = (*col, 255)

    def line(self, a, b, col=FRAME_INK):
        x0, y0, x1, y1 = int(round(a[0])), int(round(a[1])), int(round(b[0])), int(round(b[1]))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.dot(x0, y0, col)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def path(self, pts, col=FRAME_INK):
        for a, b in zip(pts, pts[1:]):
            self.line(a, b, col)


def scroll(cx, cy, r0, r1, theta0, turns, hold=0.0, step=0.04):
    """A scroll: from radius r0 at angle theta0 winding in to r1 after `turns` turns (positive turns go counterclockwise on the screen). For the first `hold`
    turns the radius stays at r0, so the scroll leaves its starting point as a round curve before it begins to wind in."""
    pts = []
    n = max(int(abs(turns) * 6.2832 / step), 2)
    for i in range(n + 1):
        t = i / n
        a = theta0 - turns * 6.2832 * t
        k = max(0.0, (t * abs(turns) - hold) / max(abs(turns) - hold, 1e-6))
        r = r0 + (r1 - r0) * k ** 0.9
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def sparkle(pen: Pen, x, y, arm=2, col=FRAME_INK):
    pen.dot(x, y, col)
    for k in range(1, arm + 1):
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            pen.dot(x + dx, y + dy, col)


def corner_tile() -> np.ndarray:
    """The top-left corner: one large scroll whose first quarter turn runs from the top edge's line round to the side edge's line (both leave it tangent), then
    winds in on itself. The other corners are this one turned over."""
    pen = Pen(CORNER, CORNER)
    pen.path(scroll(15, 15, 9.5, 2.2, -math.pi / 2, 2.35, hold=0.5))
    sparkle(pen, 4, 4, 1)
    return pen.px


def half_edge(length: int) -> np.ndarray:
    """One half of an edge, from where a corner scroll lets go of it to the middle of the edge, as a picture 18 rows high with the border line along row 5:
    the line, a fine vine of tiny leaves beside it, a scroll hanging from it, and the left half of a lozenge at the end (the other half is this turned over)."""
    pen = Pen(length + 1, 18)
    pen.line((0, 5), (length - 7, 5))
    pen.path([(length - 7, 5), (length, 1)])
    pen.path([(length - 7, 5), (length, 9)])
    pen.dot(length, 5)
    pen.dot(length - 3, 5)
    if length > 30:   # a scroll hangs from the line, and a vine runs along it from the corner to the scroll
        cx = length - 18
        pen.line((cx, 5), (cx, 7))
        pen.path(scroll(cx, 12, 5.2, 1.6, -math.pi / 2, 1.25))
        for x in range(13, cx - 8):
            pen.dot(x, 11 + 1.5 * math.sin(x * 0.5), FRAME_SOFT)
        for x in range(16, cx - 9, 9):   # a leaf at every third swing, up and down in turn
            side = 1 if (x // 9) % 2 == 0 else -1
            pen.dot(x, 11 + side * 3, FRAME_SOFT)
            pen.dot(x + 1, 11 + side * 4, FRAME_SOFT)
    return pen.px


def build_frame() -> Image.Image:
    """The ornament round the box where a spell's stroke is drawn on its page: line art in the ink of the writing, with no fill. A scroll in each corner, one
    unbroken line from scroll to scroll round the box with a fine vine beside it, and a lozenge with a hanging curl at the middle of every side. It is one picture
    of the size the game shows it at (not stretched), so every line stays one pixel wide."""
    w, h = FRAME_W, FRAME_H
    out = np.zeros((h, w, 4), np.uint8)

    def lay(tile: np.ndarray, x: int, y: int) -> None:
        region = out[y:y + tile.shape[0], x:x + tile.shape[1]]
        mask = tile[..., 3] > 0
        region[mask] = tile[mask]

    corner = corner_tile()
    lay(corner, 0, 0)
    lay(corner[:, ::-1], w - CORNER, 0)
    lay(corner[::-1], 0, h - CORNER)
    lay(corner[::-1, ::-1], w - CORNER, h - CORNER)
    # The top and the foot: a half-edge from each corner to the middle, and its mirror.
    top = half_edge(w // 2 - 15)
    lay(top, 15, 0)
    lay(top[:, ::-1], w // 2, 0)
    foot = top[::-1]
    lay(foot, 15, h - 18)
    lay(foot[:, ::-1], w // 2, h - 18)
    # The sides, the same turned on their side.
    side = half_edge(h // 2 - 15).transpose(1, 0, 2)
    lay(side, 0, 15)
    lay(side[::-1], 0, h // 2)
    lay(side[:, ::-1], w - 18, 15)
    lay(side[::-1, ::-1], w - 18, h // 2)
    return Image.fromarray(out, "RGBA")


if __name__ == "__main__":
    strip = assemble()
    out = os.environ.get("BOOK_OUT") or os.path.join(ROOT, "art", "ui")
    strip.save(os.path.join(out, "book.png" if not os.environ.get("BOOK_OUT") else "book_strip_test.png"))
    print("wrote the book", strip.size)
    build_frame().save(os.path.join(out, "book_frame.png" if not os.environ.get("BOOK_OUT") else "book_frame_test.png"))
