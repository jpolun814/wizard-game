# HANDOFF: read this before you touch anything

This is the guide for any AI model picking up this game. It tells you what the game is, what the owner wants, how
the code fits together, and the mistakes that have already been made, so you don't make them again.
`docs/original_vision.md` is the first design document. It is older than the game: use it for intent, but
trust the code and this file where they disagree.

**Read this file first, then the chapter for the job in hand** (`docs/handoff/`):

| Chapter | Read it before you... |
|---|---|
| `01_feedback_log.md` | do anything at all: every request the owner made, quoted, and the lesson behind it |
| `02_codebase_map.md` | change code: every script, the scene tree, coordinates, physics layers |
| `03_gestures_and_spell_design.md` | add or change a spell or gesture: how recognition works, design rules, school identities, vetted ideas |
| `04_art_and_assets.md` | add or change anything visible: style rules, every source, how to judge and process an asset |
| `05_audio.md` | touch sound: sources, layering, choosing sounds you can't hear |
| `06_enemies_and_ai.md` | touch enemies or the dark wizard |
| `07_testing.md` | say anything is done |
| `08_working_with_the_owner.md` | reply to the owner |
| `09_godot_pitfalls.md` | debug something strange |

---

## 1. What the game is

A 2D side-view arena roguelite built in Godot 4.7.2 and GDScript. You are a wizard, and you cast spells by
**actually doing magic**:

- **Fast spells:** hold a school's mouse button(s) and draw a shape. The shape is read by a $1 recognizer
  plus hand-written shape detectors.
- **Rituals:** press Enter and type a pseudo-Latin chant. Typing accuracy sets the ritual's power.

A roguelite: you explore a big generated world for spellbook pages, then duel the **dark wizard** at the end, who casts the same
spells you do, drawing them visibly. There are no waves.

**The owner's taste, in their words:**
- "sick as hell"
- "not a fan of the cartoony style"
- "that dark wizard was a lot of fun"

**The look:** dark gothic pixel art.
- **Levels:**
  - Level 1: a blood-moon cemetery.
  - Level 2: a haunted swamp.
  - Level 3: a gothic cathedral interior.
- **Characters and art:** LuizMelo characters, Ansimuz GothicVania environments, and CC0 pixel effects.

## 2. The eleven rules that matter most

1. **Spells must reflect something real, and must be counterable.** Fire Nova (a magic ring blast) was removed
   because it "doesn't seem to reflect anything in real life and is impossible to block."
   - Every spell needs a real-world analogue: a flamethrower, a lightning strike, quicksand, a boulder.
   - Every spell needs a counterplay: block it, dodge it, or take cover.
   - Ground, stone walls, ice and platforms block things physically.
2. **The gesture is a picture of the effect.**
   - Volcano is a mountain triangle. Fire Breath is a cone (`<`). Mudslide is a U (the pit of mud).
   - Storm Cloud is a bumpy cloud top. Gravity Well is an inward spiral.
   - Icicles are V shapes. Push is a circle (the area) plus a line out of it (the direction).
   - Never assign an arbitrary shape.
3. **No code-drawn pictures.** "All the other code-drawn pictures stick out like sore thumbs; they absolutely
   have to be replaced."
   - Everything in the world must be real pixel art from free assets.
   - The only exceptions are interface elements: health bars, the gesture trail, shadows, and pixel snowflakes
     or shards made of pixel squares.
   - Before adding `draw_circle`, `draw_line` or `draw_polygon` for a world object, look for an asset first.
4. **Pixel art at one consistent pixel size.**
   - 1 art pixel equals 1 world pixel. Camera zoom is 1.5. The texture filter is "Nearest Mipmap" (project setting `2`).
   - Only whole-number scales: 2x for the lightning, the tornado and the swamp/cathedral backdrops; 1x for characters.
   - Never use 0.6x, 1.5x or similar on pixel art.
   - Tiles are 16 px art composed 2x2 into 32 px world cells.
