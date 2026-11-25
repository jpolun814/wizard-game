# Every spell and chant in shared terms (draft for the owner, 2026-11-25; nothing is built from it yet)

The owner's aim (`23_movement_planning.md`, section 8): everything about a spell is in its data, the game runs on it, and an AI wizard reads it and works out how to use the spell.
This is the set of terms that data would be written in, tried on all 75 spells and 18 chants. Figures were read from the scripts, except where marked.

## 1. How a spell is written

A spell is one or more **parts**. Each part says **where** it acts, **when**, and **what it does**; and the spell says what it is **made of**. For example:

- **Ignite**: a shot at 700 px/s for 2 s: harm 5 heat, throw 420. Made of fire.
- **Supernova**: a place 170 px round, after 0.8 s, for 5 s, each half second: sets alight, pull; **then** a place 320 px round, once: harm 45 heat, throw 1700.

What follows from that is never written on the spell. Heat sets a body alight, water puts fire out and lightning hits the wet harder: those are laws (`Elements`, `Damage`, `Substances`), and stay so.

**What each state does** (slowed, frozen, dazed...) goes in one table of states, once each: pace, jump, may it cast, may it chant, harm taken and dealt, what it can see. Today those figures are spread
through `Wizard`. There are 22 states.

### Where

| Term | Meaning |
|---|---|
| `self` | the caster's own body |
| `with` | goes along with the caster, so wide |
| `ray` | along the stroke, the first thing met, at once |
| `shot` | a thing that flies, rolls or falls |
| `spray` | a cone out of the caster |
| `target` | whoever is under the drawing |
| `place` | where it was drawn (a spot, a line, a box, a column) |
| `world` | everywhere |
| `creature` | a thing that moves by itself |

### What it does

| Term | Meaning | Used by |
|---|---|---|
| `harm` | takes maximum stamina, of a kind (heat, cold, force, lightning, piercing, dark, blood) | 28 |
| `state` | puts a state on a body (a table of its own says what each state does) | 26 |
| `throw` | gives the body one shove | 15 |
| `heal` | gives maximum stamina | 10 |
| `floor` | leaves something to stand on | 5 |
| `light` | lights so far | 5 |
| `turn` | sends shots another way, or swallows or slows them | 5 |
| `tell` | shows the caster something hidden | 5 |
| `drive` | moves the body at a speed for a time | 3 |
| `pull` | keeps tugging while it lasts | 3 |
| `guard` | stops harm: so much, so many blows, or shots only | 3 |
| `clean` | takes states off | 2 |
| `solid` | leaves something that blocks | 2 |
| `slick` | leaves a slippery surface | 2 |
| `body` | gives the caster another body, with blows of its own | 2 |
| `likeness` | a false thing that looks real | 2 |
| `shake` | spoils aim and drawing | 2 |
| `break` | wears down walls and the like | 2 |
| `chance` | one of several, by odds | 2 |
| `breath` | acts on the air a body holds | 2 |
| `carry` | moves the body to a place at once | Shadow Step |
| `lift` | carries up while in it | Updraft |
| `climb` | leaves something to climb | Liana |
| `pit` | takes ground away | Sinkhole |
| `dark` | cuts sight to so far | Eclipse |
| `cover` | blocks sight through it | Smoke Screen |
| `bear` | lets the body stand something | Obsidian Armor |
| `fill` | stamina does not run down | Blessing of the Wellspring |
| `share_cost` | part of each cost falls on another | Leech |
| `revive` | brings back from death | Resurrection |
| `win_back` | returns harm just taken | Charm of Recovery |
| `per_blow` | gives something for each blow landed | Chant of the Bloody Needle |
| `relocate` | puts the caster somewhere random | Incantation of the Fool's Gate |

### Made of

