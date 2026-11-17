import math
from rig import *


def S(ang=0, hand=None, **kw):
    d = dict(ang=ang)
    if hand is not None:
        d["hand"] = hand
    d.update(kw)
    return d


def ease(t):
    return t * t * (3 - 2 * t)


def kf(i, keys):
    """keys: list of (frame, value) linear interpolation (values may be tuples)."""
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f0 <= i <= f1:
            t = (i - f0) / max(f1 - f0, 1e-6)
            if isinstance(v0, tuple):
                return tuple(lerp(a, b, t) for a, b in zip(v0, v1))
            return lerp(v0, v1, t)
    return keys[-1][1]


# ------------------------------------------------------------------ idle (6)
def idle(i):
    t = i / 6 * 2 * math.pi
    p = default_pose()
    br = math.sin(t)
    p.update(ph=30.2 + 0.7 * br, lean=3 + 0.8 * br, head=-1 + 0.8 * br,
             fn=(7, 0), ff=(-6, 0), fn_ang=4, ff_ang=0,
             staff=S(3, hand=(15, -5 + 0.8 * br), grip=0.5), sway=0.8 * math.sin(t - 0.8),
             book=1.2 * math.sin(t - 1.2), beard=1.2 * math.sin(t - 0.6))
    p["hf"] = (13 + 1.5 * br, 39 + 1.2 * math.sin(t + 1))
    return p, dict(motes=(t, i))


# ------------------------------------------------------------------ run (8)
def run_foot(u, A_f=18, A_b=-20, lift=13):
    if u < 0.42:
        k = u / 0.42
        return (lerp(A_f, A_b, k), 0.0)
    k = (u - 0.42) / 0.58
    return (lerp(A_b, A_f, k), lift * math.sin(math.pi * k) ** 0.8)


def run(i):
    u = i / 8
    p = default_pose()
    n = run_foot(u)
    f = run_foot((u + 0.5) % 1.0)
    bob = 2.2 * abs(math.sin(math.pi * (u * 2 + 0.15)))

    def pitch(uu):
        uu %= 1
        return -8 if uu < 0.42 else 22 * math.sin(math.pi * ((uu - 0.42) / 0.58))

    p.update(ph=28.2 + bob, lean=16, head=-8, px=-1, fn=n, ff=f, fn_ang=pitch(u), ff_ang=pitch(u + 0.5),
             staff=S(62, hand=(12, 9), grip=0.28),
             hf=(2 + 14 * math.sin(2 * math.pi * u + 0.4), 33 - 5 * abs(math.cos(2 * math.pi * u))),
             sway=-9 - 2 * math.sin(2 * math.pi * u), book=-4 * math.sin(4 * math.pi * u), beard=-6, hat_tip=-5)
    return p, {}


