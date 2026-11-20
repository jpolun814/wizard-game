"""Mutation testing: breaks the game's code one small way at a time and counts how many breakages the tests notice.

    python tools/mutate.py scripts/spells/elements.gd --count 30            break 30 places in that file, run the unit tests on each
    python tools/mutate.py scripts/spells/elements.gd --with laws_check     and also these integration checks (slower, catches more)
    python tools/mutate.py scripts/spells/substances.gd --seed 3 --list     only show the mutations that would be tried

A mutation is one change: a comparison turned round (> to <), a plus turned to a minus, true to false, a condition negated. If the tests still pass, the
mutant SURVIVED: the tests do not guard that line (or the line does nothing). Survivors are the list of what to write tests for next. A mutant that does not
parse is thrown away, not counted. The file is put back after every one, and the original is kept in <file>.mutbak while one is being tried (if the run is
killed, run it again: it restores the file first). Slow: every mutant is a test run. The score (killed / tried) is the number to watch, over time.
"""
import argparse
import os
import random
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (pattern, replacement): applied to one place on one line that is code (not a comment or a string).
OPERATORS = [
    (r"(?<![<>=!])>(?![=>])", "<"), (r"(?<![<>=!])<(?![=<])", ">"), (r">=", ">"), (r"<=", "<"), (r"==", "!="), (r"!=", "=="),
    (r" \+ ", " - "), (r" - ", " + "), (r" \* ", " / "), (r"\btrue\b", "false"), (r"\bfalse\b", "true"), (r"\band\b", "or"), (r"\bor\b", "and"),
    (r"\bnot ", ""), (r"\bcontinue\b", "pass"), (r"\bbreak\b", "pass"),
]
STRING = re.compile(r'"(?:\\.|[^"\\])*"')


def code_lines(text):
    """The lines worth changing: statements, not a declaration of a constant, a signal, a doc comment or a blank."""
    out = []
    for number, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", "const ", "signal ", "class_name", "extends", "@export", "func ", "static func ")):
            continue
        out.append(number)
    return out


def mutants(text, rng, count):
    lines = text.split("\n")
    found = []
    for number in code_lines(text):
        code = lines[number].split(" #")[0]  # (a trailing comment is not code)
        blanked = STRING.sub(lambda m: "\0" * len(m.group(0)), code)  # (same length, so a position in it is a position in the line; nothing inside a string matches)
        for pattern, replacement in OPERATORS:
            for m in re.finditer(pattern, blanked):
                found.append((number, pattern, replacement, m.start()))
    rng.shuffle(found)
    chosen, used = [], set()
    for item in found:
        if (item[0], item[3]) in used:
            continue
        used.add((item[0], item[3]))
        chosen.append(item)
        if len(chosen) >= count:
            break
    return sorted(chosen)


def apply(text, item):
    number, pattern, replacement, at = item
    lines = text.split("\n")
    code, sep, comment = lines[number].partition(" #")
    blanked = STRING.sub(lambda m: "\0" * len(m.group(0)), code)
    m = re.compile(pattern).match(blanked, at)
    if not m:
        return None
    lines[number] = code[:m.start()] + replacement + code[m.end():] + sep + comment
    return "\n".join(lines)


def run_tests(with_checks):
    started = time.time()
    try:
        done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "test.py"), "--unit"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT, timeout=300)
    except subprocess.TimeoutExpired:  # (a loop that no longer ends is a mutant the tests noticed: they never finished)
        return "killed", time.time() - started
    text = done.stdout.decode("utf-8", "replace")
    if "Parse Error" in text or "Parse error" in text:
        return "invalid", time.time() - started
    if done.returncode:
        return "killed", time.time() - started
    if with_checks:
        done = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "run_checks.py")] + with_checks, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=ROOT)
        text = done.stdout.decode("utf-8", "replace")
        if done.returncode:
            return "killed", time.time() - started
    return "survived", time.time() - started


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("file")
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--with", dest="with_checks", nargs="*", default=[], help="integration checks to run as well (words in their names)")
    parser.add_argument("--list", action="store_true")
    options = parser.parse_args()
    path = os.path.join(ROOT, options.file)
    backup = path + ".mutbak"
    if os.path.exists(backup):  # a run that was killed: put the file back first
        shutil.copyfile(backup, path)
        os.remove(backup)
        print("restored %s from an earlier run that did not finish" % options.file)
    original = open(path, encoding="utf-8", newline="").read()
    crlf = "\r\n" in original
    text = original.replace("\r\n", "\n")
    rng = random.Random(options.seed)
    picks = mutants(text, rng, options.count)
    print("%s: %d mutations to try" % (options.file, len(picks)))
    killed = survived = invalid = 0
    survivors = []
    try:
        for item in picks:
            changed = apply(text, item)
            if changed is None:
                continue
            line = text.split("\n")[item[0]].strip()
            label = "line %d: %s   [%s -> %s]" % (item[0] + 1, line[:90], item[1], item[2])
            if options.list:
                print("  " + label)
                continue
            shutil.copyfile(path, backup)
            open(path, "w", encoding="utf-8", newline="").write(changed.replace("\n", "\r\n") if crlf else changed)
            try:
                verdict, seconds = run_tests(options.with_checks)
            finally:
                shutil.copyfile(backup, path)
                os.remove(backup)
            print("  %-9s %5.0fs  %s" % (verdict.upper(), seconds, label), flush=True)
            if verdict == "killed":
                killed += 1
            elif verdict == "survived":
                survived += 1
                survivors.append(label)
            else:
                invalid += 1
    finally:
        if os.path.exists(backup):
            shutil.copyfile(backup, path)
            os.remove(backup)
    if options.list:
        return 0
    tried = killed + survived
    print("\n%s: %d killed, %d survived, %d did not parse%s" % (options.file, killed, survived, invalid, " (score %.0f%%)" % (100.0 * killed / tried) if tried else ""))
    for s in survivors:
        print("  SURVIVED " + s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
