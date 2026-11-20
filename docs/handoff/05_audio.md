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
  - `tools/make_nox_sounds.py`: `step_<ground>_k` (the biome decides the ground: `Wizard.STEP_SOUNDS`), `fire_wall` (a camp fire), `water_jet` and `geyser` (a waterfall), `raise_dead` (a cave rumble, thuds of earth and a door's creak; `summon` is the older shared sound of an enemy arriving, a swarm or a wolf), `step_mud_k` (a wizard in a Mudslide), `pickup` (a coat), `push_air` (a bag and a coat: the Push spell only), `quicksand` (a step in mud), `snow` (wind), `surf` (the sea) and `tornado` (wind in a forest). **Owner, 2026-11-20: prefer pure sounds** (one pack, no other recordings mixed in); `push` and `summon` layer only NOX recordings. The pack also has sea, rain, wind, cave and fire loops, and more footsteps (sand, mud, metal, water), not used yet.
- **Copied files:** the older sounds are copied by `tools/prepare_art.py` (see `SOUNDS` there) from:
  - Kenney's Sci-fi, Interface, RPG Audio, Impact and Platformer packs;
  - OpenGameArt's CC0 packs by rubberduck (80 RPG SFX, 80 creature SFX, 100 SFX, 100 SFX #2), "magic spell
    sfx", "ice spells", "freeze spell" and "fireball 1".
- **Mixed sounds:** `spark`, `blink` and `fire_breath` are layered by `tools/make_sounds.py` from recordings only. The synthesized parts (a noise crack, a sine thump) were taken out on 2026-11-19, because an agent must not make sounds:
  - **spark:** thunder from its first crack (the electric snap is gone with the synthesized crack; it may want a recording back).
  - **blink:** an electric teleport crackle over an air rush.
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
- **Music: fantasy battle, not slow dark ambient** (owner, 2026-11-20). See "Music" below.

## Music

**Not in the game yet (owner, 2026-11-20): the music is not ready.** `Music.in_the_game` is `false` (nothing plays) and builds exclude `music/*`. Which track goes where, and how to switch it on, is in `docs/music_plan.md`.

- **`Music`** (autoload, `scripts/core/music.gd`): each place has a track (`Music.TRACKS`: place -> file in `music/` and its loudness). A screen calls
  `Music.play_for(place)` and the track crossfades; a place with no track fades to quiet; a screen that does not call it (Library, loading, cut-scenes)
  keeps what was playing. The first screen calls it with `"menu"`; every `Arena` calls it with `_music_place()`: `"waiting_room"` (Lab, and the Tutorial,
  which is one), and the biome for a `World`. Two places that share a track (waiting room and portal fields) carry it on rather than restart it.
- It plays on the **Music bus** (`default_bus_layout.tres`), set by the settings' Music slider (`GameSettings` `"music"`); M mutes the master bus,
  so music too. A Silence hushes only the SFX bus: the music is not a sound of the world. `Music.LEVEL` keeps every track 10 dB under the effects.
- **Files:** `python -I tools/make_music.py` copies each chosen pack's own seamless loop into Ogg Vorbis (no cut, no fade). The downloads stay out of the repo.
- **The owner's rule: no AI-made music, only human-made music that is free to use.** A pack must say no generative AI was used.
- **Chosen so far (owner, 2026-11-20):** menu Invincibility (an 8-second loop), waiting room and portal fields Intro Adventurous, ashlands Boss
  (all Francesco Pirrone); sky Battle Track (TomMusic); jungle Beyond Mist, graveyard Shadowforge Convergence, castle Dread March, ocean Veil of
  Eternal Nightfall (alkakrab). Held in reserve: Moonspire, Emberlight, Silverbook (alkakrab's ambient pack) and Pirrone's Fight (liked, no place yet).
  The tutorial plays the waiting room's track (owner). Quiet: underground, peaks.
- **alkakrab's licence asks for permission before his tracks go in an open-source game** (`art/CREDITS.md`): ask the owner before the repo is made public.
- **Pirrone's tracks are registered for Content ID**: a video of the game may be claimed (see `art/CREDITS.md`).

## Every sound has one owner (owner, 2026-11-20)

**Nothing shares a sound.** Every sound belongs to one owner: a spell, a kind of creature (`mob_<kind>`), the wizard's body (`wizard`: steps, landings, being struck), a piece of scenery or terrain, or a screen. It is asked for by owner and event, `Sfx.cue("Ignite", "cast", where)`, never by a bare file name. A spell's own list is `sounds` in its `.tres` (a dictionary of event to sound, often one entry, sometimes several: a Geyser has five); everyone else's is in `data/sounds.json`. The file behind an event is `audio/<owner>__<event>_N` and is that owner's alone, even when it began as a copy of another's, so changing one sound never changes another. How loud each is: `data/sound_levels.json`. The voices (`jump_voice_*`, `hurt_voice_*`, played through `Sfx.speak`) are the one thing still played by name: each is one person's voice. `tests/checks/sound_ownership_check.tscn` fails if a file is missing, two owners name one sound, a script plays a bare name or a `Sfx.cue` asks for something that does not exist.
To change a sound: replace that owner's file (keep the name). To add one: copy a file to `audio/<owner>__<event>.wav`, add the event to the owner's `sounds`, and call `Sfx.cue`. An event name must not end in a number (it would read as a variant).

**A sound plays when the thing it stands for happens.** A footstep is a foot set down by a wizard walking or running on the ground under their own power (`Wizard._stepping`, on the floor, no ride on a wave, no shove, no swim); a landing is the ground met after a fall of 380 px/s or more (not in a swim, a flight or a wave). The ground is the biome's (`Wizard.STEP_SOUNDS`), and mud under a Mudslide. A creature's, spell's or scene's sound is played from the code that does what the sound is (the strike, the hit, the burn), not from nearby.

## Checking sounds without ears (owner asked, 2026-11-20)

An agent cannot hear, but three things stand in for part of it. None replaces the owner's ear (they judge taste and loudness by listening); they catch wrong category, wrong timing and broken files.
- **`tools/sound_search.py`** (LAION CLAP, a model that puts sounds and sentences in one space; first use downloads ~600 MB). `index <folders>` once (indexed now: NOX, the OpenGameArt CC0 packs the game's older sounds came from, and two unlicensed-as-far-as-we-know packs, `400 Sounds Pack` (kept in `C:/Users/Jordan Polun/Documents/wizard-game-sources/`, moved out of Downloads 2026-11-20) and `96 Extra SFX`: search them, but use nothing from them before their licence is found; `index` adds to `tools/sound_index.npz`, which is not in git; `tools/audit_sounds.py` and `docs/sound_audit.md` judge every game sound against these), then `find "a heavy stone door scraping"` ranks the pack's recordings by how well they match the words: use it to choose a sound instead of guessing from file names. `label file.wav` says what a file sounds like among 16 plain kinds, and `check "a footstep" a.wav b.wav` scores files against one description. Only order and gaps in the scores mean anything. Run `label` on every new sound before showing it to the owner: a "footstep" that reads as a whoosh is wrong.
- **`tests/checks/sound_cues_check.tscn`**: `Sfx.recording` keeps the name of every sound asked for, so a check can assert that a sound happens when its event does (and not otherwise): footsteps only when walking, a landing only after a fall, no steps on a wave. Add a case for every new trigger.
- **`tests/checks/sound_ownership_check.tscn`**: see above.
