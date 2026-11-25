# How an AI wizard works out how to move (2026-11-25; the design, and from section 9 what is built)

**What the owner asked for:** no tricks written spell by spell ("feels like this is cheating... rather than actually teaching it how to use the spells"), and no
crossings that "have to be explicitly stated in the world rather than just a function of how the AI brain works". All movement, not only crossings.

**The goal in one line:** a wizard knows what its body and its spells can do, sees the ground, and works out for itself how to get where it wants to be.

## 1. Why it cannot do that now

| Today | Where | What is wrong |
|---|---|---|
| The map knows a step, a fall, a jump, and the climbs and lifts it is handed | `Walkways.moves`, `WorldNav.build` | no spell is in it |
| The world generator names each obstacle (`chasm`, `flood`, `wall`...) and a table says which spells pass it | `WorldBuilder.CROSSINGS` and `shut`, `WizardBrain.WAYS` | an obstacle nobody named cannot be passed at all |
| Each lift, leap and wade has code of its own | `BrainMoves`, `BrainGates.cross`, `_hop_up_the_stairwell` | a new spell needs new code |
| How far a spell carries is typed in by hand | `LIFT_REACH`, `LIFT_STAND`, `DOUBLE_JUMP_REACH`, `PADS_REACH` | wrong the day the spell is retuned |
| Thorns and lava are "lethal" or not | `BrainDanger.lethal_at`, `barred` tiles | the jungle freeze: a wizard stood still for a whole world before thorns |
| Getting up to a rival is a separate list from getting over a wall | `BrainCombat.chase`, `ready_lift`, `LIFTS` | the same question, answered twice |

## 2. The four parts

**A. What each spell does to a body: in the spell's own data, read by the game and the AI alike (owner, 2026-11-25: "can't it just intuit that from the spell data?").**
Today it cannot: `rocket_jump.tres` says only what it costs, and the numbers that lift a body are constants in the scripts (`RocketJump.BURN` and `TOP`,
`Updraft.LIFT`, `Geyser.WIZARD_LAUNCH`, `Tornado.FLING_UP`, `SpellData.STEP_MAX`). So each movement spell's data says what it does in a few shared words, about:

| It... | Numbers | Spells |
|---|---|---|
| carries the body along the stroke | how far | Shadow Step |
| drives the body up, or along | speed, how long | Rocket Jump, Tide Surf |
| throws whoever is in a place | speed and way, when | Geyser, Push, Tornado |
| lifts whoever stays in a place | pull, top speed, width, height | Updraft |
| changes how the body moves for a time | fall speed, pace, jump, how long | Featherfall, Wild Shape, Haste, double jump |
| leaves something to climb or stand on | size, how long to grow, how long it lasts | Liana, Great Oak, Frost Bridge, Lily Pads, Stone Wall |
| lets the body bear something | what, how long | Obsidian Armor, Deep Breath |

**The game moves the body from those same numbers**, by one law for each row, and the AI works out the path with the same law. Nothing is written down twice, so retuning a spell
retunes the AI. A new spell made of these words needs no AI code; a new kind of motion needs one new law, which game and AI then share.
A check casts each one for real and compares where the body went with where the law said (it was first planned that a tool would *learn* the numbers that way; now it only checks them).

**B. Where that gets it from here (`MoveReach`).** Lays the path that the law gives over the ground, stops it at rock, and gives where the body ends, when, and at what cost. It
starts from standing or from mid-air, so "jump, then step, then step" is not written anywhere: it is this question asked three times. A walk and a jump are moves like any other.

