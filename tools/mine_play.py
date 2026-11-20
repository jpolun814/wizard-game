"""Reads what a person did in their recorded games (user://play_logs/solo_*.log) for what the AI can learn from it: the spells they cast and in what order,
which pairs of casts follow each other quickly (the combos a person finds), how much damage rivals took after each cast, and what hurt them.

    python -I tools/mine_play.py [folder] [--min-seconds 200]

Only games that were played to the end (a recording with an END line and some casts) are counted. Damage to a rival is read from its maximum stamina falling
in the four seconds after the cast, for rivals within 700 px (a rough figure: it cannot tell your cast from another wizard's).
"""
import collections
import glob
import os
import re
import statistics
import sys

DEFAULT = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "wizard-game", "play_logs")
PAIR_WINDOW = 6.0
AFTER = 4.0
NEAR = 700.0


def games(folder, min_seconds):
    for path in sorted(glob.glob(os.path.join(folder, "solo_*.log"))):
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
        if not lines or not lines[-1].endswith(" END"):
            continue
        if float(lines[-1].split()[0]) < min_seconds:
            continue
        yield path, lines


def parse(lines):
    casts, hurts, rivals = [], [], collections.defaultdict(list)
    for line in lines:
        part = line.split(" ", 2)
        if len(part) < 2:
            continue
        try:
            t = float(part[0])
        except ValueError:
            continue
        kind = part[1]
        rest = part[2] if len(part) > 2 else ""
        if kind == "C":
            casts.append((t, rest.strip()))
        elif kind == "D":
            hurts.append((t, rest))
        elif kind == "W":
            f = rest.split()
            if len(f) >= 6:
                try:
                    rivals[f[0]].append((t, float(f[2]), float(f[3]), float(f[4]), float(f[5])))  # t, place from the person (x, y), stamina, maximum
                except ValueError:
                    pass
    return casts, hurts, rivals


def damage_after(rivals, t):
    """The largest fall in a nearby rival's maximum stamina in the AFTER seconds after t."""
    best = 0.0
    for track in rivals.values():
        window = [r for r in track if t <= r[0] <= t + AFTER and abs(r[1]) < NEAR]
        if len(window) >= 2:  # (r[4] is the maximum: damage lowers it)
            best = max(best, window[0][4] - min(r[4] for r in window))
    return best


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    folder = args[0] if args else DEFAULT
    min_seconds = 200.0
    if "--min-seconds" in sys.argv:
        min_seconds = float(sys.argv[sys.argv.index("--min-seconds") + 1])
    counts = collections.Counter()
    pairs = collections.Counter()
    hit = collections.defaultdict(list)
    hurt_by = collections.Counter()
    hurt_total = 0
    gaps = []
    n = 0
    for path, lines in games(folder, min_seconds):
        n += 1
        casts, hurts, rivals = parse(lines)
        for k, (t, spell) in enumerate(casts):
            counts[spell] += 1
            hit[spell].append(damage_after(rivals, t))
            if k > 0 and t - casts[k - 1][0] < PAIR_WINDOW:
                pairs[(casts[k - 1][1], spell)] += 1
            if k > 0:
                gaps.append(t - casts[k - 1][0])
        for t, rest in hurts:
            amount = int(rest.split()[0]) if rest.split() and rest.split()[0].isdigit() else 0
            hurt_total += amount
            sources = re.findall(r"@-?\d+,-?\d+ ([A-Za-z_' ]+?)(?= by:| [A-Za-z0-9_]+@|$)", rest) or ["nothing near"]
            for source in sources:
                hurt_by[source.strip()] += amount / len(sources)
    print("%d finished games read from %s\n" % (n, folder))
    print("YOUR CASTS (count, mean damage seen to a rival in the next %.0fs):" % AFTER)
    for spell, c in counts.most_common():
        print("  %-18s %3d   %.1f" % (spell, c, statistics.mean(hit[spell])))
    print("\nCASTS FOLLOWING ANOTHER WITHIN %.0fs (a pair a person reached for):" % PAIR_WINDOW)
    for (a, b), c in pairs.most_common(20):
        print("  %-18s -> %-18s %d" % (a, b, c))
    if gaps:
        print("\nTime between your casts: median %.1fs, quickest quarter under %.1fs" % (statistics.median(gaps), sorted(gaps)[len(gaps) // 4]))
    print("\nWHAT HURT YOU (damage taken, %d in all):" % hurt_total)
    for source, amount in hurt_by.most_common(15):
        print("  %-22s %d" % (source, amount))


if __name__ == "__main__":
    main()
