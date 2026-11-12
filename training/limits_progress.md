# Progress log: human-limits AI (plan: docs/handoff/18_human_limits_ai_plan.md)

The owner left on 2026-11-09 for about two days and said "go". Work unattended; ask nothing. Keep training after the two days until the owner says stop.
Each heartbeat: read this file, carry on with the next unfinished step, append a dated line here.

## Steps
- [x] 1. Audit of limits (training/limits_audit.md)
- [ ] 2. Hands layer (people unchanged; AI through it): typing/drawing exclusion, chords, screen-space virtual mouse (camera drags stroke), shake wobble, no drawing off screen, current cursor speed
- [x] 3. Per-spell drift/wobble tolerance measured with the recognizer (ai/stroke_drift.json)
- [ ] 4. Sensing: default-window sight, walls/smoke/dark, Sneak (Hex exception), Decoy, Mirage, fading memory, reaction delay and decision rate from everyone's logs, attention, reading time for new pages, no human/AI knowledge
- [ ] 5. Same limits in training env (wizard_env.gd / wizard_agent.gd); scripted brain also held to them
- [ ] 6. Network chooses moves, spells, aim, timing
- [ ] 7. Self-play (mix: current, older checkpoints, scripted; duels, small arenas, sped-up, then full matches)
- [ ] 8. Trial 30-60 min; reward must move
- [ ] 9. Long run with watchdog, checkpoints (<20 GB), progress log
- [ ] 10. Eval: 200 seeded full matches, 4 trained vs 4 scripted, >=55% to swap; after that, beat current default by >=55%
- [ ] 11. Report page (private artifact), updated about hourly

## Log
- 2026-11-09: plan settled with the owner; audit started.
- 2026-11-09: step 3 measured: `tests/measure_drift.gd` -> `ai/stroke_drift.json` (largest slide in px, per direction, per spell). Flicks survive ~480 px forward, ~80 back; Raise Dead, Mirage, Great Oak 12-20 px. Found: AI strokes are finished world strokes injected via `Caster.cast_stroke` after `Wizard.start_drawing` (no camera drag); `_handed` has deliberate botches (owner: no made-up mistakes, remove). Player camera: smoothing speed 7, offset (0,-150), zoom 1.5, viewport 1280x720. run_h8 (old, no limits) still running at ~364k/600k; left to finish.
- 2026-11-09 ~05:30: committed 7752100: Eyes (screen-sized view, camera smoothing), sight limits (screen, smoke, eclipse, dark/lights, Sneak incl. the person, Hex shows), rival memory 8 s, Decoys fool, strokes on screen/one at a time/not while typing, camera drag of strokes, drag tolerance use (stop to draw, Featherfall at fall start), chants typed everywhere, no botches. tests/limits_check.tscn. Quick set 56/56.
- 2026-11-09 06:10: measured people (training/measure_human.py -> ai/human_limits.json, 15 files): letter 0.08-0.15 s (brain was 0.25: now measured), reaction p25 0.25 / median 0.5 (brain now 0.25-0.65 by skill), chord gap 0.01-0.05 s, book open at a new page 0.87-1.55 s (brain now waits that long before casting a new spell), stroke floor = people's p25 per spell (n>=3). Quick set 57/57.
- Still to do for the limits: attention; creatures/dangers only when seen; the map leak (the brain plans paths through unseen ground); Sensing (training obs) through Eyes; LearnedBrain obeys the same (it inherits WizardBrain).
- 2026-11-09 06:45: committed: explore over seen ground only, attention lag 0.25 s off the rival's side, Sensing through Eyes (rival stamina -> drawing flag), Blizzard deferred physics fix. arena_sim 240 s vs old: seed 3 pages 16 vs 7, seed 7 14 vs 10 (limits do not cripple it). Quick 57/57. Next: TacticsBrain (network picks attack spell + movement mode over the scripted brain), self-play env.
- 2026-11-10 20:15: owner back. Tactics training ran ~37 h (556 rounds, 13.7M decisions), reward flat at ~0.001 throughout; no evaluation run; report page never published (claude.ai login missing). Heartbeat stopped; waiting for the owner's call on stopping the loop and evaluating.
- 2026-11-10 21:05: owner said go. Stopped the tactics loop at round 556; committed 33f3c2c (tactics brain/trainer/eval, crash fixes) and 5a5c499 (duel mode). Running: 200-match eval of round 556 (training/tactics/eval_556.txt), then training/night_plan.sh trains duels 5 h (training/tactics_duel) and evaluates the last duel round (log: training/tactics_duel_night.log).
- 2026-11-10 22:59: round 556 eval: trained won 65, scripted 109, draws 26 of 200 (share 0.374, z -3.34): clearly worse than the scripted AI, not swapped in. Duel training started (training/tactics_duel).
- 2026-11-11 01:00: owner asked that the AI see all a person sees before more training. Done: training/senses_audit.md, scripts/senses.gd (second layout, memory, book, every thing and rival, minimap, Insight, Scrying Eye), the scripted brain's eye no longer finds rivals (a person's window does not say where), the tactics brain faces the way it walks. Training arena built (training/training_arena.tscn). Fixed on the way: limits_check's decoy test was flaky (the person was put back beside the looker), a reaction against a rival gone from mind, a Geyser pushing a dying creature.
- 2026-11-11 01:47: long run started in the arena (training/tactics_arena, run_tactics_forever.sh, ENVS=4, --arena --lanes 4). Round 1, a copy of the scripted brain: won 37 lost 32 against it (0.54). Owner asleep; to be looked at in the morning: does "won" in the every-third-round scripted lines climb past 0.55?
- 2026-11-11 02:10: found two training loops writing to tactics_arena at once (the first loop restarted itself after the folder was moved); both stopped, results set aside in the temp folder.
- 2026-11-11 02:37: speed-ups done (packed senses, torch threads, trimmed layout to 3,923, cheaper looks, shorter bouts; graphics card tried and slower). Run restarted fresh: training/tactics_arena, ENVS=5, --arena --lanes 4, about 146 decisions a second.
