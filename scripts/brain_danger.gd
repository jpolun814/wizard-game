class_name BrainDanger
extends RefCounted

## What can hurt an AI wizard where it stands or where it means to go: lava and the volcanoes that feed it, thorns it has no fire for, piranhas, and
## anything else that is in the "danger" group. Each answer is a look at the world as it is now.

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## True when anything that hurts (any spell, its own included) would reach it at this point.
## Where a volcano that is awake (or lava from one that is still running and cooling) lies within reach of a point, or Vector2.INF.
func volcano_near(point: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	var best_gap := reach
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		var source := node as Node2D
		if source == null or not ((node is Eruption and node.is_awake()) or (node is Pond and node.cools and node.molten())):
			continue
		var gap := absf(source.global_position.x - point.x)
		if gap < best_gap and absf(source.global_position.y - point.y) < 900.0:
			best = source.global_position
			best_gap = gap
	return best


## True while lava is burning it: that is never walked on through.
func scorched() -> bool:
	if wizard.lava_proof():
		return false
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if node is Pond and node.molten() and node.holds(wizard):
			return true
	return false


## True over a volcano that is awake, or lava from one that still runs: it passes, and nothing walks on into it meanwhile.
func lethal_at(point: Vector2) -> bool:
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if ((node is Eruption and node.is_awake()) or (node is Pond and node.cools and node.molten()) or (node is Bramble and brain.clearing_spell("brambles") == "")) and node.danger_at(point):  # (thorns are not walked into by someone with no fire to burn them)
			return true
	return in_shoal(point)


## True in water with piranhas in it.
func in_shoal(point: Vector2) -> bool:
	for shoal: Piranhas in wizard.get_tree().get_nodes_in_group("shoals"):  # water with fish in it is not waded
		if shoal.alive() and shoal.is_biting_at(point):
			return true
	return false


## True while it stands in water with piranhas in it: it gets out by the nearest bank, hopping the edge when it must.
func bitten() -> bool:
	return in_shoal(wizard.global_position + Vector2(0.0, -6.0)) or in_shoal(wizard.center())


func in_danger(point: Vector2) -> bool:
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if node.danger_at(point):
			return true
	return false


func clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
