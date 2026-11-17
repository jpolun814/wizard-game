"""Quick look without building sheets: python preview.py out.png "anim:idx,anim:idx" key=val ... [|| key=val ...]
Each '||'-separated group is one character (one row)."""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from parts import SLOTS, OPTIONS, render_layer, recolor, W, H  # noqa: E402
from poses import ANIMS  # noqa: E402

FN = {a[0]: a[2] for a in ANIMS}


def char_frame(cfg, anim, i):
    p, extra = FN[anim](i)
    acc = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for slot, _ in SLOTS:
        px = render_layer(slot, p, extra, cfg, i)
        if slot == "magic":
            px = recolor(px, cfg.get("spell", "azure"))
        acc.alpha_composite(Image.fromarray(px))
    return acc


if __name__ == "__main__":
    out, picks = sys.argv[1], [x.split(":") for x in sys.argv[2].split(",")]
    groups, cur = [], []
    for a in sys.argv[3:]:
        if a == "||":
            groups.append(cur)
            cur = []
        else:
            cur.append(a)
    groups.append(cur)
    box = (60, 6, 254, 138)
    z = 3
    w, h = (box[2] - box[0]) * z, (box[3] - box[1]) * z
    sheet = Image.new("RGBA", (w * len(picks), h * len(groups)), (56, 58, 70, 255))
    for r, grp in enumerate(groups):
        cfg = {k: v[0] for k, v in OPTIONS.items()}
        cfg.update(dict(kv.split("=") for kv in grp))
        for c, (anim, i) in enumerate(picks):
            im = char_frame(cfg, anim, int(i)).crop(box).resize((w, h), Image.NEAREST)
            sheet.alpha_composite(im, (c * w, r * h))
    sheet.save(out)