# ------------------------------------------------------------------ cast (8): overhead charge, then swing
def cast(i):
    p = default_pose()
    fx = []
    if i <= 2:
        k = i / 2
        p.update(ph=30 - 1 * k, lean=-3 - 5 * k, head=-4, fn=(9 + 2 * k, 0), ff=(-9 - 2 * k, 0), fn_ang=3,
                 staff=S(-52 - 18 * k, hand=(14, -8 - 7 * k), grip=0.5), sway=1 + 2 * k, book=2,
                 hf=(-5, 42 + 3 * k))
        p["staff"]["glow"] = 1.2 + 0.8 * k
        p["hf"] = (14, 47 + 3 * k)
        fx.append(("sparks", dict(at="orb", n=3 + 3 * i, spread=7 + 2 * i, seed=10 + i)))
    else:
        j = i - 3
        ang = kf(i, [(3, -10), (4, 38), (5, 58), (6, 60), (7, 48)])
        hand = kf(i, [(3, (14, -4)), (4, (15, -8)), (5, (16, -9)), (6, (16, -9)), (7, (15, -7))])
        lean = kf(i, [(3, 10), (4, 22), (5, 24), (6, 22), (7, 14)])
        ph = kf(i, [(3, 28), (4, 25), (5, 24.5), (6, 25), (7, 27)])
        p.update(ph=ph, lean=lean, head=-6, px=kf(i, [(3, 0), (4, 3), (7, 2)]),
                 fn=(kf(i, [(3, 14), (4, 19), (7, 17)]), 0), ff=(kf(i, [(3, -11), (4, -15), (7, -13)]), 0),
                 fn_ang=2, ff_ang=0, staff=S(ang, hand=hand, grip=0.5), sway=-8, book=-3, beard=-4, hat_tip=-4,
                 hf=(-4, 36))
        p["hf"] = (kf(i, [(3, 2), (4, -4), (7, -2)]), kf(i, [(3, 41), (4, 33), (7, 34)]))
        p["staff"]["glow"] = 1.4
        c = (CX + 9, GY - 54)
        if i == 3:
            fx.append(("arc", dict(c=c, r=50, a0=190, a1=255)))
        elif i == 4:
            fx.append(("arc", dict(c=c, r=54, a0=200, a1=315)))
            fx.append(("orb", dict(at="orb", r=12)))
        elif i == 5:
            fx.append(("arc", dict(c=c, r=54, a0=250, a1=345, thin=True)))
            fx.append(("orb", dict(at="orb", r=22)))
        elif i == 6:
            fx.append(("orb", dict(at="orb", r=15)))
            fx.append(("burst", dict(at="orb", r=30)))
            fx.append(("wisps", dict(at="orb", n=9, reach=30, seed=60, fwd=False)))
        elif i == 7:
            fx.append(("wisps", dict(at="orb", n=12, reach=44, seed=70, fwd=False, drift=(2, -3))))
            fx.append(("sparks", dict(at="orb", n=14, spread=34, seed=71, drift=(2, -4))))
    return p, dict(fx=fx)


# ------------------------------------------------------------------ release (8): thrust forward, bolt
def release(i):
    p = default_pose()
    fx = []
    lean = kf(i, [(0, 6), (1, 2), (2, 18), (3, 20), (5, 20), (7, 10)])
    ph = kf(i, [(0, 29), (1, 29.5), (2, 25.5), (3, 25), (5, 25), (7, 28)])
    ang = kf(i, [(0, 66), (1, 74), (2, 82), (5, 84), (7, 74)])
    hand = kf(i, [(0, (11, 0)), (1, (7, -1)), (2, (16, -2)), (5, (17, -2)), (7, (14, -2))])
    p.update(ph=ph, lean=lean, head=-5, px=kf(i, [(0, 0), (2, 3), (7, 1)]),
             fn=(kf(i, [(0, 9), (2, 18), (5, 18), (7, 12)]), 0), ff=(kf(i, [(0, -8), (2, -14), (5, -14), (7, -10)]), 0),
             fn_ang=2, staff=S(ang, hand=hand, grip=0.3), sway=kf(i, [(0, 0), (2, -8), (7, -3)]), book=-3, beard=-3,
             hat_tip=-3, hf=(-3, 37))
    p["hf"] = (kf(i, [(0, 12), (2, 15), (7, 9)]), kf(i, [(0, 40), (2, 44), (7, 38)]))
    p["staff"]["glow"] = 1.0 + 0.3 * min(i, 5)
    if i in (0, 1):
        fx.append(("sparks", dict(at="orb", n=4 + 2 * i, spread=6 + 2 * i, seed=100 + i)))
    elif i == 2:
        fx.append(("sparks", dict(at="orb", n=7, spread=9, seed=110)))
    elif i == 3:
        fx.append(("orb", dict(at="orb", r=6)))
    elif i == 4:
        fx.append(("orb", dict(at="orb", r=13)))
        fx.append(("sparks", dict(at="orb", n=8, spread=18, seed=140)))
    elif i == 5:
        fx.append(("blast", dict(at="orb", length=92)))
        fx.append(("orb", dict(at="orb", r=12)))
    elif i == 6:
        fx.append(("blast", dict(at="orb", length=52)))
        fx.append(("wisps", dict(at="orb", n=11, reach=46, seed=150, fwd=True, drift=(26, 0))))
    elif i == 7:
        fx.append(("wisps", dict(at="orb", n=12, reach=60, seed=160, fwd=True, drift=(46, -2))))
        fx.append(("sparks", dict(at="orb", n=12, spread=44, seed=161, drift=(44, -3))))
    return p, dict(fx=fx)


