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


## Writing a check that casts in a world

A wizard starts with no spells, so a test that casts in a world first calls the wizard's `ledger.learn_all()`. A test that needs a pit builds its floor high above
the ground (`sphere_check`). Known failures are listed in `16_open_work.md`.

## Picture tests (need a window; each takes `-- out=DIR`)

Besides those listed above: `look_check` (Smoke Screen, Ice Prison, Sinkhole, Stalagmite, Stone Wall and Eclipse at the moments that matter),
`pause_look` (the pause screen in every kind of world), `rock_art_look` (what `RockArt` makes; run with `-s`), `lab_lag_check` (every slow frame of the waiting room's
first seconds; `off=` switches things off to find the cause).


## The stats screen (end of a person's match)

`MatchStats` (`scripts/match_stats.gd`, all static) keeps the counts for the person at this machine: time survived, damage dealt and taken, kills, casts by spell, misses (a stroke that matched nothing, or a cast refused as too tired or too weak), accuracy, and a point for each chart every 2 seconds. `World` starts it with the match (`MatchState.stage == 0`), ticks it, and `_show_stats` puts a `StatsScreen` (`scripts/stats_screen.gd`, drawn in code: an interface, so it may be) over the hud when the person falls, with where they placed. Damage is credited to a wizard through `SpellTargets.hurt(..., by)` or `MatchStats.strike(self)` before a direct blow; `arena.spawn_spell` tags what it spawns with the caster (`caster` meta) so that a spell's own hits can be credited. **Limits:** a blow on another person's wizard is counted here too (`Wizard.take_damage` on a likeness reports it before returning); the practice dummy is never a kill; damage past the last of a body's strength is not counted. Pointing at a chart shows the numbers at that moment. `tests/stats_check.tscn` (add `-- out=DIR` for a picture, needs a window).

**The look of the stats screen (changed 2026-11-04):** it is a crystal ball seen close, not a dashboard. The owner said the first one (tiles, a grid of charts, a side panel) "reeks of LLM-generated design". `StatsScreen` draws the dark room and a stand, a `ColorRect` with `scripts/hud/crystal_ball.gdshader` is the ball (drifting mist in blocks of 4 px, so it sits with the pixel art), and a `Control` over it draws the writing and the chart of the page. The left and right arrow keys (or the arrows at its sides) turn through seven pages: the end, blows struck, spells learned, casting, the fallen, the tally and favourites; the pointer over a chart reads off a value. `tests/stats_check.tscn -- out=DIR` takes `stats_0.png` to `stats_6.png`. The "Match stats" button is now a small crystal ball on its stand at the bottom left (`BallButton`, the same mist shader; node `StatsButton`). The library is a bookcase (`LibraryScreen`; art drawn by `tools/make_library_art.py` into `art/ui/library/`): books of no name, books leaning and lying in stacks, and nine named tomes (seven schools, the incantations and the Chronicle) whose names run down their spines. A tome opens as the spellbook does, found pages first and blank torn ones after, with ribbons for the world filter and counts in the margins. The Chronicle's first page holds the figures (matches played and won, pages known, title, and from the matches kept: time played, kills, best placing); after it comes a page for each match played to its end, newest first, with how it ended, the date, the worlds, a line of damage dealt and taken, and the counts. The ribbons keep only the matches that went through a world. `MatchStats.summary` builds the record when the person falls or wins (`World._record_match`), `Library.record_match_end` keeps it in `history` of the library file (about half a kilobyte each, newest 5000 kept, so the file stays under about 2.5 MB; a cloud version would keep them in a database instead), and the Chronicle's text is for the human at the machine, so it may name numbers and labels. The F1 panel has Win game (every other wizard falls) and Lose game (the person falls), which end the match for real (`tests/debug_end_check.tscn -- mode=win|lose`).

**Eruption stress test (`tests/eruption_perf.tscn`, needs a window):** every volcano erupting over and over, the ash storm raining fire all the time, and all four wizards with every page together. `-- seed=5 seconds=60 [near=1] [calm=1]` prints frame rates and, twice, the per-frame cost of each kind of node. It found that every check for fire (`SpellTargets.fire_points`, asked by mud, thorns, plants, wizards and more, many times a frame) rebuilt a list with a point for each column of every lava pool, and each point cost a scan of the pool's grid: the cost grew with the lava, wherever the player was looking. A lava pool now keeps its heat points until its liquid changes (`Pond.heat_points`), and the list is kept for the frame.

