# Codebase map

Godot 4.7.2 and GDScript. The main scene is `scenes/menu.tscn`, the first screen (play alone, host, join), which leads to
`scenes/lab.tscn`, the waiting room. Its portal opens `scenes/world.tscn`, a generated world. Two autoloads: `Sfx` (`scripts/sfx.gd`)
and `Net` (`scripts/net.gd`, network play: see `11_network_play.md`).
The viewport is 1280x720, with stretch mode `canvas_items`.

## How a frame of the game fits together

```
Arena (scripts/arena.gd)            the base of the waiting room and the world: the player, spells, rituals, HUD
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

The player and walking mobs collide with mask 17 (terrain and platforms). Flyers have mask 0. The player and mobs
never block each other.

## Scripts

### Core flow
- **`arena.gd`:** builds the map (the waiting room and the world override `_build_map` and `_begin_encounter`), wires
  every signal, and routes spells: `spawn_spell` and `_place_shapes`. It also handles the wizard's casts
  (`cast_by`, one path for every wizard), rituals (`_on_ritual_finished`), death and restart, pause, debug summons and
  the Insight tooltip. `_is_ground_at` decides where a Stone Wall may start: the ground, a platform, or another
  stone wall.
- **`arena_gen.gd`:** chunk-based map generation and the `BIOMES` table (tiles, backdrop, props per level).

### Player
- **`wizard.gd`** (`class_name Wizard`, groups `"wizards"`, and `"player"` for the human only): movement (coyote time, jump buffer, variable jump height, S drop-through), stamina, HP,
  debuffs (mute, root, blind, slow), Barrier (a pixel bubble) and animation.
  - **Animations** (`ANIMATIONS`): idle, run, jump, fall, cast (staff held up while drawing), release
    (a thrust), hit, death.
  - **Frames** come from `art/chars/wizard`.
  - `mouth()` gives the Fire Breath origin.

### The waiting room
- **`lab.gd`** (`scenes/lab.tscn`, the waiting room the first screen leads to): extends `arena.gd` and overrides its `_where_are_we`,
  `_build_map` and `_begin_encounter`. A long map with a lava pit, a gap, a pond, a hill, dummies and a turret; infinite
  stamina, health that comes back, night on N, reset on R. Its portal starts a match in `scenes/world.tscn`; the worlds are described below.
  `tests/showcase.gd` with `scenario=spells` casts every spell here and photographs it.

### Casting
- **`gesture/caster.gd`:** hold buttons, record points, release, then `_end()`.
  - `_end()` runs the $1 recognizer restricted to the held buttons' templates, then the shape detectors (spiral,
    ring with a line, box, snowfall, funnel, cloud, crack, pit, cone, icicles).
  - It emits `cast_resolved(spell, targeting, origin, aim, info)`, or `misfired`.
  - `cast_stroke(mask, points)` lets the dark wizard and the tests cast without a mouse.
- **`gesture/gesture_templates.gd`:** the $1 templates, `ALIASES`, `preview_points(gesture)` (the spellbook
  picture, which is also the stroke the wizard draws), and `preview_ground`.
- **`gesture/unistroke_recognizer.gd`:** the $1 recognizer. `recognize(points, only)` limits it to the named
  templates.
- **`spell.gd` and `res://spells/*.tres`:** one `Spell` resource per fast spell (school, gesture, targeting, cost, draw, effect,
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
  - Its subclasses: `projectile.gd` (Ignite, Frostbolt), `firewall.gd`, `icicle.gd`, `blizzard.gd`,
    `push_zone.gd`, `gust.gd`, `stone_wall.gd`, `spark_strike.gd`. The arena picks one in `_new_effect`.
  - Standalone effects: `fire_breath.gd`, `tornado.gd`, `ice_prison.gd`, `abyss.gd`, `mudslide.gd`,
    `boulder.gd` (Stonefall's rock), `lava_ball.gd` (a volcano's shots; the ashlands' `Eruption` throws them), `earthquake.gd`, `smoke_screen.gd`, `flare.gd`,
    `frost_bridge.gd`, `geyser.gd`, `tsunami.gd`, `spore_puff.gd`, `eclipse.gd`, `hex.gd`, `decoy.gd`.
  - **Plants** extend `flora_spell.gd` (`FloraSpell`), which gives them fire damage: `bramble.gd`, `liana.gd`,
    `great_oak.gd`, `flytrap.gd`, `lily_pads.gd`. Fire touching one (`SpellTargets.fire_touching`) burns it away.
  - **Ponds** (`scripts/pond.gd`): water or lava sunk in the ground, which Frost Bridge freezes and Lily Pads float on. Drawn behind the ground so only the hollow shows; a water pond puts out fire shots (`shots` + `fires`) that fall in. Its liquid really flows (`scripts/liquid_grid.gd`, chapter 12): a pit dug beside it fills from it. Piranhas, ice and the wizards' map of the ways follow it, and Geyser and Tide Surf lift, carry and spill real water (chapter 12).
- **`spell_targets.gd`:** who can be hurt (`affects`, `hurt`, `all`, `hurt_within`; no sides), the ground (`ground_below`,
  `solid_below`, `surface_over`), fire (`fire_points`, `fire_heat_near`) and `shot_damage`.
- **Conventions:**
  - Every spell joins the `"danger"` group, and implements `danger_at(point)`, which the dark wizard
    uses to avoid hazards.
  - Spells find each other through groups, never by scanning the arena's children: `"fires"` (anything burning),
    `"clouds"` (blizzards, smoke and spores, which wind dissipates; each has `dissipate()` and `span()`),
    `"shots"` (enemy bolts, projectiles and lava balls), `"rocks"` (boulders), `"lasting"` (lasting effects), `"earthquakes"`, `"breakables"` (stone walls, boulders and trees: `take_blow_near(point, damage)`),
    `"sight_blockers"` and `"eclipses"` (see `SpellTargets.sight_blocked`), `"flora"`, `"climbables"` (Liana),
    `"ponds"`, `"decoys"`, `"hexes"`, `"flares"`, `"lily_pads"`.
  - Check what a node is with its class (`node is Projectile`), not by comparing spell names.

### Enemies
- **`mob.gd`:**
  - `Mob.KINDS` loads one `MobKind` resource per kind from `res://mobs/` (edit them in the inspector); each gives: role (melee, ranged, flyer, wizard), art, school, weak, resist, hp, damage, speed,
    effect and shot.
  - Creature frames are built by `CharFrames`. The shader `mob.gdshader` adds a slight school tint, a 1 px
    school-coloured outline, the hit flash and the frozen look.
  - Every attack is telegraphed: melee wind-up, shooter charge, flyer hover.
  - The dark wizard parts are `_build_wizard`, `start_drawing`, `interrupt_cast` and `mouth`.
- **`wizard_brain.gd`:** the dark wizard's AI (see `06_enemies_and_ai.md`).
- **Other enemy pieces:** `enemy_bolt.gd` (enemy shots, reflectable), `falling_shot.gd` (the fire caster's
  fireball, sometimes used by flyers), `hazard.gd` (burning ground where a volcano's lava lands).

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
- **`spellbook.gd`:** the pixel book (`art/ui/book.png`, 7 frames), `MouseIcon` and `Preview` drawn on the book's
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

The PvP match (see `docs/pvp_arena_design.md`) runs on these. `World` extends `Arena`, so the base code still applies.

- **Match:** `match_state.gd` (`MatchState`): the four worlds, their timers and seeds, and which biome each takes (`biome_of`, a shuffle of the biomes by the match's seed). `portal_collapse.gd` tears the portal open when a world gives way.
- **World:** `world.gd` builds each world, places the wizards, follows the one you watch, and watches the gates.
- **World generation:** `scripts/world/`. `world_graph.gd` (halls, tunnels, gates), `world_builder.gd` (carves rock, castle and gates; `make` builds a whole world and throws away one that is not `sound`), `surface_gen.gd` (the surface: one biome to a world; `BIOMES` lists them), `tile_grid.gd` (one byte per tile), `rock_world.gd` and `contour.gd` (chunked drawing and collision), `incantation.gd` (the seed words).
- **Walking:** `walkways.gd` (where a wizard can stand, and the moves between), `world_nav.gd` (path finder over those), `wizard_route.gd` (follows a path), `wizard_brain.gd` (what the AI wizard goes for, when it fights, what it casts).
- **Pages:** `pages.gd` (deals the starting pages and lays the rest), `ledger.gd` (one wizard's pages), `page_pickup.gd` (a page on the map).
- **Gates:** `ice_plug.gd`, `rock_wall.gd`, `spike_bed.gd`, `gas_bank.gd`, `piranhas.gd`, `sentinel.gd`, `rope_ladder.gd` (the jungle's vines now; the castle has stairs), `jungle_tree.gd`, `canopy_bridge.gd`, `critter_flock.gd`, `mist_bank.gd`, `light_shaft.gd`, `squall.gd`, `avalanche.gd`, `ice_sheet.gd`, `lava_surge.gd`, `ember_rain.gd`, `crypt.gd`, `cave_life.gd`, `falling_rock.gd` (the biomes' living scenery: see `World._raise_biome_life`), `mountain_gale.gd` and `snow_cloud.gd` (the snowy peaks' wind and drifting clouds).
- **Other:** `intro.gd` (the cut-scene), `weather.gd`.

## Tests (`tests/`)
- **`test_gestures.gd`:** every spellbook picture, at three sizes, shaky and mirrored, plus rotated cones.
- **`showcase.gd` / `showcase.tscn`:** scripted scenes that save screenshots. See `07_testing.md`.
