# Project Handoff: Wizard Arena Roguelite (Working Title: "Spellcraft")

## 1. Core Concept

A 2D side-view (Terraria-style) arena roguelite where spellcasting is performed through real input (gestures, key holds, typed incantations) rather than menu/cooldown selection. The player is meant to feel like they *actually know magic* — mastery comes from the player's real skill (muscle memory, memorized incantations, typing speed/accuracy), not from stat progression alone.

**Engine**: Godot 4.x
**Perspective**: 2D side-view, Terraria-style (camera follows player, no camera rotation)
**Genre**: Arena roguelite, wave-based combat

---

## 2. Build Priority (READ FIRST)

Build in this order. Do not proceed to a phase until the previous one is validated as *fun*, since the entire game hinges on the casting loop feeling good.

1. **Phase 0 — Gesture/input prototype (no art, no mobs, no arena).** Prove the casting detection systems work and feel responsive.
2. **Phase 1 — Single hand-built arena + 2-3 fast spells + 1 mob type.** Validate core combat loop.
3. **Phase 2 — Add stamina, ritual casting, 1-2 rituals.** Validate the tempo-shift between fast/ritual casting.
4. **Phase 3 — Add debuff mobs (mute/blind/root), item system, drop/pickup.** Validate toolkit-attacking mob design.
5. **Phase 4 — Modular arena chunks, wave/run structure, roguelite meta-loop.**
6. **Phase 5 — Content expansion** (more spells, mobs, foci, rituals, polish).

Do not build procedural arena generation, itemization breadth, or content volume before Phase 1 is confirmed fun. This is the single biggest risk-mitigation instruction in this document.

---

## 3. Core Systems Spec

### 3.1 Casting Tiers

**Fast Spells** (real-time combat casting)
- Input: hold a modifier/school key + draw a mouse gesture, release to resolve.
- Sub-second to ~2 second cast time.
- Detected via gesture recognition (see 3.2) + key-state matching.

**Ritual Spells** (high-power, vulnerable casting)
- Input: type a full incantation (pseudo-Latin, 2-3 sentences) in a text-input mode.
- Player is stationary/vulnerable while typing.
- **Interruptible**: taking damage while typing cancels the ritual (partial credit optional — see Open Questions).
- No hard requirement to "unlock" — any ritual can be cast from a blank input if the player has memorized it. Spellbook pages are an optional on-screen reference/aid only, never a gate. Pages are not consumed on use.
- Typing accuracy/speed scales effect power; large errors can cause misfire/backfire; minor typos degrade rather than fail outright.

**Foci** (equipped items, one at a time)
- Wand: baseline, forgiving gesture tolerance, lower power ceiling.
- Staff: tighter gesture tolerance required, higher power/area.
- Crystal ball: scrying tool (preview next wave composition), not primarily a damage focus.
- Broom / Magic carpet: mobility items, not casting foci — broom = fast but imprecise gesture tolerance while airborne, carpet = slower/stable, allows casting while moving.
- Only one focus held at a time. Items can be dropped and picked up later; not stealable by mobs.
- Player can mark locations with a small gesture-cast rune/glyph (diegetic waypoint) to remember drop locations.
- "Accio" pull: fast-travels an item to the player; stamina cost and travel time scale with distance/path obstruction.

### 3.2 Gesture Recognition

