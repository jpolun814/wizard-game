"""Compares the game's pictures with the reference pictures, to catch what no number catches: a tint that spills onto the ground, a stray circle, a pond that is
short, a spell that draws nothing.

    python tools/look_compare.py            take the pictures (needs a window; the game opens one for a minute) and compare
    python tools/look_compare.py --update   take them and keep them as the new references (do this on purpose, after looking at them)
    python tools/look_compare.py --keep DIR compare the pictures already in DIR (no game)

The pictures are compared in blocks of 16 by 16 pixels, so that particles, rain and animation (which are never the same twice) do not count: a block
counts as changed when its average brightness moved by more than BLOCK_DIFF, and a picture fails when more than MAX_CHANGED of its blocks changed. A failure
writes a picture of what differs (red), with the reference, the new one and the difference side by side, to reports/looks/. Exit code is the number that failed.
The references are in tests/reference/. A name that has no reference yet is stored as one and reported as new.
"""
import argparse
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
REFERENCE = os.path.join(ROOT, "tests", "reference")
REPORT = os.path.join(ROOT, "reports", "looks")
BLOCK = 16
BLOCK_DIFF = 14.0   # a block's average brightness must move this much (of 255) to count
MAX_CHANGED = 0.02  # more than this share of the blocks changed fails the picture
MAX_FOR = {"tutorial_start": 0.07}  # the tutorial scatters its props with dice of its own, which differ at each start


def blocks(path):
    image = Image.open(path).convert("L")
    w, h = image.size
    w, h = w - w % BLOCK, h - h % BLOCK
    data = np.asarray(image.crop((0, 0, w, h)), dtype=np.float32)
    return data.reshape(h // BLOCK, BLOCK, w // BLOCK, BLOCK).mean(axis=(1, 3))


def compare(name, taken, reference):
    a, b = blocks(reference), blocks(taken)
    if a.shape != b.shape:
        return 1.0, None
    changed = np.abs(a - b) > BLOCK_DIFF
    share = float(changed.mean())
    if share <= MAX_FOR.get(name, MAX_CHANGED):
        return share, None
    os.makedirs(REPORT, exist_ok=True)
    old, new = Image.open(reference).convert("RGB"), Image.open(taken).convert("RGB")
    mark = Image.fromarray((np.kron(changed, np.ones((BLOCK, BLOCK))) * 255).astype(np.uint8)).convert("RGB")
    mark = Image.composite(Image.new("RGB", mark.size, (255, 0, 0)), Image.new("RGB", mark.size, (0, 0, 0)), mark.convert("L"))
    mark = mark.resize(new.size)
    sheet = Image.new("RGB", (new.width * 3, new.height))
    sheet.paste(old, (0, 0))
    sheet.paste(new, (new.width, 0))
    sheet.paste(Image.blend(new, mark, 0.5), (new.width * 2, 0))
    path = os.path.join(REPORT, name + "_diff.png")
    sheet.save(path)
    return share, path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--update", action="store_true")
    parser.add_argument("--keep", default="")
    options = parser.parse_args()
    out = options.keep or os.path.join(ROOT, "reports", "looks_taken")
    if not options.keep:
        shutil.rmtree(out, ignore_errors=True)
        command = [GODOT, "--path", ROOT, "--audio-driver", "Dummy", "--fixed-fps", "60", "res://tests/looks/reference_shots.tscn", "--", "out=" + out]
        done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT, timeout=600, stdin=subprocess.DEVNULL)
        text = done.stdout.decode("utf-8", "replace")
        if "SCRIPT ERROR" in text:
            print("SCRIPT ERROR while taking the pictures:\n" + "\n".join(l for l in text.splitlines() if "SCRIPT ERROR" in l)[:1500])
            return 1
    os.makedirs(REFERENCE, exist_ok=True)
    failed = 0
    names = sorted(f for f in os.listdir(out) if f.endswith(".png"))
    if not names:
        print("no pictures were taken")
        return 1
    for name in names:
        taken = os.path.join(out, name)
        reference = os.path.join(REFERENCE, name)
        if options.update or not os.path.exists(reference):
            shutil.copyfile(taken, reference)
            print("%-28s %s" % (name[:-4], "kept as the reference" if options.update else "NEW: kept as the reference"))
            continue
        share, diff = compare(name[:-4], taken, reference)
        if diff:
            failed += 1
            print("%-28s DIFFERS: %.1f%% of the picture changed: %s" % (name[:-4], share * 100, diff))
        else:
            print("%-28s same (%.1f%% moved)" % (name[:-4], share * 100))
    print("%d of %d pictures differ" % (failed, len(names)))
    return failed


if __name__ == "__main__":
    sys.exit(main())
