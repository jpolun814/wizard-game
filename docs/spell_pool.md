# Spell pool (draft)

Status: **all 33 spells are built** and can be tried in the waiting room (`scenes/lab.tscn`). Not built yet: stamina
ranges (every spell still costs one number, the midpoint of the range below), mastery, gate tags, the dark wizard casting
from the pool, and real art for several spells (see "Placeholders"). Part of `roguelite_exploration_design.md`.

## Schools and buttons

Six schools in the style of the four elements, plus Shadow and Flora. One button combination per school, so a
shape only has to be distinct within its own school.

| Buttons | School | Colour | Identity |
|---|---|---|---|
| Left | Fire | orange `#ff6a2a` | burning, heat, lightning, light and smoke |
| Right | Water | cyan `#7fd8ff` | ice, slowing, dousing, floods |
| Middle | Air | pale silver | pushing, deflecting, shields, wind |
| Left + Right | Earth | brown `#b8864a` | stone, ground, weight, terrain |
| Left + Middle | Flora | green | growing, trapping, climbing (all flammable) |
| Right + Middle | Shadow | purple `#7a5aa0` | sight, decoys, curses, gravity |
| Left + Right + Middle | (open) | | |

Spark stays lightning-yellow even though it is a Fire spell. Healing is a ritual, never a spell.

Wind Wall (the old Force Wall) is merged into Gust.

Changes from today: Earth moves from Left + Middle to Left + Right. Ice becomes Water. Force becomes Air.
Storm is gone: Spark joins Fire, Tornado and Blink go to Air and Shadow, Storm Cloud is cut.

## The pool (33 spells)

Stamina is a range: a clean, quick cast pays the low number and a sloppy or slow one the high number. Mastery
lowers the whole window (see the main design doc). All numbers are provisional.

### Fire (Left)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Ignite | straight flick, any angle but vertical | a thrown fireball | dodge, Barrier, Gust | burn growth | 8-16 |
| Firewall | vertical line | a wall of flame; passable but burns | walk round | burn growth | 10-22 |
| Fire Breath | cone, `<` | a flamethrower | stone and ice stop it, Barrier | burn growth | 9-18 |
| Smoke Screen | wavy line, rising | smoke that hides you from sight | Gust or Tornado clears it | conceal | 12-24 |
| Flare | teardrop flame, point up | a small harmless flame that hovers in front of you and follows, lighting dark places | water and wind put it out; double-click it | light darkness | 6-12 |
| Spark | tall zigzag going down | a lightning bolt from the sky | shelter under a platform or stone | damage | 6-14 |

