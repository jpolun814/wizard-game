"""Plays the nine AI levels (scripts/brain/brain_level.gd) against each other, and each against the frozen old brain, and writes the results as tables.

    python tools/ai_ladder.py GAMES_PER_PAIR GAMES_VS_OLD OUTFILE

A pair is played in duels (tests/tools/ai_arena.tscn, mode=duel, lv=A,B), the seats swapped every other game. In the table, a row is a level and a column is
the level it plays: the cell is the row's share of the damage dealt (0.50 is an even match), and its win-loss-draw in games. Results are cached in BENCH_OUT, so a
run that stops can be run again and carries on. BENCH_SEED sets the first seed.
"""
import concurrent.futures
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
OUT = os.environ.get("BENCH_OUT", os.path.join(tempfile.gettempdir(), "wizard_ladder"))
FIRST_SEED = int(os.environ.get("BENCH_SEED", "100"))
LEVELS = 9


def run(args, name):
    path = os.path.join(OUT, name + ".jsonl")
    if os.path.exists(path):
        with open(path) as f:
            return json.loads(f.readline())
    subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--"] + args + ["result=" + path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.loads(f.readline())


def outcome(r, seat_a):
    """+1 if the wizard in seat_a won, -1 if it lost, 0 for a draw (called for whoever has lost less); and its share of the damage (None if none dealt)."""
    seat_b = 1 - seat_a
    fa, fb = r["fell"][str(seat_a)], r["fell"][str(seat_b)]
    if fa < 0 and fb >= 0:
        won = 1
    elif fb < 0 and fa >= 0:
        won = -1
    elif fa >= 0 and fb >= 0:
        won = 1 if fb < fa else -1
    else:
        a, b = r["stamina"][str(seat_a)], r["stamina"][str(seat_b)]
        won = 1 if a > b + 10 else (-1 if b > a + 10 else 0)
    got = r.get("taken", {})
    lost_a, lost_b = got.get(str(seat_a), 0), got.get(str(seat_b), 0)
    share = lost_b / (lost_a + lost_b) if lost_a + lost_b > 0 else None
    return won, share


def pair_jobs(a, b, games):
    out = []
    for k in range(games):
        seed = FIRST_SEED + k
        swap = k % 2 == 1
        levels = (b, a) if swap else (a, b)
        out.append((["mode=duel", "seed=%d" % seed, "seconds=120", "lv=%d,%d" % levels], "pair_%d_%d_%d" % (a, b, seed), 1 if swap else 0))
    return out


def old_jobs(a, games):
    out = []
    for k in range(games):
        seed = FIRST_SEED + 5000 + k
        swap = k % 2 == 1
        out.append((["mode=duel", "seed=%d" % seed, "seconds=120", "lv=%d" % a] + (["swap=1"] if swap else []), "old_%d_%d" % (a, seed), swap, a))
    return out


def tally(rows):
    wins = losses = draws = 0
    shares = []
    for won, share in rows:
        wins += won == 1
        losses += won == -1
        draws += won == 0
        if share is not None:
            shares.append(share)
    n = len(shares)
    mean = sum(shares) / n if n else 0.5
    var = sum((x - mean) ** 2 for x in shares) / max(1, n - 1)
    return wins, losses, draws, mean, (var / max(1, n)) ** 0.5


def main():
    os.makedirs(OUT, exist_ok=True)
    games, vs_old, outfile = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    workers = max(1, (os.cpu_count() or 4) - 1)
    pairs = [(a, b) for a in range(1, LEVELS + 1) for b in range(a + 1, LEVELS + 1)]
    cells = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for a, b in pairs:
            jobs = pair_jobs(a, b, games)
            results = list(pool.map(lambda j: (run(j[0], j[1]), j[2]), jobs))
            rows = []
            for r, swap in results:
                if r:
                    seat_a = 1 if swap else 0  # (with the seats swapped, the lower level sits in seat 1)
                    rows.append(outcome(r, seat_a))
            cells[(a, b)] = tally(rows)
            print("level %d vs %d: %s" % (a, b, cells[(a, b)]), flush=True)
        olds = {}
        for a in range(1, LEVELS + 1):
            jobs = old_jobs(a, vs_old)
            results = list(pool.map(lambda j: (run(j[0], j[1]), j[2]), jobs))
            rows = []
            for r, swap in results:
                if r:
                    old_seat = r["old"][0]
                    rows.append(outcome_new(r, old_seat))
            olds[a] = tally(rows)
            print("level %d vs the old brain: %s" % (a, olds[a]), flush=True)
    write(outfile, cells, olds, games, vs_old)


def outcome_new(r, old_seat):
    won, share = outcome(r, 1 - old_seat)
    return won, share


def write(outfile, cells, olds, games, vs_old):
    lines = ["# The nine AI levels against each other", "",
             "Each cell is the row level's share of the damage dealt against the column level (0.50 is an even match); below it, the row level's wins-losses-draws. "
             "%d duels per pair, the seats swapped every other game." % games, ""]
    head = "| level | " + " | ".join(str(b) for b in range(1, LEVELS + 1)) + " |"
    lines += [head, "|" + "---|" * (LEVELS + 1)]
    for a in range(1, LEVELS + 1):
        row = []
        for b in range(1, LEVELS + 1):
            if a == b:
                row.append("-")
            elif a < b:
                w, l, d, m, se = cells[(a, b)]
                row.append("%.2f<br>%d-%d-%d" % (m, w, l, d))
            else:
                w, l, d, m, se = cells[(b, a)]
                row.append("%.2f<br>%d-%d-%d" % (1 - m, l, w, d))
        lines.append("| %d | " % a + " | ".join(row) + " |")
    lines += ["", "## Each level against the frozen old brain", "", "%d duels each." % vs_old, "", "| level | share of the damage | wins-losses-draws |", "|---|---|---|"]
    for a in range(1, LEVELS + 1):
        w, l, d, m, se = olds[a]
        lines.append("| %d | %.3f +- %.3f | %d-%d-%d |" % (a, m, se, w, l, d))
    with open(outfile, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


main()
