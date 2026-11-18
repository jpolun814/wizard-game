"""The jungle's props, drawn with the same rig as the wizard parts (rig.py): shaded shapes lit from the upper left, no outlines,
each edge taking the material's own dark tone (selout). Run it from anywhere:

    python tools/wizard_parts/props.py            # all of them
    python tools/wizard_parts/props.py tree vine  # some

It writes art/props/great_oak.png (the great tree and the Great Oak spell), jungle_vine.png, dusk_vine.png, flytrap.png,
bramble_1..3.png and art/mobs/piranha_small/frame_0..3.png. Never edit those PNGs by hand: change this file and run it.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
from rig import ramp, add, ORB  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
ART = os.path.join(ROOT, "art")

def dim(rmp, k):
    """A ramp made darker, so that nothing here is bright: every color is scaled toward black by k, the highlights a little more than the shadows."""
    return [tuple(int(c * k * (0.9 + 0.1 * n / 3.0)) if not isinstance(c, float) else c * k for c in col) for n, col in enumerate(rmp)]


BARK = ramp("#8a6a4c", "#5c4232", "#38261e", "#180e12")
MOSS = dim(ramp("#c4e888", "#80b45c", "#477a44", "#1c3a28"), 0.62)
LEAF_FAR = ramp("#2c6048", "#214a3a", "#16322c", "#0a1a18")
LEAF_NEAR = dim(ramp("#6aa466", "#468256", "#2c5a44", "#14301f"), 0.7)
VINE = dim(ramp("#b4dc94", "#68a468", "#34684c", "#143028"), 0.62)
BONE = ramp("#f4ecd0", "#cfc2a0", "#8e8068", "#463c3c")
CANE = ramp("#8a5a68", "#5c3450", "#38203c", "#1a0e22")
BERRY = ramp("#ff8c98", "#d03450", "#8a1832", "#40081a")
FLESH = ramp("#d4505e", "#98263e", "#5a1232", "#280816")
STALK = ramp("#68b866", "#3a8450", "#235a3e", "#103024")
PLANT = ramp("#4a7c60", "#2c5448", "#1a3436", "#0a1618")
FISH_TOP = ramp("#8ea8a8", "#566e76", "#34464e", "#161e26")
FISH_BELLY = ramp("#f0a468", "#d4603a", "#9a3228", "#481418")
FIN = ramp("#e8704c", "#bc3c34", "#802428", "#3a1018")
EYE = ramp("#fff4a0", "#f0c030", "#b07818", "#503008")
SOIL = ramp("#6a4a40", "#46302e", "#2a1c22", "#140c14")


class Canvas(rig.Canvas):
    """The rig's canvas at the size of the prop, with a second edge color so a lit edge is darker than the material and a shaded one darker still."""

    def __init__(self):
        super().__init__()
        self.edge2 = np.zeros((rig.H, rig.W, 3), np.uint8)

    def paint(self, ms, rmp, hi=0.42, lo=-0.2, inner_outline=False, bias=0.0):
        super().paint(ms, rmp, hi=hi, lo=lo, inner_outline=inner_outline, bias=bias)
        self.edge2[ms[0]] = rmp[2]

    def selout(self):
        a = self.px[..., 3] == 255
        out = self.px.copy()
        for dy, dx, lit in ((-1, 0, True), (0, -1, True), (1, 0, False), (0, 1, False)):
            empty = ~a
            nb = np.ones_like(a)
            if dy == -1:
                nb[1:, :] = empty[:-1, :]
            elif dy == 1:
                nb[:-1, :] = empty[1:, :]
            elif dx == -1:
                nb[:, 1:] = empty[:, :-1]
            else:
                nb[:, :-1] = empty[:, 1:]
            inner = np.roll(np.roll(a, -2 * dy, 0), -2 * dx, 1)
            sel = a & nb & inner
            out[sel, :3] = (self.edge2 if lit else self.edge)[sel]
        self.px = out

    def save(self, path):
        self.selout()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Image.fromarray(self.px, "RGBA").save(path)


def canvas(w, h):
    rig.W, rig.H = w, h
    rig.yy, rig.xx = np.mgrid[0:h, 0:w]
    return Canvas()


