# Audio

## How sound works in the game

- **Playing sounds:** `Sfx.play("name", world_position_or_null, volume_db, pitch_spread)`.
  - World sounds pan and fade with distance; pass `null` for interface sounds.
  - Files `audio/name_1.ogg`, `name_2.ogg` and so on are random variants of one name, for footsteps, hurt
    sounds and stones.
  - `Sfx.VOLUME` balances loudness per name. Add an entry whenever you add a sound.
- **Mute:** M mutes everything.

## Where sounds come from

- **Copied files:** most are copied by `tools/prepare_art.py` (see `SOUNDS` there) from:
  - Kenney's Sci-fi, Interface, RPG Audio, Impact and Platformer packs;
  - OpenGameArt's CC0 packs by rubberduck (80 RPG SFX, 80 creature SFX, 100 SFX, 100 SFX #2), "magic spell
    sfx", "ice spells", "freeze spell", "fireball 1" and "earth element magic spell".
- **Mixed sounds:** `spark`, `blink`, `push` and `fire_breath` are built by `tools/make_sounds.py` from
  several recordings plus a little synthesis:
  - **spark:** a noise crack that re-strikes, an electric snap, then a thunder roll.
  - **blink:** an electric teleport crackle over an air rush.
  - **push:** a falling sine thump, a low-passed whump, and an air rush.
  - **fire_breath:** a rocket-thruster roar with a fire-staff burst.
- **Credits:** listed in `art/CREDITS.md`.

## You can't hear. Work around it honestly

1. **Shortlist by name and source page description.**
2. **Profile candidates:** `python -I tools/audio_profile.py file...` gives length, when it peaks, brightness,
   noisiness and bass weight per quarter of the file. The docstring explains how to read it.
3. **Match the profile to what the sound should be:**
   - A crack: instant attack, bright and noisy.
   - Thunder: low centroid, long.
   - A whoosh: mid brightness, noisy, rise and fall.
   - A chime: tonal (low flatness), bright, long tail.
   - A thump: short, bass-heavy.
4. **Layer to fix gaps.** If no single file fits, mix one in `make_sounds.py`. Resampling bug already hit:
   `np.arange` is int32 on Windows, so pass `dtype=np.float64`.
5. **Tell the owner plainly** that you chose by analysis and could not listen. They do listen, and they have
   rejected sounds before (Blink, Spark and Push).

## What the owner wants from sounds

- **Accurate to the action:**
  - Lightning cracks and rolls.
  - A teleport zips.
  - A force push sounds like displaced air.
  - Fire roars.
  - Ice shatters.
- **Not sci-fi lasers** for magic. The old Spark was a laser and was rejected.
- **Gothic mood.** Music is still missing: dark ambient CC0 loops would fit (OpenGameArt "dark ambient" with the
  CC0 filter). Pascal Belisle's GothicVania music needs credit, so ask first.
