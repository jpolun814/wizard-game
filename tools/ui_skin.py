"""Switches the interface skin the game starts with, to try it in play.

    python tools/ui_skin.py darkages      Dark Ages UI (Hypnobius)
    python tools/ui_skin.py gothic        Gothic Pixel UI (AbyssOwl)
    python tools/ui_skin.py none          the game's own flat look (ui/theme.tres), as before
    python tools/ui_skin.py               says which one is set

It edits the one line `theme/custom` in project.godot. Close the Godot editor first if it is open (it would write the old value back). The reference pictures
(`python tools/look_compare.py`) differ under a skin, by design: update them with `--update` once a skin is chosen.
"""
import os
import re
import sys

PROJECT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "project.godot")
FILES = {"none": "res://ui/theme.tres", "darkages": "res://ui/theme_darkages.tres", "gothic": "res://ui/theme_gothic.tres"}


def main():
    text = open(PROJECT, encoding="utf-8", newline="").read()
    match = re.search(r'theme/custom="([^"]*)"', text)
    now = match.group(1) if match else ""
    if len(sys.argv) < 2:
        print("skin now: %s" % ({v: k for k, v in FILES.items()}.get(now, now)))
        return
    if sys.argv[1] not in FILES:
        sys.exit("one of: " + ", ".join(FILES))
    if not match:
        sys.exit("no theme/custom line in project.godot")
    text = text.replace(match.group(0), 'theme/custom="%s"' % FILES[sys.argv[1]], 1)
    open(PROJECT, "w", encoding="utf-8", newline="").write(text)
    print("skin: %s (%s)" % (sys.argv[1], FILES[sys.argv[1]]))


if __name__ == "__main__":
    main()
