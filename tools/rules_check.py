"""The project's own rules (CLAUDE.md), checked by reading the code. No engine; a second.

    python tools/rules_check.py

* a spell that joins the "danger" group answers danger_at (the AI asks every member);
* nothing loads a resource inside _draw (it is freed before it renders: a white rectangle);
* every "res://" path written in a script names a file that exists;
* no spell effect branches on a spell's name, and the laws (Elements, Damage, Substances) name no spell, school or spell class: they act on what a thing IS;
* code and its comments are spelled the American way, outside quoted strings (a saved-data key keeps its old spelling);
* every Sfx.cue("owner", "event") written out in full is registered (data/sounds.json or the spell's own list): an unregistered one plays nothing;
* nothing that differs from run to run decides what the game or a check does: no dice nobody can set, no real clock, no other core (see CLOCKS and THREADS);
* every Sfx.cue owner of a spell is a spell that has sounds.
Exit code is 1 if anything is wrong.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
BRITISH = re.compile(r"\b(colour\w*|favourite\w*|grey\w*|centre\w*|armour\w*|honour\w*|behaviour\w*|neighbour\w*|metre|defence|travelled|cancelled|ageing)\b", re.I)
LAWS = ["scripts/spells/elements.gd", "scripts/spells/damage.gd", "scripts/spells/substances.gd"]
SPELL_WORDS = r"\b(Ignite|Frostbolt|Geyser|Firewall|Barrier|Tornado|Blizzard|Water Jet|Gust|Push|Fireball|Projectile)\b"

# The scripts that read the real clock, and why what they do with it cannot change how the game goes.
CLOCKS = {"scripts/core/library.gd": "how often a person's record is saved", "scripts/gesture/caster.gd": "how a finished stroke fades", "scripts/spells/updraft.gd": "the streaks of the wind",
          "scripts/ui/hud_bar.gd": "the bar shakes", "scripts/wizard/barrier_bubble.gd": "the bubble turns", "scripts/wizard/body_flames.gd": "the flames flicker",
          "scripts/wizard/part_frames.gd": "how long a picture took to make, which is only reported"}
# The scripts that do something on another core, and why it comes out the same whenever that ends.
THREADS = {"scripts/core/net.gd": "finding the router, only on a server asked to", "scripts/core/warmup.gd": "loading ahead, which a test does not do",
           "scripts/terrain/liquid_grid.gd": "its answer is always waited for on the next step"}


def strip_strings(line):
    """A line without its quoted strings (and without a trailing # comment's code), so that saved-data keys are not read as code."""
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', line)


def main():
    problems = []
    sources = {p.replace("\\", "/"): open(p, encoding="utf-8", errors="replace").read() for p in glob.glob("scripts/**/*.gd", recursive=True)}
    for path, text in sorted(sources.items()):
        if 'add_to_group("danger")' in text and "func danger_at" not in text:
            problems.append("%s joins the danger group but has no danger_at" % path)
        for m in re.finditer(r"^func _draw\w*\(.*?\n(?=^func |\Z)", text, re.M | re.S):
            if re.search(r"(?<!pre)\bload\(", m.group(0)):
                problems.append("%s loads a resource inside %s" % (path, m.group(0).split("(")[0].replace("func ", "")))
        for m in re.finditer(r'"(res://[^"%*{}\s]+)"', text):
            target = m.group(1)[6:]
            if target and not target.endswith("/") and not os.path.exists(target):
                problems.append("%s names %s, which does not exist" % (path, m.group(1)))
        if path.startswith("scripts/spells/") and path not in LAWS:
            for m in re.finditer(r'\b(spell_name|spell)\s*==\s*"', text):
                problems.append("%s branches on a spell's name (one script per effect: %s)" % (path, text[m.start():m.start() + 40].replace("\n", " ")))
        for number, line in enumerate(text.splitlines(), 1):
            plain = strip_strings(line)
            hit = BRITISH.search(plain)
            if hit:
                problems.append("%s:%d is spelled the British way: '%s'" % (path, number, hit.group(1)))
    for path in LAWS:
        text = sources.get(path, "")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("##")[0].split(" # ")[0]
            if re.search(r"\bschool\s*==", code) or re.search(r'"%s"' % SPELL_WORDS, code) or re.search(r"\bis (Fireball|Frostbolt|Geyser|Ignite|Firewall|Barrier|Tornado|Blizzard)\b", code):
                problems.append("%s:%d: a law names a spell or a school: %s" % (path, number, line.strip()[:90]))
    # A test must come out the same every time (docs/handoff/07_testing.md): nothing that differs from run to run may decide what the game or a check does.
    for path, text in sorted(sources.items()):
        for number, line in enumerate(text.splitlines(), 1):
            code = strip_strings(line).split("#")[0]
            if re.search(r"\brandomize\(\)", code) and path.replace("\\", "/") != "scripts/core/dice.gd":
                problems.append("%s:%d randomizes its dice: everything left to chance comes from the world's seed (see Dice)" % (path, number))
            if "seed" in code and re.search(r"get_instance_id|get_ticks|get_unix", code):
                problems.append("%s:%d seeds dice with what differs on every run and machine" % (path, number))
            if re.search(r"Time\.get_ticks_\w+\(\)", code) and path not in CLOCKS:
                problems.append("%s:%d reads the real clock, which goes on while the game is paused and is not the game's: add up delta (or name the script in CLOCKS, with why)" % (path, number))
            if re.search(r"\b(Thread\.new|WorkerThreadPool\.|load_threaded_request)", code) and path not in THREADS:
                problems.append("%s:%d does something on another core: say in THREADS why what it does cannot change how a test comes out" % (path, number))
    for path in sorted(glob.glob("tests/checks/*.gd") + glob.glob("tests/support/*.gd")):
        text = open(path, encoding="utf-8", errors="replace").read()
        for number, line in enumerate(text.splitlines(), 1):
            code = strip_strings(line).split("#")[0]
            if re.search(r"OS\.(delay|create_process)|Time\.get_(unix|ticks)", code):
                problems.append("%s:%d waits for or measures the real clock: wait for the thing itself, in frames" % (path.replace(os.sep, "/"), number))
    registry = json.load(open("data/sounds.json"))
    spell_sounds = {}
    for f in glob.glob("data/spells/*.tres"):
        text = open(f, encoding="utf-8").read()
        name = re.search(r'spell_name = "([^"]+)"', text)
        found = re.search(r"^sounds = (\{.*\})$", text, re.M)
        if name and found:
            spell_sounds[name.group(1)] = json.loads(found.group(1))
    cues = 0
    for path, text in sorted(sources.items()):
        for m in re.finditer(r'Sfx\.cue\(\s*"([^"]+)"\s*,\s*"([^"]+)"', text):
            cues += 1
            owner, event = m.groups()
            if not ((owner in registry and event in registry[owner]) or (owner in spell_sounds and event in spell_sounds[owner])):
                problems.append("%s asks Sfx.cue(\"%s\", \"%s\"), which nothing registers: it plays nothing" % (path, owner, event))
    print("%d scripts, %d written-out sound cues" % (len(sources), cues))
    for p in problems:
        print("PROBLEM  " + p)
    print("%d problems" % len(problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
