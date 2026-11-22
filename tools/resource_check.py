"""A static check: every file that a scene, theme or resource points at (an ext_resource), and the theme the project sets, is in the repository, and every
picture, sound or font among them has the .import file that the game needs to be built. A skin or a font left out of a commit works on the machine that has it
and breaks the build on every other. Reads the project's own files only, so it needs no engine and takes a second.

    python -I tools/resource_check.py        (prints PROBLEM lines; exit code 1 if there are any)
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POINTS = re.compile(r'\[ext_resource [^\]]*?path="res://([^"]+)"')
NEEDS_IMPORT = (".png", ".jpg", ".webp", ".svg", ".ogg", ".wav", ".mp3", ".ttf", ".otf")
SKIP = ("addons/", ".godot/", "art_source/")


def tracked():
    """The files git holds (so a file that exists only on this machine does not count), or None when this is not a repository."""
    done = subprocess.run(["git", "ls-files"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, cwd=ROOT)
    return set(done.stdout.decode("utf-8", "replace").splitlines()) if done.returncode == 0 else None


def main():
    held = tracked()
    exists = (lambda path: path in held) if held else (lambda path: os.path.exists(os.path.join(ROOT, path)))
    problems = []
    for folder, _, names in os.walk(ROOT):
        relative = os.path.relpath(folder, ROOT).replace(os.sep, "/")
        if relative == "." or any((relative + "/").startswith(s) for s in SKIP) or relative.startswith("."):
            if relative != ".":
                continue
        for name in names:
            if not name.endswith((".tres", ".tscn")):
                continue
            path = (relative + "/" + name).lstrip("./") if relative != "." else name
            text = open(os.path.join(folder, name), encoding="utf-8", errors="replace").read()
            for target in sorted(set(POINTS.findall(text))):
                if not exists(target):
                    problems.append("%s points at %s, which is not in the repository" % (path, target))
                elif target.endswith(NEEDS_IMPORT) and not exists(target + ".import"):
                    problems.append("%s points at %s, which has no .import file" % (path, target))
    theme = re.search(r'theme/custom="res://([^"]+)"', open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read())
    if theme and not exists(theme.group(1)):
        problems.append("project.godot sets the theme %s, which is not in the repository" % theme.group(1))
    for line in problems:
        print("PROBLEM " + line)
    print("%d problems" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
