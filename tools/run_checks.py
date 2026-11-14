"""Runs the game's quick checks side by side and prints one line for each: ok, or FAILED with where its output is.

    python tools/run_checks.py                 the quick set (aims at under a minute on six cores)
    python tools/run_checks.py --full          the quick set and the slow checks: whole matches, two or three copies talking over a network (aims at under five minutes)
    python tools/run_checks.py -j 3 stairs     only checks with "stairs" in the name, three at a time
    python tools/run_checks.py --cov           also measure line coverage (see tools/coverage_run.py)

(--all is the old name of --full.) Pictures that need a window are not in either. To be fast and steady it:
  * splits the long checks into shards that run side by side (a name ending #1, #2... is one shard of a check);
  * starts the longest first, by how long each took last time (kept in times.json beside the output);
  * gives every check of two or more copies a port of its own (WIZARD_PORT), so they run side by side instead of one after another;
  * runs a check that failed once more, and calls it flaky if that passes (it is still counted and listed at the end).
Each check's output is kept in the folder given by CHECK_OUT (default: a temp folder), as check_<name>.txt. Exit code is the number of checks that failed.
"""
import argparse
import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")

# (name, kind, arguments): "script" runs `-s tests/name.gd` and fails if it prints FAILED; "scene" runs the scene and fails on a bad exit code.
CHECKS = [
    ("test_gestures", "script", ""),
    ("test_pages", "script", ""),
    ("test_nav#1", "script", "seeds=2 first=0"),
    ("test_nav#2", "script", "seeds=2 first=2"),
    ("test_nav#3", "script", "seeds=2 first=4"),
    ("test_stages", "script", "seeds=4"),
    ("test_liquid", "script", ""),
] + [(name, "scene", "") for name in (
    "scripts_load_check", "flow_check", "tutorial_check", "tutorial_path_check", "menu_check", "settings_check", "lab_revive_check", "likeness_check", "stairs_check", "stairwell_check", "castle_spells_check", "castle_sinkhole_fall_check",
    "biome_jump_check", "page_underfoot_check", "earthquake_check", "stonefall_check", "sinkhole_check", "sinkhole_biomes_check", "ridge_check", "stalagmite_check", "parity_check", "interaction_check",
    "ritual_check", "library_screen_check", "avalanche_check", "pieces_check", "spellbook_order_check", "arrival_check", "sneak_check", "limits_check",
    "cluster_check", "brains_start_check", "blizzard_freeze_check", "blizzard_melt_check", "group_a_check", "group_d_check", "group_c_check", "group_b_check", "leech_check", "raise_dead_check", "mirage_check", "recorder_check", "log_upload_check", "solo_record_check", "sphere_check", "lab_sphere_check", "eye_check", "puppet_swing_check",
)] + [("route_check", "scene", "seed=7 moves=90")] + [("brain_spells_check#%d" % k, "scene", "shard=%d/4" % k) for k in range(4)]

# Slower checks, or ones that need arguments: run with --full. (route_check goes on to more moves than the quick set's.)
SLOW = [("tutorial_ai_check", "scene", "seconds=1100 speed=4"), ("route_check#a", "scene", "seed=7 moves=260"), ("debug_end_check#win", "scene", "mode=win"), ("debug_end_check#lose", "scene", "mode=lose"), ("route_check#b", "scene", "seed=3 moves=150"),
        ("net_check", "net", "host,client"), ("net_crowd_check", "net", "host,first,second"), ("net_hazard_check", "net", "host seed=2,client seed=2"),
        ("net_match_check", "net", "host,client"), ("dedicated_check", "net", "run"), ("net_spells_check", "net", "host,client"), ("test_world#1", "scene", "seeds=10 first=0"), ("test_world#2", "scene", "seeds=10 first=10"), ("test_world#3", "scene", "seeds=10 first=20"), ("showcase:checks", "scene", "scenario=checks"), ("showcase:newspells", "scene", "scenario=newspells"),
        ("showcase:spells", "scene", "scenario=spells"), ("showcase:soak", "scene", "scenario=soak")] + [(name, "scene", "") for name in (
    "collapse_check", "gate_check", "follow_check", "geyser_check", "wall_liquid_check", "eruption_check", "dark_check", "spectate_check", "stats_check",
    "pull_check", "spark_check", "canopy_check", "regen_check", "sentinel_check", "knight_check", "wild_shape_check", "liquid_world_check", "dig_out_check", "lab_sinkhole_check", "page_count_check",
    "portal_world_check", "ocean_world_check", "sky_world_check", "spell_fixes_check", "spoils_check", "stage_jump_check", "intro_check", "epilogue_check", "epilogue_jump_check", "eclipse_check", "minimap_check",
)]


