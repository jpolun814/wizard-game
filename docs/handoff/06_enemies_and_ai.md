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

The owner wants them indistinguishable from people (the section on playing like a person, below, says how that is judged). They have a person's body, view and limits:

- **Casting** goes through the real recognizer: `BrainHand.begin_cast(spell, stroke, draw_time)` draws the stroke in front of it over `draw_time`, then
  `caster.cast_stroke`. A blow of 6 or more while it draws interrupts the spell. Strokes come from `GestureTemplates.preview_points`, with a hand's wobble
  (`BrainHand.handed`, measured in `ai/stroke_drift.json`) and a shaky hand while its own screen shakes (`BrainHand.shaken`).
- **Sight** is a screen of its own (`Eyes`: the person's window size and camera rest, smoothed like the camera), so it sees only what a person in its place would.
- **Reactions:** it watches shots and, after a reaction time set by `skill`, jumps, turns the shot with a Gust, raises a Barrier or steps aside. Too close,
  it pushes, steps away or breathes fire. It steps out of danger with every spell's `danger_at`.
- **Footwork:** it keeps a duelling range, strafes in slow turns, hops rarely, and faces the way it moves.
- **Attacks:** each spell gets a score from the situation (is the rival still, rooted, behind cover, under a platform, near or far?); it leads moving targets (`_predict`).
- **Skill** is 0 to 1 (`skill`, from the Rival skill setting): it sets reaction time and aim.
- **Every spell has a use** (`WizardBrain.USES`; `tests/brain_spells_check.tscn` gives each spell alone to a brain and sees it cast it):
  - *attack* spells are scored in `BrainCombat.attack` and drawn in `BrainHand.attack_stroke`;
  - *repel* spells (Push, Geyser, Tide Surf, Spore Puff, Fire Breath) are chosen when a rival is on top of it (`BrainCombat.choose_repel`);
  - *defence* spells (Barrier, Gust, Shadow Step) answer an incoming shot (`BrainCombat.choose_defence`);
  - *tend* spells are cast for its own needs by `BrainMend.tend`: light in the dark, strength, hiding when badly hurt, and cover from a rival who keeps shooting; Hunter's Mark finds a
    wizard who has faded from sight; a Scrying Eye when it has lost track of everyone (`_eye_time`); Featherfall in a long fall;
  - *ways up* (`LIFTS`) raise it over a wall or up to a rival standing over its head (`_chase`).
- It stops going for Mirages once it has watched one fade (`saw_a_mirage_fade`).

**When you add a spell,** teach the brain to use it, and make sure it never casts one that can't work (no Spark at a sheltered rival, no line-of-sight spell at one it can't see).

## How the AI gets about a world

- **The map of the ways.** `Walkways` (`scripts/world/walkways.gd`) is the one set of rules for where a wizard can stand and the moves between (walk, step, fall,
  jump), shared by the generator's reachability test and the wizards. `WorldNav` finds paths over it, kept to tiles that can be left as well as come to.
  `WizardRoute` follows a path: when to jump, how fast, when it is stuck. In the ocean a wizard out of its depth swims straight for its goal instead (`_swim`).
- **Exploring:** in a match it knows only the pages it has seen (`BrainExplore.note_sights`) and walks to unexplored squares (`BrainExplore.choose_explore`), and it plans only through ground it
  has seen (`BrainExplore.toward_known`).
- **Gates it clears** (`CLEARS`): with no page to be had it goes to the nearest gate a spell it holds can clear (fire for thorns, gas and ice; stone for a wall and ice)
  and strikes until it is gone. `WorldGates.watch` marks the gate open and builds the ways again.
