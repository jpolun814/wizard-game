# 20. Making wizard parts and animations (the character creator's art)

Read this before you add or change anything a custom wizard wears or does: a hat, a hair style, a beard, an outfit, a
color, a skin tone, a weapon, an animation, a spell effect drawn on the wizard. It assumes you know nothing. Chapter 19
(`19_character_creator.md`) is the other half: how the game reads these parts. Chapter 04 (`04_art_and_assets.md`) has the
game-wide art rules, which still apply.

**The art is not drawn by hand. It is drawn by a Python program**, a small "rig": a skeleton posed frame by frame, with
every body part painted as shaded shapes, one layer per part. Change the program, run it, and every combination of parts
gets the change in every frame. **Never edit the output PNGs by hand**: the next run overwrites them, and an edit would
have to be repeated in up to 36 variants of a slot.

---

## 0. The owner's rules for this art (all from the owner, 2026-11-17; quoted in `01_feedback_log.md`, round 10)

These decide every judgment call. Breaking one is a failure even if the picture looks fine.

1. **Match the style of `art/chars/wizard` (the sample), never its character.** Same frame size, same height, same feet,
   same shading approach. But nothing made here may look like that wizard: never a purple hood + long white beard + cyan
   crystal staff together, never its exact palette. The owner: *"the 'test wizard' you make shouldn't look like the one from
   the sample, that'd be probably not legal."*
2. **No outlines.** No dark ring around a part. Edges come from the material's own darker tones (`selout()`, section 5.4).
   Chapter 04 says the same: "no cartoon outlines".
3. **A limb is one piece.** No seam, no line, no shading jump at a knee, elbow or ankle. A boot is one shape from the
   shin, down the heel, along a sloping instep to the toe (`limb()`, section 5.3). The owner: *"knee ankle and elbow all
   look like separate components... they've got like an outline"*, and later *"the boots... there's clearly a foot section
   and a calf section."*
4. **Hands are hands.** A weapon hand is a fist with finger creases closing round the shaft; a free hand is a fist or an
   open hand with fingers and a thumb, shaded, no outline (`fist()`, `open_hand()`).
5. **Staffs are held choked up**, the hand about two thirds of the way up (`STAFF_GRIP = 0.66`). Wands and sceptres are held
   a third of the way along with the end showing below the fist.
6. **The weapon hand does the magic.** In `cast` the weapon hand traces the stroke; the free hand stays still.
7. **Spell color is the game's, never the player's, and only the 7 schools.** Every gem, glow and in-frame effect goes in
   the `magic` slot, drawn in key grays, recolored at runtime from `SpellData.SCHOOL_COLORS` (section 6).
8. **Nothing may run off the frame.** No beams, rocket flames or blasts reaching the frame edge: the game draws the spell
   itself. The frames carry the body and at most a muzzle flash, sparks or a small effect near the body.
   `edge_check.py` enforces this. The owner: *"we dont need the blast coming out the feet... same with the beam and other
   things that have a line going outside the frames. it'll just look weird in the game."*
9. **Not cartoony.** Small head, slim limbs, long legs, realistic proportions like the sample.
10. **Always show the owner GIFs** when you think you are done (`art_source/wizard_parts_preview/gifs/`), and say plainly
    what you checked.

Things the owner decided NOT to have: a body-type option, accessories (book, pouch), the animations sinking, burning,
fizzle and transform, an open-mouth head for breathing spells, a separate faint (Faint plays `death`, then `wake`).

---

## 1. Where everything is

