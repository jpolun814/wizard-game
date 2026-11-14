# Art and assets

## The look

**Dark gothic pixel art,** in the spirit of Castlevania, Blasphemous and Dead Cells.
- **Palette:** deep purples, blood reds, cold blues and murky greens, lit by fire and magic.
- **Style rules:** no cartoon outlines, no bright saturated "mobile game" colour, no vector shapes, no
  painterly HD art.
- **Shipped and approved by the owner:**
  - Biome: a blood-moon graveyard.
  - Biome: a haunted swamp with jack-o'-lantern trees.
  - Biome: a cathedral with skull pillars.
  - Characters: eight identical wizards (four figures; seats beyond the fourth wear other sets of colours), each with its own look (the purple-hooded player, the shadow-flame dark wizard, the pyre and bone wizards), plus skeletons, goblins and flying eyes.

## Pixel rules (hard)

- **1 art pixel = 1 world pixel.** The camera zoom is 1.5. Mixing densities looks broken.
- **Whole-number scales only,** and only on purpose:
  - 2x: Spark's lightning, the swamp and church backdrops (far scenery reads bigger), the Barrier bubble, the
    fire vent and the tornado funnel. Every wizard figure is drawn at one height (`WizardLook.SCALE`).
  - 2x: the purple portal.
  - 5x: the spellbook (UI).
- **Filtering:** "Nearest Mipmap" (project setting `default_texture_filter=2`). Pixel fonts need
  `FontFile.antialiasing = TextServer.FONT_ANTIALIASING_NONE`.
- **Movement and rotation:** round offsets for sprite bobbing (`roundf`). Rotating pixel art is acceptable for
  projectiles; avoid it for characters.
- **Non-uniform scale:** avoid it. Only the tornado's flattened whirlwind rings use it.

## Where the current art comes from (all CC0; see `art/CREDITS.md`)

| What | Pack | Where |
|---|---|---|
| Player wizard | LuizMelo, Wizard Pack | luizmelo.itch.io/wizard-pack |
| Dark wizard | LuizMelo, Evil Wizard 2 | luizmelo.itch.io/evil-wizard-2 |
| Pyre wizard, bone wizard | LuizMelo, Evil Wizard and Evil Wizard 3 | luizmelo.itch.io/evil-wizard, luizmelo.itch.io/evil-wizard-3 |
| Skeleton, goblin | LuizMelo, Monsters Creatures Fantasy (plus v1.2 and v1.3 attack add-ons in the same zip set) | luizmelo.itch.io/monsters-creatures-fantasy |
| Cemetery | ansimuz, GothicVania Cemetery | ansimuz.itch.io/gothicvania-cemetery |
| Swamp | ansimuz, GothicVania Swamp | opengameart.org/content/gotthicvania-swamp |
| Church, stone, the ice recolour | ansimuz, GothicVania Church | opengameart.org/content/gothicvania-church-pack |
| Wooden planks, crates | ansimuz, GothicVania Town | ansimuz.itch.io/gothicvania-town |
| Fireball, ice spear, thunder orb | StarsteelGaming, Spell Effects | opengameart.org/content/spell-effects-by-starsteelgaming |
| Bolts, orbs, rock, shield, wind bolt | DevWizard, Pixel Art Spells | opengameart.org/content/pixel-art-spells |
| Lightning strike | Remedyn, Lighting Strike | opengameart.org/content/lighting-strike |
| Explosions | ansimuz, Animated Explosions | opengameart.org/content/animated-explosions |
| Flames | BenHickling, Animated Fire | opengameart.org/content/animated-fire |
| Vortex, ring, slash, ice burst, freeze, wind, bubbles | CodeManu, Free Pixel Effects Pack | opengameart.org/content/free-pixel-effects-pack |
| Purple portal | Purple Portal Sprite Sheet (source to confirm) | art/fx/portal_purple |
| Rock spikes | Kamioo, Pixel Icicles | kamioo.itch.io/pixel-icicles |
| Clouds | DustDFG, Pixel Art Clouds | opengameart.org/node/159981 |
| Giant | ansimuz, Gothicvania Legacy Collection (Ogre) | ansimuz.itch.io/gothicvania-patreon-collection |
| Spellbook | Foxel Games, Pixel Art Book | foxeldev.itch.io/pixelbooks |
| Fonts | Jersey 15 and Jacquard 24 (OFL) | fonts.google.com, via github.com/google/fonts raw files |
| Soft glows, sparks, smoke under the pixel FX | Kenney, Particle Pack | kenney.nl/assets/particle-pack |

