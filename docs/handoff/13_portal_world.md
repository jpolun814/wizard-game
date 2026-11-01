# 13. The portal world

A seventh biome, `portals` ("The Portal Fields"), dealt into every match's order like the others: `MatchState.biome_of` shuffles the other six and then deals this one in at any place, so any world of a match can be it (and the last, small one). Dealing it in after the shuffle keeps the worlds the fixed seeds of the tests had.
Its ground is gentle and bare (graveyard tiles and backdrop, a violet tint, fog), with normal pages and no hazards.

`PortalField` (`scripts/portal_field.gd`, raised in `World._raise_biome_life`) opens the portals. It is told the world's age each frame
(`_timed`) and works out which portals should be open from the seed and the age alone, so every machine of a match sees the same ones.

- Every `INTERVAL` (5 s) a wave opens. The first wave is two or three portals; every later wave is none to eight. A wave's portals each get a stretch of the world, in an order the seed shuffles, so they open from one end of the world to the other and not only in the middle.
- A shot (`"shots"` group: a fireball, an ice spear, an enemy bolt, a lava ball) that flies into a portal comes out of another, flying the same way (`PortalField._physics_process`).
- Some portals hang in the air (`lift`, up to `HIGHEST`); the first of every wave stands on the ground and some of the rest hang no higher than `JUMPABLE`, so one can always be reached by walking or jumping. The AI only goes to ones on the ground. Each ring has a dark copy under it, so that it is solid and not see-through.
- A portal stays `LIFETIME` (15 s, three intervals), closing with the sheet's closing frames (it opens with the same frames run backwards).
- Later portals that would open within `SPACING` of an older one are dropped. The first wave gets a stretch of the world each.
- Colours (`PortalField.tint_of`): twenty-four hues dealt in a scattered order, so portals open together never share one
  (checked in `tests/portal_world_check`). `FieldPortal.ring_colour` evens the colour out over the violet ring picture.
- Stepping into one (`FieldPortal.entered`) puts the wizard out of another open portal, picked at random on that machine. With only one
  open it does nothing. `COOLDOWN` (1 s) stops a wizard going straight back in. Remote-driven wizards are skipped, as with `Gateway`.
- The AI wizards use them (`WizardBrain`, goal "portal"): when there is no page to go for, or sometimes when a portal is nearer than the page.
- No sound plays and there is no fog.

Checks: `tests/portal_world_check.tscn` (add `-- out=DIR` for a picture, needs a window), `tests/portal_colours_look.tscn -- out=DIR`.
