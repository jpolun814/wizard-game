"""Runs the game's checks side by side and prints one line for each: ok, or FAILED with where its output is and why.

    python tools/run_checks.py                 the quick set
    python tools/run_checks.py --full          the quick set and the slow checks: whole matches, two or three copies talking over a network
    python tools/run_checks.py -j 3 stairs     only checks with "stairs" in the name, three copies of the game at a time
    python tools/run_checks.py --twice         each check twice with the same dice, comparing the two runs frame by frame: they must be the same
    python tools/run_checks.py --seeds 2-6     each check with five other seeds, to see whether it holds in other games too
    python tools/run_checks.py --cov           also measure line coverage (see tools/coverage_run.py)

(--all is the old name of --full.) Pictures that need a window are not in either. A check comes out the same every time, however busy the computer is:
  * it runs in a copy of the project as it was when the run began, with a save folder of its own (tools/steady.py);
  * the dice start from a seed, and every frame is as long as every other (scripts/core/steady_run.gd);
  * the copies of a network check go frame by frame together, and what they say goes through the runner: no port of the computer's is named, and nothing waits for a clock;
  * it is called stuck by how much work it has done, never by how long that took;
  * and it is run once. A check that fails has failed: there is no second try, and nothing is called flaky.
The long checks are split into shards that run side by side (a name ending #1, #2... is one shard), and the longest start first, by how long each took last time.
Each check's output is kept in the folder given by CHECK_OUT (default: a temp folder), as check_<name>.txt. Exit code is the number of checks that failed.
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import steady

ROOT = steady.ROOT
GODOT = steady.GODOT

# (name, kind, arguments): "script" runs `-s tests/name.gd`, with none of the game's autoloads (only the gestures, which must do without them), "scene" runs the scene, "net" runs the scene once for each of the roles named.
CHECKS = [
    ("test_gestures", "script", ""),
    ("test_pages", "scene", ""),
    ("test_nav#1", "scene", "seeds=2 first=0"),
    ("test_nav#2", "scene", "seeds=2 first=2"),
    ("test_nav#3", "scene", "seeds=2 first=4"),
    ("test_stages", "scene", "seeds=4"),
    ("test_liquid", "scene", ""),
    ("knowledge_check", "scene", ""),
] + [(name, "scene", "") for name in (
    "scripts_load_check", "movement_paths_check", "sound_ownership_check", "sound_cues_check", "flow_check", "tutorial_check", "tutorial_path_check", "menu_check", "settings_check", "lab_revive_check", "level_wall_check", "dither_check", "behind_wall_check", "likeness_check", "parts_check", "pose_check", "stairs_check", "stairwell_check", "castle_spells_check", "castle_sinkhole_fall_check",
    "biome_jump_check", "page_underfoot_check", "earthquake_check", "stonefall_check", "sinkhole_check", "sinkhole_biomes_check", "ridge_check", "stalagmite_check", "parity_check", "air_momentum_check", "coating_check", "laws_check", "spell_sweep_check", "lifecycle_check", "laws_matrix_check", "mob_sweep_check", "spellbook_check", "controls_check", "forced_stroke_check", "bubbles_check", "combo_check", "interaction_check",
    "ritual_check", "library_screen_check", "avalanche_check", "pieces_check", "spellbook_order_check", "arrival_check", "sneak_check", "decoy_hint_check", "lights_check", "frost_ground_check", "page_flight_check", "duel_check", "new_spells_check", "heal_check", "punch_check", "hit_source_check", "limits_check",
    "cluster_check", "brains_start_check", "blizzard_freeze_check", "blizzard_melt_check", "group_a_check", "group_d_check", "flytrap_check", "snail_check", "podium_check", "group_c_check", "group_b_check", "leech_check", "raise_dead_check", "golem_check", "mirage_check", "recorder_check", "log_upload_check", "sphere_check", "lab_sphere_check", "eye_check", "puppet_swing_check",
)] + [("route_check", "scene", "seed=7 moves=90"), ("soak_check", "scene", "seconds=12 only=graveyard,ocean,sky")] + [("brain_spells_check#%d" % k, "scene", "shard=%d/4" % k) for k in range(4)]

# Slower checks, or ones that need arguments: run with --full. (route_check goes on to more moves than the quick set's.)
SLOW = [("soak_check#a", "scene", "seconds=40 only=graveyard,mountains,jungle"), ("soak_check#b", "scene", "seconds=40 only=ashlands,castle,underground"), ("soak_check#c", "scene", "seconds=40 only=portals,ocean,sky"), ("route_check#a", "scene", "seed=7 moves=260"), ("intro_check#online", "scene", "mode=online"), ("debug_end_check#win", "scene", "mode=win"), ("debug_end_check#lose", "scene", "mode=lose"), ("route_check#b", "scene", "seed=3 moves=150"),
        ("ai_drills_check#0", "scene", "shard=0/4"), ("ai_drills_check#1", "scene", "shard=1/4"), ("ai_drills_check#2", "scene", "shard=2/4"), ("ai_drills_check#3", "scene", "shard=3/4"),
        ("net_check", "net", "host,client"), ("net_crowd_check", "net", "host,first,second"), ("net_hazard_check", "net", "host seed=2,client seed=2"),
        ("net_match_check", "net", "host,client"), ("dedicated_check", "net", "server,client"), ("net_spells_check", "net", "host,client"), ("test_world#1", "scene", "seeds=5 first=0"), ("test_world#2", "scene", "seeds=5 first=5"), ("test_world#3", "scene", "seeds=5 first=10"), ("test_world#4", "scene", "seeds=5 first=15"), ("test_world#5", "scene", "seeds=5 first=20"), ("test_world#6", "scene", "seeds=5 first=25"), ("showcase:checks", "scene", "scenario=checks"), ("showcase:newspells", "scene", "scenario=newspells")] + [(name, "scene", "") for name in (
    "collapse_check", "gate_check", "follow_check", "geyser_check", "wall_liquid_check", "eruption_check", "dark_check", "spectate_check", "stats_check",
    "pull_check", "spark_check", "canopy_check", "regen_check", "sentinel_check", "knight_check", "wild_shape_check", "liquid_world_check", "dig_out_check", "lab_sinkhole_check", "page_count_check",
    "portal_world_check", "ocean_world_check", "sky_world_check", "spell_fixes_check", "spoils_check", "stage_jump_check", "intro_check", "epilogue_check", "epilogue_jump_check", "eclipse_check", "minimap_check",
)]


NET_ENV = {"dedicated_check": {"WIZARD_HURRY": "0.4"}}  # what every copy of a network check is told besides its role


def log_folder():
    """Where this run writes its logs: a folder of its own under one for this copy of the project, so that two runs at once (or a run in another
    worktree) never write over each other's logs. The times of the checks (times.json) are kept one level up, shared by the runs of this copy."""
    folder = os.environ.get("CHECK_OUT")
    if folder:
        return folder
    base = steady.base_folder()
    folder = os.path.join(base, "run_%s_%d" % (time.strftime("%m%d_%H%M%S"), os.getpid()))
    os.makedirs(folder, exist_ok=True)
    runs = sorted(d for d in os.listdir(base) if d.startswith("run_"))
    for old in runs[:-12]:  # (the last twelve runs are kept)
        shutil.rmtree(os.path.join(base, old), ignore_errors=True)
    return folder


