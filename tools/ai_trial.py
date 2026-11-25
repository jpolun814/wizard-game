"""Tests one change to the AI brain against the brain without it, in three rungs of growing cost, and stops as soon as the answer is clear.

    python tools/ai_trial.py duel facts          1 against 1 on a small flat world: for changes to fighting alone (spell choice, aim, dodging)
    python tools/ai_trial.py quad facts          2 against 2 in a match of four on worlds half as wide: the main screen (three-way fights exist here)
    python tools/ai_trial.py royale facts        4 against 4 in a full match of eight: to confirm what passed the rungs below
    python tools/ai_trial.py quad none           an A/A test: both groups the same brain. It must come out even; how far it strays is the noise
    python tools/ai_trial.py quad legacy         the brain against the frozen old one (tests/legacy_brain)
    python tools/ai_trial.py recheck             every change that passed before is played again at its rung on new worlds

    options: --max N (pairs at most, default 60), --seed S (the first world; each rung has its own fixed list, so every change meets the same worlds),
             --delta D (the smallest gain in places worth having, default 0.25 for a match, 0.1 for a duel), --logs (write the match logs and name the worst games)

The change is a name BrainProfile.off knows: its group plays with the change turned OFF (the old way); the other group plays as the code does now.
Each world is played twice, the groups swapping seats the second time (a mirrored pair), so a good spawn or a lucky map helps both alike.

What it reports, for the group WITH the change:
  place   the mean finishing place of its wizards less that of the others' (below 0 is better). This decides: it uses the whole order, so it needs the fewest games.
  wins    the share of games its group won. A veto: a change that lifts the place but wins less is not taken (a wizard that hides can finish third and never win).
  top-weighted  the mean of 1/log2(place+1) (1st 1.0, 2nd 0.63, 3rd 0.5), a cross-check that counts 1st most and every place a little.
It stops when a sequential test (the normal-approximation SPRT that chess engines test changes with, Fishtest) says the change is better by at least
--delta (PASS) or that it is not (FAIL), with 5% chances of either mistake; or at --max pairs (UNDECIDED). Every test adds a line to reports/ai_tests.jsonl.
"""
import concurrent.futures
import json
import math
import os
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
OUT = os.path.join(tempfile.gettempdir(), "wizard_ladder")
HISTORY = os.path.join(ROOT, "reports", "ai_tests.jsonl")
LEVEL = os.environ.get("BENCH_LEVEL", "9")
WORKERS = max(1, os.cpu_count() or 4)  # (each game takes a core: more at once only slows each one down)

# The rungs: how many play, the worlds' width, the seconds of play at most, the two groups' seats (the first game; the second swaps them), and the first world.
RUNGS = {
    "duel": {"mode": "duel", "players": 2, "width": 1.0, "seconds": 120, "seats": ([0], [1]), "seed": 5000, "delta": 0.1},
    "quad": {"mode": "royale", "players": 4, "width": 0.5, "seconds": 700, "seats": ([0, 2], [1, 3]), "seed": 6000, "delta": 0.25},
    "royale": {"mode": "royale", "players": 8, "width": 1.0, "seconds": 1100, "seats": ([0, 2, 4, 6], [1, 3, 5, 7]), "seed": 7000, "delta": 0.25},
}
ALPHA = BETA = 0.05
MIN_PAIRS = 8
BATCH = WORKERS // 2 or 1  # pairs played between looks (two games each)


def play(rung, change, seed, old, need, logs):
    """One game: the seats in `old` play without the change. Returns {seat: place} (1 the winner), or None if the game did not finish."""
    r = RUNGS[rung]
    os.makedirs(OUT, exist_ok=True)
    tag = "%s_%s_%d_%s" % (rung, change.replace(",", "+"), seed, "-".join(map(str, old)))
    path = os.path.join(OUT, tag + ".jsonl")
    if os.path.exists(path):
        os.remove(path)
    args = ["mode=%s" % r["mode"], "seed=%d" % seed, "seconds=%d" % r["seconds"], "lv=%s" % ",".join([LEVEL] * 8), "result=" + path]
    if r["mode"] == "royale":
        args += ["players=%d" % r["players"], "width=%s" % r["width"]]
    if change == "legacy":
        args.append("old=" + ",".join(map(str, old)))
    elif change != "none":
        args.append("offseats=%s:%s" % (",".join(map(str, old)), change))
    if r["mode"] == "duel":  # (a duel's old= and swap are its own: the legacy brain sits in seat 1 unless swapped)
        args = [a for a in args if not a.startswith("old=")] + (["swap=1"] if old == [0] else [])
        if change == "legacy":
            args = [a for a in args if not a.startswith("lv=")]
    if need:
        args.append("need=" + need)
    if logs:
        args.append("matchlog=" + os.path.join(OUT, "logs", tag))
    started = time.time()
    try:
        subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--"] + args,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1500)
    except subprocess.TimeoutExpired:
        return None
    if not os.path.exists(path):
        return None
    result = json.loads(open(path).readline())
    left = {int(k): v for k, v in result["stamina"].items()}
    fell = {int(k): (v if v >= 0 else 1e9 + left[int(k)]) for k, v in result["fell"].items() if int(k) < r["players"]}  # (still standing at the end: ahead of all who fell, and among themselves by what they had left)
    order = sorted(fell, key=lambda seat: -fell[seat])
    return {"places": {seat: place for place, seat in enumerate(order, 1)}, "game_seconds": result["seconds"], "wall": time.time() - started, "tag": tag,
            "taken": {int(k): v for k, v in result.get("taken", {}).items()}, "deaths": result.get("deaths", [])}


