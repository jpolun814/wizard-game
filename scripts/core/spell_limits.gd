class_name SpellLimits
extends RefCounted

## What the place a wizard is in forbids, as a word on screen and a spell not cast (nothing is paid for it): the sky (chapter 19), where there is no ground for a
## spell that works on the ground, and no need of the ones that carry a wizard through the air. The arena asks before it takes the cost of a cast (Casting.by),
## and a brain asks before it chooses one. Under water (chapter 20) nothing is refused: a fire spell is cast, and goes out in steam (`fizzles`).

## Spells that work on the ground, or grow from it: with none under them they have nothing to work on.
const NEEDS_GROUND := ["Stone Wall", "Stalagmite", "Sinkhole", "Bramble", "Flaming Sphere", "Mudslide", "Great Oak", "Liana", "Flytrap", "Lily Pads", "Frost Bridge",
		"Geyser", "Tide Surf", "Earthquake", "Raise Dead", "Glowcap", "Moonbeam"]
## Spells that carry a wizard through the air, which a wizard that flies already does.
const NOT_NEEDED_IN_THE_AIR := ["Updraft", "Featherfall", "Rocket Jump"]


## The word to show when a wizard cannot cast this spell where it is ("No ground", "No need"), or "" when it can.
static func refusal(wizard: Wizard, spell: String) -> String:
	if wizard.flying:
		if NEEDS_GROUND.has(spell):
			return "No ground"
		if NOT_NEEDED_IN_THE_AIR.has(spell):
			return "No need"
	return ""


## Water puts fire out: a fire spell cast with the caster's head under water, or placed at a spot under water, goes out in steam where it starts. `origin` is
## where a spell that is placed is drawn (leave it out for a spell that leaves the caster).
static func fizzles(wizard: Wizard, spell: String, origin := Vector2.INF) -> bool:
	if not SpellData.SPELLS.has(spell) or SpellData.SPELLS[spell].school != "Fire":
		return false
	var tree := wizard.get_tree()
	if in_water(tree, wizard.global_position + Vector2(0.0, -Wizard.BODY_HEIGHT)):
		return true
	return origin != Vector2.INF and not Spell.DIRECTIONAL.has(SpellData.SPELLS[spell].targeting) and in_water(tree, origin)


## True when a point is under the surface of water (lava is not water, and the air in a wreck is not under it).
static func in_water(tree: SceneTree, point: Vector2) -> bool:
	if AirPocket.holds(tree, point):
		return false
	for pond: Pond in tree.get_nodes_in_group("ponds"):
		if not pond.lava and pond.wet_at(point):
			return true
	return false
