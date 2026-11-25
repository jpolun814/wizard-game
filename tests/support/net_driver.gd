class_name NetDriver
extends Node

## The base of a network check: one copy of the game, playing one role. The runner (tools/run_checks.py) starts every copy of a check and keeps them in step,
## frame by frame, so a wait of a second is the same sixty frames on each (see SteadyRun). A check's scene calls `start` with a driver of its own, which
## outlives the scenes the game goes through; the driver plays its part in `_play` and the base ends the copy when it returns.

const WAITING_ROOM := "res://scenes/lab.tscn"
const WORLD := "res://scenes/world.tscn"
const PATIENCE := 300.0  # seconds of the game that something waited for may take before the check fails, saying what it was

var role := "host"
var _failures := 0


## Puts a driver in the game, in the role the runner named.
static func start(scene: Node, driver: NetDriver) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("role="):
			driver.role = arg.get_slice("=", 1)
	scene.get_tree().root.add_child.call_deferred(driver)


func _ready() -> void:
	await _play()
	print("%s: %s" % [role, "PASS" if _failures == 0 else "%d FAILED" % _failures])
	await _seconds(1.0)  # (what this copy said last reaches the others before it goes)
	get_tree().quit(1 if _failures > 0 else 0)


## What this copy does.
func _play() -> void:
	pass


## Hosts the game, or joins it, and comes into the waiting room with everyone there.
func _into_the_room(people: int) -> Node:
	if role == "host":
		Net.host()
	else:
		Net.join("127.0.0.1")
		await _until(func() -> bool: return Net.roster.has(Net.my_id()), "the host to take this copy in")
	get_tree().change_scene_to_file(WAITING_ROOM)
	var room: Node = await _scene(WAITING_ROOM)
	await _until(func() -> bool: return Net.roster.size() == people and Net.peers_here().size() == people - 1, "%d people in the room" % people)
	return room


## Touches the book in the waiting room, puts the cut-scene away and comes into the world with the others.
func _into_the_world(room: Node, others: int) -> Node:
	var portal: Node2D = get_tree().get_first_node_in_group("portals")
	room.player.global_position = portal.global_position + Vector2(0, -30)
	await _until(func() -> bool: return get_tree().current_scene == null or get_tree().current_scene.scene_file_path != WAITING_ROOM, "the match to begin")
	await _until(func() -> bool: return get_tree().current_scene != null, "the cut-scene")
	await _seconds(1.5)
	if get_tree().current_scene.scene_file_path != WORLD:
		var key := InputEventKey.new()  # any key puts the cut-scene away
		key.keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
	var world: Node = await _scene(WORLD)
	await _until(func() -> bool: return Net.peers_here().size() == others, "the others in the world")
	return world


func _scene(path: String) -> Node:
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path and get_tree().current_scene.is_node_ready(), path)
	return get_tree().current_scene


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Waits until something is so. When it never comes the check ends there, saying what it was.
func _until(condition: Callable, what: String) -> void:
	var frames := int(PATIENCE * 60.0)
	while not condition.call():
		frames -= 1
		if frames <= 0:
			_check(false, "waited for %s, and it did not come" % what)
			get_tree().quit(1)
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print("%s  %s: %s" % ["PASS" if ok else "FAIL", role, what])
	if not ok:
		_failures += 1
