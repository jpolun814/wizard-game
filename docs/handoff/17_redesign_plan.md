# 17. Redesign plan: the four big files

The game was grown one request at a time, and four files carry most of the weight of that. The owner asked (2026-11-13) for them to be restructured as if they had been planned
whole, with no change in behaviour. This chapter says what is wrong with each, the shape to aim for, and the order to work in. It is a plan, not a record: when a step is done, strike it
out here and say what changed in `02_codebase_map.md`.

## State of play (end of 2026-11-13)

Done, each with the quick set green and the full set showing only the known failures (`16_open_work.md`):

| File | Was | Now | What moved |
|---|---|---|---|
| `wizard_brain.gd` | 2,866 | about 2,150 | `BrainStrokes`, `BrainHand`, `BrainChant`, `BrainDanger`, `BrainSight`; `think` and `_travel` read as steps; `_pick_page` |
| `world.gd` | 1,775 | 755 | `WorldCreatures`, `WorldScenery` (one function per biome), `WorldPages`, `WorldGates`, `MatchEnd`, `WorldStages`; one black-cover helper in `Arena` |
| `wizard.gd` | 1,432 | 1,460 | no class moved: `_physics_process` is steps over `_tick_timers`, `_fall`, `_steer`, `_shoved`, `_move_on`; `_walking_speed()` |
| `caster.gd` | 1,218 | 1,241 | `_end` is `_read_special`, `_settle` and `_resolve` |

**Not done, and why.** These are the pieces where the move is not mechanical, because the code and its state are tangled; each needs a design first, not a cut:

- **The brain's `BrainExplore`, `BrainTravel`, `BrainGates`, `BrainCombat`, `BrainMend`.** They share fields that several of them write (`settle`, `_camped`, `_goal`, `_route`, `_skip`, `_bridged`, `_cannot`, `_pads`,
  `_pad_walk`), and three "manoeuvres" in progress (`_leap`, `_wade`, `_lift`) that each have their own function and are checked all over `think` and `_travel`. The way to cut this is to make each manoeuvre a
  small object (`Leap`, `Wade`, `Lift`) with `tick(delta) -> float` and `done()`, held in one `_manoeuvre` field, so that "is one in hand" is one test instead of three. After that `_cross` stops being a
  branch per gate kind: each kind (a Geyser wall, a chant at the edge of gas, Lily Pads) is a manoeuvre that starts itself. Check it with `cross_check` for every kind and `gate_check`. `cross_check` needs a
  seed that has the kind of gate (`NOTE seed N has no flood gate` is printed otherwise); the seeds in its header comment no longer have them, so find new ones first.
- **`SkyBrain`** still has its own copies of `think` and the goal choice. It uses the shared pieces now (`hand`, `chant`, `sight`, `danger`).
- **`WizardStatus` and movement modes in `Wizard`.** The timers (`slow_time`, `haste_time`, `root_time`, `shield_time` and the rest) are public fields that spells, the brain, the HUD and about thirty tests read and
  write by name. Moving them into a list means giving every reader the new name in the same change; do it one status at a time, starting with one that few things read (`fear_time`, `rage_time`).
- **`WorldSeats`.** Placing the wizards and giving them brains shares `seats` and `rivals` with `MatchEnd` and `WorldStages`; they are public on `World` now, so it can be cut when wanted.
- **The caster's detector table.** `_read_special` is still a list of `if` and `elif`; each detector could be an entry (`name`, `reads(relative, options)`, `fills(info)`) in a table that the order of the
  list gives.

**Watch the AI by eye before going further** (`tests/arena_sim.tscn -- seed=7 seconds=300 watch=1`, in a window). The checks prove the brain still casts, crosses and fights; only the owner can say it still looks like a person.

## What is already done

- Dead code, unused flags, old mobs, the learned AI, finished plans and stale comments are out (commits `a411d0b` to `3a86064`).
- `Arena` has a `class_name`, and `SpellSpawner` (`scripts/spells/spell_spawner.gd`) holds what each spell makes. `arena.gd` went from 1,349 to 836 lines. This is the pattern to repeat:
  a `RefCounted` class that is given its owner, keeps one job, and is reached through a public field (`arena.spawner`). The compiler finds every missed reference, so a step is quick to check.

