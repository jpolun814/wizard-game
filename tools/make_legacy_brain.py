"""Makes tests/legacy_brain/: a frozen copy of the AI wizards' brain, every class renamed with an "Old" in front, so that a changed brain can be set
against the one it replaced (tests/tools/ai_arena.tscn). Run it ONCE, from the commit whose brain is to be the opponent; do not run it again, or the
opponent moves.

    python tools/make_legacy_brain.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "scripts", "brain")
OUT = os.path.join(ROOT, "tests", "legacy_brain")
FILES = ["wizard_brain", "sky_brain"] + ["brain_" + n for n in "chant combat danger explore gates hand mend moves sight strokes travel".split()]
CLASSES = ["WizardBrain", "SkyBrain"] + ["Brain" + n.capitalize() for n in "chant combat danger explore gates hand mend moves sight strokes travel".split()]

os.makedirs(OUT, exist_ok=True)
pattern = re.compile(r"\b(" + "|".join(CLASSES) + r")\b")
for name in FILES:
    with open(os.path.join(SOURCE, name + ".gd"), encoding="utf-8", newline="") as f:
        text = f.read()
    text = pattern.sub(lambda m: "Old" + m.group(1), text)
    with open(os.path.join(OUT, "old_" + name + ".gd"), "w", encoding="utf-8", newline="") as f:
        f.write(text)
print("wrote", len(FILES), "files to", OUT)
