"""Modular wizard parts. Every part is drawn on its own layer, on the same 254x138 frame, so any combination of
parts stacks (in SLOTS order) into a complete character. Built on the rig in rig.py (same folder). How to use all of this: docs/handoff/20_making_wizard_parts.md.

Spell colour is NOT baked in: the last slot, "magic" (weapon gem + glow + spell effects), is drawn in key greys
(see KEY) that the game maps to the colours of whatever spell is being cast (recolor() here; magic_ramp.gdshader in Godot)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rig import Canvas, ramp, add, ik, CX, GY, W, H, LEG1, LEG2, FOOT, PH_ADJ, ARM1, ARM2, GOLD, BOOT  # noqa: E402
import numpy as np  # noqa: E402

# ============================================================== palettes
SKINS = {
    "pale": ramp("#fbe6da", "#f0cdbc", "#c99c8c", "#7c5652"),
    "fair": ramp("#f0d0b4", "#d8aa8a", "#aa7c62", "#684434"),
    "light": ramp("#e6bf98", "#c99870", "#9a6c4c", "#5e3a28"),
    "olive": ramp("#d0a870", "#a88050", "#7c5c38", "#4a321e"),
    "tan": ramp("#c48a58", "#9c6438", "#6e4224", "#3c2010"),
    "bronze": ramp("#a8703e", "#80502a", "#5a361c", "#301a0e"),
    "brown": ramp("#8a5632", "#663a22", "#46261a", "#26120c"),
    "deep": ramp("#6e4228", "#4c2c1c", "#32190f", "#180a06"),
    "ebony": ramp("#503022", "#36201a", "#22120e", "#0c0504"),
    "orc": ramp("#8ea45a", "#667e3e", "#44582a", "#222e14"),
    "zombie": ramp("#a8b090", "#7c8a6c", "#56624c", "#2a3226"),
    "duergar": ramp("#a4a0b4", "#78748c", "#524e66", "#2a2838"),
    "vampire": ramp("#e6ecf4", "#bcc6da", "#8a94b2", "#464c66"),
    "frostborn": ramp("#bcdcf0", "#86b2d6", "#5a82ac", "#2a4064"),
    "infernal": ramp("#d0584a", "#a03a38", "#6e2230", "#3a0e1a"),
    "spectral": ramp("#b8fff0", "#6ee0d0", "#38a0b0", "#186070"),
    "bone": ramp("#fffdf6", "#f1ecde", "#c4bca4", "#726a52"),
}
HAIRS = {
    "white": ramp("#f6f4f4", "#d4cecd", "#a79d9b", "#5e5460"),
    "silver": ramp("#e8ecf4", "#b8c0d0", "#808aa0", "#444c60"),
    "gray": ramp("#b4b4be", "#86848f", "#5c5a68", "#2e2c3a"),
    "blonde": ramp("#f4e0a0", "#d8b868", "#a8843c", "#5e4218"),
    "ginger": ramp("#f09a58", "#cc6a2e", "#8e4018", "#4a1e0a"),
    "auburn": ramp("#c8603c", "#9a3e26", "#682414", "#340e08"),
    "chestnut": ramp("#a4684c", "#7a4630", "#52291c", "#26120c"),
    "brown": ramp("#8a6444", "#624430", "#3e2a1e", "#1c1210"),
    "black": ramp("#4a4a5c", "#30303c", "#1e1e28", "#0a0a10"),
    "midnight": ramp("#5a6aa8", "#38447c", "#222a54", "#0c1030"),
    "crimson": ramp("#e8505c", "#b02a3a", "#781622", "#3a0810"),
    "ember": ramp("#ffd070", "#ff8a30", "#d04a18", "#701808"),
    "gold": ramp("#fff0a0", "#f0c040", "#b8861c", "#6a4a0c"),
    "emerald": ramp("#78e8a0", "#34b070", "#1c7048", "#0a3a26"),
    "aqua": ramp("#c0fff4", "#60e8d8", "#2ea8b8", "#126078"),
    "frost": ramp("#f0fbff", "#c4e8f8", "#88bcdc", "#4a7298"),
    "violet": ramp("#d4a8ff", "#9a68e0", "#683ab0", "#341864"),
}
SILVER = ramp("#f0f0f8", "#b8b8c8", "#7a7a90", "#3a3a4a")
COLORS = {  # the cloth, and the trim it comes with by default (the maker chooses another: see TRIMS)
    "blue": dict(main=ramp("#6c9bf0", "#3f60c8", "#28368c", "#141a52"), trim=GOLD),
    "purple": dict(main=ramp("#b48ce0", "#7e58b6", "#533884", "#2b1c4a"), trim=GOLD),
    "crimson": dict(main=ramp("#e8706a", "#b83a46", "#7a2232", "#40101c"), trim=GOLD),
    "emerald": dict(main=ramp("#62cc8a", "#2e9a64", "#1c6448", "#0c3228"), trim=GOLD),
    "charcoal": dict(main=ramp("#72728a", "#4a4a60", "#2e2e40", "#16161f"), trim=SILVER),
    "ivory": dict(main=ramp("#f6f2e6", "#d6cdb4", "#a69a80", "#5a5040"), trim=GOLD),
    "black": dict(main=ramp("#5a5a6a", "#34343f", "#1e1e28", "#0a0a10"), trim=SILVER),
    "gold": dict(main=ramp("#f6dc7a", "#d6a83a", "#9a6e22", "#583a0c"), trim=ramp("#f0f0f8", "#c8c8d6", "#8a8aa0", "#46465a")),
    "teal": dict(main=ramp("#6ad8d0", "#2a9ca0", "#1a6470", "#0a3040"), trim=GOLD),
    "rose": dict(main=ramp("#f4a0b8", "#d0607e", "#9a3c58", "#561c34"), trim=GOLD),
    "lavender": dict(main=ramp("#d6c4f4", "#a688d6", "#7058a6", "#3a2a62"), trim=SILVER),
    "rust": dict(main=ramp("#e8905a", "#b85a2c", "#7e3818", "#401a08"), trim=GOLD),
}
BOOTS = {  # "bare" is the foot itself, in the skin
    "brown": BOOT,
    "black": ramp("#4a4a56", "#2c2c36", "#1a1a22", "#0a0a10"),
    "tan": ramp("#c8985c", "#a06e3c", "#704824", "#3a2410"),
    "gray": ramp("#9a9aa8", "#6e6e7c", "#48485a", "#22222c"),
    "red": ramp("#b8505a", "#8a2e3a", "#5a1824", "#2e0a10"),
    "green": ramp("#6a8a58", "#466a3c", "#2c4628", "#14240f"),
}
WOODS = {
    "oak": ramp("#8a5a30", "#5a3418", "#3d2310", "#1e1006"),
    "dark": ramp("#6a4a3a", "#4a3024", "#2e1c14", "#160c08"),
    "pale": ramp("#b88a58", "#8a6038", "#5e3e22", "#2c1a0c"),
}
RUBY = ramp("#ff8c98", "#d03450", "#8a1832", "#40081a")
ROSE = ramp("#ffd0dc", "#ee7a9a", "#b8426a", "#6a1c3c")
BONE = ramp("#f4ecd4", "#d0c3a0", "#9a8c6a", "#544a34")
IRON = ramp("#9a9aac", "#6a6a7e", "#46465a", "#22222e")
LEAF = ramp("#8ad06a", "#5aa040", "#3a7028", "#1c3a14")
LEATHER = ramp("#a0704a", "#74482c", "#4e2e1a", "#26140a")
SAPPHIRE = ramp("#d8f0ff", "#7ab8ff", "#3a6ae0", "#18246a")

# the magic layer's key greys: near-white, light, mid, deep (+ pure white stays white)
KEY = [(236, 236, 236), (190, 190, 190), (128, 128, 128), (70, 70, 70)]
WHITE = (255, 255, 255)
SCHOOL_COLORS = {  # copied from wizard-game scripts/core/spell_data.gd SCHOOL_COLORS: the game's 7 schools
    "Fire": "#ff6a2a", "Water": "#7fd8ff", "Air": "#d8e4ee", "Earth": "#b8864a",
    "Flora": "#6fcf6a", "Shadow": "#7a5aa0", "Blood": "#c4162f",
}


def school_ramp(hex_color):
    """The 4 magic colours made from one school colour - the SAME formula the game must use (see the integration handoff):
    near_white = 75% toward white, light = 35% toward white, mid = the colour, deep = the colour darkened by half."""
    c = ramp(hex_color)[0]
    mix = lambda k: tuple(int(round(c[i] + (255 - c[i]) * k)) for i in range(3))
    return [mix(0.75), mix(0.35), c, tuple(int(round(v * 0.5)) for v in c)]


SPELLS = {name: school_ramp(col) for name, col in SCHOOL_COLORS.items()}

# The order here is the order the character creator shows: plainest first, the fantastical last; colors run round the wheel and then the neutrals.
OPTIONS = {
    "skin": ["pale", "fair", "light", "olive", "tan", "bronze", "brown", "deep", "ebony", "orc", "zombie", "duergar", "vampire", "frostborn", "infernal", "spectral", "bone"],
    "outfit": ["rags", "tunic", "coat", "robe", "cloak", "gown", "bodice", "ceremonial", "gothic", "armored", "vest", "pelt", "sash", "toga"],
    "color": ["crimson", "rust", "gold", "emerald", "teal", "blue", "purple", "lavender", "rose", "ivory", "charcoal", "black"],
    "trim": ["crimson", "rust", "gold", "emerald", "teal", "blue", "purple", "lavender", "rose", "ivory", "charcoal", "black"],
    "hair": ["none", "balding", "tonsure", "short", "bob", "straight", "long", "wavy", "ponytail", "pigtails", "braids", "bun", "updo", "mohawk", "wild"],
    "hair_color": ["white", "silver", "gray", "blonde", "ginger", "auburn", "chestnut", "brown", "black", "midnight", "crimson", "ember", "gold", "emerald", "aqua", "frost", "violet"],
    "beard": ["none", "stubble", "goatee", "handlebar", "short", "long"],
    "beard_color": ["white", "silver", "gray", "blonde", "ginger", "auburn", "chestnut", "brown", "black", "midnight", "crimson", "ember", "gold", "emerald", "aqua", "frost", "violet"],
    "hat": ["none", "hood", "headscarf", "turban", "pointy", "wide", "mushroom", "circlet", "tiara", "crown", "laurel", "flower_crown", "horned", "skull"],
    "hat_color": ["crimson", "rust", "gold", "emerald", "teal", "blue", "purple", "lavender", "rose", "ivory", "charcoal", "black"],
    "boots": ["brown", "black", "tan", "gray", "red", "green", "bare"],
    "weapon": ["wand", "rose_wand", "bone_wand", "scepter", "crook", "book", "orb_hand", "staff_branch", "staff_root", "staff_flower", "staff_orb",
               "staff_crystal", "staff_moon", "staff_lantern", "staff_skull"],
}
TRIMS = {name: COLORS[name]["main"] for name in COLORS}  # an outfit can be edged in any of the colors it can be made in
assert all(set(OPTIONS[k]) == set(v) for k, v in {"skin": SKINS, "color": COLORS, "trim": TRIMS, "hair_color": HAIRS, "hat_color": COLORS}.items())
HAT_NO_COLOR = ("none", "circlet", "horned", "skull", "laurel", "crown", "tiara", "flower_crown")  # hats that have no color of their own to choose
HAT_TRIMMED = ("circlet", "tiara", "crown", "horned", "headscarf", "pointy", "wide")  # hats with metal or a band that takes the trim's color
CAP_HAIR = ("short", "long", "ponytail", "bun", "braids", "straight", "wild", "bob", "pigtails", "wavy", "updo")  # styles that draw the cap of hair over the head
BACK_COAT = ("coat", "cloak", "gothic")  # outfits with a piece behind the legs
SLEEVELESS = ("vest", "pelt", "sash", "toga")  # outfits that leave the chest and the arms bare, in the skin
BARE_LEGS = ("pelt", "toga")  # and these leave the legs bare too
NO_SKIRT = ("vest", "sash")  # worn over trousers, with nothing hanging in front of them
TRIM_SLOTS = ("far_cuff", "near_cuff", "back_trim", "body_trim", "hat_trim")  # layers made only of what is in the trim's color, so the trim can be chosen apart from the cloth
BODY_SLOTS = ("far_sleeve", "near_sleeve", "back_coat", "torso", "front_coat", "belt", "hat")  # the cloth layers, drawn without it

# z-order, back to front. Each slot's look depends only on the listed options (and variant_key says which choices share a file).
SLOTS = [
    ("far_sleeve", ["outfit", "color"]),
    ("far_arm", ["outfit", "skin"]),
    ("far_cuff", ["outfit", "trim"]),
    ("far_hand", ["skin"]),
    ("far_leg", ["outfit", "trim"]),
    ("far_bare_leg", ["outfit", "skin"]),
    ("far_boot", ["boots", "skin"]),
    ("back_coat", ["outfit", "color"]),
    ("back_trim", ["outfit", "trim"]),
    ("torso_skin", ["outfit", "skin"]),
    ("torso", ["outfit", "color"]),
    ("near_leg", ["outfit", "trim"]),
    ("near_bare_leg", ["outfit", "skin"]),
    ("near_boot", ["boots", "skin"]),
    ("front_coat", ["outfit", "color"]),
    ("belt", ["outfit", "color"]),
    ("body_trim", ["outfit", "trim"]),
    ("hair_back", ["hair", "hair_color"]),
    ("head", ["skin"]),
    ("beard", ["beard", "beard_color"]),
    ("hair_front", ["hair", "hair_color"]),
    ("hat", ["hat", "hat_color"]),
    ("hat_trim", ["hat", "trim"]),
    ("weapon", ["weapon"]),
    ("near_sleeve", ["outfit", "color"]),
    ("near_arm", ["outfit", "skin"]),
    ("near_cuff", ["outfit", "trim"]),
    ("near_hand", ["skin"]),
    ("magic", ["weapon"]),  # key greys: recolour per spell at runtime
]


def variant_key(slot, cfg):
    """The file a choice of options is drawn in, or None when the slot is empty for it. Choices that draw the same picture share one file
    (the build writes an `alias` table into the manifest for the game to find it by)."""
    o = cfg["outfit"]
    if slot in ("far_sleeve", "near_sleeve"):
        return None if o in SLEEVELESS else cfg["color"]
    if slot in ("far_arm", "near_arm"):
        return cfg["skin"] if o in SLEEVELESS else None
    if slot in ("far_cuff", "near_cuff"):
        return None if o in SLEEVELESS else cfg["trim"]
    if slot in ("far_leg", "near_leg"):
        return None if o in BARE_LEGS else cfg["trim"]
    if slot in ("far_bare_leg", "near_bare_leg"):
        return cfg["skin"] if o in BARE_LEGS else None
    if slot in ("far_boot", "near_boot"):
        return "bare-" + cfg["skin"] if cfg["boots"] == "bare" else cfg["boots"]
    if slot in ("back_coat", "back_trim"):
        return o + "-" + cfg["color" if slot == "back_coat" else "trim"] if o in BACK_COAT else None
    if slot == "torso_skin":
        return o + "-" + cfg["skin"] if o in SLEEVELESS else None
    if slot == "front_coat" and o in NO_SKIRT:
        return None
    if slot == "hat":
        if cfg["hat"] == "none":
            return None
        return cfg["hat"] if cfg["hat"] in HAT_NO_COLOR else cfg["hat"] + "-" + cfg["hat_color"]
    if slot == "hat_trim":
        return cfg["hat"] + "-" + cfg["trim"] if cfg["hat"] in HAT_TRIMMED else None
    return "-".join(cfg[d] for d in dict(SLOTS)[slot])


def recolor(px, spell):
    """Maps the magic layer's key greys to a spell's ramp (same rule as magic_ramp.gdshader)."""
    m = SPELLS[spell] if isinstance(spell, str) else spell
    out = px.copy()
    g = px[..., 0].astype(int)
    a = px[..., 3] > 0
    for lo, hi, col in ((247, 256, WHITE), (213, 247, m[0]), (159, 213, m[1]), (99, 159, m[2]), (0, 99, m[3])):
        sel = a & (g >= lo) & (g < hi)
        out[sel, :3] = col
    return out


# ============================================================== skeleton
def unit(v):
    n = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / n, v[1] / n)


def wpt(t):
    return (CX + t[0], GY - t[1])


def skeleton(p):
    P = (CX + p["px"], GY - p["ph"] - PH_ADJ)
    lean = p["lean"]
    up = (math.sin(math.radians(lean)), -math.cos(math.radians(lean)))
    fwd = (math.cos(math.radians(lean)), math.sin(math.radians(lean)))
    waist = add(P, up, 3)
    chest = add(P, up, 18.5)
    neck = add(chest, up, 3)
    hdir = (math.sin(math.radians(lean + p["head"])), -math.cos(math.radians(lean + p["head"])))
    hc = add(neck, hdir, 7.0)
    sh_n = chest
    sh_f = add(chest, fwd, -0.5)
    hip = add(P, up, -1)
    lb = p.get("lbend", -1)
    kn_n, an_n = ik(hip, wpt((p["fn"][0], p["fn"][1] + FOOT)), LEG1, LEG2, lb)
    kn_f, an_f = ik(hip, wpt((p["ff"][0], p["ff"][1] + FOOT)), LEG1, LEG2, lb)
    if p.get("hn_rel"):
        hn = add(sh_n, p["hn_rel"])
    else:
        hn = wpt(p["hn"]) if p["hn"] else add(sh_n, (12, 8))
    if p.get("hf_rel"):
        hf = add(sh_f, p["hf_rel"])
    else:
        hf = wpt(p["hf"]) if p["hf"] else add(sh_f, (10, 12))
    st = p["staff"]
    if st and "base" not in st and "hand" in st:
        hn = add(sh_n, st["hand"])
    grip = hn
    el_n, hn = ik(sh_n, hn, ARM1, ARM2, 1)
    el_f, hf = ik(sh_f, hf, ARM1, ARM2, 1)
    hrot = p.get("head_rot", p["head"] * 0.6 + lean * 0.25)
    return dict(P=P, lean=lean, up=up, fwd=fwd, waist=waist, chest=chest, neck=neck, hc=hc, sh_n=sh_n, sh_f=sh_f,
                hip=hip, kn_n=kn_n, an_n=an_n, kn_f=kn_f, an_f=an_f, el_n=el_n, hn=hn, el_f=el_f, hf=hf, grip=grip,
                hrot=hrot)


def head_R(g):
    hx, hy = g["hc"]
    c, s = math.cos(math.radians(g["hrot"])), math.sin(math.radians(g["hrot"]))

    def R(dx, dy):  # local offset from the head centre -> world
        return (hx + dx * c - dy * s, hy + dx * s + dy * c)
    return R


def arc(R, cx, cy, rx, ry, a0, a1, n=10):
    """Points along part of an ellipse in head-local space (angles in degrees; 270 is straight up)."""
    return [R(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * k / n)))
            for k in range(n + 1)]


# ============================================================== body parts
def limb(pts, radii):
    """One continuous tapered shape along a polyline, shaded as ONE piece (no seam or shading jump at a joint):
    every pixel takes the nearest segment, the radius blends along it, and the light falls on the whole limb at once."""
    from rig import xx, yy, LIGHT
    best = None
    for (a, b), (ra, rb) in zip(zip(pts, pts[1:]), zip(radii, radii[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dy * dy or 1e-6
        t = np.clip(((xx - a[0]) * dx + (yy - a[1]) * dy) / L2, 0, 1)
        ox, oy = xx - (a[0] + t * dx), yy - (a[1] + t * dy)
        r = ra + (rb - ra) * t
        ratio = np.sqrt(ox * ox + oy * oy) / r
        s = (ox * LIGHT[0] + oy * LIGHT[1]) / r
        if best is None:
            best = [ratio, s]
        else:
            closer = ratio < best[0]
            best[0] = np.where(closer, ratio, best[0])
            best[1] = np.where(closer, s, best[1])
    return best[0] <= 1.0, best[1]


def sleeve(cv, sh, el, hd, col):
    cv.paint(limb([sh, el, hd], [3.0, 2.85, 2.7]), col["main"])
    d = (el[0] - hd[0], el[1] - hd[1])
    cv.paint(cv.capsule(add(hd, d, 0.22), add(hd, d, 0.12), 2.9), col["trim"], inner_outline=False)


def fist(cv, hd, u, skin):
    """A hand closed round a shaft running along u: a small block with three finger creases across it, the way the sample
    wizard's hands are shaded (no outline; the creases are the skin's dark tone)."""
    u = unit(u)
    v = (-u[1], u[0])
    if v[0] < 0 or (v[0] == 0 and v[1] > 0):  # the knuckles face forward
        v = (-v[0], -v[1])
    c = add(hd, v, 0.6)
    pts = [add(add(c, u, s1 * 2.8), v, s2 * 2.3) for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    cv.paint(cv.poly(pts), skin, hi=0.3, lo=-0.35, inner_outline=False)
    for o in (-1.4, 0.0, 1.4):
        a = add(add(c, u, o), v, -0.4)
        b = add(add(c, u, o), v, 2.0)
        m, _ = cv.capsule(a, b, 0.45)
        cv.px[m, :3] = skin[2]
    t = add(add(c, u, 2.4), v, -1.6)  # thumb tip over the shaft
    cv.dot(t[0], t[1], skin[0])


def open_hand(cv, el, hd, skin):
    """An open hand: palm and three short fingers along the forearm, a thumb to one side."""
    f = unit((hd[0] - el[0], hd[1] - el[1]))
    side = (-f[1], f[0])
    if side[1] > 0:
        side = (-side[0], -side[1])  # the thumb on the upper side
    cv.paint(cv.ellipse(hd, 2.2, 1.9, math.atan2(f[1], f[0])), skin, hi=0.3, lo=-0.35, inner_outline=False)
    for k, ang in ((-1, -0.35), (0, 0.0), (1, 0.35)):
        ca, sa = math.cos(ang), math.sin(ang)
        d = (f[0] * ca - f[1] * sa, f[0] * sa + f[1] * ca)
        a = add(add(hd, d, 1.4), side, k * 0.9)
        b = add(a, d, 2.4)
        m, _ = cv.capsule(a, b, 0.5)
        cv.px[m, :3] = skin[1] if k else skin[0]
        cv.px[m, 3] = 255
    th = add(add(hd, side, 2.2), f, 0.6)
    m, _ = cv.capsule(add(hd, side, 1.0), th, 0.5)
    cv.px[m, :3] = skin[1]
    cv.px[m, 3] = 255
    q = add(hd, f, 0.9)
    cv.dot(q[0], q[1], skin[2])  # the crease where the fingers meet the palm


def hand(cv, g, p, which, skin, kind):
    if which == "near":
        st = p["staff"]
        el, hd = g["el_n"], g["hn"]
        if st and not ("base" in st) and not p.get("hn_open"):
            a, b, d = weapon_line(p, g, kind)
            fist(cv, hd, d, skin)
            return
        open_hand(cv, el, hd, skin)
        return
    el, hd = g["el_f"], g["hf"]
    if p.get("hf_fist"):
        fist(cv, hd, (hd[0] - el[0], hd[1] - el[1]), skin)
    else:
        open_hand(cv, el, hd, skin)


def arm(cv, sh, el, hd, skin):
    """A bare arm: the same shape as a sleeve's, in the skin."""
    cv.paint(limb([sh, el, hd], [3.0, 2.85, 2.7]), skin)


