extends Check
## An Earthquake shakes the ground as well as the screen: while it lasts a shake moves the view (and so a stroke drawn on it) farther than it does otherwise, and
## when it has gone the shake is as it was.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/earthquake_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.



func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	_put_away_all_but([world.player])  # (nobody else is being checked)
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	camera._trauma = 0.0
	camera.shake(0.6)
	var calm := GameCamera.shake_px(get_tree())
	_verdict(calm > 0.0 and not Earthquake.is_shaking(get_tree()), "a shake of 0.6 moves the view %.1f px when the ground is still" % calm)
	# Every stone wall raised anywhere in the world comes down in a quake, near the wizard or not.
	var walls: Array[StoneWall] = []
	for far in [60.0, 2500.0]:
		var wall := StoneWall.new()
		wall.wall_texture = world.earth_texture()
		world.add_child(wall)
		wall.setup("Stone Wall", world.player.global_position + Vector2(far, -40.0), 0.0)
		walls.append(wall)
	var bricks: Array[RockWall] = []
	for far in [60.0, 2500.0]:
		var brick := RockWall.new()
		brick.columns = [{"x": 10, "top": 2, "bottom": 10}]
		brick.global_position = world.player.global_position + Vector2(far, -3000.0)
		world.add_child(brick)
		bricks.append(brick)
	await get_tree().physics_frame
	_verdict(walls.all(func(w) -> bool: return is_instance_valid(w) and not w.is_queued_for_deletion()), "two stone walls stand, one near and one far")
	world.spawn_spell("Earthquake", "positional", world.player.center(), 0.0, {}, world.player)
	await get_tree().create_timer(Earthquake.WALLS_FALL_AT + 0.6).timeout
	_verdict(walls.all(func(w) -> bool: return not is_instance_valid(w) or w.is_queued_for_deletion()), "an earthquake brings down every stone wall in the world")
	_verdict(bricks.all(func(b) -> bool: return not is_instance_valid(b) or b.is_queued_for_deletion() or b._health < RockWall.HEALTH), "and wears down every wall of brick in it, near or far")
	camera._trauma = 0.6  # (the cast shakes the screen too: the same shake as before is compared)
	var quake := GameCamera.shake_px(get_tree())
	_verdict(Earthquake.is_shaking(get_tree()), "the ground shakes after the cast")
	_verdict(quake > calm * (GameCamera.QUAKE_GAIN - 0.1), "the same shake moves the view farther in a quake (%.1f px against %.1f)" % [quake, calm])
	await get_tree().create_timer(Earthquake.SECONDS + 1.0).timeout
	camera.shake(0.6)
	_verdict(not Earthquake.is_shaking(get_tree()) and absf(GameCamera.gain(get_tree()) - 1.0) < 0.001, "and when it is over the shake is as it was")
	print("the earthquake shakes strokes" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