| Path | What |
|---|---|
| `tools/wizard_parts/` | **The generator.** Python 3 + Pillow + numpy. All the drawing code and the tools below. |
| `tools/wizard_parts/rig.py` | The low-level canvas: masks (capsule, ellipse, polygon), shading, IK, the base palettes. |
| `tools/wizard_parts/anims.py` | The original pose helpers (`default_pose`, `S`, `kf`) and the hit/death/jump poses still used. |
| `tools/wizard_parts/parts.py` | **The parts:** palettes, `OPTIONS`, `SLOTS`, the skeleton, every body part, weapons, the magic layer and its effects, `render_layer()`. |
| `tools/wizard_parts/poses.py` | The 8 core animations' poses (idle, run, cast, release, fall; hit/death/jump from anims.py) and `ANIMS`, the list of every animation in sheet order. |
| `tools/wizard_parts/poses_extra.py` | The 38 extra animations (swim, climb, pulled, cast_sky...) and `EXTRA`, `GROUPS`. |
| `tools/wizard_parts/build.py` | Draws every variant of every slot into a sheet + writes `manifest.json`. |
| `tools/wizard_parts/rebuild_all.py` | **Runs the whole pipeline** (section 2). Use this. |
| `tools/wizard_parts/preview.py` | Draws chosen frames of a character without building anything. |
| `tools/wizard_parts/contact_sheet.py` | Every frame of some animations, one row each. Your main review tool. |
| `tools/wizard_parts/compare_ref.py` | Sample wizard on top, ours below, zoomed. For judging style. |
| `tools/wizard_parts/edge_check.py` | Fails if anything touches the frame edge. |
| `tools/wizard_parts/compose.py` | Stacks finished sheets for a config (what the game does); the Python reference for `PartFrames`. |
| `tools/wizard_parts/make_test.py` | Composes the test character + a lineup from the sheets; writes the preview GIFs. |
| `tools/wizard_parts/layered.lua` | Aseprite script: a one-layer-per-slot `.aseprite` of the test character. |
| `art_source/parts_sheets/` | **The generator's output:** `<slot>/<variant>.png` sheets + `manifest.json` + `reference/` (the test character the game's check compares to). Ignored by Godot (`art_source/.gdignore`). |
| `art/parts/` | What the game loads: the sheets packed by `tools/pack_parts.gd` into `<slot>/<variant>.parts`, plus a copy of `manifest.json`. |
| `art_source/wizard_parts_preview/` | `gifs/` (one GIF per animation, `all_animations.gif`, `lineup_mix_and_match.gif`, `spell_colors.gif`) and `test_character/` (config, composed sheet, layered `.aseprite`). |
| `scripts/wizard/parts_look.gd`, `part_frames.gd`, `scripts/fx/magic_ramp.gdshader`, `tests/checks/parts_check.gd` | The game side (chapter 19). |
| `art/chars/wizard/` | The sample wizard: the style reference. Look, don't copy. |

---

## 2. Setup and the commands

**Setup (once):** Python 3.9+ with `pip install pillow numpy`. Godot is the one `tools/run_checks.py` uses
(`GODOT` environment variable, default `C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`).
Aseprite (optional, for the layered file) is at `C:/Users/Jordan Polun/Desktop/aseprite/build/bin/aseprite.exe`
(`ASEPRITE` variable). Run the tools from `tools/wizard_parts/` (they also work from elsewhere). Don't use `python -I`
for them: it drops the script's own folder from the import path. Pillow prints `DeprecationWarning`s; ignore them.

**The one command:**

```
python tools/wizard_parts/rebuild_all.py              # everything, ~2.5 minutes
python tools/wizard_parts/rebuild_all.py hat weapon   # redraw + repack only those slots (the rest still runs)
                                                       # flags: --no-pack --no-aseprite --no-check
```

