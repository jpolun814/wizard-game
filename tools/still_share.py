"""How much of a match the AI wizards spend standing still, from match logs (MatchRecorder): the figure the movement planning has to bring down
(docs/handoff/23_movement_planning.md, section 4).

    python -I tools/still_share.py LOG_OR_FOLDER ...            what the logs say
    python -I tools/still_share.py --play SEED[,SEED] [--times 4] [--seconds 120] [--out FOLDER]
                                                                plays those matches' first worlds with AI wizards only, several times each with different dice, and reports

Only AI wizards are counted, while they are alive and in a world (not the waiting room or a duel). Still: less than 6 px in half a second. It says apart how much of that was
spent drawing, chanting, resting or recharging by the log's own flags (P, C, R), since a wizard may stand for a reason; "for nothing" is the rest, and with the stamina full.
A long stand is 12 s or more within 6 px.
"""
import argparse
import collections
import glob
import math
import os
import statistics
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = r"C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
STEP, NEAR, LONG = 0.5, 6.0, 12.0


def read(path):
    """The AI wizards of one log: name -> [(t, x, y, stamina, maximum, flags)], half a second apart, up to where each fell. The log's biome."""
    biome, rows, names, fell = "", collections.defaultdict(list), {}, {}
    with open(path, encoding="utf-8", errors="ignore") as lines:
        for line in lines:
            p = line.split()
            if len(p) < 3:
                continue
            if p[1] == "HEAD":
                if "Lab" in p or "Duel" in p:
                    return "", {}
                biome = p[-1] if p[-2] == "biome" else ""
            elif p[1] == "FALL":
                fell[p[2]] = float(p[0])
            elif p[1] == "WZ" and len(p) >= 17 and (p[4] == "brain"):
                t = float(p[0])
                mine = rows[p[2]]
                if not mine or t - mine[-1][0] >= STEP - 0.01:
                    mine.append((t, float(p[6]), float(p[7]), float(p[12]), float(p[13]), p[14]))
                names[p[2]] = p[3]
    return biome, {names[i] + " " + i[-4:]: [r for r in mine if r[0] <= fell.get(i, math.inf)] for i, mine in rows.items()}


def measure(rows):
    """(seconds, still, still for nothing, longest stand, long stands) of one wizard."""
    still = nothing = 0.0
    longest, stands, since = 0.0, 0, 0
    for k in range(1, len(rows)):
        t, x, y, stamina, most, flags = rows[k]
        if math.dist((x, y), rows[k - 1][1:3]) < NEAR:
            still += STEP
            if not set(flags) & set("PCRZF") and stamina >= most - 1.0:
                nothing += STEP
        if math.dist((x, y), rows[since][1:3]) >= NEAR:
            length = rows[k - 1][0] - rows[since][0]
            longest, stands, since = max(longest, length), stands + (length >= LONG), k
    if rows:
        length = rows[-1][0] - rows[since][0]
        longest, stands = max(longest, length), stands + (length >= LONG)
    return len(rows) * STEP, still, nothing, longest, stands


def report(paths):
    by_biome = collections.defaultdict(list)
    for path in paths:
        biome, wizards = read(path)
        for rows in wizards.values():
            if len(rows) * STEP >= 10.0:
                by_biome[biome].append((path,) + measure(rows))
    print("%-12s %6s %8s %7s %12s %14s %12s" % ("biome", "logs", "wizards", "still", "for nothing", "longest stand", "long stands"))
    everyone = [w for group in by_biome.values() for w in group]
    for biome, group in sorted(by_biome.items()) + ([("all", everyone)] if len(by_biome) > 1 else []):
        logs = collections.defaultdict(list)
        for w in group:
            logs[w[0]].append(w)
        seconds = sum(w[1] for w in group)
        shares = [sum(w[3] for w in log) / sum(w[1] for w in log) for log in logs.values()]
        spread = " +-%2.0f" % (100 * statistics.stdev(shares) / math.sqrt(len(shares))) if len(shares) > 1 else ""
        print("%-12s %6d %8d %6.0f%% %8.0f%%%-4s %12.0f s %12d" % (biome, len(logs), len(group), 100 * sum(w[2] for w in group) / seconds, 100 * sum(w[3] for w in group) / seconds, spread,
                                                              max(w[4] for w in group), sum(w[5] for w in group)))


def play(seeds, times, seconds, out):
    os.makedirs(out, exist_ok=True)
    before = set(glob.glob(os.path.join(out, "*", "match_*.log")))
    jobs = [(seed, k) for seed in seeds for k in range(times)]
    running = []
    while jobs or running:
        while jobs and len(running) < 3:
            seed, k = jobs.pop(0)
            folder = os.path.join(out, "%d_%d" % (seed, k))
            os.makedirs(folder, exist_ok=True)
            running.append(subprocess.Popen([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--", "mode=royale", "seed=%d" % seed, "dice=%d" % k, "seconds=%d" % seconds,
                                             "lv=9,9,9,9,9,9,9,9", "players=8", "matchlog=" + folder, "result=" + os.path.join(folder, "result.jsonl")], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
        running[0].wait()
        running = [job for job in running if job.poll() is None]
    return sorted(set(glob.glob(os.path.join(out, "*", "match_*.log"))) - before)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("logs", nargs="*")
    parser.add_argument("--play", default="")
    parser.add_argument("--times", type=int, default=4)
    parser.add_argument("--seconds", type=int, default=120)
    parser.add_argument("--out", default=os.path.join(os.environ.get("TEMP", "."), "wizard_still"))
    options = parser.parse_args()
    found = []
    for name in options.logs:
        found += sorted(glob.glob(os.path.join(name, "match_*.log"))) if os.path.isdir(name) else [name]
    if options.play:
        found += play([int(s) for s in options.play.split(",")], options.times, options.seconds, options.out)
    report(found)