**C. The cheapest way (`MovePlan`).** One search, over ground the wizard has seen and the spells it holds. **The price of everything is seconds:**
- time to walk, fly, draw the stroke (a person's drawing time), or wait for a stair (6 to 12 s at a landing: it knows only what it has watched);
- stamina, as the seconds it takes to come back (`WorldNav.JUMP_COST` already works this way);
- harm, as seconds, dearer the more worn down the wizard is. Thorns and lava become a price, and a wizard pays it or goes round.

So "wait for the stair or go up some other way" needs no patience timer, and "burn the thorns or walk through them" can become the same sum.

**D. Doing it (`MoveDo`).** Walks to the spot, draws the stroke, steers, and compares where it is with where the path said it would be. Off by more than a little: it plans again,
in the air if need be. The stroke is made from the spell's own picture and its `targeting` (at the feet, along a line, ahead), so a spell of a kind we already have needs no code.

**Who asks:** travel and exploring (get there), the chase (get to them), backing off and fleeing (get where they cannot easily follow), dodging (out of this spot in time),
getting out of a pit. All of them call C.

## 3. What stays as it is

- **The limits of a person** (`18_human_limits.md`): only ground it has seen (inside the search, not checked afterwards), one stroke at a time, drawing and reaction times, no peeking
  at a stair's schedule.
- **The generator's gate labels**, to know that a world can be finished and which pages to lay. The AI stops reading them. (`Pages.openers_of` reads the AI's `WAYS` and
  `CLEARS`: those lists move to `Pages` before the brain's copies go.)
- **What a hazard does**: today each answers only `danger_at(point)`, yes or no. Each must also say how much it hurts and slows, by the same kind of law (`harm_at`), not by a list.
- **Strokes**: a new gesture shape or a new `targeting` still needs its drawing taught.
- **Swimming and flying** (`swim`, `SkyBrain`) come last, if at all.

## 4. How we know it worked

1. **A spell it has never met:** a test makes up a movement spell out of data, with no AI code, and the AI uses it to reach a page.
2. **An obstacle nobody named:** random gaps, ledges, pits and stairwells, random movement spells. Wherever a way exists by the laws of section 2A, the AI gets there.
3. **It says no when it should:** no way, or not enough stamina, and it goes elsewhere and does not stand still.
4. **The owner's own games:** castle seed 10042159 and jungle seed 6337254: share of time standing still, before and after, over many runs (games are not repeatable).
5. **`ai_trial.py`**, with nothing else running and no file edited while it plays.

## 5. The order, each stage stopping at a gate

| Stage | What | Gate before going on |
|---|---|---|
| 0 | The tests of section 4, written first | they fail today, for the right reason |
| 1 | The movement data and its laws, the game's movement spells moved over to them, and the check against real casts | every movement spell feels and measures the same as before (positions recorded before and after); the owner sees the list |
| 2 | `MoveReach` and `MovePlan`, not yet in the brain | tests 1 to 3 pass on paper; **the cost in milliseconds is measured with eight wizards** |
| 3 | `MoveDo`, and travel and exploring use it (switch `movement`) | tests 1 to 4 in play; full suite; AI drills |
| 4 | Hazards as prices | the jungle no longer needs a rule for thorns |
| 5 | Chase, flee, dodge, pits | `ai_trial` not worse |
| 6 | Delete `WAYS`, `LIFTS`, `LIFT_REACH`, `BrainMoves`' special cases, the stairwell hop | everything green with the old code gone |

Until stage 6 the old way stays behind the switch, so each stage can be compared with it and nothing is lost if one fails.

## 6. What could go wrong

- **Speed.** The present search is native and shared by all wizards; this one differs per wizard. The plan: walk with the native search, and try spells only at the edge of what
  walking reaches. Stage 2 measures it, and if it is too slow the design changes there, before the brain depends on it.
- **Moving the spells onto shared laws touches the game, not only the AI.** Done one spell at a time, with its path recorded before and after.
- **The real body is not the predicted one.** Wind, a slope, a slow, a blow in the air. That is why D watches and plans again.
- **Spells whose effect depends on the place** (a vine needs ground, an oak headroom, a Push is drawn to any size). Some will be approximate.
- **Harm in seconds is a judgment** that sets how bold the AI is. It is one number, tuned by `ai_trial`, not one per spell.

## 7. The owner's answers (2026-11-25)

1. Harm taken on purpose to save time (a few thorns, shallow lava): "yeah sure sometimes".
2. Spells spent on travel, with a reserve kept when a rival is about: "yeah sure sometimes".

So neither is a rule: both come out of the prices (health left, stamina left, whether a rival is near), and differ from one moment, and one wizard, to the next.

## 8. Where this is going: every spell, not only movement (owner, 2026-11-25)

"Every single piece of information about an individual spell to be in that spell's data so that it's scalable and so that AIs can just look there to learn about the spell and how to use it
rather than run trials to learn about it or go digging around the place... we just say 'here's a new spell and all its info'."

- **Data** holds everything true of one spell: what it does, how much, how far, how long, where it is cast, what stops it. **Code** holds only the laws, each written once for all spells, and
  how a spell looks and sounds. The game and the AI read the same data; no figure is kept twice (`speed`, `warning` and others are copies of script constants today, kept equal by
  `tests/unit/spell_facts_test.gd`).
- **The measure, to be made a check that may only go down:** spell names quoted in `scripts/brain`. On 2026-11-25: 643, on 305 lines, all 75 spells (264 in `brain_combat`, 180 in
  `wizard_brain`, 78 in `brain_hand`). 30 of the 75 spells have no figures in their data at all. The goal is none, and no gaps. Chants are the same job (`RitualInput.RITUALS`).
- **What data cannot give:** a kind of effect no spell has had before needs one new law, and the AI one way to value it; after that every spell of the kind is free.
- **Movement is the first slice**, since it shows most in play. The words for describing an effect are to be drawn up for all 75 first, so movement is not done in a form the rest do not fit.

## 9. Stage 0, done (2026-11-25): the tests that fail today

- **`tests/checks/movement_drills.tscn`** (24 drills, run by hand for now, not in the suite: most are meant to fail until stage 3). Bare rooms with gaps, ledges, pits, a loft over open air and thorns, a page, and
  the spells named; nothing labelled. A script with the real body and spells proves that 22 have a way (the other two have none, and the AI must refuse them). **The AI passes 5 of 24**: walking, jumping, three
  columns of thorns, and the two it must refuse. In all 19 it fails it stands still 97 to 100% of the time with no goal. With `labelled=1` (the room names its pits and faces, `RoomScan`) it passes the same 5. Why it
  does no better there was not looked into; the rooms of the game, whose labels are used (`tutorial_ai_check`), are built differently.
- **`tests/unit/brain_names_test.gd`**: spell names quoted in `scripts/brain` may only go down from 643 (shown to fail when the limit is lower).
- **`tools/still_share.py`**: the share of time AI wizards stand still, from logs or from worlds it plays. Baselines: the owner's 37 worlds of 2026-11-24, before any change: castle 47%, jungle 45%, all 26%.
  Simulated, 120 s, 4 times each, with the map fix of `22` in: castle (seed 10042159) 34% still, 21% for nothing, longest 52 s; jungle (seed 6337254) 42% still, 27% for nothing, longest 97 s.
  So **the map fix did not end the standing still** (a 60 s run once made it look so). The two sets are not a before and after: they differ in seeds, length and who plays.
- Not written yet: the made-up spell (it needs the data's form) and random rooms (they need the laws, to know which have a way).
- Learnt on the way: a Shadow Step drawn at 72 degrees is not read as one (55 is), so how steep a stroke may be is part of what a spell's data must say; ground is rounded at its edges, so the last column before a drop
  slides a body in.

## 10. Stage 1, first part (2026-11-25): the movement of 17 spells is in their data

- **`Spell.parts`** (the `.tres` files) holds it, in the terms of chapter 24: Shadow Step, Rocket Jump, Featherfall, Updraft, Push, Gust, Geyser, Tornado, Tide Surf, Liana, Great Oak, Lily Pads, Stone Wall, Sinkhole,
  Wild Shape, Golem, Obsidian Armor. `Spell.effect_of(term)` gives an effect with its part's where and when. **`Motion`** (`scripts/spells/motion.gd`) is the laws that turn the numbers into movement: the
  game moves the body by them, and the planner is to predict by them. **`BodyStates`** (`scripts/wizard/body_states.gd`) says once what each state does to how a body moves. The scripts' old names for these figures
  (`Geyser.WARNING`, `SpellData.STEP_MAX`, `Wizard.FEATHER_FALL`...) are read from the data: tests and the frozen brain still use them.
- **Checks:** `movement_paths_check` (quick set): 72 paths, recorded before anything was moved over, all the same after; it notices a change of 1%. Where a spell is *meant* to move differently: run it with
  `update=1 only=NAME` and look. `tests/unit/spell_parts_test.gd`: every part is in the shared terms with the numbers it needs. Changing one number in the data was shown to change the play of eleven spells.
- **The full suite:** 150 checks, one failed (`movement_paths_check`, for Tornado, whose throws hung on other dice; the check now sets its dice, and was recorded again from the old script; it passes).
- **Left of stage 1:** Frost Bridge, the chants that move (double jump, haste), what pulls and drags (Black Hole, Supernova, Thorn Whip, Water Jet, Thunderclap, Flytrap), how steep a stroke may be, and what is thrown
  other than a wizard (recorded nowhere yet). What Great Oak, Lily Pads, Stone Wall and Sinkhole leave is not in the recorded paths.
- **Found on the way:** an AI asks for a pace of 300 (`WizardBrain.WALK_SPEED`), and `Pad.walking` holds it to that, so Haste, Adrenaline, Jolt and Wild Shape make no AI faster. To be mended by the planner, which must
  ask for what the body can do; a jump's reach is worked out from the speed, so it is not a matter of changing the constant.
- **Second part, the same day:** Frost Bridge (two parts: on water, on ground), Skystep and Swift Feet (`RitualInput.RITUALS[id]["parts"]`, `RitualInput.effect_of`). How steep a flick may be is no spell's own: within 20
  degrees of upright a straight stroke is Moonbeam's on the Umbramancy buttons (`StrokeReader.straight_means`, which the game and the planner both ask). How a body falls, steers in the air and sheds a shove is in `Motion` too.
- A static figure read from the data must not be read through a script that itself reads the data as it loads (`IceSheet` through `FrostBridge`), nor may `Spell` or `Motion` reach into the arena's scripts: the spells then
  load before their own script has, with no parts.

## 11. Stage 2 (2026-11-25): the planner on paper, not yet in the brain

- **`MoveMap`** (`scripts/brain/move_map.gd`): the ground as tiles, the moves on foot, the edges of floors, and `edges`: what each spell does from each place, worked out once and kept for all the world's wizards.
  **`MoveBody`**: a body pictured moving by `Motion`'s laws. **`MovePlan`**: the search. Nothing in them names a spell. `work(units)` goes on a little at a time; the work is counted, not timed, so that the game stays
  the same on every machine.
- **Checks:** `tests/unit/move_body_test.gd` sets the pictured body against the real casts recorded by `movement_paths_check` (walk, jump, drive, lift, throw, carry, slow fall: within 26 px, up to 70 late in a Geyser's fall,
  where the real one is a little higher). `tests/unit/move_plan_test.gd`: **all 24 drills right** (a way in 22, none in the two refusals); a spell made up in the test is used, and refused when too weak; only seen ground; prices.
  **A way on paper is not a way walked**: that the real body can follow it is what stage 3 proves.
- **In real worlds** (`tests/tools/plan_cost.tscn`, places wizards start to one of the four nearest pages, four random movement spells): a way in every one of 24 plans in each of six biomes and the two castle seeds; on foot alone
  9 of 24 and 7 of 24 in the castles (no stairs in this map yet: it is tiles only). Lava and thorns are not in the map yet either, so "on foot" in the open worlds may cross them.
- **Cost.** At first 4,400 ms a plan. Now in the open worlds median about 10 to 20 ms, worst about 230; in the castle median about 200 to 260 ms, worst about 1.1 s; the same thought again 40 ms. The longest single slice asked to be
  a millisecond: 6 to 7 ms, most far less. So with 2 ms a frame shared by eight wizards, a castle's first thoughts take some seconds and later ones a few frames.
- **What the planner does not use yet:** what leaves a floor (Great Oak, Lily Pads, Frost Bridge, Stone Wall) or a pit, what drives along the ground (Tide Surf), other bodies (Wild Shape, Golem), what throws to a side by chance
  (Tornado) or only ahead (Gust).
- **To come in stage 3:** stairs, vines and other moves the world has (`links`, `climbs`) with the wait for them as a price; hazards as a bar until stage 4 prices them; planks; the map kept right when ground is dug or walls raised.
- **Found on the way:** `tests/tools/ai_arena` ignores `biome=` and `mode=duel`'s choice of a flat world: `World` begins the match anew, which clears `MatchState.forced_biome` (asked for jungle and for ashlands, got a castle both
  times). So the duel trials of `ai_trial` were fought in whatever world the seed gave. And an AI wizard hops at a seam in level ground now and then (recorded after a Shadow Step).

## 12. Stage 3, first part (2026-11-25): an AI wizard goes by its plans

- **`MoveDo`** (`scripts/brain/move_do.gd`, `brain.go`) thinks (a little each frame), walks the legs on foot with `WizardRoute`, stands, draws, leans over at the height the plan said, and thinks again when it comes down
  elsewhere (`MISS` in a match log says why). A stroke is made from the spell's gesture and how it is aimed. The switch is `movement` (`AI_OFF=movement`). `WorldNav.ground()` is the map (made when first asked for; `World`
  says what is in it, without the floors the old map pretends over crossings), with the world's own vines and stairs, a stair reckoned at 12 s of waiting.
