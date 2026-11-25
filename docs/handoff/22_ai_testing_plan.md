# The plan for testing and improving the AI wizards (written 2026-11-24, for any model to carry out)

This chapter is a complete, step-by-step plan. It was written by a large model so that a smaller, cheaper model can carry it out without having to work
anything out for itself. **Do the steps in order. Do not skip a gate. Do not invent extra work.** When a step says "report to the owner", stop and write
the short report described, then carry on only if the owner has not said otherwise.

If anything in this file disagrees with the code, the code is right: say so in your report and fix this file.

---

## 0. Read these first (in this order), and the rules that bind every step

1. `CLAUDE.md` (the whole file; section 2 rules 7, 8 and 11 matter most here).
2. `docs/handoff/18_human_limits.md`: the AI may never know or do more than a person could. Every AI change in this plan must keep these limits.
3. `docs/handoff/07_testing.md`: how the test suite works (`python tools/test.py`).
4. `docs/handoff/21_spell_numbers.md`: the "spell choice from the spells' own numbers" work that this plan tests.
5. `docs/ai_progress.md`: the history of AI changes and what each was worth.

**Rules (each of these was learned the hard way; break none):**

- **Never commit, push, or delete the owner's files unless the owner asks.** Never run `git checkout .`, `git reset --hard` or `git clean`.
- **Before creating a file, check that it does not already exist** (`ls path` or the Glob tool). On 2026-11-24 a new tool was written over an existing `tools/ai_ladder.py`; it had to be restored from git. If the name is taken, choose another name.
- **Never run AI benchmarks and the test suite at the same time.** Both use every core; the tests that run in real time then fail for no reason (this happened). Run one, wait for it to finish, then the other.
- **Do not sit silently for hours.** After each step, write two or three sentences to the owner: what was done, what the numbers said, what comes next. The owner was rightly angry when a turn ran 2.5 hours and produced a result nobody had checked along the way.
- **Never claim more than was measured.** "Not yet tested" is a fine thing to write. A difference smaller than two standard errors is "no clear difference", not "better".
- **The owner's standing rule on AI changes** (memory `ai-keep-smart-changes`): keep a change that makes the AI more clever and more human-like unless it is *clearly harmful*. Noise is not a reason to revert. A change that is clearly harmful is first *fixed or retuned*, and only removed if it cannot be fixed.
- **The owner's rule on spell numbers** (`21_spell_numbers.md`): the AI's spell choice must come from the spells' own numbers (damage, cost, speed, how long it holds). Do not go back to hand weights to "win"; fix the numbers model instead. The old weights stay available only as a switch (`BrainProfile.off("facts")`) for comparison.
- **Switch names are matched as substrings** (`BrainProfile.off` uses `String.contains`, file `scripts/brain/brain_profile.gd` line 15). A new switch name must not be contained in, and must not contain, any existing switch name. Existing names (2026-11-24): press shield wounded wolf facts window water wary wall veil thrift thicket terrain tempo stone still spamonly shatter self roof rocket rest reserve recover recharge read range_memory oldhunt nodouse laws landing kit habit decoy crowd combo clever caution burn brace ambush. To list them again: `grep -rhoE 'off\("[a-z_]+"\)' scripts | sort -u`.
- **GDScript traps that already bit:** a `#` comment inside an expression's parentheses breaks the parse (put comments at the end of the line); `var x := dict["k"]` or `:=` on a Variant does not parse (write the type: `var x: String = dict["k"]`); after any `.gd` edit run the parse check below.
- **Shell quirk:** long bash heredocs containing apostrophes sometimes fail. For edits longer than a few lines, use the Edit tool, or write a Python script to the scratchpad and run it.

## 1. Commands you will use

```
GODOT="/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . --quit-after 100 2>&1 | grep -c "SCRIPT ERROR"     # parse check: must print 0
python tools/test.py --unit                                                    # unit tests, about 20 s
python tools/test.py                                                           # unit + quick checks, about 5 min
python tools/test.py --full                                                    # everything, about 13-15 min
python tools/test.py --full ai_drills                                          # the AI drills alone (run after any change in scripts/brain/), about 2.5 min
python tools/ai_trial.py                                                       # prints the AI comparison tool's help
```

The test logs of each run are in their own folder; the path is printed on the first line (`logs: ...`). The machine has **6 cores**; the AI tool runs 6 games at once.

## 2. Where things are (the files this plan touches)

| What | File |
|---|---|
| The AI comparison tool (new, 2026-11-24) | `tools/ai_trial.py` |
| The game runner it starts (one match per process) | `tests/tools/ai_arena.gd` (+ `.tscn`). Arguments: `mode=duel|royale seed=N seconds=S lv=9,9,... players=N width=F offseats=0,2:change old=0,2 result=FILE matchlog=DIR` |
| Smaller worlds for tests | `MatchState.width_scale` in `scripts/core/match_state.gd` (set by `width=`; never under `MIN_TEST_WIDTH` 160) |
| The old one-seat tool (superseded, keep it) | `tools/ai_ab.py` |
| The nine AI levels against each other (do not overwrite) | `tools/ai_ladder.py` |
| A frozen old brain to test against | `tests/legacy_brain/` (made once by `tools/make_legacy_brain.py`; never run that again without the owner) |
| Switches that turn a change off for one seat | `BrainProfile.off(name)` in `scripts/brain/brain_profile.gd`; per seat via `offseats=` |
| Spell worth from numbers | `scripts/spells/spell_facts.gd` (`worth`, `control_value`, `defense_worth`, `heal_worth`, `cheapest_first`) |
| Attack and control choice | `BrainCombat._by_numbers` in `scripts/brain/brain_combat.gd` (around line 160); the old weights are `_cleverness`, `_thrift`, `WORTH` |
| Heals and defenses choice | `BrainMend._heals_by_numbers`, `_defenses_by_numbers` in `scripts/brain/brain_mend.gd` (called around line 155) |
| Ways over gaps, gates, cover | `BrainGates` in `scripts/brain/brain_gates.gd`, the four `SpellFacts.cheapest_first(...)` calls (around lines 212, 232, 240, 327) |
| How the AI draws a choice | `BrainCombat.pick` (around line 752): already a weighted random choice, in proportion to the scores |
| Results log of every AI test | `reports/ai_tests.jsonl` (one JSON line per test) |
| The owner's real matches | `%APPDATA%\Godot\app_userdata\wizard-game\match_logs\` (about 250 files; format at the top of `scripts/ui/match_recorder.gd`; `kind` is `person` or `brain` in each `WZ` line) |
| The owner's duels | `%APPDATA%\Godot\app_userdata\wizard-game\duel_logs\` (5 rounds, 2026-11-21/22); read with `python -I tools/duel_study.py` |
| Match log tools | `tools/analyze_royales.py DIR` (how wizards fell, time use, spells and landing), `tools/replay_match.py LOG OUT.html` (a page that plays a match back) |
| The AI drills | `tests/checks/ai_drills_check.gd` (`--full` only) |

