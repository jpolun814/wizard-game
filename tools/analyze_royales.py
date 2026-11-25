"""Looks across many match logs (written with matchlog=DIR by tests/tools/ai_arena.gd, or by the game) for what the AI wizards do and how it goes for them.

    python -I tools/analyze_royales.py DIR [DIR ...]

Prints, over every log found: how wizards fall (killed by a wizard, or by the world), when the first falls come, how much of each wizard's time is spent in the
open, in a skirmish, standing still, in the air; the spells the AI chose and how often each one hurt anyone within 3 seconds; and stamina held in a fight."""
import collections, glob, math, os, sys

_LAST = {}


def _thin(i, t):
    """The log may hold a wizard more often than every half second; these figures count in half seconds, so keep one row to each."""
    b = int(t // 0.5)
    last = _LAST.get(i)
    if last is not None and last[0] == b and t >= last[1]:
        return False
    _LAST[i] = (b, t)
    return True


NEAR = 500.0
HIT_WINDOW = 3.0


def load(path):
    wz = collections.defaultdict(list)    # id -> [(t, x, y, vx, vy, stamina, max, flags, goal, target, cooldown, air)]
    names, kinds = {}, {}
    casts, hits, falls, decs = [], [], [], []
    end = 0.0
    for line in open(path, encoding="utf-8", errors="ignore"):
        p = line.split()
        if len(p) < 3:
            continue
        try:
            t = float(p[0])
        except ValueError:
            continue
        end = max(end, t)
        k = p[1]
        if k == "WZ" and len(p) >= 19 and _thin(p[2], t):
            i = p[2]
            names[i], kinds[i] = p[3], p[4]
            if p[15] != "death":  # (a fallen wizard lies on in the logs)
                wz[i].append((t, float(p[6]), float(p[7]), float(p[8]), float(p[9]), float(p[12]), float(p[13]), p[14], p[16], p[17], float(p[18]), p[11] == "air"))
        elif k == "CAST" and len(p) >= 4:
            casts.append((t, p[2], p[3]))
        elif k == "HIT" and len(p) >= 7:
            hits.append((t, p[2], p[3], p[4], float(p[5])))
        elif k == "FALL" and len(p) >= 3:
            falls.append((t, p[2]))
        elif k == "DEC" and len(p) >= 5:
            decs.append((t, p[2], p[3], float(p[4]) if p[4].lstrip("-").isdigit() else 0.0))
    return dict(wz=wz, names=names, kinds=kinds, casts=casts, hits=hits, falls=falls, decs=decs, end=end)


def main():
    files = []
    for a in sys.argv[1:]:
        files += sorted(glob.glob(os.path.join(a, "**", "match_*.log"), recursive=True))
    if not files:
        print("no logs")
        return
    how = collections.Counter()
    first_fall = []
    time_in = collections.Counter()
    total = 0.0
    chosen = collections.Counter()
    landed = collections.Counter()
    stamina_fight, stamina_calm = [], []
    goals = collections.Counter()
    dealt_per_cast = collections.defaultdict(list)
    for f in files:
        log = load(f)
        if len(log["wz"]) < 2:
            continue
        # how each wizard fell: the last blow in the second before
        for t, i in log["falls"]:
            blow = [h for h in log["hits"] if h[1] == i and t - 1.5 <= h[0] <= t + 0.5]
            if not blow:
                how["no blow seen (hazard, drowned, lost)"] += 1
            else:
                h = blow[-1]
                if h[2] != "-" and h[2] != i:
                    how["a wizard (%s)" % ("a spell" if h[3] != "-" else "?")] += 1
                else:
                    how["the world or itself (%s)" % h[3]] += 1
        if log["falls"]:
            first_fall.append(min(t for t, i in log["falls"]))
        # who is near whom, sample by sample
        by_t = collections.defaultdict(dict)
        for i, rows in log["wz"].items():
            for r in rows:
                by_t[round(r[0], 1)][i] = r
        for t, ws in by_t.items():
            for i, r in ws.items():
                nearest = min((math.hypot(r[1] - o[1], r[2] - o[2]) for j, o in ws.items() if j != i), default=1e9)
                total += 0.5
                if nearest < NEAR:
                    time_in["in a skirmish"] += 0.5
                    stamina_fight.append(r[5] / max(r[6], 1.0))
                else:
                    stamina_calm.append(r[5] / max(r[6], 1.0))
                if math.hypot(r[3], r[4]) < 20.0:
                    time_in["standing still"] += 0.5
                if r[11]:
                    time_in["in the air"] += 0.5
                goals[r[8]] += 0.5
        # what the AI chose, and whether anyone was hurt by that wizard soon after
        by_wiz_hits = collections.defaultdict(list)
        for t, victim, by, with_, amount in log["hits"]:
            by_wiz_hits[by].append((t, amount))
        for t, i, choice, gap in log["decs"]:
            if choice == "-":
                continue
            chosen[choice] += 1
            soon = sum(a for tt, a in by_wiz_hits.get(i, []) if t <= tt <= t + HIT_WINDOW)
            dealt_per_cast[choice].append(soon)
            if soon > 0:
                landed[choice] += 1
    print("%d logs, %.0f wizard-seconds" % (len(files), total))
    print("\nHOW WIZARDS FELL"); [print("  %-45s %d" % kv) for kv in how.most_common()]
    if first_fall:
        print("  first fall of each match at: " + ", ".join("%.0fs" % t for t in sorted(first_fall)))
    print("\nWHERE THE TIME GOES (share of wizard-seconds)")
    for k, v in time_in.most_common():
        print("  %-20s %.0f%%" % (k, 100 * v / total))
    print("  mean stamina held: in a skirmish %.0f%%, otherwise %.0f%%" % (100 * sum(stamina_fight) / max(1, len(stamina_fight)), 100 * sum(stamina_calm) / max(1, len(stamina_calm))))
    print("  what the wizards were doing: " + ", ".join("%s %.0f%%" % (g, 100 * v / total) for g, v in goals.most_common(6)))
    print("\nWHAT THE AI CHOSE, AND HOW OFTEN THE CASTER HURT ANYONE WITHIN %.0fs (a rough measure of landing)" % HIT_WINDOW)
    print("  %-18s %6s %7s %10s" % ("spell", "chosen", "hurt", "dmg/cast"))
    for spell, n in chosen.most_common(25):
        d = dealt_per_cast[spell]
        print("  %-18s %6d %6.0f%% %10.1f" % (spell, n, 100 * landed[spell] / n, sum(d) / len(d)))


if __name__ == "__main__":
    main()
