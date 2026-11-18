"""The Golem: a hulking man built of rock, drawn with the same rig as the wizard parts (rig.py): shaded shapes lit from the upper left, a dark outline, cracks that glow.

    python tools/wizard_parts/golem.py          # every animation, into art/mobs/golem/
    python tools/wizard_parts/golem.py sheet    # also a contact sheet (in the temp folder) to look at

The stone is plain gray on purpose. A wizard who becomes a Golem (scripts/wizard/golem_form.gd) wears these pictures with the gray parts replaced by the very
texture of the ground they stand on (the `stone` of scripts/fx/wizard_body.gdshader), shaded by how light or dark the gray is here. So the light, the form and the
cracks are all drawn in gray, and only the embers, the eyes and the moss have colors of their own.

Never edit the PNGs by hand: change this file and run it. Every frame is 128 x 112, facing right, standing on the bottom row.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig  # noqa: E402
from rig import ramp, ik, ORB  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "art", "mobs", "golem")
W, H = 128, 112
CX, GY = 62, 111

# light, mid, dark, deep: the value is all that is used (the ground's own colors go over it)
STONE = ramp("#d2d2d2", "#9c9c9c", "#686868", "#2c2c2c")
MOSS = [(120, 184, 92), (78, 140, 74), (44, 96, 62), (22, 52, 40)]


def canvas():
    rig.W, rig.H = W, H
    rig.yy, rig.xx = np.mgrid[0:H, 0:W]
    return rig.Canvas()


# ----------------------------------------------------------------- shapes
def lumpy(c, rx, ry, seed, rot=0.0, rough=0.14):
    """An ellipse with a ragged edge: no rock is a perfect oval. Returns the mask and the light on it."""
    rng = np.random.RandomState(seed)
    terms = [(k, rng.uniform(0, 2 * math.pi), rng.uniform(0.3, 1.0) * rough / k ** 0.5) for k in (2, 3, 5, 7)]
    cr, sr = math.cos(rot), math.sin(rot)
    ox, oy = rig.xx - c[0], rig.yy - c[1]
    u = (ox * cr + oy * sr) / rx
    v = (-ox * sr + oy * cr) / ry
    ang = np.arctan2(v, u)
    edge = 1.0 + sum(a * np.sin(k * ang + ph) for k, ph, a in terms)
    m = np.sqrt(u * u + v * v) <= edge
    s = (ox * rig.LIGHT[0] + oy * rig.LIGHT[1]) / max(rx, ry)
    return m, s


def rock_limb(a, b, ra, rb):
    """A thick tapered piece of rock from a to b."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy or 1e-6
    t = np.clip(((rig.xx - a[0]) * dx + (rig.yy - a[1]) * dy) / L2, 0, 1)
    ox, oy = rig.xx - (a[0] + t * dx), rig.yy - (a[1] + t * dy)
    r = ra + (rb - ra) * t
    m = np.sqrt(ox * ox + oy * oy) <= r
    s = (ox * rig.LIGHT[0] + oy * rig.LIGHT[1]) / r
    return m, s


def rocky(cv, ms, seed, facets=4, spread=0.5, bias=0.0):
    """Paints a shape as rock: its light is split into a few flat faces, each tilted its own way, with a crack where two faces meet hard, and a dark rim
    where it lies over another piece so the pieces read apart."""
    m, s = ms
    if not m.any():
        return
    ys, xs = np.nonzero(m)
    rng = np.random.RandomState(seed)
    pick = rng.choice(len(xs), size=min(facets, len(xs)), replace=False)
    sx, sy = xs[pick], ys[pick]
    tilt = rng.uniform(-spread, spread, size=len(pick))
    d = (xs[:, None] - sx[None, :]) ** 2 + (ys[:, None] - sy[None, :]) ** 2
    fid = d.argmin(1)
    lit = s[ys, xs] * 0.8 + tilt[fid] + bias
    lvl = np.where(lit > 0.36, 0, np.where(lit > -0.02, 1, np.where(lit > -0.5, 2, 3)))
    before = cv.px[..., 3] > 0
    for i in range(4):
        sel = lvl == i
        cv.px[ys[sel], xs[sel], :3] = STONE[i]
        cv.px[ys[sel], xs[sel], 3] = 255
    fmap = np.full(m.shape, -1.0)
    fmap[ys, xs] = tilt[fid]
    for dy, dx in ((0, 1), (1, 0)):
        other = np.roll(fmap, (-dy, -dx), (0, 1))
        hard = m & (other > -1.0) & (np.abs(other - fmap) > 0.5)
        cv.px[hard, :3] = STONE[2]
    cv.edge[m] = STONE[3]
    er = m.copy()
    er[1:, :] &= m[:-1, :]
    er[:-1, :] &= m[1:, :]
    er[:, 1:] &= m[:, :-1]
    er[:, :-1] &= m[:, 1:]
    rim = m & ~er & before
    cv.px[rim, :3] = STONE[3]