def trousers(cv, g, kn, an, col):
    cv.paint(limb([g["hip"], kn, an], [3.6, 3.3, 3.0]), col["trim"])  # trousers are in the trim's color


def bare_leg(cv, g, kn, an, skin):
    cv.paint(limb([g["hip"], kn, an], [3.6, 3.3, 3.0]), skin)


def boot(cv, g, kn, an, ang, boots, skin):
    """The boot: ONE shape from the calf, down the back of the heel, along the sole to the toe. Bare feet are the same shape from the ankle, in the skin."""
    fa = math.radians(ang)
    f = (math.cos(fa), -math.sin(fa))                     # along the foot, toward the toe
    ball = (an[0] + 3.2 * f[0], an[1] + 1.0 + 3.2 * f[1])   # the instep slopes down from the shin to the toe
    toe = (an[0] + 6.4 * f[0], an[1] + 2.0 + 6.4 * f[1])
    if boots == "bare":
        top = add(an, (kn[0] - an[0], kn[1] - an[1]), 0.1)
        cv.paint(limb([top, an, ball, toe], [2.8, 2.7, 2.4, 1.8]), skin, hi=0.5, lo=-0.2, inner_outline=False)
        return
    bt = add(kn, (an[0] - kn[0], an[1] - kn[1]), 0.5)
    # mostly one dark color with a single highlight down the front of the shin, like the sample's boots
    cv.paint(limb([bt, an, ball, toe], [3.1, 3.0, 2.6, 1.9]), BOOTS[boots], hi=0.62, lo=-0.3, inner_outline=False)


def coat_flap(cv, g, p, col, front):
    P, waist, fwd = g["P"], g["waist"], g["fwd"]
    sw, fl = p["sway"], p.get("flap", 1.0)
    if front:
        a, b = add(waist, fwd, -1.0), add(waist, fwd, 4.8)
        h1 = (P[0] + 2 + sw * 0.4, P[1] + 17 * fl)
        h2 = (P[0] + 10 + sw * 1.0, P[1] + 14.5 * fl - abs(sw) * 0.1 * fl)
    else:
        a, b = add(waist, fwd, -4.6), add(waist, fwd, 1.0)
        h1 = (P[0] - 10 + sw * 1.0, P[1] + 15.5 * fl - abs(sw) * 0.1 * fl)
        h2 = (P[0] - 1 + sw * 0.5, P[1] + 16.5 * fl)
    cv.paint(cv.poly([a, b, h2, h1]), col["second"], hi=0.5, lo=-0.1)
    cv.paint(cv.capsule(h1, h2, 0.9), col["trim"], inner_outline=False)


