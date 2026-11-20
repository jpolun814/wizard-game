"""Cuts the sounds that come from NOX SOUND's Essentials Series (CC0, https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound) into audio/.

    python tools/make_nox_sounds.py <the unpacked Essentials_Series_NOX_SOUND folder>

Each is a recording trimmed to its start, faded at the ends and brought to one loudness; nothing is made up:
    step_<ground>_1..4   a footstep on each kind of ground (the biome decides which: Wizard.STEP_SOUNDS)
    fire_wall            the crackle of a camp fire
    summon               earth giving way: a deep cave rumble, two thuds of earth and the creak of a wooden door, mixed
    pickup               a coat picked up: a rustle of cloth
    water_jet, geyser    the rush of a waterfall
The wizards' voices are cut by tools/make_voices.py from the same pack. Needs numpy and soundfile.
"""
import glob
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEPS = {  # ground: the pack's pattern for a single walking step on it
    "dirt": "Footsteps_DirtyGround_Walk_*", "snow": "Footsteps_Snow_Hard_Walk_*", "leaves": "Footsteps_Leaves_Walk_*",
    "gravel": "Footsteps_Gravel_Walk_*", "tile": "Footsteps_Tile_Walk_*", "rock": "Footsteps_Rock_Walk_*",
    "grass": "Footsteps_Walk_Grass_Mono_*", "wood": "Footsteps_Wood_Walk_*",
}


def loud(x):
    v = x[np.abs(x) > 0.02 * max(np.abs(x).max(), 1e-9) * 10]
    return float(np.sqrt(np.mean(v ** 2))) if len(v) else 1e-6


def cut(path, start, seconds, fade_in, fade_out, rms):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    x = x[int(start * rate):int((start + seconds) * rate)].copy()
    a = min(len(x), int(fade_in * rate))
    b = min(len(x), int(fade_out * rate))
    if a:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    x *= rms / loud(x)
    peak = np.abs(x).max()
    if peak > 0.95:
        x *= 0.95 / peak
    return x, rate


def onset(path):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    return max(0.0, int(np.argmax(np.abs(x) > 0.2 * np.abs(x).max())) / rate - 0.01)


def save(name, made):
    x, rate = made
    sf.write(os.path.join(ROOT, "audio", name + ".wav"), x, rate, subtype="PCM_16")
    print("wrote", name, "%.2fs" % (len(x) / rate))


def main(pack):
    steps = os.path.join(pack, "Footsteps_Essentials_NOX_SOUND")
    for ground, pattern in STEPS.items():
        files = sorted(glob.glob(os.path.join(steps, "**", pattern + ".wav"), recursive=True))
        step = max(1, len(files) // 4)
        for k, path in enumerate(files[::step][:4], 1):
            save("step_%s_%d" % (ground, k), cut(path, onset(path), 0.4, 0.0, 0.1, 0.16))
    nature = os.path.join(pack, "Nature_Essentials_NOX_SOUND")
    save("fire_wall", cut(os.path.join(nature, "Ambiance_Firecamp_Medium_Loop_Mono.wav"), 2.0, 1.4, 0.15, 0.5, 0.15))
    save("water_jet", cut(os.path.join(nature, "Ambiance_Waterfall_Strong_Loop_Stereo.wav"), 3.0, 1.5, 0.08, 0.4, 0.15))
    save("geyser", cut(os.path.join(nature, "Ambiance_Waterfall_Strong_Loop_Stereo.wav"), 8.0, 2.0, 0.05, 0.8, 0.18))
    sample = os.path.join(pack, "Sample_A_Sound_Effect")
    rumble, rate = cut(os.path.join(nature, "Ambiance_Cave_Deep_Loop_Stereo.wav"), 5.0, 1.8, 0.4, 0.7, 0.12)
    parts = [(rumble, 0.0, 0.9)]
    for name, at, gain in (("Footsteps_DirtyGround_Jump_Land_01", 0.0, 1.0), ("Footsteps_Mud_Jump_Land_01", 0.35, 0.8)):
        path = glob.glob(os.path.join(steps, "**", name + ".wav"), recursive=True)[0]
        parts.append((cut(path, onset(path), 0.5, 0.0, 0.1, 0.2)[0], at, gain))
    door = os.path.join(sample, "Household_Door_Wood_Open_Stereo.wav")
    parts.append((cut(door, 0.0, 1.0, 0.05, 0.3, 0.1)[0], 0.5, 0.5))
    mixed = np.zeros(int(1.8 * rate))
    for x, at, gain in parts:
        start = int(at * rate)
        piece = x[: len(mixed) - start]
        mixed[start:start + len(piece)] += piece / (np.abs(piece).max() or 1.0) * gain
    mixed *= 0.9 / np.abs(mixed).max()
    save("summon", (mixed, rate))
    coat = os.path.join(sample, "Cloth_Coat_PickUp_Stereo.wav")
    save("pickup", cut(coat, onset(coat), 0.7, 0.0, 0.15, 0.1))


main(sys.argv[1])
