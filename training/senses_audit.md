# Senses audit (2026-11-11)

The rule: an AI wizard knows what a person in its place could see on their screen, and no more. This lists what a person's screen shows and
whether the trained networks' senses (`scripts/sensing.gd`, 236 numbers; `TacticsBrain.observe` adds 44) carry it.
The scripted brain reads most of these straight from the world, so it copes; the gap is in what the networks are given.

Key: **yes** in the senses, **part** in them but thinly, **no** missing, **over** the senses know more than a person could.

## The wizard itself

| On screen | Senses | Notes |
|---|---|---|
| Stamina and maximum stamina (HUD bar) | yes | |
| Unlimited stamina (bar turns pale blue, Vires Fluant) | no | `infinite_time` |
| Breath (bubbles over the head, one a second; red when out) | **no** | `breath`, `deep_breath_time`, `holding_breath()` |
| In water / lava / mud, and how deep | **no** | `underwater()`, `_liquid_y`, `_in_lava` |
| Moving, on the ground, facing | yes | |
| Air jump ready | yes | only the flag; the Skystep time left is not |
| Slowed, sunk in mud, tangled in thorns, rooted, frozen, dazed, fainted, muted | no | a person sees each on their own wizard and feels it in the keys |
| Barrier, Crimson Veil, Obsidian Armor, Sneak, haste, Adrenaline, Featherfall, Rocket Jump, Tide Surf | no | visible on the body; a person knows what they cast |
| Hex star, Hunter's Mark, Fight or Flight, Moonbeam on oneself | no | drawn marks (`tests/marks_look.tscn`) |
| Hanging on a vine, in wolf shape, carried by the portal | no / no / no | `wild` is sensed for rivals but not for oneself |
| Leech tether on oneself | no | drawn as a line |
| Own pages (the book) | part | the tactics brain gets "attack ready" for 38 attacks; the leg network gets nothing; utility spells and chants are not listed |

## The ground

| On screen | Senses | Notes |
|---|---|---|
| Solid ground and wooden platforms | **part** | an 11 x 9 tile box (352 x 288 px) round the feet; the screen is about 853 x 480 px, so most of what a person sees of the ground is left out |
| Water, lava, mud as liquids | **no** | only "lethal" (molten lava) is marked; water is open air to the network |
| Piranha water | yes | as lethal |
| Thorns | **over** | marked lethal only when the wizard has no fire: what it knows of its book leaks into what it "sees" |
| Ice sheets (slippery) | no | group `slick` |
| Vines and Lianas (climbable) | no | group `climbables` |
| Swinging stairs, lily pads (moving or sinking footing) | part | seen only as they are this instant, with no motion |
| Updrafts, the peaks' wind (streaks), Tide Surf waves | no | groups `updrafts`, `drifts`; `Wizard.wind` |
| Breakable walls (Stone Wall, brick) | part | seen as solid, not as breakable |
| Ground in the dark | **over** | the box is read whether or not the tiles are lit |
| Portals (portal world, the collapse portal) | no | groups `field_portals`, `portals` |
| Minimap (after the Rite of the Land) | no | |

## Others

| On screen | Senses | Notes |
|---|---|---|
| Rivals: where, drawing or not, wolf or not | yes | two nearest |
| A rival's stroke as it is drawn (a person can read which spell is coming) | no | `shown_stroke`; only "drawing yes/no" |
| A rival's chant typed over their head | no | `shown_words` |
| A rival's facing, motion, and what is on them (Barrier, frozen, Hex, Sneak shimmer, fainted) | no | |
| Creatures: where | yes | four nearest threats, creatures marked 1 |
| Creatures: what kind (skeleton, knight, giant, eye) and whose skeleton | no | |
| Spells and fires in the world: where | part | a point and "0.5"; not what it is, how big, or which way a shot is flying |
| Shots in flight: direction and speed | **no** | a person sees motion; the network sees one still frame (no memory, no velocity) |
| Smoke, clouds, gas, Silence rings, Black Hole pull, a dying star | part | only as a point among the four threats |
| Pages: where | yes | three nearest |
| Decoys and Mirages | yes (as they fool a person) | handled by `Eyes` |

## What a person hears

Sound carries what is off screen (a volcano waking, a cast nearby, a rival's steps). The senses have none of it. The game must never rely on sound
alone (CLAUDE.md, section 0), so this is the lowest priority, but it is a real difference.

## Biggest gaps, in order

1. **Liquids and breath**: water, lava and mud are not told apart from air; breath is not sensed. Any water world is blind to the network.
2. **The ground box is too small**: about a third of the screen a person sees.
3. **No motion**: shots and moving footing are still frames.
4. **What is on the wizard**: none of its own conditions or active spells.
5. **What a thing is**: threats are points with no kind, size or extent.
6. **Two leaks the other way**: thorns marked by what the book holds, and ground sensed in the dark.

## What the second layout (scripts/senses.gd, 2026-11-11) covers

Everything in the tables above except what is listed under "Still missing", and memory, which a person has and a network does not:
the ground seen (remembered tile by tile, per world), pages seen and not seen taken, and where each rival was last seen. All things and rivals on the
screen (24 and 7), creatures by what they are like (melee, ranged, flying, how strong), moving footing (swinging stairs, lily pads) with its motion, the
whole book (spells and chants, and which chants hold), the minimap after the Rite of the Land, rivals' and creatures' stamina under Insight, the Scrying
Eye's window (who it shows and the ground round them, not where). Tested by tests/senses_check.tscn. A look costs about 4 ms.

## Still missing (checked again, 2026-11-11, layout 3)

Added in layout 3: each book page's cost and damage lines; the words the screen shows (Misfire, Too tired, Too weak, Aim at someone, Aim under a
ceiling, the spell's name when it goes off, Perfect, Interrupted, Negated, Dazed, damage numbers over wizards and creatures); which spell a thing in
the world is; which creature; which wizard a rival is (figure and colours); the chant a rival is typing, once its words say which; the school colour
of a page on the ground. Also a fairness fix found on the way: a brain's misfire now costs stamina as a person's does (`Arena.misfire_by`).

Still not sensed:
- The chant box's lines on the HUD ("Check the words and try again", "Wait for your voice to return"): needed once the AI says chants.
- "Nothing to freeze" (Frost Bridge), "Too heavy" (Thorn Whip), "Immune" (Ice Prison), "Resisted" over a creature: rare outcome words.
- More than the 24 nearest things and 3 nearest pages on a crowded screen.
- Sound.
- training/clone_human.py does not read the recording's `V` lines yet.

## Note before changing the layout

`ai/footwork.json` (the trained legs every AI wizard walks with by default) and `training/human_policy.json` take the old layout's 249 inputs. A new
layout makes both unusable: the legs must be retrained, or the setting turned back to the scripted legs, before the change ships.
