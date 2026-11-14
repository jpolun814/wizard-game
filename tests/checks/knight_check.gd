extends Node

## A knight stands guard: it keeps its post while nobody is near, fights a wizard who comes close, and walks back to its post when they are gone.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/knight_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

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
	var feet: Vector2 = world.player.global_position
	var rival: Wizard = null
	for mob in get_tree().get_nodes_in_group("mobs").duplicate():
		mob.queue_free()
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != world.player and rival == null:
			rival = found
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != rival:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
			found.remove_from_group("wizards")
	rival.set_physics_process(false)
	var knight: Mob = world.add_mob("knight", feet)
	knight.guards = true
	knight.post_x = feet.x
	await get_tree().create_timer(1.0).timeout
	rival.global_position = feet + Vector2(-900.0, 0.0)
	await get_tree().create_timer(2.0).timeout
	_verdict(absf(knight.global_position.x - feet.x) < 8.0, "a knight stays at its post while nobody is near")
	var before := rival.max_stamina
	rival.global_position = feet + Vector2(-150.0, 0.0)
	for i in 300:
		rival.global_position.x = feet.x - 150.0
		await get_tree().physics_frame
	_verdict(rival.max_stamina < before or absf(knight.global_position.x - feet.x) > 30.0, "a wizard who comes near is fought (%d of %d left)" % [rival.max_stamina, before])
	rival.global_position = feet + Vector2(-900.0, 0.0)
	await get_tree().create_timer(5.0).timeout
	_verdict(absf(knight.global_position.x - feet.x) < 20.0, "and the knight walks back to its post (%.0f px off)" % absf(knight.global_position.x - feet.x))
	print("a knight stands guard" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