def robe_skirt(cv, g, p, col, band=False, gown=False):
    """Long robe: from the waist down to the ankles, spread to cover both legs."""
    waist, fwd, up = g["waist"], g["fwd"], g["up"]
    an = [g["an_n"], g["an_f"]]
    sw = p["sway"]
    xs = [a[0] for a in an]
    lo_y = max(a[1] for a in an) - 1.5
    if g["lean"] > 45:  # lying down: the skirt follows the body back to the feet
        back = min(xs) - 3
        pts = [add(waist, fwd, -0.5), add(add(waist, up, -1), fwd, 5.0), (back, max(a[1] for a in an) + 2),
               (back, min(a[1] for a in an) - 4)]
        cv.paint(cv.poly(pts), col["main"], hi=0.5, lo=-0.15)
        return
    flare = 3.5 if band else (2.0 if gown else 0.0)  # a ceremonial robe is cut wider, and a gown wider still
    front_x = max(max(xs) + 4.0, waist[0] + 8) + sw * 0.15 + flare
    back_x = min(min(xs) - 5.0, waist[0] - 8) + sw * 0.3 - flare
    mid_y = lo_y + 1
    pts = [add(waist, fwd, -4.8), add(waist, fwd, 5.0), (front_x, lo_y - 1), ((front_x + back_x) / 2 + 1, mid_y),
           (back_x, lo_y)]
    cv.paint(cv.poly(pts), col["main"], hi=0.5, lo=-0.15)
    c_hem = (front_x * 0.62 + back_x * 0.38)
    wide = 3.2 if band else 0.0
    if gown:  # a gown: a fitted waist, the skirt swelling over the hips and falling in a bell, a curved hem, folds in the cloth
        top_f, top_b = add(waist, fwd, 5.0), add(waist, fwd, -4.8)
        def edge(t0, ctrl, t1, n=8):
            return [((1 - k / n) ** 2 * t0[0] + 2 * (1 - k / n) * (k / n) * ctrl[0] + (k / n) ** 2 * t1[0],
                     (1 - k / n) ** 2 * t0[1] + 2 * (1 - k / n) * (k / n) * ctrl[1] + (k / n) ** 2 * t1[1]) for k in range(n + 1)]
        mid_h = (waist[1] + lo_y) / 2
        fr = edge(top_f, (front_x + 3.0, mid_h - 3.0), (front_x - 0.5, lo_y))
        bk = edge((back_x + 0.5, lo_y), (back_x - 3.0, mid_h - 3.0), top_b)
        hem = [((front_x + back_x) / 2 + (front_x - back_x) * (0.5 - k / 6) * 0.9, lo_y + (1.4 if k % 2 else 0.2)) for k in range(7)]
        cv.paint(cv.poly(fr + hem + bk), col["main"], hi=0.5, lo=-0.15)
        for k in range(1, 5):  # folds
            fx0 = top_b[0] + (top_f[0] - top_b[0]) * k / 5.0
            fx1 = back_x + (front_x - back_x) * k / 5.0 + (k - 2.5) * 1.2
            cv.paint(cv.capsule((fx0, waist[1] + 2.0), (fx1, lo_y - 1.0), 0.45), col["main"], bias=-0.8, inner_outline=False)
        cv.paint(cv.poly(hem + [(hem[-1][0], lo_y - 2.0), (hem[0][0], lo_y - 2.0)]), col["second"], hi=0.5, lo=-0.1, inner_outline=False)  # a pale underskirt at the hem
        cv.paint(cv.capsule((back_x + 1, lo_y - 2.6), (front_x - 1, lo_y - 2.6), 0.5), col["trim"], inner_outline=False)
        return
    cv.paint(cv.poly([add(waist, fwd, 2.2 - wide * 0.4), add(waist, fwd, 4.4 + wide * 0.2), (c_hem + 2.8 + wide, lo_y), (c_hem - 1.4 - wide, mid_y)]),
             col["second"], hi=0.5, lo=-0.1, inner_outline=False)
    if band:  # the panel is edged in trim, down both sides
        cv.paint(cv.capsule(add(waist, fwd, 1.8), (c_hem - 1.4 - wide, mid_y), 0.5), col["trim"], inner_outline=False)
        cv.paint(cv.capsule(add(waist, fwd, 4.8), (c_hem + 2.8 + wide, lo_y), 0.5), col["trim"], inner_outline=False)
    cv.paint(cv.capsule((back_x + 1, lo_y), ((front_x + back_x) / 2 + 1, mid_y), 0.8), col["trim"], inner_outline=False)
    cv.paint(cv.capsule(((front_x + back_x) / 2 + 1, mid_y), (front_x - 1, lo_y - 1), 0.8), col["trim"], inner_outline=False)
    if band:  # a ceremonial robe has a second band of trim above the hem, with a star at its middle
        a, b = (back_x + 2, lo_y - 5.0), (front_x - 2, lo_y - 6.0)
        cv.paint(cv.capsule(a, b, 0.7), col["trim"], inner_outline=False)
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        cv.dot(mx, my - 2, col["trim"][0])
        cv.dot(mx, my + 2, col["trim"][0])
        cv.dot(mx - 2, my, col["trim"][0])
        cv.dot(mx + 2, my, col["trim"][0])


def tunic_skirt(cv, g, p, col, drop=9.0):
    P, waist, fwd, up = g["P"], g["waist"], g["fwd"], g["up"]
    sw = p["sway"]
    h1 = add(add(P, fwd, 7.0), up, -drop)
    h2 = add(add(P, fwd, -7.0), up, -drop - 0.5)
    h1 = (h1[0] + sw * 0.25, h1[1])
    h2 = (h2[0] + sw * 0.6, h2[1])
    cv.paint(cv.poly([add(waist, fwd, -4.8), add(waist, fwd, 5.0), h1, h2]), col["main"], hi=0.5, lo=-0.12)
    cv.paint(cv.capsule(h1, h2, 0.8), col["trim"], inner_outline=False)


def kilt_skirt(cv, g, p, col):
    """A kilt of pelt: short, with a ragged hem and a row of stitches under the belt."""
    P, waist, fwd, up = g["P"], g["waist"], g["fwd"], g["up"]
    sw = p["sway"]
    h1 = add(add(P, fwd, 7.2), up, -9.0)
    h2 = add(add(P, fwd, -7.2), up, -9.5)
    h1 = (h1[0] + sw * 0.25, h1[1])
    h2 = (h2[0] + sw * 0.6, h2[1])
    hem = []
    for k in range(9):
        t = k / 8
        hem.append((h1[0] + (h2[0] - h1[0]) * t, h1[1] + (h2[1] - h1[1]) * t + (3.0 if k % 2 else 0.0)))
    cv.paint(cv.poly([add(waist, fwd, -4.8), add(waist, fwd, 5.0)] + hem), col["main"], hi=0.5, lo=-0.12)
    for k in (1, 3, 5):
        q = add(add(P, fwd, 5.0 - 2.4 * k), up, -4.0)
        cv.dot(q[0], q[1], col["main"][3])
        cv.dot(q[0] + 1.0, q[1] + 2.0, col["main"][3])


def armor_skirt(cv, g, p, col):
    """A tunic with three rows of steel plates hanging over it, each a little wider than the last."""
    tunic_skirt(cv, g, p, col)
    P, fwd, up, sw = g["P"], g["fwd"], g["up"], p["sway"]
    for k in range(3):
        y0 = -1.0 - 3.4 * k
        w = 5.0 + 0.9 * k
        a = add(add(P, fwd, w), up, y0)
        b = add(add(P, fwd, -w), up, y0)
        c = add(add(P, fwd, -w - 0.6), up, y0 - 3.8)
        d = add(add(P, fwd, w + 0.6), up, y0 - 3.8)
        pts = [a, b, (c[0] + sw * 0.15 * (k + 1), c[1]), (d[0] + sw * 0.1 * (k + 1), d[1])]
        cv.paint(cv.poly(pts), SILVER, hi=0.4, lo=-0.1)
        cv.paint(cv.capsule(pts[2], pts[3], 0.4), col["trim"] if k == 2 else IRON, inner_outline=False)


def flounce_skirt(cv, g, p, col):
    """A short skirt in two tiers, with a scalloped hem."""
    P, waist, fwd, up = g["P"], g["waist"], g["fwd"], g["up"]
    sw = p["sway"]
    h1 = add(add(P, fwd, 8.4), up, -11.0)
    h2 = add(add(P, fwd, -8.4), up, -11.5)
    h1 = (h1[0] + sw * 0.25, h1[1])
    h2 = (h2[0] + sw * 0.6, h2[1])
    hem = []
    for k in range(9):  # scallops
        t = k / 8
        hem.append((h1[0] + (h2[0] - h1[0]) * t, h1[1] + (h2[1] - h1[1]) * t + (2.2 if k % 2 else 0.0)))
    cv.paint(cv.poly([add(waist, fwd, -4.8), add(waist, fwd, 5.0)] + hem), col["second"], hi=0.5, lo=-0.12)
    top1 = add(add(P, fwd, 6.6), up, -6.0)
    top2 = add(add(P, fwd, -6.6), up, -6.5)
    top1 = (top1[0] + sw * 0.2, top1[1])
    top2 = (top2[0] + sw * 0.45, top2[1])
    upper = []
    for k in range(7):
        t = k / 6
        upper.append((top1[0] + (top2[0] - top1[0]) * t, top1[1] + (top2[1] - top1[1]) * t + (2.0 if k % 2 else 0.0)))
    cv.paint(cv.poly([add(waist, fwd, -4.8), add(waist, fwd, 5.0)] + upper), col["main"], hi=0.5, lo=-0.12)
    cv.paint(cv.capsule(top1, top2, 0.6), col["trim"], inner_outline=False)


def ragged_skirt(cv, g, p, col):
    """Rags: a short skirt with a torn hem, and a patch."""
    P, waist, fwd, up = g["P"], g["waist"], g["fwd"], g["up"]
    sw = p["sway"]
    h1 = add(add(P, fwd, 7.2), up, -10.0)
    h2 = add(add(P, fwd, -7.2), up, -10.5)
    h1 = (h1[0] + sw * 0.25, h1[1])
    h2 = (h2[0] + sw * 0.6, h2[1])
    hem = []
    for k in range(7):  # from the front to the back, ragged
        t = k / 6
        hem.append((h1[0] + (h2[0] - h1[0]) * t, h1[1] + (h2[1] - h1[1]) * t + (3.2 if k % 2 else -0.4) + (1.0 if k == 3 else 0.0)))
    cv.paint(cv.poly([add(waist, fwd, -4.8), add(waist, fwd, 5.0)] + hem), col["main"], hi=0.5, lo=-0.12)
    q = add(add(P, fwd, 2.2), up, -5.0)
    cv.paint(cv.poly([(q[0] - 1.8, q[1] - 1.6), (q[0] + 1.8, q[1] - 1.6), (q[0] + 1.8, q[1] + 1.8), (q[0] - 1.8, q[1] + 1.8)]), col["second"],
             hi=0.5, lo=-0.1, inner_outline=False)
    cv.dot(q[0], q[1], col["trim"][2])


def cape(cv, g, p, col, long=False):
    """A cloak: hangs from the shoulders down the back of the legs."""
    P, waist, neck, fwd = g["P"], g["waist"], g["neck"], g["fwd"]
    sw, fl = p["sway"], p.get("flap", 1.0)
    drop = (24.0 if long else 21.0) * fl
    h1 = (P[0] - 12 + sw * 1.2, P[1] + drop - abs(sw) * 0.1 * fl)
    h2 = (P[0] - 1.5 + sw * 0.5, P[1] + drop + 1.5)
    cv.paint(cv.poly([add(neck, fwd, -2.6), add(waist, fwd, -0.6), h2, ((h1[0] + h2[0]) / 2, h1[1] + 2.5), h1]), col["main"], hi=0.5, lo=-0.15)
    cv.paint(cv.capsule(h1, h2, 0.9), col["trim"], inner_outline=False)


def bare_torso(cv, g, skin):
    """The chest, the belly and the neck of someone who wears nothing over them (the layer under a vest, a sash, a pelt or a toga)."""
    waist, chest, neck, fwd, up = g["waist"], g["chest"], g["neck"], g["fwd"], g["up"]
    cv.paint(cv.capsule(waist, chest, 4.7), skin, hi=0.45, lo=-0.1)
    cv.paint(cv.capsule(add(chest, fwd, -2.6), add(chest, fwd, 2.8), 3.4), skin, hi=0.45, lo=-0.1, inner_outline=False)
    cv.paint(cv.capsule(add(chest, up, 1.0), add(neck, up, 1.5), 2.1), skin, hi=0.45, lo=-0.1, inner_outline=False)
    m, _ = cv.capsule(add(add(chest, up, -4.0), fwd, 2.8), add(add(waist, up, 2.0), fwd, 3.2), 0.4)  # the line down the belly
    cv.px[m, :3] = skin[2]
    q = add(add(chest, up, -3.0), fwd, 2.4)
    cv.dot(q[0], q[1], skin[2])  # the shadow under the chest


