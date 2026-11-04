# Testing and verifying: do this every time

You can't play the game by hand, so you must prove things in other ways. The owner notices when something was
claimed and not checked.

## The minimum after any change

1. **Import:** `godot --headless --path . --import` (needed if you added or changed any png, ogg or wav).
2. **Parse check:** `godot --headless --path . --quit-after 200 2>&1 | grep -iE "SCRIPT|parse|error"`. It
   must print nothing (ignore "leaked" and "still in use" at exit).
3. **Gestures:** `godot --headless -s tests/test_gestures.gd` must report every check passed.
4. **Look at it:** run the showcase scenario that covers your change, and open the screenshots.
5. **Soak:** `scenario=soak`, headless. Grep for
   `SCRIPT ERROR`.

## Network play (two copies of the game on this computer)

`tests/net_check.tscn` (the shared waiting room) and `tests/net_match_check.tscn` (a whole match) each run as two copies: start one
with `-- role=host` in the background, then one with `-- role=client`. Both must print PASS, and their logs must have no
`ERROR` lines. Run them in real time: no `--fixed-fps`. Drop `--headless` and add `out=DIR` for pictures of what each side sees.
See `11_network_play.md`.

## Showcase scenarios (`tests/showcase.tscn`)

Run with `godot --path . tests/showcase.tscn -- scenario=NAME out=DIR [only=Spell_Name]`.

| Scenario | What it shows |
|---|---|
| `world` | every enemy kind standing about, then the debug view |
| `kinds` | enemy art and colours |
| `spells` | every spell cast in turn among enemies, one screenshot each; `only=Fire_Breath` casts one spell with frames every 0.1 s |
| `ui` | portal arrow, portal, spellbook spreads (with a page turn), pause, game over |
| `wizard` | a dark-wizard duel |
| `brawl` | a mixed fight |
| `soak` | random casting among a few enemies, no screenshots; works headless |

**Notes:**
- Steps are sorted by time before they run, so you can add them in any order.
- Showcase runs pick a random map each time, so positions change between runs.
- Screenshots need a window: no `--headless` except for `soak`.

## Reading screenshots well

- **Contact sheets:** combine several into one image with PIL, crop and resize, and label each.
- **Crop where the action is.** Ground effects sit at y ≈ 550–650 on screen when the player is on the ground.
- **Check all three biomes** for anything that must read against dark, green and lavender backgrounds.
- **Never explain away something strange.** If something looks wrong (a white box, a floating piece, a gap), find
  out what it is:
  - run `only=Spell` for frame-by-frame screenshots;
  - temporarily print node positions;
  - hide groups of nodes and snap again;
  - write a tiny test scene.
  
  Remove any debug code afterwards.
- **Hitboxes:** run with `--debug-collisions` to see them.

## Finding a bug methodically (what worked)

1. **Reproduce it in the showcase,** with `only=` for spells.
2. **Isolate:** a minimal scene (a Node2D plus a Camera2D plus the thing). If it works in isolation but not in the
   game, list what differs: parent, lifetime, what else holds references, order.
3. **Instrument:** print the actual values (texture, material, modulate, filter) from inside the failing code.
4. **Fix the cause, not the symptom.** Then re-run the full minimum check above.

## Testing art and sound you can't fully judge

- **Art:** compare the new asset next to the characters in a screenshot, at game zoom. Pixel density and palette
  should match.
- **Sound:** profile it (`tools/audio_profile.py`) and say plainly that you couldn't listen.
- **Controls and feel:** say that you couldn't test by hand. The owner plays it and will report back.


## Checks added with the spell expansion (chapter 14)

`cluster_check`, `brains_start_check`, `blizzard_freeze_check`, `group_a_check` (Barbs, Pebble, Hailstorm, Featherfall), `group_b_check` (Thorn Whip, Insect Plague), `leech_check`, `raise_dead_check`,
`mirage_check`, `sphere_check`, `eye_check`, `lab_sphere_check`, and additions to `test_gestures` (761 checks), `test_pages` and `library_screen_check`. All are in `tools/run_checks.py`. Tests that cast in a world set the
wizard's `ledger.learn_all()` (a wizard starts with no spells now), and a test that needs a pit builds its floor high above the ground (`sphere_check`). Failures that were there before the expansion
(checked on a clean copy of HEAD): `sinkhole_check` (2), `ridge_check` (2), and some of `brain_spells_check` (Geyser, Great Oak, Liana, Push, Tornado, Updraft, sometimes Earthquake).


## The stats screen (end of a person's match)

`MatchStats` (`scripts/match_stats.gd`, all static) keeps the counts for the person at this machine: time survived, damage dealt and taken, kills, casts by spell, misses (a stroke that matched nothing, or a cast refused as too tired or too weak), accuracy, and a point for each chart every 2 seconds. `World` starts it with the match (`MatchState.stage == 0`), ticks it, and `_show_stats` puts a `StatsScreen` (`scripts/stats_screen.gd`, drawn in code: an interface, so it may be) over the hud when the person falls, with where they placed. Damage is credited to a wizard through `SpellTargets.hurt(..., by)` or `MatchStats.strike(self)` before a direct blow; `arena.spawn_spell` tags what it spawns with the caster (`caster` meta) so that a spell's own hits can be credited. **Limits:** a blow on another person's wizard is counted here too (`Wizard.take_damage` on a likeness reports it before returning); the practice dummy is never a kill; damage past the last of a body's strength is not counted. Pointing at a chart shows the numbers at that moment. `tests/stats_check.tscn` (add `-- out=DIR` for a picture, needs a window).
