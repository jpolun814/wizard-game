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
