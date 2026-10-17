"""Builds the layered spell sounds that no single free recording covers well.

    python tools/make_sounds.py <downloads dir>

The downloads dir is the one tools/prepare_art.py uses, plus these CC0 packs unpacked into it:
    elec/      the Electricity Game Sound Pack (faxcorp)    opengameart.org/node/150369
    firestaff/ Fire Staff Sound Effects (LEGIT Audio)       opengameart.org/content/fire-staff-sound-effects

Each sound is a short mix of recordings and a little synthesis:
    spark       a lightning strike: a sharp crack that re-strikes twice, an electric snap, then a thunder roll
    blink       a teleport zip: an electric crackle over a quick rush of air
    push        a force push: a deep thump, a low whump of displaced air and a whoosh
    fire_breath a jet of flame: a roaring burner with a fire burst at its start
Needs numpy and soundfile.
"""

import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100


def load(path):
    data, rate = sf.read(path, always_2d=True)
    mono = data.mean(axis=1)
    if rate != RATE:
        t = np.arange(int(len(mono) * RATE / rate), dtype=np.float64) * (rate / RATE)
        mono = np.interp(t, np.arange(len(mono)), mono)
    return mono


def seconds(s):
    return int(s * RATE)


def envelope_peak(x):
    """Where a recording is loudest, in samples, judged over 100 ms windows so a lone click doesn't count."""
    win = seconds(0.1)
    energy = [np.sum(x[i:i + win] ** 2) for i in range(0, max(1, len(x) - win), win)]
    return int(np.argmax(energy)) * win


def fade(x, fade_in=0.005, fade_out=0.1):
    x = x.copy()
    n_in = min(seconds(fade_in), len(x))
    n_out = min(seconds(fade_out), len(x))
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x


def mix(length, *layers):
    """layers are (signal, start in seconds, loudness relative to its own peak)."""
    out = np.zeros(seconds(length))
    for signal, start, gain in layers:
        s = seconds(start)
        part = signal[: max(0, len(out) - s)]
        peak = np.abs(part).max() or 1.0
        out[s:s + len(part)] += part / peak * gain
    return out / (np.abs(out).max() or 1.0) * 0.9


def noise_burst(length, decay, rng):
    t = np.arange(seconds(length)) / RATE
    return rng.standard_normal(len(t)) * np.exp(-t / decay)


def lowpass(x, taps):
    return np.convolve(x, np.ones(taps) / taps, mode="same")


def spark(dl, rng):
    crack = np.diff(noise_burst(0.15, 0.012, rng), prepend=0.0)  # differenced noise: bright and sharp
    restrike = np.zeros(seconds(0.15))
    for at, gain in [(0.0, 1.0), (0.03, 0.6), (0.07, 0.4)]:
        burst = crack[: seconds(0.15) - seconds(at)] * gain
        restrike[seconds(at):seconds(at) + len(burst)] += burst
    snap = load(os.path.join(dl, "elec", "groundhit.wav"))
    thunder = load(os.path.join(dl, "oga", "sfx_100_v2", "sfx100v2_thunder_01.ogg"))
    start = max(0, envelope_peak(thunder) - seconds(0.05))
    roll = fade(thunder[start:start + seconds(1.6)], 0.01, 0.7)
    return mix(1.7, (restrike, 0.0, 1.0), (snap, 0.0, 0.7), (roll, 0.04, 0.75))


def blink(dl, rng):
    zap = fade(load(os.path.join(dl, "elec", "teleport_1.wav"))[: seconds(0.5)], 0.003, 0.2)
    rush = fade(load(os.path.join(dl, "oga", "sfx_100_v2", "sfx100v2_air_03.ogg")), 0.01, 0.1)
    return mix(0.55, (zap, 0.0, 0.8), (rush, 0.0, 0.7))


def push(dl, rng):
    t = np.arange(seconds(0.45)) / RATE
    freq = 45.0 + 95.0 * np.exp(-t / 0.06)  # a falling thump, like a door slammed by the air
    thump = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.09)
    whump = lowpass(rng.standard_normal(len(t)), 40) * np.exp(-t / 0.12)
    rush = fade(load(os.path.join(dl, "oga", "sfx_100_v2", "sfx100v2_air_03.ogg")), 0.01, 0.1)
    return fade(mix(0.45, (fade(thump, 0.004, 0.05), 0.0, 1.0), (fade(whump, 0.004, 0.1), 0.0, 0.6), (rush, 0.02, 0.55)), 0.0, 0.08)


def fire_breath(dl, rng):
    roar = load(os.path.join(dl, "scifi", "Audio", "thrusterFire_003.ogg"))
    roar = fade(roar[seconds(1.2):seconds(2.5)], 0.06, 0.45)
    burst = load(os.path.join(dl, "firestaff", "LEGIT_FIR_Fire_Staff 17-Audio.wav"))
    burst = fade(burst[: seconds(1.2)], 0.005, 0.5)
    return mix(1.3, (roar, 0.0, 0.8), (burst, 0.0, 0.7))


def main():
    dl = sys.argv[1] if len(sys.argv) > 1 else "."
    rng = np.random.default_rng(7)
    for name, build in [("spark", spark), ("blink", blink), ("push", push), ("fire_breath", fire_breath)]:
        sf.write(os.path.join(ROOT, "audio", name + ".wav"), build(dl, rng), RATE, subtype="PCM_16")
        print("wrote", name)


if __name__ == "__main__":
    main()
