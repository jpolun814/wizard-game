"""Reads the history that tools/test.py keeps (reports/test_history.jsonl) and says which checks do not give the same answer twice, and which are getting slower.

    python tools/flakes.py            the report
    python tools/flakes.py --last 20  only the last 20 runs

A check that has both passed and failed (or needed its second try) over the runs is flaky: it is a check that cannot be trusted, or a game that is not steady.
The cure is never a retry: find what differs between the runs (a die that is not fixed, a wait that is a guess, something left from the check before).
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HISTORY = os.path.join(ROOT, "reports", "test_history.jsonl")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--last", type=int, default=0)
    options = parser.parse_args()
    if not os.path.exists(HISTORY):
        print("no history yet: it is written by every run of tools/test.py")
        return 0
    runs = [json.loads(line) for line in open(HISTORY, encoding="utf-8") if line.strip()]
    if options.last:
        runs = runs[-options.last:]
    names = sorted({n for run in runs for n in run["results"]})
    print("%d runs, %d checks" % (len(runs), len(names)))
    flaky = []
    for name in names:
        seen = [run["results"][name] for run in runs if name in run["results"]]
        counts = {s: sum(1 for r in seen if r["status"] == s) for s in ("ok", "failed", "flaky")}
        if counts["flaky"] or (counts["failed"] and counts["ok"]):
            flaky.append((name, counts, len(seen)))
    print("\nFLAKY (%d):" % len(flaky))
    for name, counts, total in sorted(flaky, key=lambda t: -(t[1]["flaky"] + t[1]["failed"])):
        print("  %-34s %d runs: %d ok, %d failed, %d passed only on the second try" % (name, total, counts["ok"], counts["failed"], counts["flaky"]))
    print("\nSLOWER THAN IT WAS (the last run against the median of the rest, over 25% and 10 s):")
    slower = []
    for name in names:
        times = [run["results"][name]["seconds"] for run in runs if name in run["results"]]
        if len(times) >= 4:
            rest = sorted(times[:-1])
            median = rest[len(rest) // 2]
            if times[-1] > median * 1.25 and times[-1] - median > 10.0:
                slower.append((name, median, times[-1]))
    for name, median, last in sorted(slower, key=lambda t: t[1] - t[2]):
        print("  %-34s %.0f s -> %.0f s" % (name, median, last))
    if not slower:
        print("  none")
    return 0


if __name__ == "__main__":
    sys.exit(main())