def bare_torso_cloth(cv, g, outfit, col):
    """What a bare-chested outfit has on above the waist."""
    waist, chest, neck, fwd, up = g["waist"], g["chest"], g["neck"], g["fwd"], g["up"]
    if outfit == "vest":  # an open vest: the back and the sides, and a lapel down each side of the opening
        cv.paint(cv.capsule(add(waist, fwd, -2.6), add(chest, fwd, -2.4), 2.5), col["main"], hi=0.45, lo=-0.1)
        cv.paint(cv.capsule(add(chest, fwd, -2.6), add(neck, fwd, 1.2), 1.3), col["main"], hi=0.45, lo=-0.1, inner_outline=False)
        cv.paint(cv.capsule(add(neck, fwd, 1.6), add(waist, fwd, 3.8), 1.4), col["main"], hi=0.45, lo=-0.1, inner_outline=False)
        cv.paint(cv.capsule(add(neck, fwd, 2.9), add(waist, fwd, 4.9), 0.45), col["trim"], inner_outline=False)
        for k in (3, 6, 9):
            q = add(add(chest, up, -k), fwd, 3.3)
            cv.dot(q[0], q[1], col["trim"][1])
    elif outfit == "pelt":  # a pelt over one shoulder and a strap across the chest, studded
        cv.paint(cv.capsule(add(add(chest, up, 2.0), fwd, -3.4), add(waist, fwd, 4.2), 1.2), col["second"], inner_outline=False)
        cv.paint(cv.ellipse(add(chest, up, 1.6), 4.9, 3.4), col["main"], hi=0.45, lo=-0.1)
        for k in (-3.0, 0.0, 3.0):
            q = add(add(chest, up, -0.4), fwd, k)
            cv.dot(q[0], q[1], col["main"][3])
        for t in (0.3, 0.6):
            q = (chest[0] + (waist[0] + fwd[0] * 4.2 - chest[0] - fwd[0] * -3.4) * t + fwd[0] * -3.4, chest[1] + (waist[1] + fwd[1] * 4.2 - chest[1] - fwd[1] * -3.4 - up[1] * 2.0) * t + fwd[1] * -3.4 + up[1] * 2.0)
            cv.dot(q[0], q[1], col["trim"][1])
    elif outfit == "sash":  # a broad sash from the shoulder to the hip, edged in trim
        a, b = add(add(chest, up, 2.4), fwd, -3.6), add(add(waist, up, -0.5), fwd, 4.0)
        cv.paint(cv.capsule(a, b, 2.1), col["main"], hi=0.45, lo=-0.1)
        cv.paint(cv.capsule(add(a, up, 1.9), add(b, up, 1.9), 0.45), col["trim"], inner_outline=False)
        cv.paint(cv.capsule(add(a, up, -1.9), add(b, up, -1.9), 0.45), col["trim"], inner_outline=False)
    elif outfit == "toga":  # a length of cloth over the shoulder and across the chest, with a fold over the shoulder
        a, b = add(add(chest, up, 2.0), fwd, -3.8), add(add(waist, up, -0.5), fwd, 4.2)
        cv.paint(cv.capsule(a, b, 3.0), col["main"], hi=0.5, lo=-0.1)
        cv.paint(cv.ellipse(add(chest, up, 1.5), 3.8, 2.8), col["main"], hi=0.5, lo=-0.1, inner_outline=False)
        cv.paint(cv.capsule(add(a, up, 2.9), add(b, up, 2.9), 0.5), col["trim"], inner_outline=False)
        cv.paint(cv.capsule(add(a, up, -1.0), add(b, up, -1.0), 0.4), col["second"], inner_outline=False)


def torso(cv, g, outfit, col):
    waist, chest, neck, fwd, up = g["waist"], g["chest"], g["neck"], g["fwd"], g["up"]
    if outfit in SLEEVELESS:
        bare_torso_cloth(cv, g, outfit, col)
        return
    cv.paint(cv.capsule(waist, chest, 4.7), col["main"], hi=0.45, lo=-0.1)
    cv.paint(cv.capsule(add(chest, fwd, -2.6), add(chest, fwd, 2.8), 3.4), col["main"], hi=0.45, lo=-0.1,
             inner_outline=False)
    if outfit in ("coat", "robe", "cloak", "ceremonial", "gothic"):
        cv.paint(cv.capsule(add(chest, fwd, 3.2), add(waist, fwd, 3.6), 0.75), col["trim"], inner_outline=False)
        cv.paint(cv.capsule(add(neck, fwd, -2.4), add(neck, fwd, 2.7), 1.9), col["trim"], inner_outline=False)
        if outfit == "cloak":  # a mantle over the shoulders and a clasp
            cv.paint(cv.capsule(add(chest, fwd, -4.0), add(chest, fwd, 4.2), 4.1), col["second"], hi=0.45, lo=-0.1, inner_outline=False)
            q = add(add(chest, up, 1.5), fwd, 3.4)
            cv.paint(cv.ellipse(q, 1.3, 1.3), col["trim"], inner_outline=False)
        elif outfit == "ceremonial":  # a stole hanging down the front
            cv.paint(cv.capsule(add(neck, fwd, 1.8), add(waist, fwd, 4.0), 1.8), col["second"], inner_outline=False)
            cv.paint(cv.capsule(add(neck, fwd, 0.1), add(waist, fwd, 2.3), 0.5), col["trim"], inner_outline=False)
            for k in (4, 9):
                q = add(add(chest, up, -k), fwd, 3.0)
                cv.dot(q[0], q[1], col["trim"][0])
        elif outfit == "gothic":  # a high collar, standing up behind the head, and a row of buttons
            # a tall flared collar standing up behind the head, lined inside, with a pointed tip
            cv.paint(cv.poly([add(add(neck, up, -1.0), fwd, -5.2), add(add(neck, up, 9.5), fwd, -7.2), add(add(neck, up, 7.0), fwd, -2.6), add(add(neck, up, 1.5), fwd, 0.4)]),
                     col["main"], hi=0.45, lo=-0.1)
            cv.paint(cv.poly([add(add(neck, up, 0.5), fwd, -3.8), add(add(neck, up, 7.0), fwd, -5.4), add(add(neck, up, 5.2), fwd, -2.6)]), col["second"], inner_outline=False)
            cv.paint(cv.capsule(add(neck, fwd, 2.8), add(add(neck, up, 3.0), fwd, 3.4), 1.6), col["main"], hi=0.45, lo=-0.1, inner_outline=False)
            # a lining down the open front, a row of clasps and a chain across the chest
            cv.paint(cv.capsule(add(neck, fwd, 3.6), add(waist, fwd, 4.4), 1.0), col["second"], inner_outline=False)
            for k in (1, 4, 7, 10):
                q = add(add(chest, up, -k), fwd, 4.0)
                cv.dot(q[0], q[1], col["trim"][0])
                cv.dot(q[0] - 1.0, q[1], col["trim"][2])
            cv.paint(cv.capsule(add(add(chest, up, 1.0), fwd, -3.0), add(add(chest, up, -4.5), fwd, 3.6), 0.4), col["trim"], inner_outline=False)
    elif outfit in ("gown", "bodice"):  # a fitted bodice: a neckline, a trim line and, for the bodice, laces
        cv.paint(cv.capsule(add(neck, fwd, -2.0), add(neck, fwd, 2.6), 1.7), col["trim"], inner_outline=False)
        if outfit == "gown":
            cv.paint(cv.capsule(add(add(waist, up, 1.0), fwd, -4.2), add(add(waist, up, 1.0), fwd, 4.4), 1.5), col["second"], inner_outline=False)  # a sash at the waist
            q = add(add(waist, up, 1.0), fwd, -4.6)
            cv.paint(cv.capsule(q, add(q, fwd, -3.2), 0.9), col["second"], inner_outline=False)  # its bow, behind
        else:
            cv.paint(cv.capsule(add(waist, up, 0.0), add(chest, up, -3.0), 4.8), col["second"], hi=0.45, lo=-0.1, inner_outline=False)
            for k in (3, 6, 9):
                q = add(add(waist, up, k), fwd, 3.6)
                cv.dot(q[0], q[1], col["trim"][0])
                cv.dot(q[0] - 1.0, q[1], col["trim"][2])
    elif outfit == "armored":  # a breastplate and a plate on each shoulder, over a tunic
        cv.paint(cv.capsule(add(waist, up, -1.0), add(chest, up, 0.5), 5.4), SILVER, hi=0.4, lo=-0.1)  # the breastplate, with a ridge down it
        cv.paint(cv.capsule(add(add(waist, up, 0.0), fwd, 2.4), add(add(chest, up, 0.0), fwd, 2.4), 0.6), col["trim"], inner_outline=False)
        for k in (-1, 4, 9):  # rivets and the lames across the belly
            cv.paint(cv.capsule(add(add(waist, up, k * 0.5 + 1), fwd, -4.6), add(add(waist, up, k * 0.5 + 1), fwd, 4.8), 0.4), IRON, inner_outline=False)
        cv.paint(cv.capsule(add(neck, fwd, -3.0), add(neck, fwd, 3.2), 2.2), SILVER, hi=0.4, lo=-0.1, inner_outline=False)  # a gorget at the neck
        for sh in (g["sh_f"], g["sh_n"]):  # big layered shoulder plates with a spike
            cv.paint(cv.ellipse(add(sh, up, 1.0), 5.6, 4.2), SILVER, hi=0.4, lo=-0.1)
            cv.paint(cv.ellipse(add(add(sh, up, -0.8), fwd, 1.0), 4.6, 3.0), SILVER, hi=0.2, lo=-0.2, inner_outline=False)
            cv.paint(cv.poly([add(add(sh, up, 4.6), fwd, -1.4), add(add(sh, up, 4.6), fwd, 1.4), add(add(sh, up, 9.0), fwd, 0.2)]), IRON, hi=0.4, lo=-0.1)
            cv.paint(cv.capsule(add(sh, fwd, -4.4), add(sh, fwd, 4.6), 0.5), col["trim"], inner_outline=False)
    elif outfit == "rags":  # open neck, a patch and the stitches round it
        cv.paint(cv.capsule(add(neck, fwd, -2.2), add(neck, fwd, 2.4), 1.5), col["second"], inner_outline=False)
        q = add(add(chest, up, -4.0), fwd, 0.6)
        cv.paint(cv.poly([(q[0] - 2.2, q[1] - 2.0), (q[0] + 2.2, q[1] - 2.0), (q[0] + 2.2, q[1] + 2.2), (q[0] - 2.2, q[1] + 2.2)]), col["second"],
                 hi=0.5, lo=-0.1, inner_outline=False)
        cv.dot(q[0] - 1.0, q[1], col["trim"][2])
        cv.dot(q[0] + 1.0, q[1], col["trim"][2])
    else:  # tunic: open neck with lacing
        cv.paint(cv.capsule(add(neck, fwd, -2.2), add(neck, fwd, 2.4), 1.5), col["second"], inner_outline=False)
        for k in (5, 8):
            q = add(add(chest, up, -k + 2), fwd, 3.2)
            cv.dot(q[0], q[1], col["trim"][1])


def belt(cv, g, p, outfit, col):
    P, fwd, up = g["P"], g["fwd"], g["up"]
    bw = add(P, up, 4.2)
    hw = 5.4
    q = [add(add(bw, fwd, -hw), up, -1.4), add(add(bw, fwd, hw), up, -1.4), add(add(bw, fwd, hw), up, 1.4),
         add(add(bw, fwd, -hw), up, 1.4)]
    if outfit in ("tunic", "rags", "bodice", "sash", "toga"):
        cv.paint(cv.poly(q), col["second"], inner_outline=False)
        tail0 = add(add(bw, fwd, -hw + 0.5), up, -1)
        tail1 = add(add(tail0, up, -7), fwd, -1.5 + p["sway"] * 0.15)
        cv.paint(cv.capsule(tail0, tail1, 1.3), col["second"])
    else:
        cv.paint(cv.poly(q), LEATHER if outfit == "robe" else WOODS["oak"], inner_outline=False)
        bx = add(bw, fwd, 4.0)
        cv.paint(cv.capsule(add(bx, up, -1.2), add(bx, up, 1.2), 1.3), col["trim"], inner_outline=False)


# ============================================================== head parts (a little smaller than before)
def head(cv, g, skin):
    R = head_R(g)
    rot = math.radians(g["hrot"])
    cv.paint(cv.ellipse(R(-1.8, -0.5), 4.9, 5.7, rot), skin)  # the back of the skull, so a bare head is a whole head
    cv.paint(cv.ellipse(R(0, 0), 4.8, 5.8, rot), skin, inner_outline=False)
    cv.paint(cv.ellipse(R(-1.3, 0.8), 1.2, 1.7, rot), skin, bias=-0.35)                       # ear
    cv.paint(cv.ellipse(R(4.8, 0.7), 1.5, 1.4), skin, inner_outline=False)                       # nose
    r = R(2.6, -1.3)
    cv.dot(r[0], r[1], skin[3])                                                                   # eye
    r = R(3.5, -1.3)
    cv.dot(r[0], r[1], (240, 236, 230))                                                           # eye white
    r = R(1.4, 3.6)
    cv.dot(r[0], r[1], skin[2])                                                                   # cheek line


def beard(cv, g, p, style, hair):
    if style == "none":
        return
    R = head_R(g)
    bs = p["beard"]
    if style == "long":  # so long that it hangs past the arm and the belt, to the thigh
        chest, up, fwd = g["chest"], g["up"], g["fwd"]
        def low(down, out):  # a point on the body, down from the chest
            return add(add(chest, up, -down), fwd, out)
        cv.paint(cv.poly([R(-3.2, 1), R(2.4, 2.0), R(5.8, 3.3), R(6.2, 6.0), low(2.0, 6.4), low(10.0, 6.6), low(19.0, 5.8 + bs * 0.5),
                          low(25.0, 4.4 + bs * 0.9), low(19.0, 2.2 + bs * 0.4), low(8.0, 1.4), R(-3.6, 7.0)]), hair, hi=0.35, lo=-0.1)
    elif style == "short":
        cv.paint(cv.poly([R(-3.1, 1), R(2.4, 2.0), R(5.6, 3.3), R(5.4, 5.6), R(2.9 + bs * 0.2, 7.8), R(-0.7, 7.3),
                          R(-3.4, 4.2)]), hair, hi=0.35, lo=-0.1)
    elif style == "goatee":
        cv.paint(cv.poly([R(3.0, 4.0), R(5.6, 4.2), R(5.2 + bs * 0.3, 9), R(3.3, 7.8)]), hair, hi=0.35, lo=-0.1)
    elif style == "handlebar":  # no beard: a great moustache, curled up at the ends, and a small tuft under the lip
        cv.paint(cv.poly([R(3.6, 4.6), R(5.6, 4.8), R(5.2, 7.4), R(3.8, 6.8)]), hair, hi=0.35, lo=-0.1)  # the tuft
        # a great moustache that sweeps out past the face, then curls up and round into a ring
        cv.paint(limb([R(2.2, 2.9), R(5.6, 3.8), R(8.8, 4.0), R(10.6, 2.4), R(10.0, 0.4), R(8.4, 0.6)], [1.5, 1.7, 1.5, 1.2, 1.0, 0.7]), hair, hi=0.35, lo=-0.1)
        cv.paint(cv.capsule(R(2.0, 2.7), R(-1.4, 3.6), 1.2), hair, inner_outline=False)
        return
    elif style == "stubble":  # a shadow along the jaw, a dot here and there
        from rig import xx, yy
        m, sh = cv.poly([R(-3.4, 1.0), R(2.6, 2.4), R(5.6, 3.6), R(5.4, 5.6), R(2.8, 6.6), R(-0.7, 6.2), R(-3.4, 3.6)])
        dots = (((xx.astype(int) + yy.astype(int)) % 2) == 0) & m
        cv.paint((dots, sh), hair, hi=2.0, lo=-2.0, inner_outline=False, bias=0.0)
        return
    cv.paint(cv.capsule(R(2.6, 2.6), R(6.3, 3.5), 1.05), hair, inner_outline=False)                 # moustache


