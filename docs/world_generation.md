# World generation

A world is 360 by 170 tiles, made from a seed (four incantation words, or random when none is spoken).

## Layout
- **The surface** is the first hall and the start. It is open sky over rolling ground the width of the world, with a ruined castle on it. Under it lie the caves. Nothing on the surface is a trap: a trench across it would cut it in two, so the only ways down are two steep tunnels, one at each end of the world.
- **The castle** is stone you climb over: a stair up a tall tower, its roof, a stair down to a long wall, a stair up to a second tower, and a stair down the far side. Windows are cut into it. It is the only thing on the surface that blocks the way, and every part of it can be walked over.
- **The caves** are 9 to 12 halls (in practice 5 to 8) placed anywhere under the surface. Each has its own width, height and floor: rolling hills and valleys, now and then a mesa, a lake, a pool of lava with rock pillars standing in it, a dry pit, and ziggurats of rock to climb over. Nothing floats.
- **Tunnels** join halls. A gentle tunnel climbs a row in two columns, a steep one a row in one (45 degrees, the most a walker can climb). A hall has one tunnel on each side. Three extra loop tunnels are added between halls that sit near each other.
- The boss hall is the farthest by tunnels (at least 3). Every tunnel has an empty gate slot.
- There are no one-way platforms and no shafts: vertical travel is by slope.

## Code
- `scripts/world/world_graph.gd` places the halls and tunnels.
- `scripts/world/world_builder.gd` starts all rock and carves it, then adds the castle and formations. `reachable()` is a walk, step, fall and jump search (with lava) that every hall marker must pass.
- `scripts/terrain.gd` (tiled mode) traces the boundary between air and rock into closed outlines, spreads them evenly, rounds them off and thins them. That gives smooth hills and slopes like the waiting room. The rock is one textured layer, the caves are the outlines filled over it with a dark rim, grass is one mesh along every stretch facing up, the sky is gradient bands over the air above the surface, the castle is a brick layer with dark windows, and rock standing in the air (the lava pillars) is drawn in front of the pools.
- Collision is one concave outline per cave. A concave outline has no inside, so a body that gets into rock is not found by a physics query: `World` asks the tiles instead, stops teleports short of rock, and puts the wizard back on the last firm ground if they end up in rock or fall out of the world.

## Tests
- `tests/test_world.gd -- seeds=N pic=S out=DIR`: determinism, every hall reachable, boss depth, and a negative check (walls across the surface must cut halls off).
- `tests/showcase.tscn -- scenario=cave`: snapshots of the start, the castle, a lake and lava, and the steepest tunnel walked with only the walk key.
