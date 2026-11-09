# Progress log: human-limits AI (plan: docs/handoff/18_human_limits_ai_plan.md)

The owner left on 2026-11-09 for about two days and said "go". Work unattended; ask nothing. Keep training after the two days until the owner says stop.
Each heartbeat: read this file, carry on with the next unfinished step, append a dated line here.

## Steps
- [ ] 1. Audit of limits (background search started)
- [ ] 2. Hands layer (people unchanged; AI through it): typing/drawing exclusion, chords, screen-space virtual mouse (camera drags stroke), shake wobble, no drawing off screen, current cursor speed
- [ ] 3. Per-spell drift/wobble tolerance measured with the recognizer
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