- **Asked when:** no page can be walked to (`BrainTravel.take_to_its_spells`), and when it is held up on its way by a stair or by danger (`_take_another_way`). Not yet: choosing where to explore, the chase, fleeing, pits.
- **The drills: 23 of 24** with the real body (5 before), with each of four sets of dice, though they were looked at while it was made. `loft: Shadow Step` fails: its proof draws strokes at once, and at the speed a stroke is drawn, with the view sliding, it may
  not be possible. The planner knows that limit (`_steady`: the same measured figures as `BrainHand.drag_ok`).
- **In real worlds it has not yet cut the standing still.** Castle and jungle, 3 matches of 120 s each, the same dice on and off: still 37% and 35%, for nothing 24% and 24%; pages read 322 and 309; falls
  7 and 9: no difference that means anything. Why, seen by replaying the very moments: **(1)** in the castle those who stand at a stair mostly hold nothing that would get them up it (Tornado, Featherfall, Tide Surf or nothing), and a stair that swings among
  two or three landings, 6 to 12 s at each, may be away for 30 s; **(2)** in the jungle they stand before **ponds of piranhas** on their way: the old map's way goes through the pond, the danger check will not let
  them in, and they hold nothing to cross it with; **(3)** one hangs on a vine for 40 s (`climb_hang`).
