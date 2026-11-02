"""Runs the game's quick checks side by side and prints one line for each: ok, or FAILED with where its output is.

    python tools/run_checks.py                 all the quick checks, a few at a time
    python tools/run_checks.py -j 3 stairs     only checks with "stairs" in the name, three at a time
    python tools/run_checks.py --cov           also measure line coverage (see tools/coverage_run.py)

The long ones (a whole match, two machines over a network, pictures that need a window) are not in it. Each check's output is kept in
the folder given by CHECK_OUT (default: a temp folder), as check_<name>.txt. Exit code is the number of checks that failed.
"""
import argparse
import concurrent.futures
import os
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
    ("test_nav", "script", "seeds=6"),
    ("test_stages", "script", "seeds=4"),
    ("test_liquid", "script", ""),
] + [(name, "scene", "") for name in (
    "flow_check", "tutorial_check", "menu_check", "stairs_check", "stairwell_check", "castle_spells_check", "castle_sinkhole_fall_check",
    "biome_jump_check", "sinkhole_check", "sinkhole_biomes_check", "ridge_check", "stalagmite_check", "parity_check", "interaction_check",
    "route_check", "ritual_check", "library_screen_check", "avalanche_check", "pieces_check",
)]

# Slower checks, or ones that need arguments: run with --all.
SLOW = [("net_check", "net", "host,client"), ("net_crowd_check", "net", "host,first,second"), ("net_hazard_check", "net", "host seed=1,client seed=1"),
        ("net_match_check", "net", "host,client"), ("test_world", "scene", "seeds=30"), ("showcase:checks", "scene", "scenario=checks"), ("showcase:newspells", "scene", "scenario=newspells"),
        ("showcase:spells", "scene", "scenario=spells"), ("showcase:soak", "scene", "scenario=soak")] + [(name, "scene", "") for name in (
    "collapse_check", "gate_check", "follow_check", "geyser_check", "wall_liquid_check", "eruption_check", "dark_check", "spectate_check",
    "pull_check", "spark_check", "sentinel_check", "liquid_world_check", "dig_out_check", "lab_sinkhole_check", "page_count_check",
    "portal_world_check", "spell_fixes_check", "spoils_check", "stage_jump_check", "intro_check", "eclipse_check", "minimap_check",
)]


NET_LOCK = threading.Lock()  # the copies of a network check all use one port, so only one such check runs at a time


def run_net(check, folder, project, extra_env, instrumented):
    """A check of two or more copies of the game talking over the network: each copy has a role, started a second after the last, in real time
    (a fixed frame rate would run it faster than the clock, and its waits would end before the others answered)."""
    name, kind, args = check
    started = time.time()
    with NET_LOCK:
        procs, logs = [], []
        for role in args.split(","):
            command = [GODOT, "--headless", "--path", ".", "tests/%s.tscn" % name, "--", "role=" + role.split(" ")[0]] + role.split(" ")[1:]
            env = dict(os.environ, **extra_env(name + "_" + role.split(" ")[0]))
            log = open(os.path.join(folder, "net_%s_%s.txt" % (name, role.split(" ")[0])), "wb")  # a file, not a pipe: nobody reads a pipe until the end, and a full one stops the copy
            procs.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=project, stdin=subprocess.DEVNULL))
            logs.append(log.name)
            time.sleep(6.0)  # the host must be listening before the next copy tries to join
        texts, codes = [], []
        for proc in procs:
            try:
                proc.wait(timeout=1200 if instrumented else 240)
                codes.append(proc.returncode)
            except subprocess.TimeoutExpired:
                proc.kill()
                codes.append(124)
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
        command += ["--path", project, "-s", "tests/%s.gd" % name]
    else:
        command += ["--fixed-fps", "60", "--path", project, "tests/%s.tscn" % name.split(":")[0]]
    if args:
        command += ["--"] + args.split()
    env = dict(os.environ, **extra_env(name.replace(":", "_")))  # (a colon cannot be in a file name)
    output_path = os.path.join(folder, "check_%s.txt" % name.replace(":", "_"))
    started = time.time()
    try:
        done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=1200 if instrumented else 300, env=env, cwd=project)
        text = done.stdout.decode("utf-8", "replace")
        code = done.returncode
    except subprocess.TimeoutExpired as late:
        text = (late.stdout or b"").decode("utf-8", "replace") + "\nFAILED: timed out"
        code = 124
    open(output_path, "w", encoding="utf-8").write(text)
    broken = text.count("SCRIPT ERROR") - text.count("Identifier not found: Sfx")  # a script run with -s has no autoloads: expected
    failed = code != 0 or ("FAILED" in text and kind == "script") or (broken > 0 and kind == "scene" and not instrumented)
    return name, not failed, time.time() - started, output_path, broken


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("only", nargs="*", help="run only the checks whose name contains one of these")
    parser.add_argument("-j", type=int, default=max(2, (os.cpu_count() or 4) - 1), help="how many to run at once")
    parser.add_argument("--all", action="store_true", help="the slower checks too")
    parser.add_argument("--cov", action="store_true", help="measure line coverage in a scratch copy of the project")
    options = parser.parse_args()
    folder = os.environ.get("CHECK_OUT") or os.path.join(tempfile.gettempdir(), "wizard_checks")
    os.makedirs(folder, exist_ok=True)
    checks = [c for c in CHECKS + (SLOW if options.all else []) if not options.only or any(word in c[0] for word in options.only)]
    project, extra_env = ROOT, (lambda name: {})
    if options.cov:
        import coverage_run
        project, extra_env = coverage_run.prepare(folder)
        checks = [c for c in checks if c[1] in ("scene", "net") and c[0] not in ("route_check", "test_world")]  # these two take too long counted line by line  # a script run with -s has no autoloads, so the counter cannot be there
    started = time.time()
    failed = 0
    with concurrent.futures.ThreadPoolExecutor(options.j) as pool:
        futures = [pool.submit(run_one, check, folder, project, extra_env, options.cov) for check in checks]
        for future in concurrent.futures.as_completed(futures):
            name, good, seconds, path, broken = future.result()
            note = "  (%d SCRIPT ERROR lines)" % broken if broken else ""
            print(("ok      %-30s %5.1fs%s" if good else "FAILED  %-30s %5.1fs%s  see " + path) % (name, seconds, note), flush=True)
            failed += 0 if good else 1
    print("%d failed, %d checks in %.0fs" % (failed, len(checks), time.time() - started))
    if options.cov:
        coverage_run.report(project, folder)
    return failed


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(main())
