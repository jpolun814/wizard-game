"""The feathers of Featherfall (scripts/spells/featherfall.gd): one pixel-art feather in three poses (turning as it drifts), 7x13 pixels each, side by side.
Run it from anywhere:

    python tools/wizard_parts/feathers.py

It writes art/fx/feathers.png. Never edit the PNG by hand: change this file and run it. a = the vane, b = its bright edge, c = the quill and the shade.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
W, H = 7, 13
COLORS = {"a": "#e8eef8", "b": "#ffffff", "c": "#9aa8c4"}
POSES = [
    [".....b.", "....bab", "...baab", "..baaac", "..baaac", ".baaacc", ".baaac.", "baaacc.", "baacc..", ".bacc..", "..cc...", ".c.....", "c......"],
    ["...b...", "..bab..", "..baa..", ".baaa..", ".baac..", ".baac..", ".baac..", ".baac..", "..bac..", "..bac..", "...c...", "...c...", "...c..."],
    ["b......", "bab....", "baab...", "caaab..", "caaab..", "ccaaab.", ".caaab.", ".ccaaab", "..ccaab", "..ccab.", "...cc..", ".....c.", "......c"],
]


def main() -> None:
    sheet = Image.new("RGBA", (W * len(POSES), H), (0, 0, 0, 0))
    for k, rows in enumerate(POSES):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in COLORS:
                    sheet.putpixel((k * W + x, y), Image.new("RGB", (1, 1), COLORS[ch]).getpixel((0, 0)) + (255,))
    sheet.save(os.path.join(ROOT, "art", "fx", "feathers.png"))


main()
