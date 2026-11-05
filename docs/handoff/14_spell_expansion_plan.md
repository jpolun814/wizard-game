# 14. The spell expansion plan (designed and built 2026-11-04; the owner still has to look at some of it)

Read this before you rename a school, touch the Library, change where starting pages lie, or add any of the spells below.
Everything here was agreed with the owner in one conversation. **All six steps are now built** (see "What was built" at the end of this chapter, which
says what differs from the plan and what still waits for the owner). The sections above it are the plan as it was agreed.

Player-facing wording follows section 0 of `CLAUDE.md`. The lines in this chapter are the owner's confirmed lines unless marked
as a suggestion.

## 1. Why

The owner's view: **the spell list is what will bring players back**, so the game needs many more spells, ranged ones first.
Ruled out, so do not suggest them again:

- a collection of "discovered spell interactions" (it makes players think about coded rules; a fireball melting an icicle
  should feel like the real world, not a rule),
- a daily seed (seeds are random but not interesting enough one from another),
- a climb against harder AI wizards (the AI has no difficulty levels),
- replacing the element schools with D&D's eight schools (see section 9),
- Web as a spell (Bramble and Flytrap already cover slowing and trapping),
- a second line in the Library such as "Evoker".

## 2. Order of work

1. Rename the schools (section 3).
2. The Library: accuracy and the school title (section 4).
3. Starting with no spells: each wizard's pages in a cluster by their spawn (section 5).
4. Blizzard freezes (section 6).
5. The new spells, in groups (section 7): A (Barbs, Pebble, Hailstorm, Featherfall), B (Thorn Whip, Flaming Sphere, Insect
   Plague), C (Leech, Raise Dead), D (Mirage).
6. The ritual renames, and the new Chant of the Scrying Eye (section 8). The renames can go in with step 1.

After each group, show the owner **every line of text you changed**, run the checks, and look at screenshots.

## 3. Step 1: the schools get new names

Same buttons, same colours, new names. Change what a player or a doc reads: the controls list, the tutorial, the spellbook,
the Library, `CLAUDE.md`, `docs/spell_pool.md` and the handoff chapters. First find out how widely the old ids are used in
code, scenes and tests. Rename the ids too if that is safe; if it is not, tell the owner what you left alone. One name for one
thing everywhere (section 0).

| Buttons | Old | New school | Title it earns |
|---|---|---|---|
| Left | Fire | **Pyromancy** | Pyromancer |
| Right | Water | **Aquamagy** | Aquamage |
| Middle | Air | **Aerokinesis** | Aerokinetic |
| Left + Right | Earth | **Terramancy** | Terramancer |
| Left + Middle | Flora | **Druidry** | Druid |
| Right + Middle | Shadow | **Umbramancy** | Umbramancer |
| Left + Right + Middle | Blood | **Necromancy** | Necromancer |

- Necromancy keeps Blood's rule: spells are paid for in **maximum** stamina, and only healing brings it back. Blood's
  spells (Offering, Burst, Crimson Veil, Adrenaline, Faint, Hunter's Mark, Fight or Flight) now sit in Necromancy.
- Druidry may later hold animal spells as well as plants (Insect Plague is the first).
- Existing school identities are in `docs/spell_pool.md`; update its headings, not its meaning.

## 4. Step 2: the Library

The Library (`scripts/library.gd`, `library_screen.gd`, `user://library.json`) only records real matches played by the person
at the machine. Tests never touch it. Keep that.

**Accuracy.** Each spell cast in a real match records how closely the drawing matched the spell's shape (the recognizer
already scores each stroke; check how that score is exposed). The Library shows the **average as a percentage** beside each
spell. A percentage is correct here (the owner chose it); the Library is a non-diegetic ledger.

**School title.** Taken from the share of your spell casts per school, in real matches only. Rituals have no school and do not
count. The tutorial and the waiting room do not count.

- Below **100 casts**: **Novice**.
- At 100 or more: the school with the highest share gives its title, **if that share is at least 30%**.
- If the top two schools are **within 5 points** of each other, or no school reaches 30%: **Sorcerer** (an even spread).
- Titles are in the table in section 3.