def hair_back(cv, g, p, style, hair):
    if style == "none":
        return
    R = head_R(g)
    bs = p["beard"]
    if style == "short":
        cv.paint(cv.poly([R(-6.2, -3.8), R(-2.7, -5.0), R(-2.9, 3.2), R(-5.9, 4.0)]), hair)
    elif style == "long":
        cv.paint(cv.poly([R(-6.4, -4.1), R(-2.7, -5.0), R(-2.4, 7.8), R(-5.0 + bs * 0.3, 13.2), R(-8.7 + bs * 0.5, 11.4),
                          R(-7.6, 2.7)]), hair)
    elif style == "ponytail":
        cv.paint(cv.poly([R(-6.0, -3.8), R(-2.7, -5.0), R(-2.9, 2.3), R(-5.8, 2.7)]), hair)
        a, b, c = R(-5.6, -2.3), R(-8.7 + bs * 0.4, 3.2), R(-9.6 + bs * 0.8, 10)
        cv.paint(cv.capsule(a, b, 2.1), hair)
        cv.paint(cv.capsule(b, c, 1.6), hair)
        t = R(-6.6, -1.6)
        cv.dot(t[0], t[1], hair[3])
    elif style == "bun":
        cv.paint(cv.poly([R(-6.0, -3.8), R(-2.7, -5.0), R(-2.9, 2.3), R(-5.8, 2.7)]), hair)
        cv.paint(cv.ellipse(R(-5.6, -5.3), 3.0, 2.7), hair)
    elif style == "braids":  # a braid down the back, in links and a tie
        cv.paint(cv.poly([R(-6.0, -3.8), R(-2.7, -5.0), R(-2.9, 2.3), R(-5.8, 2.7)]), hair)
        cv.paint(limb([R(-5.6, -1.5), R(-7.4, 3.5), R(-8.2 + bs * 0.5, 9.0), R(-8.0 + bs * 0.8, 14.0)], [2.1, 2.0, 1.8, 1.4]), hair)
        for yy_ in (3.0, 6.0, 9.0, 12.0):
            q = R(-7.6 + bs * 0.5 * yy_ / 14, yy_)
            cv.dot(q[0], q[1], hair[3])
        q = R(-8.0 + bs * 0.8, 14.6)
        cv.dot(q[0], q[1], GOLD[1])
    elif style == "straight":  # long, straight and parted: down past the shoulders
        cv.paint(cv.poly([R(-6.6, -4.1), R(-2.7, -5.0), R(-2.2, 9.0), R(-4.6 + bs * 0.3, 15.0), R(-9.2 + bs * 0.5, 13.6), R(-7.9, 3.0)]), hair)
    elif style == "bob":  # cut at the jaw, curving in
        cv.paint(cv.poly([R(-6.8, -4.0), R(-2.7, -5.0), R(-2.4, 6.4), R(-3.6, 8.2), R(-7.6, 7.6), R(-8.0, 2.0)]), hair)
    elif style == "pigtails":  # a tail high on each side, tied
        cv.paint(cv.poly([R(-6.0, -3.8), R(-2.7, -5.0), R(-2.9, 2.3), R(-5.8, 2.7)]), hair)
        cv.paint(limb([R(-5.4, -3.6), R(-9.0, -1.4), R(-10.4 + bs * 0.6, 4.6), R(-9.8 + bs * 0.8, 9.0)], [1.9, 2.3, 2.0, 1.2]), hair)
        cv.paint(limb([R(-4.8, -1.0), R(-8.0, 3.2), R(-8.6 + bs * 0.5, 8.4), R(-8.2 + bs * 0.7, 12.0)], [1.9, 2.1, 1.8, 1.0]), hair)
        for q in (R(-5.4, -3.4), R(-4.8, -0.8)):
            cv.dot(q[0], q[1], (214, 70, 96))
    elif style == "wavy":  # long and waved, down past the shoulders
        cv.paint(cv.poly([R(-6.6, -4.1), R(-2.7, -5.0), R(-2.2, 9.0), R(-3.4, 12.2), R(-5.2, 9.8), R(-6.6, 13.6), R(-8.4, 10.6), R(-9.8, 13.0), R(-9.9 + bs * 0.4, 5.0), R(-7.9, 3.0)]), hair)
    elif style == "updo":  # up in a twist: only a loose lock at the nape
        cv.paint(cv.poly([R(-6.0, -3.8), R(-2.7, -5.0), R(-2.9, 2.3), R(-5.8, 2.7)]), hair)
        cv.paint(limb([R(-5.4, 0.5), R(-6.4, 4.0), R(-6.0 + bs * 0.5, 7.5)], [1.2, 1.1, 0.7]), hair)
    elif style == "tonsure":  # the crown shaved, a ring of hair round it: behind, down to the nape
        cv.paint(cv.poly([R(-6.5, -3.6), R(-2.9, -3.9), R(-2.9, 3.6), R(-5.9, 5.4), R(-7.0, 1.0)]), hair)
    elif style == "balding":  # a band of hair round the sides and back, none on top
        cv.paint(cv.poly([R(-6.2, -1.6), R(-2.9, -2.2), R(-2.9, 3.4), R(-5.9, 5.0), R(-6.6, 2.0)]), hair)
    elif style == "wild":  # a bushy mass standing out behind
        cv.paint(cv.ellipse(R(-6.2, -2.4), 4.6, 5.4), hair)
        cv.paint(cv.ellipse(R(-6.0, 3.6), 3.6, 4.2), hair)
        cv.paint(cv.poly([R(-9.8, -1.0), R(-7.4, -4.0), R(-8.4, 1.0)]), hair)


def hair_front(cv, g, p, style, hair):
    R = head_R(g)
    if style == "tonsure":  # and the ring comes round the front as a narrow band at the brow, with the crown bare above it
        cv.paint(cv.poly([R(-1.4, -3.9), R(2.6, -4.2), R(5.0, -3.6), R(5.3, -2.0), R(2.4, -2.6), R(-1.0, -2.2)]), hair, hi=0.35, lo=-0.15)
    if style == "mohawk":  # a tall ridge from the brow to the nape, in points
        ridge = [(3.8, -4.6), (3.0, -8.2), (1.2, -6.6), (0.2, -10.6), (-1.6, -7.2), (-3.2, -10.2), (-4.6, -6.6), (-7.0, -8.0), (-7.6, -3.4),
                 (-6.0, -0.5), (-4.4, -3.2), (-2.4, -5.0), (0.4, -5.6)]
        cv.paint(cv.poly([R(*q) for q in ridge]), hair, hi=0.3, lo=-0.15)
    if style in CAP_HAIR:
        cap = [(-6.0, 2.3), (-6.3, -2.3), (-4.6, -5.5), (-1.4, -6.8), (2.3, -6.4), (4.7, -4.4), (5.3, -3.3), (3.2, -3.6),
               (0.9, -3.3), (-1.4, -2.0), (-2.6, 0.5), (-4.1, 2.6)]
        cv.paint(cv.poly([R(*q) for q in cap]), hair, hi=0.35, lo=-0.15)
        if style == "long":
            cv.paint(cv.poly([R(-1.6, -3.2), R(0.7, -3.8), R(0.2, 4.6), R(-2.2, 3.6)]), hair, hi=0.35, lo=-0.15)
        elif style == "short":
            cv.paint(cv.poly([R(-1.6, -2.7), R(0.2, -3.1), R(-0.4, 1.6), R(-1.8, 1.3)]), hair, hi=0.35, lo=-0.15)
        elif style == "straight":  # the parting, and a lock down in front of the ear
            cv.paint(cv.poly([R(-1.8, -3.4), R(0.4, -3.8), R(-0.1, 6.6), R(-2.4, 5.4)]), hair, hi=0.35, lo=-0.15)
            for k in range(5):
                q = R(0.9 - 0.15 * k, -6.2 + k * 0.7)
                cv.dot(q[0], q[1], hair[3])
        elif style == "bob":  # a fringe, straight across
            cv.paint(cv.poly([R(-0.2, -3.6), R(4.8, -3.6), R(5.3, -1.4), R(2.0, -1.2), R(-0.8, 0.4)]), hair, hi=0.35, lo=-0.15)
        elif style == "pigtails":
            cv.paint(cv.poly([R(0.4, -3.4), R(4.8, -3.4), R(4.4, -1.6), R(1.4, -1.8)]), hair, hi=0.35, lo=-0.15)
        elif style == "wavy":  # a side parting, the front lock falling in a wave
            cv.paint(cv.poly([R(-1.8, -3.4), R(1.4, -3.8), R(1.9, 2.4), R(-0.2, 7.2), R(-2.2, 5.8)]), hair, hi=0.35, lo=-0.15)
            for k in range(4):
                q = R(2.6 - 0.4 * k, -6.0 + k * 0.8)
                cv.dot(q[0], q[1], hair[3])
        elif style == "updo":  # a high bun, with a strand wound round it
            cv.paint(cv.ellipse(R(-2.8, -7.8), 4.0, 3.4), hair, hi=0.35, lo=-0.15)
            for k in range(3):
                q = R(-4.4 + 2.0 * k, -9.6 + 0.6 * k)
                cv.dot(q[0], q[1], hair[3])
        elif style == "wild":  # tufts standing up
            for tri in (((-2.2, -6.2), (0.0, -6.6), (-1.6, -10.4)), ((1.2, -6.0), (3.4, -5.2), (3.0, -9.4)), ((-5.2, -4.8), (-3.2, -6.2), (-6.2, -9.0))):
                cv.paint(cv.poly([R(*q) for q in tri]), hair, hi=0.3, lo=-0.15)
    brow = hair[2] if hair[0][0] + hair[0][1] > 400 else hair[1]
    for q in ((2.4, -3.0), (3.3, -3.0), (4.2, -2.6)):
        r = R(*q)
        cv.dot(r[0], r[1], brow)


