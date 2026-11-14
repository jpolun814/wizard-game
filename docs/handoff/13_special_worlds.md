# 13. The special worlds: the portal fields, the ocean and the sky

Three of the nine biomes play differently from the rest. Each is one whole world of a match (`SurfaceGen.BIOMES`). The portal fields, the ocean and the sky are dealt
into a match after the seed has shuffled the other six (`MatchState.LATER_BIOMES`, `biome_of`), so every seed keeps the worlds it had before they were added. The
ocean and the sky are never a match's first world. The last, small world is one of `OPEN_BIOMES` (the portal fields and the sky are among them; the ocean is not, as it
has a sea over it, not open sky).

## The portal fields (`portals`, "The Portal Fields")

A gentle, bare world (graveyard tiles and backdrop, a violet tint) with normal pages and no hazards, where portals open every few seconds and carry a wizard to another.
`PortalField` (`scripts/arena/portal_field.gd`, raised in `WorldScenery.raise_biome_life`) works out which portals are open from the seed and the world's age alone (`_timed`), so every
machine of a match sees the same ones.

- Every `INTERVAL` (5 s) a wave opens: the first two or three portals, later ones none to eight, each in a stretch of the world the seed shuffles. Each stays `LIFETIME`
  (15 s). One that would open within `SPACING` of an older one is dropped.
- Some hang in the air (`lift`, up to `HIGHEST`); the first of every wave stands on the ground and others hang no higher than `JUMPABLE`, so one can always be reached.
- Colours (`PortalField.tint_of`): twenty-four hues dealt so that portals open together never share one.
- Stepping into one (`FieldPortal.entered`) puts the wizard out of another open portal, picked at random; `COOLDOWN` (1 s) stops a wizard going straight back in.
  A shot that flies into one comes out of another, flying the same way.
- The AI uses them (goal "portal") when there is no page to go for, or when one is nearer than the page. It goes only to ones on the ground.
- Checks: `tests/portal_world_check.tscn`, `tests/portal_colours_look.tscn -- out=DIR`.

## The ocean (`ocean`, "The Drowned Sea")

A sea over the whole world, mostly under water (owner, 2026-11-12: "primarily an underwater world, with *some* very sparse islands and driftwood. and shipwrecks too").
Breath is the only pressure: no damage from depth, and fire fizzles under water. Check: `tests/ocean_world_check.tscn`; pictures from the player's own view:
`tests/ocean_look.tscn -- out=DIR`.

- **The ground:** a rolling floor 12 to 19 rows under the sea (`SurfaceGen._offsets`), of sand (`earth_seabed`, `lip_seabed`), and very few islands (`_sea_islands`: the
  middle one and one or two more, `ISLANDS_MOST`). `surface["sea"]` holds {row, depth, islands, wrecks, landmarks}.
- **The start:** each wizard starts on a raft of driftwood out at sea (`WorldScenery.START_RAFT`, `stand_at`); its spawn tile stays on the sea floor below, which is what the
  map of the ways is built from.
- **The sea** is a row of `Pond`s with `deep = true` (`WorldScenery.lay_sea`, in lengths of `SEA_LENGTH` so only those in view are drawn), see-through so the scenery shows
  (`Pond.SEA_CLEAR_TOP`, `SEA_CLEAR_BOTTOM`). It is a fixed body of water, not the flowing `LiquidGrid`. Out of its depth (`Pond.SWIM_DEPTH`) a wizard swims
  (`Wizard.swim`): jump strokes up, S dives, and it sinks slowly. The view rests lower in the ocean (`World.SEA_VIEW`) so the floor is on screen from mid-water.
- **The look:** the night sky over the sea, and under it the darkened layers of ansimuz's Underwater Fantasy (`Backdrop.PLACES["ocean"]`, made by `tools/prepare_ocean_art.py`).
- **Wrecks** (`Wreck`) are CraftPix's sunken galleon in the driftwood's browns on a bank of sand, solid things in the water (owner, 2026-11-12): the bow's hull is
  solid and its slanting side can be stood on (`BOW`), the stern's deck is a one-way platform (`DECK`), its high back is solid (`STERN`), and an `AirPocket` sits in the
  hold under the deck (`HOLD`), where a wizard breathes. A page lies between the halves. The picture is cut to the open water (`clip`) so the floor hides its buried sand,
  and the hulls go straight down into the floor: a wedge of water under an overhanging hull trapped swimmers.
- **Driftwood** (`Driftwood`) is a one-way platform at the waterline; **kelp** (`KelpPatch`) slows and hides. A bonfire under water goes out (`Bonfire.drowned`).
- **The AI** swims straight for its goal (`BrainTravel.swim`), with a stroke at a person's pace, and goes up for air when its breath would only just last the way:
  straight up, to open water to one side, or to an air pocket it can reach in a straight line (`_nearest_air`). It goes across under a hull before it strokes up,
  drops through a deck or driftwood to get under it, gives up a place inside a hull (`_inside_solid`) and does not search a wreck's hold square by square (`Wreck.covers`).
  It still spends more time round the wrecks than elsewhere.
- **Not verified:** how swimming feels, and the balance of breath against the distance between air pockets.

## The sky (`sky`, "The Open Sky")

The wizards are falling through the sky: no ground, no jumping and no platforms. Check: `tests/sky_world_check.tscn` (add `-- out=DIR` for a picture of a bolt).

- **The world:** the air is rows `SKY_TOP_ROW` to `SKY_BOTTOM_ROW` (6 to 66), `MatchState.SKY_SHARE` (0.35) of a stage's width (owner, 2026-11-12: too large, twice).
  Far under it lies rock nobody reaches (`SKY_FLOOR_ROW`). `World.flies()` is true when `graph.surface["air"]` is not empty; `World._fly_box()` is the room.
- **Flying** (`Wizard.flying`, `fly_box`, `_fly`): A/D and W/S steer (`FLY_SPEED`); with nothing pressed a wizard drifts down (`FLY_DRIFT`); the edge of the room stops
  them, with no wall drawn. There is no running animation, only rising and falling poses, and streaks rush up past the camera (`Weather` "fall_wind").
- **Pages** (`FallingPage`) rise through the falling wizards, as paper falls slower than a person, swinging and tipping as they go (`RATE_LEAST` to `RATE_MOST`,
  `SWAY`, `ROCK`). One that rises out of the top comes back in at the bottom (`ROOM` past each end, out of sight): none is lost. Their place comes from the world's age
  alone, so every machine agrees. A wizard's first pages hang by their place and do not move.
- **Clouds** (`SkyCloud`, one to every 450 px of width, and a thundercloud to every 2000) rise past and hide whoever is in them. Thunderclouds sting whoever is inside
  each second (`CRACKLE`), and every few seconds flash, crackle where the bolt will fall, and strike: the bolt comes down out of the body of the cloud (`UNDER`), shocks
  whoever is inside and strikes whoever is under it. No sting falls in the second before a bolt, so the bolt's shock is not lost to the half-second grace after a hit.
- **Spells** that need ground are refused with "No ground" (`SpellLimits`, which the brain also asks); Updraft, Featherfall and Rocket Jump say "No need".
- **The AI** is `SkyBrain`: the scripted brain with its legs changed, flying straight at a page it has seen, a rival it hunts, or somewhere new, round thunderclouds.
- **Not verified:** how flying feels, and the thunder's sound.