The numbers are never shown. Tune them in play if the owner asks.

## 5. Step 3: starting with no spells

Wizards start with **no spells**. The pages they would have been dealt lie in a **cluster of their own near their spawn**, a
short walk away, reachable with no spell. Not a shared pile ("not hunger games style").

- The first world has that many more pages than the same biome would have later; later worlds are unchanged.
- Start from `Pages.allotment` and `Pages.count_for` (`scripts/pages.gd`) and the world's page placement.
- The AI wizards go to their own cluster first.
- A rival who arrives early can still take pages from a cluster. Spawns are far apart; the owner accepts this.
- Update `tests/test_pages.gd` and `tests/test_stages.gd`. The waiting room and tutorial still let every spell be tried.

## 6. Step 4: Blizzard freezes

Anyone who stays in a Blizzard long enough freezes solid like Ice Prison, thaws like Ice Prison, then has **a second or two of
immunity** before it can freeze them again. Frost must creep over the wizard so it can be seen coming (telegraph). It hurts the
caster too (no teams), and the AI must avoid it like any other danger.

## 7. Step 5: the new spells

Gestures marked "risk" must be tested against every neighbour on the same buttons in `tests/test_gestures.gd`. Every spell also
needs the usual `CLAUDE.md` section 6 list: a real-world thing and a counter, one script, art from a free pack (credit it in
`art/CREDITS.md`), a sound, the `danger` group and `danger_at`, a stroke the dark wizard draws (`GestureTemplates.preview_points`)
and a score and stroke in `wizard_brain.gd`, network syncing (chapter 11), and a spellbook line.

