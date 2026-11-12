# Creatures and the AI wizards

## Creatures (`Mob.KINDS`, one `MobKind` resource each in `res://mobs/`)

The world's dangers are mostly the other wizards. The creatures are few, and each has a place:

| Kind | Where | What it does |
|---|---|---|
| `basic` (skeleton) | the graveyard's dead (`Mob.roams`), a crypt's guard, a skeleton raised by Raise Dead | walks to whoever it notices, winds up for 0.3 s (leans, flashes, plays its attack), then hits; a wizard who moved away during the wind-up is missed |
| `knight` | the castle's guards (`Mob.guards`) | stands at its post until a wizard comes near, fights them, and walks back |
| `giant` (`effect` "smash") | the castle's ground floors, the tutorial | draws its leg back for 0.9 s, then stomps the ground in front of it: the first stomp that catches a wizard sticks them in the ground for 3 s, a second throws them; it breaks stone walls and boulders, and jumps a ledge that holds it up |
| `dummy`, `turret` (`effect` "dummy") | the waiting room, the tutorial | a practice target that heals when left alone; the turret charges a glowing orb for 0.45 s, then shoots |
| `earth_melee`, `runner` (`effect` "knockback") | the tutorial | skeletons whose blow knocks a wizard back; the runners are fast |
| the wizard looks (`dark_wizard`, `pyre_wizard` and the rest, role `wizard`) | every match | not creatures: these files give each wizard figure its Insight name and line |

The sentinel (`Sentinel`, an eye that shoots a laser) is a gate of the world, not a `Mob`. Piranhas (`Piranhas`) are a shoal in a pond.

## Design rules for creatures

1. **Same role, same creature.** A school is shown only by colour (an outline and a slight tint). The owner rejected a differently drawn earth skeleton.
2. **Every attack is telegraphed** and can be dodged. Add a warning to anything new.
3. **Hitboxes match the body,** not the weapon. `PixelArt.CHARACTERS[...]["body"]` is measured from the art.
4. **Spawning:** a creature arrives through a summoning fade and can't act or be hurt until it finishes.

## The AI wizards (`WizardBrain`, `SkyBrain` in the sky)

The owner wants them indistinguishable from people (`CLAUDE.md` section 12 says how that is judged). They have a person's body, view and limits:

- **Casting** goes through the real recognizer: `_begin_cast(spell, stroke, draw_time)` draws the stroke in front of it over `draw_time`, then
  `caster.cast_stroke`. A blow of 6 or more while it draws interrupts the spell. Strokes come from `GestureTemplates.preview_points`, with a hand's wobble
  (`_handed`, measured in `ai/stroke_drift.json`) and a shaky hand while its own screen shakes (`_shaken`).
- **Sight** is a screen of its own (`Eyes`: the person's window size and camera rest, smoothed like the camera), so it sees only what a person in its place would.
- **Reactions:** it watches shots and, after a reaction time set by `skill`, jumps, turns the shot with a Gust, raises a Barrier or steps aside. Too close,
  it pushes, steps away or breathes fire. It steps out of danger with every spell's `danger_at`.
- **Footwork:** it keeps a duelling range, strafes in slow turns, hops rarely, and faces the way it moves.
- **Attacks:** each spell gets a score from the situation (is the rival still, rooted, behind cover, under a platform, near or far?); it leads moving targets (`_predict`).
- **Skill** is 0 to 1 (`skill`, from the Rival skill setting): it sets reaction time and aim.
- **Every spell has a use** (`WizardBrain.USES`; `tests/brain_spells_check.tscn` gives each spell alone to a brain and sees it cast it):
  - *attack* spells are scored in `_attack` and drawn in `_attack_stroke`;
  - *repel* spells (Push, Geyser, Tide Surf, Spore Puff, Fire Breath) are chosen when a rival is on top of it (`_choose_repel`);
  - *defence* spells (Barrier, Gust, Shadow Step) answer an incoming shot (`_choose_defence`);
  - *tend* spells are cast for its own needs by `_tend`: light in the dark, strength, hiding when badly hurt, and cover from a rival who keeps shooting; Hunter's Mark finds a
    wizard who has faded from sight; a Scrying Eye when it has lost track of everyone (`_eye_time`); Featherfall in a long fall;
  - *ways up* (`LIFTS`) raise it over a wall or up to a rival standing over its head (`_chase`).
- It stops going for Mirages once it has watched one fade (`saw_a_mirage_fade`).

**When you add a spell,** teach the brain to use it, and make sure it never casts one that can't work (no Spark at a sheltered rival, no line-of-sight spell at one it can't see).

## How the AI gets about a world

- **The map of the ways.** `Walkways` (`scripts/world/walkways.gd`) is the one set of rules for where a wizard can stand and the moves between (walk, step, fall,
  jump), shared by the generator's reachability test and the wizards. `WorldNav` finds paths over it, kept to tiles that can be left as well as come to.
  `WizardRoute` follows a path: when to jump, how fast, when it is stuck. In the ocean a wizard out of its depth swims straight for its goal instead (`_swim`).
- **Exploring:** in a match it knows only the pages it has seen (`_note_sights`) and walks to unexplored squares (`_choose_explore`), and it plans only through ground it
  has seen (`_toward_known`).
- **Gates it clears** (`CLEARS`): with no page to be had it goes to the nearest gate a spell it holds can clear (fire for thorns, gas and ice; stone for a wall and ice)
  and strikes until it is gone. `World._watch_gates` marks the gate open and builds the ways again.
- **Gates it crosses** (`WAYS`): `WorldBuilder.shut(world, true)` leaves chasms, floods, piranha pits and sentinels open in the ways and lists the tiles that cross each
  (`tolls`); `WorldNav.path` goes round the crossings it holds no spell for. Over water it draws a Frost Bridge or Lily Pads and walks over; over a pit it jumps
  and carries itself on with Shadow Steps (`_leaping`); at a wall it lifts itself over (`_lifting`: a Geyser under its feet, Push, or a Liana); through lava it wades in
  Obsidian Armor (`_wading`); at a sentinel it hides behind Smoke Screen, an Eclipse, a Barrier or a Decoy; through gas it holds its breath with the Chant of the Deep Breath.
- **Rooms built by hand** (the waiting room, the tutorial) are read the same way by `RoomScan` (`CLAUDE.md` section 11).
- Tests: `tests/test_nav.gd`, `tests/route_check.tscn`, `tests/cross_check.tscn`, `tests/gate_check.tscn`, `tests/sentinel_check.tscn`, `tests/arena_sim.tscn` (AI-only matches).

## Raised skeletons

A skeleton raised by Raise Dead is a `basic` `Mob` with `master` set. `_pick_prey` skips the master and picks the nearest skeleton of another master as `_foe`;
`_target()` prefers `_foe`; with no one to fight it keeps near its master (`_follow_master`); it falls when its master falls. In a network match the machine that drives
the master drives the skeleton, named `Raised_<master>_<cast count>` on every machine; the others show a puppet.
