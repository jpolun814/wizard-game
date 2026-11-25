"""What the wizards that last longest do differently, from match logs: for each wizard of each match, its place (order of falling) and some habits, then the habits of
the first three to fall set beside the last three. One match is a set of files (its worlds); give the folders that hold them.

    python -I tools/who_wins.py DIR [DIR ...]"""
import collections, glob, math, os, re, statistics, sys

_LAST = {}


def _thin(i, t):
    """The log may hold a wizard more often than every half second; these figures count in half seconds, so keep one row to each."""
    b = int(t // 0.5)
    last = _LAST.get(i)
    if last is not None and last[0] == b and t >= last[1]:
        return False
    _LAST[i] = (b, t)
    return True



def main():
    rows = []
    for a in sys.argv[1:]:
        by_match = collections.defaultdict(list)
        for f in glob.glob(os.path.join(a, "**", "match_*.log"), recursive=True):
            m = re.sub(r"_w\d+\.log$", "", f)
            by_match[m].append(f)
        for m, files in by_match.items():
            offset, stat, fell = 0.0, collections.defaultdict(lambda: collections.Counter()), {}
            for f in sorted(files, key=lambda x: int(re.search(r"_w(\d+)\.log$", x).group(1))):
                wz = collections.defaultdict(list)
                end = 0.0
                for line in open(f, encoding="utf-8", errors="ignore"):
                    p = line.split()
                    if len(p) < 3:
                        continue
                    try:
                        t = float(p[0])
                    except ValueError:
                        continue
                    end = max(end, t)
                    if p[1] == "WZ" and len(p) >= 19 and _thin(p[2], t):
                        if p[15] != "death":
                            wz[round(t, 1)].append((p[2], float(p[6]), float(p[7]), float(p[8]), float(p[9]), float(p[12]), float(p[13]), p[3]))
                    elif p[1] == "HIT" and len(p) >= 7:
                        stat[p[2]]["taken"] += float(p[5])
                        if p[3] != "-":
                            stat[p[3]]["dealt"] += float(p[5])
                    elif p[1] == "CAST":
                        stat[p[2]]["casts"] += 1
                    elif p[1] == "FALL":
                        fell[p[2]] = offset + t
                for t, ws in wz.items():
                    for i, r in enumerate(ws):
                        s = stat[r[0]]
                        s["time"] += 0.5
                        s["stamina"] += 0.5 * r[5] / max(r[6], 1.0)
                        d = min((math.hypot(r[1] - o[1], r[2] - o[2]) for j, o in enumerate(ws) if j != i), default=1e9)
                        if d < 500.0:
                            s["near"] += 0.5
                            if r[5] < 0.2 * max(r[6], 1.0):
                                s["dry"] += 0.5
                        if math.hypot(r[3], r[4]) < 20.0:
                            s["still"] += 0.5
                offset += end
            order = sorted(stat, key=lambda i: fell.get(i, 1e9))
            for place, i in enumerate(order, 1):
                s = stat[i]
                if s["time"] > 20:
                    rows.append((place, len(order), s))
    if not rows:
        print("no data")
        return
    def habit(group):
        n = len(group)
        t = sum(s["time"] for _, _, s in group)
        near = max(1.0, sum(s["near"] for _, _, s in group))
        return dict(n=n, dealt=sum(s["dealt"] for _, _, s in group) / n, taken=sum(s["taken"] for _, _, s in group) / n, casts_min=60 * sum(s["casts"] for _, _, s in group) / t,
                    stamina=100 * sum(s["stamina"] for _, _, s in group) / t, dry=100 * sum(s["dry"] for _, _, s in group) / near, still=100 * sum(s["still"] for _, _, s in group) / t,
                    near=100 * sum(s["near"] for _, _, s in group) / t)
    first = [r for r in rows if r[0] <= 3]
    last = [r for r in rows if r[0] >= r[1] - 2]
    print("%-18s %5s %7s %7s %9s %9s %6s %7s %9s" % ("", "n", "dealt", "taken", "casts/min", "stamina%", "dry%", "still%", "near rival%"))
    for name, g in (("first three to fall", first), ("last three standing", last)):
        h = habit(g)
        print("%-18s %5d %7.0f %7.0f %9.1f %9.0f %6.0f %7.0f %9.0f" % (name, h["n"], h["dealt"], h["taken"], h["casts_min"], h["stamina"], h["dry"], h["still"], h["near"]))


if __name__ == "__main__":
    main()