`fire` `water` `ice` `wind` `lightning` `cloud` `plant` `rock` `shot` `light` `oil` (today's groups, named once): how the world's laws treat it.

## 2. The list

### Pyromancy

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Ignite | shot 700 px/s, 2 s: harm 5 heat; throw 420 | fire, shot |
| Firewall | place along the ground, 120 high · after 1 s, for 4 s, each 0.5 s: harm 2 heat | fire |
| Fire Breath | spray 110-230 px, 430 px/s · for 1.1 s, each 0.2 s: harm 3 heat | fire |
| Smoke Screen | place along the line, 48 px out · thickens 5 s, for 12 s: cover | cloud |
| Flare | with · until it falls or casts another: light 380 px *(wind puts it out)* | light |
| Spark | place from the sky down, 26 wide · at once; a roof stops it: harm 30 lightning *(14 more to all in the same water)* | lightning |
| Jolt | ray 520 px: harm 14 lightning; state hasted 1.5 s | lightning |
| Rocket Jump | self · for 1.5 s: drive up, 0 to 600 px/s |  |
| Flaming Sphere | shot rolls 170 px/s, climbs, 4300 px · each body every 1.5 s: harm 10 heat; throw 430 away, 430 up | fire, shot |
| Supernova | place 170 px · after 0.8 s, for 5 s, each 0.5 s: state burning 5 s; pull within 560 px **+** place 320 px · then once: harm 45 heat; throw 1700 |  |
| Cauterize | self · only if it can be lit: heal 55; state burning 5 s |  |

### Aquamagy

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Frostbolt | shot 600 px/s, 2 s: harm 10 cold; state slowed 2 s *(puts out a flame where it bursts)* | ice, shot |
| Icicles | place hung from a roof, 40-240 long · until melted, each 0.5 s: harm 6 cold | ice |
| Ice Prison | place box 24-160 px · at once: state frozen 4 s | ice |
| Blizzard | place from a line down · until put out: state slowed 2 s; state frozen after 5 s in it; floor snow, 2 px/s | cloud, water |
| Frost Bridge | place along water · 30 s or melted: floor; slick **+** place along level ground · 25 s or melted: slick | ice |
| Geyser | place on ground, 46 x 190 · after 0.7 s, 1.8 s, rests 1.2 s, for good: throw up 1000; harm 1 cold each s *(a scald is heat in life; today its kind is cold, from its school)* | water |
| Hailstorm | place under a line · for 4.5 s, a stone each 0.07 s: makes the next part **+** shot falls 640 px/s: harm 5 cold | cloud |
| Tide Surf | self · for 2.5 s; steep ground ends it: drive along 470 px/s; floor on water **+** with 80 px in front · each body every 0.8 s: throw 620 on, 260 up | water |
| Bathe | self: clean all but ice and breath; state wet 8 s | water |
| Healing Spring | place on ground, 34 px each way · rest of the world: heal 2 each s | water |
| Water Jet | spray 220-420 px, 980 px/s · for 1.4 s, each 0.1 s: drive away 760 px/s; state wet 8 s | water |

### Aerokinesis

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Barrier | self · for 6 s: guard all shots *(pushes off insects too)* |  |
| Push | place circle as drawn · once: throw 1120 along the line; turn shots | wind |
| Tornado | place on ground · for 6 s, each body every 1.2 s: throw up 640-800, 560 to a side; turn shots back *(takes fire from a flame: harm 4 heat each 0.5 s)* | wind |
| Vacuum | target within 90 px · up to 14 s; caster casting or hurt ends it: breath held, then choking 3 each s |  |
| Updraft | place column 70 x 520 · rest of the world: lift 2700, at most 420 px/s |  |
| Gust | place along the stroke, 340 x 130 · for 0.7 s: throw 434 sideways; turn shots along it | wind |
| Featherfall | self · for 15 s: state featherlight: falls at most 70 px/s |  |
| Headwind | with 170 px · for 12 s: state slowed while in it; turn shots to 0.4 speed |  |
| Thunderclap | with 230 px · once: throw 336, less far off; state dazed 4 s |  |
| Dancing Lights | with 24-90 px · for 25 s: light 150 px each | light |
| Breathe | self · for 10 s; a blow ends it: heal 3 each s |  |

### Terramancy

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Stonefall | shot falls from the drawing: harm speed / 24, at most 100, force; break 60 **+** place where it lands · until worn (63): solid, rolls | rock, shot |
| Stone Wall | place along the stroke, 60-240 long · until worn (0.45 a px): solid | rock |
| Mudslide | place on ground, 60-240 wide · until baked dry: state mired while in it |  |
| Earthquake | world on the ground · for 6 s, each 0.4 s: throw 160 side to side; shake; break 12; stone walls fall at 1 s |  |
| Stalagmite | place on ground, 40-200 tall · rises 0.3 s, for good, each 0.5 s: harm 6 force | rock |
| Sinkhole | place on ground, 50-130 each way, 56-120 deep · after 0.9 s, for good: pit |  |
| Obsidian Armor | self · for 20 s: guard half of shots; bear heat and lava; state heavy: 0.75 pace |  |
| Golem | self · after 1.15 s, for 10 s: body 0.5 pace, 0.7 jump, takes half; blows 40 and 80; shake; throw on landing, 220 px |  |
| Mud Mask | self · for 20 s: heal 2 each s |  |
| Oil Slick | place on ground, 70-300 wide · 60 s; water ends it: slick; state oiled 10 s *(fire law: burns 4.5 s when lit)* | oil |
| Pebble | shot 1050 px/s, drops 760, 2.5 s: harm 5 force | shot, rock |

### Druidry

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Barbs | shot 560 px/s, 0.8 s, 5 across 0.5 rad: harm 4 piercing each | plant, shot |
| Bramble | place on ground along a line, 34 high · until burned, each step (0.3 s): harm 8 piercing; state tangled while in it | plant |
| Flytrap | place on ground, 28 px · waits 60 s; one body, 3 s: state swallowed 3 s; harm 8 piercing, 3 times; throw out 280, 240 up | plant |
| Glowcap | place on ground · for 60 s: light 300 px **+** place 20 px · once, whoever touches it: heal 1 | light |
| Great Oak | place on ground · grows 0.8 s, until worn (220): floor ledges 60, 224, 312, 424 px up **+** place where it falls, 88 wide · after 1.3 + 0.9 s: harm 35 piercing; throw 360 | plant |
| Insect Plague | creature hunts the nearest within 520 px, 0.85 pace · up to 20 s; one hit ends it; each 0.66 s: harm 2 piercing |  |
| Liana | place on ground · until burned: climb 90-420 px | plant |
| Lily Pads | place on water under a line · for 8 s: floor | plant |
| Spore Puff | spray 110-230 px, 260 px/s · hangs 4.5 s, each 0.5 s: harm 8 piercing; state tangled 1 s | cloud |
| Thorn Whip | ray 380 px · after 0.12 s, up to 0.7 s: harm 8 piercing; throw 950 to the caster; pull 4200, to 60 px off | plant |
| Wild Shape | self · until one blow: body 1.25 pace; a blow of 12; no spells |  |

### Umbramancy

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Black Hole | place · at once, for 5 s: pull 4500 at the middle, fades by 2600 px; turn: shots within 120 px swallowed |  |
| Decoy | creature walks as told, 170 px/s · for 24 s or worn (40): likeness of the caster |  |
| Eclipse | world · for 6 s: dark 90 px |  |
| Eldritch Blast | ray 640 px: harm 16 dark |  |
| Hex | target within 70 px: state hexed 30 s: takes 1.5 of harm |  |
| Mirage | place · for 30 s; anyone within 96 px ends it: likeness of a page |  |
| Moonbeam | place column 64 x 700 · for 30 s: light 230 px | light |
| Shadow Step | self: carry along the stroke, at most 300 px **+** ray the way it went, 24 px: harm 8 dark |  |
| Silence | place 200 px · for 12 s: state silenced while in it |  |
| Sneak | self · 20 s; casting ends it: state invisible |  |

### Necromancy

| Spell | What it does, in the terms | Made of |
|---|---|---|
| Adrenaline | self: state adrenaline 10 s: deals 1.5, takes 0.6; state hasted 10 s |  |
| Crimson Veil | self · until used: guard 2 blows |  |
| Faint | target within 70 px: state unconscious 4 s |  |
| Fight or Flight | target within 90 px: chance half and half; state confused 6 s; state fleeing 6 s |  |
| Hemorrhage | target within 80 px · for 8 s, each 1 s: harm 5 blood; state drained while it bleeds |  |
| Hunter's Mark | self · for 20 s: tell the way to the nearest wizard |  |
| Immortal Snail | creature hunts the one it was drawn over, 50 px/s · for good, across worlds: harm kills |  |
| Leech | target along the stroke, 460 px · up to 24 s; out of sight or reach ends it: share_cost half |  |
| Raise Dead | creature a skeleton (50), serves the caster · until killed, or the caster falls: harm its own blows |  |
| Scythe | place half circle in front, 170 px · at once: harm 45 blood; throw 260 |  |

### Chants

| Chant | What it does, in the terms |
|---|---|
| Rite of the Land | self: tell a map of the world |
| Chant of Insight | self: tell how strong creatures are and what wizards know |
| Blessing of the Wellspring | self · for 20 s: fill |
| Blessing of Skystep | self · for 20 s: state extra jump |
| Incantation of the Fool's Gate | self · costs 35 max stamina: relocate |
| Charm of Swift Feet | self · for 20 s: state hasted: 1.6 pace |
| Blessing of the Deep Breath | self · for 45 s: breath held |
| Chant of Dowsing | self: tell the way to a page |
| Chant of the Scrying Eye | self: tell what another wizard sees |
| Charm of Darkvision | with · until it falls: light 380 px *(nobody else sees the light)* |
| Charm of Mending | self: heal 5 |
| Psalm of Rest | self · until it moves or casts: heal 3 each s |
| Charm of Recovery | self: win_back the last 10 s, at most 40 |
| Chant of the Bloody Needle | self · for 30 s: per_blow heal 3 |
| Chant of the Cast Die | self: chance 3 in 4; heal 30; harm 30 |
| Long Rest | self · until whole; a blow ends it: state asleep; heal 12 each s; clean all but a curse and a snail |
| Resurrection | self · until used: revive at 30%, at the last safe place |
| Prayer of Restoration | self: heal up to 120, by how well it was said |

## 3. What the exercise showed

1. **It fits.** 9 wheres, 33 effects and 11 materials describe all 93. 20 of the effects are shared by two or more; 13 are used by one spell or chant only. Those 13 each need one law and one way for the AI
   to value them, and are then free for any later spell.
2. **The hardest to fit:** Fight or Flight (a body that casts at random), Immortal Snail (hunts across worlds), Wild Shape and Golem (a body with blows of its own), Leech, Mirage, Decoy (walked by its
   caster) and the chants that deal with the past (Recovery, Second Chance, Stitch). They can be *described*; their behavior stays a script, which the data names.
3. **Seven `warning` figures are not facts, and must NOT simply be corrected** (checked 2026-11-25). Scythe (0.3), Spark (0.35; really 0.05), Ice Prison (0.4), Black Hole (0.8), Thunderclap (0.3), Silence
   (0.3) and Fight or Flight (0.3) strike at once or nearly (so do Tornado and Bramble, and Flytrap takes 0.5, not 0.3). But the chance to land is worked out from the delay alone (`SpellFacts.chance`), so these
   made-up delays stand in for missing. Measured in the owner's 15 matches, AI casts: Spark landed 23% (the AI expects 65%; with the true delay it would expect 94%), Ice Prison 54% (expects 61%, would expect
   100%), Scythe 69% (expects 69%, would expect 100%), Eldritch Blast 52% (it has no delay, and the AI expects 100%). A warning of 0 would also put Spark out of `SpellFacts.known`. What is missing is the
   time a stroke takes to draw and the size of what must be hit, which hold for every spell; put those in first, then make the delays true.
