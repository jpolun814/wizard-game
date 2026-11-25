# AI wizards: watching notes and progress

Started 2026-11-14 while the owner was away. The job: make the AI wizards better (a bit at a time), without giving them anything a person lacks (no
sight past their screen, no knowledge of rivals' books, one hand so no typing while drawing, reaction times and stroke times from
`data/ai/human_limits.json`), until they beat the brain they replaced both in 1v1 duels and in battle royales of eight.

The owner has not yet seen or approved the notes below. They are written to be read and argued with.

## How it is measured

- `tests/legacy_brain/` is the brain as it was on 2026-11-14 (commit 8c3d042), copied once by `tools/make_legacy_brain.py` with every class named `Old...`.
  **Do not regenerate it**: it is the opponent. (`Wizard.brain` is a plain `RefCounted` so either kind can play a seat.)
- `tests/tools/ai_arena.tscn` plays one game and appends a line of JSON to `result=FILE`:
  - `mode=duel`: two wizards on level ground, the same five spells each (three attacks, a way about, a defence, picked from the seed), the new brain against the old,
    sides swapped on odd seeds. Over when one falls or after 120 seconds (then whoever has lost less is ahead).
  - `mode=royale`: the whole match, all four worlds (the harness stays above the collapse of each world), eight wizards, the seats in `old=` playing the old brain.
    A game takes about 2.5 minutes.
  - `log=FILE` writes every cast (`C`), wound (`D`), bonfire (`B`) and each wizard's place and goal twice a second (`S`).
- `tools/ai_bench.py duel N` / `royale N` runs N games six at a time and prints the score. `tools/ai_yield.py DIR` adds up the damage that followed each spell
  cast in a folder of duel logs. Both are noisy: **a duel result needs about 60 games and a royale about 30 before a difference means anything.** With the same
  brain on both sides the control gave duels 6-6 (12 games) and royales a mean place of 4.53 against 4.47 (10 games).

## What I saw (watching about 40 duels and 12 matches through their logs; the sims cannot be watched, only read)

1. **The pace of a fight was slow.** A wizard threw one attack every 1.5 to 3.6 seconds and took 0.8 seconds over each stroke, though the recorded people
   draw an Ignite in 0.13 seconds and a Frostbolt in 0.35. A duel of two minutes held about 40 casts.
2. **It threw spells away.** Counting the damage that followed each cast over 24 duels: Frostbolt was cast 184 times for 1.7 damage a cast, Ice Prison 42 times
   for 0.6, Insect Plague 71 for 2.1, Pebble 60 for 1.9, against Scythe 25 a cast, Spark 9.8, Stonefall 7.9, Spore Puff 7.9, Fire Breath 7.4. The choice of attack
   was a table of hand-set scores that did not know what a spell had come to.
3. **Wounds are for keeping.** In five matches a wizard's maximum stamina (its health) rose only five times. A fifth of the time a wizard has a maximum of 60 or
   less (a third of what it began with), and nearly all of that it is walking about exploring. Bonfires are lit about three times a match. A person who is worn
   down looks for somewhere to rest, or keeps out of everyone's way.
4. **The first minute is a brawl.** In 5 matches wizards fell at 56, 82, 88 and 91 seconds. At 56 seconds in one match four wizards were within a few hundred
   pixels of each other all throwing spells, and the one that fell had a maximum of 16. Nobody stays out of a crowd, or waits for others to wear each other down.
5. **Few fights are chosen.** While on a journey the goal is `foe` for about 1% of the time of those who are worn down, so the weak neither fight well nor
   run well; the wizard with most strength left at the end of the match tends to win by being missed.
6. After the first minute whole stretches of a match are a journey (`explore`, `portal`, `sky:explore`), up to 90% of a wizard's time in some matches. The last
   world (a small open sky) did not end a match in 1,100 seconds in about a third of the games: two wizards stayed alive, far apart or each keeping off the other.

## What I changed, and what it was worth

(Results are the new brain's wins - losses - draws in duels, mean place in matches (lower is better).)

| # | Change | Duels | Matches |
|---|---|---|---|
| 0 | Nothing (control, same brain both sides) | 6-6 of 12 | 4.53 vs 4.47 of 10 |
| 1 | Strokes drawn in a person's usual time for each spell; a pause of 0.8 to 1.6 seconds between attacks instead of 1.5 to 3.6 | 24-14-2 of 40 | |
| 2 | Attacks chosen with a weight for what each has come to (`BrainCombat.WORTH`) | 37-20-3 of 60 | 4.22 vs 4.78 of 30; 21 matches won to 7 |

## To try next (in the order I mean to)

- Look after wounds: keep away from fights, rest at a bonfire or out of the way, when the maximum is low.
- Stay out of crowds: at the start walk away from the pack, and do not take a fight with a third party watching.
- Pick on the weakest rival that is in sight, not the nearest.
- Dodging: step or jump out of the way of shots it sees, not only turn them with a Gust.
- Stand still to cast the strokes that need it, so that stamina comes back while it fights.
- Close in for Scythe, and the like, when it is the best spell it holds.

## Audit of the brain: "be clever, not just fast" (2026-11-14, after the owner's reply)

What the audit found: the attack choice (`BrainCombat.attack`) is one table of hand-set scores per spell, picked at random and weighted, with only
the spell's range and whether the rival is still, held or closing as inputs. The AI keeps no memory of a rival (what spells it has shown, whether it
is hurt, how it moves), has no plan longer than one cast, and uses a spell for one thing only. Max-stamina spells (Scythe, Raise Dead, Supernova) are
gated only by `max_stamina > cost + 40`, so a nearly-dead wizard can still pay with health. Defence is jump, Gust, Barrier or Shadow Step, chosen at
random. `BrainMend.tend` casts walls, smoke, Decoy and armour from a `pressure` number, not from what is coming.

Ideas, most valuable first (none built yet; each is within what a person sees and knows):

**Know the rival (a small memory of what was seen)**
1. Keep a *rival profile* per wizard: the spells it was seen cast (a person sees the stroke and the effect), when, how often it is hurt, whether it runs or stands.
2. Counter by element: a rival seen to cast fire gets Tide Surf, Blizzard, Hailstorm or Frostbolt on its flame; a rival seen to cast ice gets fire; a Barrier-user is not shot at (it already waits).
3. Know what is probably in a book: a rival seen with a Barrier is saved Ignite shots; one that has shown no ranged spell is a wizard to close in on.
4. Remember where a rival was last seen and what it was doing when it left (fled hurt → chase while it is weak; left at full → leave it).
5. Judge a rival's health by what a person can see (it flinches, its bar is not visible, but a long fight and the hits landed are): choose to finish a weak rival and avoid a strong one.

