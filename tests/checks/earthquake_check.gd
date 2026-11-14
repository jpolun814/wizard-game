extends Node

## An Earthquake shakes the ground as well as the screen: while it lasts a shake moves the view (and so a stroke drawn on it) farther than it does otherwise, and
## when it has gone the shake is as it was.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/earthquake_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	camera._trauma = 0.0
	camera.shake(0.6)
	var calm := GameCamera.shake_px(get_tree())
	_verdict(calm > 0.0 and not Earthquake.is_shaking(get_tree()), "a shake of 0.6 moves the view %.1f px when the ground is still" % calm)
	world.spawn_spell("Earthquake", "positional", world.player.center(), 0.0, {}, world.player)
	camera._trauma = 0.6  # (the cast shakes the screen too: the same shake as before is compared)
	var quake := GameCamera.shake_px(get_tree())
	_verdict(Earthquake.is_shaking(get_tree()), "the ground shakes after the cast")
	_verdict(quake > calm * (GameCamera.QUAKE_GAIN - 0.1), "the same shake moves the view farther in a quake (%.1f px against %.1f)" % [quake, calm])
	await get_tree().create_timer(Earthquake.SECONDS + 1.0).timeout
	camera.shake(0.6)
	_verdict(not Earthquake.is_shaking(get_tree()) and absf(GameCamera.gain(get_tree()) - 1.0) < 0.001, "and when it is over the shake is as it was")
	print("the earthquake shakes strokes" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
