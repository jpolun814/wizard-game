# 19. The sky world (built 2026-11-11; the plan below, then "As built" at the end)

Agreed with the owner in conversation on 2026-11-11. **No code exists for this.** It would be a new biome (working name `sky`; the ocean of
chapter 20 is the other planned one, so these would be the eighth and ninth). Per `CLAUDE.md` section 6 the owner approves each new spell; this
plan adds none.

## The idea

The wizards are in free fall through the sky. There is **no ground, no jumping and no platforms.** Instead of gravity and a floor, a wizard
moves freely up, down, left and right. Clouds scroll past upward to give the feeling of falling. It is the one world that is not a platformer.

## Rules (all agreed)

- **Free movement.** A wizard steers in two dimensions: A and D sideways, W and S up and down (the jump key does nothing here). With no key
  pressed a wizard **drifts** slowly down; they do not hover.
- **No ground at all.** Nothing to stand on, nothing under the world. The match's portal appears and collapses the world as in every other
  world (chapter 11 and `MatchState`/`portal_collapse.gd`).
- **Bounded, but with no visible walls.** The world is large, but its sides, top and bottom are limits the wizards cannot pass, shown by no
  wall art. A wizard who reaches one simply stops (the same at the bottom as at the left and right).
- **Pages fall with the wizards, each at a rate of its own.** A page is in the world, not on the screen's scroll layer. Pages drift at similar
  but not identical rates, so they slowly spread. **A page can be lost:** one that drifts too fast or too slowly can leave the map for good, so
  the world is a race against the drift as well as against the other wizards. The world is large, so pages are sparser than in the other
  worlds.
- **Spells that "fall" still fall down the screen.** Stonefall, Pebble and the like keep a downward direction. Spells that need ground (Stone
  Wall, Stalagmite, Sinkhole, Bramble, Flaming Sphere and the like) have nothing to work on here. Updraft, Featherfall and Rocket Jump are
  redundant while a wizard can already steer freely. Which of these simply do nothing, and which a wizard cannot cast at all, is for the
  builder to decide with the owner (the Earth and Flora schools lose most of their toolkit on purpose; Air and Fire gain).

## Landmarks