# ------------------------------------------------------------------ hit (4)
def hit(i):
    p = default_pose()
    lean = kf(i, [(0, -14), (1, -22), (2, -12), (3, -2)])
    p.update(ph=kf(i, [(0, 28.5), (1, 27), (2, 28.5), (3, 30)]), lean=lean, head=kf(i, [(0, -10), (1, -14), (2, -6), (3, 0)]),
             px=kf(i, [(0, -2), (1, -4), (2, -3), (3, -1)]),
             fn=(kf(i, [(0, 11), (1, 12), (3, 8)]), 0), ff=(kf(i, [(0, -9), (1, -12), (3, -7)]), 0),
             staff=S(kf(i, [(0, -16), (1, -26), (2, -8), (3, 2)]), hand=(12, -4 + (2 if i == 1 else 0)), grip=0.5),
             sway=kf(i, [(0, 6), (1, 9), (2, 3), (3, 0)]), book=4, beard=kf(i, [(0, 5), (1, 8), (2, 3), (3, 0)]),
             hat_tip=5, flash=kf(i, [(0, 0.55), (1, 0.25), (2, 0.08), (3, 0)]))
    p["hf"] = (kf(i, [(0, -6), (1, -9), (3, 8)]), kf(i, [(0, 44), (1, 46), (3, 36)]))
    return p, dict(fx=[("sparks", dict(at="head", n=6, spread=14, seed=200 + i))] if i < 2 else [])


# ------------------------------------------------------------------ death (7)
def death(i):
    p = default_pose()
    fx = []
    if i <= 2:
        p.update(ph=kf(i, [(0, 27), (1, 22), (2, 17.5)]), lean=kf(i, [(0, -16), (1, -20), (2, -6)]),
                 head=kf(i, [(0, -12), (1, -14), (2, 5)]), px=kf(i, [(0, -3), (1, -5), (2, -4)]),
                 fn=(kf(i, [(0, 11), (1, 12), (2, 15)]), kf(i, [(0, 0), (2, 0)])),
                 ff=(kf(i, [(0, -9), (1, -12), (2, -14)]), kf(i, [(0, 0), (1, 1), (2, 3)])),
                 staff=S(kf(i, [(0, 4), (1, 25), (2, 70)]), hand=(13, -6), grip=0.5),
                 sway=kf(i, [(0, 6), (1, 8), (2, 3)]), book=5, beard=5, hat_tip=6)
        p["hf"] = (-6, 44 - 8 * i)
        if i == 2:
            p["staff"] = dict(ang=0, base=(26, 3), top=(-44, 8))  # clatter to the floor
            p["hn"] = (14, 22)
            p["staff"]["glow"] = 0.6
        else:
            p["staff"]["glow"] = 0.8
    elif i == 3:   # slump to the knees
        p.update(ph=15, lean=22, head=18, px=-3, fn=(10, 0), ff=(-17, 3), fn_ang=0, ff_ang=-40,
                 staff=dict(ang=0, base=(26, 3), top=(-44, 8), glow=0.5), sway=3, book=3, beard=4, hat_tip=5)
        p["hn"] = (16, 18)
        p["hf"] = (8, 14)
    else:          # fall forward onto the ground, ending flat out
        k = {4: 0, 5: 1, 6: 2}[i]
        p.update(ph=[10.5, 7.5, 5.6][k], lean=[52, 77, 89][k], head=[10, 6, 2][k], head_rot=[48, 78, 90][k],
                 px=[-7, -11, -13][k],
                 fn=([-14, -30, -36][k], [1.5, 1, 0.5][k]), ff=([-20, -34, -40][k], [1.5, 1, 0.5][k]),
                 fn_ang=-70, ff_ang=-70, lbend=-1,
                 staff=dict(ang=0, base=(16, 2), top=(60, [4, 3.5, 3][k]), glow=[0.35, 0.2, 0.1][k]),
                 sway=[-8, -14, -17][k], flap=[0.7, 0.3, 0.15][k], nobook=(k >= 1), book=2, beard=[3, 1, 0][k], hat_tip=[6, 8, 10][k])
        p["hn"] = ([22, 26, 28][k], [8, 4.5, 3][k])
        p["hf"] = ([16, 22, 25][k], [6, 3.5, 2.5][k])
    return p, dict(fx=fx)