def test_file(name, extension):
    """Where a check's file is: the checks, the looks (a scenario of the showcase) or the tools (a simulation) folder of tests/."""
    for folder in ("checks", "looks", "tools"):
        path = "tests/%s/%s.%s" % (folder, name, extension)
        if os.path.exists(os.path.join(ROOT, path)):
            return path
    return "tests/checks/%s.%s" % (name, extension)


# Engine errors that are only the game closing with things still alive (a check quits without freeing its world): not the check's finding.
SHUTDOWN_NOISE = ("still in use at exit", "RID allocations", "leaked at exit", "ObjectDB instances leaked", "Pages in use exist at exit", "RenderingServer::get_singleton",
                  "were leaked", "Resource still in use", "instances of", "orphan")


def engine_errors(text):
    """How many lines the engine printed as an ERROR that are not shutdown noise: a mesh built from nothing, a polygon that cannot be filled, a bad parameter.
    They are not script errors and they do not stop the game, so nothing failed on them until they were counted."""
    return sum(1 for line in text.splitlines() if line.startswith("ERROR:") and not any(n in line for n in SHUTDOWN_NOISE))


def commands_of(check, project):
    """The command lines of a check, one for each copy of the game it is played by, and which of them are servers (they end when the others have)."""
    name, kind, args = check
    base = name.split("#")[0].split(":")[0]
    if kind == "script":
        return [[GODOT, "--headless", "--path", project, "-s", test_file(base, "gd")] + (["--"] + args.split() if args else [])], []
    start = [GODOT, "--headless", "--fixed-fps", "60", "--path", project]
    if kind == "scene":
        return [start + [test_file(base, "tscn")] + (["--"] + args.split() if args else [])], []
    roles = args.split(",")
    commands = [start + ["--", "--server"] if role == "server" else start + [test_file(base, "tscn"), "--", "role=" + role.split(" ")[0]] + role.split(" ")[1:] for role in roles]
    return commands, [k for k, role in enumerate(roles) if role == "server"]


