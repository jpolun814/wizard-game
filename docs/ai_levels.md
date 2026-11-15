# The nine AI levels

Written 2026-11-15. The levels are in `scripts/brain/brain_level.gd`; `tools/ai_ladder.py` plays them against each other. Level 9 is the limit of what a person
can do (the numbers in `data/ai/human_limits.json`), never past it. The levels are not yet in the game: nothing picks one (the waiting-room wall is not built).

## What a level sets (first version)

| level | skill | memory | slower | clumsier |
|---|---|---|---|---|
| 1 | 0.05 | 0.30 | 2.4x | 3.5x |
| 2 | 0.17 | 0.40 | 1.9x | 2.8x |
| 3 | 0.29 | 0.55 | 1.5x | 2.1x |
| 4 | 0.41 | 0.70 | 1.25x | 1.6x |
| 5 | 0.53 | 0.85 | 1.1x | 1.25x |
| 6 | 0.65 | 1.00 | 1x | 1x |
| 7 | 0.78 | 1.15 | 1x | 1x |
| 8 | 0.90 | 1.30 | 1x | 1x |
| 9 | 1.00 | 1.50 | 1x | 1x |

- **skill** drives how soon it reacts, how soon it casts again, how true its aim is and how steady its hand is (`WizardBrain.skill`); level 6 is the AI the game had before the levels.
- **memory** scales how long it keeps a rival's place (8 s) and a rival's spells (60 s) in mind.
- **slower** multiplies its reaction time and the wait between attacks; **clumsier** widens its aim and its hand's wander. Neither is ever below 1x, and nothing is botched on purpose.

## First results (20 + 20 duels per pair)

Each cell is the row level's share of the damage dealt against the column level (0.50 is an even match); below it, the row level's wins-losses-draws. 40 duels per pair, the seats swapped every other game.

| level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | - | 0.45<br>18-20-2 | 0.28<br>10-28-2 | 0.26<br>4-33-3 | 0.27<br>15-24-1 | 0.30<br>11-28-1 | 0.25<br>12-25-3 | 0.26<br>12-26-2 | 0.24<br>7-30-3 |
| 2 | 0.55<br>20-18-2 | - | 0.41<br>16-21-3 | 0.40<br>14-26-0 | 0.39<br>15-24-1 | 0.29<br>10-29-1 | 0.33<br>12-26-2 | 0.30<br>14-25-1 | 0.30<br>12-26-2 |
| 3 | 0.72<br>28-10-2 | 0.59<br>21-16-3 | - | 0.41<br>14-18-8 | 0.43<br>12-27-1 | 0.39<br>16-23-1 | 0.46<br>17-20-3 | 0.42<br>17-22-1 | 0.36<br>12-28-0 |
| 4 | 0.74<br>33-4-3 | 0.60<br>26-14-0 | 0.59<br>18-14-8 | - | 0.52<br>21-17-2 | 0.46<br>20-18-2 | 0.41<br>11-25-4 | 0.41<br>14-26-0 | 0.40<br>17-21-2 |
| 5 | 0.73<br>24-15-1 | 0.61<br>24-15-1 | 0.57<br>27-12-1 | 0.48<br>17-21-2 | - | 0.52<br>20-18-2 | 0.42<br>14-23-3 | 0.46<br>18-20-2 | 0.42<br>18-21-1 |
| 6 | 0.70<br>28-11-1 | 0.71<br>29-10-1 | 0.61<br>23-16-1 | 0.54<br>18-20-2 | 0.48<br>18-20-2 | - | 0.51<br>25-14-1 | 0.44<br>17-21-2 | 0.45<br>20-19-1 |
| 7 | 0.75<br>25-12-3 | 0.67<br>26-12-2 | 0.54<br>20-17-3 | 0.59<br>25-11-4 | 0.58<br>23-14-3 | 0.49<br>14-25-1 | - | 0.53<br>19-19-2 | 0.48<br>17-21-2 |
| 8 | 0.74<br>26-12-2 | 0.70<br>25-14-1 | 0.58<br>22-17-1 | 0.59<br>26-14-0 | 0.54<br>20-18-2 | 0.56<br>21-17-2 | 0.47<br>19-19-2 | - | 0.50<br>20-17-3 |
| 9 | 0.76<br>30-7-3 | 0.70<br>26-12-2 | 0.64<br>28-12-0 | 0.60<br>21-17-2 | 0.58<br>21-18-1 | 0.55<br>19-20-1 | 0.52<br>21-17-2 | 0.50<br>17-20-3 | - |

## Each level against the frozen old brain

60 duels each.

| level | share of the damage | wins-losses-draws |
|---|---|---|
| 1 | 0.373 +- 0.040 | 19-37-4 |
| 2 | 0.385 +- 0.030 | 23-36-1 |
| 3 | 0.571 +- 0.035 | 27-30-3 |
| 4 | 0.535 +- 0.032 | 33-25-2 |
| 5 | 0.679 +- 0.029 | 36-21-3 |
| 6 | 0.699 +- 0.031 | 42-14-4 |
| 7 | 0.666 +- 0.031 | 35-22-3 |
| 8 | 0.680 +- 0.030 | 39-18-3 |
| 9 | 0.675 +- 0.031 | 35-22-3 |

## Reading it

- Against the old brain the levels rise in order: 1 and 2 lose (0.37-0.39 of the damage), 3 and 4 are even, 5 to 9 win (0.67-0.70).
- The bottom levels are clearly weaker than the rest (level 1 takes about 0.25 of the damage against any level from 3 up). Levels 1 and 2 are not told apart, and neither are 3 and 4.
- Above level 5 the skill knob stops paying: 6, 7, 8 and 9 are within about 0.05 of each other. What decides a duel there is the spells and the stamina, not the hand.