def test_file(name, extension):
    """Where a check's file is: the checks, the looks (a scenario of the showcase) or the tools (a simulation) folder of tests/."""
    for folder in ("checks", "looks", "tools"):
        path = "tests/%s/%s.%s" % (folder, name, extension)
        if os.path.exists(path):
            return path
    return "tests/checks/%s.%s" % (name, extension)


NET_PORTS = {}  # each network check has a port of its own, so that they can run at the same time
NET_PORTS_LOCK = threading.Lock()


def port_for(name):
    with NET_PORTS_LOCK:
        return NET_PORTS.setdefault(name, 24600 + 10 * len(NET_PORTS))


def run_net(check, folder, project, extra_env, instrumented):
    """A check of two or more copies of the game talking over the network: each copy has a role, started a second after the last, in real time
    (a fixed frame rate would run it faster than the clock, and its waits would end before the others answered)."""
    name, kind, args = check
    started = time.time()
    procs, logs = [], []
    for role in args.split(","):
        command = [GODOT, "--headless", "--path", ".", test_file(name, "tscn"), "--", "role=" + role.split(" ")[0]] + role.split(" ")[1:]
        env = dict(os.environ, **extra_env(name + "_" + role.split(" ")[0]))
        env["WIZARD_PORT"] = str(port_for(name))
        log = open(os.path.join(folder, "net_%s_%s.txt" % (name, role.split(" ")[0])), "wb")  # a file, not a pipe: nobody reads a pipe until the end, and a full one stops the copy
        procs.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=project, stdin=subprocess.DEVNULL))
        logs.append(log.name)
        time.sleep(4.0)  # the host must be listening before the next copy tries to join
    texts, codes = [], []
    for proc in procs:
        try:
            proc.wait(timeout=1200 if instrumented else 300)
            codes.append(proc.returncode)
        except subprocess.TimeoutExpired:
            proc.kill()
            codes.append(124)
    for k, path in enumerate(logs):  # a copy that crashed while closing, after it had printed passes and no failure, did not fail
        body = open(path, "rb").read().decode("utf-8", "replace")
        if codes[k] not in (0, 1, 124) and ("PASS" in body or " ok " in body) and "FAIL" not in body and "gave up" not in body:
            codes[k] = 0
    for path, code in zip(logs, codes):
        texts.append(open(path, "rb").read().decode("utf-8", "replace") + (" FAILED: timed out" if code == 124 else ""))
    output_path = os.path.join(folder, "check_%s.txt" % name)
    text = ("=" * 20).join(texts)
    open(output_path, "w", encoding="utf-8").write(text)
    broken = text.count("SCRIPT ERROR")
    return name, all(c == 0 for c in codes) and (broken == 0 or instrumented), time.time() - started, output_path, broken


