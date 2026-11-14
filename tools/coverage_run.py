"""Line coverage for the checks, using gd-tools (https://pypi.org/project/gd-tools-cli/), which does the counting. This file only sets it up.

    python tools/run_checks.py --all --cov

Setup, once (gd-tools needs Python 3.10 or newer):
    py -3.11 -m venv C:/Users/<you>/gd_tools_venv && C:/Users/<you>/gd_tools_venv/Scripts/pip install gd-tools-cli
    set GD_TOOLS=C:/Users/<you>/gd_tools_venv/Scripts/gd-tools.exe     (or keep it at the default path below)

The game is copied to a scratch folder and its scripts are measured there; the game's own files are not touched. Two things to know:
  - A check run with `-s` has no autoloads, so cannot be measured: only the scene checks count.
  - gd-tools cannot read a few scripts (it names them when it runs), so those are left out of the figure. Treat the total as a guide.
"""
import glob
import json
import os
import re
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GD_TOOLS = os.environ.get("GD_TOOLS", os.path.expanduser("~/AppData/Local/Temp/gdt_venv/Scripts/gd-tools.exe"))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")


def _tool(project, *args):
    env = dict(os.environ, GODOT_BIN=GODOT)
    return subprocess.run([GD_TOOLS, *args], cwd=project, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900).stdout.decode("utf-8", "replace")


def prepare(folder):
    """Copies the game to a scratch folder, sets gd-tools up in it, and returns (the folder, a function giving each check's environment)."""
    project = os.path.join(folder, "coverage_copy")
    if os.path.exists(project):
        shutil.rmtree(project)
    shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", "aseprite", "art_source", "*.zip", "__pycache__"))
    _tool(project, "init", "--non-interactive")
    text = open(os.path.join(project, "project.godot"), encoding="utf-8").read()
    text = text.replace('WandCursor="*res://scripts/ui/wand_cursor.gd"', 'WandCursor="*res://scripts/ui/wand_cursor.gd"\n_GDTCoverage="*res://addons/gd-tools-coverage/coverage.gd"', 1)
    text = text.replace("[debug]\n", "[debug]\n\ngdscript/warnings/inference_on_variant=0\n", 1)  # its counters would otherwise be refused by the game's strict warnings
    open(os.path.join(project, "project.godot"), "w", encoding="utf-8").write(text)
    config = os.path.join(project, "gd-tools.toml")
    text = open(config, encoding="utf-8").read()
    head, tail = text.split("[coverage]", 1)
    tail = tail.replace("exclude = [\n", 'exclude = [\n    "scripts/world/world_builder.gd",\n    "tests",\n', 1)  # one script its parser cannot read
    open(config, "w", encoding="utf-8").write(head + "[coverage]" + tail)
    _tool(project, "coverage", "run", "--scene", "res://tests/checks/menu_check.tscn", "--timeout", "5")  # makes the plan of what to count, then stops
    os.makedirs(os.path.join(project, "cov"), exist_ok=True)
    plan = os.path.join(project, ".gd-tools", "coverage", "plan.json")

    def environment(name):
        return {"GD_TOOLS_COVERAGE_PLAYTEST": "1", "GD_TOOLS_COVERAGE_PLAN": plan, "GD_TOOLS_COVERAGE_OUTPUT": os.path.join(project, "cov", name + ".json")}

    return project, environment


def report(project, folder):
    files = glob.glob(os.path.join(project, "cov", "*.json"))
    merged = os.path.join(project, ".gd-tools", "coverage", "coverage.json")
    _tool(project, "coverage", "merge", *files, "--output", merged)
    _tool(project, "coverage", "report", "--report-format", "text")
    skipped = _skipped(project)
    rows = []
    for line in open(os.path.join(project, ".gd-tools", "coverage", "coverage_report.txt"), encoding="utf-8"):
        line = re.sub(r"\[[0-9;]*m", "", line)
        found = re.match(r"\|\s*res://(\S+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|", line)
        if found and "res://" + found.group(1) not in skipped:
            rows.append((found.group(1), int(found.group(2)), int(found.group(3))))
    lines = sum(r[1] for r in rows)
    hit = sum(r[2] for r in rows)
    print("\nleast covered (of %d scripts it could measure):" % len(rows))
    for name, count, ran in sorted(rows, key=lambda r: r[2] / max(r[1], 1))[:30]:
        print("  %5.1f%%  %4d/%-4d  %s" % (100.0 * ran / max(count, 1), ran, count, name))
    print("\nLINE COVERAGE %.1f%%  (%d of %d statements, in %d scripts; %d scripts gd-tools cannot read are not counted)" % (100.0 * hit / max(lines, 1), hit, lines, len(rows), len(skipped)))


def _skipped(project):
    """The scripts gd-tools could not put its counters in, found by starting the game once with it on."""
    env = dict(os.environ, GODOT_BIN=GODOT, GD_TOOLS_COVERAGE_PLAYTEST="1", GD_TOOLS_COVERAGE_OUTPUT=os.path.join(project, "cov", "_probe.json"),
               GD_TOOLS_COVERAGE_PLAN=os.path.join(project, ".gd-tools", "coverage", "plan.json"))
    text = subprocess.run([GODOT, "--headless", "--path", project, "--quit-after", "30"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300).stdout.decode("utf-8", "replace")
    os.remove(os.path.join(project, "cov", "_probe.json")) if os.path.exists(os.path.join(project, "cov", "_probe.json")) else None
    return set(re.findall(r"script did not reload: (res://\S+\.gd)", text))
