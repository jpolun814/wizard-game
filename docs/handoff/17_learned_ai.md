# Chapter 17: the learned AI (started 2026-11-08)

The owner wants the AI wizards to be "indistinguishable from humans" and, to get there, "a trained AI that understands the physics and gameplay and goals", learning from their recordings first and from play second.

## The approach now (owner, 2026-11-11): a curriculum, through a person's controls, with no scripted brain

The owner's goal: an AI that **learns to play**, with all and only a person's inputs (what is on their screen) and a person's controls, so that once
trained it plays as well as a person. The earlier work did not do that: the trained legs were rewarded for keeping to the scripted route, and the
tactics network sat on top of the scripted brain and started as a copy of it, so neither could become more than the scripted brain with adjustments
(the tactics run measured 0.51, 0.45, 0.46 against the scripted brain and was stopped). **Do not build a learner on top of the scripted brain.**

What is built (stage 1):
- **`scripts/hand_brain.gd` (`HandBrain`)**: a wizard played only through the controls. Every 0.2 s it chooses (HEADS, in the alphabetical order
  of their names, because Godot RL Agents sorts the heads by name: a different order put the mask in the wrong places) where to aim on a 32 x 18 grid
  over the screen (12 x 7 was too coarse to hit a wizard across a lane), which spell from its book (or none), jump, and move. The hand draws the
  chosen spell's picture there with a person's speed and wobble, and the recognizer reads it. A mask says what can be chosen now (a spell in the
  book, the hand free); `HandBrain.observe()` is the senses then the mask (4,044 numbers). `PolicyNet.choose` takes the allowed choices. Test:
  `tests/hand_check.tscn -- --opponent=dummy --lanes=1` (in the quick set).
