# Chapter 18: a training run is going on (2026-11-11). Read this before you change anything.

Another agent is training the learned AI (chapter 17: the curriculum, stage 1, Fireball duels) on this machine, around the clock, and
reporting to the owner every few minutes. Stage 1 passed on 2026-11-12; stage 2 (Fireball, Frostbolt, Barrier, Stone Wall) runs now. You can work on the game in this folder freely; these are the things that would break that run.

## What is running

- **The trainer and its games run from a frozen copy of the project: `C:\Users\Jordan Polun\wizard-train`.** Not from this folder. Your edits
  here do not reach the running training, and that is on purpose.
- **Its results are written here, in `training/duel3/`** (stage 2, the run going now; `training/duel2/` holds stage 1, whose last network began
  stage 2, and `training/duel/` the first stage 1 run: none of them to be touched) (the saved networks `round_N.json` / `round_N.zip`, `champion.*`,
  `progress.log`, `run.log`, `curriculum.json`). The owner also watches a window that reads them.
- Processes: one `python.exe` running `train_duel.py`, five pairs of `Godot_v4.7.2-stable_win64*.exe` with `duel_arena` and `--port=11400` to
  `11404` on their command lines, and one Godot window with `--watch` (the owner's view). A shell loop (`run_duel_forever.sh`) restarts the trainer
  if it stops.

## Do not

1. **Do not touch `C:\Users\Jordan Polun\wizard-train`.** Do not edit, delete or rebuild it.
2. **Do not touch `training/duel3/`, `training/duel2/` or `training/duel/`.** Do not delete, move or rewrite anything in it, and never create a file named `STOP` there (it stops the run).
3. **Do not kill Godot or Python processes you did not start yourself.** Many are the training's. Stop only processes you started (by their
   process id), never by name.
4. **Do not use ports 11400 to 11404.** The training's games listen there. The quick checks use their own ports; anything new you write that opens
   a port must use another.
5. **Do not commit, revert or reformat the uncommitted work in this folder.** Nothing from 2026-11-11 is committed yet (the hand, the senses
   layout 3, the duel arena, the trainer, fixes in the wizard, the arena, Ice Prison and others). Never run `git checkout .`, `git reset --hard`,
   `git stash` or `git clean`. Commit only what the owner asks you to, and only your own files.
6. **Do not change, without the owner and the training agent agreeing, the things a trained network depends on.** The next stage of training
   copies this folder again, and a network trained on one shape cannot read another:
   - `scripts/senses.gd`: what is sensed and in what order (`Senses.SIZE`, `LAYOUT`, the order of everything in `observe()`, `SPELL_ORDER`,
     `CHANT_ORDER`). New spells go in the spare places at the end of `SPELL_ORDER`, never between.
   - `scripts/hand_brain.gd`: `HEADS`, `AIM_COLS`, `AIM_ROWS`, `mask()`.
   - `training/hand_agent.gd`, `training/tactics_agent.gd`, `training/duel_arena.gd`, `training/training_arena.gd`, `training/train_duel.py`,
     `training/entity_net.py`, and `scripts/policy_net.gd` (it runs the trained networks: `tests/entity_net_check.gd` must keep passing).
   - The rules a person and an AI share in `scripts/wizard.gd` and `scripts/arena.gd` (facing, misfires, words told to a wizard, cast costs):
     change gameplay as the owner asks, but say in your report what changed, because it changes what the AI must learn.

## Expect

- **A slow machine.** The training uses most of the processor. Your tests run slower, and timing-sensitive ones (the network checks, anything
  with a time limit) can fail from starvation alone. Run only the checks you need (`python tools/run_checks.py NAME ...`), not the full set, and
  rerun a failure once before believing it.
- `tests/hand_check.tscn`, `tests/training_arena_check.tscn` and `tests/senses_check.tscn` (in the quick set) cover the training's pieces: if a
  change of yours breaks one of them, it would break the next stage of training.
