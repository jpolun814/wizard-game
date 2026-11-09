# 18. Plan: an AI that plays within a human's limits, and plays better than one

Written 2026-11-09 from the owner's words, and corrected by the owner the same day. Nothing here is built yet. Read `17_learned_ai.md` first (what exists and what has not worked).

**Not superhuman (owner).** The AI has a human's body: the same sight, hands, reaction time and attention. It may beat people only by playing better (better choices, timing and strategy), never by doing something a person's body could not.

## The owner's goals

1. The AI should **play better than a human**, not only like one. It should learn strategies humans have not found.
2. It should be able to learn **without human data** (self-play, win or loss). Human recordings are a head start and a brake on strangeness, not the source.
3. It must obey **the limits a human has**. These are rules of the body, not suggestions. "Obviously it needs limited sight."
4. The owner will be **away about two days** and wants training running that whole time. So the work is: build the limits, prove on a short trial that training moves, then launch a long unattended run.
5. Nothing is swapped in as the default AI unless it clearly beats the scripted AI in many seeded matches. The scripted AI stays as the fallback.

## The owner's decisions for the unattended run (2026-11-09)

- **Swap in:** a trained AI that passes the test becomes the default; the scripted AI stays as the fallback, one setting away.
- **Passing is not the end (owner):** training runs for the whole two days whatever the results. After a pass, the default becomes the bar: a later checkpoint replaces it only if it wins at least 55% against the current default, under the same test.
- **Pass mark:** 200 seeded full matches, 4 trained AIs against 4 scripted; the trained side must win at least **55%**.
- **Commits:** to `main`, only after the quick checks pass.
- **The scripted AI gets the same limits** (Sneak, Decoy, Mirage, smoke and dark, stroke drag, reaction delay), so the comparison is fair.
- **Human-looking comes first:** the AI must stay within the human range (jump rate, waits, moves, measured from the owner's logs); inside that range, winning comes first.
- **Training format:** a mix of duels, small arenas and sped-up physics, moving on to full matches; the decision is always made in full matches.
- **Reaction delay and decision rate** come from the owner's recordings; if the logs cannot show them, 150 to 250 ms.
- **Scope of the network:** where to go, which spell, where to aim and when. The existing stroke code draws the shape, through the hands layer.
- **If the network is not winning after a day:** keep working on the network (reward, setup), not on tuning the scripted AI.
- **People:** the hands layer changes nothing for a person's play.
- **Report:** a private page with win rate over time, kept up to date, and a note in this file.
- **Exploits:** a bug the AI finds and uses (inside a wall, out of reach) is fixed in the game for everyone, the checks run, and every fix is listed in the report.
- **Balance:** changes of any size to a spell's cost or damage are allowed (owner) when self-play shows it is far too strong or useless; every change is listed in the report with the numbers behind it.
- **Variety:** keep a few strong checkpoints with different habits and deal them out, so a match feels like different people.
- **Where:** a trained AI that passes is used everywhere: matches, network seats and the tutorial. In the tutorial it must still pass `tests/tutorial_ai_check.tscn`; if it does not, the tutorial keeps the scripted AI until it does.
- **New pages:** the first cast of a newly found spell waits a person's reading time, measured from the owner's logs (time from a pickup to the Tab press and the first cast).
- **Mouse:** the cursor speed the scripted AI uses now is fine (owner). No drawing off the screen, ever.
- **Who is human:** the AI cannot tell people from AI wizards and treats every wizard the same.
- **Style:** no push toward pages or fighting; whatever wins, within the human range.
- **Every limit first:** all the limits are built and tested before any training starts, however long that takes. No training runs without them.
- **Screen size:** the AI sees what a person sees at the game's default window size and zoom.
- **Human range:** set from everyone's logs, the owner's own and those received from network matches (`received_logs`).
- **No notifications** while the owner is away; the report page is the only channel.
- **No memory between matches:** every match starts fresh; the AI still learns within a match from what it sees.
- **No end date:** training keeps going after the two days until the owner says stop; the report stays up to date throughout.

**Agent's defaults, shown to the owner and not objected to:** training opponents are a mix of the current version, older checkpoints and the scripted AI; a change that breaks a check and cannot be fixed is undone and logged, never committed; checkpoints and logs stay under 20 GB (older ones thinned, every one that became the default kept); the report page is private and updated about hourly; a watchdog restarts Godot or the trainer from the last checkpoint and logs it; a balance change updates the book's stat lines by itself, and no other wording is touched.

## The limits (the owner's list, plus what follows from it)

Enforce them in one shared "hands" layer that people and AI both act through (a virtual keyboard and mouse). A policy, scripted or trained, can then not cheat, and training happens inside the limits.

- **Typing a chant:** no mouse gestures, no moving, no jumping (A, D, W and Space would type letters).
- **Drawing a gesture:** a stroke is in progress while buttons are held; no typing, no second stroke, and switching schools takes a press and a release.
- **Moving while drawing changes the stroke, in two ways:**
  - **The camera drags the stroke.** A stroke is recorded in world space (`Caster._extend` takes `get_global_mouse_position()`). The camera follows the wizard, so a person who holds a button with the mouse still and walks draws a line, not a point; a person who walks while drawing a circle gets the circle smeared along the way they walked. The AI's virtual mouse must be a point on the *screen*: its stroke is the screen path plus the camera's travel, exactly as for a person. A policy that wants a clean shape must stand still or make up for the camera, as a person would.
  - **Shaking adds wobble.** Earthquakes, eruptions, avalanches and the like shake the screen and the hand (`wizard_brain._shaken` today); this goes in the hands layer too.
  - **How much each spell tolerates:** a quick straight stroke like Ignite (under a second) survives being smeared; a precise one like Faint does not. Do not guess: measure it with the recognizer (feed it strokes with added drift and wobble, find the break point), store one tolerance per spell, and check the numbers against the owner's recordings (`play_logs`, K/M/S lines). The tolerance is for testing and for the scripted brain's choices; the drift itself comes from the camera, not from a made-up rule.
- **Limited sight:** only what is on its screen, nothing through walls, smoke or darkness; memory of what it saw, fading; rivals' stamina and book unknown unless seen. Rite of the Land gives the map, as for a person. **Everything that hides from a person hides from the AI:**
  - A wizard under **Sneak** is invisible: the AI cannot see, aim at or track them until a spell of theirs breaks it (unless the AI's own Hex is on them: "they cannot hide from you").
  - A **Decoy** looks exactly like its wizard: the AI cannot tell which is real except by what it sees them do.
  - A **Mirage** looks exactly like a page until it fades.
  - **Smoke Screen**, the volcano's smoke, **Eclipse** and the dark all hide what a person could not see; a **Flare**, Glowcap or Moonbeam lights only what it lights.
  - What reveals is allowed only as it is for a person: Hex, Hunter's Mark, Oculum Mitto, the Scrying Eye, Rite of the Land.
  - Test each of these: an AI next to a sneaking wizard does not turn to them, aim at them or flee them.
- **Reaction delay** (about 150 to 250 ms, varying), a **decision rate** limit, and **attention** (the main target tracked; other threats noticed late).
- Button chords (two or three buttons) are not pressed in the same instant.
- **No made-up mistakes (owner):** the AI does not misclick or mistype chants on purpose. The hard rules above are the only limits.
- Already in the scripted brain (check, do not redo): typing time, a hand's wobble (`_handed`), rare jumping, limited sight in matches (`_sight_is_limited`).

## Where each limit lives

- Hands layer: typing and mouse exclusion, chords, the virtual mouse in screen space (so the camera drags its stroke), shake wobble.
- Sensing (`scripts/sensing.gd`): sight, hiding (Sneak, Decoy, Mirage, smoke, dark), memory, delay.
- The policy: nothing. It sees only what the layers give it.

## Order of work

1. **Audit** which limits the scripted brain, the learned footwork and the human input path already obey (the chant box captures keys for people; is the AI held to it? Does the brain see a sneaking wizard? Does it draw its strokes in world space, untouched by its own walking?).
2. **Hands layer**, with both people and AI routed through it. Test: impossible inputs (cast while typing, move while typing) are refused, and a held click while walking draws a line.
3. **Per-spell drift and wobble tolerance**, measured with the recognizer.
4. **Sensing limits** (sight, hiding, memory, delay), also in the training environment (`training/wizard_env.gd`, `wizard_agent.gd`), so the network learns inside them.
5. **Let the network choose spells and timing** from the casts the scripted brain can already draw (this is where new strategy can appear; footwork alone cannot discover any).
6. **Self-play training**: whole matches, win or loss as the main reward, a small shaping reward for pages and kills, a few hard safety rules early (lava, piranha water). A human-likeness pull toward `training/human_policy.json` that decays, adjustable.
7. **Trial run of 30 to 60 minutes.** If the reward does not move, fix the reward before the owner leaves, not after.
8. **Long unattended run**: checkpoints saved often, auto-restart if Godot crashes, a progress log.
9. **Evaluate** every checkpoint with `training/eval_policy.py` against the scripted AI in many seeded matches (win rate), and against the owner's recordings for human-likeness (jump rate, waits, reaction time, stroke success). Swap `ai/footwork.json` (or its successor) only if clearly better.

## What is known so far

- Reward per decision has been flat (about -0.02 to -0.03) in every PPO run so far (`run_s5`, `run_h7`, `run_h8`); none has been evaluated against the scripted legs yet. Evaluate them first, so the long run starts from what works.
- A policy trained without a limit and then given it often falls apart, so the sensing, hiding and delay limits belong in training from the start.

## State when this was written

- `training/human_policy.json` was retrained on 26,160 examples (own and received logs): 95% on moves and jumps held out.
- `run_h8` (600k steps, human weight 0.05, port 11013) was started overnight 2026-11-08 and was running at about 355k steps; `run_h7` finished its 400k; `run_s5` finished 300k. All unevaluated.
- Standing rules still apply (CLAUDE.md): no new spells without approval, no agent-made art or sound, wording is draft until confirmed, gate commits on checks, report outcomes faithfully.
