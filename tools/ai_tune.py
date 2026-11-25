"""Hill-climbs the AI brain's numbers by duels, on its own, for as long as it is left running.

    python tools/ai_tune.py [--games 40] [--rounds 1000] [--state tools/ai_tune_state.json]

The numbers are the knobs of `BrainProfile.knob` (the table KNOBS below names each with the values worth trying). A round picks a knob and a value for it and plays
`--games` duels, level 9 against level 9, in the same worlds: one seat with the knob at that value, the other with the figures now stored in data/ai/knobs.json. When the
changed seat deals at least --win of the damage (0.57: about two and a third standard errors at 40 games), the value is written to data/ai/knobs.json for good, which every
brain then reads. Every round is written to the state file and to docs/ai_tune_log.md, so whoever reads it afterwards sees what was tried.
Run it with nothing else using the machine, and do not edit the brain's scripts while it runs: every game reads them afresh."""
import argparse, concurrent.futures, json, os, random, subprocess, tempfile, time

HOME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # where this tool lives: the log, the state and the stored figures are kept here
ROOT = os.environ.get("TUNE_GAME", HOME)  # the copy of the game the duels are played in (a snapshot, so that the scripts can be edited meanwhile)
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
OUT = os.path.join(tempfile.gettempdir(), "wizard_tune")
KNOB_FILE = os.path.join(HOME, "data", "ai", "knobs.json")
GAME_KNOB_FILE = os.path.join(ROOT, "data", "ai", "knobs.json")

# name: (the figure in the code, [values to try])
KNOBS = {
    "thrift": (6.0, [3.0, 4.5, 8.0, 10.0]),
    "res_lo": (14.0, [6.0, 22.0, 30.0]),
    "res_hi": (56.0, [30.0, 80.0, 110.0]),
    "res_exit": (2.4, [1.5, 3.5, 5.0]),
    "gap_s": (1.6, [1.0, 2.2]),
    "gap_q": (0.8, [0.5, 1.1, 1.5]),
    "range": (460.0, [360.0, 560.0, 700.0]),
    "close": (95.0, [60.0, 140.0, 200.0]),
    "repeat": (0.25, [0.1, 0.5, 0.8]),
    "bold": (0.62, [0.45, 0.8]),
    "aggr": (1.0, [0.5, 1.5, 2.0]),
}


def stored():
    try:
        return json.load(open(KNOB_FILE))
    except Exception:
        return {}


def play(seed, change):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "t_%d.jsonl" % seed)
    if os.path.exists(path):
        os.remove(path)
    changed_seat = 1 if seed % 2 == 0 else 0  # the seat that carries the change swaps from game to game
    args = ["mode=duel", "seed=%d" % seed, "seconds=120", "lv=9,9", "off%d=%s" % (changed_seat, change), "result=" + path]
    try:
        subprocess.run([GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "tests/tools/ai_arena.tscn", "--"] + args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)
        r = json.loads(open(path).readline())
    except Exception:
        return None
    taken = r.get("taken", {})
    dealt, lost = taken.get(str(1 - changed_seat), 0), taken.get(str(changed_seat), 0)  # what the other seat lost to the changed one, and what it lost itself
    return (dealt, lost, r["fell"][str(changed_seat)], r["fell"][str(1 - changed_seat)])


def round_of(change, games, first_seed):
    with concurrent.futures.ThreadPoolExecutor(6) as pool:
        results = [r for r in pool.map(lambda k: play(first_seed + k, change), range(games)) if r]
    shares, wins, losses = [], 0, 0
    for dealt, lost, fell_me, fell_other in results:
        if dealt + lost > 0:
            shares.append(dealt / (dealt + lost))
        if fell_me < 0 and fell_other >= 0:
            wins += 1
        elif fell_other < 0 and fell_me >= 0:
            losses += 1
    n = len(shares)
    mean = sum(shares) / n if n else 0.5
    sd = (sum((x - mean) ** 2 for x in shares) / max(1, n - 1)) ** 0.5
    return mean, sd / max(1, n) ** 0.5, wins, losses, len(results)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=40)
    ap.add_argument("--rounds", type=int, default=1000)
    ap.add_argument("--win", type=float, default=0.57)
    ap.add_argument("--state", default=os.path.join(HOME, "tools", "ai_tune_state.json"))
    a = ap.parse_args()
    state = json.load(open(a.state)) if os.path.exists(a.state) else {"tried": {}, "round": 0}
    log_path = os.path.join(HOME, "docs", "ai_tune_log.md")
    if not os.path.exists(log_path):
        open(log_path, "w").write("# What the tuning run tried (tools/ai_tune.py)\n\nShare = the damage the changed seat dealt of all the damage in the duels (0.5 is a tie; about 0.04 is noise at 40 games).\n\n")
    rng = random.Random(state["round"])
    for _ in range(a.rounds):
        state["round"] += 1
        now = stored()
        options = []
        for name, (base, values) in KNOBS.items():
            current = now.get(name, base)
            for v in values:
                key = "%s=%s@%s" % (name, v, current)
                if v != current and key not in state["tried"]:
                    options.append((name, v, key))
        if not options:
            state["tried"] = {}  # everything has been tried against the figures now stored: begin again (a figure that lost then may win beside the others)
            continue
        name, value, key = rng.choice(options)
        before = now.get(name, KNOBS[name][0])
        started = time.time()
        mean, err, wins, losses, n = round_of("kn_%s=%s" % (name, value), a.games, 20000 + state["round"] * 100)
        verdict = "KEPT" if mean >= a.win else ("worse" if mean <= 1 - a.win else "no difference")
        state["tried"][key] = [round(mean, 3), round(err, 3)]
        if verdict == "KEPT":
            now = stored()
            now[name] = value
            json.dump(now, open(KNOB_FILE, "w"), indent=1)
            if GAME_KNOB_FILE != KNOB_FILE:
                json.dump(now, open(GAME_KNOB_FILE, "w"), indent=1)
        json.dump(state, open(a.state, "w"), indent=1)
        line = "- %s  %s %s (stored %s): %d duels, share %.3f +- %.3f, won %d lost %d, %.0f min -> %s\n" % (time.strftime("%H:%M"), name, value, before, n, mean, err, wins, losses, (time.time() - started) / 60, verdict)
        open(log_path, "a").write(line)
        print(line.strip(), flush=True)


if __name__ == "__main__":
    main()
