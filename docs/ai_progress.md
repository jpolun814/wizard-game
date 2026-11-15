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
