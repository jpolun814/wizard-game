"""Writes the training report's data as CSV files, from the logs: training/report/rounds.csv (one row a round of tactics training),
evals.csv (one row an evaluation against the scripted brain) and work.csv (the dated lines of training/limits_progress.md).
The report page (a dashboard artifact) is given these files about every hour.

    python -I training/report_data.py
"""
import csv
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(here, "report")

ROUND = re.compile(r"^(\S+ \S+) round (\d+) seed (\d+) opponent (\S+): reward per decision (-?[\d.]+) over (\d+) decisions, (\d+) s, steps (\d+)")
EVAL = re.compile(r"^(\S+ \S+) (\S+): trained won (\d+), scripted (\d+), draws (\d+) \((\d+) matches\): share ([\d.]+), z (-?[\d.]+), (PASS|not yet)")
WORK = re.compile(r"^- (2026-\d\d-\d\d)(?: ~?(\d\d:\d\d))?: (.*)$")


def write(name, header, rows):
    with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def main():
    os.makedirs(OUT, exist_ok=True)
    rounds = []
    path = os.path.join(here, "tactics", "progress.log")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            m = ROUND.match(line.strip())
            if m:
                rounds.append([int(m.group(2)), m.group(1).replace(" ", "T"), float(m.group(5)), int(m.group(6)), int(m.group(7)), int(m.group(8)), int(m.group(3)), m.group(4)])
    write("rounds.csv", ["round", "finished", "reward_per_decision", "decisions", "seconds", "total_steps", "world_seed", "opponent"], rounds)
    evals = []
    path = os.path.join(here, "tactics", "evals.log")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            m = EVAL.match(line.strip())
            if m:
                evals.append([m.group(1).replace(" ", "T"), os.path.basename(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)), float(m.group(7)), float(m.group(8)), m.group(9)])
    write("evals.csv", ["at", "network", "trained_won", "scripted_won", "draws", "matches", "trained_share", "z", "verdict"], evals)
    work = []
    for line in open(os.path.join(here, "limits_progress.md"), encoding="utf-8"):
        m = WORK.match(line.rstrip("\n"))
        if m:
            work.append([m.group(1) + ("T" + m.group(2) if m.group(2) else ""), m.group(3)])
    write("work.csv", ["at", "note"], work)
    print("rounds %d, evals %d, work notes %d -> %s" % (len(rounds), len(evals), len(work), OUT))


if __name__ == "__main__":
    main()
