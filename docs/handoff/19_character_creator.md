# TRIM, BOOTS, BARE OUTFITS AND THE MAGIC MIRROR (2026-11-18)
The owner asked for trim color, boot color, outfits that show skin, fewer look-alike beards and no invented color names. Done:
- **Looks are "parts:3:"** now (`PartsLook.ORDER` gained `trim` after `color` and `boots` after `hat_color`). "parts:1:" and "parts:2:" looks are still read (`ORDER_1`, `ORDER_2`): they get the trim they were drawn with
  (silver for charcoal, black, lavender and gold robes, gold for the rest) and brown boots; the beards `long`, `braided` and `wispy` (removed: under the arm they looked like `short`) are read as `short`, `short`, `goatee`.
- **Trim is its own layer.** `far_cuff`, `near_cuff`, `back_trim`, `body_trim` and `hat_trim` hold only what is painted in the trim's ramp; the cloth layers are drawn without it (`PartCanvas` modes "body" and "trim", found by the ramp object itself, so the
  drawing code is unchanged). Trim layers get no edge darkening. Eight trims (`TRIMS`): gold, silver, copper, iron, ivory, crimson, sapphire, emerald. Boots (`BOOTS`) are their own layers (`far_boot`, `near_boot`): brown, black, tan, gray, red, green, and `bare` (the foot in the skin).
- **Outfits that show skin:** `vest`, `pelt`, `sash`, `toga` (`SLEEVELESS`; `pelt` and `toga` also bare-legged, `BARE_LEGS`). The skin is its own layers (`torso_skin`, `far_arm`, `near_arm`, `far_bare_leg`, `near_bare_leg`), so every skin tone works.
- **Files shared by choices:** `variant_key` gives the file a choice is drawn in (or None: nothing); the build writes an `alias` table per slot into the manifest, which `PartFrames.layer_path` and `compose.py` read. The old special case for hats with no color is gone.
- **The creator** (`LikenessPanel`) is called "Magic Mirror", has rows for trim and boots, and names no colors (they are plain to see; only the bare-feet square has a tooltip). `pale` is lighter and `bone` is now the whitest skin.

# MORE PARTS (2026-11-17, later): the same day the owner asked for variety in every slot
Added with `tools/wizard_parts/parts.py` (no new slots, so saved looks still read): outfits cloak, ceremonial, rags, gothic, armored; robe colors black, gold, teal, rust;
skins ashen, frost, undead; hair mohawk, braids, straight, balding, wild; beards braided, handlebar, wispy, stubble; hats horned, skull, laurel, turban, mushroom, crown;
weapons staff_skull, staff_moon, staff_root, staff_lantern, crook, book, orb_hand, bone_wand. Hats with no color of their own are in `HAT_NO_COLOR` (parts.py, `PartsLook`, compose.py: keep the three in step).
578 packed layers. Beard color is always the hair's and hat color the robe's (`PartsLook.tied`). Labels for the creator are `LikenessPanel.NAMES` (drafts until the owner confirms).

# AS BUILT (2026-11-17): read this first, the plan below it is the art session's and is partly superseded

Done and in the game. What differs from the plan below:

- **The sheets are not in `art/`.** The 203 sheets (6.4 GB if unpacked) are in `art_source/parts_sheets/` (not imported). `tools/pack_parts.gd` packs each into `art/parts/<slot>/<variant>.parts`
  (one zstd strip per animation; 5 MB for all). Rerun it (`godot --headless --path . -s tools/pack_parts.gd`) after changing the sheets. Export presets include `art/parts/*`.
