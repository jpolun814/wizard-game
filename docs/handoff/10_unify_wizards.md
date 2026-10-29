# 10. Make every wizard the player character (DONE; kept for the reasons it gives)

**Status: built.** `scripts/player.gd` is now `scripts/wizard.gd` (`class_name Wizard`, scene `scenes/wizard.tscn`). One body is
driven either by a person (`brain == null`, group `"player"` as well) or by a `WizardBrain` (`brain != null`); all four are in
group `"wizards"`. `mob.gd` holds no wizard code any more; spells branch `mobs` against everything else, so a wizard takes the
former player path whoever drives it. The lifts over a wall (Geyser, Push, Liana; `WizardBrain._lifting`), Obsidian Armor over lava, Deep Breath through gas and the Eclipse screen veil are built; the stone stair, Great Oak, Tornado and thorns are not (`docs/pvp_arena_design.md` says why). Eclipse darkens the
screen of whoever watches from inside it. Parity is tested by `tests/parity_check.tscn`. The text below is the plan as it was
written, and the survey tables describe the code before the change. What the owner should know changed: rivals die, freeze,
tangle and are shoved exactly as the player is; they pay stamina for jumps and running (and rest when it runs low); they can
drown; a fireball no longer knocks them back; a frozen rival can still act, as the player can.

Read this if you are the agent who takes over after the "AI wizards use every way a player has past a gate" work
(commit `6c72f13` on `main`). It says what to do and why.

## The job: one wizard body, driven by a person or by the brain

### A1. What the owner said, and why it matters

The owner's words, in order:

- "nothing should be player only."
- "i want the AI to do the same things a player would be able to do ... all the ways a human player would be able
  to do it i want the AI to do."
- "why would it act differently for an AI than a player? ... why wouldnt the AI also get 'launch speed and
  decaying push'?"
- "we absolutely need to treat the other wizards as the player character. that would've made so much of this so much easier, right?"

The game is now a last-wizard-standing PvP arena with four **identical** wizards (the player plus `dark_wizard`,
`pyre_wizard`, `bone_wizard`). Later real people will replace the AIs (multiplayer is not built). If a rival is a
different kind of body from the player, then every fight is subtly unfair and every future human opponent would
need yet another code path. The owner wants that gone: **a wizard is a wizard.**

### A2. The problem in the code today

There are two body types:

- `scripts/player.gd` (`extends CharacterBody2D`, 704 lines, group `"player"`): input-driven, has stamina, `push()`
  (a held thrust that fades: `_shove`), `apply_debuff("slow" | "tangle" ...)`, `take_damage(amount, shot, ...)`,
  `has_shield()`, `holding_breath()`, `lava_proof()`, `is_frozen()`, `facing`, and so on.
- `scripts/mob.gd` (`class_name Mob`, `extends CharacterBody2D`, 1127 lines, group `"mobs"`): used for every
  enemy **and for the three AI wizards**. It has `knock_back()` (one impulse; gravity then takes over),
  `apply_slow()`, `take_damage(amount, school)`, a `KINDS[kind]` table with `role` ("flyer", ...), and a
  `brain: WizardBrain` created in `mob.gd:1028` for the wizard kinds.

Spells (and hazards) therefore **branch on the body type**. The survey the last session ran
(`grep -rn 'is_in_group("mobs")\|is_in_group("player")\|knock_back\|\.push(' scripts`) found these splits:

| Where | What differs |
|---|---|
| `spells/geyser.gd:141-144` | mobs `knock_back(-820)`, player `push(-1000)`. **The AI wizard rises about 185 px, a wall is 288 px; the player's sustained thrust goes higher.** This is why the Geyser lift over a wall could not be built for the AI. |
| `spells/burst.gd`, `earthquake.gd`, `great_oak.gd`, `gust.gd`, `push_zone.gd`, `tornado.gd`, `tide_surf.gd` | player `push()`, everyone else `knock_back()`. Push is "the only spell that lifts you", yet an AI wizard gets only a kick. |
| `spells/spell_targets.gd` (`affects`, `hurt`) | enemies take "school damage (weak, resisted)"; the player takes it plain; a frozen player is shattered for 1.5x. AI wizards take the weak enemy version, so spells hurt you more than a rival. |
| `spells/bramble.gd:65-76`, `pond.gd:60-70`, `gas_bank.gd:88-96` | the player gets `apply_debuff("tangle"/"slow")`, mobs get `apply_slow(0.3)`; thorns hurt the player on every footfall; gas can be resisted only by `holding_breath()` (player). Flyers are exempt from several. |
| `arena.gd:397` | **Tide Surf is spawned only if the caster is the player.** An AI wizard that knows it casts nothing. |
| `spells/fire_breath.gd:37`, `spore_puff.gd:45` | only the player turns to face the breath. |
| `spells/projectile.gd:90-104`, `enemy_bolt.gd:92-103` | shield/Barrier checked separately for the player and for mobs; shots knock mobs back but push the player differently. |
| `lava_proof()` (Obsidian Armor) | only guarded with `has_method`, so probably player-only. |

