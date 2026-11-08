# Chapter 17: the learned AI (started 2026-11-08)

The owner wants the AI wizards to be "indistinguishable from humans" and, to get there, "a trained AI that understands the physics and gameplay and goals", learning from their recordings first and from play second.

## What exists

- **Recording** (`scripts/play_recorder.gd`, chapter 12 of CLAUDE.md): besides the keys, `O` lines (what the wizard senses, 5 a second, built by `scripts/sensing.gd`), `A` lines (move, jump, buttons, 10 a second) and `P` lines (the book, when it changes). Solo games record by themselves (`solo_*.log`); network matches upload (`received_logs`).
- **`scripts/sensing.gd`**: 236 numbers: the wizard, an 11x9 box of ground (solid / platform / lethal), 3 pages, 2 rivals, 4 threats. The same function feeds the recordings, the trainer and the game, so what is learned from people is what the learner sees. Change its layout and every old recording stops fitting (`Sensing.SIZE`).
- **`scripts/learned_brain.gd`**: a `WizardBrain` whose legs (not spells, chants or reflexes) follow a policy. `observe()` adds four tiles of the scripted route as a hint (249 inputs). A trainer drives it through `training/wizard_agent.gd`; in the game, set `brain.policy = PolicyNet.load_file(path)` and it decides ten times a second (`scripts/policy_net.gd`, tested by `tests/policy_net_check.tscn`).
- **Cloning people**: `python training/clone_human.py` reads recordings, trains a small network on (O -> A), prints accuracy on a held-out game against doing the commonest thing, writes `training/human_policy.json`. Run `python training/analyze_play.py` for which spells are cast, cast together, and held when bold or careful.
- **Learning from play**: `python training/train_ppo.py STEPS SEED PORT NAME` (PPO from stable-baselines3 over Godot RL Agents, headless, below-normal priority); `python training/eval_policy.py MODEL.zip|scripted DECISIONS SEED PORT` measures a policy against the scripted legs; `python training/export_policy.py MODEL.zip out.json` makes the JSON the game runs. The training world is `training/wizard_env.tscn` (seven learners; a learner that falls stands up again: `Wizard.keep_when_dead`, `WizardAgent._fallen`).
- **Default (owner, 2026-11-08):** `GameSettings` `learned_ai` is on, so a match's AI wizards walk with `ai/footwork.json` (the PPO network, re-export it with `training/export_policy.py`); the scripted legs stay, deprecated, behind the same setting (Settings, "Trained AI legs"). Do not delete them yet.
- **Strength** (`WizardBrain._feel_strength`): a wizard rates itself 0 to 1 from the attacking pages it holds, its stamina and how it compares with the nearest rival. Above `BOLD_ABOVE` it hunts a rival rather than a far page; below `TIMID_BELOW` it hesitates 3 s and then keeps away from fights. These weights are by hand; the plan is to fit them to what recordings show people hold when they play boldly or carefully.

## Findings so far (not yet a win)

- Godot RL Agents never calls an agent's `reset()`; the agent must stand its wizard up itself (a dead learner earned -5 on every step until this was found).
- PPO from scratch for 150,000 decisions reached about the scripted legs on the seed-5 world (reward 0.0146 a decision against 0.0162, 48 pages against 52 in 3,000 decisions), no better. The reward (nearer the scripted route, pages, not being hurt, no jumps) is what the scripted legs already do well; the scripted legs were not beaten.
- Cloning, with two real games (about 4,900 examples), reaches 92% on the move choice of a held-out game, but velocity in the observation gives most of that away ("keep doing what you were doing"); jumping was no better than never jumping. It needs more games and a better test (does it reach the places a person reaches?) before it means anything.

## Next

- Many more recordings (every game played alone records). Re-run `clone_human.py`; put the cloned policy on an AI wizard (`brain.policy`) and compare its jumps a minute, stillness and fight distance with the numbers in chapter 12 (human: 300 px/s walk, 9 to 16 jumps a minute).
- Fit the strength score and spell-combination values to the recordings (`analyze_play.py` is the start; outcome per cast is not recorded yet).
- Reward for human-likeness (a discriminator against recordings) instead of, or on top of, the hand-made reward.