- The brain's first five pieces are out (2026-11-13): `BrainStrokes` (the static helpers), `BrainHand` (strokes and casting), `BrainChant` (the chant box), `BrainDanger` and `BrainSight`. `wizard_brain.gd` went from 2,866 to
  about 2,150 lines. What is left of the table below is `BrainExplore`, `BrainTravel`, `BrainGates`, `BrainCombat` and what remains of `BrainMend` (`_mend`, the bonfire). They share
  state (`settle`, `_camped`, `_goal`, `_foe`) that has to be given a home before they move: each field goes to the piece that writes it, or to a small object that all are given.

- `World`: `WorldCreatures`, `WorldScenery`, `WorldPages`, `WorldGates`, `MatchEnd` and `WorldStages` are out (2026-11-13), and `_raise_biome_life` is one function per biome. `world.gd` is now about 840 lines (from 1,775). Left: `WorldSeats` (placing the wizards and giving them brains), which shares `seats` and `rivals` with the match end. The match's `@rpc` methods must stay on the `World` node (an RPC needs a node), as small stubs that call the piece.

- `Caster._end` is now four steps (2026-11-13): it reads the stroke, `_read_special` finds the shapes the recognizer cannot tell apart, `_settle` decides the flicks, crosses and flames, and `_resolve` casts or misfires. The detector chain is still an if/elif list inside `_read_special`; the table the plan asks for (a detector as an entry) is not done.
- `Wizard._physics_process` is now a few lines over `_tick_timers`, `_fall`, `_steer`, `_shoved` and `_move_on`, with `_walking_speed()` for the speed factors. The status list (`WizardStatus`) and movement modes are not done: the timers are public fields that spells, the brain and the tests read directly, so each would have to be moved with its readers.

## Ground rules for every step

- **Behaviour does not change.** A refactor that fixes a bug or adds a feature is two changes: make them apart.
- **One move at a time, then `python tools/run_checks.py`** (the quick set, 56 checks, about 100 seconds). Run the `--full` set after a whole file is done. Known failures are in
  `16_open_work.md`; a new one is a regression.
- **Public names, not reaching.** When a moved piece needs something from its owner, make that a public method of the owner (as `Arena.landing` and `Arena.ground_below` now are). Do
  not read another class's `_underscore` members.
- **State goes with the code that changes it.** A field moves with the functions that write it. If two pieces both write a field, it belongs in a third place that both are given.
- **Tests that reach into private members are tests to fix**, not reasons to keep a member private (the stalagmite and ridge checks did this).
- Python edit scripts go in the scratchpad; a regex that moves code must keep each file's line endings (some files are stored with CRLF: `git ls-files --eol`).

## `scripts/wizard_brain.gd` (2,866 lines, 138 functions, 93 variables, 103 constants)

**What is wrong.** One class holds every part of the AI's mind. Its own header says it works in four layers, but the code does not: the layers are not separate, and 354 lines
read `wizard.` directly. The big functions are the ones that grew a branch for every new situation: `_travel` (159 lines), `think` (158), `_attack_stroke` (99, a branch per
spell), `_cross` (98, a branch per kind of gate), `_choose_goal` (79). The constants of a dozen unrelated skills share one list at the top, and the variables of each skill
(`_typing`, `_camped`, `_settle`, the explore squares, the shot trackers) sit together with the rest. The functions call each other in every direction, so they cannot be moved to
other files unchanged: GDScript has no partial classes, and a base class cannot call a method that only a subclass has.

**The shape to aim for.** A small `WizardBrain` that owns the frame loop and the goal, and a handful of skills, each a `RefCounted` that is given the brain and keeps its own state:

| Skill | Takes from the current file |
|---|---|
| `BrainSight` | `_look_about`, `_note_sights`, `_notice_decoys`, `_nearest_foe`, `_seen_feet`, `_seen_center`, the shot trackers (`_incoming_shot`, `_track_shots`, `_watchers`), `_sight_is_limited` |
| `BrainExplore` | `_choose_goal`, `_choose_explore`, `_square_of`, `_through_known`, the page and portal goals, `_watch_progress`, `_stuck_on_goal` |
| `BrainTravel` | `_travel`, `_path`, `_raw_path`, `_way*`, `_swim*`, `_wading`, `_leaping`, `_lifting`, `_climb_oak`, the route and nav calls |
| `BrainGates` | `_cross`, `_choose_gate`, `_work_gate`, `_clear_gate`, `_gate_stroke`, `_crossing_ahead`, `_toll_between` |
| `BrainCombat` | `_attack`, `_assailed`, `_choose_defence`, `_choose_repel`, `_footwork`, `_safe_side`, the danger tests (`_lethal_at`, `_in_shoal`, `_scorched`, `_volcano_near`) |
| `BrainHand` | every stroke and its hand: `_attack_stroke`, `_surf_stroke`, `_breath_stroke`, `_push_stroke`, `_bridge_stroke`, `_tend_stroke`, `_begin_cast`, `_handed`, `_shaken`, `_drag_ok`, `_densify` and the line helpers |
| `BrainMend` | `_mend`, `_tend`, the chant typing (`_type_then_say`, `_open_chant`, `_break_typing`), the bonfire |

- `_attack_stroke` and `_cross` should stop being branches on a spell's name or a gate's kind: a spell (or a gate) knows how the AI casts it, in a table or on its own `Spell`
  resource, as `CLAUDE.md` section 9 already asks for the effects.
- The constants go with the skill that uses them. The magic numbers that are really a person's limits stay in `ai/human_limits.json`.
- `SkyBrain` (the same job in the sky) should use the same skills where they apply (sight, hand, mend) and not a second copy.
- Do the pure, state-free helpers first (the line and offset helpers, `_drift_table`, `_quickest_stroke`, `_densify`): they move as `static` functions and need no new fields.
- The safety net is wide: `brain_spells_check`, `brains_start_check`, `route_check`, `cross_check`, `gate_check`, `tutorial_ai_check` (fails already), `arena_sim`, and the sims in
  `CLAUDE.md` section 12. After the brain is touched, run all of them, and watch a sim by eye: the owner judges the AI by what looks like a person.

## `scripts/world.gd` (1,775 lines, 93 functions, 44 variables)

**What is wrong.** A `World` is a match's world, and the file does the work of seven things: it builds the map and the backdrop, dresses the biome (landmarks, graves, trees, the gale,
sky and sea), raises the creatures that roam (the dead, the knights, the giant) and shares them over the network, seats the wizards and gives them brains, runs the collapse into the
next world, keeps the gates and what crosses them, and ends the match (stats, the win screen, the epilogue). The fields tie them together: `_gale`, `_squall`, `_sea` and `_timed` are
set by the dressing and read by the frame loop; `_dead` and `_dead_sent` belong to the roaming creatures; `_seats` and `_markers` belong to the wizards. The biome dressing is one
135-line function (`_raise_biome_life`) with a branch per biome, and `_begin_encounter` (103) and `_build_map` (73) are long for the same reason.

**The shape to aim for.** `World` keeps the frame loop and the order of the match. Each of these is a class the world is given:

| Piece | What it holds |
|---|---|
| `WorldScenery` | `_lay_landmarks`, `_plant_graves`, `_grow_trees`, `_raise_the_gale`, `_raise_biome_life`, `_lay_sea`, `_raise_clouds`, `_wash_out_the_colour`, thorns and gas; and the fields it sets (the gale, the squall, the sea, the timed nodes). One function per biome, chosen by a table, not one function with a branch each. |
| `WorldCreatures` | the dead, the knights, the giant, the roamers, and `_share_the_dead` (the host's sharing); with the constants `DEAD_*`, `KNIGHT_*`, `GIANT_*` |
| `WorldSeats` | `_spawn_wizards`, `_places`, `_stand_at`, `_new_brain`, the roster, `_watch_falls`, spectating |
| `WorldStages` | `_begin_collapse`, `_collapse`, `go_to_stage`, `go_to_biome`, `_build_nav`, `_on_ground_dug` |
| `WorldGates` | `_watch_gates`, `_name_gates`, `closed_gates`, `crossings`, `gate_target`, `gate_kinds`, `open_gates`, `go_to_gate` |
| `WorldPages` | `_lay_pages`, `_lay_sky_pages`, `_lay_clusters`, `_cluster_spots`, `_drop_pages`, `_tell_pages_left` |
| `MatchEnd` | `_on_player_died`, `_record_match`, the stats screens, `_end_with_epilogue`, `_back_to_room`, `debug_win` and `debug_lose` |

- `WorldBuilder` (tiles) and `WorldGraph` (the plan) already exist and stay as they are.
- Several of these will want a small shared object for what they all read (the graph, the seed, the biome, the tile size). Make it one `WorldContext` rather than passing the world.
- The tests reach into `world._squall`, `world._seats` and a few more: give them public names when the piece moves.
- The safety net: `flow_check`, `collapse_check`, `cluster_check`, `brains_start_check`, `ocean_world_check`, `sky_world_check`, `test_stages`, `test_world` (fails on seeds 7, 15, 23 already),
  `eruption_check`, the showcase `life` scenario with a seed for each biome, `net_match_check`, and `dedicated_check`.

## `scripts/wizard.gd` (1,432 lines, 100 functions, 109 variables, 65 constants)

**What is wrong.** The body, every status that can happen to it, every way it moves, and the way it looks are in one class. The statuses are each a few fields, a timer and a branch in
`_physics_process` (127 lines): freeze, shield, obsidian, wild shape, sneak, surf, rocket, haste, adrenaline, daze, rage, silence, blind, the breath and drowning. The ways of moving
(walk, swim, fly, climb) are branches in the same function. Painting (`_animate`, `_dress`, `_draw`, the overlays) is mixed in with it. The header still says "the player's and the
three others'", which was true once.

**The shape to aim for.**

- **`WizardStatus`:** the timed effects, each one a small object with `tick`, `blocks_cast`, `speed_factor`, `damage_factor` and `ends`, held in one list, instead of one field and one `if` per effect. A new effect becomes one class, which
  is what `CLAUDE.md` section 9 asks of spells.
- **Movement modes:** walking, swimming, flying and climbing as separate small pieces chosen each frame, so `_physics_process` is a few lines that pick one.
- **`WizardLook`** (it exists for the figure) takes the animation and the overlays.
- `take_damage`, stamina and the wounds stay in `Wizard`: they are the body.
- The network sharing (`share`, `_tell_others`, `_follow`) is a separate concern too; see `11_network_play.md` before moving it.
- The safety net: `parity_check`, `limits_check`, `puppet_swing_check`, `likeness_check`, `lab_revive_check`, `dark_check`, every spell check (statuses are spell effects), `ocean_world_check`,
  `sky_world_check`, and the network checks.

## `scripts/gesture/caster.gd` (1,218 lines, 62 functions)

**What is wrong.** One function, `_end` (224 lines), turns a finished stroke into a spell: it tries each detector, applies the special cases (the flame that is read again without
flames, the Firewall's up-and-out, the sizes and costs, the targeting types), and hands the result on. Every spell that needed a special read added a branch to it.

**The shape to aim for.** `_end` as a short list of steps (read the stroke, resolve the spell, measure it, pay, hand it on), with each special read as an entry in the detector table
(`scripts/gesture/`) rather than a branch. The gesture code must stay free of the spells and of autoloads (it loads under `-s`; `CLAUDE.md` section 9). The safety net is `test_gestures` (784
checks), `pieces_check`, `ritual_check`, `group_*_check` and the brain's stroke checks.

## Order

1. The brain's pure helpers, then its skills one at a time, `BrainHand` first (most self-contained), `BrainTravel` and `BrainGates` last (most tangled).
2. `World`: `WorldScenery` and `WorldCreatures` first (the dressing and the dead share the most fields, so decide who owns them), `MatchEnd` and `WorldGates` next, the rest after.
3. `Wizard`: the status list first; movement modes after.
4. `Caster._end`.

After each file: update the map in `02_codebase_map.md`, the line counts above, and `CLAUDE.md` where it names a function that moved.

## Smaller things seen on the way (not part of the redesign)

- `scripts/wizard.gd`'s header says "the three others'": there are seven others in a match.
- `wizard_brain.gd`'s `_begin_cast` warns about a stroke with a point that is not a number; it is defensive code for a fault in the gesture code. Find the fault, then remove the guard.
- `intro.gd` is 762 lines for a cut-scene, and `library_screen.gd`, `menu.gd` and `stats_screen.gd` build their screens in code in long functions. They have not been looked at for structure.