def hat(cv, g, p, style, colname, trim_ramp=None):
    if style == "none":
        return
    R = head_R(g)
    rot = g["hrot"]
    col = COLORS.get(colname, COLORS["blue"])
    main, trim = col["main"], trim_ramp or col["trim"]
    if style == "circlet":
        cv.paint(cv.capsule(R(-5.3, -3.1), R(4.4, -4.2), 0.8), trim, inner_outline=False)
        cv.paint(cv.ellipse(R(4.2, -4.1), 1.2, 1.2), SAPPHIRE, inner_outline=False)
        return
    if style == "hood":
        hood = cv.ellipse(R(-1.4, -0.9), 7.6, 8.2, math.radians(rot))
        drape = cv.poly([R(-7.9, 1), R(-8.6, 10.5), R(-1.8, 12.6), R(3.0, 9.8), R(2.0, 4.6)])
        opening = cv.ellipse(R(2.8, 1.5), 4.6, 6.6, math.radians(rot))[0]
        rim = cv.ellipse(R(2.8, 1.5), 5.6, 7.6, math.radians(rot))[0]
        m = (hood[0] | drape[0]) & ~opening
        s = np.where(hood[0], hood[1], drape[1])
        cv.paint((m, s), main, hi=0.4, lo=-0.15)
        rm = m & rim
        cv.px[rm, :3] = trim[1]
        cv.px[rm & (s < -0.1), :3] = trim[2]
        return
    if style == "horned":  # an iron helm with a horn on each side
        for pts in (((-3.0, -3.4), (-5.6, -8.0), (-5.0, -12.2)), ((0.6, -3.2), (1.0, -7.6), (3.4, -11.6))):
            cv.paint(limb([R(*q) for q in pts], [2.0, 1.5, 0.5]), BONE, inner_outline=False)
        cv.paint(cv.poly(arc(R, -0.9, -3.0, 6.2, 4.8, 180, 360, 12)), IRON, hi=0.35, lo=-0.15)
        cv.paint(cv.capsule(R(-7.0, -2.8), R(4.9, -3.8), 0.95), trim, inner_outline=False)
        cv.paint(cv.capsule(R(4.9, -3.8), R(5.4, 0.2), 0.7), trim, inner_outline=False)
        return
    if style == "skull":  # a band of bone with spikes and a skull at the front
        cv.paint(cv.capsule(R(-5.8, -3.0), R(4.8, -4.2), 0.95), BONE, inner_outline=False)
        for base, tip in ((((-4.8, -3.6), (-2.6, -4.0)), (-4.4, -8.6)), (((-1.6, -4.0), (0.6, -4.3)), (-0.6, -9.8))):
            cv.paint(cv.poly([R(*base[0]), R(*base[1]), R(*tip)]), BONE, inner_outline=False)
        cv.paint(cv.ellipse(R(3.2, -5.8), 2.9, 2.7), BONE, inner_outline=False)
        cv.paint(cv.ellipse(R(3.6, -3.6), 1.7, 1.1), BONE, inner_outline=False)
        for ex in (2.4, 4.1):
            q = R(ex, -6.0)
            cv.dot(q[0], q[1], BONE[3])
        return
    if style == "laurel":  # a wreath of leaves
        for k in range(11):
            a = 188 + 150 * k / 10
            c = R(-0.8 + 5.9 * math.cos(math.radians(a)), -1.0 + 5.7 * math.sin(math.radians(a)))
            cv.paint(cv.ellipse(c, 2.2, 1.0, math.radians(a + 90 + rot + (35 if k % 2 else -35))), LEAF, inner_outline=False)
        return
    if style == "crown":  # a gold band with points, and a red stone
        cv.paint(cv.capsule(R(-5.6, -3.4), R(4.7, -4.6), 1.15), trim, inner_outline=False)
        for x, hgt in ((-4.4, 3.2), (-2.2, 4.4), (0.0, 5.2), (2.2, 4.4), (4.0, 3.2)):
            by = -3.4 - (x + 5.6) * 0.12
            cv.paint(cv.poly([R(x - 1.3, by), R(x + 1.3, by - 0.2), R(x, by - hgt)]), trim, inner_outline=False)
        q = R(2.6, -4.3)
        cv.dot(q[0], q[1], (205, 40, 60))
        return
    if style == "tiara":  # a slim band with three points and a stone
        cv.paint(cv.capsule(R(-5.4, -3.6), R(4.8, -4.7), 0.7), trim, inner_outline=False)
        for x, hgt in ((-2.4, 2.4), (0.6, 3.8), (3.4, 2.4)):
            by = -3.8 - (x + 5.4) * 0.1
            cv.paint(cv.poly([R(x - 1.0, by), R(x + 1.0, by - 0.1), R(x, by - hgt)]), trim, inner_outline=False)
        q = R(0.6, -4.6)
        cv.dot(q[0], q[1], (240, 120, 170))
        return
    if style == "flower_crown":  # a ring of flowers
        shades = [(244, 148, 184), (250, 240, 222), (250, 208, 108), (190, 150, 232)]
        for k in range(8):
            a = 196 + 144 * k / 7
            c = R(-0.8 + 6.2 * math.cos(math.radians(a)), -1.2 + 6.0 * math.sin(math.radians(a)))
            tone = shades[k % 4]
            cv.paint(cv.ellipse(c, 2.0, 2.0), ramp("#ffffff", "#%02x%02x%02x" % tone, "#%02x%02x%02x" % tuple(int(v * 0.7) for v in tone), "#403030"), hi=0.6, lo=-0.3, inner_outline=False)
            cv.dot(c[0], c[1], (252, 216, 96))
            cv.dot(c[0] + 2.0, c[1] + 1.8, LEAF[1])
        return
    if style == "headscarf":  # a kerchief over the hair, knotted behind, its ends hanging
        end = cv.capsule(R(-6.4, -1.4), R(-10.6 + p["hat_tip"], 5.0), 1.6)
        cv.paint(end, main, hi=0.5, lo=-0.1, inner_outline=False)
        cv.paint(cv.poly(arc(R, -0.9, -2.2, 6.4, 5.4, 180, 360, 12)), main, hi=0.4, lo=-0.12)
        cv.paint(cv.ellipse(R(-6.6, -1.6), 2.2, 1.8), main, hi=0.5, lo=-0.1, inner_outline=False)
        for dx, dy in ((-3.5, -5.0), (0.2, -6.6), (3.2, -5.4), (-1.2, -3.2), (-5.0, -3.0)):
            q = R(dx, dy)
            cv.dot(q[0], q[1], trim[1])
        cv.paint(cv.capsule(R(-6.2, -4.0), R(4.6, -4.4), 0.5), trim, inner_outline=False)
        return
    if style == "turban":  # wound cloth, with a jewel at the front and an end hanging behind
        end = cv.capsule(R(-5.0, -2.5), R(-8.0 + p["hat_tip"], 4.5), 1.5)
        cv.paint(end, main, hi=0.5, lo=-0.1, inner_outline=False)
        mask, sh = cv.ellipse(R(-0.9, -3.5), 6.4, 5.0, math.radians(rot))
        cv.paint((mask, sh), main, hi=0.4, lo=-0.12)
        for a, b in (((-6.0, -1.6), (1.0, -7.8)), ((-6.2, -3.6), (3.0, -7.4)), ((-4.0, 0.4), (5.2, -4.6))):
            m, _ = cv.capsule(R(*a), R(*b), 0.55)
            cv.px[m & mask, :3] = main[2]
        cv.paint(cv.ellipse(R(3.4, -4.4), 1.3, 1.3), SAPPHIRE, inner_outline=False)
        return
    if style == "mushroom":  # a toadstool cap, spotted
        cv.paint(cv.ellipse(R(-0.9, -4.9), 10.6, 4.8, math.radians(rot)), main, hi=0.45, lo=-0.12)
        spot = COLORS["ivory"]["main"]
        for c, rx_, ry_ in (((-4.2, -6.3), 1.6, 1.1), ((0.8, -7.6), 1.8, 1.2), ((5.2, -5.2), 1.3, 0.9), ((-7.6, -4.4), 1.1, 0.8), ((3.0, -4.0), 0.9, 0.7)):
            cv.paint(cv.ellipse(R(*c), rx_, ry_), spot, hi=-1.0, inner_outline=False)
        return
    bcx, bcy = -0.9, -3.9  # the brim crosses the brow, so the hat is worn down over the head
    if style == "pointy":
        rx, ry, h, w0, tip, droop = 10.5, 2.8, 14, 7.0, -10 + p["hat_tip"], 0.0
    elif style == "floppy":  # a soft hat, the point folded over and hanging far behind
        rx, ry, h, w0, tip, droop = 9.0, 2.6, 11.5, 7.8, -16 + p["hat_tip"] * 1.4, 11.0
    else:  # wide-brimmed witch hat with a drooping tip
        rx, ry, h, w0, tip, droop = 14.0, 2.6, 12.5, 5.9, -12 + p["hat_tip"] * 1.2, 3.6
    cv.paint(cv.ellipse(R(bcx, bcy), rx, ry, math.radians(-6 + rot)), main, hi=0.55, lo=-0.2)
    L, Rr = [], []
    for i in range(15):
        t = i / 14
        sx = bcx + tip * t * t - 1.0 * t
        sy = bcy - 2 - h * t + droop * t ** 3
        w = w0 * (1 - t) ** 0.95
        L.append(R(sx - w, sy))
        Rr.append(R(sx + w, sy))
    cv.paint(cv.poly(L + Rr[::-1]), main, hi=0.4, lo=-0.12)
    cv.paint(cv.capsule(R(bcx - w0 + 0.6, bcy - 2.1), R(bcx + w0 - 0.6, bcy - 2.3), 1.3), trim, inner_outline=False)


# ============================================================== weapons
# grip = how far up from the butt the hand holds it. Staffs are choked up (hand ~2/3 of the way up, like the sample
# wizard); poses may ask for a different hold. Wands/sceptres are held about a third of the way along.
WEAPONS = {
    "staff_orb": dict(L=80, grip=0.66),
    "staff_crystal": dict(L=82, grip=0.66),
    "staff_branch": dict(L=78, grip=0.65),
    "wand": dict(L=19, grip=0.32, fixed=True),
    "scepter": dict(L=30, grip=0.36, fixed=True),
    "staff_skull": dict(L=80, grip=0.66),
    "staff_moon": dict(L=82, grip=0.66),
    "staff_root": dict(L=76, grip=0.65),
    "staff_lantern": dict(L=80, grip=0.66),
    "crook": dict(L=84, grip=0.66),
    "book": dict(L=14, grip=0.5, fixed=True),
    "orb_hand": dict(L=6, grip=0.5, fixed=True),
    "bone_wand": dict(L=18, grip=0.32, fixed=True),
    "rose_wand": dict(L=22, grip=0.32, fixed=True),
    "staff_flower": dict(L=80, grip=0.66),
}


def weapon_line(p, g, kind):
    spec = WEAPONS[kind]
    st = p["staff"]
    L = spec["L"]
    if "base_at" in st:  # butt planted at a point, held at the hand
        b0 = wpt(st["base_at"])
        d = unit((g["grip"][0] - b0[0], g["grip"][1] - b0[1]))
        base = b0 if L >= 60 else add(g["grip"], d, -L * spec["grip"])
        return base, add(base, d, L), d
    if "base" in st:
        base = wpt(st["base"])
        top = wpt(st["top"])
        d = unit((top[0] - base[0], top[1] - base[1]))
        if L < 60:  # a short weapon dropped where the hand let go of it
            base = add(g["hn"], d, 2)
        top = add(base, d, L)
    else:
        d = (math.sin(math.radians(st["ang"])), -math.cos(math.radians(st["ang"])))
        gf = spec["grip"] if spec.get("fixed") else st.get("grip", spec["grip"])
        base = add(g["grip"], d, -L * gf)
        top = add(base, d, L)
    return base, top, d


def head_point(p, g, kind):
    """Where the gem sits (the anchor for spell effects)."""
    a, b, d = weapon_line(p, g, kind)
    perp = (-d[1], d[0])
    return {"staff_orb": add(b, d, 1.5), "staff_crystal": add(b, d, 4.0), "staff_branch": add(add(b, d, 0.5), perp, -3.6),
            "wand": add(b, d, 0.5), "scepter": add(b, d, 2.6), "staff_skull": add(b, d, 7.5), "staff_moon": add(add(b, d, 3.6), perp, 1.9),
            "staff_root": add(b, d, 3.6), "staff_lantern": add(b, d, 5.2), "crook": add(add(b, d, 1.0), perp, -6.4),
            "book": add(a, d, 5.5), "orb_hand": add(a, d, 5.5), "bone_wand": add(b, d, 1.6),
            "rose_wand": add(b, d, 1.4), "staff_flower": add(b, d, 4.0)}[kind]


