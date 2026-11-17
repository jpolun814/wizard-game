"""Every frame of some animations, one row per animation, for a quick review (no build needed).
usage: python contact_sheet.py out.png idle,run,swim [key=val ...] [spell=Fire] [scale=1]
       python contact_sheet.py out.png group:movement      (groups from poses_extra.GROUPS: movement, status, casting, polish)"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from preview import char_frame  # noqa: E402
from poses import ANIMS  # noqa: E402
from poses_extra import GROUPS  # noqa: E402

DEFAULT = dict(skin="tan", outfit="coat", color="blue", hair="short", hair_color="auburn", beard="short",
               beard_color="auburn", hat="wide", hat_color="blue", weapon="staff_orb", spell="Fire")

if __name__ == "__main__":
    out, which = sys.argv[1], sys.argv[2]
    kv = dict(a.split("=") for a in sys.argv[3:])
    z = int(kv.pop("scale", 1))
    cfg = dict(DEFAULT, **kv)
    if which.startswith("group:"):
        rows = GROUPS[which[6:]]
    else:
        names = which.split(",")
        rows = [a for a in ANIMS if a[0] in names]
    box = (40, 0, 254, 138)
    w, h = (box[2] - box[0]) * z, (box[3] - box[1]) * z
    cols = max(a[1] for a in rows)
    sheet = Image.new("RGBA", (w * cols, h * len(rows)), (44, 46, 58, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, n, fn, fps, loop) in enumerate(rows):
        for i in range(n):
            sheet.alpha_composite(char_frame(cfg, name, i).crop(box).resize((w, h), Image.NEAREST), (i * w, r * h))
        d.text((3, r * h + 2), f"{name} ({n}f, {fps}fps, {'loop' if loop else 'once'})", fill=(230, 230, 240))
        d.line([(0, r * h + h - 1), (w * cols, r * h + h - 1)], fill=(80, 84, 100))
    sheet.save(out)
    print("wrote", out)