**Eight wizards (`WorldGraph.PLAYERS`, read by `World.WIZARDS` and `Net.SEATS`):** the worlds are wider (`MatchState.STAGES`: 900, 660, 480 and 360 columns; the castle's share is 0.6), `SurfaceGen._starts` spreads the starts evenly over the free ground (never in a volcano's cone; three spots to a castle), and `Net.rival_palette` gives the brains beyond the fourth figure another set of colours. Checks that set a wizard down at the player's start and send a spell across the ground depend on what lies there: with the starts moved, `group_a_check` and `blizzard_freeze_check` use seed 3 (flat to the east), `raise_dead_check` lays a slab to walk to, and `ridge_check` picks a crest that no other ridge hides. `brains_start_check` skips a wizard that was beaten on the way.

## Lessons from the eight-wizard work (2026-11-06)
- A check that waits for a timer is slow to fail: give every wait its own short limit and print what it waited for (`net_match_check` took 20 minutes to fail, and about a minute to pass once the real cause was found: the winner's stats screen holds the ending until someone puts it away, and no one is there).
- With eight wizards, a world full of AI wizards roams and casts at whatever a check is testing: put the others away (`set_physics_process(false)` and move them to (-9000, -9000)), as `route_check` and `net_spells_check` now do.
- `net_hazard_check` needs a seed whose first world is a graveyard: seed 2 (the order of biomes follows the seed: `MatchState.biome_of(0)`; seed 1 became a portal world).
- A check must fail without the fix: `net_hazard_check` (a crypt guard struck on the host must fall on the client) and `canopy_check` were each run once without their fix to see them fail.
- `net_spells_check` still fails now and then under the load of the whole set (a stamina split measured on the client); it passes alone.

## Every check, and how to run it

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                          # after adding or changing any asset
"$GODOT" --headless --path . --quit-after 200                  # parse check: grep the output for "SCRIPT ERROR"
"$GODOT" --headless -s tests/test_gestures.gd                  # must print "784 of 784" (or more, if you add checks)
"$GODOT" --headless -s tests/test_pages.gd                     # the pages each wizard is dealt and a ledger's rules
"$GODOT" --headless --path . tests/intro_check.tscn            # the cut-scene (add `-- mode=skip`, or `-- out=DIR` for pictures, without --headless)
"$GODOT" --headless --path . tests/flow_check.tscn             # lab, portal, cut-scene, loading, world
"$GODOT" --headless -s tests/test_nav.gd -- seeds=6            # the wizards' map of the ways agrees with the generator's
"$GODOT" --headless -s tests/test_stages.gd -- seeds=6         # the smaller worlds a match collapses into: walkable, spread starts, every page placed
"$GODOT" --headless --fixed-fps 60 --path . tests/collapse_check.tscn  # a whole match through its collapses (time shortened)
"$GODOT" --headless --fixed-fps 60 --path . tests/gate_check.tscn -- seed=8 only=ice  # a wizard clears gates with spells (without only= it walks to them: minutes)
"$GODOT" --headless --fixed-fps 60 --path . tests/interaction_check.tscn  # spells that meet: water puts out fire, fire dries mud, lightning lights plants and shocks pools, a tornado over fire
"$GODOT" --headless --fixed-fps 60 --path . tests/follow_check.tscn -- seed=0  # piranhas, ice and a Geyser follow a pool's liquid as it flows
"$GODOT" --headless --fixed-fps 60 --path . tests/geyser_check.tscn  # a Geyser's and a Tide Surf's water is real liquid, not made over and over
"$GODOT" --headless --fixed-fps 60 --path . tests/wall_liquid_check.tscn  # a Stone Wall holds back poured lava like any ground, and the lava runs on when it is gone
"$GODOT" --path . tests/minimap_look.tscn -- seed=0 out=DIR  # how much of the minimap is ground (needs a window)
"$GODOT" --path . tests/water_look.tscn -- out=DIR             # pictures of a Geyser and a Tide Surf by the waiting-room pond (needs a window)
"$GODOT" --path . tests/bonfire_look.tscn -- out=DIR [seed=N]  # a picture of a Bonfire beside the wizard in the waiting room, or in the world of a seed (needs a window)
"$GODOT" --path . tests/marks_look.tscn -- out=DIR             # pictures of the Hex, Fight or Flight and Moonbeam marks (needs a window)
"$GODOT" --path . tests/minimap_check.tscn  # the minimap stays in the top right corner as the window is resized
"$GODOT" --headless --fixed-fps 60 --path . tests/ocean_world_check.tscn  # the sea over the world in lengths, wrecks with air pockets, driftwood and kelp, a wizard out of its depth swims and loses breath
"$GODOT" --path . tests/lab_lag_check.tscn [-- wait=S off=Class|autoload:Name|draw]  # every slow frame of the first seconds of the waiting room, with what was switched off (needs a window)
"$GODOT" --headless -s tools/bake_wand_cursor.gd  # remakes art/ui/wand_turns.png, every turn of the wand cursor, after the wand or its code changes
"$GODOT" --path . tests/ocean_look.tscn -- out=DIR  # pictures of the ocean from the player's own view: the raft, the surface over a wreck, the wrecks on the floor (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/sky_world_check.tscn  # everyone flies and drifts down, pages rise and come round from below, clouds rise, thunderclouds sting and strike, spells that need ground are refused
"$GODOT" --headless --fixed-fps 60 --path . tests/eruption_check.tscn -- seed=5  # an ashlands volcano erupts: a smoke plume, lava over the rim that cools and goes (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/stalagmite_check.tscn  # a Stalagmite rises from the ground under the tip of a drawn peak (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/sinkhole_biomes_check.tscn -- seeds=0,1,2,4,5,9,13  # a drawn U digs a pit of its shape in every kind of ground, the castle's slab floors too (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/ridge_check.tscn -- seed=4  # the snowy peaks' ridges: a wizard lands on one and S drops them through it (add `out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/tutorial_path_check.tscn  # the tutorial room is shut off place from place: the book starts empty and a page at each place gives its spell, the dummy and the skeleton (put down by a Faint) kill whoever passes them awake, turrets kill the unprotected, a cliff needs the double jump chant, thorns kill until burnt, a pit cannot be jumped
"$GODOT" --headless --fixed-fps 60 --path . tests/tutorial_ai_check.tscn -- seconds=1100 speed=4  # a general AI wizard plays the whole tutorial from an empty book to the exit with no deaths (slow, full set only; speed= runs physics faster)
"$GODOT" --headless --fixed-fps 60 --path . tests/tutorial_check.tscn  # the tutorial room's page at each place, and the library's counts (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/match_stats.tscn -- seed=3  # one whole match of AI wizards at real times: the pacing of each world, how often wizards are near each other, and whether the winner won by pages or by casting (takes minutes; run several seeds and compare the RESULT lines)
"$GODOT" --headless --fixed-fps 60 --path . tests/sinkhole_check.tscn  # a Sinkhole lowers the ground under it and leaves the ground beside it (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless -s tests/test_liquid.gd                      # the flowing liquid on its own: falls, levels, fills a pit, keeps its liquid, is quick
"$GODOT" --headless --fixed-fps 60 --path . tests/liquid_world_check.tscn -- seed=3  # a world's pools and a pit dug beside one (seeds 3, 5, 7, 12 have pools)
"$GODOT" --headless --fixed-fps 60 --path . tests/dark_check.tscn  # a wizard walks across a stretch of spike strips
"$GODOT" --headless --fixed-fps 60 --path . tests/spectate_check.tscn  # the player falls and watches a rival (add `-- collapse` to follow into the next world)
"$GODOT" --headless --fixed-fps 60 --path . tests/pull_check.tscn  # the portal tears open at the top and sucks the wizards in (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/spark_check.tscn  # Spark Strike lands on the ground under open sky
"$GODOT" --headless --fixed-fps 60 --path . tests/stairs_check.tscn  # a swinging stair is a one-way platform: a wizard stands on it and holding S drops them through
"$GODOT" --headless --fixed-fps 60 --path . tests/stairwell_check.tscn  # the castle has thirteen swinging stairs (`SwingStair`) in three stairwells, each swinging among landings on other floors; a wizard waits for one, crosses it and is carried (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/menu_check.tscn  # the first screen is the open spellbook: a sign drawn with the left button held chooses its inscription, and the page turns (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/settings_check.tscn  # the Settings page (`SettingsPanel`, kept by `GameSettings` in `user://options.cfg`): a cog sign on the first screen and a button on the pause screen open it; choices are kept, shake and cut-scenes obey them (add `-- out=DIR` for a picture, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/lab_revive_check.tscn  # whoever dies in the waiting room is on their feet at once
"$GODOT" --headless --fixed-fps 60 --path . tests/likeness_check.tscn  # the wizard maker: its words open it, and the page with them comes up before the magic mirror floating over the slab of the waiting room, a figure and colours chosen are worn and kept (`GameSettings` look and palette, `Net.look_of`/`palette_of`/`rival_look`), the four figures are one height (`WizardLook.SCALE`), a brain never wears a person's figure (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --path . tests/look_palettes.tscn -- out=DIR  # every figure in every set of colours, side by side (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/cluster_check.tscn  # each wizard starts with no spells and finds a cluster of pages by their spawn (`Pages.cluster_of`), in every biome
"$GODOT" --headless --fixed-fps 60 --path . tests/brains_start_check.tscn  # the AI wizards read their cluster
"$GODOT" --headless --fixed-fps 60 --path . tests/blizzard_freeze_check.tscn  # a Blizzard chills and then freezes whoever stays in it (add `-- out=DIR` for pictures, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/group_a_check.tscn  # Barbs, Pebble, Hailstorm and Featherfall
"$GODOT" --headless --fixed-fps 60 --path . tests/group_b_check.tscn  # Thorn Whip and Insect Plague
"$GODOT" --headless --fixed-fps 60 --path . tests/group_d_check.tscn  # Eldritch Blast, Hemorrhage, Supernova and Scythe, each cast in a world against a dummy
"$GODOT" --path . tests/attacks_look.tscn -- out=DIR  # pictures of those four (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/group_c_check.tscn  # Thunderclap (throws everyone near back but the caster, and dazes them) and Rocket Jump (the caster is thrown far up)
"$GODOT" --headless --fixed-fps 60 --path . tests/leech_check.tscn  # the tether, the split of a spell's cost and what breaks it
"$GODOT" --headless --fixed-fps 60 --path . tests/raise_dead_check.tscn  # a skeleton with a master: never touches them, fights a rival and a rival's skeleton, follows, falls with its master
"$GODOT" --headless --fixed-fps 60 --path . tests/mirage_check.tscn  # a false page that fades when anyone comes near, and a brain that learns
"$GODOT" --headless --fixed-fps 60 --path . tests/sphere_check.tscn  # the Flaming Sphere rolls, climbs a wall, falls into a pit and climbs out, burns, goes out (add `-- out=DIR`, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/eye_check.tscn  # the Chant of the Scrying Eye: a window bottom right, the eye over the watched wizard, the ground made round them (add `-- out=DIR`, needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/castle_spells_check.tscn  # the castle takes spells: a boulder rests on a swinging stair, a Stalagmite and a Sinkhole work on an upper floor
"$GODOT" --headless --fixed-fps 60 --path . tests/avalanche_check.tscn  # the peaks' avalanche rumbles, then runs down its slope and hurts whoever it runs over, once
"$GODOT" --headless --fixed-fps 60 --path . tests/pieces_check.tscn  # small pieces: a world's four words and its seed, the spell table and its buttons, and the colour of every school
"$GODOT" --headless --fixed-fps 60 --path . tests/ritual_check.tscn  # the chants: how accurately they must be said, and what each gives
"$GODOT" --headless --fixed-fps 60 --path . tests/library_screen_check.tscn  # the library's ledger, its face-down cards and its world filters, from a file of its own
"$GODOT" --headless --fixed-fps 60 --path . tests/castle_sinkhole_fall_check.tscn  # a wizard dropped into a castle pit sinks into it and stays, or falls through to the floor below
"$GODOT" --path . tests/castle_sinkhole_look.tscn -- out=DIR  # pictures of a Sinkhole dug in every kind of castle floor (needs a window)
"$GODOT" --headless --fixed-fps 60 --path . tests/biome_jump_check.tscn  # the F1 panel goes to a world of any biome, whatever the seed deals
"$GODOT" --headless --fixed-fps 60 --path . tests/parity_check.tscn  # Push, Geyser, Tornado, Tide Surf and a shot do the same to a person's wizard and the brain's
"$GODOT" --headless --fixed-fps 60 --path . tests/brain_spells_check.tscn  # the brain knows every spell: each is given alone to an AI wizard in the place it wants it, and cast (add `-- only=Hex,Sneak` for some)
"$GODOT" --path . tests/eclipse_check.tscn  # an Eclipse darkens the screen of the one inside it (add `-- out=DIR` for pictures)
"$GODOT" --headless --fixed-fps 60 --path . tests/knight_check.tscn  # a castle knight stands at its post until a wizard comes near, fights them, and walks back
"$GODOT" --headless --fixed-fps 60 --path . tests/sentinel_check.tscn  # a sentinel shoots a rival wizard in range, not one out of range
"$GODOT" --headless --fixed-fps 60 --path . tests/cross_check.tscn -- seed=4 kind=flood spells=Frost%Bridge  # a wizard crosses a gate with a spell (kind=chasm, flood, piranhas, sentinel, wall or gas; spells=chant:deep_breath for a chant; no spells= and it stays put)
"$GODOT" --headless --fixed-fps 60 --path . tests/route_check.tscn -- seed=3 moves=500  # every kind of move works in real physics (`trace=X,Y,TX,TY` follows one)
"$GODOT" --headless --fixed-fps 60 --path . tests/arena_sim.tscn -- seed=7 seconds=300 report=60  # AI wizards alone in a world: pages read, who is beaten, where they were held up
"$GODOT" --path . tests/showcase.tscn -- scenario=spells out=C:/some/dir          # a screenshot of every spell
"$GODOT" --path . tests/showcase.tscn -- scenario=spells only=Fire_Breath out=DIR # one spell, frame by frame
"$GODOT" --headless --path . tests/showcase.tscn -- scenario=soak out=DIR  # random play; look for errors
"$GODOT" --headless --path . tests/net_check.tscn -- role=host &  then  ... -- role=client  # two copies in a shared waiting room (no --fixed-fps!)
"$GODOT" --headless --path . tests/net_match_check.tscn -- role=host &  then  ... -- role=client  # two copies play a whole match (add `leave` to both)
"$GODOT" --headless --path . tests/dedicated_check.tscn  # starts a dedicated server (`-- --server`, see tools/run_server.bat) as a program of its own, joins it, plays into a world and leaves (no --fixed-fps). Add `--upnp` to the server (not in the test) to open its port on the home router and print the address to join at
```

- **All the checks at once:** `python tools/run_checks.py` runs the quick set (56 checks, about 55 seconds on six cores) and prints one line for each, ok or FAILED. `--full` adds the slow ones (108 checks, about 5 minutes): a whole generated world, the showcase's scenarios, longer route checks and the network checks, which start two or three copies of the game. A scene check also fails when it prints a `SCRIPT ERROR`. How it stays fast and steady: long checks are split into shards (`test_nav#1`, `brain_spells_check#2`...); the longest start first (times are kept in `times.json` in the output folder); the network checks run first, all together, each on a port of its own (`WIZARD_PORT`, read by `Net.port()`), with nothing else running, because they run in real time and give up when starved; the rest run below normal priority; a Godot crash while starting is started again and one while closing, after passes were printed, is not a failure; and a check that fails is run once more (a pass then is listed as FLAKY, and the first try is kept as `check_<name>_first_try.txt`). `-j N` sets how many run at once (default cores + 1); names on the end pick checks (`python tools/run_checks.py --full ritual`). A flaky check is a bug in the check or the game, not something to retry past: the ones found so far were a freed page tested with `is` in the brain (`_goal_lost`), a rival with every spell freezing the person in `raise_dead_check`, other wizards putting water in the ground `geyser_check` counted, and a route move that ended on a great tree's ledge. `brain_spells_check dice=N` rolls the dice differently to look for a roll that fails.
- **Coverage:** `python tools/run_checks.py --all --cov` runs the scene checks in a scratch copy of the game with `gd-tools` (see `tools/coverage_run.py` for the setup) counting the lines that ran, and prints the scripts that ran least. It takes ten minutes or more. `gd-tools` cannot read about twenty of the scripts (it names them), so they are left out of the figure; a check run with `-s` has no autoloads, so the gesture, page, navigation and stage checks are not counted either.
- **Other scenarios:** `world`, `kinds`, `ui` (portal, spellbook pages, pause, game over), `wizard` (a duel), `brawl`, and the other scenarios named at the top of `tests/showcase.gd`.
