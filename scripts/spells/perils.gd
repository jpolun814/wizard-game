class_name Perils
extends RefCounted

## What lies in the way, as it bears on whoever goes through it. A thing that harms or hinders says so itself: `peril_at(point)` gives the harm a second and the share of its pace a walker
## keeps there (and `jump`: false where it cannot jump; `after`: what it loses for having got into it at all, the first blow or the flame that has caught; `kind`: what sort of harm), or nothing; `peril_box()` where it lies, and `undone_by()` the stuffs that put an end to it, of those a spell is made of (`Spell.made_of`). Nothing here, and nothing in the
## AI that reads it, pairs one spell with one thing: fire undoes what burns, whatever makes the fire.

## The world's laws of what undoes what kind of thing (the laws themselves are worked in FloraSpell, Elements, GasBank, Piranhas: this says them).
const PLANT := ["fire", "lightning"]    # lightning sets plants alight too
const LIVES_IN_WATER := ["lightning"]
const GAS := ["wind", "fire"]


## Every one there is.
static func all(tree: SceneTree) -> Array[Node]:
	var out: Array[Node] = []
	for group: StringName in [&"danger", &"shoals", &"perils", &"ponds"]:
		for node in tree.get_nodes_in_group(group):
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node.has_method("peril_at") and not out.has(node):
				out.append(node)
	return out
