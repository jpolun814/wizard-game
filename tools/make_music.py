"""Builds the game's music (music/*.ogg) from the loop versions of the packs the owner chose.

The downloads are not kept in the repo (see docs/handoff/04_art_and_assets.md): unpack each pack into the Downloads
folder (or pass --downloads DIR) and run

    python -I tools/make_music.py

Each track is the pack's own seamless loop, copied as it is (no cut, no fade, no change of loudness) and saved as
Ogg Vorbis, which Godot loops to the sample: a WAV loop is ten times the size. How loud each plays is set in
scripts/core/music.gd (TRACKS), from the loudness this script prints.

Every track here is human-made (the owner's rule: no AI music) and free to use in the game; the terms are in
art/CREDITS.md. Which place plays which track is the owner's choice (2026-11-20).
"""

import argparse
import os
import sys

import numpy as np
import soundfile as sf

PIRRONE = "Francesco Pirrone - Free Game Music Pack/Francesco Pirrone - Free Game Music Pack/LOOP VERSIONS/WAV"
TOMMUSIC = "Free Fantasy Music Pack By TomMusic/Free Fantasy Music Pack By TomMusic/WAV files/Loops"
ALKAKRAB_BOSS = "alkakrab_boss_loops/Loops wav"  # "Loops wav.zip" from alkakrab's 6 Dark Fantasy Boss Battle Tracks, unzipped into alkakrab_boss_loops
ALKAKRAB_MAGIC = "alkakrab_magical/Free 12 Fairytale Magical Fantasy Tracks/wav"  # alkakrab's Free 12 Fairytale Magical Fantasy Tracks, unzipped into alkakrab_magical

## The game's name for a track -> where its loop is in the downloads.
TRACKS = {
    "invincibility": (PIRRONE, "21 - Invincibility LOOP 240bpm.wav"),
    "intro_adventurous": (PIRRONE, "02 - Intro Adventurous LOOP 142bpm.wav"),
    "boss": (PIRRONE, "27 - Boss LOOP 158bpm.wav"),
    "battle_track": (TOMMUSIC, "4 Battle Track LOOP TomMusic.wav"),
    "shadowforge_convergence": (ALKAKRAB_BOSS, "2. Shadowforge Convergence (Loop).wav"),
    "dread_march": (ALKAKRAB_BOSS, "5. Dread March (Loop).wav"),
    "veil_of_eternal_nightfall": (ALKAKRAB_BOSS, "6. Veil of Eternal Nightfall (Loop).wav"),
    "beyond_mist": (ALKAKRAB_MAGIC, "4. Beyond Mist (Intense, Ambient)/Beyond Mist (Full Loop).wav"),
}

QUALITY = 0.6  # Vorbis quality, 0 to 1: about 190 kbit/s for these, far past what anyone hears in a game


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--downloads", default=os.path.expanduser("~/Downloads"))
    args = parser.parse_args()
    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "music")
    os.makedirs(out_dir, exist_ok=True)
    missing = 0
    for name, (folder, file) in TRACKS.items():
        source = os.path.join(args.downloads, folder, file)
        if not os.path.exists(source):
            print(f"missing: {source}")
            missing += 1
            continue
        data, rate = sf.read(source, dtype="float32", always_2d=True)
        target = os.path.join(out_dir, name + ".ogg")
        # Written a block at a time: libsndfile's Vorbis encoder crashes the process when handed a whole track at once.
        with sf.SoundFile(target, "w", rate, data.shape[1], format="OGG", subtype="VORBIS", compression_level=1.0 - QUALITY) as out:
            for start in range(0, len(data), 8192):
                out.write(data[start:start + 8192])
        back, _ = sf.read(target, dtype="float32", always_2d=True)
        rms = 20.0 * np.log10(np.sqrt(np.mean(data ** 2)) + 1e-9)
        print(f"{name}: {len(data) / rate:.1f} s, loudness {rms:.1f} dBFS, {len(back) - len(data):+d} samples after encoding, "
              f"{os.path.getsize(target) // 1024} KB")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