# ------------------------------------------------------------------ jump (2) / fall (2)
def jump(i):
    p = default_pose()
    p.update(ph=[33, 36][i], lean=[10, 4][i], head=-3, fn=(9, [4, 8][i]), ff=([-10, -6][i], [0, 3][i]), fn_ang=[-15, -25][i],
             ff_ang=[-30, -40][i],
             staff=S([44, 30][i], hand=(13, [-12, -14][i]), grip=0.45), sway=[4, 7][i], book=[4, 6][i],
             beard=[3, 5][i], hat_tip=[4, 6][i])
    p["hf"] = ([-3, 3][i], [43, 46][i])
    return p, {}


def fall(i):
    p = default_pose()
    p.update(ph=[44, 45][i], lean=[2, -2][i], head=-4, fn=(8 + i, [13, 15][i]), ff=([-8, -10][i], [9, 12][i]), fn_ang=-20,
             ff_ang=-30,
             staff=S([20, 38][i], hand=(12, [-15, -17][i]), grip=0.45), sway=[10, 12][i], book=[6, 8][i],
             beard=[8, 10][i], hat_tip=[8, 10][i])
    p["hf"] = ([-6, -2][i], [50, 53][i])
    return p, {}


ANIMS = {"idle": (idle, 6), "run": (run, 8), "cast": (cast, 8), "release": (release, 8),
         "hit": (hit, 4), "death": (death, 7), "jump": (jump, 2), "fall": (fall, 2)}
# the fall frames sit ~12px above the floor in the original; keep that.
LIFT = {"fall": 0}


def render(poseFn, i):
    cv = Canvas()
    p, extra = poseFn(i)
    info = draw_wizard(cv, p)
    orb = info["orb"]
    # effects that sit under the outline pass would get outlined; keep them plain
    for kind, kw in extra.get("fx", []):
        at = kw.get("at")
        c = orb if at == "orb" else info["hc"] if at == "head" else None
        if kind == "orb":
            fx_orb(cv, c, kw["r"], t=i * 0.7)
        elif kind == "arc":
            fx_arc(cv, kw["c"], kw["r"] + 4, kw["r"] - (4 if kw.get("thin") else 10), kw["a0"], kw["a1"])
        elif kind == "burst":
            fx_burst(cv, c, kw["r"], ang=10)
        elif kind == "sparks":
            fx_particles(cv, c, kw["n"], kw["spread"], kw["seed"], drift=kw.get("drift", (0, 0)))
        elif kind == "wisps":
            fx_wisps(cv, c, kw["n"], kw["reach"], kw["seed"], fwd=kw.get("fwd", True), drift=kw.get("drift", (0, 0)))
        elif kind == "blast":
            fx_blast(cv, c, kw["length"])
        elif kind == "bolt_old":
            ex = c[0] + kw["length"]
            for k in range(3):
                w = [7.0, 4.6, 2.2][k]
                col = [ORB[2], ORB[1], (255, 255, 255)][k]
                cv.paint(cv.capsule((c[0], c[1]), (ex - 6 * k, c[1] - 0.5), w), [col] * 4, inner_outline=False)
            fx_burst(cv, (ex, c[1]), 15, ang=0)
            fx_orb(cv, c, 6, t=i)
    if "motes" in extra:
        t, k = extra["motes"]
        hx, hy = info["hf"]
        for j in range(4):
            ph = (t * 0.5 + j * 1.7)
            fx_particles(cv, (hx + 1, hy - 8 - 6 * ((ph * 0.8 + j * 0.37) % 1.0)), 1, 2.0, seed=j * 7 + k // 2)
    cv.finish_outline()
    if p.get("flash"):
        cv.tint((255, 255, 255), p["flash"])
    return cv, p, info


def lift_fall(img, name):
    return img


if __name__ == "__main__":
    import sys
    from PIL import Image
    out = sys.argv[1]
    only = sys.argv[2:] or list(ANIMS)
    u = (66, 20, 252, 138)
    w, h = u[2] - u[0], u[3] - u[1]
    for name in only:
        fn, n = ANIMS[name]
        sheet = Image.new("RGBA", (w * n, h), (60, 60, 70, 255))
        for i in range(n):
            cv, p, _ = render(fn, i)
            im = cv.image().crop(u)
            sheet.paste(im, (i * w, 0), im)
        sheet.save(f"{out}/new_{name}.png")
