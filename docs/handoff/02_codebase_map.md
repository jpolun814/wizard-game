# Codebase map

Godot 4.7.2 and GDScript. The main scene is `scenes/arena.tscn`. One autoload: `Sfx` (`scripts/sfx.gd`).
The viewport is 1280x720, with stretch mode `canvas_items`.

## How a frame of the game fits together

```
Arena (scripts/arena.gd)            builds one wave's map and runs it
 ├─ Backdrop                         parallax scenery (CanvasLayer -20 sky + Parallax2D layers)
 ├─ Terrain                          tiles, collision strips, props
 ├─ Player (scenes/player.tscn)      CharacterBody2D, origin at the feet; Camera2D (zoom 1.5) inside
 ├─ Caster                           reads mouse strokes and emits cast_resolved
 ├─ Mobs (scenes/mob.tscn)           enemies, including dark wizards (each with its own Caster + WizardBrain)
 ├─ spell nodes                      SpellEffect, FireBreath, Volcano, StormCloud... added as children of Arena
 ├─ Hud (CanvasLayer 3), Spellbook (5), RitualInput (10), DebugPanel (20), Minimap
 └─ WaveDirector                     summons the wave's enemies, reports when cleared
```

Each wave gets a **fresh map**: the portal reloads the arena scene with `Levels.wave_index` advanced.
`Levels.held_focus` carries the wand or staff between maps.

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
- **`arena.gd`:** builds the level (biome from `Levels.place_of`), spawns the player and the other focus, wires
  every signal, and routes spells: `spawn_spell` and `_place_shapes`. It also handles the wizard's casts
  (`_on_wizard_cast`), rituals (`_on_ritual_finished`), the portal, death and restart, pause, debug summons and
  the Insight tooltip. `_is_ground_at` decides where a Stone Wall may start: the ground, a platform, or another
  stone wall.
- **`arena_gen.gd`:** chunk-based map generation and the `BIOMES` table (tiles, backdrop, props per level).
- **`levels.gd`:** `LEVELS`, each a biome and a list of waves (enemy kind to count). Level 1 is the cemetery
  (9 waves), level 2 the swamp (6), level 3 the church (4). A dark wizard ends each level.
- **`wave_director.gd`:** staggered spawns, `remaining()`, `is_cleared()`.

### Player
- **`player.gd`:** movement (coyote time, jump buffer, variable jump height, S drop-through), stamina, HP,
  debuffs (mute, root, blind, slow), Barrier (a pixel bubble) and animation.
  - **Animations** (`ANIMATIONS`): idle, run, jump, fall, cast (staff held up while drawing), release
    (a thrust), hit, death.
  - **Frames** come from `art/chars/wizard` or `wizard_wand`, swapped by `focus` in `_dress_for_focus`.
  - `mouth()` gives the Fire Breath origin.
- **`focus_item.gd`:** a wand or staff lying on the ground. `FOCI[...]["tolerance"]` is the recognizer
  threshold: 0.70 for the wand, 0.90 for the staff.

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
- **`spell_data.gd`:** the `SPELLS` table (buttons, gesture, targeting, cost, school, draw, effect), `DAMAGE`
  (the spellbook stats line), `SCHOOL_COLORS`, and `cost_for` (size-scaled costs).
- **`ritual_input.gd`:** the typed incantation box and `RITUALS`.
  - Accuracy uses edit distance.
  - An unfinished chant (a good match to the chant's start) fizzles harmlessly.
  - Below 0.6 accuracy a chant backfires (handled in the arena).

### Spells (`scripts/spells/`)
- **`spell_effect.gd`:** the multi-purpose Area2D for Ignite, Frostbolt, Icicles, Snowfall, Firewall, Push,
  Stone Wall, Force Wall, Stonefall and Spark. `setup()` branches by spell, and so do `_physics_process` and
  `_draw`. Images drawn every frame are `preload` constants.
- **One file per newer spell:** `fire_breath.gd`, `volcano.gd`, `tornado.gd`, `ice_prison.gd`,
  `gravity_well.gd`, `storm_cloud.gd`, `quicksand.gd`.
- **`spell_targets.gd`:** team logic, `affects`, `hurt`, `all`, `hurt_within`, `ground_below` and `solid_below`.
- **Conventions:** every spell has `team`, joins the `"danger"` group, and implements `danger_at(point)`, which
  the dark wizard uses to avoid hazards.

### Enemies
- **`mob.gd`:**
  - `KINDS` gives each kind: role (melee, ranged, flyer, wizard), art, school, weak, resist, hp, damage, speed,
    effect and shot.
  - Creature frames are built by `CharFrames`. The shader `mob.gdshader` adds a slight school tint, a 1 px
    school-coloured outline, the hit flash and the frozen look.
  - Every attack is telegraphed: melee wind-up, shooter charge, flyer hover.
  - The dark wizard parts are `_build_wizard`, `start_drawing`, `interrupt_cast`, `blink_to` and `mouth`.
- **`wizard_brain.gd`:** the dark wizard's AI (see `06_enemies_and_ai.md`).
- **Other enemy pieces:** `enemy_bolt.gd` (enemy shots, reflectable), `falling_shot.gd` (the fire caster's
  fireball, sometimes used by flyers), `hazard.gd` (fire and frost ground patches).

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
- **`hud.gd`:** bars, wave labels, banner, boss bar, portal arrow, pause and game-over screens. Uses the pixel
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

## Tests (`tests/`)
- **`test_gestures.gd`:** every spellbook picture, at three sizes, shaky and mirrored, plus rotated cones.
- **`showcase.gd` / `showcase.tscn`:** scripted scenes that save screenshots. See `07_testing.md`.
