"""Synthesises the sounds of the Blood school, Tide Surf and Obsidian Armor; no downloads needed.

    python tools/make_spell_sounds.py

    blood_cast  a wet, heavy thud with a low gurgle: a bolt of blood leaving the hand
    heartbeat   two quick heart thumps: Adrenaline
    surf        a swell of water rushing past that rises and falls: Tide Surf
    glass       a bright rising ring of struck glass over a low hum: Obsidian Armor
    faint       a falling tone that ends in a soft thud: Faint
Needs numpy and soundfile.
"""

import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100


def t_axis(length):
    return np.arange(int(length * RATE)) / RATE


def lowpass(x, taps):
    return np.convolve(x, np.ones(taps) / taps, mode="same")


def normal(x, peak=0.85):
    return x / (np.abs(x).max() or 1.0) * peak


def thump(length, start, end, decay):
    t = t_axis(length)
    freq = end + (start - end) * np.exp(-t / 0.05)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / decay)


def blood_cast(rng):
    t = t_axis(0.5)
    body = thump(0.5, 140.0, 55.0, 0.10)
    wet = lowpass(rng.standard_normal(len(t)), 60) * np.exp(-t / 0.18)  # a muffled slosh
    gurgle = np.sin(2 * np.pi * (90.0 + 30.0 * np.sin(2 * np.pi * 13.0 * t)) * t) * np.exp(-t / 0.2) * 0.5
    return normal(body + 0.9 * wet + gurgle)


def heartbeat(rng):
    out = np.zeros(int(0.7 * RATE))
    for start, gain in [(0.0, 1.0), (0.2, 0.75)]:
        beat = thump(0.3, 95.0, 50.0, 0.07) * gain
        i = int(start * RATE)
        out[i:i + len(beat)] += beat[: len(out) - i]
    return normal(out)


def surf(rng):
    t = t_axis(1.4)
    swell = np.sin(np.pi * t / 1.4) ** 1.5  # rises and falls like a wave passing
    hiss = rng.standard_normal(len(t))
    water = (lowpass(hiss, 6) * 0.6 + lowpass(hiss, 40) * 1.2) * swell
    bubbles = np.zeros(len(t))
    for _ in range(40):  # small bright drops: a quick rising chirp each
        s = int(rng.uniform(0.0, 1.2) * RATE)
        n = int(0.05 * RATE)
        tt = np.arange(n) / RATE
        chirp = np.sin(2 * np.pi * (700.0 + rng.uniform(0, 900) + 9000.0 * tt) * tt) * np.exp(-tt / 0.015)
        bubbles[s:s + n] += chirp[: len(bubbles) - s] * rng.uniform(0.05, 0.2)
    return normal(water + bubbles * swell)


def glass(rng):
    t = t_axis(1.1)
    ring = np.zeros(len(t))
    for ratio, gain in [(1.0, 1.0), (2.76, 0.6), (5.4, 0.4), (8.9, 0.25)]:  # a struck bell's inharmonic partials
        ring += np.sin(2 * np.pi * 880.0 * ratio * t) * np.exp(-t / (0.5 / ratio ** 0.5)) * gain
    hum = np.sin(2 * np.pi * 110.0 * t) * np.exp(-t / 0.5) * 0.5
    click = np.diff(rng.standard_normal(len(t)), prepend=0.0) * np.exp(-t / 0.01)
    return normal(ring + hum + 0.5 * click)


def faint(rng):
    t = t_axis(0.9)
    freq = 420.0 * np.exp(-t / 0.35) + 70.0
    sigh = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / 0.4) * 0.6
    land = np.zeros(len(t))
    thud = thump(0.3, 90.0, 45.0, 0.08)
    i = int(0.5 * RATE)
    land[i:i + len(thud)] = thud[: len(t) - i]
    return normal(sigh + land)


def main():
    rng = np.random.default_rng(11)
    for name, build in [("blood_cast", blood_cast), ("heartbeat", heartbeat), ("surf", surf), ("glass", glass), ("faint", faint)]:
        x = build(rng)
        n = min(int(0.02 * RATE), len(x))
        x[-n:] *= np.linspace(1, 0, n)
        sf.write(os.path.join(ROOT, "audio", name + ".wav"), x, RATE, subtype="PCM_16")
        print("wrote", name)


if __name__ == "__main__":
    main()
