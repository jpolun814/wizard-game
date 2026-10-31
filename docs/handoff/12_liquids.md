# 12. Liquids (the flowing water and lava)

The owner disliked liquids that only imitated water ("there's no physics behind them"). Pools are now simulated on a grid, the way
a tile game such as Terraria does it. The owner asked for it on 2026-10-31, after a Sinkhole dug beside a pond left the water standing in its
old rectangle.

## The parts

- `scripts/liquid_grid.gd` (`LiquidGrid`): cells of `CELL` = 16 px, each holding an amount of liquid from 0 to 1. Each step a cell gives to the cell
  below, then to either side, then pushes up when it holds more than its share (so connected vessels level out). It conserves liquid exactly.
  Only cells with liquid in them are worked on, and the grid goes to sleep when nothing moves (`asleep`; `wake()` starts it again).
- `scripts/pond.gd` (`Pond`): still the node everything finds by the `"ponds"` group, with the same `width`, `depth`, `lava`, `freeze_span` and
  `danger_at`. Its liquid is a `LiquidGrid` over `region()`: the pool plus `SIDE` px to each side and `BELOW` below, room for liquid to run into a
  pit. Ask `wet_at(point)`, `surface_at(x)` and `holds(body)` rather than using the pool's rectangle, which only says where the pool began.
- `Terrain.solid_at(point)`: what the liquid takes for ground. Tiled worlds use the tiles when no outline is near and the smoothed outlines
  (`RockWorld.solid_at`) beside an edge; the waiting room uses its height line. `Terrain` sends `about_to_change` and `changed` when a pit is dug,
  and a pool makes its grid at once on the first, then reads the new ground and wakes on the second.

## It is not held to a rectangle

A pool starts with `SIDE` and `BELOW` of room round it. Whenever liquid is against an edge of its grid, `Pond._make_room` adds `GROW` cells there
(`LiquidGrid.grow`), reads the ground in the new strip, and the grid carries on. It stops at `MOST_COLS` x `MOST_ROWS` cells, so liquid spreading over
a whole plain ends somewhere, and a film thinner than `EDGE_WET` does not ask for room. The area that finds bodies near the liquid and the on-screen
rectangle both follow the grid.

## Rules to keep it quick

- A grid is made only when the pool first comes into view, and a few rows a frame (`Pond.begin_grid`). `ensure_grid()` makes it at once and is
  for tests and for a dig. Nothing is simulated for a pool nobody has seen.
- Water is stepped twice at 30 Hz, lava once at 10 Hz, at most once a frame whatever the frame took. A settled pool costs nothing but its drawing,
  which reuses the columns it worked out until the liquid changes.
- Measured on a 1444 cell pool: about 0.4 ms a step, 1 ms at worst; a pool settles in under a few seconds, long ones in tens (liquid spreads one
  cell a step).
- The drawing runs `RIM_OVERLAP` under the ground beside it so no gap shows between square cells and the smooth rock.

## What follows the liquid

- `Piranhas` (a jungle pond's shoal has `pond` set) swim in the unbroken stretch of water that is deep enough, work it out again every 0.4 s, are
  bitten-range wherever `Pond.wet_at` says, and are stranded (the shoal is freed) after `STRANDED` seconds with no deep water. Shoals of the
  spell gates have no `pond` and keep their rectangle.
- Ice (`Pond.freeze_span`) lies on the surface as it is now (`slab["y"]`), as far as the surface stays level.
- Frost Bridge asks `Pond.surface_at` for how high to look, and Lily Pads settle on the water below or near the line (`Pond.surface_near`).
- The wizards' map of the ways (`World._on_ground_dug`, `_build_nav`): a pit takes the tiles it has emptied out of the map (`_dug_tiles`), and the
  map is made again 0.4 s later (it takes about 90 ms, so a burst of pits makes it once). Water itself is not in the map.
- Pits that would leave less than `RockWorld.THIN_WALL` of rock between them are made one pit, and a pit is joined to the outline as a shape
  (`merge_polygons`), so a pit beside another opens into it.

## Water that spells make

Water from a spell is real liquid, and is not made from nothing more than once:
- `LiquidGrid.add` and `take`, `Pond.pour`, `Pond.draw_off`, `Pond.water_near` and `Pond.spill` (which joins the pool at a point, or makes a `loose`
  puddle that starts empty and runs over the ground).
- Geyser lifts `LIFT` of the water at its foot at each burst and lets it fall back as the column sinks. On dry ground the first burst brings up
  `SPRING` from below, once; after that it only moves that water about.
- Tide Surf takes up the water at the caster's feet (up to `WATER`, made up from below) and spills it where the ride ends.

## What is not done

- Pools nobody has seen are still the old rectangle for everything that asks `Pond` directly.
- Liquids do not mix: lava and water in one grid do not meet.
- Water the spells make is simulated on each machine on its own; a network game does not send liquid, so two machines can differ in small ways.
- Only the spells that use water do anything with it (Geyser, Tide Surf, Frost Bridge, Lily Pads). The owner said Blizzard and the ice spells are not water spells in this sense.

## Tests

```
"$GODOT" --headless --fixed-fps 60 --path . tests/follow_check.tscn -- seed=0   # piranhas, ice and a geyser follow the pool (seed 0 is a jungle with piranhas)
"$GODOT" --headless --fixed-fps 60 --path . tests/geyser_check.tscn              # a geyser's and a surf's water is real and not made over and over
"$GODOT" --headless --fixed-fps 60 --path . tests/sinkhole_check.tscn            # also: the map of the ways has the pit, and pits beside each other leave no thin wall
```

```
"$GODOT" --headless -s tests/test_liquid.gd                                  # the grid alone: falls, levels, joins vessels, fills a pit, keeps its liquid, how fast
"$GODOT" --headless --fixed-fps 60 --path . tests/liquid_world_check.tscn -- seed=3   # every pool of a world is made and keeps its liquid; a pit dug beside one fills (seeds 3, 5, 7, 12 have pools)
"$GODOT" --fixed-fps 60 --path . tests/liquid_look.tscn -- out=DIR           # the waiting room's pond before and after a pit, as pictures (needs a window)
```
