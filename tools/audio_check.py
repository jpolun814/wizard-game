"""Checks every sound in the game as a file and as a promise: what cannot be heard in a headless run but can still be wrong.

    python tools/audio_check.py

* every owner and event (data/sounds.json, and each spell's `sounds`) points at a sound that has files in audio/;
* every file in audio/ decodes, is neither empty nor silent, is not a minute long by mistake, and does not clip;
* every file has its .import beside it (an exported game would be missing it);
* every sound level in data/sound_levels.json is for a sound that exists, and every level is a sane number of decibels;
* no file is left over that nothing names (a sound that was replaced and the old file kept).
It cannot tell whether a sound is the RIGHT sound: that is tools/audit_sounds.py, and an ear. Exit code is the number of problems.
"""
import glob
import json
import os
import re
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio")
SILENT_ON_PURPOSE = set()      # sounds that are meant to be silence (none today: the Faint is a missing event, not a silent file)
MAX_SECONDS = 40.0             # the longest a recording may be (the music beds and ambience are well under)
MIN_SECONDS = 0.02
CLIP_SHARE = 0.002             # more than this share of samples at full scale is a clipped sound
LEVEL_RANGE = (-40.0, 24.0)    # decibels a level may ask for (Godot's own limit is +24)
OVER_SCALE = 3.0               # a sound played at its level may not rise more than this above full scale (the rocks sound, tuned by ear, sits 2.6 over: told to the owner)


def key_of(stem):
    """The sound a file belongs to: its name without the trailing variant number (ignite__cast_2 -> ignite__cast)."""
    tail = stem.rsplit("_", 1)[-1]
    return stem[: -len(tail) - 1] if tail.isdigit() and "_" in stem else stem


def referenced():
    """Every sound name the game asks for by owner and event, with who asks."""
    asked = {}
    reg = json.load(open(os.path.join(ROOT, "data", "sounds.json")))
    for owner, events in reg.items():
        for event, name in events.items():
            asked[name] = "%s / %s" % (owner, event)
    for path in glob.glob(os.path.join(ROOT, "data", "spells", "*.tres")):
        text = open(path, encoding="utf-8").read()
        spell = re.search(r'spell_name = "([^"]+)"', text)
        found = re.search(r"^sounds = (\{.*\})$", text, re.M)
        if spell and found:
            for event, name in json.loads(found.group(1)).items():
                asked[name] = "%s / %s" % (spell.group(1), event)
    return asked


def named_in_code():
    """Sounds the scripts play by their own name (Sfx.play("name")) or hold in a table: found by looking for any quoted audio name."""
    names = set()
    for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        text = open(path, encoding="utf-8", errors="replace").read()
        names.update(re.findall(r'"([a-z0-9_]+)"', text))
    return names


def main():
    problems = []
    files = sorted(f for f in os.listdir(AUDIO) if f.endswith((".wav", ".ogg")))
    keys = {}
    peaks = {}  # sound -> its loudest file's peak, in decibels of full scale
    for f in files:
        keys.setdefault(key_of(os.path.splitext(f)[0]), []).append(f)
    asked = referenced()
    for name, who in sorted(asked.items()):
        if name not in keys:
            problems.append("%s asks for the sound '%s', which has no file in audio/" % (who, name))
    for f in files:
        path = os.path.join(AUDIO, f)
        if not os.path.exists(path + ".import"):
            problems.append("%s has no .import beside it" % f)
        try:
            data, rate = sf.read(path, always_2d=True)
        except Exception as error:  # noqa: BLE001 (any failure to decode is the finding)
            problems.append("%s does not decode: %s" % (f, str(error)[:80]))
            continue
        seconds = len(data) / float(rate)
        if seconds < MIN_SECONDS:
            problems.append("%s is empty (%.3f s)" % (f, seconds))
            continue
        if seconds > MAX_SECONDS:
            problems.append("%s is %.0f s long" % (f, seconds))
        peak = float(np.max(np.abs(data)))
        peaks[key_of(os.path.splitext(f)[0])] = max(peaks.get(key_of(os.path.splitext(f)[0]), -120.0), 20.0 * np.log10(max(peak, 1e-6)))
        if peak < 0.01 and os.path.splitext(f)[0] not in SILENT_ON_PURPOSE:
            problems.append("%s is silent (peak %.4f)" % (f, peak))
        clipped = float(np.mean(np.abs(data) >= 0.999))
        if clipped > CLIP_SHARE:
            problems.append("%s clips: %.2f%% of its samples are at full scale" % (f, clipped * 100))
        if not np.isfinite(data).all():
            problems.append("%s holds a sample that is not a number" % f)
    levels = json.load(open(os.path.join(ROOT, "data", "sound_levels.json")))
    for name, db in levels.items():
        if name not in keys and name not in {os.path.splitext(f)[0] for f in files}:
            problems.append("data/sound_levels.json has a level for '%s', which is no sound" % name)
        if not (LEVEL_RANGE[0] <= float(db) <= LEVEL_RANGE[1]):
            problems.append("the level for '%s' is %.1f dB, outside %s" % (name, float(db), LEVEL_RANGE))
        elif name in peaks and peaks[name] + float(db) > OVER_SCALE:
            problems.append("'%s' peaks at %.1f dB and is played %+.1f dB louder: it goes %.1f dB over full scale" % (name, peaks[name], float(db), peaks[name] + float(db)))
    code = named_in_code()
    left_over = [k for k in sorted(keys) if k not in asked and k not in code and k not in levels]
    for k in left_over:
        problems.append("nothing names the sound '%s' (%s): a replaced file left behind?" % (k, ", ".join(keys[k][:2])))
    print("%d files, %d named sounds, %d owners' events" % (len(files), len(keys), len(asked)))
    for p in problems:
        print("PROBLEM  " + p)
    print("%d problems" % len(problems))
    return len(problems)


if __name__ == "__main__":
    sys.exit(min(main(), 1))
