# Choosing spells from the spells' own numbers (started 2026-11-24)

The owner's rule: the AI's weights come from concrete numbers about the spells (damage, cost, speed, how long, how far), not from figures measured in old AI-versus-AI games or picked by hand, so that when a spell's number changes (a higher stamina cost) the AI follows with no new measuring.

## What is built (stage 1: the attacks)

- `Spell` (the `.tres` files in `data/spells/`) gained `speed` (px/s it travels; 0 = strikes at once or lands where drawn), `warning` (seconds between cast and harm), `span` (seconds the "per sec" harm keeps coming), `pellets` and `spread` (a volley), `reach` (px). Filled in for 17 attacks: Ignite, Frostbolt, Barbs, Pebble, Thorn Whip, Eldritch Blast, Jolt, Hemorrhage, Scythe, Spark, Stonefall, Stalagmite, Spore Puff, Fire Breath, Insect Plague, Flaming Sphere, Firewall. The damage figures were already numbers in the `damage` text ("5 dmg + 6 dmg/sec").
- `SpellFacts` (`scripts/spells/spell_facts.gd`): reads those fields and works out `worth = expected^(1+k) / cost^k`, where `expected = total damage x chance to land`, `chance = e^(-(warning + gap/speed) / REACTION)` (1 for a held rival, at least 0.75 for a standing one) and `k` grows as stamina runs down. The only assumptions are about people (a rival gets out of the way in about 0.8 s; a wizard minds cost more the less it has), never about a spell. `tests/unit/spell_facts_test.gd` proves a cost change moves the worth.
- `BrainCombat._by_numbers` replaces the old hand weight and the thrift for those spells (the old scores still say which spells the situation allows, and the weights are scaled to weigh what the old ones did against spells with no figures yet). `BrainProfile.off("facts")` switches it off (that seat plays the old way; used for A/B tests).
- The numbers in the resource can drift from the constants in the effect scripts (`SPEED`, `HARM`). Nothing guards that yet: a check should compare them (open work).

## Built since (2026-11-24, stages 3 to 5)

- **Healing** (`SpellFacts.heal_worth`, `BrainMend._heals_by_numbers`): the net heal (after the burn Cauterize leaves) over cost, no more than is missing.
- **Control** (`Spell.hold`, `Spell.share`; filled for Ice Prison, Faint, Silence, Thunderclap, Fight or Flight, Mudslide, Blizzard, Tornado, Black Hole, Sinkhole, Flytrap, Bramble, Vacuum): worth = (`hold` x `share` x the damage a second the wizard could deal, `SpellFacts.damage_rate`) x the chance it lands, over cost as for an attack. They take part in `BrainCombat._by_numbers` with the attacks, scaled to weigh what the hand weights did.
- **Defense** (`Spell.lasts`, `Spell.absorbs`, `Spell.blows`; Crimson Veil, Obsidian Armor, Decoy, Headwind): worth = the harm taken away (`absorbs` of the harm coming in, which is the shots thrown lately and what it has lost, for `lasts` seconds, or `blows` blows) over cost (`SpellFacts.defense_worth`, `BrainMend._defenses_by_numbers`). `Wizard.VEIL_BLOWS` and `Wizard.OBSIDIAN_SECONDS` are the one source for the script and the data.
- **Ways over a gap, a wall, a pit, and what clears a gate** (`WizardBrain.WAYS`, `CLEARS`, `COVERS`): the spells that can do the job are still listed (what a spell does is a fact), but the one taken is now the cheapest the wizard knows (`SpellFacts.cheapest_first`), where it used to be the first on a hand-ranked list.
- The numbers in the data against the scripts' constants: `tests/unit/spell_facts_test.gd`.
- Still hand-set: `BrainGates`'s measures (the width a pad row covers, the height a Rocket Jump lifts: `PADS_REACH`, `DOUBLE_JUMP_REACH`), light and summon choice, and the situational gates inside `BrainCombat.attack`'s table (which spells are allowed in a situation).

## What else a wizard needs to know, by kind of spell (the investigation)

Of the 75 spells only 27 deal damage. The rest need other numbers, and the AI today picks them with hand weights in `BrainMend.tend`, `BrainGates`, `BrainMoves` and the defense part of `BrainCombat`.

| Kind | Spells | Numbers it needs | Used for |
|---|---|---|---|
| Attack, instant | Eldritch Blast, Jolt, Scythe, Thorn Whip, Hemorrhage | damage, reach, cost, warning | EV per cost; built |
| Attack, thrown | Ignite, Frostbolt, Barbs, Pebble, Flaming Sphere | damage, speed, pellets, spread, span of the burn | EV per cost; built |
| Attack, placed or lingering | Spark, Stonefall, Stalagmite, Firewall, Fire Breath, Spore Puff, Insect Plague, Geyser, Icicles, Hailstorm, Supernova, Great Oak | damage, warning, span, area (radius), how long it lasts | EV per cost; most built, the last six still need `damage` made numeric, a `radius` and a hit rate |
| Control | Ice Prison, Faint, Blizzard, Frostbolt's slow, Mudslide, Bramble, Silence, Thunderclap, Fight or Flight, Vacuum, Black Hole, Tornado | seconds the rival is held or slowed, slow share, radius, warning, cost | worth = seconds held x the damage rate the wizard could deal in them x chance, over cost |
| Defense | Barrier, Crimson Veil, Obsidian Armor, Decoy, Golem, Sneak, Headwind, Featherfall | seconds it lasts, how many blows or how much damage it takes, share of damage removed, radius, cost | worth = incoming damage rate the wizard is under (from shots in flight and rivals in range) x share removed x seconds, over cost |
| Healing | Cauterize, Breathe, Mud Mask, Healing Spring, the chants | max stamina given, over how many seconds, what ends it (a blow, moving), cost, how fast it can be used (`Mending.CAP`) | worth = stamina healed per second of exposure and per point paid, against how worn the wizard is |
| Movement and pathfinding | Rocket Jump, Updraft, Liana, Frost Bridge, Lily Pads, Stone Wall, Sinkhole, Shadow Step, Tide Surf, Push, Great Oak | height lifted (px), distance covered (px), how long it lasts, whether it needs ground or water, cost | `BrainGates` and `BrainMoves` should ask "which spell I hold covers this gap or this wall" by comparing the obstacle's measure (gap width, wall height, pit depth) with the spell's, and take the cheapest that covers it, rather than by lists of tags |
| Light and sight | Flare, Glowcap, Moonbeam, Dancing Lights, Eclipse, Hunter's Mark, Sneak | light radius, seconds, cost | the brain asks for light when it is dark; the cheapest light that lasts the longest wins |
| Summons | Raise Dead (50 hp), Immortal Snail, Golem, Mirage, Decoy | health, damage rate, seconds, cost | worth = what the summon does over its life, over cost |

## Order of the work

1. Attacks (done), then test it in royales against the old weights (two sets of 48, as every AI change).
2. Make the damage of the last six lingering attacks numeric and add `radius`; add the drift check against the effect scripts' constants.
3. Healing: give every heal a `rate`, `seconds`, `breaks_on` in the data, and let `BrainMend` choose by worth.
4. Control and defense: add `hold` seconds and `absorbs` to the data; replace the weights in `_cleverness` and the defend code.
5. Movement: add `lift`, `carry`, `lasts` and let `BrainGates` and `BrainMoves` pick by measure.
6. The hand-set conditions inside the attack dictionary ("1.7 if sees and gap < 300") become the spell's `reach` and the rival's state; `ATTACK_RANGE` and the like become the spell's own reach.