5. **Don't make things solid or harmful unless the spell's real-world analogue would be.**
   - Firewall: anyone can pass through it ("I wanted the fire wall to be something anyone could pass
	 through").
   - Force Wall: only touches projectiles.
   - Gravity Well: does no damage.
   - Storm Cloud: hits everyone under it, including the caster.
   - Lightning: cannot pass through platforms.
   - Stonefall: does not explode; it thuds.
6. **Consistency within a role.** All melee enemies look the same (skeletons). The owner disliked the earth
   melee enemy looking different. Schools are shown by a coloured outline and tint, not by different creatures.
7. **Never commit, push or delete the owner's files without being asked.**
   - The working tree carries a very large uncommitted diff, all intentional. Never run `git checkout .`,
     `git reset --hard` or `git clean`.
   - `art_source/enemies/` and `art/wizard_parts/` are the owner's original art, now unused. Keep them.
8. **Test before you claim.**
   - Run `tests/test_gestures.gd` and the showcase screenshots, and actually look at the screenshots.
   - Tell the owner what you could not verify (you cannot hear sounds or feel the controls).
9. **Keep text short in game.** The owner disliked wordy spellbook entries, repeated "costs no stamina",
   explaining edge cases, and filler headings like "Incantations, continued."
10. **Talk to the player, not about the game.** On-screen text is imperative and addressed to the player ("Press Tab to
	open the spellbook", "Gives you endless stamina"), not a statement about the system ("Tab opens the spellbook"). A key
	and action table may use short verb-first labels. No ALL-CAPS result lines ("The ritual backfired", not "RITUAL BACKFIRED").
    **Spellbook entries** follow nine more rules (owner-confirmed):
	1. Start with a verb addressed to the player ("Hurl a bolt of fire").
    2. Say only what the spell does. Never name what counters it, what it combines with, or how to avoid it: the player learns those.
	3. Never mention self-harm ("you too"); it is implied.
	4. Never mention cost scaling or size ("a longer cone costs more").
	5. Write as a wizard inside the universe. No game-loop or meta words: wave, level, run, walkers, "to draw attacks", "as long as your stroke".
    6. Never mention interface actions such as double-clicking.
	7. Be accurate, and say "anyone" or "everything" where a spell has no teams.
    8. Keep it short; numbers only for damage and duration.
    9. Never describe the stroke: the animation shows it.
11. **Don't change what they didn't ask about.** When feedback names five things, fix those five, check
    nothing else broke, and report briefly.

## 3. Run, test and look

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --import                          # after adding or changing any asset
"$GODOT" --headless --path . --quit-after 200                  # parse check: grep the output for "SCRIPT ERROR"
"$GODOT" --headless -s tests/test_gestures.gd                  # must print "136 of 136" (or more, if you add checks)
"$GODOT" --path . tests/showcase.tscn -- scenario=spells out=C:/some/dir          # a screenshot of every spell
"$GODOT" --path . tests/showcase.tscn -- scenario=spells only=Fire_Breath out=DIR # one spell, frame by frame
"$GODOT" --headless --path . tests/showcase.tscn -- scenario=soak out=DIR  # random play; look for errors
```

- **Other scenarios:** `world`, `kinds`, `ui` (portal, spellbook pages, pause, game over), `wizard` (a dark-wizard
  duel) and `brawl`.
- **Screenshots need a window:** don't pass `--headless` for them.
- **Looking at screenshots:**
  - Open the PNGs with your image-reading tool.
  - To compare many, paste crops into one contact sheet with PIL.
  - Crop lower than you think: ground-level effects sit near the bottom.
- **Scripts run with `-s` cannot see autoloads (`Sfx`).** Anything that needs the game must run as a scene, which
  is why the showcase is a scene.
- **Python:** use `python -I` for anything that reads downloaded files. Install packages with
  `pip install --isolated --index-url https://pypi.org/simple <pkg>`.
- **Shell quirk:** in this environment, long bash heredocs containing apostrophes sometimes fail to parse. Write
  the Python edit script to a file in the scratchpad and run that.

## 4. Controls

| Key or button | Action |
|---|---|
| A / D | Move |
| W or Space | Jump |
| S | Drop through a wooden platform |
| Left mouse | Fire school |
| Right mouse | Water school |
| Middle mouse | Air school |
| Left + Right | Earth school |
| Left + Middle | Flora school |
| Right + Middle | Shadow school |
| W at a vine | Take hold of a Liana; W and S climb, Space or a sideways key lets go |
| N / R (waiting room) | Night on and off / reset the room |
| Tab | Spellbook (arrow keys turn pages) |
| Enter | Incantation box |
| E | Swap focus (wand or staff) |
| M | Mute |
| Esc | Pause and controls list |
| F1 | Debug summon panel |
| R | New run, on the game-over screen |

## 5. Spells (the `Spell` resources in `res://spells/` are the single source of truth)

| School | Spell | Shape | Real thing | Counterplay |
|---|---|---|---|---|
| Fire | Ignite | straight flick | thrown fireball | dodge, Gust, walls |
| Fire | Firewall | vertical line | burning brush line | it's passable and only burns; walk out of it |
| Fire | Fire Breath | cone `<` | flamethrower from the mouth (follows facing, rises on a jump) | cover, Barrier, distance |
| Fire | Smoke Screen | wavy line going up | a bank of smoke enemies cannot see through | wind (Tornado, Gust), Tsunami |
| Fire | Flare | flame: a loop with its point up | a small harmless flame that follows you and lights the dark | it burns out |
| Fire | Spark | tall zigzag | a lightning strike from the sky; stops at the first platform or ground | shelter under a platform |
| Water | Frostbolt | flick | thrown ice spear | as Ignite |
| Water | Icicles | one or more Vs in a row, under a ceiling | icicles hanging from the ceiling | step around |
| Water | Ice Prison | circle | freezing whoever is inside solid | Push or Earth shatter; Barrier |
| Water | Blizzard | star then a level line | snow cloud | leave the area |
| Water | Frost Bridge | wavy line across water | freezing a pond so you can cross | fire melts it |
| Water | Geyser | mountain: a triangle with a line up its middle (as Volcano) | a jet of water that throws what stands on it | step off while it bubbles |
| Air | Push | circle then a line out | a shove of air; the only spell that lifts you | positioning |
| Air | Barrier | circle | a shield bubble | wait it out |
| Air | Tornado | tall narrow coil going down | a whirlwind | avoid it |
| Air | Gust | straight flick | wind along the stroke: turns shots, sweeps flyers, smoke and you sideways | heavy foes resist |
| Earth | Stonefall | circle with a line down | a dropped boulder | watch the shadow |
| Earth | Stone Wall | line starting on the ground, a platform or another stone wall | a raised slab | Earthquake, Stonefall, shots wear it down |
| Earth | Mudslide | U | a pit of mud: slows, no jumping; flyers pass over | walk out |
| Earth | Earthquake | three peaks | the ground shakes | flyers unaffected |
| Earth | Volcano | triangle mountain | eruption | stay out of the arc |
| Flora | Bramble | low sawtooth | a thicket of thorns: slows and pricks | jump it; fire |
| Flora | Spore Puff | cone `<` (as Fire Breath) | poison spores poured from your mouth | wind, water |
| Flora | Liana | leaf and line: an almond on its point, then a line up | a vine to climb | fire |
| Flora | Great Oak | trunk drawn up into a round crown | a tree: ledges and a wall, and when it falls it crushes | fire, Earthquake, Stonefall; it creaks first |
| Flora | Flytrap | tall narrow W | a trap that snaps shut on whoever steps in | jump, fire |
| Flora | Lily Pads | chain of low loops | floating leaves to cross water or a pit | fire; they sink after 8 s |
| Shadow | Decoy | figure of eight | a shadow that draws enemies' attacks | it wears out |
| Shadow | Eclipse | crescent | darkness: enemies inside see only what is close | Flare |
| Shadow | Hex | pentagram (five-point star, one stroke) | a curse: 50% more damage | short time |
| Shadow | Abyss | inward spiral | a dark knot that pulls everything in | walk out |
| Shadow | Shadow Step | flick | slipping along the stroke | |

The school and spell plan, and the roguelite loop these are for, is in `docs/roguelite_exploration_design.md` and
`docs/spell_pool.md`. The waiting room (`scenes/lab.tscn`, `scripts/lab.gd`) is where every spell is tried; the portal there
starts a run.

**Targeting types:** `directional`, `positional`, `angled`, `shape` and `cone`. The caster's `cast_resolved`
signal passes `info` (radius, line, rect, shapes, aim, spread, reach), and `arena.spawn_spell` routes it.
**No sides:** once a spell is cast it has no team. It hurts whoever it touches: enemies, the player, the dark
wizard, and the caster and its allies too (friendly fire). The one exception is a shot (Ignite, Frostbolt, an enemy's
bolt): it can't hit whoever fired it while it is still inside that body. Once it has flown clear, it can hit them, so
it hits them if it comes back. Blink and Fire Breath start on the caster's body, so the caster is passed by there as
well. `scripts/spells/spell_targets.gd` decides who can be hurt.

## 6. Designing a new spell: checklist

1. **Name the real-world thing.** If you can't, stop.
2. **Pick the school by what it is:**
   - Fire: heat, burning, lightning, light and smoke.
   - Water: cold, slowing, freezing, solid ice, dousing, floods.
   - Air: pushing, deflecting, shields and wind.
   - Earth: stone, ground, sand, weight.
   - Flora: plants: things that grow, hold and trap, and all burn.
   - Shadow: sight, decoys, curses and gravity.
3. **Draw what it looks like.** The stroke should be the thing's silhouette or its motion.
4. **Make sure the shape is distinguishable from every other shape on the same button(s).** The recognizer
   only compares within the held button combination. Add a test case to `tests/test_gestures.gd` and add the
   preview to `GestureTemplates.preview_points`. The dark wizard draws from those previews too.
5. **Physics honesty:** what blocks it, who it hurts (the caster too?), and whether it goes through platforms.
6. **Telegraph:** the enemy or player must see it coming. Examples: Stonefall's shadow, the falling-shot ring,
   the cloud's flicker.
7. **Art from a free pack,** recoloured to the school's colour in `tools/prepare_gothic_art.py`.
8. **A sound,** chosen with `tools/audio_profile.py` or mixed in `tools/make_sounds.py`. Say plainly that you
   couldn't listen to it.
9. **Teach the dark wizard to use it** (`scripts/wizard_brain.gd`): a score in `_attack` and a stroke in
   `_attack_stroke`.
10. **Spellbook:** the stats line comes from `SpellData.DAMAGE`. Keep it short.

## 7. Art: where it comes from and how it's built

- **The pipeline:** `tools/prepare_gothic_art.py <downloads dir>`. It builds `art/chars`, `art/mobs`,
  `art/tiles`, `art/props`, `art/backgrounds`, `art/fx`, `art/ui`, and generates `scripts/pixel_art.gd`
  (frame sizes and body boxes).
- **Folder names** the script expects are listed in its docstring.
- **Downloads are not kept in the repo.** Re-download them into a scratch folder.
- **Credits:** every source and licence is in `art/CREDITS.md`. Add a line for anything new.
- **Licences (owner decision, 2026-10-25):** CC0 and CC-BY are both fine, for everything. CC-BY needs a credit line in
  `art/CREDITS.md` (name the author and link the pack). Prefer CC0 when two assets fit equally. Still skip CC-BY-SA,
  GPL, "personal use only" and paid packs unless told otherwise.
- **Good sources:**
  - kenney.nl: everything is CC0. Its "Tiny Dungeon" and "1-Bit" packs suit the style.
  - opengameart.org: check the licence badge on each page.
  - itch.io: LuizMelo, Ansimuz and CodeManu have CC0 packs. Check the page's licence field.
    `tools/itch_download.py` fetches free pages.
- **Judging an asset:**
  - It must be dark, gothic and pixel art, at roughly the same pixel density as the characters.
  - No cartoon, vector or painterly art.
  - Look at it (make a contact sheet) before using it.
  - Check whether an "effect" sheet secretly contains a character. The GothicVania "fire-sprites" were a
    fire-casting wizard, not fire.
- **Recolouring:** `recolour()` does a hue turn or a dark-to-light ramp, and `key_out()` removes a flat
  background colour.
- **Character frames** are cut so the feet sit on the bottom edge and the body is centred, so flipping a frame
  never shifts the character.
- **The wand:** the wizard art only has a staff. `wandify()` cuts the staff down to a wand in every frame,
  creating `art/chars/wizard_wand`.

## 8. Godot pitfalls that already bit

- **Never `load()` a texture inside `_draw()` into a local variable.** It gets freed before rendering and draws
  as a **white rectangle**. Use `preload()` constants or a cache.
- **`var x := dict["k"]` fails to parse** ("Cannot infer type"). Give it an explicit type.
- **`Parallax2D` vertical scroll:** use `scroll_scale.y = 1`, or layers drift off the ground line.
- **Raycasts and one-way platforms:** cast from above, downward, when testing "is it covered".
- **numpy on Windows:** `np.arange` is int32. Multiplying by a sample rate overflowed; use `dtype=float64`.
- **Label wrapping:** a Label with autowrap has zero minimum width inside an HBox, and its text collapses. Turn
  autowrap off for short labels.
- **CanvasLayer order:** sky -20, HUD 3, spellbook 5, ritual box 10, debug panel 20.
- **Physics layers:**
  - 1: terrain, stone walls, ice blocks, and spell areas by default.
  - 2: mobs.
  - 4: player.
  - 16: one-way platforms.
  - Player and walking-mob masks are 17. Flyers have mask 0.

## 9. Code style and structure

This code was grown one request at a time, which turns code into spaghetti unless each change keeps the shape
clean. It was cleaned up once, without losing any behaviour. Keep it that way:

- **Comments:** plain English `##` doc comments that say *why*, written like the existing ones. No jargon.
- **Names:** descriptive, and named after what the thing is *now*. When a feature changes, rename it (Quicksand
  became `Mudslide`; the fire walker's effect became `"burning"` when it stopped leaving a trail).
- **One script per spell effect.** Never add a branch on the spell's name (`if spell == "..."`) to a shared
  script. Simple effects extend `SpellEffect` (`scripts/spells/spell_effect.gd`) and fill in `_begin`, `_act`
  and `_finish`; bigger ones are their own Node. Add the new class to `arena._new_effect` or `spawn_spell`.
  A new `class_name` is only registered after `godot --import`.
- **Every spell** joins the `"danger"` group, and implements `danger_at(point)` (the dark wizard avoids danger,
  its own spells included, since they hurt it too).
- **Find nodes through groups, not by scanning the tree.** `"fires"`, `"clouds"`, `"shots"`, `"rocks"`,
  `"lasting"`, `"earthquakes"`, `"danger"`, `"mobs"` (full list in `02_codebase_map.md`). Anything new that
  burns joins `"fires"` and is then melted, lit and avoided by everything else for free.
- **Check types with the class** (`node is Projectile`, `area is EnemyBolt`), not with spell-name strings.
- **Ask the object, don't reach into it.** Never read another script's `_underscore` variable or call its
  `_method`. Make it public (`facing`, `damage`, `earth_texture`) or add a small method (`is_slowed()`,
  `span()`, `dissipate()`, `velocity()`). No static flags for world state: `Earthquake.is_shaking(tree)` asks
  the group instead.
- **One helper, not copies.** Shared logic lives in one place: `SpellTargets` (who can be hurt, ground, `fire_points`,
  `fire_heat_near`, `shot_damage`), `GestureTemplates.bounds()` for a stroke's box, `PixelFx` for art frames. Look
  there before writing a loop.
- **Keep dependencies pointing one way.** The gesture code (`scripts/gesture/`) knows nothing about spells; it
  must load under `-s`, where autoloads like `Sfx` don't exist. Spell-specific behaviour goes in the spell, the
  arena or the AI (the earthquake's shaky hand is in `wizard_brain._shaken`, not in the caster).
- **Use the engine.** Prefer Godot's own tools (groups, signals, `Area2D` overlaps, `StaticBody2D`, tweens,
  `Rect2` helpers) over hand-rolled bookkeeping.
- **Delete dead code** (unused functions, signals, art) in the same change that makes it dead, and update
  `art/CREDITS.md`, `tools/prepare_gothic_art.py` and these docs to match.
- **Refactoring:** change one thing at a time and re-run the full check after each step (startup, gestures,
  soak waves 3/7/12/17, the spells showcase), comparing screenshots against a baseline taken first.

## 10. Known issues and ideas

**Known issues:**
- The wand frames keep a faint line in a couple of run frames.
- The death animation still shows a staff.
- Sounds are untested by ear.

**Ideas the owner may like:**
- Spells that combine: fire melts ice, storm plus water.
- Give the dark wizard a personality per level.
- A gesture tutorial room.
- Music (CC0 dark ambient).

When unsure, ask the owner one clear question rather than guessing big.
