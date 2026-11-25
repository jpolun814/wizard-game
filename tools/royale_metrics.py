"""One line of numbers for a batch of match logs, to set one version of the AI beside another.

    python -I tools/royale_metrics.py DIR [DIR ...]

dry: share of the time with a rival within 500 px that a wizard has under a fifth of its stamina (it cannot cast). still: the same, standing still.
dmg/skirm-s: damage dealt by wizards per second of wizard-time with a rival within 500 px. per cast: damage dealt within 3 s of each choice. length: how long a match lasted."""
import collections, glob, math, os, re, sys

_LAST = {}


def _thin(i, t):
    """The log may hold a wizard more often than every half second; these figures count in half seconds, so keep one row to each."""
    b = int(t // 0.5)
    last = _LAST.get(i)
    if last is not None and last[0] == b and t >= last[1]:
        return False
    _LAST[i] = (b, t)
    return True



def spell_costs():
    cost = {}
    for f in glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "spells", "*.tres")):
        text = open(f, encoding="utf-8").read()
        n, c = re.search(r'spell_name = "([^"]+)"', text), re.search(r"^cost = ([0-9.]+)", text, re.M)
        if n and c:
            cost[n.group(1).replace(" ", "_")] = float(c.group(1))
    return cost


def main():
    near_t = dry = still = spent = 0.0
    cost = spell_costs()
    dealt = 0.0
    choices = 0
    lengths = []
    for a in sys.argv[1:]:
        for f in glob.glob(os.path.join(a, "**", "match_*.log"), recursive=True):
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
                    if p[15] != "death":  # (a fallen wizard lies on in the logs: it is not a rival, nor does it hold stamina)
                        wz[round(t, 1)].append((p[2], float(p[6]), float(p[7]), float(p[8]), float(p[9]), float(p[12]), float(p[13])))
                elif p[1] == "HIT" and len(p) >= 7 and p[3] != "-":
                    dealt += float(p[5])
                elif p[1] == "DEC" and p[3] != "-":
                    choices += 1
                    spent += cost.get(p[3], 0.0)
            lengths.append(end)
            for t, ws in wz.items():
                for i, r in enumerate(ws):
                    d = min((math.hypot(r[1] - o[1], r[2] - o[2]) for j, o in enumerate(ws) if j != i), default=1e9)
                    if d < 500.0:
                        near_t += 0.5
                        dry += 0.5 if r[5] < 0.2 * max(r[6], 1.0) else 0.0
                        still += 0.5 if math.hypot(r[3], r[4]) < 20.0 else 0.0
    if not near_t:
        print("no data")
        return
    print("logs %d  length %.0fs  dry %.0f%%  still %.0f%%  dmg/skirm-s %.2f  per cast %.1f  casts %d  dmg per 100 stamina %.0f" % (len(lengths), sum(lengths) / len(lengths), 100 * dry / near_t, 100 * still / near_t, dealt / near_t, dealt / max(1, choices), choices, 100 * dealt / max(spent, 1.0)))


if __name__ == "__main__":
    main()
