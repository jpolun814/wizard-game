"""Measures the limits of a person's body from the play recordings, for holding the AI wizards to them.

Reads every recording (the person's own in user://play_logs, and the gzipped ones other players sent from network matches in
user://received_logs) and prints, with the median and the middle half (25th to 75th percentile) of each:

- stroke time: a mouse button down to the last button up, for strokes that cast a spell (a C line just after), per spell;
- chord gap: in a stroke drawn with two or three buttons, the time from the first button down to the last one down;
- typing: seconds a letter, from the R lines (the chant words as they are typed);
- reading: from a new page in the book (a P line that adds a spell) to the first cast of that spell (mostly how long until it was wanted);
- look: how long the book stays open at a new page (Tab reads a page and opens the book at it; the next Tab or Escape shuts it);
- reaction: from a shot thrown by someone else appearing near the person (an X Projectile line not by the person) or from being hurt
  (a D line) to the person's next key or button going down.

Writes the figures as JSON (default ai/human_limits.json) for the brains to read.

    python -I training/measure_human.py [--out ai/human_limits.json]
"""
import argparse
import glob
import gzip
import json
import os
import re
import statistics


def user_dir():
    return os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "wizard-game")


def lines_of(path):
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 2:
                continue
            try:
                t = float(parts[0])
            except ValueError:
                continue
            yield t, parts[1], parts[2:]


def spread(values):
    values = sorted(v for v in values if v is not None)
    if not values:
        return None
    q = statistics.quantiles(values, n=4) if len(values) >= 4 else [values[0], statistics.median(values), values[-1]]
    return {"n": len(values), "median": round(statistics.median(values), 3), "p25": round(q[0], 3), "p75": round(q[2], 3)}


def measure(paths):
    strokes = {}      # spell -> [seconds]
    chord_gaps = []
    letters = []
    reading = []
    reactions = []
    looks = []
    for path in paths:
        look_from = None  # a new page came into the book at this time, and the book has not been opened since
        held = set()
        stroke_start = None
        downs = []
        last_up = None
        stroke_time = None
        pending_gap = None
        book = set()
        new_pages = {}    # spell -> time it came into the book
        typing_prev = None
        stimuli = []      # times of things to react to, waiting for the next key down
        me = None
        for t, kind, rest in lines_of(path):
            if kind == "K" and len(rest) >= 3:
                what, code, state = rest[0], rest[1], rest[2]
                if what == "key" and code in ("Tab", "Escape") and state == "up" and look_from is not None and t - look_from > 0.2:
                    if t - look_from < 60.0:
                        looks.append(t - look_from)  # the book is shut again: the page has been read
                    look_from = None
                if state == "down":
                    for s in stimuli:
                        if 0.08 <= t - s <= 1.5:
                            reactions.append(t - s)
                    stimuli = []
                if what == "mouse" and code in ("1", "2", "3"):
                    if state == "down":
                        if not held:
                            stroke_start = t
                            downs = []
                        held.add(code)
                        downs.append(t)
                    elif state == "up" and code in held:
                        held.discard(code)
                        if not held and stroke_start is not None:
                            stroke_time = t - stroke_start
                            last_up = t
                            gap = downs[-1] - downs[0] if len(downs) > 1 else None
                            stroke_start = None
                            pending_gap = gap
                            continue
            elif kind == "C" and rest:
                spell = " ".join(rest).replace("_", " ")
                if last_up is not None and t - last_up < 0.2 and stroke_time is not None:
                    strokes.setdefault(spell, []).append(stroke_time)
                    if pending_gap is not None:
                        chord_gaps.append(pending_gap)
                    last_up = None
                if spell in new_pages:
                    reading.append(t - new_pages.pop(spell))
            elif kind == "R" and rest:
                words = " ".join(rest)
                if typing_prev is not None and len(words) == len(typing_prev[1]) + 1 and t - typing_prev[0] < 2.0:
                    letters.append(t - typing_prev[0])
                typing_prev = (t, words)
            elif kind == "P" and rest:
                pages = set(p.replace("_", " ") for p in rest[0].split("|") if p and not p.startswith("chant:"))
                for p in pages - book:
                    if book or len(pages) <= 1:  # (the first P line is the starting book: nothing new to read)
                        new_pages[p] = t
                        look_from = t
                book = pages
            elif kind == "X" and rest and rest[0] == "Projectile":
                by = next((r[3:] for r in rest if r.startswith("by:")), "")
                if me is None and last_up is not None and t - last_up < 0.3:
                    me = by  # a shot that appears as the person lets go of a stroke is theirs: that names the person
                if by and me is not None and by != me:
                    stimuli.append(t)
            elif kind == "D":
                stimuli.append(t)
    return {
        "strokes": {k: spread(v) for k, v in sorted(strokes.items())},
        "chord_gap": spread(chord_gaps),
        "letter": spread(letters),
        "reading": spread(reading),
        "look": spread(looks),
        "reaction": spread(reactions),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="ai/human_limits.json")
    args = parser.parse_args()
    root = user_dir()
    paths = sorted(glob.glob(os.path.join(root, "play_logs", "*.log")) + glob.glob(os.path.join(root, "received_logs", "*.gz")))
    paths = [p for p in paths if os.path.getsize(p) > 5000]
    result = measure(paths)
    result["files"] = len(paths)
    print(json.dumps({k: v for k, v in result.items() if k != "strokes"}, indent=1))
    for spell, s in result["strokes"].items():
        print("%-16s %s" % (spell, s))
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
