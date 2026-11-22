"""The one command that tests the game.

    python tools/test.py                 unit tests, then the quick integration checks (the everyday run)
    python tools/test.py --unit          only the unit tests (gdUnit4, no world: a few seconds)
    python tools/test.py --changed       only what the files you changed can break (unit tests always run)
    python tools/test.py --full          everything, the slow checks (matches, network) included
    python tools/test.py --quarantined   also run the quarantined checks, to see whether they pass yet
    python tools/test.py --pictures      also compare the reference pictures (needs a window; see tools/look_compare.py)
    python tools/test.py pond sphere     only the checks with these words in the name (unit suites by file name)

What it does that the pieces alone do not:
  * runs the unit tests first, and stops there when they fail: a broken rule is not worth four minutes of worlds;
  * counts a SCRIPT ERROR or a crash in any output as a failure, whatever the check printed;
  * keeps a list of quarantined checks (tools/quarantine.json: name -> why). They still run and are shown, but they do not fail the run, and one
    that starts passing is reported so that it can be taken off the list. Nothing is quarantined without a reason written down;
  * ends with one summary: what failed, the error text, and where the full log is. Exit code is the number of real failures.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
QUARANTINE = os.path.join(ROOT, "tools", "quarantine.json")


def quarantined():
    try:
        return json.load(open(QUARANTINE, encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def unit_suites(words):
    """The unit-test files, narrowed by words in their names."""
    files = sorted(glob.glob(os.path.join(ROOT, "tests", "unit", "*_test.gd")))
    return [f for f in files if not words or any(w in os.path.basename(f) for w in words)]


def run_unit(files, folder):
    """Runs the gdUnit4 suites, a few processes at once. Returns (failures: [(suite, text)], tests, seconds)."""
    started = time.time()
    if not files:
        return [], 0, 0.0
    from concurrent.futures import ThreadPoolExecutor

    def one(path):
        name = os.path.basename(path)
        command = [GODOT, "--headless", "--path", ROOT, "-s", "-d", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--add", "res://tests/unit/" + name, "--ignoreHeadlessMode"]
        try:
            done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT, timeout=120, stdin=subprocess.DEVNULL)
        except subprocess.TimeoutExpired as late:  # (a suite that does not finish, most often one with a parse error that left the debugger waiting)
            text = ANSI.sub("", (late.stdout or b"").decode("utf-8", "replace")) + chr(10) + "SCRIPT ERROR: the suite did not finish in two minutes (a parse error in it waits in the debugger?)"
            open(os.path.join(folder, "unit_%s.txt" % name), "w", encoding="utf-8").write(text)
            return name, 124, text
        text = ANSI.sub("", done.stdout.decode("utf-8", "replace"))
        open(os.path.join(folder, "unit_%s.txt" % name), "w", encoding="utf-8").write(text)
        return name, done.returncode, text
    failures, tests = [], 0
    with ThreadPoolExecutor(max(1, min(4, len(files)))) as pool:
        for name, code, text in pool.map(one, files):
            m = re.search(r"Overall Summary:\s*(\d+) test cases \| (\d+) errors \| (\d+) failures", text)
            tests += int(m.group(1)) if m else 0
            bad = code != 0 or not m or int(m.group(2)) or int(m.group(3)) or "SCRIPT ERROR" in text or "Parse Error" in text
            if bad:
                detail = []
                lines = text.splitlines()
                for i, line in enumerate(lines):
                    if re.search(r"(test_\w+) FAILED", line):
                        detail.append(line.strip().split(" > ")[-1] + ": " + " ".join(l.strip() for l in lines[i + 1:i + 4] if l.strip() and "Report:" not in l)[:240])
                    elif "SCRIPT ERROR" in line or "Parse Error" in line:
                        detail.append(line.strip())
                failures.append((name, chr(10).join(detail[:6]) or text[-600:]))
    return failures, tests, time.time() - started


STATIC = ["audio_check.py", "rules_check.py", "resource_check.py", "shots_check.py"]  # scripts that read the project's files and need no engine: seconds, and they stop the run like a failed unit test


def run_static(words):
    """The static checks (tools/*_check.py), narrowed by words in their names. Returns the failures, as (name, what it printed)."""
    started = time.time()
    failures, ran = [], 0
    for name in STATIC:
        if not os.path.exists(os.path.join(ROOT, "tools", name)):
            continue
        if words and not any(w in name for w in words):
            continue
        ran += 1
        done = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", name)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT)
        text = done.stdout.decode("utf-8", "replace")
        if done.returncode:
            lines = [l for l in text.splitlines() if l.startswith("PROBLEM") or "Error" in l or "Traceback" in l]
            failures.append((name, chr(10).join(lines[:8]) or text[-500:]))
    return failures, ran, time.time() - started


def changed_words():
    """Words that name what the changed files are, so that the checks that mention them can be picked (a file pond.gd gives 'pond')."""
    out = subprocess.run(["git", "status", "--porcelain"], stdout=subprocess.PIPE, cwd=ROOT).stdout.decode("utf-8", "replace")
    words = set()
    for line in out.splitlines():
        path = line[3:].strip().strip('"')
        if path.endswith(".gd") and (path.startswith("scripts/") or path.startswith("tests/")):
            words.add(os.path.basename(path)[:-3].replace("_check", "").replace("_test", ""))
    return sorted(words)


def checks_for(words):
    """The integration checks whose script mentions one of the words (as a class or file name)."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import run_checks
    names = [c[0] for c in run_checks.CHECKS]
    picked = set()
    classes = {}
    for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        stem = os.path.basename(path)[:-3]
        if stem in words:
            m = re.search(r"^class_name (\w+)", open(path, encoding="utf-8", errors="replace").read(), re.M)
            classes[stem] = m.group(1) if m else stem
    for name in names:
        base = name.split("#")[0]
        path = run_checks.test_file(base, "gd")
        try:
            body = open(os.path.join(ROOT, path), encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if any(w in base for w in words) or any(re.search(r"\b%s\b" % re.escape(c), body) for c in classes.values()):
            picked.add(base)
    return sorted(picked)


def run_integration(words, full, folder, skip):
    command = [sys.executable, os.path.join(ROOT, "tools", "run_checks.py")] + (["--full"] if full else []) + (["--skip", ",".join(skip)] if skip else []) + words
    env = dict(os.environ, CHECK_OUT=folder)
    done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT, env=env)
    text = done.stdout.decode("utf-8", "replace")
    print(text)
    failed = re.findall(r"^FAILED\s+(\S+)\s+([\d.]+)s.*?see (\S+)", text, re.M)
    flaky = re.findall(r"FLAKY", text)
    times = re.findall(r"^(?:ok|FAILED)\s+(\S+)\s+([\d.]+)s", text, re.M)
    record_history(text)
    return failed, times, len(flaky)


def record_history(text):
    """Keeps what each check did in this run (ok, failed, or flaky: failed once and passed again) in reports/test_history.jsonl, one line a run,
    so that tools/flakes.py can say which checks do not give the same answer twice."""
    results = {}
    for m in re.finditer(r"^(ok|FAILED)\s+(\S+)\s+([\d.]+)s(.*)$", text, re.M):
        status = "flaky" if "FLAKY" in m.group(4) else ("ok" if m.group(1) == "ok" else "failed")
        results[m.group(2)] = {"status": status, "seconds": float(m.group(3))}
    if not results:
        return
    folder = os.path.join(ROOT, "reports")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "test_history.jsonl"), "a", encoding="utf-8") as out:
        out.write(json.dumps({"when": time.strftime("%Y-%m-%d %H:%M:%S"), "results": results}) + chr(10))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("only", nargs="*")
    parser.add_argument("--unit", action="store_true")
    parser.add_argument("--changed", action="store_true")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--quarantined", action="store_true", help="also run the quarantined checks (they are left out of the everyday run: they are known to fail)")
    parser.add_argument("--pictures", action="store_true")
    options = parser.parse_args()
    folder = os.environ.get("CHECK_OUT") or os.path.join(tempfile.gettempdir(), "wizard_checks")
    os.makedirs(folder, exist_ok=True)
    started = time.time()
    problems = []

    words = options.only
    if options.changed:
        changed = changed_words()
        words = checks_for(changed)
        print("changed: %s\n -> checks: %s\n" % (", ".join(changed) or "nothing", ", ".join(words) or "none (unit tests only)"))
    failures, tests, seconds = run_unit(unit_suites(options.only if not options.changed else []), folder)
    print("unit tests: %d tests, %d suites failed, %.1fs" % (tests, len(failures), seconds))
    for name, text in failures:
        print("  FAILED %s\n    %s" % (name, text.replace("\n", "\n    ")))
        problems.append(("unit " + name, text))
    static_failures, static_ran, static_seconds = run_static(options.only if not options.changed else [])
    print("static checks: %d run, %d failed, %.1fs" % (static_ran, len(static_failures), static_seconds))
    for name, text in static_failures:
        print("  FAILED %s\n    %s" % (name, text.replace("\n", "\n    ")))
        problems.append(("static " + name, text))
    if failures or static_failures:
        print("\nStopping: fix the rules before the worlds.")
        return len(failures) + len(static_failures)
    slow_times = []
    if not options.unit and not (options.changed and not words):
        failed, slow_times, flaky = run_integration(words, options.full, folder, [] if (options.full or options.quarantined) else list(quarantined()))
        held = quarantined()
        passing_again = []
        for name, _, path in failed:
            base = name.split("#")[0]
            if base in held:
                print("quarantined (not counted): %s: %s" % (base, held[base]))
            else:
                text = open(path, encoding="utf-8", errors="replace").read() if os.path.exists(path) else ""
                lines = [l for l in text.splitlines() if l.startswith("FAIL") or "SCRIPT ERROR" in l]
                problems.append((name, "\n".join(lines[:6]) + "\n(log: %s)" % path))
        ran = {t[0].split("#")[0] for t in slow_times}
        bad = {f[0].split("#")[0] for f in failed}
        passing_again = [b for b in held if b in ran and b not in bad]
        for b in passing_again:
            print("quarantined but PASSING: %s (take it off tools/quarantine.json)" % b)
        if flaky:
            print("%d check(s) were flaky this run: they failed once and passed on a second try" % flaky)
    if options.pictures:
        done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "look_compare.py")], cwd=ROOT)
        if done.returncode:
            problems.append(("pictures", "a reference picture differs (see reports/looks)"))
    print("\nslowest: " + ", ".join("%s %.0fs" % (n, float(s)) for n, s in sorted(slow_times, key=lambda t: -float(t[1]))[:6]))
    print("=" * 60)
    if problems:
        print("%d FAILED in %.0fs" % (len(problems), time.time() - started))
        for name, text in problems:
            print("- %s\n    %s" % (name, text.strip().replace("\n", "\n    ")[:700]))
    else:
        print("ALL GREEN in %.0fs" % (time.time() - started))
    return len(problems)


if __name__ == "__main__":
    sys.exit(main())
