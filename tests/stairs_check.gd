extends Node

## A swinging stair is a one-way platform, like a wooden one: a wizard on it stands on it, and holding S drops them through it.
##
##     godot --headless --path . --fixed-fps 60 tests/stairs_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 9
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var stair: SwingStair = get_tree().get_nodes_in_group("swing_stairs")[0]
	var player: Wizard = world.player
	player.movement_enabled = true
	player.infinite_time = 600.0
	# Wait for a stay at the first landing it can be at, so that it holds still, then set the wizard on its middle.
	var waited := 0.0
	while not stair.joins(stair.ways[0]["from"], stair.ways[0]["to"], 3.0) and waited < 120.0:
		await _frames(6)
		waited += 0.1
	_verdict(waited < 120.0, "the stair comes to rest at a landing (%.1f s)" % waited)
	var mid: Vector2 = stair.hinge.lerp(stair.ends[0], 0.5)
	player.global_position = mid + Vector2(0.0, -30.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	_verdict(absf(player.global_position.y - mid.y) < 24.0, "a wizard set on the middle of the stair stands on it (y %.0f, stair %.0f)" % [player.global_position.y, mid.y])
	var held := player.global_position.y
	Input.action_press("move_down")
	await _frames(90)
	Input.action_release("move_down")
	_verdict(player.global_position.y > held + 40.0, "holding S drops the wizard through it (y %.0f, was %.0f)" % [player.global_position.y, held])
	print("the stair works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
