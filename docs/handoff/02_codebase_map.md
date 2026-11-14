# Codebase map

Godot 4.7.2 and GDScript. The main scene is `scenes/menu.tscn`, the first screen (play alone, host, join), which leads to
`scenes/lab.tscn`, the waiting room. Its portal opens `scenes/world.tscn`, a generated world. Two autoloads: `Sfx` (`scripts/core/sfx.gd`)
and `Net` (`scripts/core/net.gd`, network play: see `11_network_play.md`).
The viewport is 1280x720, with stretch mode `canvas_items`.

## Where the scripts live (`scripts/`)

`core/` (autoloads, spell and page data, the match's records), `wizard/` (the body and its pieces), `brain/` (the AI wizards), `arena/` (the arena, worlds, rituals, casting, the waiting room, the tutorial, portals),
`creatures/` (mobs and what they shoot), `scenery/` (living scenery and backdrops), `terrain/` (ground, pools, gates, bonfires, pages on the floor), `screens/` (menu, intro, library, spellbook and the other whole screens),
`ui/` (hud, camera, cursor, tooltips), `fx/` (effects and art helpers), plus `gesture/`, `spells/` (the effects) and `world/` (generation). Shaders sit beside the script that uses them.

## How a frame of the game fits together

```
Arena (scripts/arena/arena.gd)            the base of the waiting room and the world: the player, spells, rituals, HUD
 ├─ Backdrop                         parallax scenery (CanvasLayer -20 sky + Parallax2D layers)
 ├─ Terrain                          tiles, collision strips, props
 ├─ Player (scenes/wizard.tscn)      the human wizard: CharacterBody2D, origin at the feet; Camera2D (zoom 1.5) inside
 ├─ Caster                           reads mouse strokes and emits cast_resolved
 ├─ Wizards (scenes/wizard.tscn)     the three rivals: the same body, driven by a WizardBrain, each with its own Caster
 ├─ Mobs (scenes/mob.tscn)           enemies (no wizards)
 ├─ spell nodes                      SpellEffect, FireBreath, StormCloud... added as children of Arena
 ├─ Hud (CanvasLayer 3), Spellbook (5), RitualInput (10), DebugPanel (20), Minimap
```

There are no waves. The waiting room's portal loads a world from a seed (`World.next_seed`).


## World coordinates

- **Tiles:** `ArenaGen.TILE = 32` world px. `GROUND_ROW = 6`, so the ground surface is at **y = 192**.
  y grows downward.
- **Map size:** 12 chunks x 6 columns, columns -36..35, with stone side walls. `ArenaGen.left_edge()` and
  `right_edge()` give the walkable span.
- **Chunks:** `ArenaGen.CHUNKS`, 6 rows above the ground. The ground is smooth waves (`ArenaGen._ground_heights`,
  stored in `ArenaGen.column_heights`), and each chunk's structures stand on the rounded ground of their column. Use
  `ArenaGen.surface_y(cells, col)` for where ground is in a column; the flat `GROUND_Y` is only a fallback. The end
  chunks are always flat and open.
- **Origins:** characters have their origin at the feet. Use `center()` for aiming and distance checks.
- **Helpers:** `SpellTargets.ground_below(world, point)` hits ground or platforms; `solid_below` hits ground
  only.

## Physics layers

| Bit | Layer | Notes |
|---|---|---|
| 1 | terrain | stone walls, ice blocks, and every Area2D spell by default |
| 2 | mobs | |
| 4 | player | |
| 8 | mob_barrier | unused now (the old solid Firewall) |
| 16 | platforms | one-way |

The player and mobs collide with mask 17 (terrain and platforms). The player and mobs
never block each other.

## Scripts

### Core flow
- **`arena.gd`:** builds the map (the waiting room and the world override `_build_map` and `_begin_encounter`), wires
  every signal, and hands the rest to pieces it holds: `arena.casting` (`Casting`, `scripts/arena/casting.gd`: a read stroke, one path for every wizard, what refuses a cast, what it
  costs, the misfire and the flourish), `arena.spawner` (`SpellSpawner`, `scripts/spells/spell_spawner.gd`: what each spell conjures and where it lands, from four tables of
  recipes, `CasterSpells`, `AimedSpells`, `PlacedSpells` and `ShapeSpells`, each recipe given a `SpellCast`; a spell with no recipe is the simple effect its resource names),
  `arena.rituals` (`Rituals`, `scripts/arena/rituals.gd`: the chant box, what each chant does, the bonfire, the Rift, the Scrying Eye) and `arena.insight` (`InsightTip`: the
  hover tooltip). The arena itself keeps the rpc calls (`kindle`, `show_chant`, `show_eye`, `spawn_seen`), which must stay on the node. `_is_ground_at` decides where a
  Stone Wall may start: the ground, a platform, or another stone wall.
- **`arena_gen.gd`:** chunk-based map generation and the `BIOMES` table (tiles, backdrop, props per level).

### Player
- **`wizard.gd`** (`class_name Wizard`, groups `"wizards"`, and `"player"` for the human only): movement (coyote time, jump buffer, variable jump height, S drop-through), stamina, HP,
  debuffs (mute, root, blind, slow), Barrier (a pixel bubble) and animation. Pieces it holds, each reached by a field: `wizard.wolf` (`WildShape`: the werewolf and its claws),
  `wizard.pen` (`Pen`: the stroke a brain's wizard is drawing), `wizard.lungs` (`Lungs`: the breath, and the water or lava the wizard stands in), `wizard.pad` (`Pad`: what a
  brain asks of the body, or a person's keys, said the same way) and `wizard.vine` (`VineHold`: hanging on a Liana).
  - **Animations** (`ANIMATIONS`): idle, run, jump, fall, cast (staff held up while drawing), release
    (a thrust), hit, death.
  - **Frames** come from `art/chars/wizard`.
  - `mouth()` gives the Fire Breath origin.

### The waiting room
- **`lab.gd`** (`scenes/lab.tscn`, the waiting room the first screen leads to): extends `Arena` and overrides its `_where_are_we`,
  `_build_map` and `_begin_encounter`. A long map with a lava pit, a gap, a pond, a hill, dummies and a turret; infinite
  stamina, health that comes back, night on N, reset on R. Its portal starts a match in `scenes/world.tscn`; the worlds are described below.
  `tests/looks/showcase.gd` with `scenario=spells` casts every spell here and photographs it.

### Casting
- **`gesture/caster.gd`:** hold buttons, record points, release, then `_end()`; draws the trail.
  - `_end()` hands the stroke to `reader` (`StrokeReader`, `gesture/stroke_reader.gd`), which runs the $1 recognizer restricted to the held buttons' templates, asks every
    shape detector the buttons allow (`_detect`), claims the first that finds its shape in the order they rule each other out (`_read_shapes`), and settles what is left
    (`settle`: flicks, walls, a cross or a flame that is not one). The answer is a `StrokeReading` (gesture, score, `info`, the ring's split and centre).
  - `_resolve` turns the reading into a cast: it emits `cast_resolved(spell, targeting, origin, aim, info)`, or `misfired`.
  - `cast_stroke(mask, points)` lets the AI wizards and the tests cast without a mouse.
- **`gesture/stroke_shapes.gd`** (`StrokeShapes`) and **`stroke_measure.gd`** (`StrokeMeasure`): the detectors, all static and pure (points in, answer out): the named shapes (a ring
  with a line, a V, a coil, a feather, a cloud, a cross...) and the plain measures (extent, centroid, turning, crossings, `to_world`).
- **`gesture/gesture_templates.gd`:** the $1 templates, `ALIASES`, `preview_points(gesture)` (the spellbook
  picture, which is also the stroke the wizard draws), and `preview_ground`.
- **`gesture/unistroke_recognizer.gd`:** the $1 recognizer. `recognize(points, only)` limits it to the named
  templates.
- **`spell.gd` and `res://data/spells/*.tres`:** one `Spell` resource per fast spell (school, gesture, targeting, cost, draw, effect,
  damage line, the size that scales its cost, the effect script's path). Edit them in the inspector.
- **`spell_data.gd`:** loads those resources into `SPELLS` (name -> `Spell`), plus `SCHOOL_COLORS`, `SCHOOL_BUTTONS` and `bindings()`.
- **`status_effects.gd`:** the player's timed conditions, each a `Timer` node (`slow_time`, `haste_time`... are properties over it).
- **`scenes/hud.tscn`, `ui/theme.tres`, `hud_bar.gd`, `edge_arrows.gd`:** the HUD is a scene on a project-wide Theme.
- **`ritual_input.gd`:** the typed incantation box and `RITUALS`.
  - Accuracy uses edit distance.
  - An unfinished chant (a good match to the chant's start) fizzles harmlessly.
  - Below 0.6 accuracy a chant backfires (handled in the arena).

### Spells (`scripts/spells/`)
- **One script per effect.** Every spell's effect in the world is its own script; there is no shared script that
  branches on the spell's name.
  - `spell_effect.gd` (`SpellEffect`) is a small base for the simpler effects: it holds `spell`, `caster` and the
    life timer, and calls `_begin` (start), `_act` (each physics frame) and `_finish` (end) on its subclasses.
  - Its subclasses: `projectile.gd` (the base of every shot), `fireball.gd` (Ignite), `ice_spear.gd` (Frostbolt), `firewall.gd`, `icicle.gd`, `blizzard.gd`,
    `push_zone.gd`, `gust.gd`, `stone_wall.gd`, `spark_strike.gd`. The arena picks one in `_new_effect`.
  - Standalone effects: `fire_breath.gd`, `tornado.gd`, `ice_prison.gd`, `abyss.gd`, `mudslide.gd`,
    `boulder.gd` (Stonefall's rock), `lava_ball.gd` (a volcano's shots; the ashlands' `Eruption` throws them), `earthquake.gd`, `smoke_screen.gd`, `flare.gd`,
    `frost_bridge.gd`, `geyser.gd`, `tsunami.gd`, `spore_puff.gd`, `eclipse.gd`, `hex.gd`, `decoy.gd`.
  - **Plants** extend `flora_spell.gd` (`FloraSpell`), which gives them fire damage: `bramble.gd`, `liana.gd`,
    `great_oak.gd`, `flytrap.gd`, `lily_pads.gd`. Fire touching one (`SpellTargets.fire_touching`) burns it away.
  - **Ponds** (`scripts/terrain/pond.gd`): water or lava sunk in the ground, which Frost Bridge freezes and Lily Pads float on. Drawn behind the ground so only the hollow shows; a water pond puts out fire shots (`shots` + `fires`) that fall in. Its liquid really flows (`scripts/terrain/liquid_grid.gd`, chapter 12): a pit dug beside it fills from it. Piranhas, ice and the wizards' map of the ways follow it, and Geyser and Tide Surf lift, carry and spill real water (chapter 12).
- **`spell_targets.gd`:** who can be hurt (`affects`, `hurt`, `all`, `hurt_within`; no sides), the ground (`ground_below`,
  `solid_below`, `surface_over`), fire (`fire_points`, `fire_heat_near`) and `shot_damage`.
- **Conventions:**
  - Every spell joins the `"danger"` group, and implements `danger_at(point)`, which the AI wizards
    use to avoid hazards.
  - Spells find each other through groups, never by scanning the arena's children: `"fires"` (anything burning),
    `"clouds"` (blizzards, smoke and spores, which wind dissipates; each has `dissipate()` and `span()`),
    `"shots"` (enemy bolts, projectiles and lava balls), `"rocks"` (boulders), `"lasting"` (lasting effects), `"earthquakes"`, `"breakables"` (stone walls, boulders and trees: `take_blow_near(point, damage)`),
    `"sight_blockers"` and `"eclipses"` (see `SpellTargets.sight_blocked`), `"flora"`, `"climbables"` (Liana),
    `"ponds"`, `"decoys"`, `"hexes"`, `"flares"`, `"lily_pads"`.
  - Check what a node is with its class (`node is Projectile`), not by comparing spell names.

### Creatures
- **`mob.gd`:** (a giant's stomp is `mob.stomp`, `Stomp`)
  - `Mob.KINDS` loads one `MobKind` resource per kind from `res://data/mobs/` (edit them in the inspector); each gives: role (melee, ranged, wizard), art, school, weak, resist, hp, damage, speed,
    effect and shot. The kinds and where each lives are in `06_enemies_and_ai.md`.
  - Creature frames are built by `CharFrames`. The shader `mob.gdshader` adds a slight school tint, a 1 px
    school-coloured outline, the hit flash and the frozen look.
  - Every attack is telegraphed: a melee wind-up, a shooter's charge.
- **`world.gd`** is being split the same way: `world_creatures.gd` (`WorldCreatures`, `world.creatures`: the roaming dead, knights and giant, and the host's sharing of them) and `world_scenery.gd` (`WorldScenery`, `world.scenery`: landmarks, the biome's living scenery one function per biome, the sea, the clouds, thorns and gas; it holds the gale, the squall, the sea plan and the timed nodes). `world_pages.gd` (`WorldPages`, `world.pages`: where the pages lie, the clusters by the spawns, the sky's rising pages, a fallen wizard's book, the host's list of pages that still lie). `world_gates.gd` (`WorldGates`, `world.gate_work`; the list of gates is `world.gates`, and `World` keeps one-line `closed_gates()` and the like for the brains) and `match_end.gd` (`MatchEnd`, `world.match_end`: falling out and watching, winning, the stats, the epilogue). `world_stages.gd` (`WorldStages`, `world.stages`: the portal's warning, pull and collapse into the next world). The `@rpc` methods stay on `World` as stubs that call these.
- **`wizard_brain.gd`:** the AI wizards (see `06_enemies_and_ai.md`); `sky_brain.gd` in the sky.
  The brain is being split into skills, each a `RefCounted` given the brain and its wizard (`docs/handoff/17_redesign_plan.md`): `brain_hand.gd` (`BrainHand`: every stroke, how it is drawn and when; `brain.hand`), `brain_chant.gd` (`BrainChant`: the chant box; `brain.chant`), `brain_sight.gd` (`BrainSight`: what it knows of the others, the shadow it takes for a rival, the shots it sees coming; `brain.sight`), `brain_danger.gd` (`BrainDanger`: what can hurt it where it stands; `brain.danger`) `brain_travel.gd` (`BrainTravel`: choosing what to go for, the way there, swimming, the watchdog; `brain.travel`), `brain_combat.gd` (`BrainCombat`: attacks, footwork, answers to shots, the way up to a rival; `brain.combat`), `brain_mend.gd` (`BrainMend`: resting, camping at a bonfire, tending to its own needs; `brain.mend`), `brain_explore.gd` (`BrainExplore`: which squares it has been to and where it goes to look; `brain.explore`), `brain_gates.gd` (`BrainGates`: the ways over a crossing and the clearing of a gate; `brain.gates`), `brain_moves.gd` (`BrainMoves`: the leap, wade and lift in hand while it crosses something; `brain.moves`) and `brain_strokes.gd` (`BrainStrokes`: static shape helpers, the drift table and the quickest-stroke floor).
- **Other pieces:** `enemy_bolt.gd` (a turret's or sentinel's shot, reflectable), `hazard.gd` (burning ground where a volcano's lava lands).

### Visuals
- **`terrain.gd`:** the ground is one smooth surface: `_build_edges` takes the column tops, `_draw_ground` fills it
  with the biome's earth and a grass band, and `_build_collision` adds one sloped block per column. Stone, pillars
  and platforms are still drawn and collided cell by cell (`_piece_for`, merged strips, wooden planks).
- **`backdrop.gd`:** `PLACES`, the per-biome sky and Parallax2D layers. Vertical scroll is 1.
- **`pixel_fx.gd`:** `PixelFx.frames`, `sprite` and `play` for the strips in `art/fx`.
- **`char_frames.gd`:** builds a SpriteFrames from `<anim>_<n>.png` files, cached per folder.
- **`pixel_art.gd`:** **generated**; frame sizes and body boxes. Don't edit it by hand.
- **`fx.gd`:** Kenney soft particles (sparks, smoke, glows). Allowed as accents on top of pixel art.
- **Small helpers:** `shatter.gd` (pixel shards), `float_text.gd` (damage numbers), `game_camera.gd` (screen
  shake), `bonfire.gd`, `portal.gd`.
- **`hud.gd`:** the stamina bar, title, banner, portal arrow, pause and game-over screens. Uses the pixel
  fonts Jersey 15 and Jacquard 24.
- **`spellbook.gd`:** the pixel book (`art/ui/book.png`, 7 frames), `MouseIcon` and `StrokePreview` drawn on the book's
  pixel grid, and the pages.
- **Other UI:** `minimap.gd`, `debug_panel.gd`.

### Sound
- **`sfx.gd`:** `Sfx.play(name, at=null, volume_db, pitch_spread)`. Files named `name_1`, `name_2` and so on are
  random variants of `name`. The `VOLUME` table balances loudness.

## Tools (`tools/`)
- **`prepare_gothic_art.py`:** builds all the pixel art. See its docstring for the folders it expects.
- **`prepare_art.py`:** Kenney particles and most sounds.
- **`make_sounds.py`:** the layered spark, blink, push and fire_breath sounds.
- **`itch_download.py`:** fetches free itch.io pages.
- **`audio_profile.py`:** describes sounds in numbers.

## World, match and pages

The match (a last-wizard-standing race for pages) runs on these. `World` extends `Arena`, so the base code still applies.

- **Match:** `match_state.gd` (`MatchState`): the four worlds, their timers and seeds, and which biome each takes (`biome_of`, a shuffle of the biomes by the match's seed). `portal_collapse.gd` tears the portal open when a world gives way.
- **World:** `world.gd` builds each world, places the wizards, follows the one you watch, and watches the gates.
- **World generation:** `scripts/world/`. `world_graph.gd` (halls, tunnels, gates), `world_builder.gd` (carves the halls and tunnels and makes the gates, a function to each kind; `build` is `_plan_halls`, `_carve_halls`, `_raise_castles` and the gates),  `castle_builder.gd` (`CastleBuilder`: one castle, its walls, floors, stairwells and windows), `make` builds a whole world and throws away one that is not `sound`), `surface_gen.gd` (the surface: one biome to a world; `BIOMES` lists them), `tile_grid.gd` (one byte per tile), `rock_world.gd` and `contour.gd` (chunked drawing and collision), `incantation.gd` (the seed words).
- **Walking:** `walkways.gd` (where a wizard can stand, and the moves between), `world_nav.gd` (path finder over those), `wizard_route.gd` (follows a path), `wizard_brain.gd` (what the AI wizard goes for, when it fights, what it casts).
- **Pages:** `pages.gd` (deals the starting pages and lays the rest), `ledger.gd` (one wizard's pages), `page_pickup.gd` (a page on the map).
- **Gates:** `ice_plug.gd`, `rock_wall.gd`, `spike_bed.gd`, `gas_bank.gd`, `piranhas.gd`, `sentinel.gd`, `rope_ladder.gd` (the jungle's vines now; the castle has stairs), `jungle_tree.gd`, `canopy_bridge.gd`, `critter_flock.gd`, `mist_bank.gd`, `light_shaft.gd`, `squall.gd`, `avalanche.gd`, `ice_sheet.gd`, `lava_surge.gd`, `ember_rain.gd`, `crypt.gd`, `cave_life.gd`, `falling_rock.gd` (the biomes' living scenery: see `WorldScenery.raise_biome_life`), `mountain_gale.gd` and `snow_cloud.gd` (the snowy peaks' wind and drifting clouds), `wand_cursor.gd` (autoload: the mouse cursor is a CC-BY wand whose jewel takes the colour of the school being cast; it points as an ordinary cursor does on the first screen and while the game is paused; `Back` buttons have their own theme look in `ui/theme.tres`), `swing_stair.gd` (`SwingStair`: every stair of the castle is one: thirteen planks of brick in three stairwells, one in each room of the castle (shafts cut through the floors; only the middle room's goes down to the cellar), each hinged at a landing and swinging among landings on other floors after a stay that is a different length each time (the first is far more varied, so the stairs of a world do not set off together), swinging slowly and heavily, as stone does (no bounce), with an uneven underside; a one-way platform that carries whoever stands on it; its pose follows the seed and its own clock, so every machine agrees; the wizards' route waits at a landing until one joins it, then rides it; it has no sign or rune on it (the owner found a star senseless); see `WizardRoute._ride` and `CastleBuilder.WELL_WIDTH`; the castle's old fixed stairs are gone), `mountain_ridges.gd` (the peaks' second range: ridges standing behind the ground, their flanks climbing in runs of different steepness with treads between and a broken crest, as the ground in front is, one-way slopes like the castle's stairs, S on top drops to the ground; a Sinkhole drawn on a ridge's top sinks the ridge (`dig`, `top_at`, `holds`); the AI does not use them), `library.gd` and `library_screen.gd` (what this machine remembers of the matches played on it, with a button on the first screen: a shelf of cards a row for each school, face down until found, a star on a page that has won a match, and a plate at the top that counts them under the same star), `tutorial.gd` (the tutorial room, a `Lab` with a page for each school).
- **Other:** `intro.gd` (the cut-scene), `weather.gd`.

## Tests (`tests/`)
- **Three folders:** `checks/` holds every pass-or-fail check (`tools/run_checks.py` runs them), `looks/` the scripts that take pictures (they need a window) and `tools/` the simulations, the performance runs and the measuring scripts.
- **`test_gestures.gd`:** every spellbook picture, at three sizes, shaky and mirrored, plus rotated cones.
- **`showcase.gd` / `showcase.tscn`:** scripted scenes that save screenshots. See `07_testing.md`.


## Added with the later spells

- `scripts/spells/`: `barbs.gd`, `thorn.gd`, `pebble.gd`, `hailstorm.gd`, `hail_stone.gd`, `featherfall.gd`, `thorn_whip.gd`, `insect_plague.gd`, `leech.gd`, `mirage.gd`,
  `flaming_sphere.gd`. Raise Dead has no script of its own: `arena._raise_dead` makes a `Mob` (`Mob.master`, `_foe`, `_follow_master`, `_share_raised`).
- `scripts/ui/dowsing.gd` (was `scrying.gd`), `scripts/ui/scrying_eye.gd`, `scripts/wizard/eye_mark.gd`, `scripts/ui/circle_mask.gdshader`.
- Groups: `"leeches"`, `"squalls"` (`Squall.rain`), `"dowsings"`, `"eye_marks"`, `"ground_watchers"` (anything that keeps the ground near it made: a Flaming Sphere, the Scrying Eye's camera;
  read by `World._process`).
- `Wizard.feather_time`, `Pages.start_empty`/`cluster_of`, `WorldPages._lay_clusters`, `Library.title_of`/`average_accuracy`, `SpellData.school_name`.

## Added 2026-11-06
- `scripts/core/warmup.gd` (an autoload, `Warmup`): at start-up it loads the pictures and sounds that spells use on other threads (`ResourceLoader.load_threaded_request`), then the spell scripts one a frame on the main thread (never together: a script compiled while its pictures were being read on another core once failed to preload one). Without it the first cast of each spell stalled a frame or several.
- `Mob.shared`: a skeleton the world keeps in step across the network (a roamer or a crypt guard); only these tell the other machines when they fall.
- Group `canopy`: the ledges of a jungle great tree; sky spells (Spark, Boulder) pass through them (`tests/checks/canopy_check.tscn`).
- `GameSettings.rival_skill()`: the AI wizards' skill from the Settings page (0.4, 0.65, 0.85).
- `Pages.RANGED`: the attacks that reach across a distance; each wizard is dealt one as the starting attack.

## The ocean and the sky (chapter 13)
- `pond.gd` (`deep`, `SWIM_DEPTH`: the ocean's sea, laid by `WorldScenery.lay_sea` in lengths), `wreck.gd` (`Wreck`), `air_pocket.gd` (`AirPocket`: where the sea does not reach, group `air_pockets`), `kelp_patch.gd` (`KelpPatch`: slows, and hides from the brains' eyes through `sight_blockers`), `driftwood.gd` (`Driftwood`: a one-way platform at the waterline).
- `sky_cloud.gd` (`SkyCloud`: placed from the world's age; a thundercloud warns, then shocks and strikes), `falling_page.gd` (`FallingPage`, a `PagePickup` that rises through the sky and comes round again), `sky_brain.gd` (`SkyBrain`: the brain of a wizard that flies; made by `World.new_brain`).
- `spell_limits.gd` (`SpellLimits.refusal(wizard, spell)`: "No ground" in the sky for spells that need ground, "No need" for Updraft, Featherfall and Rocket Jump there, "Fizzles" for fire under water; `Casting._refusal` and the brain both ask it).
- `wizard.gd`: `swim_time`/`swim()`, `flying`/`fly_box`/`_fly`, constants `SWIM_*`, `FLY_*`. `arena.gd`: `flies()`, `fly_box()`, `_new_brain()` (World overrides them). `arena_gen.gd`: `air_rows` (the minimap's rows in the sky).
- `surface_gen.gd`: the `ocean` and `sky` biomes (`_sea_islands`, `_sea_of`, `_build_sky`, `SEA_*`, `SKY_*`); `match_state.gd` `LATER_BIOMES` deals them in after the first world.
