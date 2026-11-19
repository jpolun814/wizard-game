"""Takes the wizards' cries (the CC0 voice recordings in art_source/voices_raw/) out of the recording booth and puts them in a stone hall.

    python tools/process_voices.py

The raw clips are close, dry and clean, so a person can hear a microphone in front of a mouth. Each clip is made less so: the very lowest and the very highest
frequencies are rolled off (the breath and the lip noise live up there), and a small hall's echo is laid under it (a decaying burst of noise, which is how a room
answers a short sound). The loudness is brought back to what it was. The cry is still the recording; nothing is made up. Writes audio/<name>.wav for every clip.
Needs numpy and soundfile.
"""
import glob
import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 44100
HIGH_CUT = 4200.0  # above this the breath and the lips
LOW_CUT = 110.0    # below this the chest of the close microphone
ECHO_SECONDS = 0.3
ECHO_DECAY = 0.08  # seconds for the echo to fall by most of its strength
ECHO_SHARE = 0.32  # how much echo is mixed under the dry sound


def band(x):
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    gain = np.ones_like(freqs)
    gain *= 1.0 / (1.0 + (freqs / HIGH_CUT) ** 4)  # a smooth fall, not a wall
    gain *= 1.0 - 1.0 / (1.0 + (freqs / LOW_CUT) ** 4)
    return np.fft.irfft(spectrum * gain, len(x))


def hall(length):
    rng = np.random.default_rng(11)
    t = np.arange(int(ECHO_SECONDS * RATE)) / RATE
    echo = rng.standard_normal(len(t)) * np.exp(-t / ECHO_DECAY)
    echo[: int(0.012 * RATE)] = 0.0  # the first wall is a little way off
    echo = np.fft.irfft(np.fft.rfft(echo) * (1.0 / (1.0 + (np.fft.rfftfreq(len(echo), 1.0 / RATE) / 2500.0) ** 2)), len(echo))  # a hall answers dull
    return echo / np.abs(echo).max()


def loudness(x):
    loud = x[np.abs(x) > 0.02]
    return float(np.sqrt(np.mean(loud ** 2))) if len(loud) else 1e-6


def process(x):
    dry = band(x)
    echo = hall(len(dry))
    size = len(dry) + len(echo)
    wet = np.fft.irfft(np.fft.rfft(dry, size) * np.fft.rfft(echo, size), size)
    wet *= np.abs(dry).max() / max(np.abs(wet).max(), 1e-9)
    out = np.zeros(size)
    out[: len(dry)] += dry
    out += wet * ECHO_SHARE
    end = int(0.08 * RATE)
    out[-end:] *= np.linspace(1.0, 0.0, end)
    out *= loudness(x) / loudness(out)
    peak = np.abs(out).max()
    return out * (0.95 / peak) if peak > 0.95 else out


def main():
    raw = os.path.join(ROOT, "art_source", "voices_raw")
    for path in sorted(glob.glob(os.path.join(raw, "*.wav"))):
        x, rate = sf.read(path, always_2d=True)
        assert rate == RATE, path
        out = process(x.mean(axis=1))
        sf.write(os.path.join(ROOT, "audio", os.path.basename(path)), out, RATE, subtype="PCM_16")
        print("wrote", os.path.basename(path), "%.2fs" % (len(out) / RATE))


main()