## 3. Where things stand (2026-11-24)

- All the work of 2026-11-24 is **uncommitted** on branch `main`.
- The numbers-based choice now covers attacks, control spells (`Spell.hold`, `Spell.share`), defenses (`Spell.lasts`, `absorbs`, `blows`), heals, and ways (cheapest first).
- **The one royale test of all of it together came out worse:** 48 matches, seats 0 and 1 of 8 differing; the seat with the numbers on finished on average 4.96th, the seat with them off 4.08th (`facts` switch, seeds 3000-3047, results in `%TEMP%\wizard_ab\facts_30*.jsonl`). That test design was poor (it compared one seat with one seat and threw away six of the eight places). Finding out which part hurts is Phase 1.
- The test suite: the quick run is green. The last full run before the 2026-11-24 fixes had 2 failures (`ai_drills_check` timed out under load; `eruption_check` failed by chance). Both were fixed (ai_drills now has 480 s and runs in `--full` only; the eruption check now stops the volcano from erupting a second time). The full run after those fixes (2026-11-24, 865 s) had **145 of 146 pass and 1 fail**: `ai_drills_check`, drill "keeps its dear spells for a rival who is dazed and cannot answer" (0.102 with the idea against 0.066 without; the drill wants a bigger rise). Six checks were FLAKY (failed once, passed on a second try): net_spells, net_match, duel, group_b, decoy_hint, soak#a. That run was disturbed: two Godot parse checks were run during it, which is exactly what section 0 forbids. So Step 0.1 must first rerun the full suite on a quiet machine. If the dazed drill still fails, it is the same kind of failure as the four drills relaxed on 2026-11-24 (the numbers-based choice spreads the weight over more spells): check its `_drills()` entry in `ai_drills_check.gd`, and lower its needed rise only if the idea still clearly raises the share (as the comment above `_drills()` explains), saying so in the report.

## 3b. Progress log (newest last; each step says what was measured)

