"""Fails (exit 1) if any frame's weapon, hat or magic layer touches the frame edge, for every weapon - effects must
never run off the frame (owner's rule: the game draws anything bigger). Run after changing poses or effects.
usage: python edge_check.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from parts import render_layer, OPTIONS  # noqa: E402
from poses import all_frames  # noqa: E402

if __name__ == "__main__":
    bad = 0
    frames = all_frames()
    for weapon in OPTIONS["weapon"]:
        cfg = {k: v[0] for k, v in OPTIONS.items()}
        cfg.update(weapon=weapon, hat="wide")
        for name, i, p, extra in frames:
            for slot in ("magic", "weapon", "hat"):
                a = render_layer(slot, p, extra, cfg, i)[..., 3] > 0
                if not a.any():
                    continue
                ys, xs = np.nonzero(a)
                if xs.min() <= 1 or xs.max() >= 252 or ys.min() <= 1:
                    bad += 1
                    print(f"EDGE {weapon:14s} {name}_{i:<3d} {slot:7s} x {xs.min()}-{xs.max()} y {ys.min()}-{ys.max()}")
    print("edge check:", "OK" if not bad else f"{bad} frames touch the edge")
    sys.exit(1 if bad else 0)
