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
