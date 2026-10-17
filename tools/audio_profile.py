"""Describes sound files in numbers, for choosing sounds without being able to listen to them.

    python -I tools/audio_profile.py audio/spark.wav some/other/*.ogg

For each file it prints:
    length in seconds; "act" how long it is actually loud (above -30 dB of its peak); "atk" when it peaks;
    then for each quarter of the file: c = spectral centroid in Hz (brightness: under ~800 is a rumble or thump,
    2-5k is a whoosh or crackle, over ~7k is hiss or fizz), fl = spectral flatness (0 = a pure tone or chime,
    0.4+ = noise such as wind, fire roar or static), lo = share of energy under 200 Hz (bass weight).

Reading it, roughly:
    a punch or thump: short, atk ~0, low centroid, high lo
    a whoosh: 0.2-0.6 s, rising then falling, mid centroid, flat (noisy)
    lightning or a crack: atk 0, very bright and flat at the start, then a rumble (low centroid) after
    a magical chime: low flatness, high centroid, long tail
    a roar or flame: long, flat, bass-heavy, steady across the quarters
Use it to rule sounds out, never to call one good: say plainly to the user that you could not listen.

Needs numpy and soundfile (pip install --isolated --index-url https://pypi.org/simple numpy soundfile).
"""

import sys

import numpy as np
import soundfile as sf


def profile(path):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    length = len(x) / rate
    win = int(rate * 0.02)
    if len(x) > win:
        env = np.array([np.sqrt(np.mean(x[i:i + win] ** 2)) for i in range(0, len(x) - win, win)])
    else:
        env = np.array([np.abs(x).max()])
    attack = np.argmax(env) * 0.02
    active = (env > env.max() * 0.03).sum() * 0.02

    def spectrum(seg):
        if len(seg) < 256:
            return 0.0, 0.0, 0.0
        f = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) + 1e-12
        freqs = np.fft.rfftfreq(len(seg), 1 / rate)
        centroid = (f * freqs).sum() / f.sum()
        flatness = np.exp(np.mean(np.log(f))) / np.mean(f)
        low = (f[freqs < 200] ** 2).sum() / (f ** 2).sum()
        return centroid, flatness, low

    n = len(x)
    quarters = [spectrum(q) for q in (x[:n // 4], x[n // 4:n // 2], x[n // 2:3 * n // 4], x[3 * n // 4:])]
    return "%5.2fs act%5.2f atk%4.2f | " % (length, active, attack) + " ".join(
        "c%5.0f/fl%.2f/lo%.2f" % q for q in quarters)


def main():
    for path in sys.argv[1:]:
        try:
            print("%-48s %s" % (path[-48:], profile(path)))
        except Exception as e:  # a file the library can't read: say so and carry on
            print(path, "ERROR", e)


if __name__ == "__main__":
    main()