Use the **$1 Unistroke Recognizer** algorithm (well documented, lightweight, no ML dependency):
1. Capture mouse-delta points while a cast key/button is held (array of points + timestamps), recorded **relative to the cursor position at the moment the cast began** (that starting position is the gesture's local origin, not absolute screen space).
2. Resample to N evenly spaced points.
3. Rotate to normalize indicative angle (note: normalization happens for *shape matching* only — see 3.3 for how raw angle is separately used for aim on directional spells).
4. Scale to reference bounding box, translate centroid to origin.
5. Compare against stored template gestures via distance scoring (golden section search for optimal rotation alignment).
6. Best match under a threshold = recognized spell. Below threshold = misfire (define misfire consequence — see Open Questions).

Gesture tolerance is a *tunable parameter per focus item* (wand = loose threshold, staff = tight threshold).

### 3.3 Aiming: Gesture-Relative, No Auto-Target (replaces old first-person camera-lock section)

The 2D side-view perspective removes the camera-vs-gesture input conflict that plagues first-person gesture-casting games (e.g. Arx Fatalis, where gesture-mode hijacking the mouse made it very hard to do anything else mid-combat, like avoid enemies). In 2D, the mouse never controls camera rotation, so this problem doesn't need a workaround — it structurally doesn't exist.

Aiming rules:
- Cursor position doubles as aim reticle and gesture-drawing origin. On cast-key press, the current cursor position is locked as the gesture's local (0,0).
- **No auto-targeting.** The player must manually aim; missing is a valid, expected outcome and should feel like a fair skill failure, not a system failure.
- Aiming and gesturing are **one continuous action**: move cursor to desired position, press, draw shape, release. No separate aim-mode/cast-mode split.
- Each spell definition needs a **targeting type** flag:
  - `directional` — spell fires along the gesture's raw indicative angle/end-vector (e.g. Ignite, Frostbolt, Spark). Use the *unrotated* stroke angle for this, captured before/alongside the shape-normalization step in 3.2.
  - `positional` — spell effect centers on the cursor's starting position or on the player (e.g. Cinderburst, Barrier, Firewall). No directional aim needed.
- A successfully-recognized gesture should always resolve as "spell cast" (stamina spent, projectile/effect fired) even if it misses its target — distinct from a failed/misfired gesture (wrong shape, not recognized). Keep these two failure modes visually and mechanically distinct so players can tell "I drew it wrong" from "I aimed it wrong."

### 3.4 Stamina System (no mana)

- Fast spells cost a small, quickly-regenerating stamina amount.
- Rituals cost a large stamina chunk and/or are gated primarily by time-exposure risk rather than stamina.
- Sloppy/failed gestures cost extra stamina as a "wasted effort" penalty.
- Accio cost scales with distance/obstruction.
- No hard mana pool — stamina should feel like physical exertion (matches Harry Potter/Doctor Strange tonal reference used in design), regenerates over a few seconds of not casting.

### 3.5 Mob Design Philosophy

Mobs should attack the player's *input channels*, not just health. This is the core differentiator of the enemy design — do not default to simple damage/HP variation. Categories:
- **Input-channel debuffs**: mute (blocks ritual typing), root/freeze (blocks movement), tremor (tightens gesture threshold).
- **Sense debuffs**: blind/darkness (hides gesture trail — this should visually remove the on-screen stroke trail, forcing the player to rely on real muscle memory), confusion (rotates/mirrors gesture input before recognition).
- **Elemental weakness/resistance**: standard type-effectiveness lookup table (ice-weak, fire-weak, etc.)
- **Summoner mobs**: cast their own telegraphed "rituals" that the player can interrupt (counterspell mechanic — symmetric with player vulnerability).
- **Mimic mobs**: copy the player's last-cast spell back at them, discouraging spam.

Each debuff should force a *different valid strategy*, not just "play worse." Validate this explicitly during playtesting per mob type.

### 3.6 Environmental Residue

Arena terrain should retain effects from casting: scorched ground, frozen/slippery patches, lingering silence zones from dead mute-mobs. Spells can interact with residue (e.g., shatter frozen ground, ignite scorched terrain). Treat this as a tile/area-state system tied to the arena geometry, not just a VFX layer.

### 3.7 Arena Generation

Build **one hand-authored arena first** (Phase 1). Do not build procedural generation until the core loop is validated. When ready (Phase 4):
- Use modular chunk-based assembly (pre-authored pillar clusters, cover, hazard zones, item nooks), randomly placed/rotated within a fixed boundary — not full algorithmic dungeon generation.
- Chunks must guarantee open space for gesture-casting near likely player positions (avoid claustrophobic spawns — this is a playability requirement unique to gesture-based combat).
- Tag chunks by purpose (cover, open, hazard, item-nook) and weight selection based on upcoming wave composition.

---

## 4. Content Lists (starter set, expand in Phase 5)

### Fast Spells
| Spell | School | Gesture | Targeting | Effect |
|---|---|---|---|---|
| Ignite | Fire | Forward flick | Directional | Low-damage bolt |
| Firewall | Fire | Horizontal slash | Positional | Damage wall, blocks projectiles |
| Cinderburst | Fire | Tight circle | Positional | AoE burst, high stamina |
| Frostbolt | Ice | Forward flick (diff. key) | Directional | Slow + damage |
| Glacial Wall | Ice | Horizontal slash | Positional | Blocking wall (no damage) |
| Rime Step | Ice | Backward flick | Positional | Self-slow-immunity, leaves frozen terrain |
| Push | Force | Flick toward target | Directional | Knockback |
| Pull | Force | Flick toward self | Directional | Yanks mob/item toward player |
| Barrier | Force | Held arc | Positional | Brief shield, interruptible |
| Spark | Lightning | Fast zigzag | Directional | Chip damage, short window |
| Chain Jolt | Lightning | Held zigzag | Directional | Multi-target, riskier exposure |
| Blind | Shadow | CCW circle | Directional (aimed at target) | Obscures enemy tracking |
| Silence | Shadow | X gesture | Directional (aimed at target) | Interrupts enemy ritual cast |

Note the deliberate mirroring: fire/ice pairs share the same gesture on different keys — reduces authoring load and improves onboarding since learned muscle memory transfers across schools.

### Ritual Spells (typed incantations, pseudo-Latin, 2-3 sentences)
- *Conjuration of the Undying Blaze* — persistent spreading fire hazard
- *Rite of Cinder-Sight* — reveals enemy elemental weaknesses for the wave
- *The Long Winter's Ward* — full-arena freeze/CC, affects player too if mistimed
- *Litany of Frozen Breath* — self-buff, fast spells gain frost effects
- *Summoning of the Bound Servant* — raises undead ally from nearby corpse (spatial requirement)
- *Rite of the Hollow Curse* — marks enemy for amplified damage
- *Words of Unmaking* — dispels all battlefield residue/hazards
- *Chant of the Second Wind* — stamina/health restore, safe baseline ritual
- *Scrying of What Comes* — preview next wave (alternative to crystal-ball item version)
- *Ward of True Sight* — removes blind/darkness debuffs for the wave

---

## 5. Open Design Questions (resolve during prototyping, not before)

- Misfire consequence for failed gestures: damage to self? wasted stamina only? random weak effect?
- Ritual interrupt behavior: full cancel vs. partial/"burnt" effect on damage taken mid-cast (design leans toward full interrupt per earlier decision, but confirm feel in playtesting).
- For `directional` spells aimed at a specific enemy (Blind, Silence) vs. free-aimed projectiles (Ignite, Spark) — do these need a "close enough" angular tolerance to hit an intended target, or is precision aiming always fully manual with no assist?
- Scrying cost: free info vs. costs time/stamina/only partial wave info.
- Grimoire (worn item) as an exception to the one-focus rule — deferred, not required for MVP.

---

## 6. Explicit Non-Goals for MVP

- No full procedural dungeon generation (BSP/cellular automata) — chunk-based only, and only after Phase 1-3 validated.
- No multiplayer/dueling mode (mentioned early in design discussion, not in current scope).
- No large itemization breadth (rings/amulets/cursed items/familiars) until Phase 5.
- No first-person camera/3D — 2D side-view (Terraria-style) only per current decision. This choice structurally avoids the camera-vs-gesture input conflict that affects first-person gesture-casting games.