**Also worth checking for more:**
- More LuizMelo packs ("Hero Knight", "Fantasy Warrior", "Medieval King", "Martial Hero", "Huntress").
- More ansimuz GothicVania packs, plus "Caverns" (dark cave tiles).
- CodeManu's other free effect packs.
- OpenGameArt's CC0 tag.
- Kenney's "1-Bit Pack" and "Tiny Dungeon".

## Choosing an asset

1. **Licence:**
   - CC0 is best, and CC-BY is fine too (the owner approved it for everything, 2026-10-25). CC-BY needs a credit line in `art/CREDITS.md`.
   - We are not restricted to CC0 (owner, 2026-11-07): any asset free to use in the game will do, with a credit where its licence asks. Tell the owner first about share-alike, GPL, non-commercial or no-redistribution terms; do not buy packs.
   - On itch.io, read the page's "License" line; descriptions and metadata sometimes disagree.
2. **Style:** dark, gothic, pixel, at a density near the characters (roughly 50–90 px tall people).
3. **Content:** open it and look at every frame in a contact sheet before using it. Pitfalls already met:
   - downloads are not kept in the repo: re-download them into a scratch folder;
   - "fire-sprites" turned out to be an enemy wizard casting fire;
   - some sheets have an opaque teal or magenta background, which needs `key_out`;
   - some sheets are grids, not strips;
   - some attack frames have big white spell blasts baked in, so use only the clean frames.
4. **Fit:** recolour to the school's colour with `recolour(image, ("ramp", dark, light))` or `("hue", degrees)`.
   A hue turn keeps greys grey, which is useful for stone portals.

## The pipeline (`tools/prepare_gothic_art.py`)

- **Characters:**
  - `CHARACTERS` lists, per character: sheet folder, frame size, whether its frames are centred on the body (none now), and animation to file.
  - Frames are cut so the feet sit on the bottom edge and the body's lower half is centred, using
    `body_column`.
  - Body boxes for hitboxes come from columns that are mostly solid, so a held staff doesn't widen the hitbox.
  - The result is written to `scripts/fx/pixel_art.gd`.
- **Tiles:**
  - Each biome names the 16 px tiles that play each **role** (TL, T, TR, L, C, R, BL, B, BR, D).
  - Each 32 px atlas piece is composed from four of them (`LAYOUT`).
  - The atlas layout is 4x5 pieces of 64 px (a 32 px art piece at 2x), with 4 px extruded padding, read by
    `terrain.gd`.
- **Effects:**
  - `FX` (numbered frame files), `FX_SHEETS` (horizontal strips), `FX_GRIDS` (grids) and `FX_RECOLOURED`
    (grids plus a recolour) all become one horizontal strip per effect in `art/fx`.
  - Frame sizes go to `PixelArt.FX`, and `PixelFx.frames(name)` builds the animation.
- **Other outputs:** props, backgrounds, the church hall strip, the swamp woods strip, clouds, ice, quicksand,
  the spellbook.
- **Re-running it:**
  1. Download every pack into one scratch folder with the folder names its docstring lists. Use
     `tools/itch_download.py` for itch pages, and curl for OpenGameArt files (`/sites/default/files/...`).
  2. Run it.
  3. Run `godot --import`.
  4. Check screenshots.

## Drawing in code: allowed and not allowed

- **Not allowed in the world:** circles, polygons and lines used as pictures, such as ice blocks, clouds,
  portals, spikes or bolts.
- **Allowed:**
  - Interface elements: health bars, the gesture trail, drop shadows, another wizard's stroke as it is drawn.
  - Light (`Fx.draw_glow` soft textures).
  - Tiny pixel squares for snowflakes and shards.
  - Pixel-art textures drawn with `draw_texture*`, including filling a drawn polygon with a pixel texture, as
    Icicles do.
- **Every texture drawn in `_draw` must be a `preload` constant or held in a member variable** (white-rectangle
  bug).

## Backdrops (`backdrop.gd`)

- **Layer format:** `[file, scroll_scale, bottom_y, drift, extend_top_colour, zoom]`.
- **Scroll:** the vertical scroll scale must be 1.
- **Colour bands:** the bottom colour carries on downward. The top colour carries on upward only when
  `extend_top` is set. The swamp's trees have flat canopy bands that look bad stretched, so those layers draw
  at 2x instead.

## One look across worlds (cohesion pass)