- **Clouds scroll up the screen** to simulate falling through them. This is partly the backdrop (parallax, as the other biomes' sky layers are)
  and partly real clouds in the world, so a wizard really is passing through one.
- **Normal clouds** hide a wizard the way the ocean's kelp does (chapter 20): drawn in front of the wizards, in patches with gaps, so a person
  stays able to see their own wizard. The hiding is the drawing alone, with no code of its own. **The AI needs a rule of its own in its sight
  check** (a wizard in a cloud is not noticed beyond a short range), the same one the kelp needs; build the two together.
- **Thunderclouds** are grayer. A wizard inside one is shocked and takes damage, in occasional bolts and not a steady tick, and a cloud can also
  throw lightning outside itself, so staying clear of the edge is not always safe. It must be readable at a glance (the gray, and a bolt must
  show before it strikes, as the game's other strikes do), so a person can steer round it. Which wizard a bolt reaches should be settled by the
  seed and the world's age, so every machine of a match sees the same bolts (as the portal world does).

## Technical plan (a sketch for whoever builds it)

- A wizard body with no gravity and free steering, and a drift. The ocean world also needs steering (swimming), so look at one movement mode
  for both before building either: `Wizard` and `WizardBrain` are built around gravity and ground (chapter 2 and 9).
- The wizards' map (`WorldNav`, `WizardRoute`, `RoomScan`) assumes ground and routes between standing places. This world has none: the brain
  needs "fly to a point, avoiding thunderclouds" as a move, a page goal that is reachable from anywhere, and the same cloud sight rule.
- Shots that fall (`Pebble`) and anything that drops (`Stonefall`, `FallingRock`) already have a downward direction in the physics; check
  what they do with no ground.
- The minimap and edge arrows matter more here: wizards will be far apart in a large world with sparse pages.
- Add the biome everywhere `portals` was added (see chapter 20's list), and decide `OPEN_BIOMES` (the sky is all sky, so probably yes).
- Each of these needs a check in `tests/` and a line in `CLAUDE.md` section 3; see chapter 7.
- The art must be free, found online and credited in `art/CREDITS.md` (`CLAUDE.md` section 2, rule 3). Do not draw clouds.

## Still open

- **How much a thundercloud hurts**, how often a bolt comes, and how far outside the cloud one can strike.
- **How a page "leaves the map"** when it drifts too slowly as well as too fast. The wizards' own drift is downward, so a slower page would
  rise out of the top relative to them; the builder should confirm with the owner what the world's own movement is, so this reads right. (The owner confirmed on 2026-11-11 that this is the intended reading: a slower page rises out of the top relative to the wizards.)
- **Lost pages and the rules about them.** Other worlds guarantee a page that opens each gate (`Pages.with_openers`) and have a fixed count
  (`Pages.PER_WORLD`). Here a page can be lost, so decide how many to lay (more than the other worlds would, since some will be lost?) and what
  the AI does about a page drifting away (`WizardBrain`'s goal and its watchdog).
- The size of the world, and which spells to turn off or change here.

## As built (2026-11-11)

Check: `tests/sky_world_check.tscn`. The world is `sky` (`SurfaceGen.OPEN_BIOMES` and `BIOMES`; `LOOKS["sky"]` "The Open Sky").
- **The world** is a flat sheet of ground at row `SKY_FLOOR_ROW` (160) that nobody reaches; the air is `surface["air"]` rows 6 to 126 (3840 px). `World._flies()`
  is true when `graph.surface["air"]` is not empty, `World._fly_box()` is the room, and `ArenaGen.air_rows` makes the minimap show the air.
  `World._stand_at` puts each starting place in the air. No arrival portal drop. A fallen wizard's book hangs where it fell and stays.
- **Flying** is in `Wizard` (`flying`, `fly_box`, `_fly`): A/D and W/S steer (`FLY_SPEED`), nothing pressed drifts down at `FLY_DRIFT` (30 px/s); the edge of
  `fly_box` stops a wizard. The learned (trained) brain is not used here: `SkyBrain` (`scripts/sky_brain.gd`) is the scripted brain with its legs changed: it flies
  straight at a page it has seen, at a rival it hunts, or to look at somewhere new, round thunderclouds, and it still reads, defends and casts as the brain does.
- **Pages** are `FallingPage` (`PagePickup`'s child): position from `home + rate * world age`, so every machine agrees; `rate` is -140 to -70 px/s: every page rises, as a sheet of paper falls slower than a person, so among wizards who drift down it is left
  above them, and it swings from side to side (`SWAY`, 46 px) and tips as it goes, as paper does (owner, 2026-11-12: the pages seemed to fall with the wizards, then rose
  too slowly). One that rises out of the top comes back in at the bottom, `ROOM` (400 px) past each end of `box`, out of sight; no page is lost (owner, 2026-11-12). A wizard's first pages (the cluster) hang by their place and do not drift.
  Reading one needs the wizard within `FallingPage.TOUCH` (80 px).
- **Clouds** are `SkyCloud` (one plain cloud to every 450 px of width, at least 8, and a thundercloud to every 2000, at least 3; owner, 2026-11-12: more of them): plain ones rise past and hide (a `sight_blockers` member, so the brains see them as cover); thunderclouds warn with a flash
  and sparks, then shock whoever is inside and strike whoever is under the bolt; between bolts the inside stings each second (`CRACKLE`, 4; owner, 2026-11-12: sitting in one
  did nothing they could feel), but not in the second before a bolt, whose shock a sting would otherwise swallow (a wizard is spared hits for half a second after one). Everything is placed from the world's age (the `_timed` list), so no network traffic.
- **Spells** that need ground are refused with "No ground" (`SpellLimits`, which the brain also asks); Updraft, Featherfall and Rocket Jump say "No need".
- **Seeds:** the ocean and the sky are dealt in after the first world, never first (`MatchState.biome_of`), so every seed keeps its first world. The sky is also in the
  last world's draw (`OPEN_BIOMES`).
- **Not verified:** how it feels to fly (speed, drift, how fast pages leave), the thunderclouds' sound, the look of the backdrop for a fall (the sky picture does not
  scroll, so a person has only the clouds and pages to show motion).
