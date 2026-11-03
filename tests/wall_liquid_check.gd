extends Node

## A Stone Wall stops liquid the way any ground does: lava poured on one side of it runs up to it and no further, and runs on when the wall is gone.
##
##     godot --headless --fixed-fps 60 --path . tests/wall_liquid_check.tscn
## It prints PASS or FAIL for each and exits with code 1 if any failed.

var _failures := 0


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## How much liquid lies beyond a given x (to the right of it), in all of the lava of the world.
func _beyond(x: float) -> float:
	var sum := 0.0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.lava and pond.grid != null:
			for r in pond.grid.rows:
				for c in pond.grid.cols:
					if pond.grid.center_of(c, r).x > x:
						sum += pond.grid.mass[r * pond.grid.cols + c]
	return sum


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
	var space := world.get_world_2d()
	var spot := feet
	for dx in [-300.0, 300.0, -150.0, 150.0, 450.0, -450.0, 700.0, -700.0, 900.0, -900.0, 1200.0, -1200.0, 1600.0, -1600.0]:
		var probe := SpellTargets.solid_below(space, feet + Vector2(dx, -100.0))
		var flat := true
		for side in [-250.0, -120.0, 120.0, 250.0]:
			flat = flat and absf(SpellTargets.solid_below(space, probe + Vector2(side, -100.0)).y - probe.y) < 10.0
		var near_water := false
		for pond: Pond in get_tree().get_nodes_in_group("ponds"):
			if probe.x > pond.global_position.x - 500.0 and probe.x < pond.global_position.x + pond.width + 500.0 and absf(probe.y - pond.global_position.y) < 400.0:
				near_water = true
		if flat and not near_water:
			spot = probe
			break
	world.player.global_position = spot + Vector2(-400.0, -40.0)
	world._ground.watch([spot], true)
	for k in 30:
		await get_tree().physics_frame
	# A wall stands straight up from the ground, 40 px to the right of where the lava is poured.
	world.spawn_spell("Stone Wall", "directional", spot + Vector2(40.0, 0.0), -PI * 0.5, {}, world.player)
	for k in 60:
		await get_tree().physics_frame
	var walls := get_tree().get_nodes_in_group("walls")
	_verdict(walls.size() == 1, "a wall is up")
	var wall_x := spot.x + 40.0
	for k in 12:
		Pond.spill(world, world._ground, spot + Vector2(0.0, -10.0), 3.0, true)
		for j in 20:
			await get_tree().physics_frame
	for k in 240:
		await get_tree().physics_frame
	var over := _beyond(wall_x + 24.0)
	_verdict(over < 0.05, "lava poured beside a wall does not run through it (%.2f beyond it)" % over)
	for wall in walls:
		wall.queue_free()
	for k in 600:
		await get_tree().physics_frame
	var after := _beyond(wall_x + 24.0)
	_verdict(after > 0.3, "and runs on once the wall is gone (%.2f beyond it)" % after)
	print("a wall holds back liquid" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
