"""Checks that nothing flies, falls or rolls at a wizard and hurts without being a shot.

    python tools/shots_check.py

The world's laws for shots (a wind slows them, a hole pulls them, a Barrier turns them) act on the group "shots", so a thing that moves and hurts but is not in it
slips past the law quietly: lava balls, hail, boulders and Flaming Spheres all did, and each was found by the owner, not a test. So:

* every script under scripts/ that moves a body and hurts someone is either a shot (it joins "shots", or extends something that does) or is named in EXEMPT below with
  the reason it is not one. A new moving, hurting script that is neither fails here, so that whoever wrote it has to decide.
* every shot answers what the laws ask of it: hinder, pull, reflect and heading (its own or inherited).
Exit code is the number of problems.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS = ["scripts/spells", "scripts/creatures", "scripts/scenery", "scripts/terrain", "scripts/wizard", "scripts/arena"]
LAWS = ["hinder", "pull", "reflect", "heading"]

# A script that moves and hurts, and is not a shot, with why. (A thing a person walks into, a cloud that hangs where it is, a ray that arrives at once, a creature.)
EXEMPT = {
    "scripts/creatures/mob.gd": "a creature: it walks, it is not thrown (wind slows it through apply_slow)",
    "scripts/spells/invincible_snail.gd": "a creature that crawls after its quarry, and is slowed by nothing by design",
    "scripts/wizard/wizard.gd": "the wizard itself",
}

MOVES = re.compile(r"\bmove_and_slide\(|\blinear_velocity\b|\bglobal_position\s*[+\-]?=\s*[^=]|\bposition\s*\+=|\bglobal_position\s*\+=|\bglobal_position\.[xy]\s*\+=|\bposition\.[xy]\s*\+=")
HURTS = re.compile(r"\.take_damage\(|SpellTargets\.hurt\w*\(|\bhurt\(")


def source(path):
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def class_info():
    """Every script: its path, class name, parent class name or path, and text."""
    found = {}
    for folder in FOLDERS:
        for path in glob.glob(os.path.join(ROOT, folder, "**", "*.gd"), recursive=True):
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            text = open(path, encoding="utf-8").read()
            name = re.search(r"^class_name (\w+)", text, re.M)
            parent = re.search(r"^extends (\S+)", text, re.M)
            found[rel] = {"name": name.group(1) if name else None, "parent": parent.group(1).strip('"') if parent else None, "text": text}
    return found


def lineage(rel, scripts, by_name):
    """The texts of a script and every script it extends."""
    texts = []
    seen = set()
    while rel and rel not in seen:
        seen.add(rel)
        info = scripts[rel]
        texts.append(info["text"])
        parent = info["parent"]
        rel = by_name.get(parent)
    return texts


def main():
    scripts = class_info()
    by_name = {info["name"]: rel for rel, info in scripts.items() if info["name"]}
    problems = []
    shots = []
    for rel, info in scripts.items():
        chain = lineage(rel, scripts, by_name)
        is_shot = any('add_to_group("shots")' in t for t in chain)
        if is_shot:
            shots.append(rel)
            for law in LAWS:
                if not any(re.search(r"^func %s\(" % law, t, re.M) for t in chain):
                    problems.append("PROBLEM %s is a shot but has no %s()" % (rel, law))
            continue
        if rel in EXEMPT:
            continue
        # A thing that moves a body and hurts someone, and says nothing about being a shot.
        if MOVES.search(info["text"]) and HURTS.search(info["text"]) and info["parent"] in ("Area2D", "CharacterBody2D", "RigidBody2D", "Node2D", "Projectile", "AnimatableBody2D"):
            if rel in ALLOWED_MOVERS:
                continue
            problems.append("PROBLEM %s moves and hurts but is not a shot: join the group \"shots\" (and answer %s), or say why not in ALLOWED_MOVERS / EXEMPT" % (rel, ", ".join(LAWS)))
    for rel in ALLOWED_MOVERS:
        if rel not in scripts:
            problems.append("PROBLEM ALLOWED_MOVERS names %s, which does not exist (remove it)" % rel)
    print("%d shots, %d scripts looked at, %d problems" % (len(shots), len(scripts), len(problems)))
    for line in problems:
        print(line)
    return len(problems)


# Scripts that move something and hurt, and are not shots, each with why. Each was read; a new one is a decision, so it is listed here by whoever adds it.
ALLOWED_MOVERS = {
    "scripts/spells/geyser.gd": "a jet of water that stands where it rose and throws what is on it: it does not travel",
    "scripts/spells/hemorrhage.gd": "a wound on a body, not a thing in flight",
    "scripts/spells/scythe.gd": "one swing of a blade at the caster's side: nothing travels",
    "scripts/spells/spell_effect.gd": "the base of the effects that last where they are cast; each effect that flies is its own script",
    "scripts/spells/tornado.gd": "a whirlwind that stands (it turns shots away itself); owner's call whether it should also be slowed by a Headwind",
    "scripts/scenery/sky_cloud.gd": "a cloud that drifts and stings what is in it: weather, not a shot",
    "scripts/terrain/gas_bank.gd": "a bank of gas that hangs where it is",
    "scripts/terrain/hazard.gd": "a place that hurts (spikes, pits): it does not move",
}

if __name__ == "__main__":
    sys.exit(main())
