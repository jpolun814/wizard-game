extends Node

## Burrow: the wizard goes into the ground and runs beneath it, unseen and casting nothing, as far as the U was wide, and comes up on the surface; a blow brings them up at once.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/burrow_check.tscn

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var me: Wizard = world.player
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != me:
			found.global_position = Vector2(-9000.0, -9000.0)
	await get_tree().create_timer(1.0).timeout
	var start := me.global_position
	me.begin_burrow(1.0, 400.0)
	await get_tree().process_frame
	_verdict(me.is_faded() and me.silenced() and me.is_burrowing(), "under the ground a wizard is hidden and can cast nothing")
	await get_tree().create_timer(0.3).timeout
	_verdict(me.global_position.y > start.y + 10.0, "below where they stood (%.0f px)" % (me.global_position.y - start.y))
	await get_tree().create_timer(1.2).timeout
	var moved := me.global_position.x - start.x
	_verdict(not me.is_burrowing() and not me.is_faded() and not me.silenced(), "and comes up when the distance is covered")
	_verdict(moved > 330.0 and moved < 470.0, "about as far as it was sent (%.0f px)" % moved)
	await get_tree().create_timer(1.0).timeout
	_verdict(me.is_on_floor() and me.get_collision_mask_value(1), "on the surface, solid")
	me.begin_burrow(-1.0, 600.0)
	await get_tree().create_timer(0.3).timeout
	var before := me.max_stamina
	me.take_damage(5)
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(not me.is_faded() and not me.silenced() and me.max_stamina < before, "a blow brings them out")
	print("burrow works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