4. **Some are opinions, not facts:** `hold` and `share` for Mudslide, Tornado, Blizzard, Black Hole, Sinkhole and Bramble, `span` for Insect Plague, Stalagmite and Healing Spring, `absorbs` for Decoy and Headwind.
   These guess what will come of a spell. The AI should work that out from the facts.
5. **Small disagreements to settle:** Supernova did its own harm on top of the burn while it hung; the owner (2026-11-25): it only burns until it explodes (done; the page's 6 dmg/sec is right). Flytrap: 3 bites of 8 is 24, and 9 dmg/sec for 3 s says 27.
   Geyser's scald is of the cold kind. Mudslide's comment says it hurts, and it does not. The comments of Hemorrhage, Ice Prison, Mudslide and Decoy describe old gestures.
6. **Chants have no data at all**: their durations and amounts are in `Rituals.grant` and `Mending`, and the spellbook's lines are kept elsewhere.

## 4. What the AI then needs, once each and not per spell

- **To value an effect:** harm, heal, guard and lost time in one currency; a state by what its table says it takes away; light by whether it is dark; `tell` by whether it lacks that knowledge.
- **To place a part:** each *where* has one way to be aimed (a shot leads its target, a place goes under where they will be, a ray needs a clear line).
- **To move:** `carry`, `drive`, `throw`, `lift`, `floor`, `climb`, `pit` and `bear` are the movement vocabulary of chapter 23.
- **To combine:** from the laws (wet and lightning, oil and fire), looked up and not listed by pairs.

## 5. The order

1. The owner reads this list. 2. The states table and the spell parts as data, read by tests only. 3. Movement (chapter 23). 4. The chance to land: drawing time and the size of the thing, and then the true delays (section 3).
5. Then attacks, control, defense, heals and chants, one kind at a time, each compared with the old way. The measure throughout: spell names quoted in `scripts/brain` (643 today) only ever go down.
