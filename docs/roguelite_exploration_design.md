# Roguelite exploration: design

Status: planning, with the spells built. Agreed in conversation with the owner on 2026-10-24. Built so far: the 33-spell pool
(`spell_pool.md`) and the waiting room where it is tried. The first world generator slice is built too (`world_generation.md`). Not built: the stamina window and gate tags, noticing
enemies. Pages, the world generator and seeds are built since (`pvp_arena_design.md`, `world_generation.md`).

The solo boss loop here has since been dropped for a last-wizard-standing race: see `pvp_arena_design.md`.

## The loop

The player enters a large, generated world with a nearly empty spellbook. They explore, find spellbook pages,
and get stronger. At the far end is the dark wizard, who has every spell the player was not given. Each run is
a fresh world and a fresh book. Nothing carries over between runs.

Story: the dark wizard blew up the spellbook and ran off with most of the pages in his haste. The player has
what he missed.

- **Length:** about 10 minutes now, about 30 later. There is no timer.
- **Death:** the run ends. The next run is a new world unless the player enters the same seed.

## Seeds

- Every world comes from a seed. The player types it as an incantation at the portal in the start world,
  like the existing typed rituals. Typing nothing gives a random seed.
- The incantation is a few Latin-sounding words that map to the seed one-to-one. The end-of-run screen shows it
  so players can share or replay a world.
- Everything the generator decides must come from the seed: layout, biomes, gates, page placement, the starter
  kit. Combat is not seeded.

## Spells and pages

- **Pool:** a master pool of spells (target 35 to 40 for the first version, up from 20). A run uses a few as the
  starter kit and places the rest as pages.
- **Every spell has its own intuitive shape.** The shape pictures what the spell does. A shape may repeat across
  schools only where it makes sense for that school (a tornado shape is never an Ice spell). Two spells on one
  button combination never share a shape. There is no "same shapes in every school" system.
- **Schools differ in when you'd use them.** Each school has its own strengths, not a reskin of another.
- **Every placed page is reachable.** The player can collect all of them. Pages come from different kinds of
  places: caves, towers, ruins, trials, libraries (pick one of three), shrines (pay for a page).
- **Starter kit:** a few basic spells covering one attack, one defence and one way to reposition.

## Stamina

Each spell has a cost **range**, not one number.

- **Accuracy** (the recognizer's score) and **speed** (stroke time against a per-spell par time) decide where in
  the range a cast lands. A clean, quick flick pays the minimum. A curved or slow one pays more.
- **Mastery within a run:** every N perfect casts of a spell lowers its whole window one step, down to that
  spell's absolute minimum. N is 5 for cheap spells and the step is larger for expensive ones (Earthquake would
  never get there with steps of 1). It resets on the next run.
- "Perfect" must be reachable but not trivial: for example accuracy above 0.95 and within about 120% of par time.
- Show it. A perfect cast flashes and the cost number is bright. A sloppy cast shows a dimmer, higher cost.
- Casts in the start world do not count towards mastery.

## Gates

Spells are rolled first. Then the generator picks gates.

- Each spell carries **capability tags**: cross a gap, break stone, burn growth, freeze water, reach height, and
  so on. A spell can have several tags and several spells share one.
- A gate needs a **tag**, not a spell. Thorns need "burn growth", which Ignite, Fire Breath and Firewall all have.
- The generator only uses tags the player is guaranteed to hold before that gate, and puts the solving page
  somewhere reachable earlier.
- A gate looks like what it needs, so players can work out the answer from the picture.
- Since every page is collectable, solvability is checked as an ordering: every page and gate must be
  reachable in some order.

## The world

- Generate a **graph first** (biomes, attractions, gates, pages), then build terrain to match.
- Much larger than today's arena, with biomes (each leaning to a school), caves, buildings, high places and low
  places. About 4 or 5 biomes and 8 to 10 pages for a 10 minute run.
- The art direction stays dark gothic CC0 pixel art.

## Enemies

- Placed on the map, not arriving in waves. They attack only once they notice the player.
- States: idle or patrolling, alert, chasing. Sight radius, plus a hearing radius.
- Candidate idea: spells have a noise level (lightning and Earthquake are loud, ice and Force are quiet), so a
  player chooses between sneaking and fighting.
- Needs a "!" over the head when an enemy notices.

## Not now

- Different casting focuses (a fire wand that boosts fire spells, a lightning staff that boosts storm). On hold.
- Longer runs (about 30 minutes): scale the same systems up later.

## Build order

1. Spell pool: add spells, with a shape, tags and a cost range each. **Done, except the tags and cost ranges.**
2. Stamina window: accuracy, speed and mastery.
3. Per-run spellbook: a small start kit plus collectable pages.
4. Enemies that notice the player.
5. The world generator, then the seed and incantation.

Items 2 and 3 work inside the current arena, so they can be tried straight away.

## Open questions

- Schools and buttons are decided: see `spell_pool.md`. Only Left+Right+Middle is still open.
- How noisy each spell is, if noise is used.