- **`training/duel_arena.gd` (`DuelArena`)**: the training arena's lanes with two hand-played wizards. The learner (`training/hand_agent.gd`) fights a
  network from the pool of its own past versions (the latest 80% of bouts, an older one 20%, as OpenAI Five did), or a yardstick for a measure
  (`--opponent=dummy`: stands; `turret`: stands and casts the stage's first spell at it). `STAGES` lists each stage's spells.
- **`training/train_duel.py`**: MaskablePPO (sb3-contrib), a 256 x 256 network, reward from outcomes only (strength taken against strength lost, the
  bout won or lost). Every 5 rounds a measure, learning nothing: against the dummy (counted only by felling it: can it aim?), the turret (can it
  dodge and win?) and an earlier version of itself (still improving?). Pass marks in `PASS`. Run with `run_duel_forever.sh` (OUT=duel); output
  in `training/duel`.
- **Between bouts** the arena clears everything a bout left in the lane, fills any pit, and stands up two fresh wizards (a skeleton left standing
  had killed the wizard who stood up beside it, bout after bout); a bout that runs its time is decided on points. `tests/training_arena_check.tscn`.

Why each choice (research, 2026-11-11):
- Self-play against a pool of past versions, not only the latest: self-play alone cycles and forgets (AlphaStar; OpenAI Five's 80/20; Unity
  ML-Agents' self-play guide: the rating against past versions should rise steadily).
- A curriculum of stages beats plain self-play in a real-time fighting game (Oh et al., Blade & Soul, 62% against professionals).
- Masking impossible choices, not punishing them (Huang and Ontanon, 2020).
- A spell plus where to cast it is a "parameterized action" (H-PPO); the hand drawing the picture is the owner's choice (option B).
- Learning from nothing does not reach a whole complex game on one machine: OpenAI Five used about 45,000 years of play; AlphaStar learned from
  human replays first and said self-play alone had almost no chance. Plan: stages from scratch while they are small; from the pages stage on, a
  start from the owner's recordings (behaviour cloning, then self-play with a pull toward human play), and possibly the scripted brain as a teacher
  whose weight falls to nothing (kickstarting, Schmitt et al. 2018). More recordings help most.
- When a stage adds spells, keep playing the earlier stages too, or it forgets them.

What stage 1 taught (2026-11-11):
- A hit worth 0.24 (DUEL_HARM 0.02 a point) against swings of 1 for a bout was too faint: four in a hundred shots hit for 1.5 hours. At 0.1 a point
  (`HandAgent.HAND_HARM`), with a near-miss reward that fades as aiming is learned (`HandAgent.NEAR_MOST`, gone at a quarter of shots landing) and
  half the bouts against a standing dummy at first (fading as it fells the dummy), it went from 4% to 45% of shots landing and from never felling
  the dummy to 90% in about four hours.
- **How often a shot can land is limited by the game, not only the aim.** The hand alone hits a still dummy 98% of the time; a perfect aimer firing
  as fast as it can in a real bout lands 75%, because each Fireball knocks the target back and a wizard cannot be hurt again for HURT_GRACE (half a
  second) after a hit: a shot inside that window strikes but does nothing. So "hit share" will not reach 90%; felling the dummy is the measure of aim.
- Choices are drawn by weight (as a person varies). With the pull toward trying everything at 0.003 its aim was spread wide: 57% of shots landed at
  its likeliest choice, 48% drawn by weight. Lowered to 0.001 (`ENT_COEF`) to sharpen it.
- Things a probe must not trip over: a network on the learner's side with no trainer (a window to watch) needs the arena to clear "done" at the end
  of a bout (`DuelArena._physics_process`), or the next bout waits for the agent's long reset; and run probes in the frozen copy, not here.

**The second network (2026-11-11 evening, `training/duel2`):** the first run's one flat network (4,814 numbers into 256 x 256) learned to aim (the
dummy 93%, 74% of shots landing, at the ceiling) and stalled at dodging (the turret about 55%). Its replacement, `training/entity_net.py`, reads the
lists of like things (the things on screen, the other wizards) with small encoders of their own, the same for every slot, pooled (the most and the
mean over slots that hold something), and the rest through a layer of its own, as OpenAI Five and AlphaStar do. `PolicyNet` runs it in the game
(kind "entity"); `tests/entity_net_check.gd` checks it gives the trainer's numbers (`training/make_entity_fixture.py` writes the fixture);
`HandBrain.fits` refuses a network trained on another layout (`Senses.list_spans`). The run starts with what the first one learned to need: a hit
worth 0.1 a point, the near-miss reward, dummy practice from half falling to a floor of a quarter, the too-tired cost, and, once half its shots land
on the dummy, the finer learning rate (1e-4) and the smaller pull toward trying everything (0.001). The first run is kept in `training/duel`.

It learned about three times as fast as the first (the turret 54% at round 45, against 18%), then stalled at the dummy about 77% and the turret
about 52% (rounds 50 to 65). A probe of 44 bouts against the dummy (a copy of the frozen copy with a line printed at each bout's end) found two kinds
of lost bout: too slow against a dummy that began strong (skill), and lost: it walked off and ended 1,000 to 1,500 px away having cast once or
twice. Bouts began up to 560 px apart and the screen shows only 427 px to either side, so a third began with the other out of sight, and the
learner, which sees only the screen, often walked the wrong way. `TrainingArena.GAP_MOST` is now 380 (from round 69): both begin on the screen.
Finding a rival out of sight is for the worlds, later. Taking its likeliest choice at every step instead of drawing by weight was far worse (the
dummy felled 9 of 38): its likeliest choice at most moments is not to cast, so play it drawn by weight.

**Stage 1 passed** at round 85 (2026-11-12, about six hours): the dummy felled 93%, the turret beaten 83%. The first run never passed the turret.

**Stage 2 (`training/duel3`): Fireball, Frostbolt, Barrier, Stone Wall** (`DuelArena.STAGES`). It begins from stage 1's round 85
(`train_duel.py --stage 2 --from training/duel2/round_85.zip`, kept as `champion.zip/json` and as the pool's round 0):
- The new spells' choices begin as Fireball's, a third as likely (`warm_start`, `NEW_SPELL_SHARE`): choices a network was never allowed are left
  where chance put them and would seldom be tried.
- A quarter of its training bouts are fought with stage 1's book (`DuelArena.EARLIER_SHARE`), so it keeps what it knew.
- Its measure adds a bout against the champion, which has only Fireball (`--opponent_stage=1`): the pass mark is the dummy 90%, the turret 60% and
  the champion 60% (`CHAMPION_PASS`). It refines (the finer learning rate) once it beats the champion half the time. Each measure lists how often
  each spell was cast, and "misread" for strokes read as a spell not in the book.
- The hand begins a shape drawn from the ground (a Stone Wall, `GestureTemplates.preview_ground`) on the ground under the aimed point
  (`HandBrain._from_ground`); it had drawn a flick from the body, as Stone Wall is "directional". `tests/hand_stage_check.tscn` casts each spell.
- A stroke read as a spell not in the book now tells a brain's wizard "misfire", as a person sees the puff (`Arena.cast_by`). About 7% of the
  hand's Barrier circles were read as Vacuum, and 2% of its Fireball flicks as other fire spells (the hand's wobble, `_handed`).
- The aim is one choice for every spell (the heads are independent): it must learn where to aim from the moment, not from the spell. Barrier wraps
  the caster wherever it is drawn, so its aim does not matter; a Stone Wall rises at the aimed column.

The curriculum after stage 1: more spells a few at a time, then more wizards, then pages, then ground and creatures, then each biome, then mixed.

## What exists (the earlier work)

- **Recording** (`scripts/play_recorder.gd`, chapter 12 of CLAUDE.md): besides the keys, `O` lines (what the wizard senses, 5 a second, built by `scripts/sensing.gd`), `A` lines (move, jump, buttons, 10 a second) and `P` lines (the book, when it changes). Solo games record by themselves (`solo_*.log`); network matches upload (`received_logs`).
- **`scripts/sensing.gd`**: 236 numbers: the wizard, an 11x9 box of ground (solid / platform / lethal), 3 pages, 2 rivals, 4 threats. The same function feeds the recordings, the trainer and the game, so what is learned from people is what the learner sees. Change its layout and every old recording stops fitting (`Sensing.SIZE`).
- **`scripts/senses.gd` (`Senses`, the second layout, 2026-11-11)**: replaces `Sensing` for all new training; `Sensing` stays, unchanged, because `ai/footwork.json` and `training/tactics/round_*.json` were trained on it (each brain picks the layout its network's input count fits). 3,923 numbers: the wizard (breath, the liquid it is in, its conditions and spells on it), the screen's tiles at two sizes, each described by what it does (solid, platform, liquid, no air, hurts, slows, slick, climbable, lifts, seen), remembered ground, every thing and rival on screen with motion (rivals with the stroke they are drawing), remembered rivals and pages, the whole book, the minimap, Insight, the Scrying Eye, and 24 spare numbers (and spare book places for new spells: add them at the end of `SPELL_ORDER`). A network has no memory, so a person's memory is given to it here. A new world's thing says what it does with `sense_traits()` and where to watch it with `sense_point()`. What it covers and what is still missing: `training/senses_audit.md`. Each wizard has one (`Wizard.senses`). A look costs about 3 ms; `PolicyNet.forward` skips zero inputs. The recorder writes it as `V` lines (`clone_human.py` does not read them yet). Test: `tests/senses_check.tscn`.
- **`scripts/learned_brain.gd`**: a `WizardBrain` whose legs (not spells, chants or reflexes) follow a policy. `observe()` adds four tiles of the scripted route as a hint (249 inputs). A trainer drives it through `training/wizard_agent.gd`; in the game, set `brain.policy = PolicyNet.load_file(path)` and it decides ten times a second (`scripts/policy_net.gd`, tested by `tests/policy_net_check.tscn`).
- **Cloning people**: `python training/clone_human.py` reads recordings, trains a small network on (O -> A), prints accuracy on a held-out game against doing the commonest thing, writes `training/human_policy.json`. Run `python training/analyze_play.py` for which spells are cast, cast together, and held when bold or careful.
- **Learning from play**: `python training/train_ppo.py STEPS SEED PORT NAME` (PPO from stable-baselines3 over Godot RL Agents, headless, below-normal priority); `python training/eval_policy.py MODEL.zip|scripted DECISIONS SEED PORT` measures a policy against the scripted legs; `python training/export_policy.py MODEL.zip out.json` makes the JSON the game runs. The training world is `training/wizard_env.tscn` (seven learners; a learner that falls stands up again: `Wizard.keep_when_dead`, `WizardAgent._fallen`).
- **Default (owner, 2026-11-08):** `GameSettings` `learned_ai` is on, so a match's AI wizards walk with `ai/footwork.json` (the PPO network, re-export it with `training/export_policy.py`); the scripted legs stay, deprecated, behind the same setting (Settings, "Trained AI legs"). Do not delete them yet.
- **Strength** (`WizardBrain._feel_strength`): a wizard rates itself 0 to 1 from the attacking pages it holds, its stamina and how it compares with the nearest rival. Above `BOLD_ABOVE` it hunts a rival rather than a far page; below `TIMID_BELOW` it hesitates 3 s and then keeps away from fights. These weights are by hand; the plan is to fit them to what recordings show people hold when they play boldly or carefully.

- **The training arena** (`training/training_arena.tscn`, `TrainingArena`, 2026-11-11): flat lanes walled at both ends, far enough apart that nobody sees into the next, one duel to a lane (a TacticsBrain learner against the scripted brain, or now and then an earlier network). A bout ends when either falls or after `BOUT_LIMIT` (60 s, a draw); then both stand, a new gap apart, each with a new random book and a random maximum stamina (60 to 200). Run with `train_tactics.py --arena --lanes 4` (or `OUT=tactics_arena ENVS=4 EXTRA='--arena --lanes 4' ./run_tactics_forever.sh`). A new network starts as a copy of the scripted brain (`scripted_start`: the last layer leans hard to "the scripted pick" and "the scripted footwork"); at a lean of 6 it strayed one choice in ten, often into a spell that hurt it, and won 37% of bouts, so the lean is 9 and 8. Every third round is against the scripted brain alone, and the progress log's "won" share is the quick measure (round 1 of the copy: 0.54). Speed (2026-11-11): the trainer in Python was the bottleneck (the games waited on it half the time), mostly reading thousands of numbers sent as text; `TacticsAgent.get_obs` now sends only the places that are not zero and `training/gd_launch.py` unpacks them (nothing is lost: a place not named is zero), torch is held to two threads (`TRAIN_THREADS`), and the layout was trimmed. From about 85 to about 146 decisions a second with 5 copies of 4 lanes (`ENVS=5`). The graphics card build of torch is installed (`--device cuda`), but the processor was faster (61 s against 72 s for the same round), as Stable-Baselines3 says it is for small networks. Bouts are at most 45 s and begin with most stamina 40 to 200. Test: `tests/training_arena_check.tscn`.

## Findings so far (not yet a win)

- Godot RL Agents never calls an agent's `reset()`; the agent must stand its wizard up itself (a dead learner earned -5 on every step until this was found).
- PPO from scratch for 150,000 decisions reached about the scripted legs on the seed-5 world (reward 0.0146 a decision against 0.0162, 48 pages against 52 in 3,000 decisions), no better. The reward (nearer the scripted route, pages, not being hurt, no jumps) is what the scripted legs already do well; the scripted legs were not beaten.
- Cloning, with two real games (about 4,900 examples), reaches 92% on the move choice of a held-out game, but velocity in the observation gives most of that away ("keep doing what you were doing"); jumping was no better than never jumping. It needs more games and a better test (does it reach the places a person reaches?) before it means anything.

## Next

- Many more recordings (every game played alone records). Re-run `clone_human.py`; put the cloned policy on an AI wizard (`brain.policy`) and compare its jumps a minute, stillness and fight distance with the numbers in chapter 12 (human: 300 px/s walk, 9 to 16 jumps a minute).
- Fit the strength score and spell-combination values to the recordings (`analyze_play.py` is the start; outcome per cast is not recorded yet).
- Reward for human-likeness (a discriminator against recordings) instead of, or on top of, the hand-made reward.
