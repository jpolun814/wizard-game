extends Node

## The castle's stairwells have thirteen swinging stairs in all; the first is the keep's. A person waits at a landing until one has swung to the landing across, walks over it, and
## is carried by it as it swings.
##
##     godot --headless --fixed-fps 60 --path . tests/stairwell_check.tscn            (add `-- out=DIR` for a picture, needs a window)
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	World.random_start = false
	World.next_seed = 9
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var stairs := get_tree().get_nodes_in_group("swing_stairs")
	_verdict(stairs.size() >= 13 and stairs.size() % 13 == 0, "each castle has thirteen swinging stairs (%d in all)" % stairs.size())
	if stairs.size() < 13:
		get_tree().quit(1)
		return
	var left: SwingStair = stairs[0]  # hinged on the left of the shaft, at the first floor
	var ways: Array = left.ways
	_verdict(ways.size() == 3, "and it swings among three landings (%d)" % ways.size())
	var from: Vector2i = ways[0]["from"]
	var player: Wizard = world.player
	player.movement_enabled = true
	player.infinite_time = 600.0
	var stand := Vector2((from.x + 0.5) * 32.0, (from.y + 1) * 32.0)
	player.global_position = stand + Vector2(0.0, -4.0)
	player.velocity = Vector2.ZERO
	await _frames(30)
	_verdict(player.is_on_floor() and absf(player.global_position.y - stand.y) < 10.0, "a wizard stands on the landing beside the shaft (%.0f from its floor)" % (player.global_position.y - stand.y))
	var across: Vector2i = ways[1]["to"]
	for index in 3:  # to the floor below, across, and to the floor above: it is walked in turn
		across = ways[index]["to"]
		player.global_position = stand + Vector2(0.0, -4.0)
		player.velocity = Vector2.ZERO
		await _frames(20)
		var waited := 0.0
		while not SwingStair.is_joined(get_tree(), from, across, 3.6) and waited < 90.0:
			await _frames(6)
			waited += 0.1
		_verdict(waited < 90.0, "the stair swings to landing %d within a minute and a half (%.1f s)" % [index, waited])
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out + "/well_%d.png" % index)
		Input.action_press("move_right")
		var got := false
		for k in 420:
			await get_tree().physics_frame
			if absf(player.global_position.x - (across.x + 0.5) * 32.0) < 24.0 and absf(player.global_position.y - (across.y + 1) * 32.0) < 20.0:
				got = true
				break
		Input.action_release("move_right")
		_verdict(got, "and a wizard walks across it to landing %d (at %.0f, %.0f, wanted %.0f, %.0f)" % [index, player.global_position.x, player.global_position.y, (across.x + 0.5) * 32.0, (across.y + 1) * 32.0])
	# Carried: stand in the middle of the stair, and watch it move them.
	player.global_position = left.hinge + Vector2(150.0, -40.0)
	player.velocity = Vector2.ZERO
	await _frames(20)
	var first := player.global_position
	var moved := 0.0
	for k in 600:
		await get_tree().physics_frame
		moved = maxf(moved, player.global_position.distance_to(first))
	_verdict(moved > 30.0, "a wizard on it is carried or thrown as it swings (%.0f px)" % moved)
	print("the stairwell works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
