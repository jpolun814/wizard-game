"""Makes the animated page strips from art/props/page.png, so a page of the spellbook moves like paper and not like a board:
  art/props/page_flutter.png       16 frames, a page in a breeze: it sways on its edge, bends and settles (a page floating in the world, a page in the sky)
  art/props/page_rustle.png        16 frames, the same barely stirring (the pages of a fan)
  art/props/page_tumble.png       12 frames, a page turning over and over as it flies (a page flying to its reader)
  art/props/page_tumble_small.png 12 frames, the same at the size of a page in the opening scene
Each frame is a row cell; the game reads a strip as `hframes`. The page is turned about its upright axis (narrower, one edge nearer and taller),
bent in a wave down its length, and shown from the back (plain parchment, no ink) when it has turned over. Every pixel is sampled from the
page with nearest-neighbor, so it stays pixel art. Run with: python -I tools/prepare_page_frames.py"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DARK = (36, 22, 30, 255)


def inner_page() -> Image.Image:
    """The page without its dark line and margin (those are put back on every frame, since the shape changes)."""
    src = Image.open(os.path.join(ROOT, "art", "props", "page.png")).convert("RGBA")
    for x in range(src.width):
        for y in range(src.height):
            if src.getpixel((x, y)) == DARK:
                src.putpixel((x, y), (0, 0, 0, 0))
    return src.crop(src.getbbox())


def back_of(front: Image.Image) -> Image.Image:
    """The back of the sheet: the parchment with the ink painted over by the colors around it, a shade darker."""
    back = front.copy()
    paper = []
    for x in range(back.width):
        for y in range(back.height):
            r, g, b, a = back.getpixel((x, y))
            if a and r > 150:  # parchment is light; ink is dark red-brown
                paper.append((r, g, b))
    mean = tuple(sum(c[i] for c in paper) // len(paper) for i in range(3))
    for x in range(back.width):
        for y in range(back.height):
            r, g, b, a = back.getpixel((x, y))
            if a and r < 170:
                back.putpixel((x, y), mean + (255,))
    shade = Image.new("RGBA", back.size, (40, 25, 40, 55))
    shade.putalpha(Image.eval(back.getchannel("A"), lambda v: 55 if v else 0))
    back.alpha_composite(shade)
    return back


def outline(img: Image.Image) -> Image.Image:
    out = img.copy()
    for x in range(img.width):
        for y in range(img.height):
            if img.getpixel((x, y))[3] == 0 and any(
                    0 <= x + dx < img.width and 0 <= y + dy < img.height and img.getpixel((x + dx, y + dy))[3] > 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), DARK)
    return out


def frame(front: Image.Image, back: Image.Image, cell: tuple, turn: float, bend: float, lean: float, phase: float) -> Image.Image:
    """One frame: the page turned `turn` radians about its upright axis, bent `bend` pixels in a wave (shifted by `phase`), its top leaning `lean` pixels sideways."""
    w, h = front.size
    cw, ch = cell
    c = math.cos(turn)
    s = math.sin(turn)
    half_w = max(w * 0.5 * abs(c), 1.0)
    img = Image.new("RGBA", cell)
    source = front if c >= 0 else back
    for x in range(cw):
        dx = x + 0.5 - cw * 0.5
        u = dx / half_w  # across the page, -1 to 1 (before the lean)
        if abs(u) > 1.0:
            continue
        u_src = u if c >= 0 else -u
        sx = min(max(int((u_src * 0.5 + 0.5) * w), 0), w - 1)
        near = 1.0 + 0.16 * s * u * (1 if c >= 0 else -1)  # the edge turned toward us is taller
        shift = bend * math.sin(u * 2.2 + phase)
        for y in range(ch):
            v = (y + 0.5 - ch * 0.5 - shift) / (h * 0.5 * near)
            if abs(v) > 1.0:
                continue
            sy = min(max(int((v * 0.5 + 0.5) * h), 0), h - 1)
            px = source.getpixel((sx, sy))
            if px[3]:
                ox = x + int(round(lean * -v))
                if 0 <= ox < cw:
                    img.putpixel((ox, y), px)
    return outline(img)


def strip(name: str, front: Image.Image, cell: tuple, frames: list) -> None:
    back = back_of(front)
    out = Image.new("RGBA", (cell[0] * len(frames), cell[1]))
    for i, args in enumerate(frames):
        out.paste(frame(front, back, cell, **args), (i * cell[0], 0))
    out.save(os.path.join(ROOT, "art", "props", name))
    print("wrote", name, out.size, len(frames), "frames")


page = inner_page()
# A page in the world is about a wizard's torso (a wizard is 78 px tall): 26 x 38.
world = page.resize((26, 38), Image.NEAREST)


def repaint_ink(img: Image.Image) -> Image.Image:
    """Shrinking smears the ink, so the small page's ink is wiped and written again: a rune at the head and short lines of words, one pixel high."""
    img = img.copy()
    paper = [img.getpixel((x, y)) for x in range(img.width) for y in range(img.height) if img.getpixel((x, y))[3] and img.getpixel((x, y))[0] > 170]
    mean = tuple(sum(c[i] for c in paper) // len(paper) for i in range(3)) + (255,)
    for x in range(img.width):
        for y in range(img.height):
            if img.getpixel((x, y))[3] and img.getpixel((x, y))[0] <= 170 and 4 <= x < img.width - 4 and 4 <= y < img.height - 4:
                img.putpixel((x, y), mean)
    ink = (74, 44, 40, 255)
    for dy in range(3):
        img.putpixel((img.width // 2, 6 + dy), (120, 40, 40, 255))
    for row, (x0, x1) in enumerate([(5, 19), (5, 20), (5, 16), (5, 20), (5, 14), (5, 19)]):
        for x in range(x0, x1):
            if (x - x0) % 5 != 4:  # gaps between words
                img.putpixel((x, 13 + row * 4), ink)
    return img


world = repaint_ink(world)
CELL = (34, 48)
bend_big, lean_big = 1.8, 1.2
# A breeze: it sways about +-0.55 radians on its edge and its bend runs along it, never turning over.
# Two rhythms laid over each other (a slow sway and a quicker shiver), so the loop does not read as one regular wobble.
def breeze(i: int, gentle: float = 1.0) -> dict:
    """`gentle` calms the sway: the pages of a fan use a fifth of it, so they stir and the hand keeps its shape."""
    a = math.tau * i / 16
    return dict(turn=gentle * (0.5 * math.sin(a) + 0.14 * math.sin(2 * a + 1.0)),
                bend=gentle * bend_big * (0.45 + 0.4 * abs(math.sin(a + 0.6)) + 0.15 * math.sin(3 * a)),
                lean=gentle * (lean_big * math.sin(a + 1.0) + 0.6 * math.sin(2 * a)), phase=a + 0.5 * math.sin(2 * a))


strip("page_flutter.png", world, CELL, [breeze(i) for i in range(16)])
strip("page_rustle.png", world, CELL, [breeze(i, 0.2) for i in range(16)])
# A tumble: a whole turn over and the bend traveling down it, as a thrown sheet does.
strip("page_tumble.png", world, CELL, [
    dict(turn=math.tau * i / 12, bend=bend_big, lean=lean_big * math.sin(math.tau * i / 12), phase=math.tau * i / 6) for i in range(12)])
small = page.resize((16, 23), Image.NEAREST)
strip("page_tumble_small.png", small, (22, 30), [
    dict(turn=math.tau * i / 12, bend=1.2, lean=0.8 * math.sin(math.tau * i / 12), phase=math.tau * i / 6) for i in range(12)])