| Spell | School | Gesture | Line (confirmed) |
|---|---|---|---|
| **Barbs** | Druidry | a plain flick | "Fling a volley of thorns." |
| **Pebble** | Terramancy | a flick (risk: Stone Wall is a straight stroke from solid ground) | "Hurl a pebble." |
| **Hailstorm** | Aquamagy | a circle, a line out as far as you want the clouds, then a line down (reuse the ring-then-line detector Push uses; risk: Ice Prison's circle) | "Call down a hailstorm." |
| **Featherfall** | Aerokinesis | a feather lying on its side (sideways to Liana's upright leaf): an almond with a line along its middle that runs out past the far end by a short amount (the quill), in one stroke. The owner's description; untested. Risk: Push, a closed ring with a line leaving it. The feather's line runs back across the inside of the loop, which Push's does not, so rule the feather out before the Push split, as the star is ruled out before the spiral | "Fall as light as a feather." |
| **Thorn Whip** | Druidry | the Tide Surf shape (risk: Great Oak's crown loop) | "Lash out with a thorny vine." |
| **Flaming Sphere** | Pyromancy | a circle, then a line along the ground in the direction it rolls | "Launch a rolling ball of fire." |
| **Insect Plague** | Druidry | a figure eight, the pattern of a bee's waggle dance. The owner feared the chain of loops I first suggested would be hard to validate, so this uses the shape Decoy already has (the `eight` templates, already tested). Check it against Glowcap's circle and Lily Pads' ring | "Summon a swarm of stinging insects." |
| **Leech** | Necromancy | the Tide Surf shape | "Leech someone's strength." |
| **Raise Dead** | Necromancy | a Latin cross: a long stem with a shorter bar across it near the top (new detector; first planned as a hand, changed after the owner played it) | "Raise a skeleton from the dead." |
| **Mirage** | Umbramancy | a portrait rectangle (new detector) | "Create a mirage of what wizards desire most." |

### What each does

- **Barbs:** a short-range spread of thorns flung along the stroke. Stone and cover stop it; fire burns the thorns.
- **Pebble:** a small stone with a falling arc (unlike Ignite and Frostbolt it goes over walls), cheap to cast. Real thing: a
  sling.
- **Hailstorm:** a cloud placed along the line you drew; stones fall one at a time and stop at the first platform, so a roof
  protects. A short violent volley, unlike Blizzard, which lingers.
- **Featherfall:** slows your fall. Needs no counter.
- **Thorn Whip** (D&D's Thorn Whip): a long lash that hits the first thing and **drags it toward the caster**. It also drags
  loose pages. Heavy things resist. Fire burns it and a stone wall stops it. It is not a projectile, so Barrier does not stop it.
- **Flaming Sphere** (D&D's Flaming Sphere): a ball of fire that rolls along the ground in the stroke's direction, follows slopes
  and **climbs over walls**, falls into pits, and keeps going until water puts it out. **It also burns out after a long roll**
  (the owner agreed to this, since a sphere that never stops would roam a world 1000 tiles wide), and should die in rain. It hurts
  everyone it touches, the caster included. Counters: jump it, water. **Prototype the climbing movement first and show the owner
  before building the rest.** Watch two risks: terrain exists only near players (chunks are freed when no one is close, so a far
  sphere could fall through the world), and every machine must track it in a network match.
- **Insect Plague** (D&D's Insect Plague): a cloud, built as **one cloud that ticks**, drawn as many insects.
  - Each tick does 1 damage; staying in the whole time adds up to about 16.
  - It follows the **nearest person within a radius**, and that can be the caster. The caster is ignored (no targeting and no
    damage) for a short time after casting, then becomes targetable.
  - It moves only slightly slower than a running wizard.
  - **One hit disperses the whole cloud.** It also disperses after some time with no targets.
  - Counters: shoot it, smoke, fire, water, wind.
- **Leech** (D&D's Vampiric Touch): a tether you can see. It **breaks when line of sight is lost**, and I suggest also at a
  maximum distance. While it holds, **every spell the caster casts has its stamina cost split 50/50 between the caster and the
  target**. It costs maximum stamina like the rest of Necromancy (the amount is not decided). The tether needs real pixel art.
- **Raise Dead:** raises a **skeleton** (not a zombie; there is no zombie art, and all melee mobs look the same). The existing
  art is in `art/mobs/skeleton`.
  - It always has **50 health** and costs **37 maximum stamina** (the cost is 75% of its health, rounded down).
  - **No limit on how many** you raise; your maximum stamina is the limit. At 200 maximum you can raise five. The usual rule
    stays: a cast is refused if it would take the last of your maximum.
  - The maximum stamina is **not refunded** if the skeleton is destroyed; only healing returns it.
  - It never attacks its master. **Skeletons raised by different wizards fight each other.**
  - This is the **first thing in the game with a master**. Spells still have no teams. Write this exception into `CLAUDE.md`
    (rule on teams, section 5) and the memory note `spells-have-no-teams`.
  - Needs AI support, and the network.
- **Mirage:** a false page that looks like a real one and **shimmers faintly**. It fades when anyone gets close, **the caster
  included**. The AI walks to it like a page but should learn from seeing one vanish. Counter: walk up to it, or notice the
  shimmer. The rectangle needs a new "closed box with four sharp corners" detector. There is none now (`caster.gd` around line
  657 holds only an old comment about Ice Prison's box). Require a portrait box.

### Starting values to tune in play (my suggestions, not agreed)

- Flaming Sphere burns out after rolling about 100 tiles.
- Insect Plague: ignores its caster for about 4 seconds, moves at about 85% of running speed, disperses after about 6 seconds with
  no target, and has a hard limit of about 20 seconds.

## 8. Step 6: rituals get new names

The ritual ids, Latin words and effects stay. Only names change (`RITUALS` in `scripts/ritual_input.gd`, the spellbook, the
Library, the tutorial, the docs). **"Ritual" stays the category word in code and text** (`RitualInput`, `kind: "ritual"`,
"The ritual backfired").

The four forms in a name say what kind of ritual it is, so no ritual is "Chant of ..." by default:

- **Rite:** about places.
- **Incantation:** the two weighty ones.
- **Blessing:** a boon on your body.
- **Chant:** sight and finding.

Jinx and Charm were considered and dropped. "Ritual of ..." was dropped as a form too.

| Id | Effect | New name | Old name |
|---|---|---|---|
| `minimap` | Show the land | **Rite of the Land** | Chant of the Land |
| `mark` | Mark this place | **Rite of the Cairn** | Incantation of the Mark |
| `recall` | Portal back to your mark | **Rite of Return** | Incantation of the Return |
| `bonfire` | Kindle a bonfire and heal | **Incantation of the Hearthfire** | Incantation of the Bonfire |
| `rift` | Tear open a way to a random place | **Incantation of the Fool's Gate** | Incantation of the Rift |
| `boundless` | Never tire for a while | **Blessing of the Wellspring** | Chant of Boundless Vigour |
| `double_jump` | Jump again in mid-air | **Blessing of Skystep** | Chant of the Second Leap |
| `haste` | Run faster | **Chant of Swift Feet** (kept) | Chant of Swift Feet |
| `deep_breath` | Hold your breath | **Blessing of the Deep Breath** | Chant of the Deep Breath |
| `insight` | Deeper knowledge of those around you | **Chant of Insight** (kept) | Chant of Insight |
| `scrying` → `dowsing` | Point to the nearest unread page | **Chant of Dowsing** | Chant of Scrying |
| new: `scrying_eye` | Keep a rival in view | **Chant of the Scrying Eye** | (new) |

(The owner might later make Fool's Gate a Rite since it moves you to a place. It is an Incantation for now because it was one
and it is the bigger gamble.)

**The page-finding chant becomes Dowsing** so "scrying" is free for the new chant.

- Rename the id `scrying`, the `Scrying` class (`scripts/scrying.gd`), the `scryings` group and `EdgeArrows`'s lookup to the
  dowsing names, and `chant:scrying` in `scripts/pages.gd`, the spellbook and the tests.
- The Library counts per page. **Carry the old counts over** to `chant:dowsing` (check whether they are keyed by that id) so no
  history is lost.
- Give the new chant a different id (`scrying_eye`) so old data can never be mistaken for it.

### The Chant of the Scrying Eye (new)

A **toggle** like the minimap and Insight (kind `"toggle"`, no stamina; the cost is finding its page).

- A small round window in the **bottom-right corner** shows a live view of a **random living rival** (AI wizards included) and
  stays on that rival until they fall, then picks another. The minimap stays top-right, so they do not collide.
- It does not say where the rival is.
- A small **eye icon floats over the watched wizard's head**, so they can see they are watched (an interface element, allowed).
- It needs a second camera. **Risk:** terrain visuals are only built near players, so the window could show empty space when the
  watched wizard is far away. Check this first. It must also work in a network match.
- The AI can cast it when it has lost track of everyone.
- Its Latin words: I suggested "oculum mitto" ("I send out an eye"). **The owner has not confirmed any words.**

## 9. D&D's schools: used as a lens, not adopted

The owner considered switching to D&D's eight schools and decided to keep the element schools. Reasons that hold: there are
only seven button combinations (left, right and middle), the gesture shapes are mirrored across element schools (five different
flicks live side by side because the buttons differ), and element schools can be read from the world while D&D's cannot.

The owner liked the idea of a hidden tag per spell but then said it is not needed; only the analysis was wanted. **No tags were
added.** This is the spread of the 48 spells in `spells/` on 2026-11-04, tagged by what each does (my judgment):

| D&D school | Now | With the planned spells |
|---|---|---|
| Evocation | 19 | 22 (Barbs, Pebble, Hailstorm) |
| Conjuration | 8 | 10 (Flaming Sphere, Insect Plague) |
| Transmutation | 8 | 9 (Featherfall) |
| Illusion | 4 | 5 (Mirage) |
| Abjuration | 3 | 3 |
| Enchantment | 3 | 3 |
| Necromancy | 2 (Offering, Vacuum) | 4 (Leech, Raise Dead) |
| Divination | 1 (Hunter's Mark) | 2 (the Scrying Eye is a ritual, not a spell) |

Evocation is about 40% of the list. **The thin ones are Divination, Enchantment and Abjuration**; look there for new ideas.

## 10. Corrections found while checking the code

- Hunter's Mark and Fight or Flight are **Blood** (now Necromancy) spells, not Shadow.
- Sneak already uses the **wavy line** on the Shadow (Umbramancy) buttons.
- A **Chant of Scrying already existed** (an arrow to the nearest unread page), so a "dowsing" spell was already built.
- Ice Prison's resource says `circle`; the comment about its closed-box detector in `caster.gd` is all that is left of one.

## 11. Ideas mentioned but not approved

Do not build these unless the owner asks. Lava Bomb, Wind Blade, Rolling Boulder, Fissure, Burning Glass, Whirlpool, Ice Wall,
Blood Lance, Ball Lightning, Alarm (a tripwire bell), Salt Circle (skeletons cannot cross it), Dizzy Spores (Druidry,
intoxicating), a dowsing-style spell for another school.

## 12. Method, checks and docs to update

- Run the checks in `CLAUDE.md` section 3 after each step (`python tools/run_checks.py`), including `tests/test_gestures.gd`
  (it must still print every check passing; add yours), `tests/test_pages.gd`, `tests/test_stages.gd`,
  `tests/brain_spells_check.tscn` and `tests/ritual_check.tscn`. Add a check for each new spell and look at the screenshots.
- You cannot hear sounds or feel the controls. Say so each time.
- Do not commit, push or delete the owner's files unless asked.
- If no free asset suits the whip, hail, tether, eye or shimmer, show the owner options before using anything. CC0 or CC-BY only.
- **Docs to update as you go:** `CLAUDE.md` (school names, the controls table, the spell table, the teams rule for Raise Dead, the
  chapter table), `docs/spell_pool.md`, `docs/handoff/02_codebase_map.md`, `03_gestures_and_spell_design.md`,
  `06_enemies_and_ai.md` (Raise Dead's skeleton), `07_testing.md`, `11_network_play.md`, `art/CREDITS.md`, and the memory note
  `retention-direction`.


## 11. What was built (2026-11-04)

All six steps. Each has a check (`python tools/run_checks.py` runs them; the list is in `CLAUDE.md` section 3).

1. **School names**: `SpellData.SCHOOL_NAMES`, `school_name()`; the spellbook, Library and tutorial show them. The ids did not change.
2. **Library**: `Library.record_cast(spell, accuracy)` keeps an average per spell (the "Accuracy" row on a card) and `Library.title_of` gives the title, shown
   on the all-worlds view. The Library carries counts for `chant:scrying` over to `chant:dowsing` when it loads (`_carry_over`).
3. **No starting spells**: `Pages.start_empty`, `Pages.cluster_of`; `World._lay_clusters` lays each seat's pages in a cluster by their spawn; the AI reads its own.
4. **Blizzard freezes**: whoever stays in the snow is chilled, then frozen in a block of ice, then shrugs it off for a while (`Mob.shrugs_off_cold`).
5. **Spells**:
   - Barbs, Pebble, Hailstorm, Featherfall, Thorn Whip, Insect Plague as designed (numbers in each script's constants). New gesture detectors:
     `caster._hailstorm`, `_feather`, and (for Flaming Sphere) a level line after the ring; previews in `GestureTemplates`.
   - **Leech**: `Leech.pick` finds the wizard in the way of the stroke (a cone, in sight, within reach); while the tether holds, `arena.cast_by` makes the caster
     pay half of each stamina spell and `spawn_spell` (on every machine) drains the other half from the one on the tether. It costs 24 maximum stamina. Blood spells
     are not split. It breaks on a wall or smoke between them, at 460 px, when either falls, after 24 seconds, or when the caster tethers again.
   - **Raise Dead**: gesture `latin_cross` (`caster._is_cross`: reads where the ink lies, a stem down most of the height and a bar across most of the width in the upper part, tried at a few slants; the recognizer has no template for it). `arena._raise_dead` makes a `basic` `Mob` with `master` and `roams` set, 50 health,
     for 37 maximum stamina. It follows its master, never attacks them, fights wizards and the skeletons of other masters, and falls when its master falls. In a
     network match the machine that drives the master drives the skeleton (`set_multiplayer_authority`), named `Raised_<master>_<cast count>` the same on every machine;
     the others show a puppet, and a blow from another machine's skeleton goes through `Mob._struck_by_the_dead`. **First thing with a master; see `CLAUDE.md` section 5.**
   - **Mirage**: gesture `portrait` (a tall closed box with four corners, `caster._is_portrait_box`, which first turns a leaning box upright). `Mirage` is a `PagePickup`
     that every wizard wants (`gives` is always true) and that fades when anyone is within 150 px (the caster too). A brain that has watched one fade stops going for them
     (`WizardBrain.saw_a_mirage_fade`).
   - **Flaming Sphere**: `FlamingSphere` (a `CharacterBody2D`): rolls at a steady pace, follows slopes, drops into pits, climbs a wall that faces it (up to 4 s, then it turns
     back), burns what it touches, and goes out in water, in rain (`Squall.rain`, the jungle's downpours) or after about 130 tiles. It is a fire (`SpellTargets.fire_points`)
     and joins the `ground_watchers` group, which `World._process` reads so that the rock round it stays made. **The owner was to see the climbing movement before the
     rest was built: I built it all and tested the movement headlessly (`tests/sphere_check.tscn`), but the owner has not seen it. The look is now a swirling ball of fire (`art/fx/sun.png`, drawn by `tools/make_sun_art.py`) that turns as it rolls, on a glow, leaving licks of flame behind it: the owner chose a rolling sun, and said the first version with rays looked like a spiky ball.**
6. **Rituals**: the names in the table of section 8; `scrying` became `dowsing` (`Dowsing`, group `dowsings`, `DowsingArrows` in `hud.tscn`, `chant:dowsing`). The new
   **Chant of the Scrying Eye** (`scrying_eye`, "oculum mitto", unconfirmed words): `ScryingEye` is a round window bottom right (a `SubViewport` sharing the world, with
   its own camera in `ground_watchers`, masked by `scripts/hud/circle_mask.gdshader`); it watches a random wizard standing other than the player and picks another when they
   fall; `EyeMark` floats over the watched wizard on every machine (`arena.eye_on`). It shows no sky (the sky is a canvas layer of the main view). A brain with the page
   sends one out when it has lost track of everyone (`WizardBrain._eye_time`).

**Open points for the owner**
- Words I wrote that are drafts until confirmed: Barbs "Fling a volley of thorns.", Pebble "Hurl a pebble.", Hailstorm "Call down a hailstorm.", Featherfall "Fall as light as a feather.",
  Thorn Whip "Lash out with a thorny vine.", Insect Plague "Summon a swarm of stinging insects.", Scrying Eye "Send out an eye to watch another wizard.". Flaming Sphere, Leech,
  Raise Dead and Mirage use the owner's lines.
- The shot art (`art/fx/thorn.png`, `pebble.png`, `hailstone.png`, `insect.png`) is hand-pixeled by `tools/make_shot_art.py`; the Leech tether is drawn from soft round beads and
  the Flaming Sphere from the pixel flames of `Flames`. None is a final look.
- Raised skeletons fall when their master does (the plan did not say), and a skeleton far from its master (over 1100 px) stays where it is.
- The Scrying Eye's window shows the world without the sky.
- Sounds were chosen from the existing set and have not been heard.

**Changed after the owner played it:** Featherfall is now a falling feather's path (three sweeps across, left-right-left, each bent down in the middle and ending lower than it began; the owner's idea) because the almond was confused with Push and Gust. The Flaming Sphere failed to appear in the waiting room because `ArenaGen.world_size` is only set by the world generator (it is zero in the waiting room) and the ball's fell-out-of-the-world check fired at once; `lab_sphere_check` covers it. A Blizzard's cold now reaches everyone in the column of falling snow, not only those near the clouds.

More changes after the owner played it: the pages a wizard starts beside lie together as one fanned pickup (`PagePickup.fan`, built on `spoils`; one Tab reads them all); the Mirage is only shy of someone right up to it (`Mirage.NEAR` 56), and shimmers in and out; Pebble is faster and flatter (`SPEED` 1050, `FALL` 760); Thorn Whip bites (`ThornWhip.HARM`); Insect Plague is driven off by water; Raise Dead's hand is drawn with a thumb and read more loosely; the Scrying Eye's window now wears the world's grade and the graveyard's grey (`arena.grade_biome`, `arena.greyed`), and its eye is a gold slit-pupilled eye (`EyeMark`). The pause screen says "Quit to menu" and "Quit to desktop". Pictures: `tests/fan_look.tscn`, `tests/eye_mark_look.tscn` (`-- out=DIR`, need a window).

More changes after the second play (2026-11-04): Raise Dead is a Latin cross now (the hand was hard to draw); Thorn Whip goes the way the wave was drawn, at any angle (`Caster`, the farthest point from where it began); the Mirage fades when anyone is within `NEAR` 96 and ripples (slow, soft) in and out over 1.5 s (the page outline shader now obeys the node's modulate, which is what makes any fade show); a Tornado with no ground under it does not form; Stone Wall needs the stroke to begin inside the ground itself (`arena._is_ground_at`); a lasting Blizzard slows whoever is in its snow, not only whoever touches the cloud. Featherfall lasts 15 s (`Featherfall.SECONDS`). The pause buttons are one width. The end-of-match stats screen is in chapter 7 and `scripts/match_stats.gd`, `scripts/stats_screen.gd`.
Mirage, as it now is: it shimmers in, then stands steady (no waver); anyone within `NEAR` makes it shimmer out and hide, it shimmers back in once everyone has left, and after `LIFE` (30 s) it shimmers out for good. The stats screen can be pulled up again by the "Match stats" button that stays on the screen (bottom left) once the match is over for the person: they have fallen, or won. There are no stats to see before then (`Hud.offer_stats`, `Hud.stats_requested`); the screen sizes itself to the window (its parent is a layer, so anchors do nothing), which is what lets the pointer reach its charts.

## 12. Thunderclap and Rocket Jump (added 2026-11-04, at the owner's design)

- **Thunderclap** (Air, `spells/thunderclap.tres`, `scripts/spells/thunderclap.gd`): gesture `thunderclap` = a cloud (a ring) and a bolt: `caster._is_thunderclap` (a closed loop, then a zigzag at least 40 px down that bends across its way twice; read before the Push and Hailstorm readings). It centres on the caster, throws every body within `RADIUS` back (not the caster) and dazes it: `Wizard.daze_time` (set by `apply_debuff("daze")`) slows it and makes `silenced()` true, so it can cast and chant nothing; a mob is thrown and slowed. No damage. Line in the book (the owner's): "Evoke thunder, throwing and dazing everything around you." No lightning is drawn; the sound is the CC0 thunder recording over a faint `quake`.
- **Rocket Jump** (Fire, `spells/rocket_jump.tres`, `scripts/spells/rocket_jump.gd`): gesture `rocket` = an arrow pointing up, drawn with the fire button (the same picture as Geyser and Updraft on theirs; a shaky one is not read as Smoke Screen). `Wizard.rocket_time` lifts the caster for `BURN` (1.5 s): barely off the ground at first, then quicker up to `TOP`, about 480 px in all; flame pours from the feet. Line in the book (the owner's): "Launch into the sky like a rocket." It is a start-of-game "move" (`Pages.MOVES`) and a brain lift/wall opener (`WizardBrain.LIFTS`, `WAYS["wall"]`); that a wall gate is cleared with it has not been run through `cross_check` (no seed found with a wall gate that the check could set up), only the brain's lift in `brain_spells_check`.
- Checks: `tests/group_c_check.tscn`; both are in `brain_spells_check`; `test_gestures` (784). Lines are drafts until the owner confirms them. The sounds are existing ones (`explosion`, `push`) and have not been heard.

**Settled by the owner (2026-11-05):** the sounds are fine, the draft spell lines (Barbs, Pebble, Hailstorm, Featherfall, Thorn Whip, Insect Plague, Scrying Eye) are fine and final, and the Flaming Sphere is a rolling sun. Leech and the stand-in shot art are the placeholders left.