SAID = re.compile(r"^\s*(PASS|FAIL)\b|\b(ok|PASS|PASSED|passed|FAILED)\b", re.M)
WENT_WRONG = re.compile(r"^\s*FAIL(ED)?\b|\bFAILED\b", re.M)


def run_one(check, folder, project, extra_env, instrumented, seed, trace=""):
    """Runs a check once. It passes when every copy ends with no error code, says that something held and that nothing did not, and neither the scripts nor the engine
    print an error. Nothing is run again: a check that fails has failed."""
    name, kind, args = check
    label = re.sub(r"[:#]", "_", name) + ("" if seed == 1 else "_s%d" % seed) + ("_again" if trace.endswith("2") else "")
    commands, lasting = commands_of(check, project)
    extra = dict(extra_env(label), **NET_ENV.get(name, {}))
    codes, texts, stuck, seconds = steady.run_copies(commands, folder, label, project, seed, trace, extra, lasting)
    text = ("\n" + "=" * 20 + "\n").join(texts) + ("\nFAILED: %s\n" % stuck if stuck else "")
    broken = text.count("SCRIPT ERROR") + engine_errors(text)
    why = []
    if stuck:
        why.append(stuck)
    elif any(codes):
        why.append("exit code %s" % ", ".join(str(c) for c in codes if c))
    if WENT_WRONG.search(text):
        why.append("something did not hold")
    if broken > 0 and not instrumented:
        why.append("%d errors printed" % broken)
    if not SAID.search(text):
        why.append("it did not say that anything held")
    if why:
        text += "\n(run_checks: %s; seed %d)\n" % ("; ".join(why), seed)
    path = os.path.join(folder, "check_%s.txt" % label)
    with open(path, "w", encoding="utf-8") as out:
        out.write(text)
    return not why, seconds, path, "; ".join(why), text


def says(text):
    """What a check printed, without what differs from run to run and is not the game's: how long things took, the numbers of objects, what was left at the end."""
    kept = [line for line in text.splitlines() if not line.startswith(("INFO", "   (")) and not any(n in line for n in SHUTDOWN_NOISE) and "at: cleanup" not in line and "at: clear" not in line]
    return [re.sub(r"#\d{6,}|\b\d{9,}\b", "#", re.sub(r"\b[\d.]+ ?(ms|s)\b", "# s", re.sub(r"\d{4}-\d\d-\d\dT[\d-]+", "#", line))) for line in kept]


