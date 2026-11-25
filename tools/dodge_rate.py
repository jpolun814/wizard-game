"""How often a wizard gets out of the way of a shot, from match logs: of the shots that passed within a short reach of a wizard who did not throw them, how many struck.

    python -I tools/dodge_rate.py DIR [DIR ...] [--reach 45]

A shot is anything in the logs' OB lines of the "shots" kind (the NEW line says shot). It counts as aimed at a wizard when its path (the logged places, ten a second) came within
--reach pixels of that wizard's place (the logged places, two a second, joined by straight lines) and the wizard was not the one who threw it. It struck when a HIT on that wizard from the
thrower follows within 0.4 s of the closest approach. Reports the rate for each kind of shot, and for the person and the AI separately."""
import argparse, collections, glob, math, os


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--reach", type=float, default=45.0)
    a = ap.parse_args()
    seen = collections.defaultdict(lambda: [0, 0])   # (kind, class) -> [passed, struck]
    for d in a.dirs:
        for f in glob.glob(os.path.join(d, "**", "match_*.log"), recursive=True):
            wz = collections.defaultdict(list)
            kinds = {}
            shots = collections.defaultdict(list)
            shot_info = {}
            hits = collections.defaultdict(list)
            for line in open(f, encoding="utf-8", errors="ignore"):
                p = line.split()
                if len(p) < 4:
                    continue
                try:
                    t = float(p[0])
                except ValueError:
                    continue
                if p[1] == "WZ" and len(p) >= 19:
                    wz[p[2]].append((t, float(p[6]), float(p[7] ) - 30.0))
                    kinds[p[2]] = p[4]
                elif p[1] == "NEW" and len(p) >= 8 and p[7] == "shot":
                    shot_info[p[2]] = (p[3], p[4])
                elif p[1] == "OB" and len(p) >= 7 and p[2] in shot_info:
                    shots[p[2]].append((t, float(p[5]), float(p[6])))
                elif p[1] == "HIT" and len(p) >= 7:
                    hits[p[2]].append((t, p[3]))

            def where(i, t):
                rows = wz[i]
                for (t0, x0, y0), (t1, x1, y1) in zip(rows, rows[1:]):
                    if t0 <= t <= t1:
                        k = (t - t0) / max(t1 - t0, 1e-6)
                        return x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
                return None
            for sid, path in shots.items():
                cls, owner = shot_info[sid]
                if owner == "-" or len(path) < 2:
                    continue
                for i in wz:
                    if i == owner:
                        continue
                    best, at = 1e9, 0.0
                    for t, x, y in path:
                        w = where(i, t)
                        if w is not None:
                            g = math.hypot(x - w[0], y - w[1])
                            if g < best:
                                best, at = g, t
                    if best <= a.reach:
                        struck = any(abs(t - at) <= 0.4 and by == owner for t, by in hits[i])
                        key = (kinds[i], cls)
                        seen[key][0] += 1
                        seen[key][1] += 1 if struck else 0
    for kind in ("brain", "person"):
        rows = {k[1]: v for k, v in seen.items() if k[0] == kind}
        if not rows:
            continue
        passed = sum(v[0] for v in rows.values())
        struck = sum(v[1] for v in rows.values())
        print("%s: %d shots came within %.0f px, %d struck (%.0f%% got clear)" % (kind, passed, a.reach, struck, 100 * (1 - struck / max(passed, 1))))
        for c, v in sorted(rows.items(), key=lambda kv: -kv[1][0])[:10]:
            print("   %-16s passed %4d  struck %4d  got clear %3.0f%%" % (c, v[0], v[1], 100 * (1 - v[1] / max(v[0], 1))))


if __name__ == "__main__":
    main()
