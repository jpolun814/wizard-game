"""Stacks part sheets into a finished character - the same thing the game would do.
Only reads the exported sheets (never the rig), so it proves the parts fit together."""
import json
import os

from PIL import Image

HAT_NO_COLOR = ("none", "circlet", "horned", "skull", "laurel", "crown", "tiara", "flower_crown")  # keep in step with parts.py
HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.join(HERE, "..", "..", "art_source", "parts_sheets")


def load_manifest(parts=PARTS):
    return json.load(open(os.path.join(parts, "manifest.json")))


def variant_key(slot, deps, cfg):
    if slot == "hat" and cfg["hat"] in HAT_NO_COLOR:
        return cfg["hat"]
    return "-".join(cfg[d] for d in deps)


def recolor(im, ramp4):
    """The magic slot is drawn in key greys; map them to a spell's ramp (same thresholds as the Godot shader)."""
    import numpy as np
    px = np.array(im)
    g = px[..., 0].astype(int)
    a = px[..., 3] > 0
    for lo, hi, col in ((247, 256, (255, 255, 255)), (213, 247, ramp4[0]), (159, 213, ramp4[1]), (99, 159, ramp4[2]),
                        (0, 99, ramp4[3])):
        sel = a & (g >= lo) & (g < hi)
        px[sel, :3] = col
    return Image.fromarray(px)


def compose_sheet(cfg, parts=PARTS, layers=False, spell=None):
    """Returns the composed sheet (and, if layers=True, the list of (slot, sheet) used).
    spell: a 4-colour ramp (or a name from the manifest's example_spells) for the magic slot."""
    man = load_manifest(parts)
    sw, sh = man["sheet_size"]
    out = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    used = []
    for s in man["slots"]:
        key = variant_key(s["name"], s["depends_on"], cfg)
        path = os.path.join(parts, s["name"], key + ".png")
        if os.path.exists(path):
            im = Image.open(path).convert("RGBA")
            if s["name"] == man.get("magic", {}).get("slot") and spell is not None:
                ramp4 = man["magic"]["example_spells"][spell] if isinstance(spell, str) else spell
                im = recolor(im, [tuple(x) for x in ramp4])
            out.alpha_composite(im)
            used.append((s["name"], im))
    return (out, used) if layers else out


def frames_of(sheet, man, anim):
    W, H = man["frame_size"]
    cols = man["columns"]
    a = man["animations"][anim]
    res = []
    for k in range(a["start"], a["start"] + a["count"]):
        x, y = (k % cols) * W, (k // cols) * H
        res.append(sheet.crop((x, y, x + W, y + H)))
    return res
