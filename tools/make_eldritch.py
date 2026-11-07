"""Synthesises audio/eldritch.wav, the sound of an Eldritch Blast: a dark, buzzing crackle, not a chime.

    python tools/make_eldritch.py

A low distorted hum that swells and sags, a harsh buzz over it, and a thick spray of electric crackle (short bursts of noise at random moments
that die away). Nothing in it is tuned high or rings, so it cannot sound like a twinkle. Needs numpy and soundfile.
"""

import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100
LENGTH = 0.85


def main():
    rng = np.random.default_rng(7)
    n = int(LENGTH * RATE)
    t = np.arange(n, dtype=np.float64) / RATE
    # How loud it is: a hard strike, then a slow sag, and a short tail.
    env = np.minimum(t / 0.01, 1.0) * np.exp(-t * 3.2)
    # The hum: a sawtooth that sags in pitch as it goes, driven into distortion so it growls.
    pitch = 95.0 * np.exp(-t * 0.9)
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    saw = 2 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    hum = np.tanh(saw * 4.0) * 0.55
    # The buzz: a harsh square wave cut up by a fast wobble, like current through a bad wire.
    buzz_phase = 2 * np.pi * np.cumsum(210.0 - 60.0 * t) / RATE
    buzz = np.sign(np.sin(buzz_phase)) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 47.0 * t))) * 0.22
    # The crackle: bursts of noise a few thousandths of a second long at random moments, many at first and fewer as it dies.
    crackle = np.zeros(n)
    count = int(LENGTH * 260)
    starts = (rng.random(count) ** 1.6 * (n - 400)).astype(int)
    for s in starts:
        length = int(rng.integers(30, 160))
        burst = rng.standard_normal(length) * np.exp(-np.arange(length) / (length * 0.25))
        burst = np.convolve(burst, np.ones(6) / 6.0, mode="same")  # smoothed, so it ticks and does not hiss
        burst = np.diff(np.concatenate(([0.0], burst)))  # and the difference keeps the low rumble out: a sharp tick, not a thump
        burst *= 6.0
        crackle[s:s + length] += burst * rng.uniform(0.2, 1.0)
    crackle *= 0.5 * (0.35 + 0.65 * np.exp(-t * 2.0))
    body = np.convolve(hum + buzz, np.ones(14) / 14.0, mode="same")  # the harsh edges of the hum and the buzz are rounded off: dark, not shrill
    out = body * env + crackle
    out = np.tanh(out * 1.4)
    out = np.convolve(out, np.ones(3) / 3.0, mode="same")
    out *= 0.9 / max(np.max(np.abs(out)), 1e-6)
    fade = int(0.04 * RATE)
    out[-fade:] *= np.linspace(1, 0, fade)
    sf.write(os.path.join(ROOT, "audio", "eldritch.wav"), out.astype(np.float32), RATE)


if __name__ == "__main__":
    main()
