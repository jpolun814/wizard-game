"""Reads the logs of tests/tools/ai_arena.tscn duels (log=FILE) and prints, for each spell, how often it was cast and how much damage came soon after it
(the damage the other wizard took within a few seconds of the cast): a rough yield, for finding the spells the AI wastes its strength on.

    python tools/ai_yield.py DIR       (the folder holds d<seed>.log and res<seed>.jsonl)
"""
import collections
import glob
import json
import os
import sys

WINDOW = 2.5
folder = sys.argv[1]
casts = collections.Counter()
damage = collections.Counter()
for path in glob.glob(os.path.join(folder, "res*.jsonl")):
    seed = os.path.basename(path)[3:-6]
    result = json.loads(open(path).readline())
    old = result["old"][0] if result["old"] else -1
    events = []
    for line in open(os.path.join(folder, "d%s.log" % seed)):
        p = line.split()
        if p[0] == "C":
            events.append(("C", float(p[1]), int(p[2]), " ".join(p[3:])))
        elif p[0] == "D":
            events.append(("D", float(p[1]), int(p[2]), int(p[3])))
    for kind, t, seat, what in events:
        if kind == "C":
            casts[what] += 1
        else:
            by = [e for e in events if e[0] == "C" and e[2] != seat and t - WINDOW <= e[1] <= t]
            if by:
                damage[by[-1][3]] += what
rows = sorted(casts, key=lambda s: -damage[s] / max(1, casts[s]))
print("%-16s %5s %7s %6s" % ("spell", "casts", "damage", "per cast"))
for s in rows:
    if casts[s] >= 3:
        print("%-16s %5d %7d %6.1f" % (s, casts[s], damage[s], damage[s] / casts[s]))
