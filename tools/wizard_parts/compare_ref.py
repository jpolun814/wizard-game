"""Side by side with the sample wizard (art/chars/wizard): top row the sample, bottom row ours, zoomed.
Only for animations the sample has (idle, run, cast, release, hit, death, jump, fall). Use it to judge STYLE
(proportions, shading, poses) - never copy the sample's character (see docs/handoff/20_making_wizard_parts.md).
usage: python compare_ref.py out.png "idle:0,run:3,fall:0" [box=80,40,200,138] [zoom=3] [key=val ...]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from preview import char_frame  # noqa: E402
from contact_sheet import DEFAULT  # noqa: E402

REF = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "chars", "wizard")

if __name__ == "__main__":
    out, picks = sys.argv[1], sys.argv[2].split(",")
    kv = dict(a.split("=") for a in sys.argv[3:])
    box = tuple(int(v) for v in kv.pop("box", "80,40,200,138").split(","))
    z = int(kv.pop("zoom", 3))
    cfg = dict(DEFAULT, **kv)
    w, h = (box[2] - box[0]) * z, (box[3] - box[1]) * z
    sheet = Image.new("RGBA", (w * len(picks), h * 2), (56, 58, 70, 255))
    for k, pick in enumerate(picks):
        anim, i = pick.split(":")
        ref = Image.open(os.path.join(REF, f"{anim}_{i}.png")).convert("RGBA").crop(box).resize((w, h), Image.NEAREST)
        sheet.alpha_composite(ref, (k * w, 0))
        sheet.alpha_composite(char_frame(cfg, anim, int(i)).crop(box).resize((w, h), Image.NEAREST), (k * w, h))
    sheet.save(out)
    print("wrote", out)