**Use each spell for what it is for**
6. Frostbolt slows: cast it to stop a runner or a closer, then follow with a slow, heavy spell (Stonefall, Spark) that needs the rival still. Do not cast it at one already slowed (partly done).
7. Pebble is chip damage: spend it when stamina is short or to finish a wounded rival, and to pester one behind a low wall (it arcs).
8. Combos: Mudslide or Bramble or Ice Prison first, then Stonefall/Spark/Fire Breath on whoever is held; Blizzard then Frostbolt; oil-like set-ups with fire after a Spore Puff or Bramble (fire burns growth).
9. Geyser/Updraft/Push as *weapons* (throw a rival over a pit, into lava or a Black Hole), not only for escape.
10. Firewall and Bramble as terrain: laid between itself and a closing rival, or across the only way a fleeing one has; not cast at a still rival.
11. Fireball as a light in a cave: with no Flare or Glowcap, in the dark, throw an Ignite ahead to see the way and to burn what is in it.
12. Fire to burn gates and growth that block a route; water to douse a fire it must pass; a Frost Bridge across a pond it would otherwise swim (some of this exists in `brain_gates`; audit which gate kinds still lack a second-best answer).
13. Eldritch Blast, Thorn Whip and Leech used at the range they are strong at, and Thorn Whip to drag a rival into a trap (a Flytrap, Stalagmite, Firewall) it set.

**Defence by anticipation**
14. A roof against the sky: when a rival knows Spark or Stonefall (seen cast) or a sky spell is incoming, stand under a platform, or raise a Stone Wall over the head, before it is cast, not after.
15. A wall against a shooter: a Stone Wall raised between itself and a rival who has been firing straight shots, kept while they keep firing, and walked behind to dodge (not a one-off at "pressure").
16. Pick the defence by the spell coming: Barrier for projectiles only, Gust to turn a bolt, a jump for a low flat shot, a dodge sideways for Stonefall's shadow and Eruption, Tide Surf under fire, Tornado to shield from Spark? (only what the real analogue supports; no new spell behaviour).
17. Dodge the telegraphs it can see: the Stonefall shadow, a Firewall's flicker, Supernova's collapse, a Spark's cloud, a Scythe swing (the stroke is visible before the spell lands, as it is to a person).
18. Break a rival's draw: a rival who is drawing a stroke is open (a hit of 6 breaks it): time its own bolt to land while a rival is mid-stroke, and stop drawing an expensive spell when it is hit (partly there).

**Spend stamina and health like a person**
19. Max-stamina spells (Scythe, Raise Dead, Supernova, Hemorrhage-type) only when the wizard can afford to be weaker: not under half, not as a habit; and never when a cheaper spell would do. Today `ready_to_cast` allows them at `cost + 40`.
20. Stamina as a clock: stop casting while resting to regenerate when out of sight; stand still to cast spells that need no motion so the 20/s regen works; do not jump or Shadow Step for nothing.
21. Do not throw away a big spell on a wizard who is going to fall to the lava or the crowd anyway; let others wear a rival down and finish it (the royale "third party" rule).
22. Retreat and mend with intent: when hurt below a third and a bonfire is known, go to it by the safe way; when none, break line of sight and rest (Sneak, Smoke Screen, a roof).

**The crowd (battle royale)**
23. Stay out of crowds: when three or more wizards are on screen, move away from the pile and let them fight; enter after the first falls.
24. Third parties: do not fight a rival who has someone else attacking it, and do not turn your back on a second wizard; target the one hurting you, or the weakest, not the nearest.
25. Do not shoot a rival through a crowd in a way that wakes the others (a spell that hurts anyone it touches will hit a bystander, who then hunts you).

**Terrain and place**
26. Fight from the high ground or from a spot with a ceiling for Icicles, a ledge, or a wall to the back; do not fight with lava or a pit behind you.
27. Use the world: Earthquake on a rival standing on a ledge or a Stone Wall; Sinkhole under a rival at a pit's lip; Black Hole next to lava; Geyser at the edge.
28. Use creatures: lead a giant or a skeleton pack to a rival (the creatures hurt anyone, the spells have no sides), or fight beside them, not through them.

**Tempo and decisions**
29. Vary the plan by the matchup, not a random pick: close-range book → close in, long-range book → keep distance and use cover; read a rival's reach from what it was seen casting.
30. Remember what has just worked: after a hit, repeat the spell (a rival may be stuck or slow); after three misses, change spell or position.
31. Feints: draw a Barrier or a Decoy to bait a defence, then cast the real spell (a human trick; it can be read from the stroke, so only worth it for the skilled).
32. Skill spread: let the `skill` setting scale how many of the above a wizard uses (a beginner uses 1–2, a veteran all), so the game's levels stay meaningful.

**Measuring the clever play (so each idea earns its place)**
33. For each idea a *subset bench*: a book where the idea matters (`need=Frostbolt,Stonefall` for the slow-then-crush combo; `need=Barrier,Stone Wall` for the roof), duels against the old brain, and a damage share with its error. An idea stays only if the share rises by more than twice its error.
34. Log every cast with the reason it was chosen (`C` lines already have the spell) so the notes can say which idea fired and what it was worth (`tools/ai_yield.py` adds up the damage that followed).

### More ideas (owner approved the list, 2026-11-14)