def parted(traces, texts, copies, lasting):
    """Where two runs of a check first differ, or "". (A server is stopped from outside when the others have ended, so how far it got then is not compared.)"""
    for k in range(copies):
        a, b = ([line for line in open(t + ("" if copies == 1 else ".%d" % k), encoding="utf-8", errors="replace")] for t in traces)
        for x, y in zip(a, b):
            if x != y:
                return "parted at physics frame %s%s" % (x.split(" ")[0], "" if copies == 1 else " (copy %d)" % k)
        if len(a) != len(b) and k not in lasting:
            return "one run went on longer (%d and %d lines of trace)" % (len(a), len(b))
    a, b = says(texts[0]), says(texts[1])
    for x, y in zip(a, b):
        if x != y:
            return "printed differently: %s | %s" % (x[:110], y[:110])
    return "" if len(a) == len(b) else "one printed more lines"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("only", nargs="*", help="run only the checks whose name contains one of these")
    parser.add_argument("-j", type=int, default=os.cpu_count() or 4, help="how many copies of the game to run at once")
    parser.add_argument("--full", "--all", dest="all", action="store_true", help="the slower checks too")
    parser.add_argument("--skip", default="", help="comma-separated names of checks to leave out (tools/test.py leaves out the quarantined ones)")
    parser.add_argument("--seeds", default="1", help="the dice's seeds to run each check with: 1 unless told otherwise (2-6 runs each five times, with five different games)")
    parser.add_argument("--twice", action="store_true", help="run each check twice with the same seed and say where the two runs differ: they never should")
    parser.add_argument("--cov", action="store_true", help="measure line coverage in a scratch copy of the project")
    options = parser.parse_args()
    folder = log_folder()
    os.makedirs(folder, exist_ok=True)
    quick = [c for c in CHECKS if not (options.all and c[0] == "route_check")]  # the long route check replaces the short one
    skipped = [s for s in options.skip.split(",") if s]
    checks = [c for c in quick + (SLOW if options.all or options.only else []) if (not options.only or any(word in c[0] for word in options.only)) and c[0].split("#")[0] not in skipped]
    seeds = []
    for part in options.seeds.split(","):
        low, _, high = part.partition("-")
        seeds += range(int(low), int(high or low) + 1)
    extra_env = lambda name: {}
    if options.cov:
        import coverage_run
        project, extra_env = coverage_run.prepare(folder)
        checks = [c for c in checks if c[1] in ("scene", "net") and c[0] not in ("route_check", "test_world")]  # these two take too long counted line by line  # a script run with -s has no autoloads, so the counter cannot be there
    else:
        project = os.environ.get("WIZARD_PROJECT") or steady.project_copy()
    times_path = os.environ.get("CHECK_TIMES") or os.path.join(os.path.dirname(folder) if os.path.basename(folder).startswith("run_") else folder, "times.json")
    try:
        times = json.load(open(times_path))
    except (OSError, ValueError):
        times = {}
    checks.sort(key=lambda c: -times.get(c[0], 20.0))  # the longest first, so the short ones fill the gaps after
    started = time.time()
    failed, different = 0, []
    room = threading.Condition()
    free = [max(options.j, 3)]

    def run(check, seed):
        copies = len(commands_of(check, project)[0])
        with room:  # (a check of two copies takes the room of two)
            room.wait_for(lambda: free[0] >= copies)
            free[0] -= copies
        try:
            if not options.twice:
                return (check, seed) + run_one(check, folder, project, extra_env, options.cov, seed) + ("",)
            traces = [os.path.join(folder, "trace_%s_%d_%d" % (re.sub(r"[:#]", "_", check[0]), seed, k)) for k in (1, 2)]
            runs = [run_one(check, folder, project, extra_env, options.cov, seed, trace) for trace in traces]
            apart = parted(traces, [r[4] for r in runs], copies, commands_of(check, project)[1]) if check[1] != "script" else ("" if says(runs[0][4]) == says(runs[1][4]) else "printed differently")
            if not apart:
                for trace in traces:
                    for k in range(copies):
                        path = trace + ("" if copies == 1 else ".%d" % k)
                        if os.path.exists(path):
                            os.remove(path)
            return (check, seed) + runs[0] + (apart,)
        finally:
            with room:
                free[0] += copies
                room.notify_all()

    with concurrent.futures.ThreadPoolExecutor(free[0]) as pool:
        for future in concurrent.futures.as_completed([pool.submit(run, check, seed) for check in checks for seed in seeds]):
            check, seed, good, seconds, path, why, _, apart = future.result()
            name = check[0] + ("" if seeds == [1] else " seed %d" % seed)
            if seed == seeds[0]:
                times[check[0]] = round(seconds, 1)
            print("%-7s %-30s %5.1fs%s%s" % ("ok" if good else "FAILED", name, seconds, "" if good else "  see %s  (%s)" % (path, why), "  DIFFERENT: " + apart if apart else ""), flush=True)
            failed += 0 if good else 1
            if apart:
                different.append(name)
    try:
        json.dump(times, open(times_path, "w"))
    except OSError:
        pass
    print("%d failed, %d checks in %.0fs%s" % (failed, len(checks) * len(seeds), time.time() - started, ("  (not the same twice: %s)" % ", ".join(different)) if different else ""))
    if options.cov:
        coverage_run.report(project, folder)
    return failed + len(different)


if __name__ == "__main__":
    sys.exit(main())
