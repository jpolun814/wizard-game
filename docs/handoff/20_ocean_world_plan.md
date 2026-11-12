# 20. The ocean world (built 2026-11-11; the plan below, then "As built" at the end)

Agreed with the owner in conversation on 2026-11-11. **No code exists for this.** It would be the eighth biome (`ocean`; the seven now are the
graveyard, peaks, jungle, ashlands, castle, underground and portal fields). Per `CLAUDE.md` section 6 the owner approves each new spell; this
plan adds none.

## The idea

A world where wizards must hold their breath. They cannot chant, breathe a Spore Puff or do anything else the game already forbids while a
breath is held. The owner chose the ocean over a space world with air pockets: it suits the dark gothic look (a graveyard of wrecked ships), it
needs no floating platforms (islands and the sea floor are ground), and the game already has breath, drowning, simulated water, piranhas and
the water-and-fire interactions. Space was set aside; low gravity could one day be a modifier on another world.

## Rules (all agreed)

- **Breath is the only pressure.** No damage from depth or from the sea floor. It drains underwater and refills at the surface, on islands and
  on driftwood (the existing drowning and held-breath rules).
- **Swimming:** tapping jump swims up; anywhere off the sea floor a wizard slowly sinks; on the floor they walk as usual.
- **Fire spells fizzle fully underwater.** Spark shocks the water. Ice, Lily Pads, Frost Bridge and Updraft are the crossing tools. Flare is a
  fire spell and fizzles like the rest.
- **A single open sea:** no halls, no tunnels (like the open biomes, but not in `OPEN_BIOMES`: it is not open sky).

## Landmarks

1. **Islands.** Fixed ground, few and dark, so the world does not read as a tropical paradise.
2. **Driftwood.** Wreckage floating at the waterline: a one-way platform (a wizard swims up through it and S drops them through). It never
   sinks and cannot burn (it is wet). It bobs for looks only; the walkable surface stays put, so landing and the AI's route plans are steady.
   Placed sparsely, small, in rings round wreck sites with open water between, so one cannot be camped on forever (ranged spells, Push and
   the like still reach a wizard on it).