def limb(pts, radii, samples=8):
    """One continuous tapered shape along a smoothed path, shaded as one piece."""
    best = None
    for (a, b), (ra, rb) in zip(zip(pts, pts[1:]), zip(radii, radii[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dy * dy or 1e-6
        t = np.clip(((rig.xx - a[0]) * dx + (rig.yy - a[1]) * dy) / L2, 0, 1)
        ox, oy = rig.xx - (a[0] + t * dx), rig.yy - (a[1] + t * dy)
        r = ra + (rb - ra) * t
        ratio = np.sqrt(ox * ox + oy * oy) / r
        s = (ox * rig.LIGHT[0] + oy * rig.LIGHT[1]) / r
        if best is None:
            best = [ratio, s]
        else:
            closer = ratio < best[0]
            best[0] = np.where(closer, ratio, best[0])
            best[1] = np.where(closer, s, best[1])
    return best[0] <= 1.0, best[1]


def curve(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in (i / n for i in range(n + 1))]


def cluster(cv, cx, cy, r, seed, rmp, squash=0.8, lobes=9):
    """A clump of leaves: the union of several ellipses, shaded as ONE mass from its middle (so the lit side is lit all across it)."""
    rng = random.Random(seed)
    mask = np.zeros((rig.H, rig.W), bool)
    for _ in range(lobes):
        c = (cx + rng.uniform(-r, r) * 0.8, cy + rng.uniform(-r, r) * 0.45)
        m, _ = cv.ellipse(c, r * rng.uniform(0.38, 0.62), r * squash * rng.uniform(0.38, 0.62))
        mask |= m
    m, _ = cv.ellipse((cx, cy), r * 0.8, r * squash * 0.8)
    mask |= m
    s = ((rig.xx - cx) * rig.LIGHT[0] + (rig.yy - cy) * rig.LIGHT[1]) / r
    s = s + 0.12 * np.sin(rig.xx * 1.7 + seed) * np.sin(rig.yy * 1.9 + seed * 0.7)  # a ragged edge to the light, so it is not a clean gradient
    cv.paint((mask, s), rmp, hi=0.35, lo=-0.15)


# ------------------------------------------------------------------- the great tree
GROUND, FOOT = 232, 92
LEDGES = [[30, -36, -10], [112, -44, -12], [156, 36, 88], [212, -26, 44]]  # must match JungleTree.LEDGES


# The tree takes the colors of the world it grows in: bark, the strip on top of each bough (where you stand), far leaves, near leaves.
THEMES = {
    "jungle": (BARK, MOSS, LEAF_FAR, LEAF_NEAR),
    "graveyard": (ramp("#7a6a7c", "#4c3e54", "#2c2236", "#120c1c"), ramp("#b8c49a", "#7c8c6e", "#4a5a52", "#222e30"),
                  ramp("#3c3050", "#2a2240", "#1a1430", "#0c0818"), ramp("#6a5a74", "#4a3e5c", "#322a44", "#181226")),
    "mountains": (ramp("#8a8a98", "#5c5c70", "#383848", "#181824"), ramp("#f4faff", "#c4dcf0", "#8ab0d0", "#46688a"),
                  ramp("#244a50", "#1a3840", "#10262e", "#08141a"), ramp("#4a8088", "#32606c", "#204450", "#102430")),
    "ashlands": (ramp("#5c4c4c", "#382c30", "#201820", "#0c080c"), ramp("#ffc060", "#e8782c", "#a83c1c", "#501408"),
                 ramp("#4a2c2c", "#341e22", "#221218", "#10080c"), ramp("#8a4a38", "#643028", "#42201e", "#220e10")),
    "castle": (ramp("#847a74", "#585054", "#383038", "#181418"), ramp("#d4d8a8", "#98a47c", "#5c6e58", "#2a3830"),
               ramp("#2c4038", "#20322e", "#142220", "#0a1412"), ramp("#587860", "#3c5c4c", "#284236", "#142620")),
    "underground": (ramp("#6a6678", "#44425a", "#2a2a40", "#10101c"), ramp("#a8f4ec", "#5cc4c0", "#2c8490", "#124050"),
                    ramp("#1c3c58", "#142c46", "#0c1c30", "#060e1c"), ramp("#3a8aa8", "#2a6a88", "#1c4a66", "#0e2840")),
    "portals": (ramp("#6c5688", "#443468", "#2a1e48", "#100a24"), ramp("#a8fcff", "#5cc8f0", "#3480cc", "#1a3a84"),
                ramp("#4a2c78", "#361e5c", "#241442", "#120a24"), ramp("#a05cc8", "#7a3ca4", "#542878", "#2c1444")),
    "ocean": (ramp("#a89c88", "#7a6e62", "#4e4448", "#241c24"), ramp("#c8fff0", "#78d4c8", "#3c9aa0", "#18505e"),
              ramp("#1c5058", "#143c48", "#0c2834", "#06141e"), ramp("#48a49c", "#32807e", "#205c60", "#103840")),
    "sky": (ramp("#c4b8c0", "#928490", "#625468", "#322838"), ramp("#fffce0", "#f4dc90", "#d4a85c", "#8a5c34"),
            ramp("#6c88b8", "#506c9c", "#38507c", "#1e3050"), ramp("#a4c4e0", "#78a0c8", "#547ca8", "#345480")),
}


def make_tree():
    for name, (bark, moss, far, near) in THEMES.items():
        global BARK, MOSS, LEAF_FAR, LEAF_NEAR
        BARK, MOSS, LEAF_FAR, LEAF_NEAR = dim(bark, 0.85), dim(moss, 0.6), dim(far, 0.85), dim(near, 0.68)
        draw_tree(os.path.join(ART, "props", "great_oak.png" if name == "jungle" else "great_oak_%s.png" % name))


def draw_tree(out_path):
    cv = canvas(208, 234)
    far = [(100, 6, 34), (60, 14, 28), (140, 12, 30), (30, 40, 26), (172, 38, 28), (20, 84, 24), (186, 90, 22), (44, 62, 22), (156, 64, 22),
           (14, 130, 22), (188, 128, 18), (30, 160, 20), (176, 164, 20), (16, 196, 16), (190, 200, 14), (70, 92, 14), (120, 98, 16),
           (56, 150, 14), (130, 140, 14), (62, 214, 12), (122, 206, 14)]
    for i, (x, y, r) in enumerate(far):
        cluster(cv, x, y, r, i * 31 + 5, LEAF_FAR)
    near = [(30, 54, 10), (170, 56, 10), (184, 106, 9), (58, 22, 12), (146, 24, 12), (178, 144, 9)]
    for i, (x, y, r) in enumerate(near):
        cluster(cv, x, y, r, i * 17 + 3, LEAF_NEAR, squash=0.75)
    # the trunk: one shaded shape, flaring into roots at the foot
    path = [(FOOT + 6 * math.sin(y / 31.0) + 2 * math.sin(y / 11.0), y) for y in range(GROUND + 4, 4, -10)]
    radii = [13.0 + 22.0 * math.exp(-(GROUND - p[1]) / 20.0) + 2.5 * math.sin(p[1] / 17.0) + 2.0 * (1 - (GROUND - p[1]) / 230.0) for p in path]
    cv.paint(limb(path, radii), BARK, hi=0.35, lo=-0.2)
    for sgn in (-1, 1):  # roots
        for reach, rise in ((40, 12), (28, 7), (52, 5)):
            pts = curve((FOOT + sgn * 10, GROUND - rise), (FOOT + sgn * reach * 0.6, GROUND - 2), (FOOT + sgn * reach, GROUND + 3))
            cv.paint(limb(pts, [rise * 0.7 + 2, rise * 0.45 + 1.5, 2.0]), BARK, hi=0.35, lo=-0.2)
    rng = random.Random(4)
    for _ in range(46):  # bark furrows: thin dark runs down the trunk
        y = rng.randint(14, GROUND - 24)
        c = FOOT + 6 * math.sin(y / 31.0)
        x = c + rng.uniform(-11, 11)
        m, _ = cv.capsule((x, y), (x + rng.uniform(-1, 1), y + rng.randint(5, 14)), 0.55)
        cv.px[m & (cv.px[..., 3] > 0), :3] = BARK[2]
    for ky, kr in ((170, 5.0), (60, 4.0), (126, 3.4)):  # knot holes in the trunk, dark and deep
        kx = FOOT + 6 * math.sin(ky / 31.0) + (3 if ky == 60 else -2)
        cv.paint(cv.ellipse((kx, ky), kr * 0.8, kr * 1.3), ramp("#241830", "#120a1c", "#0a0612", "#06030a"), hi=0.9, lo=0.5)
    for h, left, right in LEDGES:
        top = GROUND - h
        if right <= 4:
            root, tip = right + 14, left
        elif left >= -4:
            root, tip = left - 14, right
        else:
            root, tip = left, right
        a, b = (FOOT + root, top + 8), (FOOT + tip, top + 7)
        mid = ((a[0] + b[0]) / 2, top + 7)
        cv.paint(limb([a, mid, b], [8.0 if root != left or right <= 4 or left >= -4 else 6.0, 6.5, 4.4]), BARK, hi=0.3, lo=-0.25)
        brace = [(FOOT + root, top + 22), (FOOT + root * 0.6 + tip * 0.0, top + 14), (a[0] + (tip - root) * 0.25, top + 9)]
        cv.paint(limb(brace, [4.0, 3.2, 2.4]), BARK, hi=0.3, lo=-0.25)
        # the standing surface: a strip of moss along the top, lit, ragged below
        cv.paint(cv.capsule((a[0], top + 1.3), (b[0], top + 1.3), 2.0), MOSS, hi=0.2, lo=-0.5)
        for x in range(int(min(a[0], b[0])), int(max(a[0], b[0])), 4):  # tufts of moss over the edge
            m, _ = cv.capsule((x, top + 3), (x + rng.uniform(-1, 1), top + rng.randint(5, 8)), 0.8)
            cv.px[m, :3] = MOSS[1 + rng.randint(0, 1)]
            cv.px[m, 3] = 255
        for x in range(int(min(a[0], b[0])) + 3, int(max(a[0], b[0])) - 2, 9):  # leaves hanging under
            cv.paint(cv.ellipse((x, top + 15 + rng.randint(0, 3)), 2.2, 3.4, 0.4), LEAF_NEAR)
        tipx = b[0]
        cluster(cv, tipx, top - 20, 10, h, LEAF_NEAR, squash=0.6, lobes=6)  # leaves above the tip, clear of the surface
        sg = 1 if tip > root else -1
        for j in range(3):  # dead twigs jutting from the bough, bare and crooked
            tx = tipx - sg * (4 + j * 11)
            pts = curve((tx, top + 5), (tx + sg * 3, top - 5 - j * 3), (tx + sg * (6 + j * 2), top - 14 - j * 5), 6)
            cv.paint(limb(pts, [1.6, 1.1, 0.6, 0.5, 0.5, 0.4, 0.4]), BARK, hi=0.3, lo=-0.2)
        for j in range(5):  # long strands of grey moss hanging from the bough
            mx = min(a[0], b[0]) + 6 + j * (abs(b[0] - a[0]) - 10) / 4.0
            ln = rng.randint(12, 26)
            cv.paint(limb([(mx, top + 11), (mx + rng.uniform(-1.5, 1.5), top + 11 + ln * 0.5), (mx + rng.uniform(-2, 2), top + 11 + ln)], [1.5, 1.2, 0.5]), LEAF_NEAR, hi=0.3, lo=-0.2)
    cluster(cv, FOOT, 6, 26, 77, LEAF_NEAR, squash=0.6)
    cv.save(out_path)


# ------------------------------------------------------------------- the vines
def vine_strands(cv, w, h, periods, seed):
    rng = random.Random(seed)
    cx, amp = (w - 1) / 2, w * 0.2
    for strand in (0, 1):  # the back strand first, then the front over it
        for s in (1, 0) if strand == 0 else (0, 1):
            pass
    for back in (True, False):
        for strand in (0, 1):
            pts = []
            for y in range(-2, h + 3, 2):
                ph = 2 * math.pi * periods * y / h + strand * math.pi
                if (math.cos(ph) > 0) != back:
                    pts.append((cx + amp * math.sin(ph), y))
                else:
                    if len(pts) >= 2:
                        cv.paint(limb(pts, [2.2 if back is False else 1.6] * len(pts)), VINE if not back else STALK, hi=0.3, lo=-0.2)
                    pts = []
            if len(pts) >= 2:
                cv.paint(limb(pts, [2.2 if back is False else 1.6] * len(pts)), VINE if not back else STALK, hi=0.3, lo=-0.2)
    for p in range(periods):
        for half in (0, 1):
            y = (p + 0.25 + 0.5 * half) * h / periods
            side = 1 if half == 0 else -1
            c = (cx + side * 6.5, y + 1.5)
            cv.paint(cv.ellipse(c, 5.2, 2.4, 0.5 * side), VINE, hi=0.3, lo=-0.2)
            m, _ = cv.capsule((cx + side * 1.5, y), (cx + side * 11, y + 3), 0.4)
            cv.px[m & (cv.px[..., 3] > 0), :3] = STALK[2]


def make_vines():
    cv = canvas(21, 110)
    vine_strands(cv, 21, 110, 2, 3)
    cv.save(os.path.join(ART, "props", "jungle_vine.png"))
    cv = canvas(21, 55)
    vine_strands(cv, 21, 55, 1, 5)
    cv.px = np.ascontiguousarray(np.rot90(cv.px, -1)) if False else cv.px
    cv.selout()
    im = Image.fromarray(cv.px, "RGBA").rotate(90, expand=True)  # the game turns it a quarter round clockwise
    im.save(os.path.join(ART, "props", "dusk_vine.png"))


# ------------------------------------------------------------------- the piranha
def make_piranha():
    for k in range(4):
        cv = canvas(32, 22)
        sway = (0, 1.4, 0, -1.4)[k]
        body = limb([(6, 11), (14, 10.6), (23, 11)], [3.8, 5.6, 3.4])
        cv.paint(body, FISH_TOP, hi=0.25, lo=-0.1)
        belly = limb([(7, 13.4), (14, 14.4), (22, 13)], [2.0, 3.0, 2.0])
        cv.paint((belly[0] & body[0], belly[1]), FISH_BELLY, hi=0.6, lo=-0.4)
        cv.paint(cv.poly([(22, 11), (30, 5.6 + sway), (28.6, 11), (30, 16.4 - sway)]), FIN, hi=0.3, lo=-0.1)  # the tail
        cv.paint(cv.poly([(11, 6.4), (16, 3.2), (19, 7.4)]), FIN, hi=0.3, lo=-0.1)  # the back fin
        cv.paint(cv.poly([(12, 15.6), (15, 19.4 + sway * 0.4), (18, 15.8)]), FIN, hi=0.3, lo=-0.1)
        cv.paint(cv.ellipse((8.2, 9.2), 2.1, 2.1), EYE, hi=0.3, lo=-0.1)
        cv.dot(7.4, 9.2, (20, 10, 14))
        for i in range(4):  # a row of teeth
            cv.dot(3.2 + i * 1.5, 13.4, BONE[0])
            cv.dot(3.6 + i * 1.5, 12.2, BONE[1])
        cv.save(os.path.join(ART, "mobs", "piranha_small", "frame_%d.png" % k))


# ------------------------------------------------------------------- the flytrap
def speckle(cv, mask, rmp, seed, every=6):
    """Pixel texture, so a surface is not a smooth gradient: a hashed scatter of the light and dark tones."""
    h = ((rig.xx * 73856093) ^ (rig.yy * 19349663) ^ seed) % every
    solid = mask & (cv.px[..., 3] > 0)
    cv.px[solid & (h == 0), :3] = rmp[0]
    cv.px[solid & (h == 1), :3] = rmp[2]


def make_flytrap():
    """Six 64 px frames side by side: three waiting (the jaws wide, the head swaying), three lunging (closing). The art faces left.
    Hard-edged and textured: veined red insides, speckled green skin, bright rims and crisp teeth."""
    sheet = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
    opens = [62, 70, 58, 34, 10, 2, 84, 96]  # the last two: spitting, the jaws thrown wide
    sways = [0, 2, -1, -3, -2, 0, 3, 5]
    for k in range(8):
        cv = canvas(64, 64)
        head = (36 + sways[k], 31)
        cv.paint(cv.ellipse((32, 56), 15, 3.4), SOIL, hi=0.5, lo=-0.1)
        for sgn in (-1, 1):  # two ragged leaves on the ground
            m = limb([(32, 54), (32 + sgn * 9, 51), (32 + sgn * 17, 53)], [2.6, 3.0, 0.8])
            cv.paint(m, PLANT, hi=0.25, lo=-0.3)
            speckle(cv, m[0], PLANT, 3 + sgn)
        stem = limb(curve((32, 55), (40, 46), head, 10), [3.2, 2.6, 2.4])
        cv.paint(stem, PLANT, hi=0.25, lo=-0.3)
        speckle(cv, stem[0], PLANT, 9)
        o = math.radians(opens[k]) / 2
        hinge = (head[0] + 5, head[1])
        for sgn in (-1, 1):  # -1 the upper jaw, +1 the lower
            d = (-math.cos(o), sgn * math.sin(o))
            tip = (hinge[0] + d[0] * 26, hinge[1] + d[1] * 26)
            mid = (hinge[0] + d[0] * 13, hinge[1] + d[1] * 13 + sgn * 3.0)
            lobe = limb([hinge, mid, tip], [7.0, 8.4, 2.4])
            cv.paint(lobe, PLANT, hi=0.25, lo=-0.3)
            speckle(cv, lobe[0], PLANT, 17 + sgn, 5)
            inner = limb([(hinge[0] - 1, hinge[1] - sgn * 1.2), (mid[0], mid[1] - sgn * 2.4), (tip[0] + 1.5, tip[1] - sgn * 0.8)], [4.4, 5.2, 1.2])
            fl = inner[0] & lobe[0]
            cv.paint((fl, inner[1]), FLESH, hi=0.3, lo=-0.25)
            for j in range(-2, 3):  # veins running along the red inside
                a_ = (hinge[0] + j * 0.4, hinge[1] - sgn * (1.2 + j * 0.9))
                b_ = (tip[0] + 1.0, tip[1] - sgn * (0.8 + j * 0.2))
                m, _ = cv.capsule(a_, b_, 0.4)
                cv.px[m & fl, :3] = FLESH[3 if j % 2 else 2]
            rim = fl & ~np.roll(fl, -sgn * 1, 0)
            cv.px[rim, :3] = FLESH[0]  # a bright wet rim where the red meets the green
            for i in range(6):  # long pointed teeth, two pixels wide at the root
                t = 0.18 + i * 0.14 + (0.07 if sgn > 0 else 0.0)
                bx_, by_ = hinge[0] + (tip[0] - hinge[0]) * t, hinge[1] + (tip[1] - hinge[1]) * t - sgn * 4.4 * (1 - t) - sgn * 0.6
                cv.paint(cv.poly([(bx_ - 1.5, by_), (bx_ + 1.3, by_), (bx_ - 0.1, by_ + sgn * 4.6)]), BONE, hi=0.15, lo=-0.1)
            for i in range(4):  # thorns on the outside of the lobe
                t = 0.3 + i * 0.18
                bx_, by_ = hinge[0] + (mid[0] - hinge[0]) * t * 1.6, hinge[1] + (mid[1] - hinge[1]) * t * 1.6 + sgn * 6.6 * (1 - 0.4 * t)
                cv.paint(cv.poly([(bx_ - 1.4, by_), (bx_ + 1.0, by_), (bx_ - 0.4, by_ + sgn * 3.2)]), BONE, hi=0.5, lo=0.0)
        if k >= 6:  # goo flung out of the mouth: drops of slime in an arc, a string between the jaws
            for j in range(6 if k == 6 else 9):
                gx, gy = head[0] - 14 - j * (3.2 if k == 6 else 3.8), head[1] - 6 + j * j * 0.5 + (0 if k == 6 else -3)
                cv.paint(cv.ellipse((gx, gy), 1.6, 1.3), ramp("#d8f89c", "#9ad060", "#5a9a3c", "#2a5a20"), hi=0.3, lo=-0.1)
            cv.paint(cv.capsule((head[0] - 5, head[1] - 4), (head[0] - 5, head[1] + 4), 0.6), ramp("#d8f89c", "#9ad060", "#5a9a3c", "#2a5a20"), inner_outline=False)
        tmp = os.path.join(os.environ.get("TEMP", "."), "_ft%d.png" % k)
        cv.save(tmp)
        sheet.alpha_composite(Image.open(tmp), (k * 64, 0))
    sheet.save(os.path.join(ART, "props", "flytrap.png"))


# ------------------------------------------------------------------- the bramble
def make_bramble():
    for n in range(3):
        rng = random.Random(11 + n * 5)
        w, h = 44, 38
        cv = canvas(w, h)
        ground = h - 3
        cv.paint(cv.ellipse((w / 2, ground + 1), w / 2 - 2, 3.0), SOIL, hi=0.5, lo=0.0)
        for c in range(6):  # thick canes arching up and over
            x0 = 5 + c * (w - 10) / 5.0 + rng.uniform(-1.5, 1.5)
            peak = ground - rng.uniform(16, h - 8)
            d = 1 if c % 2 else -1
            pts = curve((x0, ground + 1), (x0 + d * rng.uniform(-2, 5), peak - 4), (x0 + d * rng.uniform(7, 13), peak + rng.uniform(3, 9)), 20)
            cv.paint(limb(pts, [2.4 - 0.9 * i / 20 for i in range(21)]), CANE, hi=0.3, lo=-0.2)
            for i in range(3, 20, 4):  # thorns: pale spikes, alternating sides
                x, y = pts[i]
                nx, ny = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
                L = math.hypot(nx, ny) or 1.0
                px_, py_ = -ny / L, nx / L
                s = 1 if (i // 4) % 2 else -1
                cv.paint(cv.poly([(x + px_ * s * 1.2, y + py_ * s * 1.2), (x - nx / L * 1.4 + px_ * s * 1.2, y - ny / L * 1.4 + py_ * s * 1.2),
                                  (x + px_ * s * 5.2 + nx / L * 1.6, y + py_ * s * 5.2 + ny / L * 1.6)]), BONE, hi=0.3, lo=-0.1)
            if rng.random() < 0.8:
                x, y = pts[rng.randint(8, 16)]
                cv.paint(cv.ellipse((x, y + 2.4), 1.7, 1.9), BERRY, hi=0.3, lo=-0.1)
            else:
                x, y = pts[rng.randint(6, 14)]
                cv.paint(cv.ellipse((x + 3 * d, y - 1), 3.6, 1.5, -0.4 * d), PLANT, hi=0.3, lo=-0.2)
        cv.save(os.path.join(ART, "props", "bramble_%d.png" % (n + 1)))


# ------------------------------------------------------------------- the marble stairs under the spellbook
MARBLE = ramp("#faf8f4", "#dcdae0", "#aaa8bc", "#6c6a84")
VEIN = ramp("#8a8ca8", "#6c6e8e", "#50526e", "#34364e")
GILT = ramp("#fff0a0", "#f0c35a", "#c08a30", "#7a4a18")


def make_podium():
    """352 x 96: a landing 96 wide in the middle at the full height, and seven low steps down each side (12 px high, 16 deep), the way Podium.gd lays
    them. White marble with grey-blue veins, mortar joints, a lit tread with a line of gilt along its front, and a shadowed foot."""
    w, h = 352, 96
    cv = canvas(w, h)
    rng = np.random.RandomState(5)
    yy, xx = rig.yy, rig.xx
    top = np.full(w, h + 1)
    for x in range(w):
        d = abs(x - 176) - 48
        if d < 0:
            top[x] = 0
        else:
            n = d // 16 + 1
            if n <= 7:
                top[x] = 12 * n
    solid = yy >= top[xx]
    depth = yy - top[xx]
    tone = np.full((h, w), 1)
    tone[depth < 2] = 0
    tone[depth >= 22] = 2
    # the step's outer face, a darker band a couple of pixels wide at the end of each tread
    edge_x = np.zeros(w, bool)
    for x in range(1, w):
        edge_x[x] = top[x] != top[x - 1] and top[x] <= h
    for x in range(w - 1):
        if top[x] != top[x + 1] and top[x] <= h:
            edge_x[max(x - 1, 0):x + 1] = True
    tone[(depth >= 2) & edge_x[xx]] = 2
    joint = np.zeros((h, w), bool)
    for course in range(0, 5):  # courses of blocks every 24 px, offset on alternate courses
        yj = h - 24 * course
        joint |= (yy == yj - 1) & solid & (depth > 3)
        off = 24 if course % 2 else 0
        joint |= ((xx + off) % 48 == 0) & (yy >= yj - 24) & (yy < yj) & solid & (depth > 3)
    vein = np.zeros((h, w), bool)
    for _ in range(22):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.uniform(-0.5, 0.5) + (math.pi / 3 if rng.rand() < 0.5 else -math.pi / 3)
        for t in np.arange(0, rng.uniform(24, 60), 0.5):
            x, y = x0 + math.cos(ang) * t + math.sin(t * 0.35) * 2.0, y0 + math.sin(ang) * t + math.sin(t * 0.21) * 1.5
            if 0 <= int(x) < w and 0 <= int(y) < h:
                vein[int(y), int(x)] = True
    vein &= solid & (depth > 3) & ~joint
    speck = ((xx * 73856093 ^ yy * 19349663) % 29 == 0) & solid
    px = cv.px
    for y in range(h):
        for x in range(w):
            if solid[y, x]:
                px[y, x, :3] = MARBLE[int(tone[y, x])]
                px[y, x, 3] = 255
    px[joint & solid, :3] = MARBLE[3]
    px[vein, :3] = VEIN[1]
    px[vein & (tone == 2), :3] = VEIN[2]
    px[speck & (tone < 2) & ~joint, :3] = MARBLE[2]
    for x in range(w):  # gilt along the front of every tread
        if top[x] <= h and x % 16 not in (0, 15) or (top[x] == 0 and 128 < x < 224):
            y = top[x] + 2
            if y < h:
                px[y, x, :3] = GILT[1]
    px[(yy >= h - 2) & solid, :3] = MARBLE[3]
    os.makedirs(os.path.join(ART, "tiles"), exist_ok=True)
    Image.fromarray(px, "RGBA").save(os.path.join(ART, "tiles", "podium_marble.png"))


# ------------------------------------------------------------------- the lectern, the book, and the smaller props
NIGHT = ramp("#7c7894", "#524e6a", "#302c48", "#14101e")  # dark veined marble
LEATHER = ramp("#9a4450", "#6a2634", "#421422", "#1e0812")
WOOD = ramp("#94684a", "#62422e", "#3e281e", "#1c1010")
IRONP = ramp("#a4a4b8", "#6c6c84", "#44445a", "#20202e")
SAND = ramp("#8a6a3c", "#6a4e2c", "#4a361e", "#241a10")
ROCK = dim(ramp("#c4c0c8", "#908c98", "#605c6c", "#34303c"), 0.85)
PAD = dim(ramp("#7cc064", "#4c9450", "#2c6444", "#123424"), 0.68)
HULL = ramp("#7a5c44", "#523a30", "#32221e", "#150c0e")
SEA_SAND = ramp("#a89468", "#7c6c4c", "#524632", "#2a2218")


def dithered_veins(cv, mask, rmp, seed, count=8, length=(10, 26)):
    rng = np.random.RandomState(seed)
    h, w = mask.shape
    for _ in range(count):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.uniform(0, math.pi)
        for t in np.arange(0, rng.uniform(*length), 0.5):
            x, y = x0 + math.cos(ang) * t + math.sin(t * 0.4) * 1.4, y0 + math.sin(ang) * t + math.sin(t * 0.3)
            if 0 <= int(x) < w and 0 <= int(y) < h and mask[int(y), int(x)]:
                cv.px[int(y), int(x), :3] = rmp[2]


def line(cv, a, b, col, r=0.6):
    m, _ = cv.capsule(a, b, r)
    cv.px[m & (cv.px[..., 3] > 0), :3] = col


def make_lectern():
    """The stand: 68 x 63, a tomb of dark veined marble with a heavy cap, a panelled face (the plaques are laid over it) and a plinth, gilt along the cap."""
    cv = canvas(68, 63)
    cv.paint(cv.poly([(5, 14), (63, 14), (63, 58), (5, 58)]), NIGHT, hi=0.95, lo=-0.95)
    cv.paint(cv.poly([(8, 18), (60, 18), (60, 54), (8, 54)]), NIGHT, hi=0.95, lo=-0.3, bias=-0.1)
    cv.paint(cv.poly([(0, 4), (68, 4), (68, 14), (0, 14)]), NIGHT, hi=0.35, lo=-0.1)
    cv.paint(cv.poly([(0, 0), (68, 0), (66, 4), (2, 4)]), NIGHT, hi=-1.0, lo=-2.0)
    cv.paint(cv.poly([(1, 56), (67, 56), (67, 63), (1, 63)]), NIGHT, hi=0.3, lo=-0.1)
    line(cv, (2, 13.5), (66, 13.5), GILT[1])
    for cx_, cy_ in ((11, 21), (57, 21), (11, 51), (57, 51)):
        cv.paint(cv.ellipse((cx_, cy_), 1.3, 1.3), GILT, hi=0.3, lo=-0.1)
    mask = cv.px[..., 3] > 0
    dithered_veins(cv, mask, NIGHT, 3, 7)
    h = ((rig.xx * 73856093) ^ (rig.yy * 19349663)) % 19
    cv.px[mask & (h == 0), :3] = NIGHT[0]
    cv.save(os.path.join(ART, "props", "lectern_stand.png"))


def make_plaque():
    """47 x 22: a plate of gilt metal with a raised rim, a flat middle for the lettering and a rivet at each corner."""
    cv = canvas(47, 22)
    cv.paint(cv.poly([(1, 0), (46, 0), (47, 1), (47, 21), (46, 22), (1, 22), (0, 21), (0, 1)]), GILT, hi=0.5, lo=-0.3)
    cv.paint(cv.poly([(4, 3), (43, 3), (43, 19), (4, 19)]), ramp("#f4d27c", "#dba84c", "#b0802c", "#6e4a18"), hi=0.9, lo=0.6)
    for x, y in ((2, 2), (44, 2), (2, 19), (44, 19)):
        cv.px[y, x, :3] = GILT[3]
        cv.px[y - 1, x - 1, :3] = GILT[0]
    cv.save(os.path.join(ART, "props", "lectern_plaque.png"))


def make_book():
    """44 x 68: the whole book closed, standing: black-red leather, gilt corner caps and border, a gilt seal on the cover, a strap and lock, the page block
    showing on the right edge. Three empty rows under it (the book rests on the stand)."""
    cv = canvas(44, 68)
    cv.paint(cv.poly([(3, 2), (40, 2), (40, 63), (3, 63)]), LEATHER, hi=0.35, lo=-0.25)
    cv.paint(cv.poly([(40, 3), (43, 4), (43, 62), (40, 63)]), BONE, hi=0.2, lo=-0.1)
    for y in range(5, 62, 3):
        cv.px[y, 41:43, :3] = BONE[2]
    cv.paint(cv.poly([(0, 2), (4, 1), (4, 64), (0, 63)]), LEATHER, hi=0.6, lo=-0.1, bias=-0.3)
    for y in (10, 30, 50):
        cv.px[y:y + 2, 0:5, :3] = GILT[1]
    for x, y, fx, fy in ((3, 2, 1, 1), (40, 2, -1, 1), (3, 63, 1, -1), (40, 63, -1, -1)):
        cv.paint(cv.poly([(x, y), (x + 8 * fx, y), (x, y + 8 * fy)]), GILT, hi=0.4, lo=-0.2)
    for a, b in (((8, 7), (36, 7)), ((8, 58), (36, 58)), ((8, 7), (8, 58)), ((36, 7), (36, 58))):
        line(cv, a, b, GILT[1])
    cv.paint(cv.ellipse((22, 28), 12, 12), GILT, hi=0.5, lo=-0.1)  # a seal: a gilt ring around an eight-pointed star with a small gem
    cv.paint(cv.ellipse((22, 28), 9.6, 9.6), LEATHER, hi=0.2, lo=-0.4)
    star = [(22 + math.cos(k * math.pi / 8 - math.pi / 2) * (9.0 if k % 2 == 0 else 3.8), 28 + math.sin(k * math.pi / 8 - math.pi / 2) * (9.0 if k % 2 == 0 else 3.8)) for k in range(16)]
    cv.paint(cv.poly(star), GILT, hi=0.4, lo=-0.1)
    cv.paint(cv.ellipse((22, 28), 2.4, 2.4), ramp("#c8a0ff", "#8a5ad0", "#5a2e98", "#2a1060"), hi=0.4, lo=-0.1)
    cv.paint(cv.poly([(3, 40), (40, 40), (40, 46), (3, 46)]), LEATHER, hi=0.5, lo=0.0, bias=-0.35)
    cv.paint(cv.ellipse((22, 43), 4.2, 4.6), IRONP, hi=0.4, lo=-0.1)
    cv.px[43, 21:23, :3] = IRONP[3]
    cv.save(os.path.join(ART, "props", "spellbook.png"))


def make_lily():
    """52 x 14, seen from the side lying on the water: a broad leaf with a notch, a lit top, veins and a dark underside, and a small bud."""
    cv = canvas(52, 14)
    cv.paint(cv.ellipse((26, 8), 25, 4.2), PAD, hi=0.35, lo=-0.3)
    cv.paint(cv.ellipse((26, 6.6), 22, 2.6), dim(ramp("#9ed880", "#6cb464", "#3e8450", "#1a4a30"), 0.7), hi=0.5, lo=-0.1)
    for x in (10, 18, 34, 42):
        line(cv, (26, 7), (x, 6.0), PAD[2], 0.4)
    cv.px[3:9, 30:33, 3] = 0
    cv.paint(cv.ellipse((17, 3.4), 2.2, 2.6), ramp("#d8b4c4", "#a8607c", "#742c48", "#3a1424"), hi=0.4, lo=-0.1)
    cv.save(os.path.join(ART, "props", "lily_pad.png"))


def tiled(w, h, fn):
    """A picture that wraps left to right: every function of x in it has a period dividing w."""
    px = np.zeros((h, w, 4), np.uint8)
    fn(px, np.mgrid[0:h, 0:w])
    return px


def make_plank():
    """16 x 13, tiles sideways: a weathered board, lit along its top, dark along its underside, with grain and a nail at each end."""
    def draw(px, g):
        yy, xx = g
        body = (yy >= 1) & (yy <= 11)
        grain = np.sin(xx * 2 * math.pi / 16 * 2 + yy * 0.9) + 0.6 * np.sin(xx * 2 * math.pi / 16 * 3 - yy * 0.5)
        tone = np.where(yy <= 2, 0, np.where(yy >= 10, 3, np.where(yy >= 8, 2, 1)))
        tone = np.where((grain > 1.2) & (tone == 1), 2, tone)
        tone = np.where((grain < -1.3) & (tone == 1), 0, tone)
        for ch in range(3):
            px[..., ch] = np.where(body, np.array([c[ch] for c in WOOD])[tone], 0)
        px[..., 3] = np.where(body, 255, 0)
        under = (yy == 12) & (xx % 5 < 3)
        px[under, :3] = WOOD[3]
        px[under, 3] = 255
        for x in (1, 14):
            px[5, x, :3] = IRONP[0]
            px[6, x, :3] = IRONP[3]
    Image.fromarray(tiled(16, 13, draw), "RGBA").save(os.path.join(ART, "props", "plank.png"))


def make_quicksand():
    """64 x 32, tiles sideways (it scrolls): a rippled surface of dark wet sand, grainy, with a few bubbles."""
    def draw(px, g):
        yy, xx = g
        rip = np.sin(xx * 2 * math.pi / 64 * 3 + yy * 0.4) + 0.7 * np.sin(xx * 2 * math.pi / 64 * 5 - yy * 0.2)
        depth = yy / 31.0
        tone = np.where(depth < 0.08, 0, np.where(rip > 0.9, 1, np.where(rip < -0.8, 3, 2)))
        tone = np.where(depth > 0.6, np.minimum(tone + 1, 3), tone)
        h = ((xx * 73856093) ^ (yy * 19349663)) % 11
        tone = np.where(h == 0, np.maximum(tone - 1, 0), tone)
        for ch in range(3):
            px[..., ch] = np.array([c[ch] for c in SAND])[tone]
        px[..., 3] = 255
        for bx, by in ((10, 6), (31, 12), (50, 5), (22, 20)):
            px[by, bx, :3] = (210, 190, 140)
            px[by, bx + 1, :3] = SAND[3]
    Image.fromarray(tiled(64, 32, draw), "RGBA").save(os.path.join(ART, "props", "quicksand.png"))


def make_spikes():
    """Three rock spikes, grey so the game can tint them to the ground rock: faceted, a lit left face and a shaded right, flecked."""
    for n, (w, h, peaks) in enumerate(((16, 16, [(8, 0)]), (14, 12, [(5, 1), (10, 4)]), (16, 16, [(5, 3), (11, 0)])), start=1):
        cv = canvas(w, h)
        for px_, py_ in peaks:
            cv.paint(cv.poly([(max(px_ - 6, 0), h), (px_, py_), (min(px_ + 6, w - 1), h)]), ROCK, hi=0.2, lo=-0.1)
            cv.paint(cv.poly([(px_, py_), (min(px_ + 6, w - 1), h), (px_ + 1, h)]), ROCK, hi=5.0, lo=4.0)
        m = cv.px[..., 3] > 0
        for y in range(h):
            for x in range(w):
                if m[y, x] and (x * 5 + y * 3) % 9 == 0:
                    cv.px[y, x, :3] = ROCK[3]
        cv.save(os.path.join(ART, "props", "rock_spike_%d.png" % n))


def make_door():
    """32 x 48: a crypt door: a pointed arch of stone around dark planks, iron straps with studs, a ring handle."""
    cv = canvas(32, 48)
    full = cv.poly([(0, 0), (32, 0), (32, 48), (0, 48)])[1]
    arch = np.zeros((48, 32), bool)
    inner = np.zeros((48, 32), bool)
    for y in range(48):
        for x in range(32):
            arch[y, x] = y > 12 or ((x - 16) / 16.0) ** 2 + ((y - 12) / 13.0) ** 2 <= 1.0
            inner[y, x] = 3 <= y and 4 <= x < 28 and (y > 14 or ((x - 16) / 12.0) ** 2 + ((y - 14) / 11.0) ** 2 <= 1.0)
    cv.paint((arch, full), NIGHT, hi=0.3, lo=-0.2)
    cv.paint((inner, full), WOOD, hi=0.25, lo=-0.3)
    for x in (10, 16, 22):
        cv.px[8:48, x, :3] = WOOD[3]
    for y in (14, 26, 38):
        cv.paint(cv.poly([(4, y), (28, y), (28, y + 3), (4, y + 3)]), IRONP, hi=0.4, lo=-0.1)
        for x in (7, 13, 19, 25):
            cv.px[y + 1, x, :3] = IRONP[0]
    cv.paint(cv.ellipse((21, 30), 3.0, 3.0), IRONP, hi=0.4, lo=-0.1)
    cv.paint(cv.ellipse((21, 30), 1.4, 1.4), WOOD, hi=2, lo=2)
    cv.save(os.path.join(ART, "props", "door.png"))


def make_shipwreck(variant=0):
    """576 x 253: a galleon broken in two on a bank of sand, drawn around the silhouette Wreck.gd collision follows: the bow hull sloping down from its
    left end, the stern deck and high back on the right, the hold open between. Variant 0 keeps its mast and sail; variant 1 has lost them and
    lies with a cracked stern window and a spilled cargo. Every plank its own tone, gun ports, rails with balusters, curved ribs, barnacles, weed."""
    w, h = 576, 253
    cv = canvas(w, h)
    rng = np.random.RandomState(9 + variant * 17)
    yy, xx = rig.yy, rig.xx
    flat = dict(hi=0.97, lo=-0.97)
    wood = ramp("#7a6252", "#52403a", "#32262c", "#150e14")
    pale = ramp("#a89478", "#7c6a58", "#54443c", "#241a1c")
    gloom = ramp("#2c2230", "#1e1624", "#120e18", "#08060c")
    weed = dim(ramp("#8cc47a", "#4c9456", "#2c6048", "#143426"), 0.65)
    rope = ramp("#b8a888", "#8a7c64", "#5a5040", "#2a241c")
    # the bank of sand, rippled
    cv.paint(cv.poly([(0, 253), (0, 220), (100, 204), (288, 196), (470, 202), (576, 218), (576, 253)]), SEA_SAND, **flat)
    for y in range(200, 253, 6):
        for x in range(0, w, 3):
            if cv.px[y, x, 3] and (x // 3 + y) % 4 == 0:
                cv.px[y, x:x + 3, :3] = SEA_SAND[0]
    # the two hulls, with a curved keel under each that sinks into the sand
    bow = [(12, 52), (32, 54), (80, 72), (120, 82), (170, 95), (215, 110), (248, 136), (262, 152), (268, 200), (12, 200)]
    stern = [(452, 98), (515, 80), (545, 72), (550, 98), (550, 206), (336, 206), (336, 128)]
    cv.paint(cv.poly(bow), wood, **flat)
    cv.paint(cv.poly(stern), wood, **flat)
    cv.paint(cv.poly([(12, 190), (140, 214), (268, 196), (268, 204), (140, 222), (12, 204)]), wood, **flat)  # the bow's keel and planking curving under
    cv.paint(cv.poly([(336, 200), (440, 218), (550, 206), (550, 214), (440, 224), (336, 212)]), wood, **flat)
    for part in (bow, stern):
        m = cv.poly(part)[0]
        for k, y in enumerate(range(56, 212, 9)):
            tone = [0, 1, 1, 2, 1, 0, 1][(k * 3 + int(rng.randint(0, 3))) % 7]
            tone = min(tone + (1 if y > 150 else 0), 2)
            for dy in range(1, 9):
                if y + dy < h:
                    row = m[y + dy, :] & (cv.px[y + dy, :, 3] > 0)
                    cv.px[y + dy, row, :3] = wood[tone]
            seam = m[y, :] & (cv.px[y, :, 3] > 0)
            cv.px[y, seam, :3] = wood[3]
            for x in range(int(rng.randint(0, 17)), w, 31 + int(rng.randint(0, 9))):  # butt joints between planks
                if y + 1 < h and m[y + 4, x]:
                    cv.px[y + 1:y + 9, x, :3] = wood[3]
    # the hold, open between the halves: dark, with curved ribs rising out of the keel
    cv.paint(cv.poly([(336, 132), (452, 106), (452, 196), (336, 196)]), gloom, hi=5, lo=4)
    for x in range(342, 452, 16):
        pts = curve((x - 4, 204), (x - 10, 160), (x, 128 - (x - 336) * 0.2), 10)
        cv.paint(limb(pts, [2.6, 2.2, 1.8, 1.8, 1.6, 1.6, 1.6, 1.4, 1.4, 1.2, 1.2]), wood, hi=0.3, lo=-0.1)
    # ribs jutting from the broken ends, into the open
    for x0, side in ((268, 1), (336, -1)):
        for k in range(5):
            y0 = 206 - k * 10
            pts = curve((x0, y0), (x0 + side * 22, y0 - 6), (x0 + side * (26 + k * 4), y0 - 44 + k * 5), 8)
            cv.paint(limb(pts, [2.6, 2.4, 2.2, 2.0, 1.8, 1.6, 1.2, 1.0, 0.6]), wood, hi=0.3, lo=-0.1)
    # the deck of the stern, with its rail
    cv.paint(cv.capsule((336, 128), (452, 102), 2.6), pale, hi=0.3, lo=-0.1)
    for x in range(340, 452, 14):
        y = 128 - (x - 336) * 26.0 / 116
        cv.paint(cv.capsule((x, y - 1), (x, y - 9), 1.0), pale, hi=0.3, lo=-0.1)  # balusters
    cv.paint(cv.capsule((340, 119), (452, 93), 1.2), pale, hi=0.3, lo=-0.1)
    # the stern castle: a round window in a gilt ring, carved rail along the high back
    cv.paint(cv.ellipse((508, 124), 11, 11), ramp("#d8b060", "#a8802c", "#6a4a18", "#34240c"), hi=0.3, lo=-0.1)
    cv.paint(cv.ellipse((508, 124), 8, 8), gloom, hi=5, lo=4)
    if variant == 0:
        cv.paint(cv.ellipse((506, 122), 3, 2), ramp("#bcd4ec", "#7c9cc0", "#445c80", "#1c2840"), hi=0.4, lo=-0.1)
    else:
        for a_ in (0.4, 1.9, 3.4):  # a broken pane
            line(cv, (508, 124), (508 + 8 * math.cos(a_), 124 + 8 * math.sin(a_)), gloom[0], 0.5)
    for x in range(458, 548, 10):
        y = 98 - (x - 452) * 26.0 / 93 if x < 515 else 80 - (x - 515) * 8.0 / 30
        cv.paint(cv.capsule((x, y - 1), (x, y - 8), 1.0), pale, hi=0.3, lo=-0.1)
    cv.paint(cv.capsule((452, 92), (515, 74), 1.3), pale, hi=0.3, lo=-0.1)
    cv.paint(cv.capsule((515, 74), (546, 66), 1.3), pale, hi=0.3, lo=-0.1)
    cv.paint(cv.poly([(548, 100), (556, 98), (560, 206), (550, 208)]), wood, **flat)  # the rudder, hanging off the stern
    line(cv, (553, 118), (553, 196), wood[3], 0.5)
    # gun ports along the bow's side, each with a lid and a dark mouth, one cannon run out
    for x in range(54, 250, 34):
        y = 52 + int(np.interp(x, [12, 32, 80, 120, 170, 215, 248], [52, 54, 72, 82, 95, 110, 136])) - 52 + 24
        if cv.px[y, x, 3]:
            cv.paint(cv.poly([(x, y), (x + 11, y), (x + 11, y + 9), (x, y + 9)]), gloom, hi=5, lo=4)
            cv.paint(cv.poly([(x - 1, y - 3), (x + 12, y - 3), (x + 12, y)]), pale, hi=0.3, lo=-0.1)
    cx_ = 120 if variant == 0 else 154
    cy_ = 82 + 24 + (0 if variant == 0 else 13)
    cv.paint(cv.capsule((cx_ + 4, cy_ + 4), (cx_ - 8, cy_ + 7), 3.0), ramp("#6c6c80", "#44445a", "#2a2a3c", "#12121c"), hi=0.3, lo=-0.1)
    # the bow's rail with balusters, and the bowsprit
    for x in range(14, 250, 12):
        y = int(np.interp(x, [12, 32, 80, 120, 170, 215, 248], [52, 54, 72, 82, 95, 110, 136]))
        cv.paint(cv.capsule((x, y), (x, y - 7), 0.9), pale, hi=0.3, lo=-0.1)
    for x0, x1 in ((12, 80), (80, 170), (170, 248)):
        y0 = int(np.interp(x0, [12, 32, 80, 120, 170, 215, 248], [52, 54, 72, 82, 95, 110, 136]))
        y1 = int(np.interp(x1, [12, 32, 80, 120, 170, 215, 248], [52, 54, 72, 82, 95, 110, 136]))
        cv.paint(cv.capsule((x0, y0 - 7), (x1, y1 - 7), 1.0), pale, hi=0.3, lo=-0.1)
    if variant == 0:
        cv.paint(limb([(14, 52), (4, 44), (0, 36)], [2.4, 1.8, 1.3]), wood, hi=0.3, lo=-0.1)
    # the mast, snapped, and what hangs from it (variant 0); or just the splintered stump (variant 1)
    if variant == 0:
        cv.paint(cv.capsule((520, 82), (558, 20), 3.2), wood, hi=0.3, lo=-0.1)
        cv.paint(cv.poly([(556, 22), (564, 14), (561, 24), (566, 30), (558, 28)]), wood, hi=0.3, lo=-0.1)
        cv.paint(cv.capsule((536, 56), (566, 50), 1.6), wood, hi=0.3, lo=-0.1)  # a spar
        cv.paint(cv.poly([(540, 52), (566, 50), (562, 82), (534, 88), (526, 72)]), ramp("#a8a08c", "#76705c", "#4e4838", "#24201a"), hi=0.5, lo=-0.1)  # the torn sail
        for k in range(5):
            pts = curve((556, 26 + k * 6), (524 - k * 8, 54 + k * 12), (496 - k * 10, 100 + k * 6), 10)
            cv.paint(limb(pts, [0.8] * 11), rope, hi=0.5, lo=0.2)
    else:
        cv.paint(cv.poly([(508, 80), (524, 78), (522, 62), (516, 68), (512, 56), (508, 66)]), wood, hi=0.3, lo=-0.1)
    # the anchor, half buried, and a few barrels spilled on the sand
    ax = 300 if variant == 0 else 292
    cv.paint(cv.capsule((ax, 160), (ax, 198), 1.8), ramp("#8a8aa0", "#5a5a72", "#383850", "#18182a"), hi=0.3, lo=-0.1)
    cv.paint(cv.capsule((ax - 10, 168), (ax + 10, 168), 1.6), ramp("#8a8aa0", "#5a5a72", "#383850", "#18182a"), hi=0.3, lo=-0.1)
    cv.paint(limb(curve((ax - 12, 190), (ax, 206), (ax + 12, 190), 8), [1.6] * 9), ramp("#8a8aa0", "#5a5a72", "#383850", "#18182a"), hi=0.3, lo=-0.1)
    for bx, by, rot in ((232, 196, 0.0), (256, 200, 1.3), (470, 202, 0.4)) if variant == 0 else ((226, 198, 1.2), (246, 202, 0.2), (468, 204, 1.5), (492, 208, 0.9), (514, 210, 0.1)):
        cv.paint(cv.ellipse((bx, by), 9, 7, rot), wood, hi=0.3, lo=-0.1)
        cv.paint(cv.ellipse((bx, by), 9.5, 2.4, rot + 1.57), ramp("#9a9ab0", "#66667c", "#40405a", "#1e1e2e"), hi=0.3, lo=-0.1)
    # barnacles and weed hanging from every rail and plank edge
    m = cv.px[..., 3] > 0
    speck = ((xx * 73856093 ^ yy * 19349663) % 13 == 0) & m & (yy > 120)
    cv.px[speck, :3] = pale[1]
    for x in range(6, w - 6, 9):
        col = np.nonzero(cv.px[:, x, 3] > 0)[0]
        if len(col) and rng.rand() < 0.65:
            top, L = int(col.min()), rng.randint(6, 20)
            cv.paint(limb([(x, top + 3), (x + rng.uniform(-2, 2), top - L * 0.5), (x + rng.uniform(-3, 3), top - L)], [1.5, 1.1, 0.4]), weed, hi=0.3, lo=-0.1)
    for x in range(20, 560, 23):  # strands hanging down from the rails and decks
        if rng.rand() < 0.5:
            col = np.nonzero(cv.px[:, x, 3] > 0)[0]
            if len(col):
                top = int(col.min()) + 12
                L = rng.randint(10, 26)
                cv.paint(limb([(x, top), (x + rng.uniform(-3, 3), top + L * 0.5), (x + rng.uniform(-3, 3), top + L)], [1.5, 1.0, 0.4]), weed, hi=0.3, lo=-0.1)
    name = "shipwreck.png" if variant == 0 else "shipwreck_b.png"
    cv.save(os.path.join(ART, "props", name))


def make_shipwrecks():
    make_shipwreck(0)
    make_shipwreck(1)


def make_wreck_backdrops():
    """Two layers of distant wrecks for the ocean backdrop, in the way the peaks have ranges of mountains: the far one small, hazy and slow, the nearer one
    larger and clearer (art/backgrounds/ocean/wrecks_far.png and wrecks_mid.png, drawn by Backdrop at twice their size, standing on the bottom edge)."""
    water = np.array([22, 40, 70])
    ships = [Image.open(os.path.join(ART, "props", n)).convert("RGBA") for n in ("shipwreck.png", "shipwreck_b.png")]

    def far_ship(im, k, fog, alpha, flip=False):
        full = np.array(im).astype(int)
        for c in SEA_SAND:  # the bank of sand under the wreck is left out: the layers in front are the seabed
            full[(np.abs(full[..., :3] - np.array(c)).sum(-1) < 40) & (np.arange(full.shape[0])[:, None] > 180), 3] = 0
        small = full[::k, ::k].astype(float)  # every kth pixel: crisp, not smoothed
        rgb = small[..., :3] * (1 - fog) + water * fog
        rgb = rgb * 0.8
        out = np.zeros(small.shape, np.uint8)
        out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        out[..., 3] = np.where(small[..., 3] > 0, int(255 * alpha), 0)
        img = Image.fromarray(out, "RGBA")
        return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img

    far = Image.new("RGBA", (768, 192), (0, 0, 0, 0))
    far.alpha_composite(far_ship(ships[0], 3, 0.72, 0.8), (20, 192 - 84 - 6))
    far.alpha_composite(far_ship(ships[1], 3, 0.72, 0.8, True), (400, 192 - 84 - 2))
    far.save(os.path.join(ART, "backgrounds", "ocean", "wrecks_far.png"))
    mid = Image.new("RGBA", (1024, 192), (0, 0, 0, 0))
    mid.alpha_composite(far_ship(ships[1], 2, 0.5, 0.92), (70, 192 - 127 + 14))
    mid.alpha_composite(far_ship(ships[0], 2, 0.5, 0.92, True), (560, 192 - 127 + 20))
    mid.save(os.path.join(ART, "backgrounds", "ocean", "wrecks_mid.png"))


def make_clouds():
    """The six clouds: heavy, brooding masses lit from the upper left, with a flat dark underside and ragged lobes. The snow clouds are cold grey-blue, the storm clouds bruised violet-black. Sizes as before."""
    snow = ramp("#b4bed4", "#8590ac", "#566080", "#2c3450")
    storm = ramp("#6c6088", "#4a4066", "#2e2646", "#140e24")
    specs = [("big", 86, 47, 7, 5), ("small_1", 37, 30, 4, 3), ("small_2", 37, 20, 4, 2)]
    for kind, rmp in (("snow", snow), ("storm", storm)):
        for tag, w, h, n, seed in specs:
            cv = canvas(w, h)
            rng = random.Random(seed * 11 + (3 if kind == "storm" else 0))
            floor_y = h - 4 if tag != "small_1" else h - 11
            parts = [(w * 0.5, floor_y - h * 0.3, w * 0.34), (w * 0.27, floor_y - h * 0.2, w * 0.2), (w * 0.73, floor_y - h * 0.22, w * 0.21)]
            if tag == "big":
                parts += [(w * 0.4, floor_y - h * 0.45, w * 0.2), (w * 0.62, floor_y - h * 0.42, w * 0.17), (w * 0.12, floor_y - h * 0.1, w * 0.12), (w * 0.88, floor_y - h * 0.1, w * 0.12)]
            for i, (cx, cy, r) in enumerate(parts):
                cluster(cv, cx, cy, r, seed * 7 + i, rmp, squash=0.7, lobes=8)
            under = (rig.yy > floor_y)
            cv.px[under, 3] = 0  # a flat belly under the cloud
            if tag == "small_1":  # a ragged fall of snow or rain under the cloud's belly
                for x in range(int(w * 0.3), int(w * 0.72), 3):
                    cv.px[floor_y + 1:floor_y + 1 + 4 + (x * 7) % 7, x, :] = list(rmp[2]) + [200]
            cv.save(os.path.join(ART, "props", "cloud_%s_%s.png" % (kind, tag)))


def make_snail():
    """The Invincible Snail: four frames of a crawl, 24 x 16, facing right, standing on the bottom row. A dark violet shell with a pale spiral groove, a long grey body
    that stretches and gathers as it goes, two stalks with small red eyes, a wet shine along the foot, and a trail of slime behind."""
    body = ramp("#aeae98", "#7e7e6c", "#52524a", "#26261f")
    shell = ramp("#7a6a90", "#54486a", "#362c48", "#1a1228")
    groove = ramp("#e6dcc8", "#c4b8a8", "#8a7e72", "#463e3a")
    eye = ramp("#ff9a8a", "#e02c34", "#901c28", "#400c14")
    slime = ramp("#cfe0d0", "#9ab4a6", "#62806e", "#2c4036")
    for k in range(4):
        cv = canvas(24, 16)
        t = 2 * math.pi * k / 4
        reach = 1.0 * math.sin(t)  # the head reaches out and the tail is drawn up behind it
        floor = 14
        tail_x, head_x = 3 + 0.7 * math.cos(t), 21 + reach
        path = [(tail_x, floor - 0.4), (tail_x + 4, floor - 0.9), (9, floor - 1.4), (14, floor - 1.7), (head_x - 2, floor - 2.3 - 0.3 * math.sin(t)), (head_x, floor - 3.6 - 0.45 * math.sin(t))]
        radii = [0.5, 1.0, 1.4, 1.65, 1.75, 1.45]
        m, s = limb(path, radii)
        m &= rig.yy <= floor  # a flat foot
        cv.paint((m, s), body, hi=0.35, lo=-0.2)
        cv.px[floor, 2:int(head_x - 2), :3] = slime[0]  # the wet shine along the foot
        cv.px[floor, 2:int(head_x - 2), 3] = 255
        for x in range(1, 3):
            cv.px[floor + 1, x, :3] = slime[2]
            cv.px[floor + 1, x, 3] = 150
        # the shell: a round dome with a spiral groove from its middle out
        cx, cy, r = 9.5, floor - 5.8, 5.7
        sm, ss = cv.ellipse((cx, cy), r, r * 0.95)
        cv.paint((sm, ss), shell, hi=0.4, lo=-0.25)
        for a in np.arange(0.0, 4.2 * math.pi, 0.05):
            rr = 0.6 + a * 0.39
            x, y = cx + math.cos(a + 0.6) * rr, cy + math.sin(a + 0.6) * rr * 0.95
            if 0 <= int(x) < 24 and 0 <= int(y) < 16 and sm[int(y), int(x)] and rr < r - 0.5:
                lit = (x - cx) * rig.LIGHT[0] + (y - cy) * rig.LIGHT[1] < 0
                cv.px[int(y), int(x), :3] = groove[1] if lit else groove[2]
        # two eye stalks with a small red eye each, swaying
        for j, (dx, lean) in enumerate(((0, 0.0), (4, 0.6))):
            bx, by = head_x - 1.1 + dx * 0.2, floor - 4.1 - 0.2 * math.sin(t)
            tipx, tipy = bx + 1.1 + lean * 0.75 + math.sin(t + j) * 0.45, by - 3.7 + j * 0.6
            cv.paint(limb([(bx, by), ((bx + tipx) / 2, (by + tipy) / 2 - 1), (tipx, tipy)], [0.55, 0.45, 0.4]), body, hi=0.35, lo=-0.2)
            cv.paint(cv.ellipse((tipx, tipy - 0.3), 0.8, 0.8), eye, hi=0.4, lo=-0.1)
        cv.save(os.path.join(ART, "mobs", "snail", "frame_%d.png" % k))


def draw_golem(cv, dx=0.0, bob=0.0, legs=(0.0, 0.0), far_fist=None, near_fist=None, tilt=0.0, eyes=True, drop=0.0):
    """One pose of the Golem, 96 x 88, facing right, standing on the bottom row: a hulking man of dark stone, moss in the cracks, small ember eyes
    and one ember rune on the chest. dx leans the whole body, bob lifts it, legs are the two feet's sideways steps, the fists are where the hands are
    (relative to the shoulders), and drop sinks the body into its legs."""
    stone = ramp("#c8c8c8", "#969696", "#626262", "#303030")  # plain gray: the game colors it with the stone of the world it is summoned in (mob.gdshader, `stone_color`)
    gy, cx = 87, 44.0
    hip = 56.0 + bob + drop
    ty = hip - 21.0 + tilt * 0.2
    sx_far, sx_near = cx + dx - 19, cx + dx + 19
    sy = ty - 10
    far_fist = far_fist or (-5, 30)
    near_fist = near_fist or (6, 30)

    def arm(sx, fist, front):
        fx, fy = sx + fist[0], sy + fist[1]
        mid = ((sx + fx) / 2 + (2 if front else -2), (sy + fy) / 2 + 2)
        cv.paint(limb([(sx, sy), mid, (fx, fy)], [7.5, 6.5, 6.0]), stone, hi=0.4, lo=-0.25)
        cv.paint(cv.ellipse((fx, fy + 2), 8.5, 7.5), stone, hi=0.4, lo=-0.25)
        for k in range(3):  # knuckles
            cv.dot(fx - 4 + 4 * k, fy - 1, stone[3])

    def leg(x, step):
        fx = x + step
        cv.paint(limb([(x, hip), (fx - 1, gy - 14), (fx, gy - 4)], [8.0, 7.5, 7.5]), stone, hi=0.4, lo=-0.25)
        cv.paint(cv.ellipse((fx + 2, gy - 3), 10, 4.2), stone, hi=0.4, lo=-0.25)

    arm(sx_far, far_fist, False)
    leg(cx + dx * 0.4 - 10, legs[0])
    cv.paint(cv.ellipse((cx + dx, ty), 22, 20), stone, hi=0.42, lo=-0.22)                                # the chest
    cv.paint(cv.ellipse((cx + dx - 2, ty + 15), 17, 9), stone, hi=0.42, lo=-0.22, inner_outline=False)  # the belly
    cv.paint(cv.ellipse((sx_far, sy - 1), 10, 9), stone, hi=0.45, lo=-0.2)                                # shoulders
    cv.paint(cv.ellipse((sx_near, sy - 1), 10, 9), stone, hi=0.45, lo=-0.2)
    leg(cx + dx * 0.4 + 9, legs[1])
    # cracks, moss and the rune
    for pts in (((cx + dx - 12, ty - 8), (cx + dx - 8, ty - 2), (cx + dx - 11, ty + 6)), ((cx + dx + 8, ty + 10), (cx + dx + 12, ty + 15))):
        for a, b in zip(pts, pts[1:]):
            line(cv, a, b, stone[3], 0.5)
    for mx, my in ((sx_far - 4, sy - 7), (sx_near + 2, sy - 8), (cx + dx + 14, ty + 6), (cx + dx - 10, ty + 14)):
        for ox, oy in ((0, 0), (1, 0), (-1, 1), (0, 1), (2, 1)):
            cv.dot(mx + ox, my + oy, PAD[2] if (ox + oy) % 2 else PAD[1])
    for j in range(5):  # an ember rune down the chest
        cv.dot(cx + dx + 3, ty - 6 + j * 3, ORB[2])
    cv.dot(cx + dx + 1, ty - 3, ORB[2])
    cv.dot(cx + dx + 5, ty + 3, ORB[2])
    cv.glow_disc((cx + dx + 3, ty + 1), 6.0, ORB[3], 60)
    arm(sx_near, near_fist, True)
    hx, hy = cx + dx + 5 + tilt * 0.3, ty - 25 + drop * 0.3
    cv.paint(cv.ellipse((hx, hy), 10, 8.5), stone, hi=0.42, lo=-0.22)                                     # a low, heavy head
    cv.paint(cv.ellipse((hx + 4, hy + 4), 6, 4), stone, hi=0.3, lo=-0.3, inner_outline=False)            # the jaw
    cv.paint(cv.poly([(hx - 3, hy - 7), (hx + 1, hy - 12), (hx + 5, hy - 7)]), stone, hi=0.45, lo=-0.2)    # a crag of stone on top
    if eyes:
        for ex in (hx + 2, hx + 7):
            cv.dot(ex, hy - 1, ORB[0])
            cv.dot(ex, hy, ORB[2])
            cv.glow_disc((ex, hy - 1), 2.2, ORB[3], 110)


def make_golem():
    """The Golem: every animation the creatures use (idle, walk, attack, hit, death), 96 x 88, in art/mobs/golem/."""
    out = os.path.join(ART, "mobs", "golem")
    os.makedirs(out, exist_ok=True)

    def save(name, k, **kw):
        cv = canvas(96, 88)
        draw_golem(cv, **kw)
        cv.save(os.path.join(out, "%s_%d.png" % (name, k)))

    for k in range(4):  # breathing: the chest rises and sinks, the fists sway
        b = (0.0, -1.0, -1.0, 0.0)[k]
        save("idle", k, bob=b, far_fist=(-5, 30 + b), near_fist=(6, 30 + b))
    for k in range(6):  # a heavy, slow stride: the body dips as each foot lands
        t = 2 * math.pi * k / 6
        save("walk", k, bob=1.2 * abs(math.sin(t)) - 1.0, dx=2.0 * math.sin(t), legs=(7 * math.sin(t), -7 * math.sin(t)),
             far_fist=(-5 + 5 * math.sin(t), 30), near_fist=(6 - 5 * math.sin(t), 30))
    # attack: the fist is drawn back and up, held, and brought down hard
    poses = [((6, 12), 0.0, -2), ((9, -8), -3.0, -3), ((10, -16), -5.0, -3), ((24, 32), 6.0, 2), ((12, 30), 2.0, 0)]
    for k, (fist, lean, bob) in enumerate(poses):
        save("attack", k, near_fist=fist, dx=lean, bob=bob, tilt=lean * 1.5)
    save("hit", 0, dx=-4.0, tilt=-8.0, bob=1.0, eyes=False)
    save("hit", 1, dx=-2.0, tilt=-4.0, bob=0.0)
    # death: it cracks, sags, and falls into a heap of stone with the embers dying in it
    save("death", 0, dx=-3.0, tilt=-6.0, drop=3.0, eyes=False)
    save("death", 1, dx=-6.0, tilt=-10.0, drop=14.0, far_fist=(-10, 14), near_fist=(10, 14), eyes=False)
    for k, size in ((2, 1.0), (3, 0.8)):
        cv = canvas(96, 88)
        rng = random.Random(11)
        for i in range(9):
            x, y = 44 + rng.randint(-24, 24), 87 - rng.randint(3, int(14 * size))
            cv.paint(cv.ellipse((x, y), rng.randint(5, 9), rng.randint(3, 6)), ROCK, hi=0.4, lo=-0.25)
        cv.paint(cv.ellipse((50, 82), 8 * size, 6 * size), ROCK, hi=0.4, lo=-0.25)
        for ex, ey in ((52, 80), (38, 84), (60, 84)):
            cv.dot(ex, ey, ORB[2] if k == 2 else ORB[3])
        cv.save(os.path.join(out, "death_%d.png" % k))


JOBS = {"tree": make_tree, "vine": make_vines, "piranha": make_piranha, "flytrap": make_flytrap, "bramble": make_bramble, "podium": make_podium, "lectern": make_lectern, "plaque": make_plaque, "book": make_book, "lily": make_lily, "plank": make_plank, "quicksand": make_quicksand, "spikes": make_spikes, "door": make_door, "ship": make_shipwrecks, "shipbg": make_wreck_backdrops, "clouds": make_clouds, "snail": make_snail, "golem": make_golem}

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(JOBS)):
        JOBS[name]()
        print("drew", name)
