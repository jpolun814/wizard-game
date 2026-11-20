"""Cuts the sounds that come from NOX SOUND's Essentials Series (CC0, https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound) into audio/.

    python tools/make_nox_sounds.py <the unpacked Essentials_Series_NOX_SOUND folder>

Each is a recording trimmed to its start, faded at the ends and brought to one loudness; nothing is made up:
    step_<ground>_1..4   a footstep on each kind of ground (the biome decides which: Wizard.STEP_SOUNDS)
    fire_wall            the crackle of a camp fire
    raise_dead           earth giving way: a deep cave rumble, two thuds of earth and the creak of a wooden door, mixed
    pickup               a coat picked up: a rustle of cloth
    water_jet, geyser    the rush of a waterfall
    push_air             a bag dropped and a coat thrown (the Push spell; `push` is the shared whoosh of shots, blows and gusts)
    step_mud_1..4        a step in mud (a wizard in a Mudslide)
    land_<ground>_1..3   a landing on each kind of ground, after a fall (the wizard's own)
    quicksand            a step in mud
    snow                 a gust of cold wind (the Blizzard)
    surf                 the sea (Tide Surf)
    tornado              wind through a forest
Every sound here is NOX and nothing else (the owner prefers pure sounds). Only `summon` and `push` lay two or more NOX recordings over each other.
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
LANDS = {  # ground: the pack's pattern for a landing on it (the pack has none for gravel: the ashlands' basalt lands as rock)
    "dirt": "Footsteps_DirtyGround_Jump_Land_*", "snow": "Footsteps_Snow_Hard_Jump_Land_*", "leaves": "Footsteps_Leaves_Jump_Land_*",
    "gravel": "Footsteps_Rock_Jump_Land_*", "tile": "Footsteps_Tile_Jump_Land_*", "rock": "Footsteps_Rock_Jump_Land_*",
    "grass": "Footsteps_Grass_Jump_Land_*", "wood": "Footsteps_Wood_Jump_Land_*", "mud": "Footsteps_Mud_Jump_Land_*",
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
            save("wizard__step_%s_%d" % (ground, k), cut(path, onset(path), 0.4, 0.0, 0.1, 0.16))
    for ground, pattern in LANDS.items():
        files = sorted(glob.glob(os.path.join(steps, "**", pattern + ".wav"), recursive=True))
        for k, path in enumerate(files[:3], 1):
            save("wizard__land_%s_%d" % (ground, k), cut(path, onset(path), 0.5, 0.0, 0.15, 0.2))
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
    save("raise_dead", (mixed, rate))
    mud = sorted(glob.glob(os.path.join(steps, "**", "Footsteps_Mud_Walk_*.wav"), recursive=True))[2]
    save("quicksand", cut(mud, onset(mud), 0.8, 0.0, 0.2, 0.18))
    steps_in_mud = sorted(glob.glob(os.path.join(steps, "**", "Footsteps_Mud_Walk_*.wav"), recursive=True))
    for k, path in enumerate(steps_in_mud[::max(1, len(steps_in_mud) // 4)][:4], 1):
        save("wizard__step_mud_%d" % k, cut(path, onset(path), 0.5, 0.0, 0.1, 0.16))
    save("snow", cut(os.path.join(nature, "Ambiance_Wind_Calm_Loop_Stereo.wav"), 4.0, 2.6, 0.5, 1.0, 0.1))
    save("surf", cut(os.path.join(nature, "Ambiance_Sea_Loop_Stereo.wav"), 6.0, 6.0, 1.0, 1.5, 0.15))
    save("tornado", cut(os.path.join(nature, "Ambiance_Wind_Forest_Loop_Stereo.wav"), 3.0, 4.0, 0.6, 1.0, 0.2))
    thump = os.path.join(sample, "Backpack_Medium_Polyester_Drop_Stereo.wav")
    coat_throw = os.path.join(sample, "Cloth_Winter_Coat_Throw_Moderate_Stereo.wav")
    bag = cut(thump, onset(thump), 0.45, 0.0, 0.2, 0.2)[0]
    x, rate = sf.read(coat_throw, always_2d=True)
    x = x.mean(axis=1)
    window = int(0.1 * rate)
    energy = [np.sum(x[i:i + window] ** 2) for i in range(0, len(x) - window, window)]
    peak = int(np.argmax(energy)) * window / rate
    whoosh = cut(coat_throw, max(0.0, peak - 0.15), 0.5, 0.04, 0.2, 0.2)[0]
    pushed = np.zeros(int(0.5 * rate))
    for layer, gain in ((bag, 1.0), (whoosh, 0.7)):
        layer = layer[: len(pushed)]
        pushed[: len(layer)] += layer / (np.abs(layer).max() or 1.0) * gain
    save("push_air", (pushed * (0.9 / np.abs(pushed).max()), rate))
    coat = os.path.join(sample, "Cloth_Coat_PickUp_Stereo.wav")
    save("pickup", cut(coat, onset(coat), 0.7, 0.0, 0.15, 0.1))


main(sys.argv[1])