3. **Wrecks and a sunken cathedral.** Anchored on the sea floor (the castle's gothic art): they hold pages and an air pocket.
4. **Kelp.** Pure scenery, no hiding code. Single strands are drawn in front of the wizards, in patches with gaps, so whoever stands among them
   is covered by the drawing alone (every machine of a network match sees the same, nothing to sync). The strands must leave gaps so a person
   can still see their own wizard. Kelp slows movement (a movement modifier in the patch, like the Mudslide). Only some patches lie near pages;
   the rest are decoration. Fire cannot clear it (it fizzles); Hex and Insight see through it; a Push or Thunderclap may flatten it.
   **The AI needs one rule of its own in its sight check:** a wizard inside kelp is not noticed beyond a short range (the picture does nothing for
   the AI, which reads positions). One that was seen going in can still be hunted.

Dropped by the owner: whirlpools and an abyss.

## Pages

Most lie on the sea floor and on deep ledges, a few on islands, so diving is worth the breath. `Pages.PER_WORLD` would need an `ocean` entry.

## Technical plan (a sketch for whoever builds it)

- The sea is a fixed volume that does not flow. `LiquidGrid` (chapter 12) is only for local effects (a Geyser, a pit dug beside the sea): a whole
  world of flowing cells would be far too heavy.
- Add the biome everywhere `portals` was added: `SurfaceGen.BIOMES` and `LOOKS`, `Pages.PER_WORLD`, `Grade.CASTS`, the Bonfire's log filters,
  `Library` screen's `WORLDS`, the F1 panel (`debug_panel.gd` reads `BIOMES`), `World._raise_biome_life`. `MatchState.biome_of` shuffles all the
  biomes but `portals`, so check what an eighth does to the seeds the tests use.
- The wizard needs the swim movement (jump taps, a slow sink, no sink on the floor) and the brain needs swim moves in `WizardRoute`/`WorldNav`,
  a "surface for air" goal, and never to start a chant underwater (`RoomScan` reads a room the same way a World does).
- Each of these needs a check in `tests/` and a line in `CLAUDE.md` section 3; see chapter 7.
- The art must be free, found online and credited in `art/CREDITS.md` (`CLAUDE.md` section 2, rule 3). Do not draw it.

## Still open

Whether driftwood is a few big pieces or many small ones, how much kelp, and the look (colour cast). Decide those with the owner when building.

## As built (2026-11-11)

Check: `tests/ocean_world_check.tscn`. The world is `ocean` ("The Drowned Sea"): a rolling floor 12 to 19 rows under the sea (`SurfaceGen._offsets`), very few
islands (`_sea_islands`: the middle one and one or two more, `ISLANDS_MOST`; owner, 2026-11-12: "primarily an underwater world, with *some* very sparse islands"),
and `surface["sea"]` ({row, depth, islands, wrecks, landmarks}). The wizards start on rafts of driftwood out at sea (`World.START_RAFT`, `World._stand_at`): their
spawn tiles stay on the sea floor below, which is what the wizards' map of the ways is built from.
- **The look** (2026-11-12): the night sky over the sea, and under it the darkened layers of ansimuz's Underwater Fantasy (`Backdrop.PLACES["ocean"]`, each layer's
  top at the surface), seen through the sea, which is see-through (`Pond.SEA_CLEAR_TOP`, `SEA_CLEAR_BOTTOM`); the floor is sand (owner, 2026-11-12: sand, not stone;
  `earth_seabed`, `lip_seabed`, the snow's drifts in a sand ramp). The view rests lower in the ocean (`World.SEA_VIEW`), so the floor and its wrecks are on
  screen from mid-water (at the old height they were off the bottom of the screen). A bonfire under water goes out in a puff of steam (`Bonfire.drowned`).
  Pictures from the player's own view: `tests/ocean_look.tscn -- out=DIR` (needs a window). The art is made by `tools/prepare_ocean_art.py` from the downloads (see `art/CREDITS.md`).
- **The sea** is a row of `Pond`s with `deep = true` (`World._lay_sea`, lengths of `SEA_LENGTH`, 1536 px, so only those in view are drawn: one pond over the whole
  world drew so slowly in a window that a run never finished). It is a fixed rectangle, not the flowing `LiquidGrid` (`ground` is null), so a Sinkhole dug beside it
  does not fill from it. Out of its depth (`Pond.SWIM_DEPTH`, 44 px under the surface) a wizard swims (`Wizard.swim`): the jump key strokes up, S dives, and it sinks slowly.
  The water slows everyone in it, as every pool does. Out of its depth a brain swims (`WizardBrain._swim`, 2026-11-12): straight for its goal (not along the
  map of ways, made for legs: following it, wizards bobbed at the top and drowned at the world's edge), a stroke at a person's pace, and up for air when its
  breath would only just last the way: straight up, or to open water to one side, or to an air pocket.
- **Breath** is the only pressure: nothing else is added. A `Wreck` has an `AirPocket` (150 by 110 px) where the sea does not reach, and a page lies in each wreck.
- **Driftwood** (`Driftwood`) is a one-way platform at the waterline; **kelp** (`KelpPatch`) slows and hides (a `sight_blockers` member); a wreck is CraftPix's sunken galleon (`art/props/shipwreck.png`), cut to the open water (`Wreck.clip`) so the floor hides its buried sand. It is a thing in the
  water (owner, 2026-11-12): the bow's hull is solid and its slanting side stood on (`Wreck.BOW`), the stern's deck is a one-way platform (`DECK`), its high back is
  solid (`STERN`), and the air pocket is in the hold under the deck (`HOLD`). The hulls go straight down into the floor: a wedge of water under an overhanging hull
  caught swimmers, who drowned. For the brain: an air pocket counts only when the way to it is clear (`_nearest_air`), a swimmer goes across under a hull before
  it strokes up (`_swim`), drops through a deck or driftwood to get under it, gives up a place inside a hull (`_inside_solid`), and does not explore a wreck's hold
  square by square (`Wreck.covers`). In sims (seed 23, world 1) the AI still spends more time round the wrecks than with flat ones, and reads its pages a little later.
- **Fire** fizzles under water; spells that need ground work on the sea floor (they are refused only in the sky).
- **Not verified:** how swimming feels, the balance of breath against the distance between air pockets, and the look of the rafts (plain planks of the town pack). Pictures of the surface,
  the open water and a wreck were looked at (`tests/arena_sim.tscn -- seed=5 stage=1 watch=1 follow=2 shot=FILE shotat=8`).
