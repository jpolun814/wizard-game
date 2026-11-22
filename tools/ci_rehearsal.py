"""Rehearses what GitHub's machines do on a push, on a fresh copy of the last commit, so a file that only this machine has (left out of a commit) or a step that
only works here shows up before the push and not after it:

    python tools/ci_rehearsal.py              clone HEAD, import it, parse every script, run the unit tests and static checks
    python tools/ci_rehearsal.py --keep       leave the copy where it is afterwards (its folder is printed)

It checks the committed state, not the working folder: commit first (changes not yet committed are not in the copy). The slow whole-world checks and the
pictures are not part of it (they need this machine's window and are run with tools/test.py). Exit code 0 when every step passed.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")


def run(step, command, cwd, env=None):
    print("== " + step, flush=True)
    done = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=cwd, env=env, stdin=subprocess.DEVNULL)
    return done.returncode, done.stdout.decode("utf-8", "replace")


def main():
    folder = tempfile.mkdtemp(prefix="ci_rehearsal_")
    copy = os.path.join(folder, "game")
    code, text = run("clone the last commit", ["git", "clone", "--quiet", "--local", ROOT, copy], folder)
    if code:
        print(text)
        return 1
    failed = []
    env = dict(os.environ, GODOT=GODOT)
    code, text = run("import the assets", [GODOT, "--headless", "--path", copy, "--import"], copy, env)
    code, text = run("parse every script", [GODOT, "--headless", "--path", copy, "--quit-after", "200"], copy, env)
    bad = [line for line in text.splitlines() if "SCRIPT ERROR" in line or "Parse Error" in line]
    if bad:
        failed.append("parse")
        print("\n".join(bad[:10]))
    code, text = run("unit tests and static checks", [sys.executable, "tools/test.py", "--unit"], copy, env)
    print(text.strip()[-1500:])
    if code:
        failed.append("tests")
    if "--keep" in sys.argv:
        print("the copy is in " + copy)
    else:
        shutil.rmtree(folder, ignore_errors=True)
    print("FAILED: " + ", ".join(failed) if failed else "the rehearsal passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
