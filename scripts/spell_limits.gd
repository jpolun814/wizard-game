class_name SpellLimits
extends RefCounted

## What the place a wizard is in forbids, as a word on screen and a spell not cast (nothing is paid for it). Two places forbid anything:
## the sky (chapter 19), where there is no ground for a spell that works on the ground, and no need of the ones that carry a wizard through the air; and under
## the sea (chapter 20), where fire cannot burn. The arena asks before it takes the cost of a cast (Arena.cast_by), and a brain asks before it chooses one.

## Spells that work on the ground, or grow from it: with none under them they have nothing to work on.
const NEEDS_GROUND := ["Stone Wall", "Stalagmite", "Sinkhole", "Bramble", "Flaming Sphere", "Mudslide", "Great Oak", "Liana", "Flytrap", "Lily Pads", "Frost Bridge",
		"Geyser", "Tide Surf", "Earthquake", "Raise Dead", "Glowcap", "Moonbeam"]
## Spells that carry a wizard through the air, which a wizard that flies already does.
const NOT_NEEDED_IN_THE_AIR := ["Updraft", "Featherfall", "Rocket Jump"]


## The word to show when a wizard cannot cast this spell where it is ("No ground", "No need", "Fizzles"), or "" when it can.
static func refusal(wizard: Wizard, spell: String) -> String:
	if wizard.flying:
		if NEEDS_GROUND.has(spell):
			return "No ground"
		if NOT_NEEDED_IN_THE_AIR.has(spell):
			return "No need"
	if wizard.lungs.submerged() and SpellData.SPELLS.has(spell) and SpellData.SPELLS[spell].school == "Fire":
		return "Fizzles"
	return ""