def weapon(cv, g, p, kind):
    if not p["staff"]:
        return
    a, b, d = weapon_line(p, g, kind)
    perp = (-d[1], d[0])
    if kind == "staff_orb":
        cv.paint(cv.capsule(a, b, 1.25), WOODS["oak"], hi=0.5, lo=-0.1)
        c0 = add(b, d, -5)
        cv.paint(cv.capsule(add(c0, perp, 1.0), add(b, perp, 3.2), 1.0), WOODS["oak"])
        cv.paint(cv.capsule(add(c0, perp, -1.0), add(b, perp, -3.2), 1.0), WOODS["oak"])
    elif kind == "staff_crystal":
        cv.paint(cv.capsule(a, b, 1.2), WOODS["dark"], hi=0.5, lo=-0.1)
        c0 = add(b, d, -4)
        cv.paint(cv.capsule(add(c0, perp, 0.8), add(add(b, d, 1.5), perp, 2.8), 0.85), WOODS["dark"])
        cv.paint(cv.capsule(add(c0, perp, -0.8), add(add(b, d, 1.5), perp, -2.8), 0.85), WOODS["dark"])
    elif kind == "staff_branch":
        wood = WOODS["pale"]
        mid = add(add(a, d, 40), perp, 0.8)
        cv.paint(cv.capsule(a, mid, 1.4), wood, hi=0.5, lo=-0.1)
        cv.paint(cv.capsule(mid, b, 1.25), wood, hi=0.5, lo=-0.1)
        for k in (18, 52):
            q = add(add(a, d, k), perp, 1.3)
            cv.dot(q[0], q[1], wood[2])
        hook1 = add(add(b, d, 3), perp, -3.5)
        hook2 = add(add(b, d, 0), perp, -6)
        cv.paint(cv.capsule(b, hook1, 1.2), wood)
        cv.paint(cv.capsule(hook1, hook2, 1.0), wood)
        cv.paint(cv.ellipse(add(add(b, d, -6), perp, 3.0), 2.5, 1.3, math.atan2(d[1], d[0]) + 0.6), LEAF)
        cv.paint(cv.ellipse(add(add(b, d, -10), perp, -2.5), 2.3, 1.2, math.atan2(d[1], d[0]) - 0.6), LEAF)
    elif kind == "wand":
        cv.paint(cv.capsule(a, b, 0.9), WOODS["dark"], hi=0.5, lo=-0.1)
        cv.paint(cv.capsule(add(a, d, 0.5), add(a, d, 3.0), 1.2), GOLD, inner_outline=False)   # pommel below the fist
    elif kind == "scepter":
        cv.paint(cv.capsule(a, b, 1.0), GOLD, hi=0.5, lo=-0.1)
        cv.paint(cv.capsule(add(a, d, -0.5), add(a, d, 1.5), 1.8), GOLD)
        ring = add(b, d, 2.6)
        cv.paint(cv.ellipse(ring, 3.4, 3.4), GOLD)
        hole = cv.ellipse(ring, 2.2, 2.2)[0]
        cv.px[hole] = 0
        cv.paint(cv.capsule(add(ring, d, 3.0), add(ring, d, 4.2), 0.7), GOLD, inner_outline=False)
    elif kind == "staff_skull":
        cv.paint(cv.capsule(a, b, 1.25), WOODS["dark"], hi=0.5, lo=-0.1)
        sk = add(b, d, 1.0)
        cv.paint(cv.ellipse(sk, 3.3, 3.0), BONE, inner_outline=False)
        cv.paint(cv.ellipse(add(sk, d, -2.8), 1.9, 1.2), BONE, inner_outline=False)
        for o in (-1.2, 1.2):
            q = add(add(sk, d, 0.2), perp, o)
            cv.dot(q[0], q[1], BONE[3])
    elif kind == "staff_moon":
        cv.paint(cv.capsule(a, b, 1.2), WOODS["oak"], hi=0.5, lo=-0.1)
        c = add(b, d, 3.6)
        outer = cv.ellipse(c, 4.8, 4.8)
        cut = cv.ellipse(add(c, perp, 2.4), 4.0, 4.0)[0]
        cv.paint((outer[0] & ~cut, outer[1]), SILVER, hi=0.4, lo=-0.1)
    elif kind == "staff_root":
        wood = WOODS["pale"]
        cv.paint(limb([a, add(add(a, d, 30), perp, 1.2), add(add(a, d, 56), perp, -0.8), b], [1.5, 1.8, 1.6, 1.3]), wood, hi=0.5, lo=-0.1)
        for k in (14, 44):
            q = add(add(a, d, k), perp, 1.6)
            cv.dot(q[0], q[1], wood[3])
        for o, hgt in ((-4.2, 8.0), (4.2, 8.0), (0.0, 9.5)):  # roots curling up round the gem
            cv.paint(limb([add(b, d, -3.0), add(add(b, d, 2.0), perp, o * 0.9), add(add(b, d, hgt), perp, o * 0.45)], [1.4, 1.1, 0.5]), wood, inner_outline=False)
    elif kind == "staff_lantern":
        cv.paint(cv.capsule(a, b, 1.2), WOODS["dark"], hi=0.5, lo=-0.1)
        cv.paint(cv.capsule(add(b, d, 0.5), add(b, d, 1.5), 2.6), IRON, inner_outline=False)
        base0 = add(b, d, 1.5)
        for o in (-3.0, 3.0):
            cv.paint(cv.capsule(add(base0, perp, o), add(add(base0, d, 8.0), perp, o), 0.55), IRON, inner_outline=False)
        cv.paint(cv.poly([add(add(base0, d, 8.0), perp, -3.4), add(add(base0, d, 8.0), perp, 3.4), add(add(base0, d, 11.0), perp, 0.0)]), IRON, inner_outline=False)
        cv.paint(cv.capsule(add(base0, d, 8.4), add(base0, d, 9.6), 0.6), IRON, inner_outline=False)
    elif kind == "crook":
        wood = WOODS["pale"]
        cv.paint(cv.capsule(a, add(b, d, -3), 1.35), wood, hi=0.5, lo=-0.1)
        cv.paint(limb([add(b, d, -3), add(b, d, 2.5), add(add(b, d, 5.4), perp, -2.6), add(add(b, d, 3.8), perp, -6.0), add(add(b, d, 0.5), perp, -6.4)],
                      [1.35, 1.25, 1.1, 1.0, 0.9]), wood, hi=0.5, lo=-0.1)
        q = add(add(a, d, 18), perp, 1.4)
        cv.dot(q[0], q[1], wood[3])
        cv.paint(cv.capsule(add(add(b, d, 0.5), perp, -6.4), add(add(b, d, -1.0), perp, -6.4), 1.3), LEATHER, inner_outline=False)  # a cord
    elif kind == "book":  # a closed book held up, a clasp on the cover
        c = add(a, d, 5.5)
        pts = [add(add(c, d, -7.0), perp, -5.2), add(add(c, d, 7.0), perp, -5.2), add(add(c, d, 7.0), perp, 5.2), add(add(c, d, -7.0), perp, 5.2)]
        cv.paint(cv.poly(pts), LEATHER, hi=0.5, lo=-0.1)
        for sx in (-7.0, 7.0):  # metal corners
            for sy in (-5.2, 5.2):
                cv.paint(cv.ellipse(add(add(c, d, sx), perp, sy), 1.5, 1.5), GOLD, inner_outline=False)
        cv.paint(cv.ellipse(c, 2.4, 2.4), RUBY, hi=0.5, lo=-0.1)  # a red stone set in the cover
        cv.paint(cv.capsule(add(add(c, d, -7.0), perp, 0.0), add(add(c, d, 7.0), perp, 0.0), 0.4), GOLD, inner_outline=False)
        cv.paint(cv.capsule(add(add(c, d, 1.0), perp, 5.2), add(add(c, d, 0.0), perp, 11.0), 0.5), RUBY, inner_outline=False)  # a ribbon bookmark hanging
        cv.paint(cv.capsule(add(add(c, d, -5.8), perp, 4.0), add(add(c, d, 5.8), perp, 4.0), 0.7), BONE, inner_outline=False)  # the pages
        cv.paint(cv.capsule(add(add(c, d, -5.2), perp, -3.4), add(add(c, d, 5.2), perp, -3.4), 0.55), GOLD, inner_outline=False)  # the spine
        cv.paint(cv.capsule(add(add(c, d, 5.0), perp, -3.0), add(add(c, d, 5.0), perp, 3.2), 0.5), GOLD, inner_outline=False)
    elif kind == "orb_hand":  # claws of gold holding a sphere in the palm
        for o in (-2.4, 0.0, 2.4):
            cv.paint(limb([add(a, d, 0.5), add(add(a, d, 2.2), perp, o), add(add(a, d, 4.4), perp, o * 1.2)], [0.8, 0.7, 0.45]), GOLD, inner_outline=False)
    elif kind == "rose_wand":  # a stem with two leaves and a rose
        cv.paint(cv.capsule(a, b, 0.8), LEAF, hi=0.5, lo=-0.1)
        for k, o in ((6, 1.0), (11, -1.0)):
            q = add(add(a, d, k), perp, o * 2.0)
            cv.paint(cv.ellipse(q, 2.0, 0.9, math.atan2(d[1], d[0]) + 0.7 * o), LEAF, inner_outline=False)
        bloom = add(b, d, 1.0)
        cv.paint(cv.ellipse(bloom, 3.0, 2.6), ROSE, hi=0.5, lo=-0.1)
        cv.paint(cv.ellipse(add(bloom, d, 0.6), 1.7, 1.5), ROSE, hi=0.1, lo=-0.4, inner_outline=False)
    elif kind == "staff_flower":  # a slender stalk with leaves, and a flower of five petals round the light
        wood = WOODS["pale"]
        cv.paint(limb([a, add(add(a, d, 40), perp, 0.8), b], [1.4, 1.3, 1.2]), wood, hi=0.5, lo=-0.1)
        for k, o in ((22, 1.0), (46, -1.0)):
            cv.paint(cv.ellipse(add(add(a, d, k), perp, o * 3.0), 3.0, 1.1, math.atan2(d[1], d[0]) + 0.6 * o), LEAF, inner_outline=False)
        c = add(b, d, 4.0)
        for k in range(5):
            ang = -math.pi / 2 + 2 * math.pi * k / 5
            q = (c[0] + 4.0 * math.cos(ang), c[1] + 4.0 * math.sin(ang))
            cv.paint(cv.ellipse(q, 2.6, 2.6), ROSE, hi=0.5, lo=-0.2, inner_outline=False)
    elif kind == "bone_wand":
        cv.paint(cv.capsule(a, b, 0.95), BONE, hi=0.5, lo=-0.1)
        cv.paint(cv.ellipse(add(a, d, 0.3), 1.5, 1.5), BONE, inner_outline=False)
        cv.paint(cv.ellipse(add(b, d, -0.4), 1.4, 1.4), BONE, inner_outline=False)


# ============================================================== magic layer (key greys)
K = [KEY[0], KEY[1], KEY[2], KEY[3]]


def gem(cv, c, r, glow, shape="round", d=(0, -1)):
    if glow > 0:
        cv.glow_disc(c, (r + 2.8) * glow, K[1], 28)
        cv.glow_disc(c, (r + 1.3) * glow, K[1], 60)
    if shape == "crystal":
        perp = (-d[1], d[0])
        pts = [add(c, d, -5), add(add(c, d, -1), perp, 2.8), add(c, d, 6), add(add(c, d, -1), perp, -2.8)]
        cv.paint(cv.poly(pts), K, hi=0.25, lo=-0.2, inner_outline=False)
        q = add(add(c, d, 0), perp, 0.8)
        cv.dot(q[0], q[1], WHITE)
    else:
        cv.paint(cv.ellipse(c, r, r), K, hi=0.35, lo=-0.25, inner_outline=False)
        cv.dot(c[0] - 1, c[1] - 1, WHITE)


def fx_glowball(cv, c, r, t=0.0):
    cv.glow_disc(c, r + 5, K[1], 40)
    cv.glow_disc(c, r + 2.5, K[0], 110)
    cv.paint(cv.ellipse(c, r, r), [WHITE, K[0], K[1], K[2]], hi=0.15, lo=-0.5, inner_outline=False)
    inside = cv.ellipse(c, r - 0.5, r - 0.5)[0]
    for k, col in enumerate((K[1], K[2], K[1])):
        a = t + k * 2.1
        oc = (c[0] + math.cos(a) * r * 0.35, c[1] + math.sin(a) * r * 0.35)
        m1 = cv.ellipse(oc, r * 0.72, r * 0.5, a)[0]
        m2 = cv.ellipse((oc[0] + math.cos(a + 1.2) * r * 0.22, oc[1] + math.sin(a + 1.2) * r * 0.22), r * 0.66, r * 0.42, a)[0]
        sel = m1 & ~m2 & inside
        cv.px[sel, :3] = col
        cv.px[sel, 3] = 255


def fx_sparks(cv, c, n, spread, seed, drift=(0, 0)):
    rnd = np.random.RandomState(seed)
    cols = [K[0], K[1], K[2], WHITE]
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        dd = rnd.uniform(0.2, 1.0) * spread
        x = c[0] + math.cos(a) * dd * 1.3 + drift[0]
        y = c[1] + math.sin(a) * dd * 0.8 + drift[1]
        col = cols[rnd.randint(0, 4)]
        cv.dot(x, y, col)
        if rnd.rand() < 0.35:
            cv.dot(x + 1, y, col)


def fx_wisps(cv, c, n, reach, seed, fwd=True, thick=1.6, drift=(0, 0)):
    rnd = np.random.RandomState(seed)
    cols = [K[1], K[2], WHITE, K[2]]
    for k in range(n):
        a0 = rnd.uniform(-1.2, 1.2) if fwd else rnd.uniform(0, 2 * math.pi)
        dist = rnd.uniform(0.35, 1.0) * reach
        curl = rnd.choice([-1, 1]) * rnd.uniform(0.8, 1.8)
        col = cols[rnd.randint(0, 4)]
        L = rnd.uniform(0.25, 0.5) * reach
        pts = []
        for s in range(9):
            t = s / 8
            ang = a0 + curl * t
            rr = dist + L * t
            pts.append((c[0] + math.cos(ang) * rr + drift[0], c[1] + math.sin(ang) * rr * 0.75 + drift[1]))
        for s in range(8):
            mm, _ = cv.capsule(pts[s], pts[s + 1], thick * (1 - s / 8) + 0.3)
            cv.px[mm, :3] = col
            cv.px[mm, 3] = 255


def fx_trail(cv, pts):
    """The stroke the weapon tip is drawing: newest point first, fading to the tail."""
    n = len(pts)
    for s in range(n - 1):
        k = s / max(n - 2, 1)
        col = WHITE if k < 0.2 else K[0] if k < 0.45 else K[1] if k < 0.75 else K[2]
        mm, _ = cv.capsule(pts[s], pts[s + 1], 1.5 * (1 - k) + 0.4)
        cv.px[mm, :3] = col
        cv.px[mm, 3] = 255


def fx_blast(cv, c, length, spread=34, ang=0.0):
    if ang == 0:
        length = max(12, min(length, W - 4 - c[0]))  # keep it inside the frame
    spikes = [(-spread, 0.55), (-24, 0.8), (-12, 0.95), (0, 1.0), (12, 0.92), (24, 0.75), (spread, 0.5)]
    pts = [(c[0], c[1] - 9)]
    for i, (a, k) in enumerate(spikes):
        ar = math.radians(a)
        pts.append((c[0] + math.cos(ar) * length * k, c[1] + math.sin(ar) * length * k * 0.55))
        mid = math.radians(a + (6 if i < len(spikes) - 1 else 0))
        pts.append((c[0] + math.cos(mid) * length * 0.38, c[1] + math.sin(mid) * length * 0.38 * 0.55))
    pts.append((c[0], c[1] + 9))
    if ang:
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        pts = [(c[0] + (x - c[0]) * ca - (y - c[1]) * sa, c[1] + (x - c[0]) * sa + (y - c[1]) * ca) for x, y in pts]
    for sc, col in ((1.0, K[2]), (0.82, K[1]), (0.58, WHITE)):
        mm, _ = cv.poly([(c[0] + (x - c[0]) * sc, c[1] + (y - c[1]) * sc) for x, y in pts])
        cv.px[mm, :3] = col
        cv.px[mm, 3] = 255


def fx_beam(cv, c, ang, length, width, t=0.0):
    d = (math.cos(math.radians(ang)), math.sin(math.radians(ang)))
    e = add(c, d, length)
    w = width * (1 + 0.15 * math.sin(t * 7))
    for k, col in ((1.0, K[2]), (0.68, K[1]), (0.36, WHITE)):
        mm, _ = cv.capsule(c, e, w * k)
        cv.px[mm, :3] = col
        cv.px[mm, 3] = 255
    cv.glow_disc(c, w + 4, K[1], 50)


def fx_ring(cv, c, rx, ry, thick):
    for th, col in ((thick, K[2]), (thick * 0.5, WHITE)):
        outer = cv.ellipse(c, rx, ry)[0]
        inner = cv.ellipse(c, max(rx - th, 0.5), max(ry - th * ry / rx, 0.5))[0]
        mm = outer & ~inner
        cv.px[mm, :3] = col
        cv.px[mm, 3] = 255
        rx, ry = rx - thick * 0.25, ry - thick * 0.25 * ry / rx


