"""Sets the AI brain against itself with ONE change turned off for one of the two wizards, to see what that change is worth.

    python tools/ai_ab.py combo 40                    40 duels, level 9 against level 9; the wizard that has `combo` turned off is the control
    python tools/ai_ab.py combo 40 Spark,Water_Jet    the same, with these spells in both books (underscores stand for spaces)

The change is named as BrainProfile.off(name) knows it. The sides swap every other game, so the seat does not matter. Prints the share of the damage the wizard WITH the
change dealt (0.5 means it is worth nothing) and the standard error, and its wins and losses. A duel result needs about 60 games before a difference of 0.04 means anything.
"""
import concurrent.futures
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
OUT = os.environ.get("BENCH_OUT", os.path.join(tempfile.gettempdir(), "wizard_ab"))
FIRST_SEED = int(os.environ.get("BENCH_SEED", "100"))
LEVEL = os.environ.get("BENCH_LEVEL", "9")


MODE = os.environ.get("BENCH_MODE", "duel")  # BENCH_MODE=royale: whole matches of eight, seats 0 and 1 differing by the change, compared by mean finishing place


def play(change, seed, need):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "%s_%d.jsonl" % (change.replace(",", "+"), seed))
    if os.path.exists(path):
        os.remove(path)
    off_seat = 1 if seed % 2 == 0 else 0  # (the control's seat swaps from game to game)
    args = ["mode=%s" % MODE, "seed=%d" % seed, "seconds=%d" % (120 if MODE == "duel" else 1100), "lv=%s" % ",".join([LEVEL] * (2 if MODE == "duel" else 8)), "off%d=%s" % (off_seat, change), "result=" + path]
    if need:
        args.append("need=" + need)
    subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--"] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        result = json.loads(f.readline())
    result["control"] = off_seat
    return result


def main():
    change, count = sys.argv[1], int(sys.argv[2])
    need = sys.argv[3] if len(sys.argv) > 3 else ""
    with concurrent.futures.ThreadPoolExecutor(6) as pool:
        results = [r for r in pool.map(lambda k: play(change, FIRST_SEED + k, need), range(count)) if r]
    if MODE == "royale":
        places = {"with": [], "without": []}
        for r in results:
            left = {int(k): v for k, v in r["stamina"].items()}
            times = {int(k): (v if v >= 0 else 1e9 + left[int(k)]) for k, v in r["fell"].items()}
            order = sorted(times, key=lambda seat: -times[seat])
            for place, seat in enumerate(order, 1):
                if seat == r["control"]:
                    places["without"].append(place)
                elif seat == 1 - r["control"]:
                    places["with"].append(place)
        mean = lambda xs: sum(xs) / len(xs) if xs else float("nan")
        print("%s (%d matches): mean place with it %.2f, without it %.2f (lower is better; the other six play as the change does)" % (change, len(results), mean(places["with"]), mean(places["without"])))
        return
    shares, wins, losses, draws = [], 0, 0, 0
    for r in results:
        control = r["control"]
        taken = r.get("taken", {})
        lost_control, lost_change = taken.get(str(control), 0), taken.get(str(1 - control), 0)
        if lost_control + lost_change > 0:
            shares.append(lost_control / (lost_control + lost_change))
        fell_control, fell_change = r["fell"][str(control)], r["fell"][str(1 - control)]
        if fell_control >= 0 and fell_change < 0:
            wins += 1
        elif fell_change >= 0 and fell_control < 0:
            losses += 1
        elif fell_control >= 0 and fell_change >= 0:
            wins, losses = (wins + 1, losses) if fell_control < fell_change else (wins, losses + 1)
        else:
            draws += 1
    mean = sum(shares) / len(shares) if shares else 0.5
    var = sum((x - mean) ** 2 for x in shares) / max(1, len(shares) - 1)
    print("%s (%d games): with it won %d, lost %d, drew %d; its share of the damage %.3f +- %.3f" % (change, len(results), wins, losses, draws, mean, (var / max(1, len(shares))) ** 0.5))


if __name__ == "__main__":
    main()
