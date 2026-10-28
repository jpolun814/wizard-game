extends Node

## A Spark comes down from the sky over its stroke and lands on the ground under it: on the open surface of a world with caves, in the last world
## (all open sky), and under a cave's roof (from the roof). The place it lands is compared with the ground the physics world has there.
##
##     godot --headless --path . --fixed-fps 60 tests/spark_check.tscn
## It prints PASS or FAIL for each place and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	for stage in [0, 3]:
		World.next_seed = 8
		MatchState.hurry = 100.0
		if stage > 0:
			MatchState.begin(8)
			MatchState.stage = stage
			MatchState.pending = true
			MatchState.ledgers = Pages.deal(8 + 31, World.WIZARDS)
			for k in 4:
				MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		await get_tree().process_frame
		await get_tree().process_frame
		var feet: Vector2 = world.player.global_position
		_strike(world, feet + Vector2(120.0, -150.0), "stage %d, drawn 150 px up in the open" % stage)
		_strike(world, feet + Vector2(-200.0, -600.0), "stage %d, drawn 600 px up in the open" % stage)
		if stage == 0:
			var room: Dictionary = world.graph.rooms[1]
			var floor_pos: Vector2 = world._stand_at(world._markers[room["id"]])
			_strike(world, floor_pos + Vector2(0.0, -120.0), "stage 0, in a cave")
		world.queue_free()
		await get_tree().process_frame
	print("sparks land on the ground" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _strike(world: World, origin: Vector2, what: String) -> void:
	var strike := SparkStrike.new()
	world.add_child(strike)
	strike.setup("Spark", origin, 0.0)
	var shape: CollisionShape2D = null
	for child in strike.get_children():
		if child is CollisionShape2D:
			shape = child
	var landed := strike.global_position.y + (shape.shape as RectangleShape2D).size.y
	var query := PhysicsRayQueryParameters2D.create(Vector2(origin.x, origin.y - 1.0), Vector2(origin.x, origin.y + 3000.0))
	query.collision_mask = 1 | 16
	var ground := world.get_world_2d().direct_space_state.intersect_ray(query)
	var want: float = ground["position"].y if not ground.is_empty() else -1.0
	_verdict(absf(landed - want) < 12.0, "%s: lands at y %.0f, the ground is at %.0f" % [what, landed, want])
	strike.queue_free()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
