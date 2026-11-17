extends Node

## Burrow: the wizard sinks into the ground and travels beneath it, unseen and casting nothing; a blow, or the time running out, brings them up on the surface.
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
	me.begin_burrow()
	await get_tree().process_frame
	_verdict(me.is_faded() and me.silenced(), "under the ground a wizard is hidden and can cast nothing")
	for i in 60:
		Input.action_press("move_right")
		await get_tree().physics_frame
	Input.action_release("move_right")
	var moved := me.global_position.x - start.x
	_verdict(moved > 120.0, "and travels along beneath the surface (%.0f px)" % moved)
	_verdict(me.global_position.y > start.y + 10.0, "below where they stood (%.0f px)" % (me.global_position.y - start.y))
	var before := me.max_stamina
	me.take_damage(5)
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(not me.is_faded() and not me.silenced(), "a blow brings them out")
	_verdict(me.max_stamina < before, "and it lands")
	await get_tree().create_timer(1.5).timeout
	_verdict(absf(me.global_position.y - start.y) < 40.0 and me.get_collision_mask_value(1), "up on the ground again, solid")
	me.begin_burrow()
	await get_tree().create_timer(Wizard.BURROW_SECONDS + 0.8).timeout
	_verdict(not me.is_faded() and not me.silenced(), "left alone they come up when the time is out")
	_verdict(absf(me.global_position.y - start.y) < 60.0, "on the surface (%.0f px off)" % (me.global_position.y - start.y))
	print("burrow works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
