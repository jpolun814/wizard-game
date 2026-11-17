"""Poses for every frame, in sheet order. Timing (fps/loop) is copied from wizard.gd ANIMATIONS:
cast = a LOOP while a stroke is drawn (the weapon hand draws it with the tip), release = a one-shot thrust."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anims  # noqa: E402
from anims import S, kf, default_pose  # noqa: E402

STAFF_GRIP = 0.66   # choked up: the hand about two thirds of the way up the staff


# ------------------------------------------------------------------ idle (6)
def idle(i):
    t = i / 6 * 2 * math.pi
    p = default_pose()
    br = math.sin(t)
    p.update(ph=30.2 + 0.7 * br, lean=3 + 0.8 * br, head=-1 + 0.8 * br, fn=(7, 0), ff=(-6, 0), fn_ang=4,
             staff=S(3, hand=(14, -4 + 0.8 * br), grip=STAFF_GRIP), sway=0.8 * math.sin(t - 0.8),
             book=0, beard=1.2 * math.sin(t - 0.6))
    p["hf"] = (13 + 1.5 * br, 39 + 1.2 * math.sin(t + 1))
    return p, dict(motes=(t, i))


# ------------------------------------------------------------------ run (8): long strides like the sample wizard
#            contact  down   pass   push  kick   tuck  knee-up reach
RUN_X = [20, 10, -2, -16, -27, -17, 4, 17]
RUN_H = [0, 0, 0, 2, 9, 16, 12, 4]
RUN_A = [16, 0, 0, -32, -58, -62, -18, 8]
RUN_PH = [31.0, 29.4, 30.6, 32.4]


def run(i):
    n, f = i, (i + 4) % 8
    ph = 2 * math.pi * i / 8
    p = default_pose()
    p.update(ph=RUN_PH[i % 4], lean=16 + 2.5 * math.sin(2 * ph + 0.6), head=-9 - 2 * math.sin(2 * ph + 0.6), px=-2,
             fn=(RUN_X[n], RUN_H[n]), ff=(RUN_X[f], RUN_H[f]), fn_ang=RUN_A[n], ff_ang=RUN_A[f],
             staff=S(42 + 5 * math.sin(2 * ph), hand=(12, 0 + 2 * math.sin(2 * ph + 1)), grip=0.7),
             sway=-7 - 3 * math.sin(2 * ph), beard=-5 + 2 * math.sin(2 * ph), hat_tip=-6 + 3 * math.sin(2 * ph + 1))
    # the free arm pumps against the near leg, fist closed
    p["hf_fist"] = True
    p["hf_rel"] = (3 + 10 * math.cos(ph), 11 - 3 * math.sin(ph) - 2 * abs(math.cos(ph)))
    return p, {}


# ------------------------------------------------------------------ cast (8, loop): the weapon hand draws the stroke
def _cast_pose(t):
    p = default_pose()
    s = math.sin(t)
    p.update(ph=29.6 + 0.4 * math.sin(2 * t), lean=-2 + 1.0 * s, head=-7, fn=(10, 0), ff=(-9, 0), fn_ang=3,
             staff=S(14 + 12 * math.sin(t + 0.7), hand=(13 + 4 * math.cos(t), -11 + 3.5 * s), grip=0.62),
             sway=1.5 * s, beard=1.5 * math.sin(t - 0.5), hat_tip=1.5 * s)
    p["staff"]["glow"] = 1.6
    p["hf_rel"] = (11, 5 + 0.8 * s)  # the free hand held open in front, steady
    return p


def cast(i):
    t = i / 8 * 2 * math.pi
    p = _cast_pose(t)
    trail = [_cast_pose(t - k * 0.32) for k in range(1, 7)]
    fx = [("trail", dict(poses=trail)), ("ball", dict(r=3.0 + 0.8 * math.sin(2 * t))),
          ("sparks", dict(n=3, spread=4, seed=300 + i))]
    return p, dict(fx=fx)


# ------------------------------------------------------------------ release (8, once)
def release(i):
    p = default_pose()
    lean = kf(i, [(0, 0), (1, 18), (4, 19), (6, 13), (7, 7)])
    ph = kf(i, [(0, 30), (1, 26), (4, 26), (7, 29)])
    ang = kf(i, [(0, 64), (1, 82), (4, 84), (7, 72)])
    hand = kf(i, [(0, (6, -1)), (1, (16, -2)), (4, (17, -2)), (7, (12, -1))])
    p.update(ph=ph, lean=lean, head=-5, px=kf(i, [(0, -1), (1, 3), (7, 1)]),
             fn=(kf(i, [(0, 9), (1, 18), (4, 18), (7, 12)]), 0), ff=(kf(i, [(0, -8), (1, -14), (4, -14), (7, -9)]), 0),
             fn_ang=2, staff=S(ang, hand=hand, grip=0.6), sway=kf(i, [(0, 2), (1, -9), (7, -2)]), beard=-3, hat_tip=-3)
    p["hf"] = (kf(i, [(0, 12), (1, 15), (7, 9)]), kf(i, [(0, 40), (1, 44), (7, 38)]))
    p["staff"]["glow"] = 1.4
    fx = {  # a muzzle flash at the tip only: the spell itself is drawn by the game
        0: [("sparks", dict(n=6, spread=7, seed=400))],
        1: [("ball", dict(r=6))],
        2: [("burst", dict(r=11)), ("ball", dict(r=6))],
        3: [("burst", dict(r=13)), ("sparks", dict(n=8, spread=10, seed=403))],
        4: [("ball", dict(r=4)), ("wisps", dict(n=6, reach=14, seed=410, fwd=False))],
        5: [("sparks", dict(n=10, spread=14, seed=421, drift=(6, -2)))],
        6: [("sparks", dict(n=7, spread=18, seed=430, drift=(10, -4)))],
        7: [("sparks", dict(n=3, spread=20, seed=440, drift=(12, -6)))],
    }[i]
    return p, dict(fx=fx)


# ------------------------------------------------------------------ fall (2, loop): knees tucked, staff arm up
def fall(i):
    p = default_pose()
    p.update(ph=[44, 45.5][i], lean=[2, -1][i], head=[8, 6][i],
             fn=([7, 8][i], [19, 21][i]), ff=([-3, -5][i], [15, 17][i]), fn_ang=[-30, -24][i], ff_ang=[-45, -38][i],
             staff=S([24, 30][i], hand=([-9, -10][i], [-17, -19][i]), grip=0.58),
             sway=[7, 10][i], flap=[0.75, 0.62][i], beard=[3, 5][i], hat_tip=[8, 11][i])
    p["hf_rel"] = ([11, 12][i], [-6, -9][i])
    return p, {}


# ------------------------------------------------------------------ the rest reuse the rig's poses, choked up
def _reuse(fn):
    def wrapped(i):
        p, extra = fn(i)
        if p["staff"] and "base" not in p["staff"]:
            p["staff"]["grip"] = STAFF_GRIP if fn is not anims.jump else 0.62
        out = dict(extra)
        out["fx"] = [(k, dict(kw, at={"orb": "tip"}.get(kw.get("at"), kw.get("at", "tip"))))
                     for k, kw in extra.get("fx", []) if k == "sparks"]
        if p.get("flash"):  # a short flicker reads better than a long white-out
            p["flash"] = 0.32 if p["flash"] > 0.5 else 0.12 if p["flash"] > 0.2 else 0.0
        return p, out
    return wrapped


# name, frame count, pose fn, fps, loop  (fps/loop as in wizard.gd ANIMATIONS)
ANIMS = [
    ("idle", 6, idle, 8, True),
    ("run", 8, run, 12, True),
    ("cast", 8, cast, 8, True),
    ("release", 8, release, 16, False),
    ("hit", 4, _reuse(anims.hit), 12, False),
    ("death", 7, _reuse(anims.death), 9, False),
    ("jump", 2, _reuse(anims.jump), 10, False),
    ("fall", 2, fall, 8, True),
]


from poses_extra import EXTRA  # noqa: E402

ANIMS += EXTRA


def all_frames():
    out = []
    for name, n, fn, _, _ in ANIMS:
        for i in range(n):
            p, extra = fn(i)
            out.append((name, i, p, extra))
    return out
