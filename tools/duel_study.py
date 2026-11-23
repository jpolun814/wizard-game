"""Reads the Duel logs (user://duel_logs, written by DuelLog) and sets the person's way of fighting beside the AI's.

    python -I tools/duel_study.py              every round played
    python -I tools/duel_study.py --last 10    only the last ten rounds
    python -I tools/duel_study.py --folder DIR another folder of logs (the duel check writes to duel_logs_check)

For each side it prints: rounds won, the spells cast and how often, the seconds between casts, the hits it landed per cast, the shots of the other side that came
near it (within 80 px) and how many of those struck it (the dodge rate), what it did while a shot was coming (jumped, turned, stood), the distance it kept, and how
much stamina it kept in hand. Then the same per spell: how often each spell, when cast, was followed by a hit within two seconds.
"""
import glob
import math
import os
import statistics
import sys
from collections import Counter, defaultdict

APPDATA = os.environ.get("APPDATA", "")
DEFAULT = os.path.join(APPDATA, "Godot", "app_userdata", "wizard-game", "duel_logs")
NEAR = 80.0      # a shot this close has come near enough to need dodging
HIT_AFTER = 2.0  # a hit within this long after a cast is counted to that cast


def read(path):
    rounds = {"book": {}, "p": defaultdict(list), "f": [], "c": [], "h": [], "winner": None, "level": None}
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.split()
        if len(parts) < 2:
            continue
        try:
            t = float(parts[0])
        except ValueError:
            continue
        kind = parts[1]
        if kind == "ROUND":
            rounds["level"] = parts[4] if len(parts) > 4 else None
        elif kind == "BOOK":
            rounds["book"][parts[2]] = parts[3].split("|") if len(parts) > 3 else []
        elif kind == "P":
            who = parts[2]
            x, y, vx, vy, st, mx, drawing, floor = (float(v) for v in parts[3:11])
            rounds["p"][who].append((t, x, y, vx, vy, st, mx, drawing, floor))
        elif kind == "F":
            rounds["f"].append((t, parts[2], parts[3], float(parts[4]), float(parts[5])))
        elif kind == "C":
            rounds["c"].append((t, parts[2], parts[3]))
        elif kind == "M":
            rounds["c"].append((t, parts[2], "(misfire)"))
        elif kind == "H":
            rounds["h"].append((t, parts[2], int(parts[3]), " ".join(parts[4:])))
        elif kind == "END":
            rounds["winner"] = parts[2]
    return rounds


def other(side):
    return "ai" if side == "person" else "person"


def position_at(track, t):
    """The sample of a track nearest a time (the tracks are twenty a second)."""
    if not track:
        return None
    lo, hi = 0, len(track) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if track[mid][0] < t:
            lo = mid + 1
        else:
            hi = mid
    return track[lo]


def study(rounds):
    out = {side: defaultdict(float) for side in ("person", "ai")}
    spells = {side: Counter() for side in ("person", "ai")}
    spell_hits = {side: Counter() for side in ("person", "ai")}
    gaps = {side: [] for side in ("person", "ai")}
    distance = []
    stamina = {side: [] for side in ("person", "ai")}
    reaction = {side: Counter() for side in ("person", "ai")}
    for r in rounds:
        if r["winner"] in ("person", "ai"):
            out[r["winner"]]["won"] += 1
        out["person"]["rounds"] += 1
        out["ai"]["rounds"] += 1
        last = {}
        for t, side, spell in r["c"]:
            spells[side][spell] += 1
            if side in last:
                gaps[side].append(t - last[side])
            last[side] = t
            target = other(side)
            if any(h[1] == target and 0.0 <= h[0] - t <= HIT_AFTER for h in r["h"]):
                spell_hits[side][spell] += 1
        for t, victim, amount, near in r["h"]:
            out[other(victim)]["damage"] += amount
        for side in ("person", "ai"):
            for sample in r["p"][side]:
                stamina[side].append(sample[5] / max(sample[6], 1.0))
        for a, b in zip(r["p"]["person"], r["p"]["ai"]):
            distance.append(math.hypot(a[1] - b[1], a[2] - b[2]))
        # Shots of each side that came near the other: each shot is followed by its class and owner and the time it was first near. A shot "struck" if the target
        # was hurt within 0.15 s of the shot being near.
        seen = set()
        for t, owner, cls, x, y in r["f"]:
            if owner not in ("person", "ai"):
                continue
            target = other(owner)
            me = position_at(r["p"][target], t)
            if me is None:
                continue
            gap = math.hypot(me[1] - x, (me[2] - 40.0) - y)
            key = (owner, cls, round(t * 2))  # (one shot near is one event, roughly)
            if gap < NEAR and key not in seen:
                seen.add(key)
                out[target]["shots_near"] += 1
                if any(h[1] == target and abs(h[0] - t) < 0.25 for h in r["h"]):
                    out[target]["shots_struck"] += 1
                before = position_at(r["p"][target], t - 0.3)
                if before is not None:
                    jumped = before[8] > 0.5 and me[8] < 0.5
                    turned = before[3] * me[3] < 0 and abs(me[3]) > 30
                    still = abs(me[3]) < 30 and me[8] > 0.5
                    reaction[target]["jumped" if jumped else ("turned" if turned else ("stood" if still else "kept moving"))] += 1
    return out, spells, spell_hits, gaps, distance, stamina, reaction


def main():
    folder = DEFAULT
    last = None
    args = sys.argv[1:]
    if "--folder" in args:
        folder = args[args.index("--folder") + 1]
    if "--last" in args:
        last = int(args[args.index("--last") + 1])
    paths = sorted(glob.glob(os.path.join(folder, "duel_*.log")))
    if last:
        paths = paths[-last:]
    rounds = [read(p) for p in paths]
    rounds = [r for r in rounds if r["p"]["person"] and r["p"]["ai"]]
    if not rounds:
        print("no duels in", folder)
        return
    out, spells, spell_hits, gaps, distance, stamina, reaction = study(rounds)
    print("%d rounds (AI level %s)" % (len(rounds), ", ".join(sorted({str(r["level"]) for r in rounds}))))
    for side in ("person", "ai"):
        o = out[side]
        casts = sum(spells[side].values())
        print("\n== %s: won %d of %d" % (side.upper(), o["won"], o["rounds"]))
        print("  casts %d, %.1f a round; seconds between casts: median %.2f" % (casts, casts / max(o["rounds"], 1), statistics.median(gaps[side]) if gaps[side] else float("nan")))
        print("  damage dealt %d, %.2f a cast" % (o["damage"], o["damage"] / max(casts, 1)))
        near = o["shots_near"]
        print("  the other's shots near it %d, struck %d (%.0f%% dodged)" % (near, o["shots_struck"], 100.0 * (1.0 - o["shots_struck"] / near) if near else float("nan")))
        total = sum(reaction[side].values())
        if total:
            print("  as a shot came: " + ", ".join("%s %.0f%%" % (k, 100.0 * v / total) for k, v in reaction[side].most_common()))
        print("  stamina in hand: median %.0f%%, under a quarter %.0f%% of the time" % (100.0 * statistics.median(stamina[side]), 100.0 * sum(1 for s in stamina[side] if s < 0.25) / len(stamina[side])))
        print("  spells (cast / followed by a hit): " + ", ".join("%s %d/%d" % (k, v, spell_hits[side][k]) for k, v in spells[side].most_common(12)))
    print("\ndistance between them: median %.0f px, quartiles %.0f-%.0f" % (statistics.median(distance), *statistics.quantiles(distance, n=4)[::2]))


if __name__ == "__main__":
    main()
