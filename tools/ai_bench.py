"""Sets the AI wizards' current brain against the frozen old one (tests/legacy_brain) in many games at once and adds up who wins.

    python tools/ai_bench.py duel 24            24 duels, the new brain against the old, sides swapped every other game
    python tools/ai_bench.py royale 12          12 whole matches of eight, new and old seated alternately (the seats swap every other game)
    python tools/ai_bench.py both 16 12         both

Prints the new brain's score: for duels, wins / losses / draws (a draw is called for whoever has lost less); for matches, the mean place of the
new and the old (1 is best) and how often each won. Results are kept in the folder given by BENCH_OUT (default: a temp folder).
"""
import concurrent.futures
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
OUT = os.environ.get("BENCH_OUT", os.path.join(tempfile.gettempdir(), "wizard_bench"))
FIRST_SEED = int(os.environ.get("BENCH_SEED", "100"))


def run(args, name):
    path = os.path.join(OUT, name + ".jsonl")
    if os.path.exists(path):
        os.remove(path)
    subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--"] + args + ["result=" + path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.loads(f.readline())


def jobs(kind, count):
    out = []
    for k in range(count):
        seed = FIRST_SEED + k
        swap = k % 2 == 1
        if kind == "duel":
            out.append((["mode=duel", "seed=%d" % seed, "seconds=120"] + os.environ.get("BENCH_ARGS", "").split() + (["swap=1"] if swap else []), "duel_%d" % seed))
        else:
            old = [1, 3, 5, 7] if not swap else [0, 2, 4, 6]
            out.append((["mode=royale", "seed=%d" % seed, "old=" + ",".join(map(str, old))], "royale_%d" % seed))
    return out


def share(results):
    """The new brain's share of the damage dealt in the duels, game by game: its opponent's damage taken over both's, with the standard error of the mean."""
    xs = []
    for r in results:
        old = r["old"][0]
        got = r.get("taken", {})
        lost_new, lost_old = got.get(str(1 - old), 0), got.get(str(old), 0)
        if lost_new + lost_old > 0:
            xs.append(lost_old / (lost_new + lost_old))
    if not xs:
        return 0.5, 0.0
    mean = sum(xs) / len(xs)
    var = sum((x - mean) ** 2 for x in xs) / max(1, len(xs) - 1)
    return mean, (var / len(xs)) ** 0.5


def duel_score(results):
    wins = losses = draws = 0
    for r in results:
        old = r["old"][0]
        new = 1 - old
        fell_new, fell_old = r["fell"][str(new)], r["fell"][str(old)]
        if fell_old >= 0 and fell_new < 0:
            wins += 1
        elif fell_new >= 0 and fell_old < 0:
            losses += 1
        elif fell_new >= 0 and fell_old >= 0:
            wins, losses = (wins + 1, losses) if fell_old > fell_new else (wins, losses + 1)
        else:
            a, b = r["stamina"][str(new)], r["stamina"][str(old)]
            if a > b + 10:
                wins += 1
            elif b > a + 10:
                losses += 1
            else:
                draws += 1
    return wins, losses, draws


def royale_score(results):
    places = {"new": [], "old": []}
    won = {"new": 0, "old": 0}
    for r in results:
        left = {int(k): v for k, v in r["stamina"].items()}
        times = {int(k): (v if v >= 0 else 1e9 + left[int(k)]) for k, v in r["fell"].items()}  # (those standing at the end are ranked by what they have left)
        order = sorted(times, key=lambda s: -times[s])  # last to fall first
        for place, seat in enumerate(order, 1):
            places["old" if seat in r["old"] else "new"].append(place)
        if len([t for t in times.values() if t >= 1e9]) == 1:
            won["old" if order[0] in r["old"] else "new"] += 1
    mean = lambda xs: sum(xs) / len(xs) if xs else float("nan")
    return mean(places["new"]), mean(places["old"]), won["new"], won["old"]


def main():
    os.makedirs(OUT, exist_ok=True)
    kinds = sys.argv[1]
    counts = [int(x) for x in sys.argv[2:]]
    plan = [("duel", counts[0])] if kinds == "duel" else [("royale", counts[0])] if kinds == "royale" else [("duel", counts[0]), ("royale", counts[1])]
    for kind, count in plan:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, (os.cpu_count() or 4) - 1)) as pool:
            results = [r for r in pool.map(lambda j: run(*j), jobs(kind, count)) if r]
        if kind == "duel":
            w, l, d = duel_score(results)
            m, se = share(results)
            print("duel   (%d games): new won %d, lost %d, drew %d; its share of the damage %.3f +- %.3f" % (len(results), w, l, d, m, se))
        else:
            n, o, wn, wo = royale_score(results)
            print("royale (%d games): mean place new %.2f, old %.2f; wins new %d, old %d" % (len(results), n, o, wn, wo))


main()
