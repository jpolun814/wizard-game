"""What people's recordings say about spells: which are cast and how often, which are cast together, and which a person holds when they play
boldly (going toward rivals) and when they play carefully (looking for pages, keeping away). The same questions the AI's strength score
(WizardBrain._feel_strength) answers by hand; this is the data to learn it from.

    python tools/analyze_play.py [--logs DIR_OR_FILE ...] [--window 5] [--together 8]
"""
import argparse, collections, glob, gzip, math, os, re

DEFAULT_LOGS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "wizard-game", "play_logs")
SPELLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "spells")


def attack_spells():
    """Spell name -> the first figure of its damage line, for the spells that deal damage."""
    out = {}
    for path in glob.glob(os.path.join(SPELLS, "*.tres")):
        text = open(path, encoding="utf-8", errors="replace").read()
        name = re.search(r'^spell_name = "(.*)"', text, re.M)
        dmg = re.search(r'^damage = "(\d+)', text, re.M)
        if name and dmg:
            out[name.group(1).replace(" ", "_")] = int(dmg.group(1))
    return out


def lines(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        for raw in f:
            parts = raw.rstrip("\n").split(" ")
            if len(parts) > 1:
                try:
                    yield float(parts[0]), parts[1], parts[2:]
                except ValueError:
                    pass


def stances(rows, window):
    """Cuts a game into windows and calls each one bold (the nearest rival got nearer, or the person cast at one near), careful (the nearest got farther, or there was
    none and pages were found) or neither. Returns [(start, stance, held spells)]."""
    gaps = {}   # window index -> list of nearest rival distance
    casts = collections.Counter()
    pages = {}
    held, held_at = [], []
    for t, kind, a in rows:
        w = int(t // window)
        if kind == "W" and len(a) >= 4:
            try:
                d = math.hypot(float(a[2]), float(a[3]))
            except ValueError:
                continue
            gaps.setdefault(w, []).append(d)
        elif kind == "C":
            casts[w] += 1
        elif kind == "S" and len(a) >= 10:
            try:
                pages[w] = int(a[8])
            except ValueError:
                pass
        elif kind == "P":
            held_at.append((t, [] if a[0] == "-" else a[0].split("|")))
    out = []
    for w in sorted(set(gaps) | set(casts) | set(pages)):
        near = gaps.get(w)
        stance = None
        if near and min(near) < 700:
            trend = near[-1] - near[0]
            if trend < -80 or (casts[w] and min(near) < 600):
                stance = "bold"
            elif trend > 80:
                stance = "careful"
        elif not near and w in pages and w - 1 in pages and pages[w] > pages[w - 1]:
            stance = "careful"  # nobody about, and it found a page
        book = []
        for t, h in held_at:
            if t <= w * window:
                book = h
        out.append((w * window, stance, book))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="*", default=[DEFAULT_LOGS])
    ap.add_argument("--window", type=float, default=5.0)
    ap.add_argument("--together", type=float, default=8.0, help="spells cast within this many seconds count as cast together")
    args = ap.parse_args()
    dmg = attack_spells()

    files = []
    for t in args.logs:
        if os.path.isdir(t):
            for pat in ("play_*.log", "solo_*.log", "net_*.log", "*.gz"):
                files += glob.glob(os.path.join(t, pat))
        else:
            files.append(t)
    casts = collections.Counter()
    pairs = collections.Counter()
    by_stance = collections.defaultdict(lambda: collections.Counter())
    n_stance = collections.Counter()
    arms = collections.defaultdict(list)
    games = 0
    for path in sorted(set(files)):
        rows = list(lines(path))
        if not any(k == "C" for _, k, _ in rows):
            continue
        games += 1
        recent = []
        for t, k, a in rows:
            if k == "C" and a:
                spell = "_".join(a)
                casts[spell] += 1
                recent = [(tt, s) for tt, s in recent if t - tt <= args.together]
                for _, other in recent:
                    if other != spell:
                        pairs[tuple(sorted((other, spell)))] += 1
                recent.append((t, spell))
        for start, stance, book in stances(rows, args.window):
            if stance is None:
                continue
            n_stance[stance] += 1
            arms[stance].append(sum(min(dmg.get(p, 0), 40) / 40 for p in book))
            for p in book:
                by_stance[stance][p] += 1

    print("games with casts:", games)
    print("\nCast most:")
    for s, n in casts.most_common(12):
        print("  %-18s %4d" % (s, n))
    print("\nCast within %.0f s of each other:" % args.together)
    for (a, b), n in pairs.most_common(12):
        print("  %-18s + %-18s %4d" % (a, b, n))
    print("\nStances (windows of %.0f s):" % args.window, dict(n_stance))
    for stance in ("bold", "careful"):
        if n_stance[stance]:
            print("  %-8s average attack strength of the book %.2f" % (stance, sum(arms[stance]) / len(arms[stance])))
    for stance in ("bold", "careful"):
        if n_stance[stance]:
            print("\nHeld most often while %s:" % stance)
            for s, n in by_stance[stance].most_common(8):
                print("  %-18s %3.0f%% of windows" % (s, 100.0 * n / n_stance[stance]))


if __name__ == "__main__":
    main()