- **A bug mended on the way** (`leapover`): a leap over thorns was never made, because the danger check saw them ahead, backed off, and the jump was already marked as made (`WizardRoute.leaps_over`). It did not change the figures above.
- **Next:** a price on harm (stage 4), so that a pond or thorns is waded by one who can afford it and no way is planned through one who cannot; exploring by what can be reached with the spells held, and by the stairs that stand
  ready in sight; the vine.

## 13. The measuring tools were not doing what they said (mended 2026-11-25)

`MatchState.begin` cleared `forced_biome`, so `ai_arena`'s `biome=` and the flat worlds of `mode=duel` did nothing, and `soak_check` played portals for graveyard and sky, jungle for castle, and ashlands for ocean. Now `MatchState.first_biome`
says where the next match begins. `soak_check` passes in all nine. **Duel trials before this day were fought in whatever world the seed gave.**

## 14. Stage 4: harm on the way, what ends it, and the top of water (2026-11-25)

Nothing here pairs a spell with a thing. A thing in the way says what it does; a spell says what it is made of; the planner puts the two together.

- **Perils** (`scripts/spells/perils.gd`). Anything that harms or hinders whoever goes through it answers `peril_at(point)` (`harm` a second, `pace` kept, `jump` false where it holds a body, `after`: what it loses for having got in at all, `kind`), `peril_box()` and `undone_by()` (the stuffs that end it). Thorns, piranhas, spikes, gas, lava ponds and mud do. A new one answers the three and is in one of the groups `danger`, `shoals`, `perils`, `ponds`.
- **Spells** have `made_of` (from chapter 24) and, where they reach somewhere, a part with `{"do": "touch"}`. An `undo` leg casts whatever is made of a stuff that ends the thing.
- **The price.** A harm costs seconds (`MovePlan.HARM`, dearer the more worn), and a crossing may cost at most a share of all it has that depends on what it is for (`MoveDo.WORTH`) and grows while it is held up (`balked`). What is begun is finished unless it hurts far more than reckoned.
- **Rides.** A spell that lays a floor over water (`floor`, `needs: water`) or carries one along (`with`, `over: water`) gives a `ride` leg. A laid floor is drawn a stretch at a time (what is on the screen), priced at its drawn size.
- **Getting out** (`MoveDo.get_out`): the nearest harmless standing place, by any means, for 2.5 s, and then the old reflex has it. Letting the plan answer before the reflex was tried and was worse (63 bites against 34): do not repeat it.
- **Laws made general on the way:** lightning shocks what lives in water and lights plants (`Elements.lightning`), so Jolt does as Spark does; an unseen pool has a level (`Pond.level_at`), so an AI off the person's screen can grow Lily Pads.