def run_one(check, folder, project, extra_env, instrumented):
    name, kind, args = check
    if kind == "net":
        return run_net(check, folder, project, extra_env, instrumented)
    command = [GODOT, "--headless"]
    if kind == "script":
        command += ["--path", project, "-s", test_file(name.split("#")[0], "gd")]
    else:
        command += ["--fixed-fps", "60", "--path", project, test_file(name.split(":")[0].split("#")[0], "tscn")]
    if args:
        command += ["--"] + args.split()
    env = dict(os.environ, **extra_env(name.replace(":", "_").replace("#", "_")))  # (a colon cannot be in a file name)
    output_path = os.path.join(folder, "check_%s.txt" % name.replace(":", "_").replace("#", "_"))
    started = time.time()
    for launch in range(3):  # Godot sometimes crashes in starting, before it has printed a line (more often with many starting at once): that is not the check's, so it is started again
        try:
            done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=1200 if instrumented else (240 if name.startswith("route_check") else 150), env=env, cwd=project,
                                  creationflags=0x4000 if sys.platform == "win32" else 0)  # below normal priority, so that the checks of two copies, which run in real time, are not starved by them
            text = done.stdout.decode("utf-8", "replace")
            code = done.returncode
        except subprocess.TimeoutExpired as late:
            text = (late.stdout or b"").decode("utf-8", "replace") + "\nFAILED: timed out"
            code = 124
        if code in (0, 1, 124) or len(text.strip().splitlines()) > 1:
            break
    open(output_path, "w", encoding="utf-8").write(text)
    broken = text.count("SCRIPT ERROR") - text.count("Identifier not found: Sfx")  # a script run with -s has no autoloads: expected
    # Godot now and then crashes while shutting down, after the check has printed all it has to say (more often with many copies at once).
    # Such an exit, with passes printed and no failure, is not the check's failure; it is noted in the output.
    lines = text.splitlines()
    crashed_at_exit = code not in (0, 1, 124) and any(l.startswith("PASS") for l in lines) and not any(l.startswith("FAIL") or "FAILED" in l for l in lines)
    if crashed_at_exit:
        code = 0
        open(output_path, "w", encoding="utf-8").write(text + "\n(run_checks: the game crashed while closing; the check had finished)\n")
    failed = code != 0 or ("FAILED" in text and kind == "script") or (broken > 0 and kind == "scene" and not instrumented)
    return name, not failed, time.time() - started, output_path, broken


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("only", nargs="*", help="run only the checks whose name contains one of these")
    parser.add_argument("-j", type=int, default=max(2, (os.cpu_count() or 4) + 1), help="how many to run at once")
    parser.add_argument("--full", "--all", dest="all", action="store_true", help="the slower checks too (the whole set aims at under five minutes)")
    parser.add_argument("--cov", action="store_true", help="measure line coverage in a scratch copy of the project")
    options = parser.parse_args()
    folder = os.environ.get("CHECK_OUT") or os.path.join(tempfile.gettempdir(), "wizard_checks")
    os.makedirs(folder, exist_ok=True)
    quick = [c for c in CHECKS if not (options.all and c[0] == "route_check")]  # the long route check replaces the short one
    checks = [c for c in quick + (SLOW if options.all else []) if not options.only or any(word in c[0] for word in options.only)]
    project, extra_env = ROOT, (lambda name: {})
    if options.cov:
        import coverage_run
        project, extra_env = coverage_run.prepare(folder)
        checks = [c for c in checks if c[1] in ("scene", "net") and c[0] not in ("route_check", "test_world")]  # these two take too long counted line by line  # a script run with -s has no autoloads, so the counter cannot be there
    times_path = os.path.join(folder, "times.json")
    try:
        times = json.load(open(times_path))
    except (OSError, ValueError):
        times = {}
    checks.sort(key=lambda c: -times.get(c[0], 20.0 if c[1] == "net" else 5.0))  # the longest first, so the short ones fill the gaps after
    started = time.time()
    failed = 0
    flaky = []

    def run_steady(check):
        result = run_one(check, folder, project, extra_env, options.cov)
        if result[1] or options.cov:
            return result + (False,)
        try:
            shutil.copyfile(result[3], result[3].replace(".txt", "_first_try.txt"))  # what the first try said, which the second overwrites
        except OSError:
            pass
        again = run_one(check, folder, project, extra_env, options.cov)  # once more
        return (again[0], again[1], result[2] + again[2], result[3] if not again[1] else again[3], again[4], again[1])
    # The checks of two or three copies of the game run in real time: when the others take the cores, the game time of a copy falls behind
    # the clock and the other copy gives up waiting. So they go first, all together, with nothing else running, and the rest after them.
    nets = [c for c in checks if c[1] == "net"]
    rest = [c for c in checks if c[1] != "net"]

    def report(futures):
        nonlocal failed
        for future in concurrent.futures.as_completed(futures):
            name, good, seconds, path, broken, was_flaky = future.result()
            times[name] = round(seconds, 1)
            if was_flaky:
                flaky.append(name)
            note = "  (%d SCRIPT ERROR lines)" % broken if broken else ""
            note += "  FLAKY: failed once, passed on a second try" if was_flaky else ""
            print(("ok      %-30s %5.1fs%s" if good else "FAILED  %-30s %5.1fs%s  see " + path) % (name, seconds, note), flush=True)
            failed += 0 if good else 1
    with concurrent.futures.ThreadPoolExecutor(max(1, len(nets))) as net_pool:
        report([net_pool.submit(run_steady, check) for check in nets])
    with concurrent.futures.ThreadPoolExecutor(options.j) as pool:
        report([pool.submit(run_steady, check) for check in rest])
    try:
        json.dump(times, open(times_path, "w"))
    except OSError:
        pass
    print("%d failed, %d checks in %.0fs%s" % (failed, len(checks), time.time() - started, ("  (flaky: %s)" % ", ".join(flaky)) if flaky else ""))
    if options.cov:
        coverage_run.report(project, folder)
    return failed


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main())