The packs come from different artists, so three things tie them together:
- **The earth.** The packs' ground atlases are a thin lit band over black, which drew as bare navy with stripes. `tools/prepare_earth.py`
  now makes `art/tiles/earth_<tiles>.png` (stones with dark seams, lit from the top left) and `art/tiles/lip_<tiles>.png` (the grassy,
  mossy, ashen or frosted lip along each surface) for every tile set, each from a four-step ramp of its own. `Terrain` takes the earth of
  the world's first biome; the lip follows each biome's span. Change a ramp in the script, run it, then `godot --import`.
- **The grade.** `Grade` (`scripts/ui/grade.gd`, `grade.gdshader`) is a layer over every world and under the interface: shadows pulled toward
  one deep violet, colours drawn a little together, lights warmed a touch, corners darkened. Tune it there, not per biome.
- **Pixel size.** The earth and lip are drawn with 2x2 blocks, like the other tiles.

### Loose rock, vines and glow (second cohesion pass)

- `RockArt` (`scripts/terrain/rock_art.gd`) cuts boulders, stone walls, stalagmites, icicles and Ice Prison blocks from the world's own earth texture, brightened so they read over the ground. Nothing loose is a plain polygon with a texture on it.
- Vines use `art/props/dusk_vine.png` (made by `tools/prepare_vines.py`) so they share the Great Oak's colours; the Great Oak's trunk is walk-through, its ledges are solid.
- Air spells (Gust, Push, Updraft) all take `SpellData.SCHOOL_COLORS["Air"]`.
- Glowcap grows from the ground; a wizard who walks into it eats it (`GlowAura` gives the glow). The spellbook line must not say so.
- Test: `tests/checks/spell_fixes_check.tscn` (Sneak, veil, Geyser, Smoke Screen).

### Third cohesion pass (jungle, peaks, fire, sounds)

- **No sounds I made.** The owner asked that none of the game's sounds be purely my own. The ones I had synthesised were replaced by CC0 recordings (see art/CREDITS.md): `blood_cast`, `heartbeat`, `surf`, `glass`, `faint`, `jaw_snap`, `chomp`; the choice was made from file names, not by ear. Growth of plants uses `pickup` (a rustle). `spark`, `blink`, `push`, `fire_breath`, `ritual_ok`, `tornado`, `jump` and `quake` are still layered by `tools/make_sounds.py` from CC0 recordings with a little synthesis, which the owner said is fine.
- **Earth.** `tools/prepare_earth.py` makes every ground: stones with seams, but the jungle's is soil (`dirt()`), and the peaks' high rock is a pack of snow with drifts along the ridges (`earth_snow.png`, `lip_snow.png`). Loose rock (`RockArt`) samples the ground's own texels at the same scale, so a wall looks like what it grew from.
- **Grade.** `Grade.for_biome` gives each biome a cast on the shared grade: shadows pulled toward its colour, lights tinted a little.
- **Fire.** `Flames.lay` scatters flames over a burning plant, a patch of burning ground or a lava lake: uneven sizes, heights and leans, a glow, and embers. Never lay flames in a row or a grid.
- **Ice and snow.** `RockArt.ice_block` (Ice Prison, round wizards and mobs: the old `ice_fill` overlay is no longer drawn), `RockArt.ice_sheet` (the peaks' ice), `SnowDrift` (laid by `SnowCloud`; cosmetic and not solid). `art/props/ice_fill.png` is now unused; keep it until the owner says it can go.
- **Jungle.** Every tree has ledges and a vine (no small ones); the painted backdrop is hazed so the trees to climb stand out; fish face the way they swim; mud and thorns follow the drawn ground (`Terrain.surface_near`).

## Fonts (decided with the owner, 2026-11-04)

- **Olde Tome** (`fonts/OldeTome.ttf`, used through `Lettering.FACE` = `fonts/olde_tome.tres`, which falls back to Jersey 15 for the few letters it lacks): titles, spell and school names, headings, buttons made of words, banners, the plaque. It is a pixel font on a grid of 22 pixels to the em, so **use only sizes that suit it: 22, 44, 66, 88** (`Lettering.size_near` rounds to them; the home screen's choices use 33, a deliberate compromise to fit the page). **Its digits are blank**: never put a number in it (the stats screen draws "#3 of 4" in Jersey 15). Its K and H are easy to misread at small sizes ("Keep" looks like "Reep").
- **Jersey 15** (`fonts/Jersey15-Regular.ttf`): everything small or numeric: spell descriptions in the book, the controls list, tooltips, the stamina bar and edge arrows, the stats screen's numbers and chart text, damage numbers.
- Pirata One and Jacquard 24 are no longer used (still in `fonts/`).