def fx_stars(cv, c, t, n=3, rx=8, ry=3):
    for k in range(n):
        a = t + 2 * math.pi * k / n
        x, y = c[0] + math.cos(a) * rx, c[1] + math.sin(a) * ry
        cv.dot(x, y, WHITE)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.dot(x + dx, y + dy, K[0] if math.sin(a) > 0 else K[1])
            cv.dot(x + 2 * dx, y + 2 * dy, K[1] if math.sin(a) > 0 else K[2])


def fx_rise(cv, c, n, h, seed, t, w=8):
    rnd = np.random.RandomState(seed)
    for i in range(n):
        x = c[0] + rnd.uniform(-w, w)
        y = c[1] - ((rnd.rand() + t) % 1.0) * h
        cv.dot(x, y, [WHITE, K[0], K[1], K[1]][rnd.randint(0, 4)])


def fx_burst(cv, c, r, ang=10.0):
    pts = []
    n = 10
    for i in range(n * 2):
        a = math.radians(ang + i * 180 / n)
        rr = r * (1.0 if i % 4 == 0 else 0.8 if i % 2 == 0 else 0.34)
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr * 0.85))
    for sc, col in ((1.0, K[2]), (0.8, K[1]), (0.55, WHITE)):
        mm, _ = cv.poly([(c[0] + (x - c[0]) * sc, c[1] + (y - c[1]) * sc) for x, y in pts])
        cv.px[mm, :3] = col
        cv.px[mm, 3] = 255


def anchor(at, p, g, kind, kw):
    if at == "tip":
        return head_point(p, g, kind) if p["staff"] else g["hn"]
    if at == "base":
        return weapon_line(p, g, kind)[0] if p["staff"] else g["hn"]
    if at == "feet":
        return ((g["an_n"][0] + g["an_f"][0]) / 2, max(g["an_n"][1], g["an_f"][1]) + 2.5)
    if at == "abs":
        return wpt(kw["xy"])
    pt = {"hand": g["hf"], "nhand": g["hn"], "head": g["hc"], "body": g["chest"]}[at]
    off = kw.get("off", (0, 0))
    return (pt[0] + off[0], pt[1] + off[1])


def magic(cv, g, p, extra, kind, frame):
    if p["staff"] and not p.get("no_gem"):
        a, b, d = weapon_line(p, g, kind)
        c = head_point(p, g, kind)
        glow = p["staff"].get("glow", 1.0)
        r = {"staff_orb": 3.3, "staff_crystal": 3.0, "staff_branch": 1.9, "wand": 1.6, "scepter": 1.7, "staff_skull": 2.2, "staff_moon": 2.0,
             "staff_root": 3.0, "staff_lantern": 2.6, "crook": 1.9, "book": 1.8, "orb_hand": 3.6, "bone_wand": 1.5, "rose_wand": 1.3, "staff_flower": 2.4}[kind]
        if kind in ("staff_branch", "wand", "bone_wand", "crook", "book", "rose_wand"):
            glow *= 0.75
        gem(cv, c, r, glow, "crystal" if kind == "staff_crystal" else "round", d)
    tip = head_point(p, g, kind) if p["staff"] else g["hn"]
    for name, kw in extra.get("fx", []):
        c = anchor(kw.get("at", "tip"), p, g, kind, kw)
        if name == "beam":
            fx_beam(cv, c, kw.get("ang", 0), kw["length"], kw["width"], t=frame)
        elif name == "ring":
            fx_ring(cv, c, kw["rx"], kw["ry"], kw.get("thick", 2.5))
        elif name == "stars":
            fx_stars(cv, c, kw["t"], kw.get("n", 3), kw.get("rx", 8), kw.get("ry", 3))
        elif name == "rise":
            fx_rise(cv, c, kw["n"], kw["h"], kw["seed"], kw["t"], kw.get("w", 8))
        elif name == "burst":
            fx_burst(cv, c, kw["r"])
        elif name == "jet":
            fx_blast(cv, c, kw["length"], spread=kw.get("spread", 20), ang=kw.get("ang", 0))
        elif name == "ball":
            fx_glowball(cv, c, kw["r"], t=frame * 0.7)
        elif name == "sparks":
            fx_sparks(cv, c, kw["n"], kw["spread"], kw["seed"], drift=kw.get("drift", (0, 0)))
        elif name == "wisps":
            fx_wisps(cv, c, kw["n"], kw["reach"], kw["seed"], fwd=kw.get("fwd", True), drift=kw.get("drift", (0, 0)))
        elif name == "blast":
            fx_blast(cv, c, kw["length"])
        elif name == "trail":  # tip positions along the stroke, from earlier phases of the loop
            pts = [tip]
            for pp in kw["poses"]:
                pts.append(head_point(pp, skeleton(pp), kind))
            fx_trail(cv, pts)
    if "motes" in extra:  # idle: a few motes rising over the open hand
        t, k = extra["motes"]
        hx, hy = g["hf"]
        for j in range(4):
            ph = t * 0.5 + j * 1.7
            fx_sparks(cv, (hx + 1, hy - 8 - 6 * ((ph * 0.8 + j * 0.37) % 1.0)), 1, 2.0, j * 7 + k // 2)


# ============================================================== shading the edges like the sample art
def selout(cv):
    """No outline ring: the layer's own edge pixels take the material's dark tones instead (darkest on the shadow
    side), the way the sample wizards are drawn. Parts too thin to spare a pixel keep their colour."""
    a = cv.px[..., 3] == 255
    out = cv.px.copy()
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
        inner = np.roll(np.roll(a, -2 * dy, 0), -2 * dx, 1)  # still solid two pixels inward
        sel = a & nb & inner
        if lit:
            out[sel, :3] = cv.edge2[sel]
        else:
            out[sel, :3] = cv.edge[sel]
    cv.px = out
    cv.apply_glows()


class PartCanvas(Canvas):
    """A canvas that can draw a cloth layer without its trim, or a trim layer without its cloth: `mode` is "all", "body" or "trim", and the trim is
    whatever is painted in the ramp `trim` (found by the ramp itself, so the drawing code is the same for all three)."""

    def __init__(self, mode="all", trim=None):
        super().__init__()
        self.edge2 = np.zeros((H, W, 3), np.uint8)
        self.mode = mode
        self.trim = trim

    def _drawn(self, is_trim):
        return self.mode == "all" or self.trim is None or is_trim == (self.mode == "trim")

    def paint(self, ms, rmp, hi=0.42, lo=-0.2, inner_outline=True, bias=0.0):
        if not self._drawn(rmp is self.trim):
            return
        super().paint(ms, rmp, hi=hi, lo=lo, inner_outline=inner_outline, bias=bias)
        self.edge2[ms[0]] = rmp[2]

    def dot(self, x, y, col, a=255):
        if not self._drawn(self.trim is not None and tuple(col) in [tuple(c) for c in self.trim]):
            return
        super().dot(x, y, col, a)
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < W and 0 <= yi < H:
            self.edge2[yi, xi] = col


# ============================================================== slot dispatch
def front_cloth(cv, g, p, o, col):
    """What hangs in front of the legs for an outfit."""
    {"coat": lambda: coat_flap(cv, g, p, col, front=True), "robe": lambda: robe_skirt(cv, g, p, col),
     "tunic": lambda: tunic_skirt(cv, g, p, col), "cloak": lambda: coat_flap(cv, g, p, col, front=True),
     "ceremonial": lambda: robe_skirt(cv, g, p, col, band=True), "rags": lambda: ragged_skirt(cv, g, p, col),
     "gothic": lambda: coat_flap(cv, g, {**p, "flap": p.get("flap", 1.0) * 1.3}, col, front=True),
     "armored": lambda: armor_skirt(cv, g, p, col), "gown": lambda: robe_skirt(cv, g, p, col, gown=True),
     "bodice": lambda: flounce_skirt(cv, g, p, col), "pelt": lambda: kilt_skirt(cv, g, p, col),
     "toga": lambda: tunic_skirt(cv, g, p, col, drop=15.0), "vest": lambda: None, "sash": lambda: None}[o]()


def back_cloth(cv, g, p, o, col):
    if o == "coat":
        coat_flap(cv, g, p, col, front=False)
    elif o == "cloak":
        cape(cv, g, p, col)
    elif o == "gothic":
        cape(cv, g, p, col, long=True)


def draw_slot(cv, slot, g, p, extra, cfg, frame):
    col = dict(COLORS[cfg["color"]])
    if slot in TRIM_SLOTS or slot in ("far_leg", "near_leg"):
        col["trim"] = TRIMS[cfg["trim"]]
    col["second"] = col["trim"]  # the cloth has no other color of its own: what is not the main color is the trim's, which is chosen
    skin = SKINS[cfg["skin"]]
    o = cfg["outfit"]
    if slot in ("far_sleeve", "far_cuff"):
        sleeve(cv, g["sh_f"], g["el_f"], g["hf"], col)
    elif slot == "far_arm":
        arm(cv, g["sh_f"], g["el_f"], g["hf"], skin)
    elif slot == "far_hand":
        hand(cv, g, p, "far", skin, cfg["weapon"])
    elif slot == "far_leg":
        trousers(cv, g, g["kn_f"], g["an_f"], col)
    elif slot == "far_bare_leg":
        bare_leg(cv, g, g["kn_f"], g["an_f"], skin)
    elif slot == "far_boot":
        boot(cv, g, g["kn_f"], g["an_f"], p["ff_ang"], cfg["boots"], skin)
    elif slot in ("back_coat", "back_trim"):
        back_cloth(cv, g, p, o, col)
    elif slot == "torso_skin":
        bare_torso(cv, g, skin)
    elif slot == "torso":
        torso(cv, g, o, col)
    elif slot == "near_leg":
        trousers(cv, g, g["kn_n"], g["an_n"], col)
    elif slot == "near_bare_leg":
        bare_leg(cv, g, g["kn_n"], g["an_n"], skin)
    elif slot == "near_boot":
        boot(cv, g, g["kn_n"], g["an_n"], p["fn_ang"], cfg["boots"], skin)
    elif slot == "front_coat":
        front_cloth(cv, g, p, o, col)
    elif slot == "belt":
        belt(cv, g, p, o, col)
    elif slot == "body_trim":
        torso(cv, g, o, col)
        front_cloth(cv, g, p, o, col)
        belt(cv, g, p, o, col)
    elif slot == "hair_back":
        hair_back(cv, g, p, cfg["hair"], HAIRS[cfg["hair_color"]])
    elif slot == "head":
        head(cv, g, skin)
    elif slot == "beard":
        beard(cv, g, p, cfg["beard"], HAIRS[cfg["beard_color"]])
    elif slot == "hair_front":
        hair_front(cv, g, p, cfg["hair"], HAIRS[cfg["hair_color"]])
    elif slot == "hat":
        hat(cv, g, p, cfg["hat"], cfg["hat_color"])
    elif slot == "hat_trim":
        hat(cv, g, p, cfg["hat"], cfg["hat_color"], trim_ramp=TRIMS[cfg["trim"]])
    elif slot == "weapon":
        weapon(cv, g, p, cfg["weapon"])
    elif slot in ("near_sleeve", "near_cuff"):
        sleeve(cv, g["sh_n"], g["el_n"], g["hn"], col)
    elif slot == "near_arm":
        arm(cv, g["sh_n"], g["el_n"], g["hn"], skin)
    elif slot == "near_hand":
        hand(cv, g, p, "near", skin, cfg["weapon"])
    elif slot == "magic":
        magic(cv, g, p, extra, cfg["weapon"], frame)


def apply_xform(px, xf, is_magic):
    """Rotate/scale/move a finished layer about an anchor (the same for every layer, so the parts stay together),
    and fade it. Nearest-neighbour, so pixels stay crisp."""
    from PIL import Image
    rot = math.radians(xf.get("rot", 0.0))
    sx, sy = xf.get("sx", 1.0), xf.get("sy", 1.0)
    ax, ay = wpt(xf.get("anchor", (0, 42)))
    dx, dy = xf.get("dx", 0.0), xf.get("dy", -0.0)
    if rot or sx != 1 or sy != 1 or dx or dy:
        c, s = math.cos(rot), math.sin(rot)
        a, b, d, e = c / sx, s / sx, -s / sy, c / sy
        tx, ty = ax + dx, ay + dy
        coeffs = (a, b, ax - (a * tx + b * ty), d, e, ay - (d * tx + e * ty))
        px = np.array(Image.fromarray(px).transform((W, H), Image.AFFINE, coeffs, resample=Image.NEAREST))
    alpha = xf.get("alpha", 1.0)
    if alpha < 1.0 and (not is_magic or xf.get("fade_magic")):
        px = px.copy()
        px[..., 3] = (px[..., 3].astype(float) * alpha).astype(np.uint8)
    return px


def render_layer(slot, pose, extra, cfg, frame):
    if slot in TRIM_SLOTS:
        cv = PartCanvas("trim", TRIMS[cfg["trim"]])
    elif slot in BODY_SLOTS:
        cv = PartCanvas("body", COLORS[cfg["hat_color" if slot == "hat" else "color"]]["trim"])
    else:
        cv = PartCanvas()
    g = skeleton(pose)
    draw_slot(cv, slot, g, pose, extra, cfg, frame)
    if slot in ("magic", "far_hand", "near_hand") or slot in TRIM_SLOTS:
        cv.apply_glows()  # light / hands: their shading is drawn by hand, no edge darkening (nor on trim, which lies on the cloth)
    else:
        selout(cv)
    if pose.get("flash") and slot != "magic":
        cv.tint((255, 255, 255), pose["flash"])
    if pose.get("xform"):
        return apply_xform(cv.px, pose["xform"], slot == "magic")
    return cv.px
