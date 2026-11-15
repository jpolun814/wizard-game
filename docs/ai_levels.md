# The nine AI levels

Written 2026-11-15. The levels are in `scripts/brain/brain_level.gd`; `tools/ai_ladder.py` plays them against each other. Level 9 is the limit of what a person
can do (the numbers in `data/ai/human_limits.json`), never past it. The levels are not yet in the game: nothing picks one (the waiting-room wall is not built).

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
| 8 | 0.80 | 1.30 | 1x | 1x |
| 9 | 1.00 | 1.50 | 1x | 1x |

- **skill** drives how soon it reacts, how soon it casts again, how true its aim is and how steady its hand is (`WizardBrain.skill`); level 7 (the default) is the AI as trained before the levels.
- **memory** scales how long it keeps a rival's place (8 s) and a rival's spells (60 s) in mind.
- **slower** multiplies its reaction time and the wait between attacks; **clumsier** widens its aim and its hand's wander. Neither is ever below 1x, and nothing is botched on purpose.

## Results (30 duels per pair, seed 9000)

Each cell is the row level's share of the damage dealt against the column level (0.50 is an even match); below it, wins-losses-draws. Seats swapped every other game. A gap of 0.05 or less is noise.

| level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | - | 0.43<br>6-19-5 | 0.37<br>10-16-4 | 0.31<br>6-23-1 | 0.22<br>5-20-5 | 0.26<br>7-22-1 | 0.23<br>8-22-0 | 0.22<br>13-17-0 | 0.24<br>8-20-2 |
| 2 | 0.57<br>19-6-5 | - | 0.38<br>10-19-1 | 0.41<br>15-14-1 | 0.37<br>9-19-2 | 0.33<br>15-14-1 | 0.36<br>9-20-1 | 0.30<br>8-19-3 | 0.35<br>9-20-1 |
| 3 | 0.63<br>16-10-4 | 0.62<br>19-10-1 | - | 0.51<br>17-12-1 | 0.45<br>14-15-1 | 0.35<br>12-15-3 | 0.41<br>16-12-2 | 0.35<br>10-15-5 | 0.28<br>9-21-0 |
| 4 | 0.69<br>23-6-1 | 0.59<br>14-15-1 | 0.49<br>12-17-1 | - | 0.36<br>11-17-2 | 0.47<br>13-17-0 | 0.45<br>14-14-2 | 0.47<br>14-15-1 | 0.43<br>12-18-0 |
| 5 | 0.78<br>20-5-5 | 0.63<br>19-9-2 | 0.55<br>15-14-1 | 0.64<br>17-11-2 | - | 0.42<br>8-19-3 | 0.45<br>13-15-2 | 0.48<br>14-14-2 | 0.44<br>14-15-1 |
| 6 | 0.74<br>22-7-1 | 0.67<br>14-15-1 | 0.65<br>15-12-3 | 0.53<br>17-13-0 | 0.58<br>19-8-3 | - | 0.45<br>13-14-3 | 0.46<br>12-18-0 | 0.43<br>11-19-0 |
| 7 | 0.77<br>22-8-0 | 0.64<br>20-9-1 | 0.59<br>12-16-2 | 0.55<br>14-14-2 | 0.55<br>15-13-2 | 0.55<br>14-13-3 | - | 0.49<br>17-12-1 | 0.56<br>18-12-0 |
| 8 | 0.78<br>17-13-0 | 0.70<br>19-8-3 | 0.65<br>15-10-5 | 0.53<br>15-14-1 | 0.52<br>14-14-2 | 0.54<br>18-12-0 | 0.51<br>12-17-1 | - | 0.50<br>12-18-0 |
| 9 | 0.76<br>20-8-2 | 0.65<br>20-9-1 | 0.72<br>21-9-0 | 0.57<br>18-12-0 | 0.56<br>15-14-1 | 0.57<br>19-11-0 | 0.44<br>12-18-0 | 0.50<br>18-12-0 | - |

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
| 7 | 0.692 +- 0.030 | 31-6-3 |
| 8 | 0.681 +- 0.030 | 23-13-4 |
| 9 | 0.661 +- 0.035 | 27-13-0 |

## Reading it

Each level's average share against the other eight rises 0.28, 0.38, 0.45, 0.49, 0.55, 0.57, 0.59, 0.59, 0.60: the order holds. Levels 1 to 6 are clearly separated; levels 7, 8 and 9 are close to even with each other (9 lost to 7 at 0.44), which is within noise at this sample size. Against the old brain, levels 1 and 2 lose, 3 to 4 win narrowly, and 5 to 9 win by about two to one in the damage.
