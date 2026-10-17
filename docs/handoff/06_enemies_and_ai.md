# Enemies and the dark wizard

## Enemy kinds (`Mob.KINDS`)

- **Naming:** `<school>_<role>`, plus `basic` and `dark_wizard`.
- **Roles and art:**
  - **melee:** skeleton. Walks to you, winds up for 0.3 s (leans, flashes in its school colour, plays its attack
    animation), then hits. If you moved away during the wind-up, it misses.
  - **ranged:** goblin. Stops in range, charges a glowing orb for 0.45 s, then throws.
  - **flyer:** flying eye. Patrols above, hovers and shakes for 0.4 s (the warning), dives, then retreats.
  - **wizard:** the dark wizard (below).
- **School:** sets the outline and tint colour, `weak` (double damage) and `resist` (none), plus a trick:
  - fire melee leaves a fire trail;
  - ice melee leaves snow;
  - earth melee knocks you back;
  - storm melee is fast and explodes;
  - fire ranged calls a fireball down onto a marked spot;
  - ice ranged slows;
  - earth ranged lobs rocks;
  - storm ranged fires a fan;
  - flyers drop their element on you.

## Design rules for enemies

1. **Same role, same creature.** School is shown only by colour (outline plus slight tint). The owner rejected
   the differently-drawn earth melee enemy.
2. **Every attack is telegraphed** and dodgeable. Add a warning to anything new.
3. **Enemies should attack your inputs, not just your HP** (from the original vision): mute blocks rituals, root
   stops movement, blind hides the gesture trail. This is still the direction for new enemies. Ideas:
   - a "tremor" that tightens gesture tolerance;
   - a mimic that casts your last spell back;
   - a summoner whose ritual you can interrupt.
4. **Hitboxes match the body,** not the weapon. `PixelArt.CHARACTERS[...]["body"]` is measured from the art.
5. **Spawning:** enemies arrive through a summoning fade and can't act or be hurt until it finishes.

## The dark wizard (`wizard_brain.gd`)

It's the owner's favourite part. It plays like a skilled human:

- **Casting** goes through the real recognizer. `_begin_cast(spell, stroke, draw_time)` draws the stroke in
  front of it over `draw_time`, then calls `caster.cast_stroke`. A hit of 6 or more damage while it draws
  interrupts the spell, and it says "Interrupted!".
- **Reactions:**
  - It watches your projectiles and, after a reaction time (shorter the more skilled it is), picks one of:
    jump, Force Wall reflect, Barrier, or blink aside.
  - When you're too close it pushes you, blinks away, or uses Fire Breath.
  - It steps out of danger, using every spell's `danger_at`.
- **Footwork:** keeps dueling range (190–330 px), strafes, never backs into walls or hazards, and jumps to get a
  line of sight.
- **Attacks:**
  - Each spell gets a score from the situation: are you still, rooted, behind cover, sheltered under a platform,
    close or far?
  - It avoids its last two spells and leads moving targets with `_predict`.
  - Strokes come from `GestureTemplates.preview_points`, placed in the world.
- **Skill** grows with the level (0.5 + 0.15 per level). Level 3 has two dark wizards at once.
- **Art:** LuizMelo Evil Wizard 2 at 2x. It channels shadow while drawing and bursts when a spell fires.

**When you add a spell,** teach the wizard to use it, and make sure it doesn't cast spells that can't work:
- no Spark or Storm Cloud while you're sheltered;
- no line-of-sight spells when it can't see you.

## Wave and level structure (`levels.gd`)

- Each level introduces the schools one at a time, then mixes them, then ends with the dark wizard.
- Each wave is a fresh random map, and a portal appears when the wave is cleared.
- Dying resets the run; R or a click starts a new one.

## Improvement ideas the owner may like

- A wizard personality per level: level 1 leans on fire, level 2 on ice and earth, level 3 on everything.
- Mini-bosses using the 2x scale trick.
- An enemy that steals or knocks away your focus.
- A healer enemy that must be killed first.
- An elite skeleton with a shield that blocks frontal projectiles. The skeleton art has a "Shield"
  animation that's unused.
