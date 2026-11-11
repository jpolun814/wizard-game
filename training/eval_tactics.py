"""Measures a tactics network against the scripted brain in whole matches (tests/tactics_eval.tscn), and says whether it has won.

Each seed is played twice, the sides swapped: the network in seats 1,3,5,7 and then in 2,4,6 (seven AI seats, the person's empty), so that over a
pair both sides hold seven seats of fourteen and an even match is 50%. Draws (time ran out with both sides standing) are left out of the share.
Prints one line a match and a summary, and appends the summary to training/tactics/evals.log.

    python -I training/eval_tactics.py POLICY.json [--seeds 100] [--first 1000] [--jobs 3] [--pass 0.55]
"""
import argparse
import math
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

here = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(here)
GODOT = os.environ.get("GODOT_EXE", r"C:\Users\Jordan Polun\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
BELOW_NORMAL = 0x00004000
SIDES = ("1,3,5,7", "2,4,6")


def play(policy, seed, seats):
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", PROJECT, "res://tests/tactics_eval.tscn", "--", "seed=%d" % seed, "policy=" + policy, "seats=" + seats]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3600, creationflags=BELOW_NORMAL).stdout
    except subprocess.TimeoutExpired:
        return {"seed": seed, "seats": seats, "side": "none", "error": "timeout"}
    m = re.search(r"RESULT seed=(\d+) seats=(\S+) winner=(-?\d+) side=(\w+) seconds=(\d+)", out)
    if not m:
        return {"seed": seed, "seats": seats, "side": "none", "error": "no result"}
    return {"seed": seed, "seats": seats, "winner": int(m.group(3)), "side": m.group(4), "seconds": int(m.group(5))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("policy", help="res:// path (or a file in the project) of an exported network")
    parser.add_argument("--seeds", type=int, default=100)
    parser.add_argument("--first", type=int, default=1000, help="the first seed (kept apart from the training seeds, 0-39)")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--pass", dest="mark", type=float, default=0.55)
    parser.add_argument("--log", default=os.path.join(here, "tactics", "evals.log"))
    args = parser.parse_args()
    policy = args.policy
    if not policy.startswith("res://"):
        policy = "res://" + os.path.relpath(os.path.abspath(policy), PROJECT).replace("\\", "/")
    games = [(s, side) for s in range(args.first, args.first + args.seeds) for side in SIDES]
    began = time.time()
    results = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for r in pool.map(lambda g: play(policy, g[0], g[1]), games):
            results.append(r)
            print("seed %d seats %-8s -> %s%s" % (r["seed"], r["seats"], r["side"], (" (%s)" % r["error"]) if "error" in r else ""), flush=True)
    won = sum(1 for r in results if r["side"] == "trained")
    lost = sum(1 for r in results if r["side"] == "scripted")
    decided = won + lost
    share = won / decided if decided else 0.0
    # How sure: the chance an even side would do this well or better by luck (a normal approximation to the binomial).
    z = (won - decided * 0.5) / math.sqrt(decided * 0.25) if decided else 0.0
    passed = decided >= 20 and share >= args.mark
    line = "%s %s: trained won %d, scripted %d, draws %d (%d matches): share %.3f, z %.2f, %s, %.0f min" % (
        time.strftime("%Y-%m-%d %H:%M"), policy, won, lost, len(results) - decided, len(results), share, z, "PASS" if passed else "not yet", (time.time() - began) / 60)
    print(line)
    os.makedirs(os.path.dirname(args.log), exist_ok=True)
    with open(args.log, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
