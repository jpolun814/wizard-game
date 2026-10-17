# Art and assets

## The look

**Dark gothic pixel art,** in the spirit of Castlevania, Blasphemous and Dead Cells.
- **Palette:** deep purples, blood reds, cold blues and murky greens, lit by fire and magic.
- **Style rules:** no cartoon outlines, no bright saturated "mobile game" colour, no vector shapes, no
  painterly HD art.
- **Shipped and approved by the owner:**
  - Level 1: a blood-moon cemetery.
  - Level 2: a haunted swamp with jack-o'-lantern trees.
  - Level 3: a cathedral with skull pillars.
  - Characters: a purple-hooded wizard, a looming shadow-flame dark wizard, skeletons, goblins and flying eyes.

## Pixel rules (hard)

- **1 art pixel = 1 world pixel.** The camera zoom is 1.5. Mixing densities looks broken.
- **Whole-number scales only,** and only on purpose:
  - 2x: the dark wizard (a looming boss), Spark's lightning, the swamp and church backdrops (far scenery reads
    bigger), the Barrier bubble, and the fire vent.
  - 3x: the portal arch.
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
| Skeleton, goblin, flying eye | LuizMelo, Monsters Creatures Fantasy (plus v1.2 and v1.3 attack add-ons in the same zip set) | luizmelo.itch.io/monsters-creatures-fantasy |
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
| Portal | LetargicDev, Portals | opengameart.org/content/portals |
| Rock spikes | Kamioo, Pixel Icicles | kamioo.itch.io/pixel-icicles |
| Clouds | DustDFG, Pixel Art Clouds | opengameart.org/node/159981 |
| Wand and staff pickups | Kenney, Tiny Dungeon | kenney.nl/assets/tiny-dungeon |
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
   - CC0 is best.
   - CC-BY means you need the owner's okay and a credit.
   - Skip CC-BY-SA, GPL, "personal use only" and paid packs unless told otherwise.
   - On itch.io, read the page's "License" line; descriptions and metadata sometimes disagree.
2. **Style:** dark, gothic, pixel, at a density near the characters (roughly 50–90 px tall people).
3. **Content:** open it and look at every frame in a contact sheet before using it. Pitfalls already met:
   - "fire-sprites" turned out to be an enemy wizard casting fire;
   - some sheets have an opaque teal or magenta background, which needs `key_out`;
   - some sheets are grids, not strips;
   - some attack frames have big white spell blasts baked in, so use only the clean frames.
4. **Fit:** recolour to the school's colour with `recolour(image, ("ramp", dark, light))` or `("hue", degrees)`.
   A hue turn keeps greys grey, which is useful for stone portals.

## The pipeline (`tools/prepare_gothic_art.py`)

- **Characters:**
  - `CHARACTERS` lists, per character: sheet folder, frame size, flyer flag, and animation to file.
  - Frames are cut so the feet sit on the bottom edge and the body's lower half is centred, using
    `body_column`.
  - Body boxes for hitboxes come from columns that are mostly solid, so a held staff doesn't widen the hitbox.
  - The result is written to `scripts/pixel_art.gd`.
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
  `wand`/`staff`, the spellbook, and `wizard_wand` (the staff cut down to a wand; see `wandify`).
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
  - Interface elements: health bars, the gesture trail, drop shadows, the dark wizard's in-progress stroke.
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
- **Screenshots:** check every biome with `scenario=biome wave=1/10/17`.