- **Gates it crosses** (`WAYS`): `WorldBuilder.shut(world, true)` leaves chasms, floods, piranha pits and sentinels open in the ways and lists the tiles that cross each
  (`tolls`); `WorldNav.path` goes round the crossings it holds no spell for. Over water it draws a Frost Bridge or Lily Pads and walks over; over a pit it jumps
  and carries itself on with Shadow Steps (`BrainMoves.leaping`); at a wall it lifts itself over (`BrainMoves.lifting`: a Geyser under its feet, Push, or a Liana); through lava it wades in
  Obsidian Armor (`BrainMoves.wading`); at a sentinel it hides behind Smoke Screen, an Eclipse, a Barrier or a Decoy; through gas it holds its breath with the Chant of the Deep Breath.
- **Rooms built by hand** (the waiting room, the tutorial) are read the same way by `RoomScan` (the section "The AI reads any room" below).
- Tests: `tests/test_nav.gd`, `tests/route_check.tscn`, `tests/cross_check.tscn`, `tests/gate_check.tscn`, `tests/sentinel_check.tscn`, `tests/arena_sim.tscn` (AI-only matches).

## Raised skeletons

A skeleton raised by Raise Dead is a `basic` `Mob` with `master` set. `_pick_prey` skips the master and picks the nearest skeleton of another master as `_foe`;
`_target()` prefers `_foe`; with no one to fight it keeps near its master (`_follow_master`); it falls when its master falls. In a network match the machine that drives
the master drives the skeleton, named `Raised_<master>_<cast count>` on every machine; the others show a puppet.

## The AI reads any room

The brain used to plan only from a match world's gate lists. `scripts/room_scan.gd` (`RoomScan.read`) now reads a hand-built room the same way: its ground, plus live thorns, gas, brick walls, ponds with fish, turrets, eyes, creatures, deep pits and sheer cliffs, and gives the same gates and crossings a World does. A room hosts it by joining group `gate_source` (the `Lab` and so the `Tutorial` do; it rescans every 0.5 s) and puts its exit in group `exit_points`. `WorldNav` has an `origin` (rooms run in negative columns) and `WorldNav.NONE` for "no tile". New brain skills: clearing creatures, Faint on giants, Barrier against several shooters, the double-jump chant, a rocket plus Featherfall leap, striking tall walls at the foot, gas banks, walking to the exit. The brain has no code for the tutorial itself: change the tutorial and the same wizard should still finish it (`tests/tutorial_ai_check.tscn`). The tutorial keeps lost maximum stamina (`Lab.heals_wounds = false`) and its gauntlet is shorter, with no second giant, dark stage, wall-gas-eye stage or last pit. Not yet general: spike beds are not read as hazards, and match worlds were left as they were.

## How the AI is made to play like a person

**The AI wizards are the scripted brain (`WizardBrain`, `SkyBrain` in the sky).** A learned AI was tried from 2026-11-08 to 11-12: networks that
played through a person's controls, trained by self-play in a curriculum (Fireball duels, then four spells), and trained footwork for the rivals'
legs. It learned the duels, but the owner called it off on 2026-11-12: whole matches were far off, and a trained player wins in ways that do not
look human. All of it (the hand, the senses, the trainers, the arenas, the checks, and chapters 17 and 18) was removed; it is all in commit
`8b82bc3` ("Learned AI through a person's controls..."), and `git checkout 8b82bc3 -- training scripts/senses.gd ...` brings it back. What it left
that the scripted brain uses: a wizard faces the way it moves (no moonwalking), a brain's misfire costs stamina as a person's does, and the
people's limits measured from recordings (`ai/human_limits.json` from `tools/measure_human.py`, `ai/stroke_drift.json` from `tests/measure_drift.gd`).

