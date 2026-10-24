# Gestures and spell design

## How a stroke becomes a spell

1. **Recording:** the player holds one or more mouse buttons. Every button pressed during the stroke is added to
   `_active_mask`, so Left then Middle counts as Earth. Points are recorded relative to where the press began.
2. **On release** (`Caster._end`):
   - **Too short:** a stroke shorter than `min_stroke_length` (20 px) is ignored.
   - **Recognizer:** the $1 recognizer scores the stroke against **only the templates bound to that button
     combination** (`_templates_for`). This restriction is why a Volcano can't come out as a Tornado.
   - **Shape detectors** then run for shapes $1 handles badly: `_inward_spiral`, `_ring_then_line_split` (Push),
     `_box`, `_snowfall_line`, `_funnel_stroke`, `_cloud_line` (also Frost Bridge's wave), `_pit_stroke`, `_cone`,
     `_icicle_triangles`, `_rising_wave` (Smoke Screen), `_stem_and_arc` (a stroke that sets off upward and curls: Liana,
     Geyser, Spore Puff and Great Oak, told apart by proportions in `_stem_gesture`), `_big_wave` (Tsunami), `_coil`
     (Tornado), `_sawtooth` (Bramble), `_w_shape` (Flytrap) and `_loop_row` (Lily Pads). Flare, Decoy, Eclipse and Hex are
     $1 templates (a flame, a figure of eight, a crescent, a pentagram, a geyser peak). A detector match sets score 1.0 and fills `info`.
   - **Straight strokes:** a flick that is near-vertical becomes `wall` (Firewall). A flick starting on solid
     ground with Earth held becomes `stone_wall`.
   - **Thresholds:** a score below `tolerance` (the focus: wand 0.70, staff 0.90) is a misfire, which costs
     stamina and plays a fizzle. A recognized shape with no spell on those buttons is also a misfire.
3. **`cast_resolved`** goes to the arena, which deducts the cost (`SpellData.cost_for`, scaled by drawn size)
   and spawns the effect.

## Rules for a good gesture

1. **It pictures the effect.** It's the silhouette of the thing (mountain, cloud, cone, pit, box, crack) or its
   motion (an inward spiral pulls in, a zigzag down is lightning).
2. **The drawing places it.** Where and how big you draw is where and how big it happens, wherever that makes
   sense: Snowfall along its line, Ice Prison in its box, Push's circle as the area, Storm Cloud along its
   bumps. Size should cost stamina (`cost_for`).
3. **Distinct within its button combination.** Two spells on the same buttons must not be confusable when drawn
   sloppily. Spells on different buttons may share a shape: Ignite, Frostbolt and Blink are all flicks, which
   is good, because muscle memory carries across schools.
4. **Drawable by a mouse in about half a second.** One stroke only, never more than about 3 turns.
   Direction-independent where possible (mirrored and either way round).
5. **Readable from the dark wizard's drawing.** The player learns shapes by watching the wizard draw them.
6. **Shown in the spellbook.** `preview_points` must produce a stroke that the caster itself recognizes, which
   the test enforces.

## Adding a gesture, step by step

1. **Spell entry:** add the spell to `SpellData.SPELLS` (buttons, gesture name, targeting, cost, school,
   draw, effect) and a short `DAMAGE` line.
2. **Template or detector:**
   - **$1 template** (for an outline-like shape): add to `recognizer_templates()`, plus an alias if several
     templates mean one gesture.
   - **Detector** (for a structural shape): write `_my_shape(points) -> Dictionary` in `caster.gd`. Call it only
     when `options.has("my_shape")`, and fill `info`.
   - Robust detectors measure structure, not exact geometry. Count turns, check straightness with
     `_max_deviation`, compare arm lengths, check whether the stroke closes (start near end), and use total
     turning angle measured over spans of a few pixels (2 px steps are noisy).
3. **Preview:** add `preview_points("my_shape")`, plus `preview_ground` if it must start on the ground.
4. **Routing:** route it in `arena.spawn_spell` or `_place_shapes`.
5. **Tests:** add the gesture to the mirrored list in `tests/test_gestures.gd` if direction shouldn't matter,
   plus any special checks. The rotated-cone checks are an example.
6. **Dark wizard:** a score in `WizardBrain._attack` and a stroke in `_attack_stroke`, using preview points
   placed and scaled in the world.
7. **Run** `tests/test_gestures.gd`. Every check must pass.

## Testing pitfalls already found

- **Shaky strokes:** shaky tests use slow sinusoidal wobble plus pixel noise. Thresholds tuned on perfect strokes
  fail on real hands.
- **Preview too small:** a preview drawn too small (a short Push tail, a shallow crack zig) fails at 0.7x size.
  Make previews bold.
- **Template collisions:** a $1 template from another school can steal a match if templates aren't restricted
  to the held buttons. That is why they are restricted.
- **Partial detection:** the caster's templates load in `_ready`, so tests must run in `_process` (first frame),
  not `_initialize`.

---

# Designing spells the owner will like

## The test every spell must pass

| Question | Bad answer | Good answer |
|---|---|---|
| What real thing is it? | "a magic ring of fire" | "a flamethrower", "a boulder dropped from above" |
| How is it countered? | "it can't be" | "get behind a wall", "jump", "Barrier", "watch the warning" |
| What does its gesture picture? | "a circle, because" | "the funnel of a tornado, wide at the top" |
| Does physics apply? | goes through platforms, ignores walls | stopped by ground, stone, ice and platforms like the real thing |
| Who does it hurt? | only foes, magically | anything it physically touches, the caster included (except the caster's own projectile right as it leaves) |
| Does it fit its school? | Earth spell made of light | Earth is stone, sand, ground and weight |

## School identities

Six schools, each cast with its own mouse buttons (see `SpellData.SCHOOL_BUTTONS`). A shape may repeat in two schools only
where it makes sense for both, and two spells on one button combination never share a shape.

- **Fire** (Left, orange `#ff6a2a`): burning, heat, lightning from the sky, light and smoke. Spark is Fire but stays
  lightning-yellow (`SpellData.SPELL_COLORS`).
- **Water** (Right, cyan `#7fd8ff`): slowing, freezing, solid ice you can stand on, dousing, floods. Control rather than
  burst damage. Ice is part of Water.
- **Air** (Middle, pale silver `#d8e4ee`): pushing, deflecting, shields, wind. Little or no damage. Push is the only spell that
  lifts the wizard.
- **Earth** (Left + Right, brown `#b8864a`): stone, ground, sand, weight. Slow, heavy, terrain-shaping.
- **Flora** (Left + Middle, green `#6fcf6a`): plants. They grow, hold and trap, and every one of them burns. Not called
  Nature, so lightning is not confusingly "not nature".
- **Shadow** (Right + Middle, purple `#7a5aa0`): sight, decoys, curses and gravity. The dark wizard has no school of his own:
  he casts from the same pool as the player.

## Interactions worth building (owner-approved direction: physical consistency)

- **Fire and ice:** Fire melts icicles and Blizzard snow; Frost puts out fire patches.
- **Storm and stone:** lightning hits a Stone Wall instead of whoever is behind it.
- **Push and hazards:** pushing an enemy into Mudslide or fire makes those hazards a combo.
- **Wind and fire:** Tornado carries fire patches, becoming a fire whirl.
- **Force and ice:** a frozen enemy shatters with Force or Earth. This already exists; keep the pattern.

## The spell pool

Every spell, its shape, its counter and its gate tags are in `docs/spell_pool.md`. The plan they are part of (random pages
in a generated world, a boss who holds the spells you did not find) is in `docs/roguelite_exploration_design.md`. Design
each new spell with the checklist in `HANDOFF.md` §6, and expect the owner to veto physics they find unfair.

## Rituals (typed)

- **Existing:** Second Wind (heal), Land (minimap), Insight (enemy info), Bonfire (a healing fire), Boundless
  (endless stamina).
- **Chants are Latin-ish and grammatical-sounding.** Longer chants are for stronger effects.
- **Accuracy sets power.** Stopping partway does nothing; garbling backfires.
- **Text:** the spellbook shows each ritual's name, chant and one short line. Never repeat "costs no stamina".
- **Unbuilt ideas from the original vision:** Words of Unmaking (clear hazards), Scrying (preview the next
  wave), Ward of True Sight (cure blind), Summoning of the Bound Servant.
