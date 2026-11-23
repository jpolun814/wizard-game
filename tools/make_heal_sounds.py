"""Cuts the healing sound: JaggedStone's "Magic spell SFX" (OpenGameArt, CC0) `magical_1`, the recording that CLAP (tools/sound_search.py) rated nearest to "a gentle
magical healing chime" among the sounds the game may use (0.41, with magical_6 at 0.41 and magical_2 at 0.39; the packs of unknown licence were left out of the search).
Nothing is made up: it is the recording, faded at the ends and brought to a peak. Each owner has a file of its own, as the game requires (docs/handoff/05_audio.md):

    python tools/make_heal_sounds.py <path to magical_1.ogg>

    rituals__mend         a healing chant said (Mending.say)
    cauterize__mend, breathe__mend, mud_mask__mend, healing_spring__mend     the heal spells
Needs numpy and soundfile.
"""
import os
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OWNERS = ["rituals", "cauterize", "breathe", "mud_mask", "healing_spring"]


def main(path):
    x, rate = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    a = int(0.01 * rate)
    b = int(0.2 * rate)
    x[:a] *= np.linspace(0.0, 1.0, a)
    x[-b:] *= np.linspace(1.0, 0.0, b)
    x *= 0.8 / np.abs(x).max()
    for owner in OWNERS:
        out = os.path.join(ROOT, "audio", "%s__mend.wav" % owner)
        sf.write(out, x, rate, subtype="PCM_16")
        print("wrote", out)


main(sys.argv[1])
