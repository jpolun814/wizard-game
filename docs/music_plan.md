# Music plan: which track goes where (not in the game yet)

**Status (owner, 2026-11-20): the music is not ready, so it is not in the game.** The tracks (`music/`), the player (`scripts/core/music.gd`), the converter
(`tools/make_music.py`) and the test (`tests/unit/music_test.gd`) are kept, but nothing plays:
- `Music.in_the_game` is `false`, so `Music.play_for(place)` returns at once. The test turns it on for itself.
- `export_presets.cfg` excludes `music/*`, so a build does not carry the tracks.

**To put the music in the game** (when the owner says it is ready): set `in_the_game := true` in `scripts/core/music.gd`, remove `music/*` from both
`exclude_filter` lines in `export_presets.cfg`, and clear the points under "Before it goes in" below.

## Which track plays where (the owner's choice, 2026-11-20)

| Place | Track | Made by | Loudness (`db`, on top of `Music.LEVEL` of -10) | Note |
|---|---|---|---|---|
| Menu (first screen) | Invincibility | Francesco Pirrone | +5.6 | an 8-second loop |
| Waiting room, and the Tutorial (it is a Lab) | Intro Adventurous | Francesco Pirrone | -1.5 | |
| Portal fields | Intro Adventurous | Francesco Pirrone | -1.5 | shares the waiting room's track, which carries on rather than restarting |
| Ashlands | Boss | Francesco Pirrone | 0.0 | |
| Sky (open sky, the last world) | Battle Track | TomMusic | -2.7 | |
| Jungle | Beyond Mist | alkakrab | -0.7 | |
| Graveyard | Shadowforge Convergence | alkakrab | -1.0 | |
| Castle | Dread March | alkakrab | +2.5 | |
| Ocean | Veil of Eternal Nightfall | alkakrab | +0.6 | |
| Underground | none (quiet) | | | no track chosen yet |
| Peaks (`mountains`) | none (quiet) | | | no track chosen yet |

The same table is `Music.TRACKS` in code. A place with no track fades to quiet. A screen that does not call `Music.play_for` (the Library, the loading screen,
the cut-scenes) leaves what was playing.

**Held in reserve:** Moonspire, Emberlight and Silverbook (alkakrab's ambient pack), and Pirrone's Fight (liked, no place yet). The two quiet places are the
natural homes for these.

## How it behaves

- Each screen says where the player is; the new track fades in over 1.5 s as the last fades out. In a network game each person hears the place they are in.
- It plays on the Music bus (the settings' Music slider); M mutes everything. A Silence hushes only the sound effects.
- Every track is a pack's own seamless loop, copied to Ogg Vorbis with no cut and no fade (`python -I tools/make_music.py`).

## Before it goes in

1. **The owner says it is ready** (it is not: nothing here has been judged as a whole in play yet).
2. **Choose tracks for the underground and the peaks**, or leave them quiet on purpose.
3. **alkakrab's licence asks for permission before his tracks go into an open-source game** (jungle, graveyard, castle and ocean use his). Ask first if the repo is
   made public. Contact is in `art/CREDITS.md`.
4. **Pirrone's tracks are registered for Content ID**: a video of the game (menu, waiting room, ashlands) may be claimed. He asks to be contacted to clear it.
5. **No AI-made music** (owner's rule): each pack must say no generative AI was used. The four sources all do, as recorded in `art/CREDITS.md`.
6. Listen to every transition and each track's loudness against the effects; nobody has heard the whole set in a match yet.
