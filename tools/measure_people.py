"""Measures, from the owner's own recorded matches, the two figures about people that `SpellFacts` assumes (scripts/spells/spell_facts.gd):

    python -I tools/measure_people.py [LOG_FOLDER]

  FREE_LANDING  how often a shot thrown at a wizard lands, when the wizard is moving and when it is standing still
  REACTION      how long a person takes to answer a shot coming at them (turn, or jump) from the moment it is thrown

It reads the match logs written by MatchRecorder (scripts/ui/match_recorder.gd; the default folder is the game's user://match_logs), and only the logs of
real play: those with key presses in them (K lines). A shot is taken to be thrown at the nearest other wizard to where it was made, if one is within
AIMED_WITHIN pixels; it lands if that wizard takes a blow from the same caster with the same kind of shot before the shot is gone (or SOON seconds, if it
lasts). Nothing here is exact (a shot can be aimed at no one, and a wizard may be held or shielded), so the figures are read as rough, and every one is printed
with the number of cases behind it.
"""
import collections
import glob
import math
import os
import statistics
import sys

APPDATA = os.environ.get("APPDATA", "")
DEFAULT = os.path.join(APPDATA, "Godot", "app_userdata", "wizard-game", "match_logs")
AIMED_WITHIN = 900.0   # a shot made farther than this from every wizard is taken to be aimed at no one
MOVING = 40.0          # px/s: faster than this is "moving"
SOON = 3.0             # seconds a shot is given to land, at the most, from when it is made
COMING = 400.0         # a shot closer than this to a wizard is "coming at" them (for the reaction time)
ANSWER_WITHIN = 2.0    # seconds: a turn or a jump later than this after the shot came is not an answer to it
JUMP_SPEED = -200.0    # px/s upward that is a jump
MIN_MOUSE = 300        # M lines (the mouse, twenty times a second) a log must hold to be a person's play


def read(path):
    """The log as: wizards {id: {"name", "kind", "rows": [(t, x, y, vx, vy)]}}, shots {id: {"owner", "cls", "t", "x", "y", "path": [(t, x, y)]}}, hits [(t, victim, by, cls)]."""
    wizards = {}
    shots = {}
    hits = []
    keys = 0
    mouse = 0
    for line in open(path, encoding="utf-8", errors="ignore"):
        p = line.split()
        if len(p) < 3:
            continue
        try:
            t = float(p[0])
        except ValueError:
            continue
        k = p[1]
        if k == "WZ" and len(p) >= 19:
            w = wizards.setdefault(p[2], {"name": p[3], "kind": p[4], "rows": []})
            if p[15] != "death":
                w["rows"].append((t, float(p[6]), float(p[7]), float(p[8]), float(p[9])))
        elif k == "NEW" and len(p) >= 8 and p[-1] == "shot":
            shots[p[2]] = {"owner": p[4], "cls": p[3], "t": t, "x": float(p[5]), "y": float(p[6]), "path": [(t, float(p[5]), float(p[6]))]}
        elif k == "OB" and len(p) >= 7 and p[2] in shots:
            shots[p[2]]["path"].append((t, float(p[5]), float(p[6])))
        elif k == "HIT" and len(p) >= 6 and p[3] != "-":
            hits.append((t, p[2], p[3], p[4]))
        elif k == "K":
            keys += 1
        elif k == "M":
            mouse += 1
    return wizards, shots, hits, keys + (0 if mouse >= MIN_MOUSE else -keys)  # (a hand at the mouse moves it: a log with no mouse in it is a scripted check, not a person)


def at(rows, t):
    """The wizard's row nearest in time to t, if it is within a third of a second."""
    best = None
    for r in rows:
        if best is None or abs(r[0] - t) < abs(best[0] - t):
            best = r
        if r[0] > t + 0.5:
            break
    return best if best is not None and abs(best[0] - t) <= 0.35 else None


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    files = sorted(glob.glob(os.path.join(folder, "match_*.log")))
    landed = {kind: {"moving": [0, 0], "still": [0, 0]} for kind in ("person", "brain")}  # [landed, thrown]
    reactions = []
    unanswered = 0
    used = 0
    for f in files:
        wizards, shots, hits, keys = read(f)
        if keys < 6 or len(wizards) < 2:
            continue
        used += 1
        by_victim = collections.defaultdict(list)
        for t, victim, by, cls in hits:
            by_victim[victim].append((t, by, cls))
        for sid, shot in shots.items():
            # who it was thrown at: the nearest other wizard to where it was made
            best, best_d = None, AIMED_WITHIN
            for wid, w in wizards.items():
                if wid == shot["owner"]:
                    continue
                row = at(w["rows"], shot["t"])
                if row is None:
                    continue
                d = math.hypot(row[1] - shot["x"], row[2] - shot["y"])
                if d < best_d:
                    best, best_d, best_row = wid, d, row
            if best is None:
                continue
            target = wizards[best]
            speed = math.hypot(best_row[3], best_row[4])
            end = min(shot["path"][-1][0] + 0.5, shot["t"] + SOON)
            hit = any(shot["t"] <= t <= end and by == shot["owner"] and cls == shot["cls"] for t, by, cls in by_victim.get(best, []))
            cell = landed[target["kind"] if target["kind"] in landed else "brain"]["moving" if speed > MOVING else "still"]
            cell[0] += 1 if hit else 0
            cell[1] += 1
            # the person's answer to it: from the moment it came within COMING px, the next turn or jump
            if target["kind"] == "person":
                came = None
                for t, x, y in shot["path"]:
                    row = at(target["rows"], t)
                    if row and math.hypot(x - row[1], y - row[2]) < COMING:
                        came = (t, row)
                        break
                if came:
                    t0, row0 = came
                    answered = None
                    for r in target["rows"]:
                        if r[0] <= t0:
                            continue
                        if r[0] > t0 + ANSWER_WITHIN:
                            break
                        turned = row0[3] * r[3] < 0 and abs(r[3]) > MOVING and abs(row0[3]) > MOVING
                        jumped = r[4] < JUMP_SPEED and row0[4] > JUMP_SPEED
                        if turned or jumped:
                            answered = r[0] - t0
                            break
                    if answered is None:
                        unanswered += 1
                    else:
                        reactions.append(answered)
    print("%d logs of real play read (of %d)" % (used, len(files)))
    print("\nFREE_LANDING: shots thrown at a wizard that landed (assumed in spell_facts.gd: 0.6)")
    for kind in ("person", "brain"):
        for state in ("moving", "still"):
            n_hit, n = landed[kind][state]
            print("  at %-6s while %-6s: %3d of %4d  = %s" % ("a person" if kind == "person" else "an AI", state, n_hit, n, "%.0f%%" % (100.0 * n_hit / n) if n else "n/a"))
    print("\nREACTION: seconds from a shot coming within %.0f px of the person to their next turn or jump (assumed REACTION: 0.8)" % COMING)
    if reactions:
        q = statistics.quantiles(reactions, n=4) if len(reactions) >= 4 else [min(reactions)] * 3
        print("  answered %d, no answer within %.0f s: %d; median %.2f s (quartiles %.2f to %.2f)" % (len(reactions), ANSWER_WITHIN, unanswered, statistics.median(reactions), q[0], q[2]))
        print("  note: the person does not always need to answer (a shot may miss), so 'no answer' is not a failure")
    else:
        print("  no cases")


if __name__ == "__main__":
    main()
