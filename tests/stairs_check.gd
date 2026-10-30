extends Node

## A castle's stair to the cellar is a slope a wizard walks down, stands on, and drops through by holding S, like a wooden platform.
##
##     godot --headless --path . --fixed-fps 60 tests/stairs_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.next_seed = 9
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var run: Dictionary = world._castle_stairs[0]
	var from: Vector2 = run["from"]
	var cellar_floor: float = run["to"].y
	var player: Wizard = world.player
	player.movement_enabled = true
	player.global_position = from + Vector2(0.0, -30.0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	var line_y := from.y + (player.global_position.x - from.x)
	_verdict(player.global_position.x > from.x + 40.0, "the wizard walks down the stair (x %.0f from %.0f)" % [player.global_position.x, from.x])
	_verdict(absf(player.global_position.y - minf(line_y, cellar_floor)) < 20.0, "and stands on it or the cellar floor (y %.0f, slope %.0f, floor %.0f)" % [player.global_position.y, line_y, cellar_floor])
	var mid := from + Vector2(5.0, 5.0) * 32.0
	player.global_position = mid + Vector2(0.0, -20.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	_verdict(absf(player.global_position.y - mid.y) < 20.0, "a wizard set on the middle of the stair stands on it (y %.0f, slope %.0f)" % [player.global_position.y, mid.y])
	Input.action_press("move_down")
	await _frames(90)
	Input.action_release("move_down")
	_verdict(player.global_position.y > cellar_floor - 20.0, "holding S drops the wizard through it to the cellar floor (y %.0f, floor %.0f)" % [player.global_position.y, cellar_floor])
	print("the stair works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