- **Code:** `PartsLook` (the look string and its validation), `PartFrames` (stacks the layers one animation at a time, caches by weak reference, `warm_next` fills in the rest for the
  person's own wizard), `MagicLayer` (the gem and effects, shader `magic_ramp.gdshader` with a `keep` cut), `WizardPose` (which of the 48 animations: the first rule that holds wins),
  `CastStyles` (spell -> casting animation; `throw` is only Pebble and Barbs, owner 2026-11-17, and Icicles is `cast_sky`; Ignite, Frostbolt and Flaming Sphere use `release`), `Wizard.look_dir` (a visual facing for pulls and shoves, synced), `WizardLook.dress_sprite` (cut-scenes, decoys, menu).
- **The seven found figures are gone from play** (`WizardLook.LOOKS` and the art stay in the files; `WizardLook.is_look` accepts only parts looks; an old saved look is ignored). Palettes are unused.
  Looks of brains come from `Net.rival_look` (seeded by `MatchState.seed_base` and the seat). The first seat starts as `PartsLook.DEFAULT_LOOK`.
- **Feet:** the art's boots are one row above the bottom of the frame, so `PartFrames.OFFSET` is -68, not -69.
- **Cost:** about 130 ms to make a new look's common animations, 7 to 14 ms for one more; about 250 MB of textures for eight wizards in a match (one made whole).
- **Checks:** `parts_check` (files, options, pixel match with the art's reference, look strings, all 48 animations), `pose_check` (the state -> animation table, the magic keeping to the body).
  Pictures: `tests/looks/parts_look.tscn -- out=DIR scenario=lineup|anims|magic|memory` and `parts_game_look.tscn`.
- **Animations never played:** `inhale` (nothing to time it with before Fire Breath/Spore Puff) and `sucked_in` (nothing in the game consumes a wizard). Cast styles are in `CastStyles`.

---

# Handoff: putting the character creator into the game

**For:** the model that works on the wizard game (`C:\Users\Jordan Polun\Desktop\wizard-game\`).
**From:** the art session that made the parts. Everything it made now lives in this repo; **how to make or change parts
and animations is chapter 20** (`docs/handoff/20_making_wizard_parts.md`).
**Status (2026-11-17):** the art is finished. The integration below was begun (`scripts/wizard/parts_look.gd`,
`scripts/wizard/part_frames.gd`, `tools/pack_parts.gd`, `art/parts/`, `tests/checks/parts_check.gd`); read the code for what
is done. Follow the game's own `CLAUDE.md` first (wording rules, testing, network play); where this file and the game's docs
disagree, the game's docs win, and tell the owner.

Suggested: copy this file into the game as `docs/handoff/19_character_creator.md` and add it to the chapter table in `CLAUDE.md`.

---

## 1. What the owner wants (their decisions)

- Replace "pick one of 7 found sprites + a color filter" (`scripts/wizard/wizard_look.gd`, the Likeness panel) with a real
  **character creator**: the player mixes and matches **skin, outfit, outfit color, hair, hair color, beard, beard color,
  hat, hat color and weapon**.
- **No body-type option and no accessories.** (Both were tried and dropped.)
- **Spell color is not a player choice.** The weapon's gem, its glow and every in-frame spell effect take the color of
  the spell being cast, and **the only possible colors are the game's 7 schools** (`SpellData.SCHOOL_COLORS`). They are
  drawn in one separate layer, in key grays, that the game recolors at runtime (section 4.4 has the exact formula).
- **Style must match the existing art** (`docs/handoff/04_art_and_assets.md`: no cartoon outlines, gothic pixel art,
  1 art pixel = 1 world pixel). The figure is drawn exactly like `art/chars/wizard`: same frame size, same height, same
  feet position, scale 1.0.
- **Match the style, never the character.** Default and demo characters must not look like the purple-hooded sample
  wizard (no purple hood + long white beard + cyan crystal staff together).
- **Staffs are held "choked up"** (hand about two thirds of the way up). In `cast` the **weapon hand** draws the
  stroke, not the free hand.
- **Effects that would run off the frame are not drawn** (rocket boost, beams, the release blast). The game draws the
  spell itself; the frames only carry the body and a muzzle flash at the weapon tip.
- The extra animations in section 7 were all approved. The owner turned down: sinking, burning, fizzle, a transform into
  the werewolf, an open-mouth head, and a separate faint (Faint keeps playing `death`; only `wake` is new).

---

## 2. What was delivered (where it lives in this repo)

| Path | What it is |
|---|---|
| `art_source/parts_sheets/<slot>/<variant>.png` (packed for the game into `art/parts/<slot>/<variant>.parts` by `tools/pack_parts.gd`) | **The parts library**: 203 sprite sheets, ~12 MB. One sheet per variant of each body slot. |
| `art_source/parts_sheets/manifest.json` (copied to `art/parts/manifest.json`) | **Everything the game needs to read**: frame size, sheet layout, all 48 animations (start/count/fps/loop), the options, the slots in draw order with their dependencies and existing variants, and the magic-layer key grays. Treat it as the source of truth. |
| `scripts/fx/magic_ramp.gdshader` | Canvas shader that maps the magic layer's key grays to a spell's 4 colors. |
| `art_source/wizard_parts_preview/gifs/*.gif` | One GIF per animation for a test character (magic shown in Fire), `all_animations.gif`, `lineup_mix_and_match.gif` (six different characters from the same parts, each in a different school color), `spell_colors.gif` (the 7 schools). **Use these to check your in-game result looks the same.** |
| `art_source/wizard_parts_preview/test_character/` (its sheet + config also in `art_source/parts_sheets/reference/`) | The test character's config (`test_character.json`), its composed sheet, a layered `test_character.aseprite` (one layer per slot, all animations tagged), and the six lineup configs. |
| `tools/wizard_parts/compose.py` | **Reference implementation** of mix-and-match: it stacks the sheets for a config and recolors the magic layer. Your GDScript must produce the same pixels. |
| `tools/wizard_parts/` (`parts.py`, `poses.py`, `poses_extra.py`, `build.py`, `rebuild_all.py`, ...) | The generator (Python + PIL/numpy) that drew every sheet. Only needed to change or add art (section 10). |
| `docs/handoff/20_making_wizard_parts.md` | How the rig works and exactly how to make new parts and animations. |

Provenance for `04_art_and_assets.md`: all of this art was **generated procedurally by scripts written in that session**
(an IK rig drawing shaded shapes), not traced or recolored from any downloaded sprite. Only the **style** (size,
proportions, shading approach) was matched to `art/chars/wizard`. No license strings attached; it is the owner's.

---

## 3. How the parts system works (read this before writing code)

### 3.1 Every sheet has the same layout

- Every frame is **254 x 138 px**, exactly like `art/chars/wizard`. The figure faces **right**. The **feet are on the
  bottom row**, centred at **x = 127**. So the existing `PixelArt.CHARACTERS["wizard"]` entry (size and body box) and
  `_sprite.offset = Vector2(0, -138 * 0.5)` are already right.
- Each sheet holds **all 236 frames** of all 48 animations in a fixed order, left to right, top to bottom, **9 columns**
  (sheet = 2286 x 3726 px, 27 rows). Frame `k` is at `x = (k % 9) * 254`, `y = (k / 9) * 138`.
- `manifest.json -> animations[name] = {start, count, fps, loop}` says where each animation's frames are.
- **Every sheet of every slot is frame-aligned:** frame `k` of the torso sheet lines up with frame `k` of the hat sheet,
  the weapon sheet, and every other slot. That is what makes mix-and-match a plain stack.

### 3.2 Slots: the layers of a character, back to front

A character is **17 layers** stacked in this order (`manifest.json -> slots`, already in draw order). Each slot's look
depends only on the options listed:

| # | slot | depends on | what it is |
|---|---|---|---|
| 1 | `far_sleeve` | color | the arm on the far side, in the outfit color |
| 2 | `far_hand` | skin | its hand |
| 3 | `far_leg` | color | far leg: trousers (a darker shade that goes with the outfit) and boot |
| 4 | `back_coat` | outfit, color | the coat's back tail (only the `coat` outfit has one) |
| 5 | `torso` | outfit, color | body, shoulders, collar and trim |
| 6 | `near_leg` | color | near leg and boot |
| 7 | `front_coat` | outfit, color | front coat tail / long robe skirt / tunic skirt |
| 8 | `belt` | outfit, color | belt and buckle, or a sash for the tunic |
| 9 | `hair_back` | hair, hair_color | hair behind the head (long hair, ponytail, bun, back tuft) |
| 10 | `head` | skin | face, ear, nose and eye |
| 11 | `beard` | beard, beard_color | beard and moustache |
| 12 | `hair_front` | hair, hair_color | the hair cap and fringe, **and the eyebrows** (so "no hair" still has brows) |
| 13 | `hat` | hat, hat_color | the hat, hood or circlet |
| 14 | `weapon` | weapon | the staff/wand/sceptre itself (wood, gold), **without** its gem |
| 15 | `near_sleeve` | color | the near arm, which holds the weapon |
| 16 | `near_hand` | skin | its hand, drawn over the weapon so the fist closes on it |

The hands are shaded like the sample wizard's: the weapon hand is a fist with three finger creases closing round the
shaft; the free hand is a fist in some poses (run, climb, beam, sweep, walk, fly, cower, victory...) and an open hand with
fingers and a thumb in others (idle, cast, throw, clap, summon, curse, fall...). Which one is baked into each frame, so
nothing in the game has to choose.
| 17 | `magic` | weapon | the gem + glow + every spell effect, **in key grays** (section 5) |

The order matters (for example the near hand must cover the weapon). Never reorder slots; read them from the manifest.

### 3.3 Options (`manifest.json -> options`)

| option | values (internal ids) |
|---|---|
| `skin` | pale, fair, light, olive, tan, bronze, brown, deep, ebony, sage (green), plum, ashen, frost, undead |
| `outfit` | coat (split coat tails), robe (ankle length), tunic (short, sash) |
| `color` | blue, purple, crimson, emerald, charcoal (silver trim), ivory |
| `hair` | none, short, long, ponytail, bun |
| `hair_color` | white, gray, black, brown, auburn, blonde |
| `beard` | none, short, long, goatee |
| `beard_color` | white, gray, black, brown, auburn, blonde |
| `hat` | none, pointy, wide (witch hat), hood, circlet |
| `hat_color` | blue, purple, crimson, emerald, charcoal, ivory |
| `weapon` | staff_orb, staff_crystal, staff_branch, wand, scepter |

That is 6 x 3 x 6 x 5 x 6 x 4 x 6 x 5 x 6 x 5 = over 23 million combinations from 203 files. **Every combination is
valid**; there are no forbidden pairs. The player-facing names are for you to write (follow section 0 of `CLAUDE.md`:
American spelling, "Gray", "Color"). Suggested: Skin, Outfit (Coat / Robe / Tunic), Robe color, Hair, Hair color,
Beard, Beard color, Hat (None / Pointed hat / Witch hat / Hood / Circlet), Hat color, Weapon (Orb staff / Crystal
staff / Branch staff / Wand / Scepter).

### 3.4 Which file to load for a slot (the mix-and-match rule)

```
variant = the values of the slot's depends_on options, in that order, joined with "-"
file    = parts/<slot>/<variant>.png
```

Examples for `{skin: tan, outfit: coat, color: blue, hair: short, hair_color: auburn, beard: short,
beard_color: auburn, hat: wide, hat_color: blue, weapon: staff_orb}`:

```
far_sleeve/blue.png      far_hand/tan.png        far_leg/blue.png       back_coat/coat-blue.png
torso/coat-blue.png      near_leg/blue.png       front_coat/coat-blue.png belt/coat-blue.png
hair_back/short-auburn.png head/tan.png          beard/short-auburn.png hair_front/short-auburn.png
hat/wide-blue.png        weapon/staff_orb.png    near_sleeve/blue.png   near_hand/tan.png
magic/staff_orb.png
```

Two special cases:
- **`hat` = `none` or `circlet` ignores `hat_color`:** the file is `hat/none.png` (doesn't exist, see the next rule) or
  `hat/circlet.png`.
- **A missing file means that slot draws nothing** for that choice: `hat/none`, `beard/none-*`, `hair_back/none-*`,
  `back_coat/robe-*` and `back_coat/tunic-*` don't exist on purpose. Skip them. Don't treat a missing file as an error,
  but do check it against `manifest.slots[i].variants` (that list holds exactly the files that exist).

### 3.5 Building one character = blend the sheets in order

Load each slot's sheet in manifest order and **alpha-blend** it over the previous ones (`Image.blend_rect`, not
`blit_rect`, because the glows and the fades are semi-transparent). Do this for every slot **except `magic`**. The result
is one 2286 x 3726 sheet: the whole character, every animation. Cut it into 254 x 138 frames for a `SpriteFrames`.
`tools/wizard_parts/compose.py -> compose_sheet()` does exactly this; compare your output against
`art_source/parts_sheets/reference/test_character_sheet.png` for the config in `reference/test_character.json` (that composed sheet
includes the magic layer recolored "amber"; compare body pixels, or recolor magic the same way).

The `magic` sheet is kept **separate** (its own sprite), because it changes color with the spell.

---

## 4. Implementation plan in the game

### 4.1 Put the files in the project

- (Done.) The sheets are in `art_source/parts_sheets/` and packed into `res://art/parts/` by `tools/pack_parts.gd`;
  the shader is `res://scripts/fx/magic_ramp.gdshader`. `python tools/wizard_parts/rebuild_all.py` redoes all of it.
- **Import settings for the sheets:** they are read as images to blend, not drawn directly, so import them **lossless**,
  **no mipmaps**, not VRAM-compressed (compression would break the exact key grays of `magic`). Check the `.import` files
  after the first editor scan. (Or load them with `Image.load_from_file()` from a non-imported folder; but exported builds
  need them imported, so prefer import + `Texture2D.get_image()`.)
- Record the provenance in `docs/handoff/04_art_and_assets.md` (section 2 above).

### 4.2 How a custom wizard is named: the look string

The game already passes a wizard's look around everywhere as one `String` (`wizard.look`, `GameSettings "look"`,
`Net.look_of()`, `Net._said_style` RPC, `match_end` / epilogue, the arena's seats). The least invasive design is to **keep
that plumbing and encode the whole config in the look string**:

```
"parts:1:" + values joined with "." in the manifest's option order
e.g. "parts:1:tan.coat.blue.short.auburn.short.auburn.wide.blue.staff_orb"
order: skin.outfit.color.hair.hair_color.beard.beard_color.hat.hat_color.weapon
```

The `1` is a format version (add options later without breaking saved looks). Write one helper (suggested: a new
`scripts/wizard/parts_look.gd`, `class_name PartsLook`) with `encode(config) -> String`, `decode(look) -> Dictionary`
(empty if invalid), `is_parts(look) -> bool`, `random_config(rng) -> Dictionary` and `default_config()`. Validate every value
against `manifest.options`, because a look arrives over the network.

**Default config** (what a new player starts with, and must not resemble the sample wizard): the test character,
`tan.coat.blue.short.auburn.short.auburn.wide.blue.staff_orb`.

### 4.3 Building the frames: a `PartFrames` builder (new file, next to `char_frames.gd`)

Sketch (adapt to the codebase's style; it is not tested in the game):

```gdscript
class_name PartFrames
## Builds a custom wizard's animations by stacking the part sheets in res://art/parts (see manifest.json).
## Built once per look string and shared by everyone wearing that look, like CharFrames.

const DIR := "res://art/parts/"
static var _manifest: Dictionary
static var _body_cache := {}   # look -> SpriteFrames (all slots but magic)
static var _magic_cache := {}  # weapon -> SpriteFrames (the magic layer)

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
	return _manifest

static func _sheet_path(slot: Dictionary, config: Dictionary) -> String:
	var name: String = slot["name"]
	var key: String
	if name == "hat" and (config["hat"] == "none" or config["hat"] == "circlet"):
		key = config["hat"]
	else:
		var values: PackedStringArray = []
		for option: String in slot["depends_on"]:
			values.append(config[option])
		key = "-".join(values)
	if not (slot["variants"] as Array).has(key):
		return ""  # this choice draws nothing in this slot
	return DIR + name + "/" + key + ".png"

static func body(look: String) -> SpriteFrames:
	if _body_cache.has(look):
		return _body_cache[look]
	var config := PartsLook.decode(look)
	var m := manifest()
	var size: Array = m["sheet_size"]
	var sheet := Image.create(int(size[0]), int(size[1]), false, Image.FORMAT_RGBA8)
	for slot: Dictionary in m["slots"]:
		if slot["name"] == m["magic"]["slot"]:
			continue
		var path := _sheet_path(slot, config)
		if path == "":
			continue
		var part := (load(path) as Texture2D).get_image()
		part.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
	var frames := _cut(ImageTexture.create_from_image(sheet))
	_body_cache[look] = frames
	return frames

static func magic(weapon: String) -> SpriteFrames:
	if not _magic_cache.has(weapon):
		_magic_cache[weapon] = _cut(load(DIR + "magic/" + weapon + ".png"))
	return _magic_cache[weapon]

static func _cut(texture: Texture2D) -> SpriteFrames:
	var m := manifest()
	var w: int = m["frame_size"][0]
	var h: int = m["frame_size"][1]
	var cols: int = m["columns"]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in m["animations"]:
		var a: Dictionary = m["animations"][anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, a["fps"])
		frames.set_animation_loop(anim, a["loop"])
		for k in range(int(a["start"]), int(a["start"]) + int(a["count"])):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2((k % cols) * w, (k / cols) * h, w, h)
			frames.add_frame(anim, atlas)
	return frames
```

Notes:
- **fps/loop:** the manifest copies `wizard.gd ANIMATIONS` for the core 8 (`cast` loops at 8, `release` once at 16, and so on).
  If the game wants different speeds, override them in code like `ANIMATIONS` does now; don't edit the manifest by hand.
- **Memory:** one composed sheet is 2286 x 3726 RGBA = about 34 MB of texture. A match with 8 different custom wizards
  is about 270 MB. If that's too much: cache by look (identical looks share), drop cached sheets after a match, or
  build only the core 8 animations eagerly and the rest when first played (blend only those rows: frames 0-44 are the
  core 8). The magic sheets are shared per weapon (5 at most).
- **Building is a one-time cost** per look (16 blends of a 2286 x 3726 image). Do it when the look is chosen or the
  match loads, not mid-fight. Clients build the other players' looks from the string they received.

### 4.4 Dressing the wizard (`scripts/wizard/wizard.gd -> dress()`)

Now: `look == "wizard"` uses `art/chars/wizard`, otherwise `Mob.KINDS[look]`. Add a branch first:

```gdscript
if PartsLook.is_parts(look) and not wolf.on:
	_sprite.sprite_frames = PartFrames.body(look)
	_sprite.scale = Vector2.ONE
	_sprite.offset = Vector2(0, -PixelArt.CHARACTERS["wizard"]["size"].y * 0.5)
	_art = "parts"
	_magic_sprite.sprite_frames = PartFrames.magic(PartsLook.decode(look)["weapon"])
	_magic_sprite.visible = true
	...
```

- **The magic sprite:** add a child `AnimatedSprite2D` (`_magic_sprite`) above `_sprite`, with the same offset and
  `flip_h`, and a `ShaderMaterial` using `magic_ramp.gdshader`. Every frame, in `_animate()`, copy the body's animation and
  frame into it (`_magic_sprite.animation = _sprite.animation; _magic_sprite.frame = _sprite.frame;` and the same
  `speed_scale`/pause handling, so frozen stays frozen). Hide it for the old looks and the werewolf. Apply the same
  `modulate` (hit flash, blink, Sneak fade) and the `keep` cut (stuck in the ground) as the body, or it will show alone.
- **Color the magic from the spell (the game's job, at runtime):** the possible magic colors are exactly the game's
  **7 schools**, `SpellData.SCHOOL_COLORS` (Fire, Water, Air, Earth, Flora, Shadow, Blood). The wizard already has
  `cast_color` (the school being drawn). Turn that one color into the shader's four with **exactly this formula** (it is
  the one the art session used for `manifest.magic.example_spells` and `art_source/wizard_parts_preview/gifs/spell_colors.gif`, so the game will match):
  ```gdscript
  static func magic_ramp(c: Color) -> Array[Color]:
  	return [c.lerp(Color.WHITE, 0.75), c.lerp(Color.WHITE, 0.35), c, Color(c.r * 0.5, c.g * 0.5, c.b * 0.5)]
  # material.set_shader_parameter("near_white", r[0]); ("light", r[1]); ("mid", r[2]); ("deep", r[3])
  ```
  If a school color ever changes in `spell_data.gd`, nothing in the art needs rebuilding; only
  `tools/wizard_parts/parts.py SCHOOL_COLORS` (used for the preview GIFs) should be kept in step.
  When no spell is being cast, use the last spell's school, or the player's most-used school, for the idle gem glow. Some frames
  carry non-spell effects in this layer (the dazed stars, the thaw ice shards, the clap shockwave): set a fitting ramp
  for those animations (yellow for dazed, pale blue for thaw/frozen). The key grays are 236 / 190 / 128 / 70 (pure white
  255 stays white); the shader's thresholds are written for exactly those, so keep the sheets lossless.
- **The body material** (`wizard_body.gdshader`) still applies: `keep`, `obsidian` and `aura` work as before. **Turn the
  robe/trim recolor off** for parts looks: there is no `WizardLook.GROUPS` entry, so make `WizardLook.paint()` set the
  groups to hue -1 for a parts look (and ignore `palette`). The outfit color comes from the parts.
- `WizardLook.scale_of()` must return 1.0 for a parts look; `WizardLook.is_look()` must accept a valid parts string
  (this is what `Net.look_of()` and `Net._said_style` use to validate, so network play keeps working).
- **Werewolf (Wild Shape)** keeps its own art, as now.

### 4.5 Every place that reads a look (all need the parts branch)

Found by `grep -rn "art/chars\|\.look\b\|is_look\|PixelArt.CHARACTERS" scripts`:

| File | What to do |
|---|---|
| `scripts/wizard/wizard_look.gd` | `is_look`, `scale_of`, `paint`, `swatch`, `jump_sound` handle parts strings. The 7 old looks can stay as presets or be retired; ask the owner. |
| `scripts/core/net.gd` | `look_of` / `_said_style` validate through `WizardLook.is_look`. `rival_look(seat)` chooses a brain's look: give brains `PartsLook.encode(PartsLook.random_config(rng_seeded_by_seat))` so AI wizards are varied too (and never two alike). |
| `scripts/core/game_settings.gd` | `"look"` already stores a String: the parts string fits. `"palette"` becomes unused for parts looks. |
| `scripts/wizard/wizard.gd` | `dress()`, `_animate()` (section 7), the magic sprite. |
| `scripts/wizard/char_frames.gd` | unchanged; `PartFrames` sits beside it. |
| `scripts/screens/likeness_panel.gd` | becomes the creator UI (section 6). Its portraits load `art/chars/<look>/idle_0.png`; for parts, show frame 0 of `PartFrames.body(look)`'s `idle`. |
| `scripts/spells/decoy.gd` | builds the caster's frames with `CharFrames`: use `PartFrames.body(look)` for a parts look (and the magic sprite, or none). |
| `scripts/screens/epilogue.gd`, `scripts/arena/match_end.gd` | the winner's look/palette are passed along: the parts string just works once the epilogue builds frames through the same branch. |
| `scripts/screens/intro.gd` | the intro's eight wizards are fixed old looks; fine to leave, or swap in parts presets. |
| `scripts/screens/menu.gd` | loads `art/chars/wizard/idle_*.png` for the menu figure; leave, or show the player's own look. |
| `scripts/arena/insight_tip.gd` | checks `Mob.KINDS.has(look)`, which is false for parts: fine. |
| `tests/checks/intro_check.gd`, `tests/checks/likeness_check.gd`, `tests/looks/look_palettes.gd` | assume `res://art/chars/<look>/`; update them for parts looks, and add the checks in section 9. |

### 4.6 Network

Only the look string travels (as now, through `_said_style(look, palette)`). Each machine builds the frames locally from
the same files, so every machine sees the same pixels. `shown_anim` already carries the animation name to the other
machines (`_animate()` sets it); the new animation names travel the same way. **A likeness (`is_likeness()`) plays
`shown_anim`**, so the other machines need the new animations too, which they have, since every parts look has all 46.
Old looks don't: see the fallback in section 7.3.

---

## 5. The magic layer in detail

- Drawn in five values only: **255 (white, stays white), 236 (near-white), 190 (light), 128 (mid), 70 (deep)**, with
  alpha. The shader maps 236/190/128/70 to the spell's `near_white` / `light` / `mid` / `deep`.
- It holds: the weapon's gem (every frame where the weapon is held) and its soft glow (semi-transparent), the cast
  loop's stroke trail and pulsing ball at the tip, the release muzzle flash, sparks, the idle motes over the open hand,
  and the effects of the extra animations (stars, shards, rings, rising motes, wisps).
- It's drawn **on top of everything** (the gem is always at the tip, clear of the body), so one overlay sprite is right.
- It has **no outline** on purpose (it's light).
- `tools/wizard_parts/compose.py -> recolor()` and the shader use the same thresholds; `art_source/wizard_parts_preview/gifs/spell_colors.gif` shows the same
  character casting in all **7 school colors** (`manifest.magic.example_spells` = Fire, Water, Air, Earth, Flora,
  Shadow, Blood, made from `SCHOOL_COLORS` with the formula in 4.4). The spell color is never stored in the look: the
  player doesn't choose it.

---

## 6. The creator UI (the Likeness panel)

`scripts/screens/likeness_panel.gd` is the wizard maker in the waiting room ("the words at the glowing spot on the hill").
It saves to `GameSettings` and tells everyone (`Net`). Keep that flow; change what it offers:

- A **live preview**: an `AnimatedSprite2D` with `PartFrames.body(look)` + the magic sprite, playing `idle` (and maybe
  `cast` when hovering the weapon row). Rebuild it when a choice changes (cheap enough for a preview; or build only the
  idle rows while the panel is open).
- One row per option with previous/next arrows or a strip of buttons: Skin, Outfit, Robe color, Hair, Hair color, Beard,
  Beard color, Hat, Hat color, Weapon. Hide the hat color row when the hat is None or Circlet, the beard color row when
  the beard is None, and the hair color row when the hair is None (the eyebrows still use it: you may keep it).
- A **Random** button (`PartsLook.random_config`), since the space is huge.
- Swatches for the color rows: take each color's mid value from the generator (`tools/wizard_parts/parts.py`: `COLORS[...]["main"][1]`,
  `HAIRS[...][1]`, `SKINS[...][1]`) or sample the part sheets.
- On every change: `GameSettings.set_value("look", PartsLook.encode(config))`, re-dress the wizard, and announce the style
  to the other machines exactly as the panel does now.
- Wording: follow `CLAUDE.md` section 0 (player-facing words). Labels are short nouns; buttons imperative.

---

## 7. The animations

### 7.1 The 48 animations (all in every parts look)

Frames, fps, loop. Facing right. **Directions:** `pulled` / `sucked_in` are drawn with the pull coming **from the front**,
so face the sprite toward the source (black hole, Thorn Whip's caster). `knockback` throws the wizard **backward**, so
face the sprite toward whatever hit them. `turn` squeezes the figure thin; flip `flip_h` on its middle frame.

**Core 8** (what the game plays today; fps/loop are copied from `wizard.gd ANIMATIONS`):

| anim | frames | fps | loop | notes |
|---|---|---|---|---|
| idle | 6 | 8 | yes | staff planted, motes over the free hand |
| run | 8 | 12 | yes | long strides, staff carried forward |
| cast | 8 | 8 | yes | staff held up; the weapon hand traces the stroke, the tip leaves a glowing trail |
| release | 8 | 16 | no | thrust forward; a muzzle flash at the tip only |
| hit | 4 | 12 | no | recoil with a short white flicker |
| death | 7 | 9 | no | collapses forward, ends lying flat (also used for Faint) |
| jump | 2 | 10 | no | |
| fall | 2 | 8 | yes | knees tucked, staff arm up |

**Movement:**

| anim | frames | fps | loop | play it when |
|---|---|---|---|---|
| swim | 6 | 8 | yes | out of its depth (`swim_time > 0`) and not diving |
| swim_dive | 6 | 10 | yes | swimming and pressing down / sinking under (`13_special_worlds.md`) |
| climb | 6 | 8 | yes | on a vine (`vine` holds one) and moving up or down; the vine is ~10 px in front of the body |
| climb_hang | 2 | 3 | yes | on a vine, not moving |
| float | 4 | 6 | yes | `feather_time > 0` and falling; also good for Updraft, and maybe `drawn` (a collapsing portal carrying the wizard up) |
| surf | 4 | 10 | yes | `surf_time > 0` (Tide Surf) |
| rocket | 4 | 12 | no | `rocket_time` starts (Rocket Jump): crouch then launch pose. No flame in the frames: the game draws the boost |
| fly | 4 | 10 | yes | `flying` (sky world) and moving; today it uses jump/fall |
| land | 3 | 16 | no | on landing after a real fall (optional polish) |
| stuck | 6 | 8 | yes | `root_time`, `tangle_time` or `sink_time > 0` (Bramble, Mudslide, quicksand, roots) and trying to move |

**Done to the wizard:**

| anim | frames | fps | loop | play it when |
|---|---|---|---|---|
| frozen | 2 | 4 | yes | `is_frozen()`. Today the game freezes whatever pose it was in (`speed_scale = 0`); play `frozen` instead (still pause it if you like: it's a 1 px shiver). The ice block stays the game's |
| thaw | 4 | 12 | no | the moment the ice breaks or melts. Its shards are in the magic layer: give it an ice ramp |
| pulled | 6 | 10 | yes | being pulled (`pull()`: Black Hole, Supernova's pull, Thorn Whip's drag) while on the ground |
| sucked_in | 6 | 12 | no | consumed by a Black Hole, if the game has that moment. Spins, stretches, shrinks and fades by itself |
| knockback | 4 | 12 | yes | flung by `push()` (Gust, Push, Geyser, Earthquake, Scythe, Great Oak, Supernova, Flaming Sphere) while airborne from it |
| get_up | 5 | 10 | no | after a knockback lands hard (optional), from lying face down |
| dazed | 6 | 8 | yes | `daze_time > 0` (Thunderclap). Stars in the magic layer: yellow ramp |
| wake | 5 | 6 | no | when a Faint ends (`fainted` goes false). Starts from `death`'s last pose, so it follows on cleanly |
| gasping | 6 | 8 | yes | Vacuum, or out of air under water (`lungs`) |
| cower | 4 | 10 | yes | Fight or Flight, fleeing (`fear_time > 0`) |

**Casting styles** (one-shots instead of `release`, chosen by the spell; the spell's effect is drawn by the game):

| anim | frames | fps | loop | spells it suits (owner: "some tags may be off, keep them anyway") |
|---|---|---|---|---|
| inhale | 3 | 10 | no | before Fire Breath / Spore Puff |
| exhale | 4 | 12 | yes | while Fire Breath / Spore Puff pours out |
| cast_sky | 6 | 14 | no | Spark, Stonefall, Moonbeam, Hailstorm, Blizzard, Eclipse, Supernova |
| cast_ground | 6 | 14 | no | Earthquake, Stalagmite, Stone Wall, Sinkhole, Geyser, Bramble, Great Oak, Glowcap, Flytrap, Liana, Mudslide, Lily Pads, Frost Bridge |
| beam | 4 | 12 | yes | while a beam lasts: Eldritch Blast, Leech's tether. No beam in the frames, only a glow at the tip |
| throw | 6 | 14 | no | Pebble, Barbs, Ignite, Frostbolt, Flaming Sphere, Icicles |
| sweep | 6 | 14 | no | Thorn Whip, Scythe, Gust, Push, Tornado |
| empower | 6 | 12 | no | Adrenaline, Crimson Veil, Obsidian Armor, Barrier, Sneak, Hunter's Mark |
| clap | 5 | 14 | no | Thunderclap |
| summon | 6 | 10 | no | Raise Dead, Decoy, Insect Plague, Mirage |
| curse | 5 | 12 | no | Hex, Hemorrhage, Faint, Fight or Flight, Silence |
| vanish | 5 | 12 | no | Shadow Step (start), Sneak. Fades the body itself (baked alpha); combine carefully with `FADE_ALPHA` |
| appear | 5 | 12 | no | Shadow Step (arrival) |

**Polish:**

| anim | frames | fps | loop | play it when |
|---|---|---|---|---|
| spawn | 6 | 10 | no | arriving out of the summoning circle (`SPAWN_TIME`) |
| idle_fidget | 8 | 8 | no | now and then after standing idle a while; return to idle after |
| turn | 3 | 16 | no | changing facing while standing; flip `flip_h` at frame 1 |
| victory | 6 | 10 | no | winning a match / the epilogue |
| walk | 8 | 10 | yes | slow movement (slowed, haste off, `slow_time > 0`, or walking in the waiting room) |

The exact trigger variables above were read from `wizard.gd` but not tested; check each against the code (and
`docs/handoff/02_codebase_map.md`) before relying on it.

### 7.2 Choosing them in `_animate()`

`_animate()` picks one name by priority: likeness / dead or fainted / hurt / releasing / casting / flying / airborne / running /
idle. Extend it in the same style, highest priority first, for example: dead or fainted -> `death` (then `wake` once
when a faint ends); frozen -> `frozen`; hurt -> `hit`; releasing -> **the spell's casting style** (store which style the
last spell asked for when `play_cast_release()` is called, defaulting to `release`); casting -> `cast`; pulled ->
`pulled`; dazed -> `dazed`; fear -> `cower`; on a vine -> `climb` / `climb_hang`; swimming -> `swim` / `swim_dive`; surf ->
`surf`; rocket -> `rocket`; flying -> `fly`; feather fall -> `float`; knocked back -> `knockback`; stuck -> `stuck`;
airborne -> `jump` / `fall`; moving -> `run` (or `walk` when slow); else `idle` (with an occasional `idle_fidget`). One-shot
animations need a timer like `_releasing` so they finish before something else takes over. A per-spell style needs
a field on `Spell` (e.g. `body_anim := "release"`) set in `data/spells/*.tres`.

### 7.3 Old looks don't have the new animations

The 7 found sprites only have the core 8. If old looks stay in the game, map a missing animation to a core one before
playing it (`SpriteFrames.has_animation()`): swim/swim_dive/float/fly/knockback/sucked_in -> fall; climb/climb_hang ->
jump (or idle); surf/stuck/pulled/gasping/cower/dazed/frozen -> idle (frozen: keep today's "pause the current pose");
thaw/get_up/wake -> idle; casting styles/inhale/exhale -> release; rocket -> jump; land -> idle; spawn/turn/idle_fidget/
victory -> idle; walk -> run. Remote machines need the same fallback, since `shown_anim` may name a new animation.

---

## 8. Things to watch out for

- **Don't scale the frames** except by whole numbers (`04_art_and_assets.md`). They are drawn at the wizard's 1.0 height.
- **Keep the magic sheets lossless:** any filtering or compression changes the key grays and the shader will pick the
  wrong colors (it shows as wrong-colored speckles in the glow).
- **Blend, don't blit,** when stacking: glows and the baked fades (`vanish`, `appear`, `spawn`, `sucked_in`) are
  semi-transparent.
- **The magic sprite must follow the body exactly**: animation, frame, `flip_h`, offset, `modulate`, `keep`, hidden state,
  and the frozen pause. If it lags by a frame the gem jumps off the staff.
- **Frame 0 of every animation starts from a sensible pose**, but `wake` starts from `death`'s last frame (lying flat),
  and `get_up` from lying face down: don't play them from standing.
- **The in-frame offsets:** the airborne animations (`fall`, `float`, `rocket`, `fly`, `swim`, `knockback`) lift the body
  a little inside the frame, like the original wizard's `fall` (about 12 px). The physics body doesn't move; that's intended.
- **Network:** never send the config as anything but the look string; validate it (`PartsLook.decode` returning empty
  -> fall back to the seat's look, as `Net.look_of` does now).
- **Old saves:** a saved `"look"` of `"wizard"` etc. must still load (keep the old looks or map them to a parts preset).

---

## 9. Testing (see the game's `docs/handoff/07_testing.md`; it defines what "done" means)

Add checks (headless where possible):
1. **Every variant file exists and has the manifest's size:** for each slot, each name in `variants` loads and is 2286 x 3726.
2. **Every option combination resolves:** for each option value (one at a time over the default), `_sheet_path` returns a
   file or "" only for the documented empty cases; never a missing file outside them.
3. **Composite matches the reference:** compose `art_source/parts_sheets/reference/test_character.json`'s config and compare a few frames to
   `reference/test_character_sheet.png` (body slots; recolor magic "amber" with the manifest ramp to compare everything).
4. **Look strings round-trip:** `decode(encode(c)) == c` for random configs; garbage strings decode to empty; `is_look`
   accepts parts strings; `Net.look_of` falls back on an invalid one.
5. **Every animation in the manifest exists in the built SpriteFrames** with the right count, fps and loop.
6. **Two machines** (the game's network test procedure): a player picks a custom look; the other machine sees the same
   figure, the same animations and the magic colors changing with the spell.
7. **Picture test:** screenshot a custom wizard idle / casting / frozen / swimming in a world and compare against the
   GIFs in `art_source/wizard_parts_preview/gifs/`.

---

## 10. Changing or adding art (the generator)

Moved to its own chapter: **`docs/handoff/20_making_wizard_parts.md`** explains, step by step, how the generator in
`tools/wizard_parts/` works and how to add hats, hair, colors, weapons and animations; then
`python tools/wizard_parts/rebuild_all.py` redraws, packs, previews and checks everything in one go.
