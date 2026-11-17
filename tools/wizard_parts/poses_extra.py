"""The extra animations (movement, things done to the wizard, casting styles, polish).
Each function returns (pose, extra) for frame i, like poses.py. Conventions: +x = forward (the way the sprite faces),
heights are above the ground; staff S(ang, hand=(dx, dy) from the shoulder, grip); ang 0 = straight up, + = top forward.
Pulls/knockbacks are drawn as if the force comes from the FRONT (pulled) or pushes BACKWARD (knockback) - the game flips the
sprite to suit."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anims import S, kf, default_pose  # noqa: E402

TAU = 2 * math.pi
GRIP = 0.66


def P(**kw):
    p = default_pose()
    p.update(kw)
    return p


def plant(base_x, hand, **kw):  # staff butt planted on the ground at base_x, hand held at `hand` (from the shoulder)
    d = dict(ang=0, base_at=(base_x, 0))
    d.update(kw)
    return d, hand


def idle_like(**kw):
    p = P(ph=30.2, lean=3, head=-1, fn=(7, 0), ff=(-6, 0), fn_ang=4, staff=S(3, hand=(14, -4), grip=GRIP))
    p["hf"] = (13, 39)
    p.update(kw)
    return p


# =========================================================== movement
def swim(i):  # treading water, staff held up out of the water, free arm paddling
    t = TAU * i / 6
    p = P(ph=34 + 1.2 * math.sin(t), lean=8, head=-4, px=0,
          fn=(6 + 4 * math.sin(t), 10 + 4 * math.cos(t)), ff=(-4 + 4 * math.sin(t + math.pi), 9 + 4 * math.cos(t + math.pi)),
          fn_ang=-30, ff_ang=-35, staff=S(6, hand=(7, -15 + 0.8 * math.sin(t)), grip=0.5),
          sway=3 * math.sin(t), flap=0.75, beard=1.5 * math.sin(t), hat_tip=2 * math.sin(t))
    p["hf_rel"] = (9 + 6 * math.cos(t), 13 + 3 * math.sin(t))
    return p, {}


def swim_dive(i):  # head-first down, flutter kick, staff pointed the way it dives
    t = TAU * i / 6
    p = P(ph=52, lean=132, head=-20, head_rot=118, px=-6,
          fn=(-20, 70 + 5 * math.sin(t)), ff=(-23, 64 + 5 * math.sin(t + math.pi)), fn_ang=-80, ff_ang=-80,
          staff=S(140, hand=(12, 4 + math.sin(t)), grip=0.55), sway=-6, flap=0.6, beard=-4, hat_tip=-6)
    p["hf_rel"] = (6 + 9 * math.cos(t), 6 + 7 * math.sin(t))
    return p, {}


def swim_up(i):  # the dive turned over: head-first up, the same flutter kick, staff pointed the way it climbs
    t = TAU * i / 6
    p = P(ph=52, lean=48, head=-20, head_rot=62, px=-6,
          fn=(-20, 34 - 5 * math.sin(t)), ff=(-23, 40 - 5 * math.sin(t + math.pi)), fn_ang=-100, ff_ang=-100,
          staff=S(40, hand=(12, 4 + math.sin(t)), grip=0.55), sway=-6, flap=0.6, beard=-4, hat_tip=-6)
    p["hf_rel"] = (6 + 9 * math.cos(t), 6 + 7 * math.sin(t))
    return p, {}


def swim_side(i):  # lying level in the water and pulling along: body flat, a flutter kick behind, one arm over and one under, staff trailing forward
    t = TAU * i / 6
    p = P(ph=46, lean=88, head=-14, head_rot=76, px=-4,
          fn=(-30, 44 + 6 * math.sin(t)), ff=(-33, 44 + 6 * math.sin(t + math.pi)), fn_ang=-84, ff_ang=-84,
          staff=S(98, hand=(14, 2 + math.sin(t)), grip=0.55), sway=-3, flap=0.7, beard=-3, hat_tip=-5)
    p["hf_rel"] = (8 + 10 * math.cos(t), 4 + 6 * math.sin(t))
    return p, {}


def climb(i):  # hand over hand up a vine in front of the wizard (vine at about x = +10)
    t = TAU * i / 6
    up_n, up_f = math.sin(t), math.sin(t + math.pi)
    p = P(ph=35 + 1.0 * math.sin(2 * t), lean=4, head=-12,
          fn=(7, 13 + 6 * up_f), ff=(6, 13 + 6 * up_n), fn_ang=-5, ff_ang=-5,
          staff=dict(ang=2, grip=0.5), sway=1.5 * up_n, flap=0.9, beard=0.8 * up_n)
    p["hf_fist"] = True
    p["hn"] = (10, 70 + 6 * up_n)
    p["hf"] = (9, 70 + 6 * up_f)
    return p, {}


def climb_hang(i):
    p = P(ph=35 - 0.4 * i, lean=4, head=-10, fn=(7, 15), ff=(6, 12), fn_ang=-5, ff_ang=-5,
          staff=dict(ang=2, grip=0.5), sway=0.5 * i, flap=0.9)
    p["hf_fist"] = True
    p["hn"] = (10, 74)
    p["hf"] = (9, 72 - 0.5 * i)
    return p, {}


def float_(i):  # Featherfall: drifting down, arms out, robe billowing up
    t = TAU * i / 4
    p = P(ph=38 + 0.8 * math.sin(t), lean=2 * math.sin(t), head=4, fn=(5, 8 + math.sin(t)), ff=(-3, 6), fn_ang=-35,
          ff_ang=-40, staff=S(32 + 4 * math.sin(t), hand=(13, -4), grip=0.6), sway=5 + 2 * math.sin(t), flap=0.55,
          beard=2 * math.sin(t), hat_tip=6 + 2 * math.sin(t))
    p["hf_rel"] = (-11, -5 + 1.5 * math.sin(t + 1))
    return p, {}


def surf(i):  # riding a wave: wide low stance, leaning back, arms out for balance
    t = TAU * i / 4
    p = P(ph=25 + 1.0 * math.sin(t), lean=-6 + 2 * math.sin(t), head=4, fn=(13, 0), ff=(-12, 0), fn_ang=6, ff_ang=-4,
          staff=S(72 + 4 * math.sin(t), hand=(14, -3), grip=0.55), sway=-12 - 2 * math.sin(2 * t), beard=-6,
          hat_tip=-8 - 2 * math.sin(2 * t))
    p["hf_rel"] = (-11, 1 + math.sin(t))
    return p, {}


def rocket(i):  # crouch, then blast upward (flame from the feet)
    if i == 0:
        p = P(ph=22, lean=10, head=6, fn=(7, 0), ff=(-7, 0), staff=S(2, hand=(7, -2), grip=GRIP), sway=2)
        p["hf_rel"] = (6, 10)
        return p, dict(fx=[("sparks", dict(at="feet", n=6, spread=8, seed=500))])
    k = i - 1
    p = P(ph=38, lean=2, head=-10, fn=(2, 10), ff=(-2, 8), fn_ang=-65, ff_ang=-65,
          staff=S(4, hand=(5, -18), grip=GRIP), sway=0, flap=0.75 - 0.05 * k, beard=0, hat_tip=-2 + k)
    p["hf_rel"] = (5, -15)
    return p, {}  # the game draws the rocket boost


def fly(i):  # flying in a world with no ground: leaning into it, legs trailing
    t = TAU * i / 4
    p = P(ph=38, lean=34, head=-24, fn=(-14, 14 + 2 * math.sin(t)), ff=(-18, 18 + 2 * math.sin(t + math.pi)),
          fn_ang=-55, ff_ang=-55, staff=S(80, hand=(14, -1), grip=0.6), sway=-12 - 3 * math.sin(2 * t), flap=0.85,
          beard=-5 - math.sin(2 * t), hat_tip=-8 - 2 * math.sin(2 * t))
    p["hf_rel"] = (-6, 10)
    p["hf_fist"] = True
    return p, {}


def land(i):
    p = P(ph=[23, 25.5, 28.8][i], lean=[12, 9, 5][i], head=[6, 3, 0][i], fn=(8, 0), ff=(-7, 0), fn_ang=2,
          staff=S([12, 8, 4][i], hand=(13, [3, 0, -3][i]), grip=GRIP), sway=[4, 2, 0.5][i], flap=[0.85, 0.95, 1][i])
    p["hf_rel"] = (8, [12, 12, 11][i])
    return p, {}


def stuck(i):  # feet held fast (mud, brambles, roots): heaving to pull free
    t = TAU * i / 6
    s = math.sin(t)
    p = P(ph=28 + 0.8 * s, lean=6 + 9 * s, head=-4 + 7 * s, fn=(7, 0), ff=(-7, max(0, 2.2 * math.sin(t + 0.6))),
          fn_ang=0, ff_ang=-10 * max(0, s), staff=S(22 + 12 * s, hand=(12, -4 + 3 * s), grip=GRIP),
          sway=-4 * s, beard=-3 * s, hat_tip=-3 * s)
    p["hf_rel"] = (-4 + 9 * math.sin(t + 0.5), 6 - 3 * s)
    p["hf_fist"] = True
    return p, {}


# =========================================================== things done to the wizard
def frozen(i):  # the pose caught in the ice (the game draws the ice); a tiny shiver
    p = P(ph=28, lean=-4, head=8, px=0.6 * i, fn=(8, 0), ff=(-7, 0), staff=S(-28, hand=(10, -7), grip=GRIP),
          sway=1, beard=1)
    p["hf_rel"] = (9, -11)
    p["hf_fist"] = True
    return p, {}


def thaw(i):  # shaking, then bursting out of the ice
    if i < 2:
        p, _ = frozen(i)
        p["px"] = [-1.2, 1.4][i]
        p["lean"] = -4 + [2, -2][i]
        return p, dict(fx=[("sparks", dict(at="body", n=4 + 4 * i, spread=10, seed=600 + i))])
    if i == 2:
        p = P(ph=31, lean=-8, head=-12, fn=(10, 0), ff=(-9, 0), staff=S(26, hand=(14, -10), grip=GRIP), sway=6,
              beard=4, hat_tip=6)
        p["hf_rel"] = (-10, -8)
        return p, dict(fx=[("sparks", dict(at="body", n=26, spread=26, seed=620)),
                           ("burst", dict(at="body", r=14))])
    p = idle_like(lean=1, head=2, sway=2)
    return p, dict(fx=[("sparks", dict(at="body", n=10, spread=36, seed=630, drift=(0, 10)))])


def pulled(i):  # dragged toward the FRONT by a black hole: leaning back, heels sliding, everything streaming forward
    t = TAU * i / 6
    s = math.sin(t)
    p = P(ph=27 + 0.6 * s, lean=-18 + 3 * s, head=10, px=1.2 * s, fn=(15 + 1.5 * s, 0), ff=(2, 0), fn_ang=22, ff_ang=6,
          sway=12 + 3 * math.sin(3 * t), beard=6 + 1.5 * math.sin(3 * t), hat_tip=14 + 2 * math.sin(3 * t))
    p["staff"], p["hn_rel"] = plant(-17, (-7, 10), grip=GRIP)
    p["hf_rel"] = (-12, -2 + 3 * s)
    return p, dict(fx=[("sparks", dict(at="body", n=5, spread=14, seed=700 + i, drift=(18 + 4 * i, 0)))])


def sucked_in(i):  # lifted off the feet and spun into the pull, stretched and shrinking away
    k = i / 5
    p = P(ph=34, lean=24, head=10, fn=(-12, 12), ff=(-17, 16), fn_ang=-50, ff_ang=-50,
          staff=S(70, hand=(14, -2), grip=0.6), sway=12, flap=0.8, beard=7, hat_tip=14)
    p["hf_rel"] = (14, -6)
    p["xform"] = dict(anchor=(0, 44), rot=40 * i, sx=max(0.08, (1 - 0.18 * i) * (1 + 0.35 * k)),
                      sy=max(0.08, (1 - 0.18 * i) * (1 - 0.3 * k)), dx=10 * i, dy=-3 * i,
                      alpha=[1, 1, 1, 0.9, 0.6, 0.25][i])
    return p, dict(fx=[("sparks", dict(at="body", n=6, spread=16, seed=720 + i, drift=(22, 0)))])


def knockback(i):  # flung backward, tumbling (the whole curled body turns a quarter each frame)
    p = P(ph=32, lean=30, head=20, fn=(6, 22), ff=(2, 18), fn_ang=-20, ff_ang=-30,
          staff=S(40, hand=(8, 4), grip=0.6), sway=6, flap=0.7, beard=3, hat_tip=6)
    p["hf_rel"] = (6, 6)
    p["xform"] = dict(anchor=(0, 44), rot=-90 * i)
    p["hf_fist"] = True
    return p, {}


def _up_from_prone(i, slow=False):
    if i == 0:
        p = P(ph=5.6, lean=89, head=2, head_rot=86 if slow else 80, px=-13, fn=(-36, 0.5), ff=(-40, 0.5),
              fn_ang=-70, ff_ang=-70, lbend=-1, staff=dict(ang=0, base=(16, 2), top=(60, 3), glow=0.1),
              sway=-17, flap=0.15, beard=0, hat_tip=10)
        p["hn"], p["hf"] = (28, 3), (25, 2.5)
        return p
    if i == 1:  # push up on the hands
        p = P(ph=10, lean=58, head=-12, px=-9, fn=(-14, 0), ff=(-20, 0), fn_ang=-70, ff_ang=-70,
              staff=dict(ang=0, base=(16, 2), top=(60, 3), glow=0.2), sway=-8, flap=0.6, hat_tip=6)
        p["hn"], p["hf"] = (19, 2), (15, 2)
        return p
    if i == 2:  # kneel, grab the staff
        p = P(ph=15, lean=22, head=18 if slow else 8, px=-3, fn=(10, 0), ff=(-17, 3), ff_ang=-40, sway=2, hat_tip=5)
        p["staff"], p["hn_rel"] = plant(16, (12, 4), grip=GRIP)
        p["hf_rel"] = (6, 12)
        return p
    if i == 3:
        p = P(ph=22 if not slow else 15.5, lean=12 if not slow else 20, head=4 if not slow else -10, px=-1,
              fn=(9, 0), ff=(-8 if not slow else -17, 0 if not slow else 3), ff_ang=0 if not slow else -40, sway=1)
        p["staff"], p["hn_rel"] = plant(15, (12, -2), grip=GRIP)
        p["hf_rel"] = (6, 12)
        return p
    p = idle_like(lean=5 if slow else 3, head=4 if slow else -1)
    return p


def get_up(i):
    return _up_from_prone(i), {}


def wake(i):  # coming round after Faint (which plays death): slower, with a dazed head shake while kneeling
    return _up_from_prone(i, slow=True), (dict(fx=[("stars", dict(at="head", off=(0, -10), t=i * 1.4, n=2, rx=7))])
                                          if i in (2, 3) else {})


def dazed(i):  # wobbling, leaning on the staff, stars around the head
    t = TAU * i / 6
    p = P(ph=28 + 0.6 * math.sin(2 * t), lean=4 + 5 * math.sin(t), head=10 + 8 * math.sin(t + 1), px=2 * math.sin(t),
          fn=(8, 0), ff=(-6, 0), sway=2 * math.sin(t), beard=2 * math.sin(t + 1), hat_tip=3 * math.sin(t + 1))
    p["staff"], p["hn_rel"] = plant(17, (12, -1), grip=GRIP)
    p["hf_rel"] = (2, 14)
    return p, dict(fx=[("stars", dict(at="head", off=(0, -11), t=t, n=3, rx=8, ry=3))])


def gasping(i):  # Vacuum / out of air: clutching the throat, heaving
    t = TAU * i / 6
    s = math.sin(t)
    p = P(ph=28 + 0.8 * s, lean=14 + 5 * s, head=-10 + 7 * s, fn=(8, 0), ff=(-7, 0), sway=-2 * s, beard=-2 * s)
    p["staff"], p["hn_rel"] = plant(16, (11, 5), grip=GRIP)
    p["hf_rel"] = (4.5, -2.5)
    return p, {}


def cower(i):  # Fight or Flight (flight): crouched behind a raised arm, trembling
    p = P(ph=22, lean=18, head=24, px=[0, 0.7, -0.4, 0.5][i], fn=(9, 0), ff=(-9, 0), fn_ang=0,
          staff=S(-6, hand=(9, 0), grip=0.6), sway=2, beard=1, hat_tip=2)
    p["hf_rel"] = (7, -10)
    p["hf_fist"] = True
    return p, {}


# =========================================================== casting styles
def inhale(i):  # (once) before Fire Breath / Spore Puff
    p = P(ph=30.4 + 0.4 * i, lean=[0, -7, -10][i], head=[-2, -12, -18][i], fn=(7, 0), ff=(-6, 0),
          staff=S(4, hand=(12, -2), grip=GRIP), sway=0.5 * i)
    p["hf_rel"] = (6, 7)
    return p, {}


def exhale(i):  # (loop) breathing it out; the fire / spores are the spell's own effect
    t = TAU * i / 4
    p = P(ph=29.5, lean=15 + 2 * math.sin(t), head=8 + 2 * math.sin(t), px=1, fn=(10, 0), ff=(-8, 0),
          staff=S(-22, hand=(3, 8), grip=GRIP), sway=-3 - math.sin(t), beard=-3 - math.sin(t))
    p["hf_rel"] = (14, 3 + math.sin(t))
    return p, {}


def cast_sky(i):  # call something down from the sky: staff thrust overhead, light shoots up
    p = P(ph=kf(i, [(0, 28), (1, 31), (2, 32), (4, 31.5), (5, 30)]), lean=kf(i, [(0, 6), (1, -6), (2, -8), (4, -6), (5, 0)]),
          head=kf(i, [(0, 6), (1, -16), (2, -20), (4, -16), (5, -4)]), fn=(9, 0), ff=(-8, 0),
          staff=S(kf(i, [(0, 30), (1, 6), (2, 2), (4, 4), (5, 10)]),
                  hand=kf(i, [(0, (10, 0)), (1, (6, -16)), (2, (5, -20)), (4, (5, -19)), (5, (10, -8))]), grip=GRIP),
          sway=kf(i, [(0, 0), (2, 3), (5, 1)]))
    p["hf_rel"] = kf(i, [(0, (6, 8)), (1, (9, -12)), (2, (9, -15)), (5, (8, 6))])
    p["staff"]["glow"] = 1.5
    fx = {0: [("sparks", dict(n=4, spread=5, seed=800))], 1: [("ball", dict(r=5))],
          2: [("ball", dict(r=7)), ("sparks", dict(n=8, spread=8, seed=802, drift=(0, -6)))],
          3: [("ball", dict(r=5)), ("sparks", dict(n=10, spread=12, seed=803, drift=(0, -10)))],
          4: [("sparks", dict(n=12, spread=18, seed=804, drift=(0, 6)))], 5: []}[i]
    return p, dict(fx=fx)


def cast_ground(i):  # raise the staff and slam its butt into the ground; shockwave from the strike
    if i < 2:
        p = P(ph=30 + i, lean=-4 - 2 * i, head=-6, fn=(9, 0), ff=(-8, 0), staff=S(8, hand=(10, -14 - 4 * i), grip=GRIP),
              sway=1)
        p["hf_rel"] = (8, 4)
        return p, {}
    k = i - 2
    p = P(ph=[25, 25.5, 27, 29][k], lean=[16, 15, 11, 6][k], head=[6, 4, 2, 0][k], fn=(14, 0), ff=(-12, 0), fn_ang=2,
          sway=[-3, -2, -1, 0][k])
    p["staff"], p["hn_rel"] = plant(19, (14, [6, 5, 3, 0][k]), grip=GRIP)
    p["hf_rel"] = (8, 6)
    fx = [[("burst", dict(at="base", r=9)), ("ring", dict(at="base", rx=12, ry=3, thick=2.5))],
          [("ring", dict(at="base", rx=26, ry=5, thick=3)), ("sparks", dict(at="base", n=12, spread=14, seed=820, drift=(0, -6)))],
          [("ring", dict(at="base", rx=38, ry=6.5, thick=2)), ("sparks", dict(at="base", n=8, spread=24, seed=821, drift=(0, -10)))],
          []][k]
    return p, dict(fx=fx)


def beam(i):  # (loop) braced, staff forward, a sustained beam (Eldritch Blast, Leech's tether)
    p = P(ph=26, lean=18, head=-5, px=[0, 0.6, -0.3, 0.4][i], fn=(18, 0), ff=(-14, 0), fn_ang=2,
          staff=S(86, hand=(17, -2), grip=0.6), sway=-6, beard=-3, hat_tip=-4)
    p["hf_rel"] = (13, 3)
    p["hf_fist"] = True
    p["staff"]["glow"] = 1.6
    return p, dict(fx=[("ball", dict(r=4 + (i % 2)))])  # the beam itself is the spell's own effect


def throw(i):  # overhand throw with the free hand (Pebble, Barbs, Ignite, Frostbolt, Flaming Sphere)
    hf = [(-9, -12), (-12, -9), (16, -6), (14, 7), (10, 9), (8, 10)][i]
    p = P(ph=[29, 28.5, 27, 27, 28.5, 29.8][i], lean=[-6, -9, 16, 18, 10, 5][i], head=[-4, -6, -4, 0, 0, -1][i],
          fn=([8, 8, 15, 15, 12, 9][i], 0), ff=([-7, -8, -11, -11, -9, -7][i], 0),
          staff=S([30, 32, 46, 48, 30, 12][i], hand=([8, 6, 10, 10, 11, 13][i], [6, 7, 4, 4, 1, -3][i]), grip=GRIP),
          sway=[2, 3, -6, -7, -4, -1][i], beard=[1, 2, -3, -3, -2, 0][i])
    p["hf_rel"] = hf
    fx = [[("ball", dict(at="hand", r=2.5))], [("ball", dict(at="hand", r=3))],
          [("sparks", dict(at="hand", n=8, spread=6, seed=840, drift=(6, 0)))], [], [], []][i]
    return p, dict(fx=fx)


def _sweep_pose(u):  # u: 0 (wound up behind) .. 1 (swung through in front)
    ang = -105 + 215 * u
    p = P(ph=27.5, lean=-8 + 26 * u, head=-4, fn=(13, 0), ff=(-11, 0), fn_ang=2,
          staff=S(ang, hand=(-3 + 19 * u, 5 - 2 * math.sin(math.pi * u)), grip=0.6), sway=4 - 12 * u, beard=2 - 5 * u,
          hat_tip=3 - 8 * u)
    p["hf_rel"] = (4 + 6 * u, 8)
    p["hf_fist"] = True
    return p


def sweep(i):  # a wide horizontal swing of the staff (Thorn Whip, Scythe, Gust, Push, Tornado)
    us = [0.0, 0.12, 0.5, 0.82, 0.95, 0.7]
    p = _sweep_pose(us[i])
    p["staff"]["glow"] = 1.4
    if i in (2, 3):
        trail = [_sweep_pose(max(0.0, us[i] - 0.06 * k)) for k in range(1, 8)]
        return p, dict(fx=[("trail", dict(poses=trail))])
    if i == 5:
        p["lean"], p["sway"] = 9, -3
    return p, {}


def empower(i):  # self-buffs: draw in, then flare outward (Adrenaline, Crimson Veil, Obsidian Armor, Barrier, Sneak...)
    if i < 2:
        p = P(ph=[27, 25.5][i], lean=[14, 18][i], head=[14, 20][i], fn=(8, 0), ff=(-8, 0),
              staff=S(6, hand=(6, 4), grip=GRIP), sway=1)
        p["hf_rel"] = (6, 5)
        return p, dict(fx=[("sparks", dict(at="body", n=8 + 4 * i, spread=24 - 8 * i, seed=860 + i))])
    k = i - 2
    p = P(ph=[31.5, 31, 30.5, 30.2][k], lean=[-6, -5, -2, 2][k], head=[-14, -12, -6, -2][k], fn=(9, 0), ff=(-8, 0),
          staff=S([30, 26, 16, 6][k], hand=(14, [-8, -7, -6, -4][k]), grip=GRIP), sway=[5, 4, 2, 1][k],
          beard=[3, 2, 1, 0][k], hat_tip=[5, 4, 2, 0][k])
    p["hf_rel"] = [(-10, -8), (-10, -6), (-4, 2), (8, 10)][k]
    fx = [[("burst", dict(at="body", r=12)), ("ring", dict(at="body", rx=16, ry=22, thick=2.5))],
          [("ring", dict(at="body", rx=24, ry=30, thick=2))], [("sparks", dict(at="body", n=14, spread=26, seed=870))], []][k]
    return p, dict(fx=fx)


def clap(i):  # Thunderclap: hands brought together overhead
    hn = [(8, -13), (5, -19), (4, -21), (4, -20), (12, -5)][i]
    hf = [(-8, -13), (2, -19), (4.5, -21), (4.5, -20), (8, 8)][i]
    p = P(ph=[30.5, 31, 28, 28.5, 30][i], lean=[-4, -5, 2, 0, 3][i], head=[-10, -12, -4, -6, -1][i], fn=(9, 0),
          ff=(-8, 0), staff=S([-12, -4, 0, 0, 4][i], hand=hn, grip=0.62), sway=[1, 1, -2, 0, 0][i])
    p["hf_rel"] = hf
    fx = [[], [], [("burst", dict(at="nhand", r=11)), ("ring", dict(at="nhand", rx=14, ry=14, thick=2.5))],
          [("ring", dict(at="nhand", rx=30, ry=30, thick=2)), ("sparks", dict(at="nhand", n=12, spread=24, seed=880))], []][i]
    return p, dict(fx=fx)


def summon(i):  # hands rise palms-up; something gathers from the ground in front (Raise Dead, Decoy, Insect Plague, Mirage)
    u = min(i, 4) / 4
    p = P(ph=29 + 2 * u, lean=10 - 16 * u, head=10 - 22 * u, fn=(9, 0), ff=(-8, 0),
          staff=S(30 - 26 * u, hand=(12, 6 - 18 * u), grip=GRIP), sway=2 * u)
    p["hf_rel"] = (12, 10 - 26 * u)
    if i == 5:
        p.update(lean=0, head=-4)
        p["hf_rel"] = (10, 2)
    fx = [("rise", dict(at="abs", xy=(30, 0), n=6 + 4 * i, h=10 + 9 * i, seed=900 + i, t=i * 0.2, w=10))]
    if i == 4:
        fx.append(("ring", dict(at="abs", xy=(30, 1), rx=16, ry=4, thick=2.5)))
    return p, dict(fx=fx)


def curse(i):  # point and twist: a dark star leaves the fingertip (Hex, Hemorrhage, Faint, Fight or Flight, Silence)
    p = P(ph=[29.5, 28.5, 28.5, 29, 30][i], lean=[-4, 14, 15, 12, 4][i], head=[0, -3, -3, -2, -1][i],
          fn=([8, 14, 14, 13, 9][i], 0), ff=(-8, 0), staff=S([16, 8, 8, 10, 6][i], hand=(10, 2), grip=GRIP),
          sway=[1, -4, -4, -3, -1][i])
    p["hf_rel"] = [(-4, 4), (17, -3), (17, -2), (16, -1), (9, 8)][i]
    fx = [[], [("stars", dict(at="hand", off=(3, 0), t=0.4, n=1, rx=0, ry=0)), ("sparks", dict(at="hand", n=4, spread=4, seed=920))],
          [("burst", dict(at="hand", off=(5, 0), r=6)), ("sparks", dict(at="hand", n=8, spread=8, seed=921, drift=(6, 0)))],
          [("sparks", dict(at="hand", n=5, spread=12, seed=922, drift=(14, 0)))], []][i]
    return p, dict(fx=fx)


def _vanish_pose(k):  # k 0..4: standing -> wrapped and gone
    p = P(ph=[30, 27, 25, 24, 24][k], lean=[3, 12, 16, 18, 18][k], head=[0, 10, 16, 18, 18][k], fn=(7, 0), ff=(-6, 0),
          staff=S(4, hand=(9, 2), grip=GRIP), sway=[0, 2, 3, 3, 3][k])
    p["hf_rel"] = (8, 3)
    p["xform"] = dict(anchor=(0, 30), sy=[1, 1, 0.92, 0.8, 0.7][k], alpha=[1, 0.85, 0.55, 0.25, 0.0][k])
    p["no_gem"] = k >= 3
    fx = [("wisps", dict(at="body", n=3 + 2 * k, reach=8 + 4 * k, seed=940 + k, fwd=False)),
          ("rise", dict(at="feet", n=4 + 3 * k, h=20 + 6 * k, seed=950 + k, t=k * 0.25, w=9))] if k else []
    return p, dict(fx=fx)


def vanish(i):  # Shadow Step / Sneak: wrap up and fade away
    return _vanish_pose(i)


def appear(i):
    return _vanish_pose(4 - i)


# =========================================================== polish
def spawn(i):  # arriving out of the summoning circle
    alpha = [0, 0.3, 0.65, 1, 1, 1][i]
    p = P(ph=[24, 24, 25, 26, 28.5, 30.2][i], lean=[16, 16, 12, 10, 5, 3][i], head=[18, 18, 12, 8, 2, -1][i],
          fn=(7, 0), ff=(-6, 0), staff=S([4, 4, 4, 4, 4, 3][i], hand=(10, [2, 2, 0, -1, -3, -4][i]), grip=GRIP),
          sway=[3, 3, 2, 1, 0, 0][i])
    p["hf_rel"] = (8, 8)
    p["no_gem"] = i < 2
    if alpha < 1:
        p["xform"] = dict(alpha=alpha)
    fx = [("ring", dict(at="abs", xy=(0, 1), rx=[20, 22, 22, 18, 10, 0][i] or 1, ry=4, thick=2.5))] if i < 5 else []
    fx.append(("rise", dict(at="abs", xy=(0, 0), n=[10, 12, 10, 6, 3, 0][i], h=40, seed=960 + i, t=i * 0.3, w=12)))
    return p, dict(fx=fx)


def idle_fidget(i):  # (once, between idles) looks around, then taps the staff
    head = [-1, -10, -16, -10, 6, 2, 0, -1][i]
    hand_y = [-4, -4, -4, -4, -4, -8, -3, -4][i]
    p = idle_like(head=head, lean=[3, 2, 1, 2, 4, 3, 3, 3][i], staff=S(3, hand=(14, hand_y), grip=GRIP))
    return p, (dict(fx=[("sparks", dict(at="base", n=4, spread=5, seed=980))]) if i == 6 else {})


def turn(i):  # squeeze through the middle; the game flips the sprite at frame 1
    p = idle_like()
    p["xform"] = dict(anchor=(0, 40), sx=[0.7, 0.3, 0.7][i])
    return p, {}


def victory(i):
    p = P(ph=[26, 36, 37, 27, 30, 30.2][i], lean=[8, -4, -4, 6, 0, 0][i], head=[4, -14, -16, -4, -10, -10][i],
          fn=([7, 3, 3, 8, 7, 7][i], [0, 6, 7, 0, 0, 0][i]), ff=([-7, -4, -4, -7, -6, -6][i], [0, 8, 9, 0, 0, 0][i]),
          fn_ang=[0, -40, -40, 0, 0, 0][i], ff_ang=[0, -50, -50, 0, 0, 0][i],
          staff=S([10, 2, 0, 4, 0, 0][i], hand=([9, 6, 6, 8, 6, 6][i], [-2, -20, -21, -16, -20, -20][i]), grip=GRIP),
          sway=[2, -2, -2, 3, 0, 0][i], flap=[1, 0.8, 0.8, 1, 1, 1][i])
    p["hf_rel"] = [(6, 8), (8, -14), (8, -15), (6, -6), (6, 6), (6, 6)][i]
    p["hf_fist"] = True
    p["staff"]["glow"] = 1.6
    fx = [("sparks", dict(n=6 + 2 * i, spread=10 + 2 * i, seed=990 + i))] if i else []
    return p, dict(fx=fx)


def walk_foot(u):
    if u < 0.55:
        return (lerp_(9, -9, u / 0.55), 0.0)
    k = (u - 0.55) / 0.45
    return (lerp_(-9, 9, k), 4.5 * math.sin(math.pi * k))


def lerp_(a, b, t):
    return a + (b - a) * t


def walk(i):  # an unhurried walk, the staff swinging along like a walking stick
    u = i / 8
    n, f = walk_foot(u), walk_foot((u + 0.5) % 1)
    t = TAU * u
    p = P(ph=30 + 0.7 * abs(math.cos(t)), lean=5, head=-2, fn=n, ff=f,
          fn_ang=0 if n[1] < 0.5 else 12 * math.sin(math.pi * ((u - 0.55) / 0.45)),
          ff_ang=0 if f[1] < 0.5 else 12 * math.sin(math.pi * (((u + 0.5) % 1 - 0.55) / 0.45)),
          staff=S(10 + 8 * math.sin(t), hand=(13 + 3 * math.sin(t), -3), grip=GRIP), sway=-2 - math.sin(2 * t),
          beard=-1, hat_tip=-1 + math.sin(2 * t))
    p["hf_rel"] = (3 - 6 * math.sin(t), 12)
    p["hf_fist"] = True
    return p, {}


# name, frames, fn, fps, loop
EXTRA = [
    # movement
    ("swim", 6, swim, 8, True), ("swim_dive", 6, swim_dive, 10, True), ("swim_up", 6, swim_up, 10, True), ("swim_side", 6, swim_side, 9, True), ("climb", 6, climb, 8, True),
    ("climb_hang", 2, climb_hang, 3, True), ("float", 4, float_, 6, True), ("surf", 4, surf, 10, True),
    ("rocket", 4, rocket, 12, False), ("fly", 4, fly, 10, True), ("land", 3, land, 16, False),
    ("stuck", 6, stuck, 8, True),
    # done to the wizard
    ("frozen", 2, frozen, 4, True), ("thaw", 4, thaw, 12, False), ("pulled", 6, pulled, 10, True),
    ("sucked_in", 6, sucked_in, 12, False), ("knockback", 4, knockback, 12, True), ("get_up", 5, get_up, 10, False),
    ("dazed", 6, dazed, 8, True), ("wake", 5, wake, 6, False), ("gasping", 6, gasping, 8, True),
    ("cower", 4, cower, 10, True),
    # casting styles
    ("inhale", 3, inhale, 10, False), ("exhale", 4, exhale, 12, True), ("cast_sky", 6, cast_sky, 14, False),
    ("cast_ground", 6, cast_ground, 14, False), ("beam", 4, beam, 12, True), ("throw", 6, throw, 14, False),
    ("sweep", 6, sweep, 14, False), ("empower", 6, empower, 12, False), ("clap", 5, clap, 14, False),
    ("summon", 6, summon, 10, False), ("curse", 5, curse, 12, False), ("vanish", 5, vanish, 12, False),
    ("appear", 5, appear, 12, False),
    # polish
    ("spawn", 6, spawn, 10, False), ("idle_fidget", 8, idle_fidget, 8, False), ("turn", 3, turn, 16, False),
    ("victory", 6, victory, 10, False), ("walk", 8, walk, 10, True),
]
GROUPS = {"movement": EXTRA[0:10], "status": EXTRA[10:20], "casting": EXTRA[20:33], "polish": EXTRA[33:]}
