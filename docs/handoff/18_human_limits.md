# What an AI wizard may know and do: the limits of a person

**Read this before adding or changing anything in `scripts/brain/`.** The owner's rule (2026-11-07, 2026-11-09, restated 2026-11-14): the AI may play *better* than a
person, but only by better choices. It has a person's eyes, memory, hands, reaction and attention, and it knows nothing a person at that screen could not know.
It was forgotten once, in an idea list (2026-11-14); `tests/checks/knowledge_check.gd` now fails on the commonest breaches, and this chapter is the full list.

**Amended 2026-11-15 (owner): the numbers may stretch, the abilities may not.** The recorded people (`data/ai/human_limits.json`) are a sample, not a ceiling: no expert has had
the practice yet. So the top two levels (`BrainLevel`: `slow` and `clumsy` below 1, a longer `memory`) may react, draw and type quicker, aim truer and remember longer than the best
people recorded, as long as a person plausibly could (a reaction of about 0.18 s, typing near 200 words a minute). What never stretches is what it may *know* or *do* (everything
numbered below that is about knowledge or action: its screen only, no counting, no two spells at once, no moving while chanting, no peeking, no made-up mistakes). Read the
numbers below as the usual person, not the limit, for levels 8 and 9.

## What it can know (the eyes and the memory)
1. **Its screen only**: a 1280 x 720 window at zoom 1.5, about 427 px either side and 240 px up and down of the view (`Eyes`). Nothing off the screen.
2. **Nothing through smoke, an eclipse, the dark** (unless a light falls on it) **or a Sneak**. A faded wizard is not seen.
3. **A shadow (Decoy) or a Mirage looks real** until it has been seen to appear or to fade; then it is known for what it is.
4. **Where a rival was last seen**, and only for about 8 seconds (`BrainSight.REMEMBER`); then it is forgotten.
5. **Pages it has seen**, not all the pages; and **only the ground it has walked or seen** (`BrainExplore`): it explores unexplored squares like a person.
6. **A rival's spells only from casts it saw** (`BrainProfile`: a cast is noted only if the caster was in view when it happened) and only for a minute.
7. **No rival's book, strength or health.** No bar hangs over a rival: it cannot read their stamina, maximum, pages, curses it did not see or their skill. What it may do is
   *guess* from what it saw: what they cast (and so spent), the blows it watched land on them, whether they stand still with words over their head (a chant).
8. **It does not know how many wizards are left**, who is a person and who is an AI, which seat or seed anyone has, or what the match's clock is. It sees the
   banner and the shaking of a collapse as a person does, and nothing sooner.
9. **It does not know a world's layout beyond its screen**: no map unless it has chanted the Rite of the Land, no minimap of the others.
10. **Sound** is only what a person at that screen would hear; do not use a sound as a pointer to something the eyes could not see.

## What it can do (the hands and the body)
11. **One hand on the mouse**: one stroke at a time, so *no two spells at once*. A stroke takes a person's time (`data/ai/human_limits.json`, `BrainStrokes`): the quickest
    it draws a spell is the fastest 25% of recorded people.
12. **No typing while doing anything else**: a chant is typed standing on the ground, not moving, not drawing, not hit, not in water, at about 30 words a minute; any blow
    breaks it (`BrainChant`, `WizardBrain._typing_disturbed`). No chant while a stroke is being drawn.
13. **Moving while drawing drags the stroke**: the screen follows the wizard, so a stroke drawn on the move comes out bent (`Wizard.start_drawing`); a careful person stands
    still for the strokes that need it. A shaky hand in an earthquake, an eruption or an avalanche (`BrainHand.shaken`).
14. **Reading a page takes about a second** before its spell is drawn (`READ_MIN`, `READ_MAX`).
15. **Reaction time**: a person answers a shot after 0.25 to 0.65 seconds, not at once (`_reaction_time`).
16. **Attention**: it watches the rival it is fighting closely; a shot from elsewhere is taken in a moment late (`BrainSight.ATTENTION_LAG`). It deals with *one rival at a time*.
17. **The same body**: the same stamina, regeneration (only still, after a pause), wounds that heal only at a bonfire, the same costs, silences, freezes, daze and rules of every
    spell. No cheat on cost, cooldown or range.
18. **No made-up mistakes**: no random misclicks or mistyped chants added to look human (owner decision 2026-11-09). Its aim is as true as its skill; its stroke is a real stroke.
19. **No peeking at the world's data**: it asks the ground by ray what a person sees (a ceiling over a few steps, a drop ahead), not the world's tables, nav grids it has not explored,
    or another wizard's private variables.

## How the rules are kept
- `Eyes`, `BrainSight` and `BrainProfile` are the only doors to another wizard: a rival is read through them.
- `tests/checks/knowledge_check.gd` (in the quick set) fails when a brain script reads a rival's stamina, book or kind, lists all wizards, or reads the match's clock. Lines it
  already knew of are listed in its `KNOWN` (the Hunter's Mark and Scrying Eye gates, `BrainSight.look_about`'s watching of every wizard to test eyes): **fix those, never add to the list.**
- `tests/checks/limits_check` holds the stroke and chant limits. Any new idea is read against this list before it is built. Ideas that failed it: counting who is
  left alive (pace by number alive; the last-two endgame); treating a rival as person or AI; random mistakes at low skill; sound cues from off the screen.
