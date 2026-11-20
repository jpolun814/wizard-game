"""Cuts owned sounds (data/sounds.json, a spell's `sounds`) from the packs, one file per owner and event, brought to the level of the sound it replaces.

    python tools/make_pack_sounds.py <NOX folder> <OpenGameArt packs folder> <400 Sounds Pack folder>

Each line of CUTS is: owner, event, which pack, the recording, where to start, how long, fade in, fade out. A recording is trimmed, faded and
set to one loudness; the sound it replaces is removed, and its level in data/sound_levels.json is set so the new one sounds as loud as the old did
(only run it once per change: a second run would match the new sound against itself). Nothing is mixed: each file is one recording.
Sources: NOX SOUND's Essentials Series (CC0), the CC0 packs of OpenGameArt (rubberduck's breaking sounds), and the 400 Sounds Pack (the owner approved
its use, 2026-11-20). Needs numpy and soundfile.
"""
import glob
import json
import os
import re
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FIRE = "Ambiance_Fire_Big_Loop_Mono"
DRONE = "Atmosphere_Drone_Hum_Eerie_Loop_Stereo"
CAVE = "Ambiance_Cave_Dark_Loop_Stereo"
WIND = "Ambiance_Wind_Calm_Loop_Stereo"
CUTS = [  # owner, event, pack, recording, start, seconds, fade in, fade out
    # fire: the crackle of a big fire, a different stretch for each
    ("Firewall", "fire", "nox", FIRE, 0.5, 1.2, 0.05, 0.4), ("Flaming Sphere", "fire", "nox", FIRE, 2.0, 1.0, 0.05, 0.4),
    ("Bramble", "fire", "nox", FIRE, 3.2, 0.9, 0.05, 0.3), ("Liana", "fire", "nox", FIRE, 4.3, 0.9, 0.05, 0.3),
    ("Lily Pads", "fire", "nox", FIRE, 5.4, 0.8, 0.05, 0.3), ("Great Oak", "fire", "nox", FIRE, 1.0, 1.4, 0.1, 0.5),
    ("Flytrap", "fire", "nox", FIRE, 6.4, 0.8, 0.05, 0.3), ("Supernova", "fire", "nox", FIRE, 0.0, 1.8, 0.05, 0.6),
    ("Oil Slick", "fire", "nox", FIRE, 7.4, 1.0, 0.05, 0.4), ("lava_ball", "fire", "nox", FIRE, 2.8, 0.7, 0.03, 0.3),
    ("gas_bank", "fire", "nox", FIRE, 4.0, 0.8, 0.05, 0.3), ("coating", "fire", "nox", FIRE, 5.0, 0.6, 0.03, 0.3),
    ("Flare", "fire", "p400", "Other/light_match", 0.0, 1.28, 0.0, 0.2),
    # the dark of the Shadow school, and the portals: an eerie drone and a dark cave
    ("Black Hole", "dark_whoosh", "nox", DRONE, 2.0, 2.2, 0.5, 0.9), ("Hex", "dark_whoosh", "nox", CAVE, 3.0, 1.2, 0.2, 0.5),
    ("Eclipse", "dark_whoosh", "nox", DRONE, 6.0, 2.6, 1.0, 1.0), ("Silence", "dark_whoosh", "nox", CAVE, 8.0, 1.0, 0.3, 0.5),
    ("Decoy", "dark_whoosh", "nox", DRONE, 12.0, 0.9, 0.1, 0.4), ("Moonbeam", "dark_whoosh", "nox", DRONE, 15.0, 1.5, 0.4, 0.6),
    ("Vacuum", "dark_whoosh", "nox", CAVE, 12.0, 1.4, 0.3, 0.6), ("Shadow Step", "dark_whoosh", "nox", CAVE, 16.0, 0.5, 0.02, 0.2),
    ("intro", "dark_whoosh", "nox", DRONE, 20.0, 2.0, 0.4, 0.8), ("rituals", "dark_whoosh", "nox", CAVE, 20.0, 1.2, 0.2, 0.5),
    ("arrival_portal", "portal_open", "nox", DRONE, 25.0, 2.0, 0.6, 0.6), ("field_portal", "portal_open", "nox", DRONE, 30.0, 2.0, 0.6, 0.6),
    ("portal_collapse", "portal_open", "nox", DRONE, 35.0, 2.0, 0.6, 0.6),
    # air: wind, and the pack's whooshes and swipe
    ("Gust", "whoosh", "nox", WIND, 4.0, 1.4, 0.15, 0.6), ("Featherfall", "whoosh", "nox", WIND, 10.0, 1.6, 0.4, 0.7),
    ("Barbs", "whoosh", "p400", "Other/whoosh_2", 0.0, 0.77, 0.0, 0.1), ("Barbs", "turned", "p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05),
    ("Ignite", "turned", "p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05), ("Frostbolt", "turned", "p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05),
    ("Pebble", "turned", "p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05), ("Pebble", "whoosh", "p400", "Other/whoosh_2", 0.0, 0.77, 0.0, 0.1),
    ("Thorn Whip", "whoosh", "p400", "Combat and Gore/swipe", 0.0, 0.39, 0.0, 0.05), ("enemy_bolt", "whoosh", "p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05),
    ("lava_ball", "whoosh", "p400", "Other/whoosh_2", 0.0, 0.77, 0.0, 0.1), ("intro", "whoosh", "p400", "Other/whoosh_2", 0.0, 0.77, 0.0, 0.1),
    ("Scythe", "swing", "p400", "Weapons/sword_slice", 0.0, 0.77, 0.0, 0.1),
    # stone, ice, rain, insects
    ("Stone Wall", "rocks", "p400", "Materials/stone_push_long", 0.0, 2.48, 0.05, 0.4),
    ("Ice Prison", "shatter", "oga", "bfh1_glass_breaking_01", 0.0, 3.0, 0.0, 0.3), ("ice_block", "shatter", "oga", "bfh1_glass_breaking_02", 0.0, 3.0, 0.0, 0.3),
    ("ice_plug", "shatter", "oga", "bfh1_glass_breaking_03", 0.0, 3.0, 0.0, 0.3),
    ("Hailstorm", "shatter", "nox", "Ambiance_Rain_Strong_Loop_Stereo", 4.0, 0.9, 0.05, 0.4),
    ("Insect Plague", "summon", "nox", "Ambiance_Night_Loop_Stereo", 5.0, 1.5, 0.2, 0.5),
]
MOB_WHOOSH = ("p400", "Other/whoosh_1", 0.0, 0.33, 0.0, 0.05)  # every kind of creature's blow


def slug(owner):
    return re.sub(r"[^a-z0-9]+", "_", owner.lower()).strip("_")


def find(packs, pack, name):
    if pack == "p400":
        return os.path.join(packs["p400"], name + ".wav")
    hits = glob.glob(os.path.join(packs[pack], "**", name + ".*"), recursive=True)
    return [h for h in hits if h.endswith((".wav", ".ogg"))][0]


def rms_db(x):
    v = x[np.abs(x) > 0.1 * max(np.abs(x).max(), 1e-9)]
    return 20 * np.log10(float(np.sqrt(np.mean(v ** 2))) + 1e-9) if len(v) else -90.0


def existing(name):
    files = [f for f in glob.glob(os.path.join(ROOT, "audio", name + ".*")) + glob.glob(os.path.join(ROOT, "audio", name + "_[0-9]*.*"))]
    return [f for f in files if not f.endswith(".import") and re.fullmatch(r"(_\d+)?", os.path.splitext(os.path.basename(f))[0][len(name):])]


def main(nox, oga, p400):
    packs = {"nox": nox, "oga": oga, "p400": p400}
    levels = json.load(open(os.path.join(ROOT, "data/sound_levels.json")))
    registry = json.load(open(os.path.join(ROOT, "data/sounds.json")))
    cuts = list(CUTS)
    for owner in [o for o in registry if o.startswith("mob_")]:
        cuts.append((owner, "whoosh") + MOB_WHOOSH)
    for owner, event, pack, rec, start, secs, fin, fout in cuts:
        name = "%s__%s" % (slug(owner), event)
        old = existing(name)
        old_db = 0.0
        if old:
            x, _ = sf.read(old[0], always_2d=True)
            old_db = rms_db(x.mean(axis=1)) + levels.get(name, 0.0)
        x, rate = sf.read(find(packs, pack, rec), always_2d=True)
        x = x.mean(axis=1)[int(start * rate):int((start + secs) * rate)].copy()
        a, b = min(len(x), int(fin * rate)), min(len(x), int(fout * rate))
        if a:
            x[:a] *= np.linspace(0, 1, a)
        if b:
            x[-b:] *= np.linspace(1, 0, b)
        x *= 0.7 / max(float(np.abs(x).max()), 1e-9)
        for f in old:
            os.remove(f)
            if os.path.exists(f + ".import"):
                os.remove(f + ".import")
        sf.write(os.path.join(ROOT, "audio", name + ".wav"), x, rate, subtype="PCM_16")
        levels[name] = round((old_db - rms_db(x)) * 2) / 2 if old else 0.0
        print("%-28s %-12s %s  level %+.1f" % (owner, event, rec, levels[name]))
    json.dump(dict(sorted(levels.items())), open(os.path.join(ROOT, "data/sound_levels.json"), "w"), indent=1)


main(*sys.argv[1:4])