- **Step 0.1 (2026-11-24):** the full suite ended `ALL GREEN` (146 of 146) on the third quiet run, but 7 checks failed once and passed on the retry (net_spells, net_match, collapse, interaction, duel, heal, new_spells). `python -I tools/flakes.py` shows this is old and wide: 95 checks have failed once and passed on a retry somewhere in the 102 runs recorded, `net_match_check` in 9 of 15 runs. It is **not** new from today's work, and fixing it is not part of this plan. `net_match_check` was made to wait for the fallen wizard's book to arrive (it crashed once on a freed world; the explanation first written for that, "hurry=100 makes the second world collapse fast", was wrong: `MatchState.hurry` multiplies a world's seconds, so 100 means no collapse).
- **Step 0.2:** a four-wizard match on half-width worlds runs clean (3 worlds, fights, no errors). A match log and a replay page were made; nobody has watched the replay yet.
- **Step 0.3:** games are **not repeatable**. The same seed three times gave three different results (the first fall was identical each time, the rest differed: 347 s, 504 s and 676 s long). So every comparison needs enough pairs.
- **Step 0.4:** `tools/ai_trial.py` now scores top-weighted (1/log2(place+1)), prints damage taken and how each group fell, has `--level`, `queue FILE` and `worst_logs`. `ai_arena.gd` counts at most 200 damage per blow (a hazard death was counted as 100,075 and swamped an average).
- **Step 0.5 (A/A, both groups the same brain):** duel, 40 pairs: +0.12 +- 0.07 places, UNDECIDED. Quad, 18 pairs: -0.31 +- 0.19, stopped as FAIL (that means "no gain of 0.25 or more", as it should for a null). Both are within 2 standard errors of 0. One pair's gain varies by about 0.46 places in a duel and 0.81 in a quad (standard deviation), so a quad test needs about 60 pairs to decide at delta 0.25. **What an A/A test can and cannot show:** both games of a pair come from the same distribution, so seat bias cancels in it by construction and it cannot reveal one. Seat bias was measured from the unpaired games instead: in duels seat 0 won only 31 of 80 games (+0.23 +- 0.11 places for seat 1, about 2 standard errors); in quads there was none (-0.08 +- 0.22). That is why every test is a mirrored pair.
- **Step 1.1:** the 48 royales of 2026-11-24 re-scored with all seven new-way seats: the seat without the numbers finished 4.08th, the seven others 4.56th on average; the gap is **+0.48 +- 0.40** (1.2 standard errors: not a clear difference). The neighbor-seat figure the first test used was +0.88 +- 0.52. So the first scare was weak evidence either way.
- **Step 1.2:** five switches added and covered by `tests/unit/brain_switches_test.gd` (it reads every `BrainProfile.off("...")` name in the scripts and fails if one name is inside another; it was shown to fail on a deliberately colliding name): `nb_attack`, `nb_control` (both in `BrainCombat._by_numbers`), `nb_heal`, `nb_defense` (`BrainMend`), `nb_ways` (`BrainGates._ordered`). Unit tests and the AI drills pass.
- **Step 1.3 (stopped early on the owner's order, 2026-11-24):** each part of the numbers-based choice turned off for one group; gain is for the group WITH the numbers (places; above 0 is better): duel attacks -0.15 +- 0.09 (60 pairs); duel control -0.08 +- 0.09 (59 pairs, Ice Prison forced into the book); quad attacks -0.17 +- 0.14 (26 pairs, stopped as "no gain of 0.25"); quad control -0.21 +- 0.16 (29 pairs, same); quad defense +0.02 +- 0.12 (43 pairs, not finished). Not run: heals, ways, and all together (`facts`). **No part was clearly harmful (none below -2 standard errors).** The two attack tests lean the same way (about -0.15 +- 0.08 together), too weak to call. **Decision (owner): keep the numbers-based choice as the default and move on to Phase 2.** The all-together test (`python tools/ai_trial.py quad facts --max 80`) and the choice-difference counter (Step 1.3b) can be run any time later, when the machine is free and no AI change is in progress.

**Backlog from the owner's game of 2026-11-24 12:26 (seed 14186328; the owner confirmed these by watching; NOT part of this plan, to be taken up later, each behind a switch and tested in the ladder):**
- *Stairs:* in the castle world the AIs stood still 56% of the time; Rival3 sat in the basement 44 s with goal "explore" and cast nothing from t=85 to 140 s, although its book held Rocket Jump (and Liana, Frost Bridge). `BrainTravel.follow_route` waits at a swinging stair (`STAIR_PATIENCE` 10 s, and only for goal "explore", then re-plans, often back to the same stair); nothing turns a long stair wait into a spell from `WizardBrain.WAYS["wall"]`. Idea: switch `stairs`.
- *Hopeless casts:* `BrainCombat.pick` casts the best of whatever scores above zero, however low: Rival6 cast Tornado 13 times at scores of 0.00-0.02 and 300+ px, when Spark was spent. Idea: switch `floor`, no cast when every score is hopeless.
- *Ice Prison without a follow-up:* `SpellFacts.damage_rate` assumes the best open attack can be thrown every `CYCLE` (1.5 s) whatever it costs, so a control spell is overvalued for a wizard whose only attack is dear (Rival6: Spark). Rival6 cast Ice Prison 10 times in one world. Idea: switch `affordable`, the rate the wizard can afford to repeat (stamina and its return against cost).
- Replay of that game: `docs`-less, made with `python -I tools/replay_match.py <match_log> out.html` (the logs are in `%APPDATA%\Godotpp_userdata\wizard-game\match_logs\`, `match_2026-11-24T12-26-40_w1.log`).

---

## 4. How an AI test match is set up (what happens inside, so you can debug it)

**One process is one match.** `tools/ai_trial.py` starts Godot once per game:
`GODOT --headless --fixed-fps 60 --path <repo> tests/tools/ai_arena.tscn -- <arguments>`.
- `--headless`: no window, no sound. `--fixed-fps 60`: every frame advances the game by exactly 1/60 s and the engine does **not** wait for real time, so a game runs as fast as the CPU allows and gives the same game-time results on a slow or busy machine ([Godot command line reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), option `--fixed-fps`: "disables real-time synchronization"). The one thing that is NOT tied to frames: the liquid simulation (lava and water) runs on another thread and is taken in when ready (`docs/handoff/12_liquids.md`), so two runs of one seed can differ (Step 0.3 measures how much).
- Everything after `--` reaches the game as `OS.get_cmdline_user_args()`, read in `ai_arena.gd` `_ready()`.

**What `ai_arena.gd` does with them:**
1. Reads the arguments (table below). `seed(seed_value)`, `MatchState.begin(seed)`, `World.next_seed = seed`, then loads `res://scenes/world.tscn`: the **same match the game itself plays** (same world generation, page deals, creatures, collapses), just with no person in it.
2. Each time a world has been built (`_attach`, three frames after it appears), it hands the person's seat to an AI brain (`seat_work.give_player_to_a_brain()`), sets each seat's level (`lv=`), sets each seat's switches (`off_seat[k]` goes to `brain.off_here`; `BrainProfile.off` reads it when that wizard thinks), swaps in the frozen old brain for the seats in `old=`, and puts away the seats that do not play (`_put_away`: moved far off, frozen, marked dead, hidden). This is done again in **every** world of the match, because each world builds its wizards anew.
3. Every physics frame it counts game seconds and notes when each playing seat falls. The match ends when one (or none) is left standing, when `seconds=` of game time have passed, or in a duel when either falls.
4. `_finish()` prints `RESULT {json}` and appends the same JSON as one line to `result=FILE`.

**Arguments** (all optional):

| Argument | Meaning |
|---|---|
| `mode=royale` / `mode=duel` | royale: the real match (four worlds, shrinking, collapsing). duel: two wizards 320 px apart on a flat world of biome `["graveyard","mountains","jungle","ashlands"][seed % 4]`, each given the same five spells picked by the seed (three attacks from `Pages.RANGED`, a way from `Pages.MOVES`, a defense from `Pages.DEFENCES`; `need=A,B` adds spells, underscores for spaces) |
| `seed=N` | the world, the page deal and all chance in it |
| `seconds=S` | game seconds at most. A royale's worlds last 180 + 150 + 120 s plus warnings, and the last world's walls close in from 60 s on, so about 650-700 s of game is a full match; quad uses 700, royale 1100 |
| `lv=9,9,...` | level of each seat's brain (`scripts/brain/brain_level.gd`; 9 is the best). Give all 8 |
| `players=N` | royale only: seats 0..N-1 play, the rest are put away |
| `width=F` | royale only: every world is F times as wide (`MatchState.width_scale`, never under 160 tiles) |
| `offseats=0,2:NAME` | these seats play with switch NAME turned off (several names: `NAME1,NAME2`) |
| `off0=NAME`, `off1=NAME` | the same for seat 0 or 1 alone (older form) |
| `old=0,2` | these seats play the frozen old brain (`OldWizardBrain`, `OldSkyBrain` from `tests/legacy_brain/`). In a duel, use `swap=1` instead: without it the old brain is seat 1 (only when fewer than 2 levels are given) |
| `result=FILE` | where the JSON line goes |
| `matchlog=DIR` | write the full match log there (big: several MB a match) |
| `biome=NAME` | force the first world's biome |

**The JSON line** has: `mode`, `seed`, `seconds` (game seconds played), `worlds` (how many worlds it reached), `fell` (seat -> game second it fell, -1 = standing at the end), `stamina` (seat -> stamina + max stamina left, 0 if fallen), `taken` (seat -> damage taken), `deaths` (list of `{seat, t, x, y, cause}`), `pages` (seat -> pages held), and a few fields for other studies. Only seats that play appear in `fell`.

**Places.** `ai_trial.py` `play()` sorts the playing seats: anyone still standing ranks above anyone who fell, those standing by `stamina` (more is better), those fallen by how late they fell. Place 1 is the winner.

**Groups and mirrored pairs** (`RUNGS` in `ai_trial.py`): duel `[0]` against `[1]`; quad `[0,2]` against `[1,3]`; royale `[0,2,4,6]` against `[1,3,5,7]`. For each seed: game A gives the first list the change turned off; game B gives the second list the change turned off. Both games of a pair run at the same time. `BATCH` (3 pairs = 6 games, one per core) are played between looks at the SPRT.

**First runs, 2026-11-24 (by the planning model, so you know what works):**
- One quad game by hand (Step 0.2's command, with `offseats=0,2:facts`): no SCRIPT ERROR, 3 worlds, the four seats fought (three falls, cause "fight"), the put-away seats stayed away. 415 s of game in 54 s of wall time.
- `python tools/ai_trial.py quad none --max 3`: ran end to end, 6 games in 2 minutes (5.6x real time with 6 at once). `duel none --max 3`: under a minute. So a quad pair costs about 40 s of wall time (about 90 pairs an hour) and a duel pair far less; a royale game took about 6 minutes in the old tool (about 25 pairs an hour).
- From those 3 quad pairs, one pair's gain wobbles by about 0.75 places (standard deviation). If that holds, a quad test needs about 50 pairs to decide at delta 0.25, so **use `--max 80` for quad**, not 40, wherever this plan says `--max 40`. The A/A test in Step 0.5 measures this properly; use its figure.
- These smoke runs' lines were removed from `reports/ai_tests.jsonl`, so that file starts empty.

**What may still break** (not yet tried):
- A seat put away coming back alive in the second world (check `_put_away` is reached: it is called from `_attach` when `players < 8`).
- World generation at width 160 failing for some biome (look for `SCRIPT ERROR` in Godot's output: `play()` throws the output away, so run one game by hand as in Step 0.2).
- The duel's `old=` handling in `play()` (only for `legacy`): check by hand that in a legacy duel the old brain sits in the seat of `old` (print `_seats[k].brain.get_class()` or its script's global name in `_attach` once, then remove the print).
- A game that does not finish in 1500 s of wall time is dropped with its pair (the tool prints it). If many are dropped, the time limit or `seconds=` is wrong.

**The data about people** (for Step 2.1), checked 2026-11-24: 264 match logs (92 MB), every one with the owner playing (`kind` = `person` in field 4 of the `WZ` lines; fields counted from 0, field 0 is the time). In them: 3235 shots and 411 blows on the person by another wizard or a creature. Line forms (`scripts/ui/match_recorder.gd`, top of file):
- `t WZ id name kind level x y vx vy facing floor|air stamina max flags anim goal target cooldown ...`
- `t NEW id class owner x y shot|thing` (owner is the id of who cast it, or `-`)
- `t OB id class owner x y` (a shot's position, twenty times a second, until it goes)
- `t HIT victim by with amount max_after x y` (`by` may be a creature's id, not only a wizard's: keep only `by` values that are a wizard's id from the `WZ` lines)
- `t CAST wizard spell targeting x y aim stamina_after`

A shot has no target in the log. Count a shot as "thrown at the person" when it was cast by another wizard, and its `OB` positions come within 300 px of the person's position at the same time (nearest `WZ` line of the person by time).

**Which references were looked up.** The Fishtest, pentanomial, rating-systems, Neural MMO, LieCraft, Agent Island and Drivatar links in Appendix C came from web searches on 2026-11-24. The Godot command-line and `openskill` links are the usual addresses and were not opened; if one has moved, search for it by name.

---

## PHASE 0: make the measuring trustworthy (no AI changes in this phase)

### Step 0.1: the full suite must be green

1. Run `python tools/test.py --full`. Do not run anything else meanwhile. It takes about 15 minutes.
2. If it ends in `ALL GREEN`, go on.
3. If a check failed: open the log named in the summary. Run that check alone (`python tools/test.py --full NAME`).
   - It fails alone too: a real failure. Find the cause, fix it, and write what it was in your report.
   - It passes alone: it is load-sensitive. Find what in the check depends on wall-clock time or on the order threads finish (see how `eruption_check` was fixed on 2026-11-24: the second eruption was frozen with `process_mode = Node.PROCESS_MODE_DISABLED`). Do **not** just raise a timeout unless the check genuinely needs more time (the AI drills did: 141 s alone against a 150 s limit).
4. **Report to the owner:** "Full suite: N of N passed" (or what failed and why).

### Step 0.2: a match of four on a smaller world works (smoke test)

The four-player mode (`players=4 width=0.5`) was run once on 2026-11-24 and worked (section 4). Do this step anyway, with the match log, to see the fights with your own eyes.

1. Run one game and time it:
   ```
   "$GODOT" --headless --fixed-fps 60 --path . tests/tools/ai_arena.tscn -- mode=royale players=4 width=0.5 seed=6000 seconds=700 lv=9,9,9,9,9,9,9,9 result=C:/Users/JORDAN~1/AppData/Local/Temp/quad_test.jsonl > C:/Users/JORDAN~1/AppData/Local/Temp/quad_test.txt 2>&1
   ```
2. Check, and write down:
   - `grep -c "SCRIPT ERROR" quad_test.txt` must be 0.
   - The `RESULT` line's `"fell"` has exactly 4 entries ("0" to "3"), and at least 3 of them are not -1 (three fell, one won), or the game ran to 700 s.
   - `"worlds"` (how many worlds the match went through) is at least 2.
   - The wall time it took (time the command, e.g. `time` in bash) and the game seconds (`"seconds"` in the result). Their ratio is how much faster than real time it runs.
3. If seats 4-7 show up alive in a later world, or the world fails to build at width 160, fix `_put_away` in `tests/tools/ai_arena.gd` or raise `MatchState.MIN_TEST_WIDTH`. Run again until the checks hold.
4. Also make the match log once and look at it: add `matchlog=C:/Users/JORDAN~1/AppData/Local/Temp/quad_log` to the command, then run `python -I tools/replay_match.py <one log from that folder> C:/Users/JORDAN~1/AppData/Local/Temp/quad.html` and open the HTML. Do the four wizards meet and fight? Write one sentence about what you saw.

### Step 0.3: are games repeatable? (determinism)

1. Run the same quad game (seed 6000) twice more, into two result files.
2. Compare the `"fell"` times of the two runs.
   - Identical: the games are deterministic; noise comes only from the worlds.
   - Different: the liquid simulation runs on another core (`docs/handoff/12_liquids.md`) and its timing differs from run to run, so the games are not repeatable. That is acceptable; it only means more games are needed. Write down how different (e.g. "the order of falls changed in 1 of 2 runs").
3. Do not try to make the game deterministic. That is a large job and not needed.

### Step 0.4: improve `tools/ai_trial.py` (code)

Read the whole file first. Then make these changes, one at a time, running `python tools/ai_trial.py` (the help) after each to check it still parses.

**(a) Replace the "points" score with a top-weighted score (the DCG discount).** A study of rating systems on over 25,000 battle-royale matches found the NDCG family the most reliable ([The Evaluation of Rating Systems](https://ar5iv.labs.arxiv.org/html/2105.14069)). For a wizard in place `p` (1 = winner), its score is `1 / log2(p + 1)`: 1.0 for first, 0.63 for second, 0.5 for third, and so on, so first counts most but every place counts. A group's score is the mean over its seats; the pair's figure is the group-with-the-change's score minus the other group's, averaged over the two games of the pair. In `score()`, replace the `pts` lambda:
```python
pts = lambda seats: sum(1.0 / math.log2(p[s] + 1) for s in seats) / len(seats)
```
and rename "points" to "top-weighted" in every print and in the history line (key `"top_weighted"`).

**(b) Explain each group's results (diagnostics).** The arena's result line already has `"taken"` (damage each seat took, keyed by seat as a string) and `"deaths"` (a list of `{"seat", "t", "x", "y", "cause"}`; `cause` names what killed them). In `play()`, keep these in the returned dict (`"taken": result["taken"], "deaths": result["deaths"]`). In `run()`, after the verdict, print for each group (with the change, without it): mean damage taken per game, and a count of death causes (use `collections.Counter`). Map seats to groups per game: in the first game of a pair the group without the change sits in `old_seats`; in the second game the groups are swapped.

**(c) A level-5 sanity check.** Add an option `--level L` that overrides `LEVEL` (it already reads `BENCH_LEVEL` from the environment; make the option set the same variable). Nothing more: Phase 1 uses it.

**(d) A queue.** Add a command `python tools/ai_trial.py queue FILE`: FILE is a text file with one test per line (e.g. `quad nb_control --max 40`). It runs the lines one after another, calling `run()` for each with the same parsing as `main()`. Lines starting with `#` are skipped. This lets a batch of tests run overnight.

**(e) Record where the logs went.** When `--logs` is given, also write the worst pairs' paths into the history line (key `"worst_logs"`).

Do not change the SPRT, the mirrored pairs, the seat groups, or the seeds.

### Step 0.5: the A/A tests (both groups the same brain)

These measure the noise and prove the tool is fair.

1. `python tools/ai_trial.py duel none --max 40`
2. `python tools/ai_trial.py quad none --max 60`
3. Write down for each: the final "better by X places +- SE", the win share, and the minutes it took.

**Gate:** each A/A result must be within 2 standard errors of 0 (that is, `abs(gain) < 2 * se`), and the verdict must not be PASS. A PASS on `none` means the tool is wrong (a gain this size by chance is a 1-in-20 event).
- If it fails: check that the second game of a pair really swaps the groups (`play(..., new_seats, ...)` is the second game) and that the scoring subtracts in the right order. (An A/A test cannot find seat bias, because the pair cancels it; see the progress log. Seat bias is measured from the unpaired games.) Fix and run again.
- **Report to the owner:** the two A/A results, how long a pair takes at each rung, and from that how many pairs an hour each rung can afford.

---

## PHASE 1: find which part of the numbers-based choice made the AI worse

### Step 1.1: re-score the old 48 matches (free)

Write a small Python script in the scratchpad (not in the repo) that reads `%TEMP%\wizard_ab\facts_3000.jsonl` to `facts_3047.jsonl`. Each file has one JSON line: `"fell"` (seat to the second it fell, -1 = still standing) and `"stamina"` (seat to what it had left). For seed `s`, the seat playing *without* the numbers was `1 if s % 2 == 0 else 0` (see `tools/ai_ab.py`, `play()`). Work out the places exactly as `ai_ab.py` does (standing wizards ahead of fallen ones, then by stamina left). Print: the mean place of the without-seat, the mean place of all seven other seats, and the standard error of the difference per match. **Report it to the owner** in one sentence (the expected answer is a gap of about 0.5 places instead of 0.9). If those files are gone (Windows may empty `%TEMP%`), say so and skip this step: it is not needed for the rest.

### Step 1.2: one switch for each part

Add five switches. Names are chosen so that none is a substring of another (check with the grep in section 0):

| Switch | Turns off (that seat goes back to the old hand weights for) | Where to add the check |
|---|---|---|
| `nb_attack` | attacks (spells with damage that do not hold) | `BrainCombat._by_numbers`: at the top of the loop over `scores.keys()`, `if not SpellFacts.controls(spell_name) and BrainProfile.off("nb_attack"): continue` |
| `nb_control` | control spells | the same loop: `if SpellFacts.controls(spell_name) and BrainProfile.off("nb_control"): continue` |
| `nb_heal` | heals | `brain_mend.gd`, where `_heals_by_numbers(weights)` is called: `if not BrainProfile.off("nb_heal"): _heals_by_numbers(weights)` |
| `nb_defense` | defenses | the same place, for `_defenses_by_numbers(weights)` |
| `nb_ways` | cheapest-first order of ways, gates and cover | `brain_gates.gd`: add `func _ordered(names: Array) -> Array: return names if BrainProfile.off("nb_ways") else SpellFacts.cheapest_first(names)` and use it in place of each of the four `SpellFacts.cheapest_first(...)` calls |

A spell skipped in `_by_numbers` is not put in `done`, so its old weight (`WORTH`) is used for it: that is what "the old way" means. The existing `facts` switch must keep turning everything except `nb_ways` off (leave its checks as they are).

Then: parse check, `python tools/test.py --unit`, `python tools/test.py --full ai_drills`. All must pass.

### Step 1.3: test each part

Write a queue file in the scratchpad and run it with `python tools/ai_trial.py queue FILE`:
```
duel nb_attack --max 60
duel nb_control --max 60
quad nb_attack --max 80
quad nb_control --max 80
quad nb_defense --max 80
quad nb_heal --max 80
quad nb_ways --max 80
quad facts --max 80
```
**How to read a result.** The tool reports the group WITH the change (numbers on). Positive "better by" means the numbers helped.
- `PASS`: the numbers part helps. Keep it.
- `UNDECIDED` with `abs(gain) < 2*se`: no clear difference. Keep it (the owner's rules: noise is no reason to revert, and the numbers are the mandate).
- `FAIL` and the result says `WORSE` (gain below -2 standard errors): this part is clearly harmful. Go to step 1.4 for it.
- `VETO`: places better but wins fewer. Treat it as harmful only if the diagnostics show the group hiding (fewer deaths to wizards, less damage dealt, more time alive without winning). Otherwise report it and keep it.

**Report to the owner** after the queue: one line per test (rung, part, verdict, gain +- se, win share), and which parts go to step 1.4.

### Step 1.3b: how often does the numbers-based choice differ from the old one? (added 2026-11-24)

**Why.** Every test so far (attacks, control, defense) shows no clear difference. One reason may be that the numbers only re-weight spells the old rules already allowed (`_by_numbers` scales the new worths to the sum of the old weights), so the two methods may nearly always pick the same spell, and then no test could ever show a difference. This measures it. **Do it after the Step 1.3 queue has finished** (editing `scripts/brain/` while the queue runs changes the AI being tested).

**What to build** (small, and behind no switch: it only counts, it changes no decision):
1. In `BrainCombat._by_numbers`, just before the loop that writes `scores[spell_name] = fresh[...] * scale`, find `old_top`: the spell with the highest `scores[name] * WORTH.get(name, 1.0)` among all `scores` greater than 0 (that is what the old way would have picked as its most likely spell); after the loop find `new_top`: the highest of the final `scores` (after `* WORTH` for the spells that were not worked out, as `attack` does). If both exist, add 1 to `BrainProfile.tally["decisions"]`, and 1 to `BrainProfile.tally["differ"]` when `old_top != new_top`; also add the shares: `tally["old_top_share"] += old_top's share of the old total`, `tally["new_top_share"] += new_top's share of the new total` (how sure each method was).
2. In `brain_profile.gd` add `static var tally := {"decisions": 0, "differ": 0, "old_top_share": 0.0, "new_top_share": 0.0}`.
3. In `ai_arena.gd` `_finish()`, add `"tally": BrainProfile.tally` to the result line (it is per process, one match, so no resetting is needed).
4. Run 20 quad games with nothing turned off (`python tools/ai_trial.py quad none --max 10`: each pair is two games; read the `tally` from the result files in `%TEMP%\wizard_ladder\quad_none_*.jsonl`), and add up `differ / decisions` over all of them. Also the mean of the two shares.

**How to read it.** Under about 10% of decisions differ: the numbers barely change what the AI does, which explains the null results; no test of the weights can show much, and the effort belongs elsewhere (the backlog items and movement). 10 to 30%: they change a fair amount but neither is clearly better. Over 30% and still no difference: they pick different spells that are about equally good. **Report the figure to the owner** with one sentence on which reading it supports.

**The decision rule that goes with it (owner, 2026-11-24).** If the numbers-based choice is not clearly worse than the old weights, keep it: it follows the spells' own numbers (so a change of a spell's number changes the AI with no new measuring), which is the owner's standing wish and the more human way to choose. Only a part that is *clearly* worse (more than 2 standard errors below 0 in a quad or royale test) is fixed, and fixed by correcting its numbers (Step 1.4), not by going back to hand weights.

### Step 1.4: fix a harmful part (do not just delete it)

For each harmful part, in this order of suspicion:

1. **Look at what it chooses.** Run its trial again with `--logs --max 10`, then `python -I tools/analyze_royales.py <the logs folder>`. Compare the "WHAT THE AI CHOSE" table with and without the change. A spell chosen far more often with the numbers than without, and landing rarely, is the culprit.
2. **Check the figures that spell's worth comes from**, in its `data/spells/*.tres` (`hold`, `share`, `warning`, `speed`, `lasts`, `absorbs`, `blows`, `cost`) against what the spell really does in its script. The control figures (`hold`, `share`) of 2026-11-24 were first estimates, not measurements: an `share` of 1.0 says the rival is fully helpless for all of `hold`, which is only true for Ice Prison, Faint and Flytrap.
3. **Check the constants about people** in `spell_facts.gd`: `FREE_LANDING` (0.6), `REACTION` (0.8), `CYCLE` (1.5), `TYPICAL_BLOW` (14). If a control spell is chosen too often, its worth is too high: the usual cause is `rate` (the best open attack's damage over `CYCLE`) being large, or `hold * share` being too generous.
4. Change one figure at a time, with a comment saying why. Run the unit tests (`tests/unit/spell_facts_test.gd` must still pass) and run the part's quad trial again.
5. If after three honest attempts it is still clearly harmful, **report to the owner** with the numbers and ask whether to turn that part off by default. Do not decide that alone.

### Step 1.5: confirm the whole set at the big rung

`python tools/ai_trial.py royale facts --max 30`. The verdict must not be `FAIL` with `WORSE`. Then `python tools/ai_trial.py quad facts --level 5 --max 20` (the numbers must not break a weaker level). **Report to the owner.**

---

## PHASE 2: make the AI better (each idea is one change, one switch, and one trial)

**For every idea below, the same recipe:**
1. Read `18_human_limits.md` again: the idea may only use what a person at the screen could see or know.
2. Build it behind a new switch (a name that collides with none; see section 0). The switch turns the NEW behavior off, so `offseats=...:name` plays the old way.
3. Parse check, unit tests, `python tools/test.py --full ai_drills`. Add a drill to `ai_drills_check.gd` if the idea is a situation you can set up in a small scene (look at the existing drills for the pattern).
4. Screen it: `duel` first if it is about fighting only, then `quad`. Confirm a PASS with `royale --max 30`.
5. Write a paragraph in `docs/ai_progress.md` (what, why, the trial's numbers) and **report to the owner**.

### 2.1 Human figures from the owner's own play (the idea behind Forza's Drivatar)

Forza's Drivatar builds its AI drivers from how players actually drive ([How Forza's Drivatar actually works](https://gamedeveloper.com/design/how-forza-s-drivatar-actually-works); [Affective Game Computing survey, which covers its history](https://arxiv.org/pdf/2309.14104)). Here: measure the two figures about people that `SpellFacts` guesses, from the owner's recorded play, and use the measurements.

Data: the match logs (section 2). In a `WZ` line, field 4 (counting from 0: time, `WZ`, id, name, kind) is `person` or `brain`. `CAST` lines give who cast what and when; `HIT` lines who was hurt, by whom, with what, how much; `NEW` lines with `shot` give each thing thrown.

Write `tools/measure_people.py` (check the name is free) that reads every match log and prints, with the number of cases behind each:
- **Landing on a moving rival** (`FREE_LANDING`): of the shots thrown at the person (see section 4 for how to tell) while the person was moving (speed from the `WZ` line's vx, vy above 40 px/s at the moment the shot came within 300 px), the share that were followed by a `HIT` on the person with `by` = that shot's owner within 1.5 s. Do the same for shots at AI wizards, and print both.
- **Reaction** (`REACTION`): for shots that came within 300 px of the person, the seconds from the shot's `NEW` line to the person's next change of direction or jump (vx changes sign, or vy goes strongly negative). Print the median and the quartiles.

Compare them with the constants (`FREE_LANDING` 0.6, `REACTION` 0.8). If a measured figure has at least 100 cases behind it and differs by more than 20%, change the constant to the measured figure, with a comment naming the measurement, the date, and the number of cases. Then run the recipe above (the switch is not needed for a constant; compare with a trial of `facts` before and after instead, or ask the owner).

### 2.1 result (2026-11-24, `tools/measure_people.py`, 33 logs of the owner's real play)

- **REACTION 0.8:** the owner's median is 0.88 s (quartiles 0.52 to 1.37; 195 answered shots, 236 not answered within 2 s). Within 20%: **kept**.
- **FREE_LANDING 0.6:** shots at an AI wizard land 49% while it moves and 66% while it stands (1,745 shots): 0.6 fits. Shots at the **owner** land only 16% moving and 23% standing (503 shots): a person is about three times harder to hit. The AI cannot know in advance who is a person, and in a solo match six of seven rivals are AIs, so the constant is **kept**. The finding belongs to a new idea, 2.7 below. Both figures are noted next to the constants in `spell_facts.gd`.

### 2.2 to 2.5: ALREADY BUILT (found 2026-11-24, when Phase 2 was started; the plan was written without checking the brain closely enough)

Do not build these again. Their switches (`BrainProfile.off(name)`) turn them off for a seat; `docs/ai_progress.md` has each one's history.
- **2.2 Punish windows:** `window` (the dear spells wait for a rival who cannot answer: frozen, dazed, down, rooted, typing a chant, or just spent on a spell), `recover` (a rival that has just cast a dear spell is slow to answer), and `winded` (one that has spent a lot is pressed), `scripts/brain/brain_combat.gd` lines 260 to 280 and `BrainProfile.recovering/winded`.
- **2.3 Habit tracking:** `habit` and `BrainProfile.dodge_lean(rival)`: which way a rival has been seen to step as shots come at it, used to lead the shot (`WizardBrain.predict`, `wizard_brain.gd` around line 691). The Barrier habit is also tracked (`shield`).
- **2.4 Third-party timing:** `crowd` (stay out of a pile of three or more, let others wear each other down), `wizard_brain.gd` line 389.
- **2.5 Lookahead for a shot:** `WizardBrain.predict(seconds)`: where the rival will be when the shot lands, from its speed, its jump's arc and the ground below, led by the AI's skill; and `range_memory` (a spell that missed twice from about this far off is not tried again from there).

What is **not** built, from the same family of ideas: 2.7 (below), and the three observed problems in the backlog in section 3b (stairs, hopeless casts, an overvalued Ice Prison).

### 2.7 A hit rate for each rival (new; from the 2.1 measurement)

The brain learns how well each of its spells has landed this match (`BrainProfile.tried/worked`, `form()`), but not how well its shots land on each rival. A person who dodges is hit a third as often as an AI, and the AI does not notice. Idea: count tries and hits for each rival (`note_try` knows the target; `_hurt_seen(amount, other)` knows who was hurt) and replace the constant `FREE_LANDING` in `SpellFacts.control_value` with that rival's rate, mixed with 0.6 as a prior of about four shots. Then holding a rival who is hard to hit is worth more (a control spell takes 1 - rate of what attacks would have done), and one who is easy to hit is worth less. Switch `rivalrate`. Test: `quad rivalrate --max 40`; the effect will be small and the test will probably say "no clear difference"; keep it unless clearly worse, as for every change.

### 2.6 Danger and opportunity maps (from strategy-game AI: "influence maps")

Score the places near the wizard for standing in: cover nearby, high ground, distance from other wizards, distance from hazards. Move toward good ones when not chasing a page or a rival. Leave this to last, and **ask the owner before starting it**: it changes how the AI moves everywhere.

### Not on the list, and why
- **Randomness in choices** (poker): `BrainCombat.pick` already chooses at random in proportion to the scores, so the AI is not fully predictable. Nothing to add.
- **Training the AI by learning** (reinforcement learning): the owner called that off on 2026-11-12 (memory `learned-ai-abandoned`). Do not start it.

---

## PHASE 3: keep the AI from slipping back

### 3.1 A gauntlet of frozen brains
After every three changes accepted in Phase 2, ask the owner whether to freeze a new copy of the brain to test against. `tools/make_legacy_brain.py` overwrites `tests/legacy_brain/` (it says so in its header), so it must be changed to write to a new folder each time (`tests/legacy_brain_2/`, with classes renamed `Old2...`) before it is used again. Then `ai_trial.py` needs a change name `legacy2` that uses those classes in `ai_arena.gd`. Do not do this without the owner's yes.

### 3.2 Ratings across many versions (TrueSkill or Plackett-Luce)
Once there are three or more frozen brains, rate them all from mixed matches with a rating system that uses the whole finishing order of a free-for-all. TrueSkill does this ([used over full rankings in the NeurIPS 2022 Neural MMO Challenge](https://arxiv.org/pdf/2311.03707); [LieCraft on why TrueSkill suits free-for-all](https://arxiv.org/pdf/2603.06874)). A ready Python library: `openskill` (it implements Plackett-Luce and others; install with `pip install --isolated --index-url https://pypi.org/simple openskill`, as CLAUDE.md section 3 says for any package). Plackett-Luce background: [Agent Island](https://arxiv.org/pdf/2605.04312).

### 3.3 Re-check the old winners
Once a week of work, run `python tools/ai_trial.py recheck --max 30`. A past PASS that now fails gets a report to the owner.

### 3.4 Drills from the owner's play
Every weakness the owner reports (e.g. 2026-11-24: "the AI ran from my werewolf instead of hitting it") becomes a drill in `ai_drills_check.gd` (the `wolf_touch` drill is the example) so it can never quietly come back.

---

## Appendix A: the statistics, in plain words

- **Mirrored pair.** One world (seed) is played twice: the group without the change sits in seats A the first time and in seats B the second time. The pair's result is the average of the two games. Luck of the world and of the starting places then falls on both groups equally. Chess testing does the same with an opening played as both white and black, and models a pair as one outcome (the "pentanomial" model: [Fishtest mathematics](https://github-wiki-see.page/m/xoto10/fishtest/wiki/Fishtest-mathematics), [vdbergh/pentanomial](https://github-redirect.dependabot.com/vdbergh/pentanomial)).
- **Gain.** For one game: mean place of the group without the change, minus mean place of the group with it. Positive = the change helps. Over a pair, the average of its two games.
- **Standard error (se).** How much the mean gain would wobble if the test were run again: the standard deviation of the pairs' gains divided by the square root of the number of pairs. A gain is only "clear" when it is more than 2 se from 0.
- **SPRT (sequential probability ratio test)** ([Wikipedia](https://en.wikipedia.org/wiki/Sequential_probability_ratio_test)). After each batch the tool works out `llr = delta * (sum of gains - n * delta / 2) / variance`. That compares "the change is better by `delta` places" with "the change is no better". When `llr` rises above `ln(19) = 2.94` the answer is PASS; below `-2.94`, FAIL. Each kind of mistake then happens at most about 5% of the time. It stops as soon as the answer is clear, which saves games, and it never stops before 8 pairs. `delta` is 0.25 places for matches and 0.1 for a duel (a duel's places are only 1 and 2).
- **Top-weighted score.** `1 / log2(place + 1)`: first is 1, second 0.63, third 0.5. It counts winning more without ignoring the rest (the NDCG idea, [The Evaluation of Rating Systems](https://ar5iv.labs.arxiv.org/html/2105.14069)).
- **Why not win rate alone.** In a match of eight each wizard wins 1 time in 8 by chance; telling 12.5% from 15% takes thousands of games. Mean place uses the whole finishing order and needs far fewer. Win share is kept as a veto against a change that survives longer without winning.
- **Why the ladder (duel, then quad, then royale).** Chess engines test a change first at a short time control and confirm at a long one (Stockfish's "STC" then "LTC"). Here the cheap screen is the small game and the confirmation the full one. A duel only tests fighting: a change about choosing fights must go straight to quad.

## Appendix B: what to write to the owner

The owner wants short, plain reports. After each step, three sentences at most: what was done; what the numbers said (with the ± and the number of pairs); what comes next. Example:
> Step 1.3 done. Control spells by the numbers: FAIL, worse by 0.31 places ± 0.11 over 24 pairs; attacks, defenses, heals and ways: no clear difference. Next: step 1.4 on the control spells.

Never write "better" for a result inside 2 se of 0. Never write "tested" for something that was not run.

## Appendix C: reference links (look these up when a step needs them)

- Fishtest (Stockfish's testing system) mathematics: https://github-wiki-see.page/m/xoto10/fishtest/wiki/Fishtest-mathematics
- Pentanomial SPRT implementation: https://github-redirect.dependabot.com/vdbergh/pentanomial
- Sequential probability ratio test: https://en.wikipedia.org/wiki/Sequential_probability_ratio_test
- Rating systems on battle-royale data (NDCG): https://ar5iv.labs.arxiv.org/html/2105.14069
- TrueSkill over full rankings (Neural MMO 2022): https://arxiv.org/pdf/2311.03707
- TrueSkill for free-for-all (LieCraft): https://arxiv.org/pdf/2603.06874
- Plackett-Luce ratings (Agent Island): https://arxiv.org/pdf/2605.04312
- Forza's Drivatar: https://gamedeveloper.com/design/how-forza-s-drivatar-actually-works
- Survey covering Drivatar's history: https://arxiv.org/pdf/2309.14104
- Godot command line (headless, --fixed-fps): https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- openskill (Python ratings library): https://pypi.org/project/openskill/
