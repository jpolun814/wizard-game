"""How much pressure the AI wizards put on a person, from the recorded games (user://play_logs/solo_*.log): how long a rival was within range, how often the
person was hit by a wizard's spell, and how the person spent the time while one was near.

    python -I tools/mine_pressure.py [folder]
"""
import collections
import glob
import os
import statistics
import sys

DEFAULT = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "wizard-game", "play_logs")
RANGE = 500.0


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    rows = []
    for path in sorted(glob.glob(os.path.join(folder, "solo_*.log"))):
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        if not lines or not lines[-1].endswith(" END") or float(lines[-1].split()[0]) < 200:
            continue
        total = float(lines[-1].split()[0])
        near_ticks = set()  # tenths of a second with a rival within RANGE
        casts, hits_by_wizard, hits_all = [], 0, 0
        rival_casts = 0
        last_spell = {}
        for line in lines:
            f = line.split(" ")
            if len(f) < 3:
                continue
            try:
                t = float(f[0])
            except ValueError:
                continue
            if f[1] == "W" and len(f) >= 10:
                try:
                    x, y = float(f[4]), float(f[5])
                except ValueError:
                    continue
                if (x * x + y * y) ** 0.5 < RANGE:
                    near_ticks.add(int(t * 4))
                spell = f[-1]
                if spell != "-" and last_spell.get(f[2]) != spell:
                    rival_casts += 1
                last_spell[f[2]] = spell
            elif f[1] == "C":
                casts.append(t)
            elif f[1] == "D":
                hits_all += 1
                if "Rival" in line:
                    hits_by_wizard += 1
        near = len(near_ticks) / 4.0
        near_casts = sum(1 for t in casts if int(t * 4) in near_ticks)
        rows.append((os.path.basename(path), total, near, hits_all, hits_by_wizard, len(casts), near_casts))
    print("%-34s %6s %7s %6s %9s %6s %10s" % ("game", "secs", "rival<%d" % RANGE, "hurts", "by wizard", "casts", "cast near"))
    for r in rows:
        print("%-34s %6.0f %6.0fs %6d %9d %6d %10d" % r)
    if rows:
        secs = sum(r[1] for r in rows)
        near = sum(r[2] for r in rows)
        print("\nA rival was within %d px for %.0f%% of the time (%.0f of %.0f s)." % (RANGE, 100 * near / secs, near, secs))
        print("Hurt events: %.1f a minute; casts: %.1f a minute; %.0f%% of your casts were with a rival near." % (60 * sum(r[3] for r in rows) / secs, 60 * sum(r[5] for r in rows) / secs, 100 * sum(r[6] for r in rows) / max(1, sum(r[5] for r in rows))))


if __name__ == "__main__":
    main()