The owner wants the AI wizards to be indistinguishable from people, judged by what a human would find odd, not by what the code says. The method: run
`tests/arena_sim.tscn -- seed=N seconds=360 log=FILE` headless on many seeds (`log=` writes a line four times a second for each wizard: position, velocity,
stamina, foe, flags, goal, plus `C` cast and `D` damage lines; `probe=N,SEC` prints a brain's variables, `kill=SEC`, `sketch=X,Y` prints the nav map, `shot=FILE shotat=SEC follow=N` takes a picture, `fightshots=DIR`),
read the logs for stalls, jitter, pointless deaths and idling, and fix what a person would not do. Worlds are not deterministic run to run, even with one seed.
What the brain does now that it did not:
- **Sight and exploring** (matches only, `BrainExplore.sight_is_limited()`): it knows only the pages it has seen (`BrainExplore.note_sights`), and otherwise walks to unexplored squares (`BrainExplore.choose_explore`). When a way is shut by danger or by a stair that will not come, it marks that side explored and goes the other way.
- **Fire, lava, volcanoes, piranhas:** it will not wade piranha water (`_in_shoal`, `_bitten`), keeps off an awake volcano and flees it downhill (`_safe_side`), never stands chanting in fire (an escape cancels `_settle`, `_typing`, `_camped`), and does not turn back and forth while fleeing (hysteresis in `_safe_side`).
- **Creatures that attack** (`_assailed`): it strikes one down with a spell that kills, or runs.
- **Mending:** a worn-down wizard lights a bonfire (chant) and rests at it (`BrainMend.mend`); a wizard rests when stamina is low (thresholds scale with maximum stamina).
- **Footwork:** it walks, hops rarely (jumping is a last resort), strafes in a fight in slow turns, draws attack strokes with a hand's wobble (`_handed`), and takes a person's time to type a chant.
- **Watchdog:** `_watch_progress` gives up a goal after 20 s with no progress; `WizardRoute.wait()` marks a wait as not being stuck.
- **Floors:** exploring weighs nearby unexplored squares on other floors as well as along the way (`BrainExplore.choose_explore`, `EXPLORE_FLOOR`), so the castle's upper and lower halls get visited; a stair that does not come in `STAIR_PATIENCE` seconds, or a ride that never began (`WizardRoute.RIDE_GIVE_UP`), is given up. `tests/arena_sim.tscn` prints the pages still lying at the end and whether anyone could walk to them.
- **Thorns:** with no fire to burn them, it does not walk into world thorns (`BrainDanger.lethal_at`); it stops camping or chanting when a creature, fire or fish is on it (`BrainMend.mend`).
Seen and left alone: long waits for swinging castle stairs (legitimate, up to about 78 s), the rift, boundless and dowsing chants are unused, foe hunting still knows where rivals are.
The quick check set is the safety net; run `python tools/run_checks.py --full tutorial_ai brain_spells route_check test_nav cross gate` after touching the brain.

- **Recording a person:** press F9 in a game to record (`PlayRecorder`, `tests/recorder_check.tscn`); F9 again stops. It writes `user://play_logs/play_*.log` (on Windows: `%APPDATA%\Godotpp_userdata\<project name>\play_logs`): K every key and mouse press, M the mouse, S the wizard ten times a second, G the ground about it, W every other wizard near, E creatures, spells, fires and pages near, X anything new in the world (a spell, with who cast it), C and R spells and chant words, D damage with everything within reach that could have caused it, N who fell. Compare a person's jump rate, waits and fight rhythm with the AI's before judging the AI human.
- **Play logs from network matches:** with the setting `share_logs` on (the default; Settings, "Share play logs"), a person in a network match is recorded from the start of each world (`net_*.log` in `user://play_logs`). When they are out or have won, `PlayRecorder.finish` packs the file (gzip) and `Net.send_play_log` sends it to the machine that keeps the game, which stores it in `user://received_logs/peer<id>_<name>.gz` (a different folder from the person's own, so a machine that hosts and plays never deletes what it keeps) and says so; the sender then deletes its file. A file left by a match that was cut short is sent at the next match. Read them with `gzip`; the line kinds are in `scripts/play_recorder.gd`. Test: `tests/log_upload_check.tscn`. The wording of the setting is a draft.
