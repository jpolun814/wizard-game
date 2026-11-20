# Audio

## How sound works in the game

- **Playing sounds:** `Sfx.play("name", world_position_or_null, volume_db, pitch_spread)`.
  - World sounds pan and fade with distance; pass `null` for interface sounds.
  - Files `audio/name_1.wav`, `name_2.wav` and so on are random variants of one name (footsteps, voices, stones).
  - `Sfx.VOLUME` balances loudness per name. Add an entry whenever you add a sound, then run `python tools/level_sounds.py` (it lists what is off its target loudness; `--apply` fixes it) and judge by ear.
- **Mute:** M mutes everything.

## Where sounds come from

- **NOX SOUND's Essentials Series (CC0) is the preferred source now** (owner, 2026-11-19: "use as many sounds from the same pack as possible"). Look there first; it is unpacked into a scratch folder and cut by two scripts:
  - `tools/make_voices.py`: the four wizard voices, `hurt_voice_N_k` (short hit grunts) and `jump_voice_N_k`. `WizardLook.jump_sound` and `hurt_sound` pick the voice a look carries (`voice_1`, `voice_3` men, `voice_4`, `voice_5` women), chosen in the character creator.
  - `tools/make_nox_sounds.py`: `step_<ground>_k` (the biome decides the ground: `Wizard.STEP_SOUNDS`), `fire_wall` (a camp fire), `water_jet` and `geyser` (a waterfall), `summon` (an eerie drone) and `pickup` (a coat). The pack also has sea, rain, wind, cave and fire loops, and more footsteps (sand, mud, metal, water), not used yet.
- **Copied files:** the older sounds are copied by `tools/prepare_art.py` (see `SOUNDS` there) from:
  - Kenney's Sci-fi, Interface, RPG Audio, Impact and Platformer packs;
  - OpenGameArt's CC0 packs by rubberduck (80 RPG SFX, 80 creature SFX, 100 SFX, 100 SFX #2), "magic spell
    sfx", "ice spells", "freeze spell" and "fireball 1".
- **Mixed sounds:** `spark`, `blink`, `push` and `fire_breath` are layered by `tools/make_sounds.py` from recordings only. The synthesized parts (a noise crack, a sine thump) were taken out on 2026-11-19, because an agent must not make sounds:
  - **spark:** thunder from its first crack (the electric snap is gone with the synthesized crack; it may want a recording back).
  - **blink:** an electric teleport crackle over an air rush.
  - **push:** a dropped bag, a thrown coat (both NOX) and an air rush.
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

## Sounds that are made from a recording with its problem removed

- **`tornado`:** a jet roar with everything above about a kilohertz rolled off, so the hiss goes and the rumble stays.
- **`ritual_ok`:** a 2.6-second phrase cut from the loudest part of a Gregorian chant (`new_assets/chant.ogg`).
- Both are built in `tools/make_sounds.py`. `NEW_ASSETS` copies `quicksand` (a mud squelch) into `audio/`.

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