def score(game, new, old, players):
    """What one game says of the group with the change: (place difference, won, top-weighted score difference)."""
    p = game["places"]
    mean = lambda seats: sum(p[s] for s in seats) / len(seats)
    pts = lambda seats: sum(1.0 / math.log2(p[s] + 1) for s in seats) / len(seats)  # top-weighted: 1st 1.0, 2nd 0.63, 3rd 0.5 (NDCG-style)
    return mean(new) - mean(old), 1.0 if any(p[s] == 1 for s in new) else 0.0, pts(new) - pts(old)


def sprt(xs, delta):
    """The log-likelihood ratio of 'better by delta' against 'no better', for the pairs' gains (places, above 0 is better), with the variance as measured."""
    n = len(xs)
    if n < 2:
        return 0.0
    mean = sum(xs) / n
    var = max(sum((x - mean) ** 2 for x in xs) / (n - 1), 1e-6)
    return delta * (sum(xs) - n * delta / 2.0) / var


def run(rung, change, max_pairs, first_seed, delta, need, logs):
    r = RUNGS[rung]
    new_seats, old_seats = r["seats"]
    upper, lower = math.log((1 - BETA) / ALPHA), math.log(BETA / (1 - ALPHA))
    gains, wins, points, games, walls = [], [], [], [], []
    verdict, pair = "UNDECIDED", 0
    started = time.time()
    print("%s, %s: up to %d mirrored pairs, %d games at once" % (rung, change, max_pairs, WORKERS), flush=True)
    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        while pair < max_pairs:
            seeds = [first_seed + pair + k for k in range(min(BATCH, max_pairs - pair))]
            pair += len(seeds)
            jobs = [(s, pool.submit(play, rung, change, s, old_seats, need, logs), pool.submit(play, rung, change, s, new_seats, need, logs)) for s in seeds]
            for s, a, b in jobs:
                ga, gb = a.result(), b.result()
                if ga is None or gb is None:
                    print("  world %d: a game did not finish, the pair is left out" % s, flush=True)
                    continue
                d1, w1, p1 = score(ga, new_seats, old_seats, r["players"])  # (in the first game the old way sits in old_seats; in the second the groups swap)
                d2, w2, p2 = score(gb, old_seats, new_seats, r["players"])
                gains.append(-(d1 + d2) / 2.0)
                wins += [w1, w2]
                points.append((p1 + p2) / 2.0)
                games += [ga, gb]
                walls += [ga["wall"], gb["wall"]]
            llr = sprt(gains, delta)
            n = len(gains)
            mean = sum(gains) / n if n else 0.0
            se = (sum((x - mean) ** 2 for x in gains) / max(1, n - 1) / max(1, n)) ** 0.5 if n > 1 else float("nan")
            print("  %3d pairs: better by %+.2f places (+- %.2f), its group won %.0f%% of games, llr %.2f [%.2f, %.2f]" % (n, mean, se, 100 * sum(wins) / max(1, len(wins)), llr, lower, upper), flush=True)
            if n >= MIN_PAIRS and llr >= upper:
                verdict = "PASS"
                break
            if n >= MIN_PAIRS and llr <= lower:
                verdict = "FAIL"
                break
    n = len(gains)
    mean = sum(gains) / n if n else 0.0
    se = (sum((x - mean) ** 2 for x in gains) / max(1, n - 1) / max(1, n)) ** 0.5 if n > 1 else float("nan")
    win_share = sum(wins) / max(1, len(wins))
    fair_win = len(new_seats) / r["players"]
    veto = verdict == "PASS" and win_share < fair_win - 0.02
    if veto:
        verdict = "VETO (places better, wins fewer)"
    harm = n > 1 and mean < -2.0 * se
    speed = sum(g["game_seconds"] for g in games) / max(1e-6, sum(walls))
    print("%s: %s after %d pairs (%d games, %.0f min). Better by %+.2f places +- %.2f%s; its group won %.0f%% (an even share is %.0f%%); top-weighted %+.2f. The games ran %.1fx as fast as real time."
          % (change, verdict, n, len(games), (time.time() - started) / 60, mean, se, " (WORSE: more than two errors below 0)" if harm else "", 100 * win_share, 100 * fair_win,
             sum(points) / max(1, len(points)), speed), flush=True)
    if logs and games:
        worst = sorted(range(n), key=lambda k: gains[k])[:3]
        print("the worst pairs for the change (match logs, for tools/replay_match.py and tools/analyze_royales.py):")
        for k in worst:
            for g in games[2 * k:2 * k + 2]:
                print("  %+.2f  %s" % (gains[k], os.path.join(OUT, "logs", g["tag"])))
    # (b) what each group did: damage taken per game, and how its wizards fell (a group that hides survives longer and takes less)
    for label, side in (("WITH the change", 0), ("WITHOUT it", 1)):
        taken, causes, count = 0.0, {}, 0
        for k in range(n):
            for j, g in enumerate(games[2 * k:2 * k + 2]):
                group = new_seats if (j == 0) == (side == 0) else old_seats  # (game 1: the old group sits in old_seats; game 2 they swap)
                taken += sum(g["taken"].get(seat, 0) for seat in group)
                count += len(group)
                for death in g["deaths"]:
                    if death["seat"] in group:
                        causes[death["cause"]] = causes.get(death["cause"], 0) + 1
        if count:
            print("  %s: damage taken %.0f per wizard per game; how they fell: %s" % (label, taken / count, ", ".join("%s %d" % kv for kv in sorted(causes.items(), key=lambda kv: -kv[1])) or "none"))
    os.makedirs(os.path.dirname(HISTORY), exist_ok=True)
    worst_logs = [os.path.join(OUT, "logs", g["tag"]) for k in sorted(range(n), key=lambda k: gains[k])[:3] for g in games[2 * k:2 * k + 2]] if logs else []  # (e)
    with open(HISTORY, "a", encoding="utf-8") as out:
        out.write(json.dumps({"when": time.strftime("%Y-%m-%d %H:%M"), "rung": rung, "change": change, "verdict": verdict, "pairs": n, "gain": round(mean, 3), "se": round(se, 3) if n > 1 else None,
                              "win_share": round(win_share, 3), "top_weighted": round(sum(points) / max(1, len(points)), 3), "first_seed": first_seed, "delta": delta, "level": LEVEL, "need": need, "worst_logs": worst_logs}) + "\n")
    return verdict