### Water (Right)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Frostbolt | straight flick | a bolt of cold; slows | dodge, Barrier | | 8-16 |
| Icicles | one or more Vs, one per V, under a ceiling | icicles hanging from a ceiling | fire melts them | block path | 8-16 each |
| Ice Prison | circle drawn round the target | freezes foes solid | Push or Earth shatters them | | 8-18 |
| Blizzard | five-point star in one stroke, then a horizontal line | snowfall over the line | fire melts it | slow | 12-26 |
| Frost Bridge | wavy line across water | freezing a pond | fire melts it | freeze water, cross gap | 12-24 |
| Geyser | mountain: a triangle with a line up its middle (the Volcano's shape, on the water button) | a water jet that launches what stands on it | step off | reach height | 14-26 |

### Air (Middle)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Push | circle, then a line out of it | a blast moving everything inside, heavy foes included; the only spell that lifts you | anchor, Stone Wall | push, reach height | 6-14 |
| Barrier | circle round yourself | a shell of air that negates projectiles (nothing else) | it ends after 6 seconds | | 20-40 |
| Tornado | tall narrow coil going down, like a drill bit | a funnel that swirls foes | step away | | 18-34 |
| Gust | any swoosh or flick; the stroke is the wind's direction | wind that blows light things along the stroke: shots (this replaces Wind Wall), flyers, smoke, spores, and you sideways. It cannot lift you; only Push does | heavy foes resist | cross gap | 8-18 |

### Earth (Left + Right)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Stonefall | circle, then a line down from its top | a boulder dropped on a spot | watch the warning | break stone | 14-30 |
| Stone Wall | straight stroke that starts on solid ground | a solid wall | broken by Earthquake, Stonefall and lava, not by Push | block path | 15-36 |
| Mudslide | U | ground turned to mud; slows, stops jumping | flyers pass over | | 20-44 |
| Earthquake | three peaks | the ground shakes | flyers unaffected | break stone | 45-85 |
| Volcano | upward triangle (a mountain) | lava erupts and sets ground on fire | (nothing yet) | burn, damage | 30-58 |

### Flora (Left + Middle)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Bramble | low sawtooth row of thorns | a thicket that slows to a crawl and pricks with every step | fire | block path | 14-28 |
| Spore Puff | cone, `<` (as Fire Breath, on the Flora buttons) | poison spores poured from your mouth that drift and linger | Gust clears it | | 14-26 |
| Liana | leaf and line: an almond on its point, then a line up from it | a vine that grows to a ledge or ceiling; climb it, or ride it across a gap | fire burns it | reach height, cross gap | 12-24 |
| Great Oak | tall trunk drawn up, ending in a big round crown | branches you can stand on; a wall until broken; then it falls ("Timber!") and crushes everything beneath it, you included | fire, Earthquake, Stonefall; it creaks and leans before it falls | reach height, block path | 45-60 |
| Flytrap | open jaws, a tall narrow W | a trap: waits up to a minute, snaps on whatever steps in | jump or fly over, burn it | trap | 18-34 |
| Lily Pads | a row of flat ovals | floating leaves that carry you across water or a pit, then sink | lava burns them | cross gap | 12-24 |

### Shadow (Right + Middle)

| Spell | Shape | Pictures | Counter | Tags | Stamina |
|---|---|---|---|---|---|
| Decoy | figure-eight | a dummy enemies notice instead of you | it takes hits and vanishes | bypass guards | 14-28 |
| Eclipse | crescent moon | darkness that shrinks enemies' sight in an area | Flare cuts through it | bypass guards | 16-30 |
| Hex | pentagram: a five-pointed star in one stroke | the marked foe takes extra damage from every spell | short time | | 14-26 |
| Abyss | inward spiral, wide to narrow (the old Gravity Well) | a dark knot that pulls everything in and swallows shots | step away | | 18-34 |
| Shadow Step | straight flick (the old Blink) | you vanish and surface along the stroke, up to 300 px | stops short of walls | cross gap | 4-12 |

## Gate tags and who can answer them

- **cross gap:** Frost Bridge, Gust, Liana, Lily Pads, Shadow Step
- **reach height:** Push, Geyser, Liana, Great Oak
- **break stone:** Stonefall, Earthquake
- **burn growth:** Ignite, Firewall, Fire Breath (and Volcano's fire)
- **freeze water:** Frost Bridge
- **light darkness:** Flare
- **bypass guards:** Decoy, Eclipse, Smoke Screen (conceal)
- **block path:** Stone Wall, Icicles, Bramble, Great Oak

## Physical interactions

- Fire burns every Flora spell, and Bramble, Great Oak, Liana and Flytrap are all gates a fire spell can open.
- Fire melts Icicles, Blizzard and Frost Bridge.
- Great Oak, Flytrap and Stonefall hurt anyone beneath them. Spells have no teams.

## Placeholders

These work, but their pictures are stand-ins for pixel art from a free pack, which the owner's art rules ask for:

- **Pond (water and lava), Geyser column:** shapes drawn in code. The Geyser
  now carries real splash sprites (DevWizard) for their foam; the water bodies are still code.
- **Great Oak:** done, a living tree from GothicVania Bridge (ansimuz). **Bramble, Flytrap:** bushes and ferns (the Flytrap is
  tinted red). **Lily Pads:** the swamp vine laid flat. **Barrier:** the old force bubble, now a faint pale ball with a twirl texture turning round it. **Liana:** the swamp vine hung upright.
- **Smoke Screen, Spore Puff, Eclipse:** Kenney soft smoke particles.
- **Sounds:** none of the new spells has a sound of its own; they borrow the nearest existing one (`push`, `quake`, `earth`,
  `snow`, `gravity`, `freeze`, `fire_hit`). Water has no sound at all.

## Shape risks (all tested at three sizes, tilted, stretched and shaky: `tests/test_gestures.gd`)

- Water: Geyser (a closed triangle with a vent line) against Icicles (open Vs). Icicles also need a ceiling overhead, so the lab has a slab for them.
- Flora: Liana (an almond, then a line up) against Great Oak (a trunk ending in a crown loop): separated by which comes first, the loop or the line. Also Flytrap (W) against Bramble (sawtooth): separate by count of peaks.
- Shadow: Hex (a star that winds inward) against Abyss (spiral): a star is ruled out of the spiral detector first.
- Air: Tornado (a tall coil) against Abyss (a spiral): the coil goes down and is narrow, the spiral winds inward.

## Not decided

- The starter kit: one attack, one defence, one way to reposition. Suggestion: Ignite or Frostbolt, Barrier,
  Push.
- Whether Air needs more spells (it has 5 and no damage).
- The boss's choice of spells from his stash.
- How loud each spell is, if noise is used.
- Whether Growth (a cheap vine ladder) comes back, if Liana and Great Oak are not enough.

## Cut
- **Tsunami** (2026-10-25): cut for now. Its gesture recognizer (`_big_wave`) is still in the caster, unused.
