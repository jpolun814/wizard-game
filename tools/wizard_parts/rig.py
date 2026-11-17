"""Procedural pixel-art wizard rig. Renders 254x138 frames, facing right, feet on y=GY."""
import math
import numpy as np
from PIL import Image, ImageDraw

W, H = 254, 138
CX, GY = 127, 137
yy, xx = np.mgrid[0:H, 0:W]
LIGHT = np.array([-0.55, -0.83])


def hexc(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def ramp(*cols):
    return [hexc(c) for c in cols]


# hi, mid, dark, deep
ROBE = ramp("#6c9bf0", "#3f60c8", "#28368c", "#141a52")
SKIRT = ramp("#47c8b6", "#23918a", "#155a66", "#0a303c")
PANTS = ramp("#4a5cb8", "#2f3c8a", "#202860", "#0d1030")
BOOT = ramp("#6c4429", "#4b2c18", "#33190c", "#1e1006")
SKIN = ramp("#ecc3a2", "#cf9877", "#a56e56", "#6e4034")
BEARD = ramp("#f6f4f4", "#d4cecd", "#a79d9b", "#5e5460")
GOLD = ramp("#fff0a0", "#f0c35a", "#c08a30", "#7a4a18")
WOOD = ramp("#8a5a30", "#5a3418", "#3d2310", "#1e1006")
ORB = ramp("#fffbe0", "#ffc84a", "#ff8a22", "#b03a10")
BOOKC = ramp("#9a4a4a", "#74303c", "#4a1c2c", "#240c16")
STEEL = ramp("#d8d8e0", "#a8a8b4", "#76768a", "#3a3a4a")


class Canvas:
    def __init__(self):
        self.px = np.zeros((H, W, 4), np.uint8)
        self.edge = np.zeros((H, W, 3), np.uint8)
        self.glows = []

    # ---- masks -------------------------------------------------------
    @staticmethod
    def capsule(a, b, r):
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 < 1e-6:
            t = np.zeros_like(xx, float)
        else:
            t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / L2, 0, 1)
        px_, py_ = ax + t * dx, ay + t * dy
        ox, oy = xx - px_, yy - py_
        d = np.sqrt(ox * ox + oy * oy)
        m = d <= r
        s = (ox * LIGHT[0] + oy * LIGHT[1]) / max(r, 0.5)
        return m, s

    @staticmethod
    def ellipse(c, rx, ry, rot=0.0):
        cr, sr = math.cos(rot), math.sin(rot)
        ox, oy = xx - c[0], yy - c[1]
        u = (ox * cr + oy * sr) / rx
        v = (-ox * sr + oy * cr) / ry
        m = u * u + v * v <= 1.0
        s = (ox * LIGHT[0] + oy * LIGHT[1]) / max(rx, ry)
        return m, s

    @staticmethod
    def poly(pts):
        im = Image.new("L", (W, H), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        m = np.array(im) > 0
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        R = max(max(p[0] for p in pts) - min(p[0] for p in pts),
                max(p[1] for p in pts) - min(p[1] for p in pts)) / 2 + 1e-3
        s = ((xx - cx) * LIGHT[0] + (yy - cy) * LIGHT[1]) / R
        return m, s

    # ---- painting ----------------------------------------------------
    def paint(self, ms, rmp, hi=0.42, lo=-0.2, inner_outline=True, bias=0.0):
        m, s = ms
        if not m.any():
            return
        s = s + bias
        before = self.px[..., 3] > 0
        lvl = np.where(s > hi, 0, np.where(s > lo, 1, 2))
        for i in range(3):
            sel = m & (lvl == i)
            self.px[sel, :3] = rmp[i]
            self.px[sel, 3] = 255
        self.edge[m] = rmp[3]
        if inner_outline:
            er = m.copy()
            er[1:, :] &= m[:-1, :]
            er[:-1, :] &= m[1:, :]
            er[:, 1:] &= m[:, :-1]
            er[:, :-1] &= m[:, 1:]
            b = m & ~er & before
            self.px[b, :3] = rmp[3]

    def dot(self, x, y, col, a=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.px[y, x] = (*col, a)
            self.edge[y, x] = col

    def finish_outline(self):
        a = self.px[..., 3] > 0
        n = np.zeros_like(a)
        n[1:, :] |= a[:-1, :]
        n[:-1, :] |= a[1:, :]
        n[:, 1:] |= a[:, :-1]
        n[:, :-1] |= a[:, 1:]
        ring = n & ~a
        # colour from neighbours' edge colour
        e = self.edge.astype(int)
        acc = np.zeros((H, W, 3), int)
        cnt = np.zeros((H, W), int)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sa = np.roll(a, (dy, dx), (0, 1))
            se = np.roll(e, (dy, dx), (0, 1))
            acc += se * sa[..., None]
            cnt += sa
        cnt = np.maximum(cnt, 1)
        col = (acc // cnt[..., None]).astype(np.uint8)
        self.px[ring, :3] = col[ring]
        self.px[ring, 3] = 255
        self.apply_glows()

    def glow_disc(self, c, r, col, a):
        self.glows.append((c, r, col, a))

    def apply_glows(self):
        for c, r, col, a in self.glows:
            d = np.sqrt((xx - c[0]) ** 2 + (yy - c[1]) ** 2)
            m = (d <= r) & (self.px[..., 3] < a)
            self.px[m, :3] = col
            self.px[m, 3] = a

    def tint(self, col, amt):
        m = self.px[..., 3] > 0
        for i in range(3):
            ch = self.px[..., i].astype(float)
            self.px[..., i] = np.where(m, ch * (1 - amt) + col[i] * amt, ch).astype(np.uint8)

    def image(self):
        return Image.fromarray(self.px, "RGBA")


# ---------------------------------------------------------------- math
def dirv(a):  # angle from straight-down, + = forward(+x)
    r = math.radians(a)
    return (math.sin(r), math.cos(r))


def add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k)


def ik(root, target, l1, l2, bend):
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = math.hypot(dx, dy)
    d = min(max(d, abs(l1 - l2) + 0.01), l1 + l2 - 0.01)
    ux, uy = dx / (math.hypot(dx, dy) or 1), dy / (math.hypot(dx, dy) or 1)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(0, l1 * l1 - a * a))
    mid = (root[0] + ux * a, root[1] + uy * a)
    knee = (mid[0] - uy * h * bend, mid[1] + ux * h * bend)
    end = (root[0] + ux * d, root[1] + uy * d)
    return knee, end


def lerp(a, b, t):
    return a + (b - a) * t


# ---------------------------------------------------------------- the wizard
LEG1, LEG2 = 15.2, 15.2
PH_ADJ = 1.6
FOOT = 5.0
ARM1, ARM2 = 11.0, 11.0


def default_pose():
    return dict(
        px=0.0, ph=28.5, lean=4.0, head=0.0,           # pelvis offset x, height above ground, torso lean, head tilt
        fn=(4, 0), ff=(-4, 0),                          # near/far foot targets (x rel CX, height above ground)
        fn_ang=0.0, ff_ang=0.0,                         # foot pitch (deg, + = toes up)
        hn=None, hf=None,                               # hand targets, world offsets rel. CX,GY (x, height)
        staff=None,                                     # dict(base=(x,h), ang=deg, grip=0.45) or dict(hand='near',ang=..)
        sway=0.0, book=0.0, beard=0.0, flash=0.0,
        fx=None, hat_tip=0.0, lying=False,
    )


def staff_ends(p, hand_pos):
    st = p["staff"]
    if "base" in st:
        return (CX + st["base"][0], GY - st["base"][1]), (CX + st["top"][0], GY - st["top"][1])
    ang = st["ang"]
    L = st.get("len", 84)
    g = st.get("grip", 0.42)
    d = (math.sin(math.radians(ang)), -math.cos(math.radians(ang)))  # up direction
    base = (hand_pos[0] - d[0] * L * g, hand_pos[1] - d[1] * L * g)
    top = (base[0] + d[0] * L, base[1] + d[1] * L)
    return base, top


def draw_wizard(cv, p):
    P = (CX + p["px"], GY - p["ph"] - PH_ADJ)
    lean = p["lean"]
    up = (math.sin(math.radians(lean)), -math.cos(math.radians(lean)))
    fwd = (math.cos(math.radians(lean)), math.sin(math.radians(lean)))
    waist = add(P, up, 3)
    chest = add(P, up, 18)
    neck = add(chest, up, 3)
    hc = add(neck, (math.sin(math.radians(lean + p["head"])), -math.cos(math.radians(lean + p["head"]))), 7.5)
    sh_n = add(chest, fwd, 0.0)
    sh_f = add(chest, fwd, -0.5)

    def wpt(t):  # (x rel CX, height above ground) -> world px
        return (CX + t[0], GY - t[1])

    # ---- legs (IK) ----
    hip = add(P, up, -1)
    lb = p.get("lbend", -1)
    kn_n, an_n = ik(hip, wpt((p["fn"][0], p["fn"][1] + FOOT)), LEG1, LEG2, lb)
    kn_f, an_f = ik(hip, wpt((p["ff"][0], p["ff"][1] + FOOT)), LEG1, LEG2, lb)

    # ---- arms ----
    hn = wpt(p["hn"]) if p["hn"] else add(sh_n, (12, 8))
    hf = wpt(p["hf"]) if p["hf"] else add(sh_f, (10, 12))
    st = p["staff"]
    sbase = stop = None
    if st:
        if "base" in st:
            pass
        elif "hand" in st:
            hn = add(sh_n, st["hand"])
            hn_ = hn
        else:
            hn_ = hn
        sbase, stop = staff_ends(p, hn)
    el_n, hn = ik(sh_n, hn, ARM1, ARM2, 1)
    el_f, hf = ik(sh_f, hf, ARM1, ARM2, 1)

    def leg(kn, an, ang):
        cv.paint(cv.capsule(hip, kn, 3.9), PANTS)
        cv.paint(cv.capsule(kn, an, 3.3), PANTS)
        # boot: from ~45% down the shin to ankle, plus foot
        bt = add(kn, (an[0] - kn[0], an[1] - kn[1]), 0.5)
        cv.paint(cv.capsule(bt, an, 3.6), BOOT)
        fa = math.radians(ang)
        toe = (an[0] + 8.5 * math.cos(fa), an[1] + 2.3 - 8.5 * math.sin(fa))
        heel = (an[0] - 1.5, an[1] + 2.3)
        cv.paint(cv.capsule(heel, toe, 2.4), BOOT)

    def arm(sh, el, hd, front):
        cv.paint(cv.capsule(sh, el, 3.2), ROBE)
        cv.paint(cv.capsule(el, hd, 2.9), ROBE)
        cuff0 = add(hd, (el[0] - hd[0], el[1] - hd[1]), 0.22)
        cv.paint(cv.capsule(cuff0, add(hd, (el[0] - hd[0], el[1] - hd[1]), 0.12), 3.1), GOLD, inner_outline=True)
        cv.paint(cv.ellipse(hd, 2.1, 2.1), SKIN, inner_outline=False)

    def staff_draw(front_hand):
        if not st:
            return
        a, b = sbase, stop
        cv.paint(cv.capsule(a, b, 1.35), WOOD, hi=0.5, lo=-0.1)
        # head claw
        d = (b[0] - a[0], b[1] - a[1])
        n = math.hypot(*d) or 1
        d = (d[0] / n, d[1] / n)
        perp = (-d[1], d[0])
        c0 = add(b, d, -5)
        cv.paint(cv.capsule(add(c0, perp, 1.0), add(b, perp, 3.2), 1.1), WOOD)
        cv.paint(cv.capsule(add(c0, perp, -1.0), add(b, perp, -3.2), 1.1), WOOD)
        oc = add(b, d, 1.5)
        glow = st.get("glow", 1.0)
        if glow > 0:
            cv.glow_disc(oc, 6.2 * glow, ORB[1], 28)
            cv.glow_disc(oc, 4.8 * glow, ORB[1], 60)
        cv.paint(cv.ellipse(oc, 3.5, 3.5), ORB, hi=0.35, lo=-0.25)
        cv.dot(oc[0] - 1, oc[1] - 1, ORB[0])
        return oc

    # ================= draw order =================
    # far arm, far leg
    arm(sh_f, el_f, hf, False)
    leg(kn_f, an_f, p["ff_ang"])

    # back skirt flap
    sw = p["sway"]
    fl = p.get("flap", 1.0)
    ft = add(waist, fwd, -4.8)
    f2 = add(waist, fwd, 1.0)
    b1 = (P[0] - 11 + sw * 1.0, P[1] + 15.5 * fl - abs(sw) * 0.1 * fl)
    b2 = (P[0] - 1 + sw * 0.5, P[1] + 16.5 * fl)
    cv.paint(cv.poly([ft, f2, b2, b1]), SKIRT, hi=0.5, lo=-0.1)
    cv.paint(cv.capsule(b1, b2, 1.0), GOLD, inner_outline=False)

    # book hanging at the back of the belt
    nobook = p.get("nobook", False)
    if not nobook:
        bk0 = add(add(P, fwd, -9), up, -6)
        bk = (bk0[0] + p["book"] * 0.6, bk0[1] + abs(p["book"]) * 0.2)
        cv.paint(cv.poly([(bk[0] - 4, bk[1] - 5), (bk[0] + 3, bk[1] - 5), (bk[0] + 3 + p["book"] * 0.3, bk[1] + 5),
                          (bk[0] - 4 + p["book"] * 0.3, bk[1] + 5)]), BOOKC)
        cv.dot(bk[0] + 2, bk[1], BEARD[1])
        cv.dot(bk[0] + 2, bk[1] - 2, BEARD[1])
        cv.dot(bk[0] + 2, bk[1] + 2, BEARD[1])

    # torso
    cv.paint(cv.capsule(waist, chest, 5.0), ROBE, hi=0.45, lo=-0.1)
    # shoulder mantle
    cv.paint(cv.capsule(add(chest, fwd, -2.8), add(chest, fwd, 3.0), 3.6), ROBE, hi=0.45, lo=-0.1, inner_outline=False)
    # gold trim down the front of the robe
    cv.paint(cv.capsule(add(chest, fwd, 3.6), add(waist, fwd, 4.0), 0.8), GOLD, inner_outline=False)
    # collar
    cv.paint(cv.capsule(add(neck, fwd, -2.6), add(neck, fwd, 3.0), 2.1), GOLD, inner_outline=False)

    # near leg
    leg(kn_n, an_n, p["fn_ang"])

    # front skirt flap
    t1 = add(waist, fwd, -1.0)
    t2 = add(waist, fwd, 5.2)
    f1 = (P[0] + 2 + sw * 0.4, P[1] + 17 * fl)
    f2_ = (P[0] + 11 + sw * 1.0, P[1] + 14.5 * fl - abs(sw) * 0.1 * fl)
    cv.paint(cv.poly([t1, t2, f2_, f1]), SKIRT, hi=0.5, lo=-0.1)
    cv.paint(cv.capsule(f1, f2_, 1.0), GOLD, inner_outline=False)

    # belt
    bw = add(P, up, 4.2)
    q = [add(add(bw, fwd, -5.8), up, -1.6), add(add(bw, fwd, 5.8), up, -1.6),
         add(add(bw, fwd, 5.8), up, 1.6), add(add(bw, fwd, -5.8), up, 1.6)]
    cv.paint(cv.poly(q), WOOD, inner_outline=False)
    bx = add(bw, fwd, 4.4)
    cv.paint(cv.capsule(add(bx, up, -1.4), add(bx, up, 1.4), 1.5), GOLD, inner_outline=False)

    # ---- head (everything rotates about the head centre) ----
    hx, hy = hc
    hrot = p.get("head_rot", p["head"] * 0.6 + lean * 0.25)
    hc_, hs_ = math.cos(math.radians(hrot)), math.sin(math.radians(hrot))

    def R(pt):
        dx, dy = pt[0] - hx, pt[1] - hy
        return (hx + dx * hc_ - dy * hs_, hy + dx * hs_ + dy * hc_)

    def RP(pts):
        return [R(q) for q in pts]

    bs = p["beard"]
    # hair at the back
    cv.paint(cv.poly(RP([(hx - 7, hy - 4.5), (hx - 3, hy - 5.5), (hx - 3.5, hy + 5), (hx - 9, hy + 8 + bs * 0.3)])), BEARD)
    cv.paint(cv.ellipse(R((hx, hy)), 5.3, 6.3, math.radians(hrot)), SKIN)
    cv.paint(cv.ellipse(R((hx + 5.3, hy + 0.8)), 1.8, 1.6), SKIN, inner_outline=False)   # nose
    for q, col in (((hx + 2.6, hy - 1.4), SKIN[3]), ((hx + 3.6, hy - 1.4), SKIN[3]),
                   ((hx + 2.6, hy - 3.3), BEARD[2]), ((hx + 3.6, hy - 3.3), BEARD[2]), ((hx + 4.6, hy - 2.8), BEARD[2])):
        r = R(q)
        cv.dot(r[0], r[1], col)
    # beard + moustache
    cv.paint(cv.poly(RP([(hx - 3.5, hy + 1), (hx + 2.6, hy + 2.2), (hx + 6.4, hy + 3.6), (hx + 6.4, hy + 6),
                         (hx + 3.5 + bs, hy + 15), (hx - 1 + bs * 0.6, hy + 12.5), (hx - 4, hy + 7)])), BEARD, hi=0.35, lo=-0.1)
    cv.paint(cv.capsule(R((hx + 2.8, hy + 2.8)), R((hx + 7, hy + 3.9)), 1.2), BEARD, inner_outline=False)

    # ---- hat ----
    bcx, bcy = hx - 1.0, hy - 6.4
    cv.paint(cv.ellipse(R((bcx, bcy)), 11.5, 3.1, math.radians(-6 + hrot)), ROBE, hi=0.55, lo=-0.2)
    tip_x = -11 + p["hat_tip"]
    pts_l, pts_r = [], []
    N = 14
    for i in range(N + 1):
        t = i / N
        sx = bcx + (tip_x * t * t) - 1.0 * t
        sy = bcy - 2 - 15 * t
        w = 7.6 * (1 - t) ** 0.95
        pts_l.append((sx - w, sy))
        pts_r.append((sx + w, sy))
    cv.paint(cv.poly(RP(pts_l + pts_r[::-1])), ROBE, hi=0.4, lo=-0.12)
    cv.paint(cv.capsule(R((bcx - 7.0, bcy - 2.2)), R((bcx + 7.0, bcy - 2.4)), 1.5), GOLD, inner_outline=False)
    for q, col in (((-2.5, -9.5), GOLD[0]), ((-2.5, -10.5), GOLD[1]), ((-2.5, -8.5), GOLD[1]),
                   ((-3.5, -9.5), GOLD[1]), ((-1.5, -9.5), GOLD[1])):
        r = R((bcx + q[0], bcy + q[1]))
        cv.dot(r[0], r[1], col)

    # ---- staff, near arm ----
    staff_draw(True)
    arm(sh_n, el_n, hn, True)
    orb_c = None
    if st:
        orb_c = add(stop, (0, 0), 0)
    return dict(P=P, hc=hc, hn=hn, hf=hf, staff_top=stop, staff_base=sbase, orb=orb_c)


# ---------------------------------------------------------------- effects
def _inside(cv, c, r):
    return cv.ellipse(c, r, r)[0]


def fx_orb(cv, c, r, t=0.0):
    """White-hot sphere with amber swirl cut-outs (like the original's big spell orbs)."""
    cv.glow_disc(c, r + 5, ORB[1], 40)
    cv.glow_disc(c, r + 2.5, ORB[0], 110)
    sph = ramp("#ffffff", "#fff6d8", "#ffe29a", "#ff9a30")
    cv.paint(cv.ellipse(c, r, r), sph, hi=0.15, lo=-0.5, inner_outline=False)
    inside = _inside(cv, c, r - 0.5)
    sw_cols = [(255, 190, 70), (255, 150, 40), (255, 215, 120)]
    for k in range(3):
        a = t + k * 2.1
        oc = (c[0] + math.cos(a) * r * 0.35, c[1] + math.sin(a) * r * 0.35)
        m1 = cv.ellipse(oc, r * 0.72, r * 0.5, a)[0]
        m2 = cv.ellipse((oc[0] + math.cos(a + 1.2) * r * 0.22, oc[1] + math.sin(a + 1.2) * r * 0.22), r * 0.66, r * 0.42, a)[0]
        m = m1 & ~m2 & inside
        cv.px[m, :3] = sw_cols[k]
        cv.px[m, 3] = 255
    cv.edge[inside] = ORB[3]


def fx_arc(cv, c, r_out, r_in, a0, a1, col_o=ORB[2], col_i=(255, 255, 255)):
    """Big crescent slash: fat in the middle, tapering to points."""
    n = 28
    outer, inner = [], []
    for i in range(n + 1):
        a = math.radians(lerp(a0, a1, i / n))
        k = math.sin(math.pi * i / n) ** 0.7
        ro = r_in + (r_out - r_in) * k
        outer.append((c[0] + math.cos(a) * ro, c[1] + math.sin(a) * ro))
        inner.append((c[0] + math.cos(a) * r_in, c[1] + math.sin(a) * r_in))
    m, _ = cv.poly(outer + inner[::-1])
    cv.px[m, :3] = col_o
    cv.px[m, 3] = 255
    core = []
    for i in range(n + 1):
        a = math.radians(lerp(a0, a1, i / n))
        k = math.sin(math.pi * i / n) ** 0.7
        core.append((c[0] + math.cos(a) * (r_in + (r_out - r_in) * 0.7 * k), c[1] + math.sin(a) * (r_in + (r_out - r_in) * 0.7 * k)))
    m2, _ = cv.poly(core + inner[::-1])
    cv.px[m2, :3] = col_i
    cv.px[m2, 3] = 255


def fx_particles(cv, c, n, spread, seed, fade=1.0, drift=(0, 0)):
    rnd = np.random.RandomState(seed)
    cols = [ORB[0], ORB[1], ORB[2], (255, 255, 255)]
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(0.2, 1.0) * spread
        x = c[0] + math.cos(a) * d * 1.3 + drift[0]
        y = c[1] + math.sin(a) * d * 0.8 + drift[1]
        col = cols[rnd.randint(0, len(cols))]
        if rnd.rand() < fade:
            cv.dot(x, y, col)
            if rnd.rand() < 0.35:
                cv.dot(x + 1, y, col)


def fx_wisps(cv, c, n, reach, seed, fwd=1.0, thick=1.6, drift=(0, 0)):
    """Curling energy wisps drifting away from c (the dissipating-spell look)."""
    rnd = np.random.RandomState(seed)
    cols = [(255, 214, 120), (255, 170, 60), (255, 255, 255), (255, 140, 40)]
    for k in range(n):
        a0 = rnd.uniform(-1.2, 1.2) if fwd else rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(0.35, 1.0) * reach
        curl = rnd.choice([-1, 1]) * rnd.uniform(0.8, 1.8)
        col = cols[rnd.randint(0, len(cols))]
        L = rnd.uniform(0.25, 0.5) * reach
        steps = 8
        pts = []
        for s in range(steps + 1):
            t = s / steps
            ang = a0 + curl * t
            rr = dist + L * t
            pts.append((c[0] + math.cos(ang) * rr * 1.0 + drift[0], c[1] + math.sin(ang) * rr * 0.75 + drift[1]))
        for s in range(steps):
            w = thick * (1 - s / steps) + 0.3
            m, _ = cv.capsule(pts[s], pts[s + 1], w)
            cv.px[m, :3] = col
            cv.px[m, 3] = 255


def fx_burst(cv, c, r, ang=0.0):
    pts = []
    n = 10
    for i in range(n * 2):
        a = math.radians(ang + i * 180 / n)
        rr = r * (1.0 if i % 4 == 0 else 0.8 if i % 2 == 0 else 0.34)
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr * 0.85))
    m, _ = cv.poly(pts)
    cv.px[m, :3] = ORB[2]
    cv.px[m, 3] = 255
    m1, _ = cv.poly([(c[0] + (x - c[0]) * 0.8, c[1] + (y - c[1]) * 0.8) for x, y in pts])
    cv.px[m1, :3] = ORB[1]
    cv.px[m1, 3] = 255
    m2, _ = cv.poly([(c[0] + (x - c[0]) * 0.55, c[1] + (y - c[1]) * 0.55) for x, y in pts])
    cv.px[m2, :3] = (255, 255, 255)
    cv.px[m2, 3] = 255


def fx_blast(cv, c, length, spread=34):
    """Big spiky forward blast (white core, amber edge), like the original's release burst."""
    spikes = [(-spread, 0.55), (-24, 0.8), (-12, 0.95), (0, 1.0), (12, 0.92), (24, 0.75), (spread, 0.5)]
    pts = [(c[0], c[1] - 9)]
    for i, (a, k) in enumerate(spikes):
        ar = math.radians(a)
        pts.append((c[0] + math.cos(ar) * length * k, c[1] + math.sin(ar) * length * k * 0.55))
        mid = math.radians(a + (6 if i < len(spikes) - 1 else 0))
        pts.append((c[0] + math.cos(mid) * length * 0.38, c[1] + math.sin(mid) * length * 0.38 * 0.55))
    pts.append((c[0], c[1] + 9))
    for sc, col in ((1.0, ORB[2]), (0.82, ORB[1]), (0.58, (255, 255, 255))):
        m, _ = cv.poly([(c[0] + (x - c[0]) * sc, c[1] + (y - c[1]) * sc) for x, y in pts])
        cv.px[m, :3] = col
        cv.px[m, 3] = 255