def recheck(max_pairs):
    """Plays again every change that once passed, at the rung it passed, on worlds it has not met (changes act on each other: a gain can fade)."""
    if not os.path.exists(HISTORY):
        print("no tests yet")
        return
    passed = {}
    for line in open(HISTORY, encoding="utf-8"):
        t = json.loads(line)
        if t["verdict"] == "PASS":
            passed[(t["rung"], t["change"])] = t
    for (rung, change), t in passed.items():
        run(rung, change, max_pairs, t["first_seed"] + 1000, t["delta"], t.get("need", ""), False)


def main():
    global LEVEL
    args = sys.argv[1:]
    option = lambda name, default: type(default)(args[args.index(name) + 1]) if name in args else default
    max_pairs = option("--max", 60)
    LEVEL = option("--level", LEVEL)  # (c) a weaker level as a sanity check: the change must not break it
    if args and args[0] == "queue":  # (d) one test per line of FILE: "rung change [--max N] [--need A,B] [--level L] [--logs]"; lines starting with # are skipped
        for line in open(args[1], encoding="utf-8"):
            if line.strip() and not line.startswith("#"):
                print(">>> " + line.strip(), flush=True)
                main_with(line.split())
        return
    if args and args[0] == "recheck":
        recheck(max_pairs)
        return
    if len(args) < 2 or args[0] not in RUNGS:
        print(__doc__)
        return
    rung, change = args[0], args[1]
    run(rung, change, max_pairs, option("--seed", RUNGS[rung]["seed"]), option("--delta", RUNGS[rung]["delta"]), option("--need", ""), "--logs" in args)


def main_with(words):
    """Runs one line of a queue file as if it were the command line."""
    saved = sys.argv
    sys.argv = [saved[0]] + words
    try:
        main()
    finally:
        sys.argv = saved


if __name__ == "__main__":
    main()