def moss(cv, x, y, seed, size=3):
    rng = random.Random(seed)
    for _ in range(size * 3):
        px, py = int(x + rng.randint(-size, size)), int(y + rng.randint(-size // 2, size // 2))
        if 0 <= px < W and 0 <= py < H and cv.px[py, px, 3] > 0:
            cv.px[py, px, :3] = MOSS[rng.choice((0, 1, 1, 2))]


def crack(cv, pts, glow=False):
    """A crack across the rock: dark, or with an ember in it."""
    for a, b in zip(pts, pts[1:]):
        n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
        for i in range(n + 1):
            x, y = int(round(a[0] + (b[0] - a[0]) * i / n)), int(round(a[1] + (b[1] - a[1]) * i / n))
            if 0 <= x < W and 0 <= y < H and cv.px[y, x, 3] > 0:
                cv.px[y, x, :3] = ORB[2] if glow else STONE[3]
                if glow and i % 3 == 0:
                    cv.px[y, x, :3] = ORB[1]
    if glow:
        mid = pts[len(pts) // 2]
        cv.glow_disc(mid, 4.0, ORB[3], 70)


# ----------------------------------------------------------------- the body
def draw_golem(cv, p, seed=1):
    """One pose. p's keys (all optional): px (the pelvis, sideways), sink (how far it squats), lean (the chest, forward), head (dx, dy),
    far_hand / near_hand (where each fist is, from its shoulder), far_foot / near_foot (x from the middle, height above the ground), eyes (0 to 1)."""
    px = p.get("px", 0.0)
    sink = p.get("sink", 0.0)
    lean = p.get("lean", 0.0)
    hx, hy = p.get("head", (0.0, 0.0))
    far_hand = p.get("far_hand", (-8, 34))
    near_hand = p.get("near_hand", (9, 34))
    far_foot = p.get("far_foot", (-12, 0))
    near_foot = p.get("near_foot", (13, 0))
    eyes = p.get("eyes", 1.0)
    squash = p.get("squash", 0.0)  # the whole body pressed down, for a landing

    pelvis = (CX + px, GY - 5 - 33 + sink)
    chest = (CX + px + lean, pelvis[1] - 24 + sink * 0.25 + squash * 0.5)
    sh_far = (chest[0] - 23, chest[1] - 8)
    sh_near = (chest[0] + 23, chest[1] - 8)

    def foot_target(f):
        return (CX + f[0], GY - 5 - f[1])

    def arm(sh, hand, outward):
        fist = (sh[0] + hand[0], sh[1] + hand[1] + (5 if hand[1] >= 18 else 0))  # a hanging arm reaches a little lower: it is not bent into a hug
        elbow, fist = ik(sh, fist, 21, 21, outward)
        return elbow, fist

    def leg(hip_dx, foot, bend=-1):
        hip = (pelvis[0] + hip_dx, pelvis[1] + 3)
        knee, ankle = ik(hip, foot_target(foot), 17, 17, bend)
        return hip, knee, ankle

    def draw_leg(hip, knee, ankle, seed_, bias):
        rocky(cv, rock_limb(hip, knee, 10, 9), seed_, 3, bias=bias)
        rocky(cv, lumpy(knee, 9.5, 9, seed_ + 1), seed_ + 1, 3, bias=bias)
        rocky(cv, rock_limb(knee, ankle, 9, 8.5), seed_ + 2, 3, bias=bias)
        rocky(cv, lumpy((ankle[0] + 3, ankle[1] + 2), 13, 6.5, seed_ + 3, rough=0.1), seed_ + 3, 3, bias=bias)

    def draw_arm(sh, elbow, fist, seed_, bias):
        rocky(cv, rock_limb(sh, elbow, 9, 8), seed_, 3, bias=bias)
        rocky(cv, lumpy(elbow, 8.5, 8, seed_ + 1), seed_ + 1, 3, bias=bias)
        rocky(cv, rock_limb(elbow, fist, 8, 9.5), seed_ + 2, 3, bias=bias)
        rocky(cv, lumpy((fist[0], fist[1] + 2), 11, 10, seed_ + 3, rough=0.12), seed_ + 3, 4, bias=bias)
        for k in range(3):  # knuckles
            cv.dot(fist[0] - 4 + 4 * k, fist[1] - 3 + (k % 2), STONE[3])

    e_far, f_far = arm(sh_far, far_hand, 1)
    hip_f, knee_f, ank_f = leg(-9, far_foot)
    # far side first, a little darker
    draw_arm(sh_far, e_far, f_far, seed * 10, -0.18)
    draw_leg(hip_f, knee_f, ank_f, seed * 10 + 20, -0.18)
    # the trunk: hips, belly, chest and the great shoulders
    rocky(cv, lumpy((pelvis[0], pelvis[1] + 2), 19, 11, seed * 10 + 40), seed * 10 + 40, 3)
    rocky(cv, lumpy((chest[0] - 1, chest[1] + 15 - squash * 0.3), 17, 12, seed * 10 + 41, rough=0.1), seed * 10 + 41, 3)
    rocky(cv, lumpy(chest, 26, 20, seed * 10 + 42, rough=0.1), seed * 10 + 42, 5)
    for sh, sd in ((sh_far, seed * 10 + 43), (sh_near, seed * 10 + 44)):
        rocky(cv, lumpy((sh[0], sh[1] - 2), 13, 10, sd, rough=0.16), sd, 4)
        rocky(cv, cv.poly([(sh[0] - 6, sh[1] - 8), (sh[0] - 1, sh[1] - 17), (sh[0] + 5, sh[1] - 8)]), sd + 7, 2)  # a crag on each shoulder
    hip_n, knee_n, ank_n = leg(9, near_foot)
    draw_leg(hip_n, knee_n, ank_n, seed * 10 + 50, 0.0)
    # the head: low and heavy, between the shoulders, the brow over the eyes
    head = (chest[0] + 6 + hx, chest[1] - 24 + hy + squash * 0.4)
    rocky(cv, lumpy(head, 11.5, 10, seed * 10 + 60, rough=0.1), seed * 10 + 60, 4)
    rocky(cv, lumpy((head[0] + 5, head[1] + 5), 7, 5, seed * 10 + 61), seed * 10 + 61, 2)               # the jaw
    rocky(cv, cv.poly([(head[0] - 3, head[1] - 8), (head[0] + 1, head[1] - 15), (head[0] + 6, head[1] - 8)]), seed * 10 + 62, 2)  # a crag on top
    rocky(cv, cv.poly([(head[0] - 1, head[1] - 2), (head[0] + 11, head[1] - 3), (head[0] + 11, head[1] - 1), (head[0] - 1, head[1] + 1)]), seed * 10 + 63, 1, bias=-0.3)  # the brow
    e_near, f_near = arm(sh_near, near_hand, -1)
    draw_arm(sh_near, e_near, f_near, seed * 10 + 70, 0.0)

    # cracks, moss, and the ember that burns in the chest
    crack(cv, [(chest[0] - 14, chest[1] - 12), (chest[0] - 9, chest[1] - 4), (chest[0] - 12, chest[1] + 5), (chest[0] - 8, chest[1] + 12)])
    crack(cv, [(pelvis[0] + 6, pelvis[1] - 3), (pelvis[0] + 11, pelvis[1] + 4)])
    crack(cv, [(chest[0] + 2, chest[1] - 10), (chest[0] + 6, chest[1] - 3), (chest[0] + 3, chest[1] + 4), (chest[0] + 8, chest[1] + 10)], glow=True)
    crack(cv, [(chest[0] + 6, chest[1] - 3), (chest[0] + 13, chest[1] - 5), (chest[0] + 18, chest[1] - 1)], glow=True)
    moss(cv, sh_far[0] - 5, sh_far[1] - 9, seed + 1, 4)
    moss(cv, sh_near[0] + 4, sh_near[1] - 9, seed + 2, 3)
    moss(cv, chest[0] - 14, chest[1] + 12, seed + 3, 3)
    moss(cv, knee_n[0] + 2, knee_n[1] - 5, seed + 4, 2)
    if eyes > 0.0:
        for ex in (head[0] + 2, head[0] + 8):
            cv.dot(ex, head[1] - 0.5, ORB[0] if eyes > 0.6 else ORB[2])
            cv.dot(ex, head[1] + 0.5, ORB[2])
            cv.glow_disc((ex, head[1]), 2.4 * eyes + 0.4, ORB[3], int(110 * eyes))
    return {"head": head, "chest": chest, "pelvis": pelvis}


# ----------------------------------------------------------------- the frames
def render(name, k, p, seed=1, extra=None):
    cv = canvas()
    draw_golem(cv, p, seed)
    if extra:
        extra(cv)
    cv.finish_outline()
    os.makedirs(OUT, exist_ok=True)
    cv.image().save(os.path.join(OUT, "%s_%d.png" % (name, k)))


def sway(t, a):
    return a * math.sin(t)


def make_all():
    for f in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    # idle: it breathes, the fists swing a little, the ember beats
    for k in range(6):
        t = 2 * math.pi * k / 6
        b = 1.2 * math.sin(t)
        render("idle", k, dict(sink=-b * 0.5, far_hand=(-8, 34 + b), near_hand=(9, 34 - b), head=(0, -b * 0.4), eyes=0.85 + 0.15 * math.sin(t)))
    # walk: a slow, heavy stride, the body dipping as each foot comes down
    for k in range(8):
        t = 2 * math.pi * k / 8
        s = math.sin(t)
        lift_n = max(0.0, math.cos(t)) * 7
        lift_f = max(0.0, -math.cos(t)) * 7
        render("walk", k, dict(px=1.5 * s, sink=1.6 * abs(s) - 0.5, lean=2.0, near_foot=(13 + 11 * s, lift_n), far_foot=(-12 - 11 * s, lift_f),
                               far_hand=(-8 + 8 * s, 32), near_hand=(9 - 8 * s, 32), head=(1, 1 + 1.5 * abs(s))))
    # jump: it crouches, drives up with its arms thrown back, and hangs
    render("jump", 0, dict(sink=9, lean=-3, far_foot=(-14, 0), near_foot=(15, 0), far_hand=(-14, 22), near_hand=(15, 22), head=(2, 4)))
    render("jump", 1, dict(sink=-2, lean=1, far_foot=(-9, 4), near_foot=(10, 2), far_hand=(-12, 8), near_hand=(12, 8), head=(0, -1)))
    render("jump", 2, dict(sink=-3, far_foot=(-8, 14), near_foot=(9, 9), far_hand=(-16, 2), near_hand=(16, 2), head=(0, -1)))
    # fall: legs spread, arms out for balance
    render("fall", 0, dict(sink=-4, far_foot=(-14, 10), near_foot=(14, 12), far_hand=(-20, 4), near_hand=(20, 4), head=(0, -2)))
    render("fall", 1, dict(sink=-2, far_foot=(-15, 12), near_foot=(15, 14), far_hand=(-22, 6), near_hand=(22, 6), head=(0, -2)))
    # land: it hits the ground and the whole body gives, then heaves back up
    render("land", 0, dict(sink=14, squash=8, lean=1, far_foot=(-17, 0), near_foot=(18, 0), far_hand=(-18, 30), near_hand=(18, 30), head=(0, 6)))
    render("land", 1, dict(sink=10, squash=5, far_foot=(-16, 0), near_foot=(17, 0), far_hand=(-15, 32), near_hand=(16, 32), head=(0, 4)))
    render("land", 2, dict(sink=4, squash=2, far_foot=(-13, 0), near_foot=(14, 0), far_hand=(-10, 34), near_hand=(11, 34), head=(0, 1)))
    render("land", 3, dict(sink=0, far_hand=(-8, 34), near_hand=(9, 34)))
    # attack: the right fist is drawn back and up, held, and brought down hard
    atk = [dict(lean=-3, near_hand=(2, 6), sink=2, head=(-1, 1)),
           dict(lean=-6, near_hand=(-6, -20), sink=3, px=-3, head=(-2, 2)),
           dict(lean=-6, near_hand=(-4, -24), sink=3, px=-3, head=(-2, 2)),
           dict(lean=7, near_hand=(26, 30), sink=6, px=3, head=(3, 3)),
           dict(lean=5, near_hand=(26, 34), sink=6, px=3, head=(3, 3)),
           dict(lean=1, near_hand=(12, 34), sink=1)]
    for k, p in enumerate(atk):
        render("attack", k, p)
    # smash: both fists raised high over its head, trembling, and brought down together with its whole weight
    smash = [dict(lean=-2, near_hand=(4, 4), far_hand=(-4, 4), sink=4),
             dict(lean=-5, near_hand=(2, -16), far_hand=(-8, -16), sink=4, px=-2, head=(-1, 2)),
             dict(lean=-8, near_hand=(0, -26), far_hand=(-10, -26), sink=2, px=-3, head=(-2, 3), far_foot=(-14, 0), near_foot=(14, 0)),
             dict(lean=-9, near_hand=(2, -29), far_hand=(-8, -29), sink=0, px=-3, head=(-2, 4)),
             dict(lean=-9, near_hand=(-1, -28), far_hand=(-11, -28), sink=1, px=-3, head=(-2, 4)),
             dict(lean=9, near_hand=(26, 36), far_hand=(14, 36), sink=10, px=4, head=(4, 4), far_foot=(-16, 0), near_foot=(17, 0)),
             dict(lean=8, near_hand=(26, 38), far_hand=(14, 38), sink=11, px=4, head=(4, 5), far_foot=(-17, 0), near_foot=(18, 0)),
             dict(lean=5, near_hand=(18, 36), far_hand=(6, 36), sink=6, px=2),
             dict(lean=1, near_hand=(10, 34), far_hand=(-6, 34), sink=1)]
    for k, p in enumerate(smash):
        render("smash", k, p)
    render("hit", 0, dict(px=-5, lean=-9, sink=2, head=(-5, 3), far_hand=(-14, 30), near_hand=(4, 30), eyes=0.25))
    render("hit", 1, dict(px=-3, lean=-5, sink=1, head=(-3, 2), far_hand=(-11, 32), near_hand=(6, 32)))
    # death: it cracks, sags, and comes apart into a heap of rock with the ember going out in it
    render("death", 0, dict(px=-3, lean=-8, sink=5, head=(-4, 4), eyes=0.3, far_hand=(-12, 26), near_hand=(6, 26)))
    render("death", 1, dict(px=-6, lean=-12, sink=16, squash=6, head=(-6, 10), eyes=0.0, far_hand=(-14, 18), near_hand=(10, 18), far_foot=(-18, 0), near_foot=(16, 0)))
    for k, size in ((2, 1.0), (3, 0.85), (4, 0.8)):
        cv = canvas()
        rng = random.Random(11)
        for i in range(11):
            x, y = CX + rng.randint(-28, 28), GY - rng.randint(4, int(18 * size))
            rocky(cv, lumpy((x, y), rng.randint(6, 12), rng.randint(4, 8), 90 + i), 90 + i, 3)
        rocky(cv, lumpy((CX + 6, GY - 8 * size), 11 * size, 8 * size, 77), 77, 3)
        for ex, ey in ((CX + 8, GY - 9), (CX - 12, GY - 4), (CX + 22, GY - 5)):
            cv.dot(ex, ey, ORB[2] if k < 4 else ORB[3])
        cv.finish_outline()
        cv.image().save(os.path.join(OUT, "death_%d.png" % k))
    # rise: a heap of rock, an ember in it, and then the golem standing up out of it (the world's ground grows up around the wizard first, in the game)
    for k, (sink, squash, lean, eyes, hands) in enumerate([(26, 12, 0, 0.0, 6), (22, 10, 2, 0.3, 14), (14, 6, 5, 0.7, 24), (8, 3, 3, 1.0, 30), (3, 1, 1, 1.0, 33), (0, 0, 0, 1.0, 34)]):
        render("rise", k, dict(sink=sink, squash=squash, lean=lean, eyes=eyes, far_hand=(-8, hands), near_hand=(9, hands), head=(0, max(0, sink * 0.35)),
                               far_foot=(-12 - sink * 0.2, 0), near_foot=(13 + sink * 0.2, 0)))
    print("golem: %d frames" % len([f for f in os.listdir(OUT) if f.endswith(".png")]))


def contact_sheet():
    names = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    order = ["idle", "walk", "jump", "fall", "land", "attack", "smash", "hit", "death", "rise"]
    rows = []
    for anim in order:
        frames = [f for f in names if f.startswith(anim + "_")]
        rows.append(frames)
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * W, len(rows) * H), (58, 52, 64, 255))
    for r, frames in enumerate(rows):
        for c, f in enumerate(frames):
            sheet.alpha_composite(Image.open(os.path.join(OUT, f)).convert("RGBA"), (c * W, r * H))
    path = os.path.join(os.environ.get("TEMP", "."), "golem_sheet.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("sheet:", path)


if __name__ == "__main__":
    make_all()
    if "sheet" in sys.argv[1:]:
        contact_sheet()