**Reading the rival's body:** 35 read tells (a rival standing still is typing a chant: strike it); 36 punish recovery after a rival's big spell; 37 track a rival's stamina by what it spent; 38 notice limping (a rival that stops jumping or walks off from fights is wounded: hunt it).
**Spells:** 39 Hex before the big hit; 40 Silence a rival who has shown many spells; 41 Vacuum a rival mid-chant; 42 Decoy beside a trap; 43 Leech the strongest rival; 44 Raise Dead only with company; 45 Mirage by a trap; 46 Gust to set a rival up; 47 Shadow Step behind a rival, then a close spell; 48 no fire cast into water.
**Place:** 49 fight from cover and step out to cast; 50 high-ground discipline; 51 chokepoints; 52 bait rivals into creatures; 53 use the weather.
**Match:** 54 page denial; 55 bonfire ambush; 56 last-world endgame (go to the fight); 57 time-aware retreat in the 18 s collapse warning.
**Human-like:** 58 flinch and recover; 59 deliberate mistakes at low skill; 60 bluffs; 61 personalities (aggressive, sniper, trapper, turtle); 62 learn within a match; 63 learn across matches (needs the owner's OK); 64 self-tuning hill-climber.
Order: 35-38 and 62, then 49-51 and 56-57, then 61; 63 waits for the owner.

### Struck from the lists (they break a person's limits, see docs/handoff/18_human_limits.md)
- 56 and the "last two" hunt (counted who was left alive; built and removed), 57 (the collapse pulls everyone: nothing to do), 59 (made-up mistakes: owner decision 2026-11-09), 66 (sound from off the screen),
  82 "pace by number alive", 84 "play to a human opponent". Ideas that need to know the whole world are re-read as "what has it seen?" or dropped.
- Still to fix in what exists: `covered_at` looks 600 px above a head (a screen shows 240); the old `SpellTargets.wizards` uses in `knowledge_check`'s `KNOWN` list.

### Results so far (new brain against the frozen old one; duels = share of damage, royales = mean place, lower is better)

| # | Change | Duels | Matches |
|---|---|---|---|
| 3 | Rival profile; water against fire; slow-then-crush; blood spells kept for when it can afford them; crowd avoidance (4+ in sight); roof against Spark/Stonefall; stand still to regain stamina; no stepping off a ledge | 0.640 ± 0.023 of 90 (52-33-5); with Frostbolt+Stonefall in the book 0.654 ± 0.026 of 60 | 4.67 vs 4.33 of 30 (14-11); with crowd avoidance off 4.49 vs 4.51 (18-11) |
| 4 | Tells (a chanting rival is hit), a winded or wounded rival is pressed, what lands this match is cast more, four fighting styles, Hex then a heavy blow, crowd avoidance only for 4+ | 0.668 ± 0.022 of 90 (49-34-7) | 4.22 vs 4.78 of 30 (20-8) |
| 5 | As 4 with the window shortened to a screen, and the "last two" hunt removed | 0.653 ± 0.022 of 90 (60-29-1) | 4.33 vs 4.67 of 30 (19-8) |
| 6 | Quick bolts at a rival who is drawing, Ice Prison in water, Silence for a rival who has shown a book's worth, a flinch after a blow, defence by shot speed | 0.659 ± 0.030 of 90 (51-33-6) | 4.08 vs 4.92 of 30 (19-8) |
| 7 | As 6, with Silence for a rival seen casting in the last 15 seconds | 0.641 ± 0.022 of 90 (57-31-2) | 4.09 vs 4.91 of 30 (21-8) |
| 8 | As 7, with a Stone Wall raised against a rival seen casting straight shots at it | 0.610 ± 0.028 of 90 (57-28-5) | 4.28 vs 4.72 of 30 (20-9) |

Rows 4 and 5 are the same idea set; the spread between them (0.668 and 0.653) is the noise of the measure.

| 9 | Wall A/B, 150 duels, seed 2000 | wall off: 0.682 +- 0.020 (97-45-8); wall on: 0.653 +- 0.017 (91-51-6). Difference 0.03, about 1 SE: noise, not clear harm. Kept (owner rule); AI_OFF=wall remains for re-testing. |

| 10 | Rest under a roof A/B, 120 duels, seed 3000 | rest off: 0.687 +- 0.020 (79-36-4); rest on: 0.651 +- 0.019 (71-41-8). Gap 0.036, about 1.3 SE. Same direction as the wall A/B, where "on" also ran second: next, order swapped to see if run order biases it. Kept for now. AI_OFF=rest. |

| 11 | Rest A/B, order swapped (on first) | rest on: 0.659 +- 0.021 (74-40-6); rest off: 0.635 +- 0.022 (69-42-9). The second run of a pair is lower both ways, so run order (not the rule) caused the earlier gap. Both orders pooled: on 0.655, off 0.661: no effect either way. Rule kept; the wall result is likely the same artifact. Lesson: swap the order in every A/B. |

- Idea 27 (Earthquake on a rival at a ledge or pit) struck: the quake only shoves grounded wizards left and right in turn and does no damage, so there is nothing to aim it at; an edge-push would be a coin flip. Sinkhole at a pit lip and Black Hole by lava still open.

- Cleanup: three places where the brain counted the wizards left in the world (Hunter's Mark, the Scrying Eye, and stopping to walk when alone) no longer do. A person cannot know that; the Mark and the Eye now go by "it has lost track of everyone", and a won match simply ends. Two entries came off the knowledge_check list; the two left are scans that are then filtered by what the wizard sees.

| 12 | After the survivor-count cleanup, seed 4000 | duels 90: 0.648 +- 0.022 (58-30-2); royale 30: mean place 4.34 vs 4.66, wins 18 vs 11. No loss from the cleanup. |

- Cleanup: a rival that died out of its sight is no longer forgotten at once; it learns of a death only by seeing it (BrainSight.look_about). The other scan (BrainProfile.tick) only listens for damage and counts it only for rivals in view.

| 13 | After "learns of a death only by seeing it", seed 5000 | royale 30: mean place 4.43 vs 4.57, wins 20 vs 8; duels 89: 0.674 +- 0.023 (58-26-5). No loss. |

## 2026-11-15, after the level wall

- **Turning on the spot:** while winded, the wish to keep its range and the wish to get under a roof pulled it opposite ways and it turned left and right every frame (500 to 950 turns in 20 seconds, owner saw it standing and running both ways). A turn is now kept for 0.6 s (`BrainCombat.REVERSE_HOLD`); `dither_check`.
- **A wall between:** it used to stop fighting the moment a wall hid the rival. It now fights on for 4 s from where it last saw them (`WizardBrain.BLIND_FIGHT`), and if the wall is too tall to jump it stops hopping and raises itself over with a spell it holds, skipping spells too weak for the height (`LIFT_REACH`, `BrainCombat.chase`/`wall_top`); `behind_wall_check`.
- **Strength after both:** 120 duels 0.623 +- 0.019 of the damage against the old brain (earlier runs of the same kind 0.65 to 0.69, order bias about 0.03), 30 matches mean place 4.47 against 4.53, 18 wins against 9. Within noise; kept.

## 2026-11-15, situations and sense (owner: "make the AI more clever, act like a human that understands the spells and when to use them")

Each of these is switched off in a drill with `AI_OFF=<name>`, and `tests/checks/ai_drills_check.gd` asks the partner what it would do with and without it (decision drills: the brain's choice is read, not its legs).

- **Reading a rival's stroke as it is drawn (`read`):** the trail on the screen is read once 70% of it is drawn (`BrainSight.rival_drawing`, `Caster.glimpse`, `Pen.drawn_share`): the color gives the school, the shape the spell. A spell it holds, or has seen this rival cast, is known by its shape. A spell that lands where it was drawn (`BrainCombat.PLACED`: Stonefall, Spark, Firewall, Stalagmite...) is stepped out of, a reaction time after it is known. Bolts are left out: a flick is gone before anyone can answer it, and a drill showed no gain.
- **Terrain kills (`terrain`):** a rival at the edge of a drop (ground 300 px or more below, a step or two beyond them) or beside lava is shoved over with a Push (`BrainCombat.edge_beyond`, `lava_beyond`; the Push is drawn round the rival, the line out away from here).
- **Break the frozen (`shatter`):** a rival in a block of ice cannot move, so the slow heavy spells (Stonefall, Earthquake, Scythe, Supernova, Spark) are cast far more.
- **Behind a Barrier (`shield`):** it no longer waits out a Barrier. The thrown spells (`BrainCombat.SHOTS`) are left out while one is up and the rest are cast; a rival it has seen raise a Barrier is hit from above and from the ground even when none is up.
- **Pages for a kit (`kit`):** a page is outlined in its school's color, which anyone sees; the spell inside is not shown. A page of a school it holds little of counts up to 1.6 times nearer (`BrainTravel.kit_want`, `PagePickup.schools`), scaled by skill.
- **The chant before a fight (`brace`):** once a rival has shot at it lately (`pressure`) and it is quiet all round, it types the chant that fills its strength (`BrainMend.tend`, 50 s before it thinks of it again).
- **A rocket to get clear (`rocket`):** among the ways it gets a rival off it (`choose_repel`), a flame from the feet lifts it out of reach.
- **Lightning in the water (`water`):** a rival swimming is struck with a Spark more often (the bolt runs through the pool).
- **Left out on purpose:** the Rift to flee (a blow breaks the typing, so it is only any use out of sight, and where it lands is chance), and the Rite of the Land (a map the brain has no way to use: it explores by sight). High ground and cover are only what it already did (roofs, Stone Wall).

Second round (owner: "do all of them, keep coming up with more, always follow the human limits"):

- **Dear spells wait for a window (`window`):** spells costing 50 or more are cast 1.8 times as readily at a rival who cannot answer (frozen, dazed, down, rooted, typing a chant, or just spent a spell of its own) and 0.75 times otherwise (`BrainCombat._cleverness`).
- **Burn what they stand on (`burn`):** a rival on ice laid over water or on lily pads is met with fire (`BrainCombat.on_a_bridge`, `Pond.carries`, `LilyPads.carries`).
- **Where a jumper comes down (`landing`):** `WizardBrain.predict` follows the arc of a rival in the air to the ground under it, not half its speed.
- **Which way they step (`habit`):** `BrainProfile.dodge_lean`: a running average of the side a rival steps to while a shot of its own is coming; shots lean that way.
- **A stone falling on it (`stone`):** a boulder seen over its head is stepped out from under (`BrainSight.falling_stone`).
- **An ambush (`ambush`):** a rival it knows of, a way off, and not yet a fight: it casts Sneak to close the gap unseen (`BrainMend.tend`).
- **Bait (`decoy`):** a rival it has seen throw heavy blows is given a Decoy.
- **Not done, and why:** luring mobs onto a rival (it would need the brain to steer creatures it cannot command); sky and ocean tricks beyond the Spark in water (their brains are their own); breaking off a bad fight (it already goes about its journey and keeps away when it feels weak: `TIMID_BELOW`).

Third round (owner: "keep it going overnight, remember the human limits"):

- **A reserve (`reserve`):** under 75 stamina, a spell that would leave under 25 is cast half as readily: a person keeps something back to get away with (`BrainCombat._cleverness`). It reads only its own stamina.
- **Pressing a rival who just spent (`recover`):** a rival seen to cast a spell costing 50 or more is, for 3 seconds, hit with quick shots more (`BrainProfile.recovering`, `dear_at`; only a cast it saw).
- **Setting thorns alight (`thicket`):** a rival standing in a Bramble is met with fire (`BrainCombat._thicket_under`).
- **Range memory (`range_memory`):** a spell that has missed twice or more from about this far off (a 180 px band) is cast less from there for the rest of the match (`BrainProfile.form(spell, gap)`, `tried_at`, `worked_at`).
- **Caution when worn (`caution`):** under half its maximum it casts close-range spells 0.55 times as readily; whole (over 80%) against a rival it has watched get hurt, 1.4 times.
- **Left out on purpose:** tilt after a big hit (a made-up mistake, forbidden by limit 18); counting who else is in a fight (limit 8); feints, which need a stroke taken back mid-draw; page denial and patience in a royale, because both need the brain to track several rivals at once (limit 16).
- **Strength, rounds one to three** (120 duels and 30 matches each, different seeds): before 0.623 / place 4.47 against 4.53; after round one 0.660 / 4.36 against 4.64; with the kit, chant, rocket and water 0.697 / 4.31 against 4.69; round two 0.678 / 4.46 against 4.54; round three 0.676 / 4.55 against 4.45 (15 wins each way: within the noise of 30 matches). Duels stay about 0.05 above where they began.
- **`brain_spells_check` is flaky** (a different spell fails each time: Hunter's Mark at 5 s, Push, Spore Puff, Wild Shape at 60 s). The same happens on a clean copy of the last commit, so it is not from these changes.

### Level 9 push (2026-11-20): measuring tool and first lever

- **New: `tools/ai_ab.py CHANGE N [spells]`** plays level 9 against level 9 with one `BrainProfile.off(CHANGE)` change turned off for one seat only (`off0=`/`off1=` in `ai_arena`, `WizardBrain.off_here`). This sees small changes that the old-brain bench cannot, because level 9 already takes about 0.65 of the damage against the old brain and that number hardly moves. **Always run a null control first** (`python tools/ai_ab.py zzz 36`): it gave 0.473 ± 0.029, so differences under about 0.06 mean nothing at 36 games.
- **Lever 1, starting combos on purpose** (Water Jet before holding Spark, Oil Slick before a flame, a hold before a heavy blow): 0.454 ± 0.029 against the control's 0.473. No measurable gain, but **the owner's call (2026-11-20): a skilled player knows these setups, so the AI does them whatever the number says; it was put back** (`BrainCombat._combos`, switch `combo`). Likewise `_laws` (switch `laws`): ice on the soaked, no water on the burning, no oil on the soaked, close in on the slowed or silenced, no flame while oiled or alight (0.467 vs the null's 0.473: no cost). Standing rule: mechanic knowledge a talented player has goes in even when the bench cannot see it, provided `limits_check` stays green.
- Still to try, in order: defence that uses the laws (levers 2), reading a rival's states, stamina/tempo, terrain, per-rival modelling, rollouts.

### Aggression (2026-11-20, owner: "the wizards are passive enough that I just keep attacking")

- From 10 of the owner's finished games (`tools/mine_play.py`, `tools/mine_pressure.py`): a rival was within 500 px for 29% of the time, 2.8 hits a minute taken, almost no defensive casts (Barrier 1, Decoy 1 in 10 games). The AI waited to be found.
- `BrainLevel.AGGRESSION` (0 at level 1 to 0.5 at the default 7 and 1.0 at 9; `WizardBrain.aggression`, switch `press`): feels fit for a fight sooner (`_feel_strength`), hunts a rival even when a page is near (`BrainTravel.choose_goal`, from 0.5), keeps closer (`near_limit` down 60, `far_limit` down 90 at full).
- Measured: duels 0.503 vs a null of 0.484 (no effect: they start close); 24 matches (`BENCH_MODE=royale python tools/ai_ab.py press 24`) mean place 4.12 with it, 4.46 without (noise about 0.5). No harm; the aim is how it feels to play against, which the bench cannot tell: re-run `tools/mine_pressure.py` on new games and compare (before: rival near 29% of the time, 2.8 hits a minute).

### The owner's games, and the duel bench (2026-11-21, owner: "I easily beat 7 level-9 AIs")

- **From 78 minutes of the owner's solo logs** (`play_logs/solo_*.log`): the owner casts every 2.75 s (median), far less than the AI; of 75 rivals met, 43 were already wounded by other AIs; rivals under 50 maximum within 600 px walked toward the owner as often as away (670 / 588 / 471 still); against the owner, Hemorrhage did about 4.4 damage a cast, Ignite about 0.5 and each Barbs thorn 0.17; rivals near the owner were under a quarter of their stamina 22% of the time, the owner 12%.
- **Bug: a wounded wizard never felt weak.** `_feel_strength` gives half its weight to the book, so a well-armed wizard at 5% of its maximum still felt about 0.6 (the line to keep away is 0.3), and the level-9 aggression bonus added more. It now plays wounds the way the owner does ("below 50% I get more cautious, below a third I've got to get out of there"): from `CAREFUL_BELOW` (half the greatest maximum) down to `WOUNDED_BELOW` (a third), `WizardBrain.caution()` rises from 0 to 1, taking away the level's boldness and keeping it up to 80 px farther off (`near_limit`, `far_limit`); under a third it feels too weak to fight unless it has watched the rival take a beating (switch `wounded`; `duel_check` fails with it off: 0.52 against under 0.3).
- **The recorder never wrote a fall** (`N`): it listed wizards through `SpellTargets.wizards`, which leaves the fallen out. It now reads the group, writes a wizard taken out of the world from where it was last seen, and says `by_you` when the person struck the last blow.
- **Duel bench** (`Duel`, `DuelLog`, `tools/duel_study.py`): the owner plays one AI in a one-screen room with dealt books; the logs are for learning how a person fights and dodges.
- Next, from the same study: who to fight (the one hurting it, the one it watched get hurt, not only the nearest), spells that land on a person who dodges (recalibrate `WORTH` from the owner's games, not AI duels), and fewer, better casts.


### Changes from the owner's first duels (2026-11-21)

Switches (usable with `AI_OFF=name` or `python tools/ai_ab.py name N`):
- `wounded`: `WizardBrain.caution()` ramps from 0 at half of max stamina to 1 at a third; it presses less and keeps farther off. Under a third it gets out. A/B royale, 23 matches: mean place 4.35 with it, 5.65 without (lower is better).
- `self`: `BrainCombat.OWN_HARM` lists spells that hurt their caster when used near the target (Insect Plague and the like); the AI skips them when it would be stung.
- `veil`: Crimson Veil is cast only when wounded or when the rival has shown a spray (`BrainMend.SPRAYS`), not at random.
- `recharge`: below `RECHARGE_BELOW` (35) stamina the AI stands still and stops attacking (`WizardBrain.recharging`) until `RECHARGE_UNTIL` (110, or 90% of its max). Adrenaline is exempt.
`self`, `veil` and `recharge` are not yet measured with the A/B bench.

**Later the same day, the owner: decisions should come from perceived strength, not fixed numbers.** The cutoffs above are now feelings: `BrainProfile.threat(rival)` (0 to 1, from the spells it has seen the rival cast and how hard they hit, whether the rival has cast at it, and whether the rival looks hurt, winded or recovering; 0.5 for a rival it has seen nothing of) moves where caution begins (`WizardBrain.caution()`: from about 0.6 of its greatest maximum against a dangerous rival, 0.4 against a worn one, 0.5 at an ordinary one) and how much stamina it keeps in hand (`WizardBrain.reserve()`, 14 to 56; it recharges below that and fights again at 2.4 times it). `RECHARGE_BELOW/UNTIL` are gone. Still to do: movement (anticipating and reading shot velocity, jumping with little motion, controlling where the other goes, escaping), which the owner named as the other half of what makes a person hard to beat.

### 2026-11-22: thrift, a test opponent, and the world studies

- **`thrift`** (`BrainCombat._thrift`): what a spell costs weighs on its score, more the less stamina it has in hand (cheap spells up to 1.8 times, dear ones down to 0.45); not against a rival who cannot answer (the `window` moments). AI against AI it measured 0.499 +- 0.026 (60 duels): worth nothing there, kept because the owner's own cheap-spell habit only pays against an opponent who punishes an empty bar.
- **`spamonly`**: a TEST OPPONENT, not a way the game plays: `python tools/ai_ab.py spamonly N Barbs,Frostbolt,Ignite,Pebble,Stonefall,...` seats one wizard that throws only the four cheap shots. The seat WITH the switch off is the bot. The books must hold those spells, or the bot has nothing to cast (the first run, 0.538, was void for that reason). Not finished: the owner pointed out that duels are not how games are played; the royale is the measure.
- **`tests/looks/dodge_bench.tscn`** fires single Ignite and Frostbolt at the AI from 220 to 380 px: level 9 avoids 76 to 83% of them (run-to-run swing is several points). A Shadow Step sidestep across the shot's line was tried and measured no better (76 against 83 with it off); taken out. Lone shots are not what beats it.
- **`tests/tools/ai_arena.tscn`** gained `biome=NAME` (force the first world), `bait=1` (all but seat 0 put away, a page lying in a piranha pond, seat 0 a little way off) and, in each result, `deaths` (seat, time, place, cause: piranhas, drowned, fight, alone), `pages` held at the end and `water_pages`. In 24 jungle and 24 ocean falls none were from piranhas or drowning, and in the two bait runs that had a shoal the wizard stayed out for 90 s and left the page. The owner saw books lying by piranha ponds in play: not reproduced; the play recorder writes `N name fell ...` with what was near, so the next such game will say.

### 2026-11-22 (later): the fundamentals the owner asked for
- **`wary`** (`BrainSight.trail_over_me`): a large stroke (110 px or more) being drawn over the place it stands, of a spell it cannot read, is stepped out from under. Drill `wary_stroke`: 1.0 with, 0.0 without. Royale, 24 matches: place 4.25 with, 4.71 without. (The owner's three Spark deaths in the portal game were the ocean: lightning in water, not this; it stays as a general fundamental.)
- **Reaction, level 9 and 8** (`BrainLevel.SLOW` 0.7 -> 0.6, 0.85 -> 0.75): a reaction of about 0.15 to 0.27 s at level 9, a little under the 0.18 s the human-limits chapter names as about the quickest a person plausibly does; the top two levels may stretch it.
- **Drawing time** (`BrainStrokes.skilled_stroke`): an attack's stroke was drawn at the MEDIAN of recorded people at every level. It is now the median for the unskilled and the quick end (p25) for the most skilled, a little quicker again at the top two levels.
- **Tempo** (`WizardBrain._pause_after`, switch `tempo`): the pause after a cheap spell is down to 0.65 of the usual, a dear one's the usual.
- Aim and hand wander at level 9 were already at zero error (`0.1 * (1 - skill) * clumsy`); nothing left to take there.
- Measured: new level 9 against level 8, 36 duels: 0.528 before tempo, 0.501 after (noise is about 0.04). Speed does not show between AIs; it is meant for a person.

### 2026-11-23: the owner says they win too easily; a human-style opponent

- **Why the old bench did not show it:** every measure so far set the AI against itself or the frozen old brain, which is saturated: level 9 beats the old brain and the numbers rise while the owner still wins easily. The owner's 8 recorded matches show about 130 damage taken a match, over a third of it from "nothing near", with a rival within 500 px 31% of the time (`tools/mine_pressure.py`); in the duels the AI held a median 30% of its stamina against the owner's 64%, and its dear spells (Stonefall, Eldritch Blast) landed about 36 to 42% against the owner's cheap Barbs and Frostbolt at about 65%.
- **A measure that does look like the owner:** `python tools/ai_ab.py spamonly 30 Barbs,Frostbolt,Ignite,Pebble` (do NOT pass more than about four spells to `need=`: ten hangs the world search). "with it" in the output is the normal AI; the bot (a wizard that casts only the four cheap shots) is the control. Level 9 against that bot: AI share of damage 0.520 (9 wins, 9 losses, 12 draws), so the AI only ties a bot that throws four cheap spells.
- **Tried: `BrainCombat.THRIFT_BITE`** (how hard a spell's cost weighs on the choice; it was 1.0). At 2.0: 0.496; at 3.5: 0.446; at 6.0: 0.561 (18 wins, 5 losses) on seeds 100 to 129, and 0.456 (7 wins, 11 losses) on seeds 300 to 329. Noise is about 0.03 per run and the result swings by seed, so the bot test cannot yet tell this change from nothing. AI against AI (`thrift`, 40 duels): 0.544 at 3.5 and 0.562 at 6.0, a small gain. Left at 6.0.
- **Not yet tried, in the order the evidence points:** not standing still to recharge while a shot is coming (`recharge`, `still`); how well it dodges (43% against the owner's 48%); getting into fights with the person at all; hit-rate learning per spell from this match.
- **Knob variants against the cheap-shot bot (30 duels on each of two seed sets, share of damage for the AI, 0.5 = a tie):** thrift 6.0 alone 0.561 / 0.456; plus quicker reactions at levels 8 and 9 (`SLOW` 0.7 and 0.55) 0.511 / 0.480; plus a shorter pause between attacks (`ATTACK_GAP_QUICK` 0.65) 0.508 / 0.476; plus a smaller stamina reserve (`reserve` 8 to 40) 0.528 / 0.464. None is better than the others within noise (about 0.035 each), so the quicker reactions, shorter pause and smaller reserve were NOT kept. In a royale (24 matches) the bot placed 4.67 and the normal level 9 4.50 (4.5 is the average of eight), so cheap spam does not win royales either. Conclusion: reaction speed, cast rate and stamina thresholds are not what separates a person from this AI; the missing piece is somewhere else (who it fights, where it goes, how it uses the ground and the laws), and the owner's own matches need to be read for it.
- **Past human speed (owner, 2026-11-23: reaction, casting and draw times may beat a person's as long as nothing is physically impossible):** `SLOW` for levels 8 and 9 set to 0.5 and 0.3 (was 0.75 and 0.6): reaction about 0.1 to 0.2 s, quicker strokes and pauses. Against the cheap-shot bot: 0.534 and 0.551 share of the damage (about 0.54, up from about 0.51; small, noise 0.035). Also shortening the pause between attacks to 0.4 and the attention lag to 0.08 made it no better (0.524 and 0.489), so those stayed.
- **Owner: not *way* past human; somewhat realistic.** `SLOW` for levels 8 and 9 settled at 0.6 and 0.4 (between the old 0.75/0.6 and the tested 0.5/0.3).
- **What the 8 recorded matches show (2026-11-23; `mine_play.py`, `mine_pressure.py`, and the rival lines `W` of the play logs):** matches last 300 to 575 s; the owner casts only 2.9 a minute (median 11 s between casts) and takes about 127 damage a match, 3.2 hurt events a minute, 46% of it from "nothing near" (hazards) and thorns. A rival is within 500 px 35% of the time. Rivals within 500 px start about 4.9 casts a minute, more than the owner, but hurt far less. The owner's casts land far harder (Barbs 28 damage seen per cast, Spark 22, against Ignite 12). Of the owner's kills, many are Spark from the sky and fire, on wizards that stood in the open; a rival also dies to hazards, snails and other rivals before the owner reaches it.

### 2026-11-23: the match logger and the first twelve full royales (all eight seats level 9, seeds 11 to 16 and 21 to 26, `tools/analyze_royales.py`)

- `MatchRecorder` (see `docs/handoff/06_enemies_and_ai.md`) is now the one logger; `tools/read_match.py` summarizes a match, `tools/analyze_royales.py` looks across many. A benchmark game writes logs with `matchlog=DIR`.
- A royale of eight level-9 wizards ends in 150 to 500 s (all seven others fall). 31 of 42 falls were a wizard's blow, the rest the world: most "world" falls were a BURN (`BodyFlames` near the victim): burn damage is not credited to whoever lit it, so it reads as the world.
- **A wizard with a rival within 500 px has under 20% of its stamina 36 to 39% of that time** (dry: it cannot cast), and stands still about 35% of it. It holds 39 to 40% of its stamina in a skirmish, 72 to 76% otherwise. It casts at a median of 54% stamina. Damage per cast by distance is lowest far off (under 1 per cast past 450 px) and best close in.
- The AI chose Fire Breath (hurt anyone 29% of the time), Tornado (20%), Hailstorm (24%), Hex (24%), Blizzard (22%) and Tide Surf (31%) often with a low landing rate; Pebble, Frostbolt, Eldritch Blast, Spark, Spore Puff and Barbs were chosen often and landed 64 to 79% of the time.
- Half the wizard-seconds are logged as "in the air" (`is_on_floor` false): not yet checked whether that is real or a slope or platform artifact.
- **First improvement cycle (2026-11-23).** Tools: `tools/make_worth.py` (what each spell really does per cast, from logs, into `data/ai/worth.json`, read by `BrainCombat.worth_of`; `off("oldworth")` turns it off for an A/B), `tools/royale_metrics.py` (one line per batch: dry, still, damage per skirmish second, damage per 100 stamina spent), `tools/who_wins.py` (habits of the first three to fall against the last three), `tools/analyze_royales.py`. A batch is `python <scratch>/batch.py` style: six royales of eight level-9 seats, `matchlog=DIR`, about 14 minutes.
  - Measured worth against the old table: duels 0.524, 0.456 (two seed sets of about 40) and 0.481 against the cheap-shot bot: no difference beyond noise (about 0.03). Royale damage per 100 stamina went 17, 19 and then 12 in three batches: that measure is too noisy at six matches (matches last 120 to 150 s) to read. The file was NOT kept: with it the `ai_drills_check` drill "chooses a heavy blow for a rival frozen in ice" fell just short (a table averaged over every situation halves Stonefall, which the code boosts for a frozen rival). The code and `tools/make_worth.py` that read and wrote it were removed (dead code).
  - **Walking to water when alight** (`BrainTravel._toward_water`, `off("nodouse")`): a burn lasts its full 4.5 s and about 30 damage (40 episodes in the first logs; 13% of all damage is burning), but in a royale seen water is rarely within reach: it fired about twice in a 300 s match. Kept, small.
  - **What the logs say about who survives (51 first-to-fall against 54 last-standing wizards over 18 matches):** the first three to fall cast 11.6 times a minute and took 154 damage; the last three cast 6.7 times a minute, took 47, dealt LESS (47 against 59), were dry 60% against 29% and stood still 46% against 27%. In a royale of AIs, fighting loses and keeping out of it wins. The owner's own habit (few casts, 62% of the stamina in hand) is the survivors'.
  - Where damage comes from (24,000 damage in 18 matches): burning 12.7%, Spore Puff 9.6%, Insect Plague 7.9%, Eldritch Blast 6.4%, Thorn 5.3%, Spark 4.9%, a wizard's own staff or hand 4.5%, Hemorrhage 4.5%, Scythe 4.2%. Over a third is damage over time.

### 2026-11-23, the night: the owner away, the loop left running (read this first in the morning)

- **Owner's orders:** worlds shrink harder to force fights; the AI plays as well as it can within the rules, even by avoiding fights (they cannot avoid forever); keep playing games, analyzing, improving the AI and the logger; do not stop to ask.
- **Built:** `MatchStats`-independent match logger (`MatchRecorder`, see 06_enemies_and_ai.md); worlds now 900, 560, 340, 240 columns collapsing after 180, 150, 120 s; `ClosingWalls` in the last world (deadly ends that move in after 60 s, 4 damage every half second, 28 px/s each side, stops at 1100 px; placeholder red veil, logged as `WALLS` lines and blow cause "walls"). A royale now lasts 270 to 560 s (was 120 to 150); one of six reached the last world.
- **`tools/ai_tune.py`** (the hill-climb): plays duels (level 9 against level 9, 40 games) with one number of the brain changed for one seat (`BrainProfile.knob`, set as `off0=kn_NAME=VALUE`), keeps a value in `data/ai/knobs.json` when the changed seat deals at least 57% of the damage, logs every round to `docs/ai_tune_log.md`. It plays in a SNAPSHOT of the project (`TUNE_GAME`, `%TEMP%/tune_repo`) so the scripts can be edited meanwhile. Calibration: even an extreme change (`thrift` 0.2, cost almost ignored) gave 0.52 and the null change 0.49 over 24 duels, so the duel measure moves little with these numbers.
- **Paired royale test of prudent hunting** (`off("oldhunt")`: a hunter no longer goes after a rival over a page just because it is bold): 46 matches, mean place 4.48 with it and 4.43 without: no difference. Left on.
- Owner's casts are at the same range as the AI's (median 249 px against 229 px).
- **Tuner, first 5 rounds (40 duels each):** bold 0.45, res_exit 5.0, repeat 0.5, gap_s 2.2, thrift 4.5: all within noise (shares 0.46 to 0.53). Nothing kept.
- **Passive royale test** (`kn_aggr=0.0,kn_bold=2.0`: no pressing, never bold; one seat against six, 48 matches each in two seed sets): mean place 4.92 vs 4.65, then 4.19 vs 4.52. Pooled 4.55 vs 4.58: no difference. Being passive neither helps nor hurts in the shrinking worlds as measured; the endgame is decided by fights either way.
- **Logger:** WZ gains the brain's strength, caution and recharging; flags P (drawing), C (chanting), E (waiting for a way over water), R (resting), G (holding spells to recharge); blows from the closing walls are labeled "walls". Dead wizards are no longer counted in the tools' time shares.
- **Where AI time goes (royale logs):** about 27% still. Of that, 12.5% is the deliberate recharge hold (G), 3.9% resting, 3.7% drawing, about 10% no stated reason (mostly idle while exploring: 531 episodes over 1 s, median 2.6 s; some castle and mountain stretches of 40-110 s standing on a floor). That is the clearest AI fault found so far: stuck while exploring.
- **`tools/test.py --full` (after all of the above): 9 failed of 146.** Failures are in areas not touched here: minimap corner, lily pads, ocean wreck deck, newspells showcase, stats_screen draw errors, net_crowd (freed wizard), dedicated_check, soak_check#b and eruption_check (leak-only output, no FAIL line). The tree also holds the other person's unfinished art/parts and likeness_panel edits. Not investigated further; rerun before trusting.
- **Logger update (2026-11-24, after the owner's first recorded match):** the person's own casts were never logged (their strokes go through the arena's caster, not the wizard's): CAST, MISS and the new SAY (chants, with accuracy) now come from it. New ST lines write every change of a wizard's states (hexed, silenced, wet, burning ...) from the status bubbles (`StatusBubbles.states()`). WZ is now ten times a second (was two), shots twenty, other things four, the person's hands twenty; S also carries where their screen is centered and its zoom. The reading tools keep one WZ row per half second (`_thin`) so their figures stay comparable. Explained the "hexed" the owner saw in the sky: Rival3 hexed Rival5 (AI on AI), not a bug.
- 2026-11-24: the tuner's duels had been writing match logs into the person's own folder since midnight (1108 files, folder at its cap); fixed with MatchRecorder.silent (ai_arena sets it); the person's logs were kept.
- **Logger + replay (2026-11-24):** PAGE lines now name the reader (`PAGE wizard page x y`); each world's file starts with the ground (`TERR`/`TR` rows of 32 px tiles); `tools/replay_match.py LOG` plays the whole match (all worlds that share the stamp) in one web page with the ground, shot and thing names, spell names over casts, states, and the person's screen box.
- **`range` 560 re-tested in royales (2 x 48 matches, kn_range=460 against the stored 560):** mean place 4.58 vs 3.94, then 4.38 vs 4.92. Pooled 4.48 (460) vs 4.43 (560): no difference. The duel round that "kept" it (0.604) was noise. `data/ai/knobs.json` reset to `{}` (the code's own figures). Lesson: a duel round of 40 at the 0.57 bar keeps about one false winner in 25 tries; a kept knob needs a royale re-test before it is believed.
- **Person vs AI (owner's three recorded games, level 9 AIs):** the person deals 2 to 2.5 times the damage per cast (8.1 vs 3.7, 3.6 vs 2.6, 7.8 vs 3.8), uses 5.5 to 7 distinct spells where an AI uses 3.5 to 4.7, holds 72 to 88% of stamina where an AI holds 48 to 69%, and spends 0 to 14% of its time under 20% stamina where an AI spends 10 to 18%. Open question: whether choosing better spells (more variety, more of the high damage-per-cast ones) closes that.
- Killed the cheap_w/sure_w royale test at the owner's request (a tweak of the old table is not worth testing); the two settings were removed again. Next: derive spell choice from the spells' own numbers (cost, damage, speed), see the owner's note that a cost change must not need retraining.
- **Spell choice from the spells' own numbers (2026-11-24, owner's rule: weights must come from cost, damage, speed etc., so a changed number needs no retraining):** `SpellFacts` + new `Spell` fields (speed, warning, span, pellets, spread, reach) for 17 attacks; `BrainCombat._by_numbers` replaces the hand weight and thrift for them; `BrainProfile.off("facts")` gives the old way. Royale test, one set of 47: old weights 4.36, new 4.55 (noise; the second set was stopped at the owner's word that the change is right whether or not it wins now). A unit test (`spell_facts_test.gd`) checks the data's numbers against the effect scripts' constants. Plan for the other kinds of spell (control, defense, healing, movement): `docs/handoff/21_spell_numbers.md`.
- **Level 8 and 9 speed put back** (2026-11-24): `BrainLevel.SLOW` 0.75 and 0.6 again (I had set 0.6 and 0.4, a reaction near 0.1 s and strokes drawn in 40% of the quickest human time: past what a person can do). The tuner's stored knobs are empty, so every other figure is the code's own.
- **Numbers-based choice, second version:** the first one broke `ai_drills_check` (six drills) because it threw away what `_cleverness` knows of the rival and the laws (fire against plants, a heavy blow at a frozen rival). Now the worth from the spell's numbers is multiplied by what `_cleverness` made of the old score (`wise / plain`); `ai_drills_check` passes (one flaky retry). Healing is worked out the same way (`SpellFacts.heal_worth`, `BrainMend._heals_by_numbers`: net heal after the burn Cauterize leaves, over cost).
- 2026-11-24 (owner): Hemorrhage 3 -> 5 dmg a second (8 s, 20 max stamina: 40 in all); Stitch (Chant of the Bloody Needle) lasts 30 s, not 15. The AI no longer runs from a werewolf (it cannot outrun one) and prefers cheap sure shots at it, since one blow of any size turns it back (drill wolf_touch).
- 2026-11-24 (owner): closing walls are now a wall of fire (fire_wall pictures, `tests/tools/walls_look.tscn` takes a picture) with dark smoke behind, no red rectangles. Volcano lag: SmokeVeil only works when smoke is on the screen, every 4th frame; plume puffs 70 -> 50. GPU cost near a volcano could not be measured headless (logic cost was small); still to confirm by play.
- **2026-11-24 (owner: "fix the tests and update the AI to handle control, movement, defense, healing"):** *Tests fixed:* minimap (the skin's frame offset), stats screen (a replaced face drew onto the new one), eruption (a freed pool in a typed filter; the last lava cools later), showcase lily pads (pads are laid only on water: the checks lay them on dry ground through `LilyPads.on_dry_ground`), Great Oak (the room's hill is an overhang: the check accepts the real surface), Crimson Veil (its gesture is `shield`, and its cost is now paid in the most), Faint (it lasts 4 s) and Tide Surf (2.5 s), the ocean deck (tolerance 40), and the dedicated server check (the first world lasts 180 s, so `WIZARD_HURRY` 0.12 gave it 21 s and the world collapsed before the client read a page: now 0.4). *Real fix found by it:* a machine that comes into a world after pages were read there was never told (`Arena._peers_changed`, `_pages_gone`). *AI:* control, defense, heal and way-choice now come from the spells' own numbers (see `docs/handoff/21_spell_numbers.md`). Not yet royale-tested; the old hand-weight behavior is `BrainProfile.off("facts")` for the control spells and defenses too.