**What the measurements taught.** A goal at the bottom of a pond was the cause of nearly all the worst bites (it "arrived" there). A body slowed by water was thought to leap nine tiles. Wizards stood on branches of great trees that the map of the ways has not got, straight over their next step, for ever: they drop now (`WizardRoute.steer`). A wizard jammed in rock and struggling is put back where it last stood (`Wizard._get_out_of_rock`); it must never move one that stands quietly (the world's tiles call some open ground rock: it yanked a person's wizard in `raise_dead_check`).

**Final figures** (castle and jungle, four matches each, for nothing): castle 24% to 9%, jungle 27% to 13%. Bites 24 against 34, pages 487 against 441, falls 27 against 19. On a fresh sample (seeds 521 to 524, eight matches each way, 2026-11-25) falls were 18 and 18, bites 5 against 19 and harm from the world's thorns 460 against 1070, so the first difference was chance. Thorns say `still: 0` (they prick only a walker): a wizard that stands in them keeps quiet and thinks, rather than bolting (one lost 192 in two seconds to four stacked thickets of its own). **Something to stand on, leapt from** (later that day): a slab raised as the stroke leans (Stone Wall: a ramp at 36 degrees, or a plank over a gap) and a branch no more than 112 px up (Great Oak) are mounted and leapt from (`MovePlan._stand_on`, `MoveDo._mount`). Left out on purpose: Gust (a shove too weak to carry anyone), Sinkhole (a pit with a floor), Wild Shape (one-hit health for a pace the AI's walking cannot use) and Golem (half harm at half pace is no gain, and it jumps low). A stroke that says only which way and how far is drawn where it fits on the screen (`MoveDo._on_its_screen`): that was the whole of the failing drill "loft: Shadow Step". All 50 drills pass.