(The list is from a grep, not from playing. Some entries may hide more splits; re-run the grep.)

### A3. The plan (do it in stages; run the tests after every stage)

**Stage 0. Survey and write the plan down.** Read `player.gd` and `mob.gd` completely. Make a table of every
public method/property the spells and hazards call on a body (`take_damage`, `push`, `knock_back`, `apply_slow`,
`apply_debuff`, `has_shield`, `raise_shield`, `is_frozen`, `soak`, `holding_breath`, `lava_proof`, `center()`,
`stamina`, `hp`, `ledger`, `caster`, `start_drawing`, `is_drawing`, ...). That table is the interface a wizard
must have. Check `SpellTargets.wizards(tree)` (the list of wizards still standing) and `HUD`/camera/minimap code,
which also assume "player = the one wizard".

**Stage 1. One wizard class.** Recommended shape (decide after the survey, but this is the idea):

- A `Wizard` body (start from `player.gd`, rename/split) holding everything about *being a wizard*: movement
  physics, jump, stamina (single bar: max 200 = the cap, damage lowers max, death at 0), damage and status
  effects, `push`, shields, the `caster`, the ledger of pages.
- Two **controllers** feed it: `PlayerInput` (keyboard/mouse, today's player code) and `WizardBrain` (already
  exists; it currently talks to a `Mob`). The controller only produces: a walk direction/speed, jump, and drawn
  strokes. The body does the rest identically.
- Group: put every wizard in one group (e.g. `"wizards"`) and keep `"player"` only for "the wizard the camera/HUD
  follows" if that distinction is still needed (spectating already follows a rival; see `spectate_check`).
- **Mobs stay mobs.** Sentinels, piranhas, enemies keep `Mob`. Only the four wizards change.

**Stage 2. Delete the splits.** For each row in the table above make the spell treat a wizard through one method
(`push`, `take_damage`, `apply_debuff`, ...). Delete `knock_back` for wizards, the `"Flora"/school` weak-damage path for
wizards, the Tide Surf `is_in_group("player")` guard, the facing guards, etc. Remember the repo rule: "no
branching on spell names in shared scripts" and "delete dead code".

**Stage 3. Put back what the split blocked.**
- The Geyser lift over a wall in `WizardBrain` (it was removed in `6c72f13` because it could not work). Reference
  design: walk to the wall face, draw a Geyser under the feet (`GestureTemplates.preview_points("geyser")`; note
  `"geyser_peak"` returns an empty array and throws out-of-bounds), wait for the launch, move across once the feet
  clear the wall top (`span.position.y - 26`), and treat landing on the near side as failure (`_cannot`). `git show 3e6c6e4..6c72f13 -- scripts/wizard_brain.gd` or `git log -p -S_lifting` shows the removed code.
- Check Push as a wall solution too (it "lifts about 250 px", marginal against 288 px).
- Then consider the other human ways the AI still lacks: Liana, Great Oak (climb), Push, Stone Wall (as a stair),
  Obsidian Armor over lava, Shadow Step through thorns, gas or ice.

**Stage 4. Retune and re-test.** Walk speed, jump height (apex ~138 px), stamina costs, the AI's reaction times
(`ATTACK_DRAW`, `QUICK_DRAW`, etc. in `wizard_brain.gd`) were tuned for `Mob`. They will shift. Expect the
crossing tests to need small changes.

### A4. Why this is worth the risk, and the risks

Why: fairness, one code path (every spell has half the branches), and multiplayer later (a remote human is just
another controller). Risks: it touches most spells and the HUD/camera/minimap; the AI's navigation (`WizardRoute`,
`WorldNav`) was tuned on mob physics; the three AIs' hit-box/animation setup lives in `mob.gd` + `mob_kind.gd` +
`char_frames.gd` (the `dark_wizard`, `pyre_wizard`, `bone_wizard` kinds use the Luiz Melo wizard sprites). The
owner will notice if the fights feel different: rivals will die as easily as the player and be frozen/tangled the
same way. That is intended; tell them.

### A5. Tests that must pass before you commit (commands in `CLAUDE.md` section 3)

`test_gestures` (461 checks), `test_pages`, `test_nav` and `test_stages` (`seeds=6`), `test_world` (seed 50 is a
known failure), `intro_check`, `flow_check`, `collapse_check`, `dark_check`, `spectate_check`, `pull_check`,
`spark_check`, `sentinel_check`, every `cross_check` kind, `gate_check` for each gate, and `arena_sim` (seeds 7 and
12, 300 s: 3 of 3 wizards standing). Add a new test that casts Push, Geyser, Burst, Tornado, Tide Surf and a
damage spell at a player-controlled wizard and at an AI wizard and asserts the same result.
