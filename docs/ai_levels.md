# The nine AI levels

Written 2026-11-15. The levels are in `scripts/brain/brain_level.gd`; `tools/ai_ladder.py` plays them against each other. Level 9 is the best a person could plausibly be: quicker, steadier and longer of memory than the people recorded in `data/ai/human_limits.json`, but knowing and doing nothing a person cannot. In the game the waiting room's wall of nine crystals sets the level of a solo match (`LevelWall`, `Lab`); a network match uses the players' average rating (`Lab._start_if_all_in`).

## What a level sets

| level | skill | memory | slower | clumsier |
|---|---|---|---|---|
| 1 | 0.05 | 0.30 | 2.6x | 4.0x |
| 2 | 0.14 | 0.40 | 2.1x | 3.2x |
| 3 | 0.23 | 0.55 | 1.7x | 2.5x |
| 4 | 0.32 | 0.70 | 1.4x | 1.9x |
| 5 | 0.41 | 0.85 | 1.2x | 1.5x |
| 6 | 0.50 | 1.00 | 1.1x | 1.2x |
| 7 | 0.62 | 1.15 | 1x | 1x |
| 8 | 0.80 | 1.60 | 0.85x | 0.7x |
| 9 | 1.00 | 2.20 | 0.7x | 0.5x |

- **skill** drives how soon it reacts, how soon it casts again, how true its aim is and how steady its hand is (`WizardBrain.skill`); level 7 (the default) is the AI as trained before the levels.
- **memory** scales how long it keeps a rival's place (8 s) and a rival's spells (60 s) in mind.
- **slower** multiplies its reaction time and the wait between attacks; **clumsier** widens its aim and its hand's wander. Below 1x (levels 8 and 9 only) they make it quicker and steadier than the best people recorded (owner, 2026-11-15: the recorded people are a sample, not a ceiling); what it may know or do stays a person's. Nothing is botched on purpose.

## Results (30 duels per pair, seed 9000)

Each cell is the row level's share of the damage dealt against the column level (0.50 is an even match). Seats swapped every other game. A gap of 0.05 or less is noise. Levels 1 to 6 are from the first retuned run; the pairs with 7, 8 or 9 were rerun after levels 8 and 9 were pushed past the recorded people.

| lvl | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | average |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | - | 0.43 | 0.37 | 0.31 | 0.22 | 0.26 | 0.29 | 0.24 | 0.24 | 0.29 |
| 2 | 0.57 | - | 0.38 | 0.41 | 0.37 | 0.33 | 0.30 | 0.26 | 0.33 | 0.37 |
| 3 | 0.63 | 0.62 | - | 0.51 | 0.45 | 0.35 | 0.37 | 0.34 | 0.30 | 0.45 |
| 4 | 0.69 | 0.59 | 0.49 | - | 0.36 | 0.47 | 0.42 | 0.47 | 0.45 | 0.49 |
| 5 | 0.78 | 0.63 | 0.55 | 0.64 | - | 0.42 | 0.46 | 0.42 | 0.35 | 0.53 |
| 6 | 0.74 | 0.67 | 0.65 | 0.53 | 0.58 | - | 0.49 | 0.42 | 0.42 | 0.56 |
| 7 | 0.71 | 0.70 | 0.63 | 0.58 | 0.54 | 0.51 | - | 0.54 | 0.42 | 0.58 |
| 8 | 0.76 | 0.74 | 0.66 | 0.53 | 0.58 | 0.58 | 0.46 | - | 0.45 | 0.59 |
| 9 | 0.76 | 0.67 | 0.70 | 0.55 | 0.65 | 0.58 | 0.58 | 0.55 | - | 0.63 |

## Each level against the frozen old brain

40 duels each.

| level | share of the damage | wins-losses-draws |
|---|---|---|
| 1 | 0.398 +- 0.033 | 15-23-2 |
| 2 | 0.391 +- 0.036 | 13-26-1 |
| 3 | 0.548 +- 0.039 | 22-14-4 |
| 4 | 0.601 +- 0.036 | 24-14-2 |
| 5 | 0.680 +- 0.030 | 28-10-2 |
| 6 | 0.643 +- 0.036 | 25-12-3 |
| 7 | 0.655 +- 0.031 | 28-10-2 |
| 8 | 0.604 +- 0.040 | 26-13-1 |
| 9 | 0.624 +- 0.039 | 20-17-3 |

## Reading it

Averages against the other eight rise 0.29, 0.37, 0.45, 0.49, 0.53, 0.56, 0.58, 0.59, 0.63: the order holds, and level 9 is now clearly the top (it beats 7 at 0.58 and 8 at 0.55, where before the change they were even). Levels 7 and 8 are still close (0.46 to 0.54 between them, within noise). Against the old brain, 1 and 2 lose, 3 and 4 win narrowly, and 5 to 9 win by about 0.60 to 0.68 of the damage.