It does, in order (each step's command is printed):
1. `build.py` draws the sheets into `art_source/parts_sheets/` and writes `manifest.json` (multiprocess, ~1 minute).
2. On a full build, deletes sheets and packed files of variants that no longer exist.
3. Copies `manifest.json` to `art/parts/manifest.json` (the game reads that copy; `pack_parts.gd` doesn't copy it).
4. `tools/pack_parts.gd` (Godot headless) packs the sheets into `art/parts/*.parts`.
5. `make_test.py` composes the test character and the lineup **from the sheets** and writes the GIFs.
6. Copies the test character's sheet + config to `art_source/parts_sheets/reference/` (the game's check compares pixel for pixel).
7. `layered.lua` (Aseprite) writes `test_character.aseprite`, one layer per slot, every animation tagged.
8. `edge_check.py`.
9. `tests/checks/parts_check.tscn`, the game's own check (must say `parts_check: PASSED`).

**While working, don't rebuild; preview:**

```
cd tools/wizard_parts
python contact_sheet.py out.png swim,climb                     # all frames of these animations
python contact_sheet.py out.png group:casting                  # a group: movement, status, casting, polish
python contact_sheet.py out.png run hat=hood outfit=robe scale=2   # any option overrides; spell=Water for the magic color
python preview.py out.png "idle:0,cast:3" skin=deep hat=pointy "||" outfit=tunic weapon=wand   # rows of characters, chosen frames
python compare_ref.py out.png "idle:0,run:3,fall:0" box=80,40,200,138 zoom=3   # sample above, ours below
python edge_check.py
```

Open the PNG you wrote and **look at it** (zoom in: problems are 1-2 pixels). A contact sheet at scale 1 is too small to
judge details; crop and enlarge (`scale=2`, or `compare_ref.py ... zoom=6` on a small `box`).

---

## 3. How the output is organized (the mix-and-match model)

### 3.1 Frames and sheets
- One frame is **254 x 138**, like `art/chars/wizard`. The figure faces **right**; **feet on the bottom row (y = 137)**,
  centred at **x = 127**. Head-top about 86 px above the feet (the sample's height; `WizardLook` scale 1.0).
- A sheet holds **every frame of every animation**, in `ANIMS` order, left to right then down, **9 columns**. Today:
  46 animations, 236 frames, 2286 x 3726 px. Frame `k` is at `((k % 9) * 254, (k // 9) * 138)`.
- `manifest.json -> animations[name] = {start, count, fps, loop}`.
- **Every sheet of every slot is frame-aligned**, so a character is the sheets stacked.

### 3.2 Slots (the layers), options and variants
`parts.py SLOTS` lists the slots **back to front** with the options each depends on:

```
far_sleeve[color]  far_hand[skin]  far_leg[color]  back_coat[outfit,color]  torso[outfit,color]  near_leg[color]
front_coat[outfit,color]  belt[outfit,color]  hair_back[hair,hair_color]  head[skin]  beard[beard,beard_color]
hair_front[hair,hair_color]  hat[hat,hat_color]  weapon[weapon]  near_sleeve[color]  near_hand[skin]  magic[weapon]
```

- A **variant** is one value per dependency, joined by `-`: `torso/coat-blue.png`, `hair_back/long-auburn.png`,
  `weapon/wand.png`. `variant_key()` is the rule; the one exception: `hat` `none`/`circlet` ignore `hat_color` (`hat/circlet.png`).
- `build.py` renders every combination of a slot's dependencies, so a slot costs (product of its options' counts) sheets.
  **Keep dependencies minimal**: a slot that depended on 3 options of 6 values each would be 216 sheets.
- A combination that draws nothing writes no file (`hat/none`, `beard/none-*`, `back_coat/robe-*`...). The manifest's
  `variants` list holds exactly the files that exist; the game treats a missing one as "draws nothing".
- `OPTIONS` (in `parts.py`) lists every option's values. The game's `PartsLook.ORDER` and saved looks
  (`"parts:1:tan.coat.blue..."`) depend on these **names** and on the **order of the options**; see section 9.

### 3.3 Why the layer order is what it is
The far arm is behind everything; the near leg is in front of the torso but behind the front coat tail; the hat is over
the hair; **the weapon is under the near sleeve and the near hand** so the fist closes on the shaft; `magic` is last (the
gem sits at the weapon tip, clear of the body, and the game draws this layer as a separate sprite with a shader).

---

## 4. The rig: coordinates, the skeleton and the pose fields

### 4.1 Coordinates
- Pixel coordinates of the 254 x 138 frame, **y down**. `CX = 127` (feet centre), `GY = 137` (the ground row).
- A pose gives positions as **(x from CX, height above the ground)**; `wpt((x, h))` turns that into a pixel.
- **+x is forward** (the way the wizard faces). Angles are **degrees from straight down, + toward forward**
  for legs/arms; for the **staff and the torso, 0 = straight up, + = top tilted forward**.
- Light comes from the upper left (`LIGHT = (-0.55, -0.83)`), for every shape.

### 4.2 The skeleton (`parts.skeleton(p)` turns a pose into joint positions `g`)
- Pelvis `P = (CX + px, GY - ph - PH_ADJ)`; `PH_ADJ = 1.6`. **Standing `ph` is about 30.2.**
- `lean` tilts the torso (0 upright, + forward). `up` / `fwd` are the torso's unit vectors.
- `waist = P + 3 up`, `chest = P + 18.5 up` (the shoulders), `neck = chest + 3 up`, head centre `hc` 7 px further along
  the neck, tilted by `head` (degrees, + = bowed forward).
- **Legs by IK**: hip = `P - 1 up`; thigh and shin `LEG1 = LEG2 = 15.2`; the foot targets `fn` (near) and `ff` (far) are
  `(x, height of the sole)`; the ankle sits `FOOT = 5` above the sole. Knees bend forward (`lbend = -1`; +1 bends them back).
  A target out of reach gives a straight leg pointing at it (useful for extended legs).
- **Arms by IK**: upper arm and forearm `ARM1 = ARM2 = 11`, elbows bend back. Hand targets: `hn` / `hf` as world
  `(x, height)`, or `hn_rel` / `hf_rel` as an offset from that shoulder (pixels, y down), or, for the near hand, the
  staff's `hand` (below).
- `g` holds: `P, lean, up, fwd, waist, chest, neck, hc, sh_n, sh_f, hip, kn_n, an_n, kn_f, an_f, el_n, hn, el_f, hf, grip,
  hrot` (`_n` near, `_f` far; `an` ankle, `kn` knee, `el` elbow, `sh` shoulder; `grip` is the near hand target).
- `hrot`: how far the head's features turn (default `head * 0.6 + lean * 0.25`); set `head_rot` to turn the face, hat and
  hair with a body lying down (death, swim_dive).

### 4.3 Every pose field (`anims.default_pose()` + extensions)

| field | meaning |
|---|---|
| `px`, `ph` | pelvis x offset; pelvis height above the ground (standing 30.2, crouch ~22, kneel ~15, lying ~6) |
| `lean`, `head`, `head_rot` | torso tilt; head tilt; face/hat rotation override |
| `fn`, `ff` | near/far foot target `(x, sole height)` |
| `fn_ang`, `ff_ang` | foot pitch in degrees (+ = toes up, - = toes down; -70 for toes pointing down) |
| `lbend` | knee bend direction (-1 forward, default) |
| `hn`, `hf`, `hn_rel`, `hf_rel` | hand targets (world, or from the shoulder) |
| `hf_fist` | the free hand is a fist (else an open hand with fingers) |
| `hn_open` | the near hand is open even though a weapon is held (rare) |
| `staff` | the weapon, see below; `None` for none |
| `sway` | coat tails / robe hem pushed along x (- = streaming back, as when running) |
| `flap` | coat tail length scale (1 normal; <1 when billowing up or lying) |
| `beard`, `hat_tip` | beard / hat tip sway in pixels (- = back) |
| `flash` | white tint 0..1 for being hit (0.32 then 0.12) |
| `no_gem` | hide the gem (a fading body) |
| `xform` | transform the finished frame, the same for every layer: `dict(rot=deg, sx=, sy=, dx=, dy=, anchor=(x, h), alpha=, fade_magic=bool)`. Used for the knockback tumble (rot -90 per frame), sucked_in (spin, stretch, shrink, fade), vanish/appear/spawn (alpha), turn (sx). Nearest-neighbour, so pixels stay crisp. |
| `book`, `nobook`, `lying`, `fx` | old fields; book/nobook are unused (no accessories) |

**The weapon (`staff`)**, built with `S(ang, hand=(dx, dy), grip=...)` from `anims.py`:
- `ang`: 0 up, + top forward (`90` points straight ahead, `-60` up and back).
- `hand`: the near hand's offset from the near shoulder. The hand target IS the grip point.
- `grip`: how far up from the butt the hand holds a staff (`STAFF_GRIP = 0.66`, choked up). Wands and sceptres ignore it
  (`WEAPONS[...]["fixed"]`: wand 0.32, sceptre 0.36).
- `glow`: the gem's glow size (1 normal, 1.4-1.6 while casting).
- `base_at=(x, h)` instead of `ang`: the staff's butt is planted at that ground point and the shaft runs through the hand
  (`plant()` in `poses_extra.py`: dazed, gasping, cast_ground, getting up). A short weapon is simply held.
- `base=(x, h), top=(x, h)`: a dropped weapon lying at those points (death); the hands are then free (`hn`, `hf`).
- `weapon_line()` turns all this into butt, top and direction for any weapon length; `head_point()` gives the gem position
  (the anchor `tip` for effects).

### 4.4 Keyframes and loops
- `kf(i, [(frame, value), ...])` interpolates a value (number or tuple) between keyframes: write poses as a few keys.
- A **looping** animation must join up: drive it with `t = 2*pi*i/n` and `sin`/`cos` of `t` (or of `2t`), so frame `n`
  equals frame 0. Check the last and first frames side by side.
- **Keep feet planted** on the ground (`fn`/`ff` height 0) in grounded poses; the IK does the knees. Move the pelvis (`ph`,
  `px`, `lean`), not the feet, for breathing and bobbing.
- **Airborne poses** may lift the body inside the frame a little (`ph` ~ 38-45; the sample's fall sits ~12 px up), but the
  game positions the sprite by its feet, so don't move a body far from the bottom of the frame.

---

## 5. How parts are painted

### 5.1 Canvas, masks, shading (`rig.py`, `parts.PartCanvas`)
- Every layer is painted on its own `PartCanvas` (254 x 138 RGBA). Shapes are masks: `cv.capsule(a, b, r)` (a rounded line),
  `cv.ellipse(c, rx, ry, rot)`, `cv.poly(points)`, and `limb(points, radii)` (section 5.3). Each returns `(mask, s)` where
  `s` is a shading value from the light direction.
- `cv.paint((mask, s), ramp, hi=0.42, lo=-0.2, inner_outline=True, bias=0)` fills the mask with the ramp's **light**
  (`s > hi`), **mid** (`s > lo`) or **dark** tone. Raise `hi` for less highlight, lower `lo` for more shadow, `bias` shifts
  everything (ears use -0.35 to sit in shadow).
- A **ramp** is 4 colors light to dark: `ramp("#light", "#mid", "#dark", "#deepest")`. The 4th is only for edges and creases.
  Make ramps **hue-shifted** like the sample (shadows cooler/more saturated, lights warmer), not just darker.
- `inner_outline=True` darkens the new shape's border **where it overlaps something already painted in the same layer**.
  Use it to separate different things (a coat tail over a leg). **Set it False for anything that should read as the same
  piece** (trim on cloth, a cuff, the parts of one limb).
- `cv.dot(x, y, color)` sets one pixel (eyes, brows, buttons, star points).
- `cv.glow_disc(c, r, color, alpha)` adds a soft disc under everything, applied at the end (gems, effects).

### 5.2 After painting: `selout()` (no outlines)
`render_layer()` finishes every body layer with `selout()`: a pixel on the layer's edge takes the material's **dark tone on
the lit side** (top/left) and its **deepest tone on the shadow side** (bottom/right), but only where the shape is at least
3 px thick (thin things keep their color). That gives the sample's look: shapes defined by their own dark tones, no
outline ring. Hands and the magic layer skip it (their shading is drawn by hand).

### 5.3 `limb()`: one continuous shape
`limb([p0, p1, p2...], [r0, r1, r2...])` is a tapered polyline: every pixel takes its nearest segment, the radius blends
along the segment, and the shading is computed for the whole limb at once, so **no seam or tone jump at a joint**. Use it for
anything that bends: sleeves (`shoulder, elbow, hand`), trouser legs (`hip, knee, ankle`), the boot
(`calf, ankle, ball, toe` with radii `3.1, 3.0, 2.6, 1.9`), tails, tentacles, a scarf. Painting two capsules instead is
exactly the bug the owner rejected.

### 5.4 The body parts (functions in `parts.py`)
`sleeve`, `fist`, `open_hand`, `hand`, `leg`, `coat_flap`, `robe_skirt`, `tunic_skirt`, `torso`, `belt`, `head`, `beard`,
`hair_back`, `hair_front` (also the eyebrows: "no hair" still draws brows), `hat`, `weapon`, and `magic` (+ its `fx_*`).
`draw_slot()` maps each slot to its function. Head parts use `R = head_R(g)`: `R(dx, dy)` turns an offset from the head
centre (x forward, y down) into a pixel, rotating with `hrot`, so hats and hair follow a tilted or lying head.

### 5.5 Palettes
`SKINS`, `HAIRS` (4-tone ramps), `COLORS` (each: `main` cloth, `second` cloth, `legs` trousers, `trim`), `WOODS`, `LEAF`,
`LEATHER`, `SAPPHIRE`, `SILVER`, `GOLD`, `BOOT`. The option values are these dicts' keys, in insertion order.

---

## 6. The magic layer (gems and effects)

- Drawn **only** in the key grays `KEY = 236 (near-white), 190 (light), 128 (mid), 70 (deep)` plus pure white `255`, with
  alpha. Use `K[0..3]` and `WHITE` from `parts.py`; **never any other color in this layer**, or the game's shader will pick
  the wrong spell tone. The game turns them into the school's colors with `PartFrames.ramp()`:
  `[c.lerp(white, 0.75), c.lerp(white, 0.35), c, c * 0.5]`, where `c` is `SpellData.SCHOOL_COLORS[school]`.
  `parts.school_ramp()` is the same formula (used for the previews; `SCHOOL_COLORS` in `parts.py` is a copy of the game's,
  keep it in step if a school color changes).
- Effects are listed per frame in the pose's `extra["fx"]`: `[("name", dict(at="tip", ...)), ...]`. Anchors (`at`):
  `tip` (the gem; default), `base` (the weapon's butt), `hand` (free hand), `nhand` (weapon hand), `head`, `body` (chest),
  `feet`, `abs` (with `xy=(x, h)`); add `off=(dx, dy)` to nudge.
- Effects available: `ball` (glowing swirled sphere, `r`), `sparks` (`n, spread, seed, drift`), `wisps` (curling streaks,
  `n, reach, seed, fwd, drift`), `burst` (spiky flash, `r`), `ring` (shockwave ellipse, `rx, ry, thick`), `stars` (dizzy
  stars, `t, n, rx, ry`), `rise` (motes rising, `n, h, seed, t, w`), `trail` (the stroke behind the tip: `poses=[earlier poses]`),
  plus `beam`/`jet`/`blast` which **must not reach the frame edge** (rule 8; the current animations no longer use them).
- `idle`'s rising motes over the open hand come from `extra["motes"]`.
- Effects are **small and near the body**: a muzzle flash, sparks, a ring on the ground. The spell itself (projectile,
  beam, flame, storm) is the game's. Run `edge_check.py`.
- Non-spell effects in this layer (dazed stars, thaw shards, the clap ring) are recolored by the game too; chapter 19 says
  which ramp to give them.

---

## 7. Recipe: a new animation

Worked example: a looping "meditate" animation (kneeling, staff across the knees, motes rising).

1. **Write the pose function** in `poses_extra.py`, next to similar ones. Start from the nearest existing animation and
   change it. Use `P(...)` to start a pose, `S(...)` / `plant(...)` for the weapon, `kf()` for keys:
   ```python
   def meditate(i):  # (loop) kneeling, eyes down, staff across the knees, motes rising from the hands
       t = TAU * i / 6
       p = P(ph=15 + 0.4 * math.sin(t), lean=6 + 1.0 * math.sin(t), head=16, fn=(10, 0), ff=(-16, 2), ff_ang=-40,
             staff=S(80, hand=(10, 10), grip=0.5), sway=1, beard=0.5 * math.sin(t))
       p["hf_rel"] = (9, 12)          # open hand resting on the knee (no hf_fist)
       return p, dict(fx=[("rise", dict(at="hand", n=5, h=18, seed=1000 + i, t=i / 6, w=4))])
   ```
2. **Add it to `EXTRA`** (name, frames, fps, loop), **at the end of its group**, and add it to `GROUPS` if you want it in
   a group contact sheet. **Only ever append** to the overall order: inserting shifts the frame index of every later
   animation in every sheet (harmless for the game, which reads the manifest, but it churns every file).
   `("meditate", 6, meditate, 6, True),`
3. **Preview it** (no build): `python contact_sheet.py out.png meditate scale=2`, and with other looks:
   `python contact_sheet.py out.png meditate outfit=robe hat=hood weapon=wand`. Look at every frame. Check:
   feet on the ground, no limb seams, the loop joins (last frame next to first), the weapon in the fist, nothing crosses
   the face, the hat and hair follow the head, the robe doesn't cover a raised knee oddly, effects small.
4. **Try it on every outfit, hat and weapon**: robe vs coat vs tunic and wand vs staff behave differently. A pose that only
   works for one look is wrong. (`preview.py` with several `||` groups puts them in rows.)
5. `python edge_check.py`.
6. `python rebuild_all.py`. Then open `art_source/wizard_parts_preview/gifs/meditate.gif` (and `all_animations.gif`) and
   look at it moving.
7. **The game side** (chapter 19, section 7): `parts_check.gd` counts the animations (`== 46` today: update it), the
   trigger in `wizard.gd _animate()`, `PartFrames.CORE`/`FAMILIAR` if it should be ready when dressed, the fallback for the
   old looks that don't have it, and `shown_anim` over the network.
8. Show the owner the GIF.

**Tips for good poses** (what fixed the owner's complaints):
- Study the sample's frames for the same action: `python compare_ref.py out.png "run:2,fall:0"` and copy the *motion*:
  how far the legs split, where the hands go, how much the body leans.
- Big, clear key poses read better than small moves. The first run was rejected as "stiff": the fix was long strides
  (feet from x +20 to -27), a knee lifted high, 16-22 degrees of lean, body bob of 3 px, coat tails streaming back
  (`sway` -7 to -10), arms pumping (`hf_rel` swinging with `cos`).
- Overlapping action: let the coat (`sway`), beard (`beard`) and hat tip (`hat_tip`) lag the body by a phase
  (`sin(t - 0.6)`).
- Keep the staff off the face: watch `hand` and `ang` so the shaft doesn't cross the head.

---

## 8. Recipes: new parts

### 8.1 A new color (outfit/hat), hair color or skin
Add an entry to `COLORS` (`main`, `second`, `legs`, `trim` ramps), `HAIRS` or `SKINS` in `parts.py`. It joins `OPTIONS`
automatically (they are built from the dict keys). Make the ramp hue-shifted and check it against the others in
`preview.py` rows. Then `rebuild_all.py` (all slots that depend on it rebuild). A new color multiplies the sheets of every
slot that depends on `color`: check the sheet count printed by `build.py`, and update `parts_check.gd`'s `files == 203`.

### 8.2 A new hat, hair style or beard
1. Add the value to the option's list in `OPTIONS` (append; `none` stays first).
2. Add a branch in `hat()` / `hair_back()` + `hair_front()` / `beard()`. Draw with `R(dx, dy)` head-local points so it
   tilts and lies down with the head. Hats: `bcx, bcy = -0.9, -5.9` is the brim centre; see `pointy` and `wide` for the
   cone, `hood` for a shape with a face opening, `circlet` for a band.
3. If it should hide something (a hood over hair), remember the layers: `hair_back` is behind the head and `hat` is above
   `hair_front`; draw the cover in the later layer.
4. If a value draws nothing in a slot, return without painting: no file is written and the manifest knows.
   Update `parts_check.gd`'s list of allowed gaps for a new empty case.
5. Preview it on a standing, running, lying (`death:6`), swimming-down (`swim_dive:0`) and tumbling (`knockback:1`) frame.
6. `rebuild_all.py hat` (or the slots you changed).

### 8.3 A new outfit
Add to `OPTIONS["outfit"]` and give it a branch in `torso()`, `belt()`, the `front_coat` / `back_coat` dispatch in
`draw_slot()` (see `coat_flap`, `robe_skirt`, `tunic_skirt`). A long skirt must follow the legs (`robe_skirt` spans
both ankles and has a lying-down case). Check run, swim, climb, knockback and death.

### 8.4 A new weapon
1. `OPTIONS["weapon"]` and `WEAPONS[name] = dict(L=length, grip=..., fixed=True for short ones)`.
2. A branch in `weapon()` (the shaft and head, **no gem**; the gem goes in the magic layer).
3. `head_point()`: where its gem sits. `magic()`: the gem's radius (and shape: round or `crystal`).
4. Check that the fist sits right on it in idle, run, cast, release, climb (held alongside the vine), dazed (planted),
   death (dropped).
5. `rebuild_all.py weapon magic`.

### 8.5 A new slot (rare)
Add it to `SLOTS` at the right depth, add its drawing to `draw_slot()`, and expect game-side work: `PartFrames` stacks
whatever the manifest lists, but `parts_check.gd` counts files and `PartsLook` may need a new option.

---

## 9. Changing options safely (saved looks and the network)

A player's look is saved and sent as `"parts:3:" + values in PartsLook.ORDER` (older "parts:1:" and "parts:2:" looks are still read: see chapter 19) (`scripts/wizard/parts_look.gd`).
- **Adding a value** to an option is safe.
- **Renaming or removing a value** breaks every saved look using it (`PartsLook.decode` rejects it and the game falls back).
  Don't, or map the old name in `PartsLook.decode`.
- **Adding a new option** changes the format: add it to `OPTIONS` (anywhere), to `PartsLook.ORDER` at the END, give it a
  default in `PartsLook.DEFAULT`, bump the prefix to `parts:2:` and make `decode` accept `parts:1:` strings with the
  default filled in.
- The default look is the test character (`make_test.py TEST` = `PartsLook.DEFAULT`). If you change one, change both, and
  never make it resemble the sample wizard (rule 1).

---

## 10. Checking your work (definition of done)

1. Contact sheets of what you changed, on several looks, **looked at zoomed in**.
2. `compare_ref.py` against the sample for style (size, shading, proportions).
3. `edge_check.py` passes.
4. `rebuild_all.py` ends with `parts_check: PASSED` (update its counts if you added files/animations).
5. The GIFs in `art_source/wizard_parts_preview/gifs/` play right: loops join, one-shots end cleanly.
6. Show the owner the GIFs (`all_animations.gif`, the changed animation's GIF, `lineup_mix_and_match.gif`).
7. `python tools/run_checks.py` (the game's quick set) if you touched any game code.

---

## 11. Pitfalls already met

- **Two shapes for one limb** read as separate components with a seam: use `limb()` (rule 3).
- **`inner_outline=True` between parts of the same thing** draws a dark line inside it.
- **A dark outline ring** looks cartoony; the sample has none (rule 2). `selout()` is the replacement.
- **Copying the sample's palette or look** (rule 1). The purple outfit was once the sample's exact colors; it was changed.
- **Effects past the frame edge** (rule 8).
- **The magic layer in any color but the key grays** breaks the recolor; and the sheets must stay lossless PNG.
- **Moving the feet to animate breathing**: move the pelvis instead.
- **Hands as round blobs**: use `fist()` / `open_hand()`; set `hf_fist` in the pose when the free hand should be closed.
- **A pose tuned on one look only**: robe skirts, wide hats and wands each break different poses.
- **`python -I`** hides the tool folder from imports (the tools then fail to import `rig`).
- **Building is multiprocess**: on Windows the code that runs must stay under `if __name__ == "__main__":`.
- **Forgetting the downstream steps** (manifest copy, packing, the reference sheet): just run `rebuild_all.py`.
- **Stale files**: a removed variant leaves its old sheet; `rebuild_all.py` (full) deletes them.


---

## Jungle props

The great tree, the vines, the flytrap, the piranha and the bramble are drawn by the same rig: `python tools/wizard_parts/props.py [tree vine piranha flytrap bramble]`. Never edit their PNGs by hand. The tree's boughs must stay where `JungleTree.LEDGES` puts its ledges (each has a moss strip on top, and no leaves are drawn over it). Editable `.aseprite` copies of an earlier draw are in `art_source/props/aseprite/`.

The same `props.py` draws the marble stairs under the spellbook (`python tools/wizard_parts/props.py podium` -> `art/tiles/podium_marble.png`, laid out as `Podium` lays its columns), the nine world-colored trees (`great_oak_<biome>.png`; the Great Oak spell picks by `ArenaGen.biome_name_at`, and the waiting room uses the portal fields' colors) and the flytrap's eight frames (three waiting, three lunging, two spitting; `Flytrap` swallows whoever steps on it and spits them out, `tests/checks/flytrap_check.tscn`).
