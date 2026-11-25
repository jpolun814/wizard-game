"""Reads the match logs written by MatchRecorder (user://match_logs, i.e. %APPDATA%/Godot/app_userdata/wizard-game/match_logs) and prints a summary of each match.

    python -I tools/read_match.py [folder-or-file ...]      (no argument: the game's own folder)

Per world: who was there, every wizard's casts and the damage it dealt and took, how each one fell, the skirmishes (two wizards within 500 px, merged when the gaps
are under 8 seconds) with each wizard's casts and damage in them, and what the AI chose (how often, and how often it chose each spell). Lines are described at the top
of scripts/ui/match_recorder.gd."""
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


NEAR, GAP = 500.0, 8.0


def default_folder():
    return os.path.expandvars(r"%APPDATA%\Godot\app_userdata\wizard-game\match_logs")


def parse(path):
    """Returns a dict of the lists a log holds."""
    out = dict(head="", wz=[], cast=[], dec=[], hit=[], fall=[], names={}, kinds={}, levels={}, end=0.0)
    for line in open(path, encoding="utf-8", errors="ignore"):
        p = line.split()
        if len(p) < 2:
            continue
        try:
            t = float(p[0])
        except ValueError:
            continue
        out["end"] = max(out["end"], t)
        k = p[1]
        if k == "HEAD":
            out["head"] = " ".join(p[2:])
        elif k == "WZ" and len(p) >= 15 and _thin(p[2], t):
            i = p[2]
            out["names"][i], out["kinds"][i], out["levels"][i] = p[3], p[4], p[5]
            out["wz"].append((t, i, float(p[6]), float(p[7]), int(p[14]) if p[14].lstrip("-").isdigit() else 0, int(p[15]) if p[15].lstrip("-").isdigit() else 0, p[16] if len(p) > 16 else "-", p[17] if len(p) > 17 else "-"))
        elif k == "CAST" and len(p) >= 4:
            out["cast"].append((t, p[2], p[3]))
        elif k == "DEC" and len(p) >= 4:
            out["dec"].append((t, p[2], p[3], p[4:]))
        elif k == "HIT" and len(p) >= 7:
            out["hit"].append((t, p[2], p[3], p[4], float(p[5])))
        elif k == "FALL" and len(p) >= 3:
            out["fall"].append((t, p[2]))
    return out


def skirmishes(log):
    """Episodes in which any two wizards were within NEAR of each other: [start, end, {wizard ids}]."""
    by_time = collections.defaultdict(list)
    for t, i, x, y, *_ in log["wz"]:
        by_time[round(t, 1)].append((i, x, y))
    close = []
    for t in sorted(by_time):
        ws = by_time[t]
        who = set()
        for a in range(len(ws)):
            for b in range(a + 1, len(ws)):
                if math.hypot(ws[a][1] - ws[b][1], ws[a][2] - ws[b][2]) < NEAR:
                    who.update((ws[a][0], ws[b][0]))
        if who:
            close.append((t, who))
    eps = []
    for t, who in close:
        if eps and t - eps[-1][1] <= GAP:
            eps[-1][1] = t
            eps[-1][2] |= who
        else:
            eps.append([t, t, set(who)])
    return eps


def summarize(path):
    log = parse(path)
    n = lambda i: "%s(%s%s)" % (log["names"].get(i, i), log["kinds"].get(i, "?"), "" if log["kinds"].get(i) != "brain" else " L" + log["levels"].get(i, "?"))
    print("== %s   %.0fs   %s" % (os.path.basename(path), log["end"], log["head"]))
    casts, dealt, taken = collections.Counter(), collections.Counter(), collections.Counter()
    for t, i, spell in log["cast"]:
        casts[i] += 1
    for t, victim, by, with_, amount in log["hit"]:
        taken[victim] += amount
        if by != "-":
            dealt[by] += amount
    for i in sorted(log["names"], key=lambda i: log["names"][i]):
        print("   %-26s casts %3d  dealt %4.0f  taken %4.0f" % (n(i), casts[i], dealt[i], taken[i]))
    for t, i in log["fall"]:
        by = [h for h in log["hit"] if h[1] == i and h[0] <= t + 0.5]
        last = by[-1] if by else None
        print("   %6.1fs  %s fell%s" % (t, n(i), (" (last blow by %s with %s)" % (n(last[2]) if last[2] != "-" else "the world", last[3])) if last else ""))
    eps = skirmishes(log)
    if eps:
        lens = [e[1] - e[0] + 0.5 for e in eps]
        print("   skirmishes: %d, total %.0fs, longest %.0fs" % (len(eps), sum(lens), max(lens)))
    choices = collections.Counter(c for t, i, c, rest in log["dec"] if c != "-")
    if choices:
        print("   AI chose: " + ", ".join("%s %d" % (c, k) for c, k in choices.most_common(8)))


def main():
    args = sys.argv[1:] or [default_folder()]
    files = []
    for a in args:
        files += sorted(glob.glob(os.path.join(a, "match_*.log"))) if os.path.isdir(a) else [a]
    if not files:
        print("no match logs found in", args)
    for f in files[-12:]:
        summarize(f)


if __name__ == "__main__":
    main()
