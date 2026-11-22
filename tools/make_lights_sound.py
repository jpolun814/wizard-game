"""Cuts the twinkle of a Dancing Lights light (owner, 2026-11-21: "a really high pitched twinkle almost like wind chimes but staccato"): a small glass ping from the
400 Sounds Pack (the owner approved it, 2026-11-20), raised in pitch three ways and cut short, one file each: audio/dancing_lights__twinkle_1..3.wav.

    python -I tools/make_lights_sound.py "<the 400 Sounds Pack folder>"

The ping was found with tools/sound_search.py ("high pitched staccato wind chimes"). Needs numpy and soundfile.
"""
import json
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PITCHES = [1.9, 2.4, 3.0]  # how many times higher than the recording: three bell-like notes
SECONDS = 0.3
LEVEL = -9.0

pack = sys.argv[1]
x, rate = sf.read(os.path.join(pack, "Materials", "glass_ping_small.wav"), always_2d=True)
x = x.mean(axis=1)
for old in ("dancing_lights__twinkle.wav", "dancing_lights__twinkle.wav.import"):
    path = os.path.join(ROOT, "audio", old)
    if os.path.exists(path):
        os.remove(path)
for k, pitch in enumerate(PITCHES, 1):
    n = int(len(x) / pitch)
    y = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)[: int(SECONDS * rate)].copy()  # played faster: higher, and shorter
    fade = min(len(y), int(0.12 * rate))
    y[-fade:] *= np.linspace(1, 0, fade)
    y *= 0.7 / max(float(np.abs(y).max()), 1e-9)
    sf.write(os.path.join(ROOT, "audio", "dancing_lights__twinkle_%d.wav" % k), y, rate, subtype="PCM_16")
levels = json.load(open(os.path.join(ROOT, "data/sound_levels.json")))
levels.pop("dancing_lights__twinkle", None)
levels["dancing_lights__twinkle"] = LEVEL
json.dump(dict(sorted(levels.items())), open(os.path.join(ROOT, "data/sound_levels.json"), "w"), indent=1)
print("twinkles written")
