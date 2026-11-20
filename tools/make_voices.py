"""Cuts the wizards' voices (their jump and hurt grunts) from NOX SOUND's Voices Essentials (CC0) into audio/.

    python tools/make_voices.py <the unpacked Essentials_Series_NOX_SOUND folder>

Four voices (the ids a look carries, kept from the older games): voice_1 and voice_3 are men, voice_4 and voice_5 women. Each gets four short hit grunts, for being
hurt, and four jumps: evenly chosen from the pack's own, trimmed to their start, faded and brought to one loudness. Nothing else is done to them.
Needs numpy and soundfile.
"""
import glob
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VOICES = {"voice_1": ("Male", "V1"), "voice_3": ("Male", "V2"), "voice_4": ("Female", "V1"), "voice_5": ("Female", "V2")}
COUNT = 4


def loud(x):
    v = x[np.abs(x) > 0.02]
    return float(np.sqrt(np.mean(v ** 2))) if len(v) else 1e-6


def prepare(path, rms, longest):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    start = int(np.argmax(np.abs(x) > 0.1 * np.abs(x).max()))
    x = x[max(0, start - int(0.01 * rate)):][: int(longest * rate)].copy()
    f = min(len(x), int(0.03 * rate))
    x[-f:] *= np.linspace(1, 0, f)
    x *= rms / loud(x)
    peak = np.abs(x).max()
    if peak > 0.95:
        x *= 0.95 / peak
    return x, rate


def choose(pack, gender, voice, kind, limit):
    files = []
    for path in sorted(glob.glob(os.path.join(pack, "Voices_Essentials_NOX_SOUND", "*", "*", "Voice_%s_%s_%s_Mono_*.wav" % (gender, voice, kind)))):
        x, rate = sf.read(path, always_2d=True)
        if len(x) / rate <= limit:
            files.append(path)
    return files[::max(1, len(files) // COUNT)][:COUNT]


def main(pack):
    for voice_id, (gender, voice) in VOICES.items():
        for k, path in enumerate(choose(pack, gender, voice, "Hit_Short", 0.55), 1):
            x, rate = prepare(path, 0.21, 0.5)
            sf.write(os.path.join(ROOT, "audio", "hurt_%s_%d.wav" % (voice_id, k)), x, rate, subtype="PCM_16")
        for k, path in enumerate(choose(pack, gender, voice, "Jump", 0.45), 1):
            x, rate = prepare(path, 0.19, 0.4)
            sf.write(os.path.join(ROOT, "audio", "jump_%s_%d.wav" % (voice_id, k)), x, rate, subtype="PCM_16")


main(sys.argv[1])
