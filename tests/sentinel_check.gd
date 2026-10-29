extends Node

## A sentinel shoots any wizard it sees, not only the player: a rival standing in its range is hit, and one behind rock is not.
##
##     godot --headless --fixed-fps 60 --path . tests/sentinel_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var feet: Vector2 = world.player.global_position  # the open ground at the start
	var rival: Wizard = null
	for mob in get_tree().get_nodes_in_group("mobs").duplicate():
		mob.queue_free()
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != world.player and rival == null:
			rival = found
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != rival:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)  # the sentinel has only the rival to go for
			found.remove_from_group("wizards")
	rival.global_position = feet
	rival.velocity = Vector2.ZERO
	var post := Sentinel.new()
	world.add_child(post)
	post.global_position = feet + Vector2(-1500.0, 0.0)
	var before := rival.max_stamina
	await _hold(rival, feet)
	_verdict(rival.max_stamina == before, "a rival out of the sentinel's range is not hurt (%d of %d left)" % [rival.max_stamina, before])
	post.global_position = feet + Vector2(-250.0, 0.0)
	await _hold(rival, feet)
	_verdict(rival.max_stamina < before, "a rival in range is shot (%d of %d left)" % [rival.max_stamina, before])
	print("sentinels shoot any wizard" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Keeps the rival standing where it is for four seconds.
func _hold(rival: Wizard, at: Vector2) -> void:
	for i in 240:
		if rival.dead:
			return
		rival.global_position = at
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
