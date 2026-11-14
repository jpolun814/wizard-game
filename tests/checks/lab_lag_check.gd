extends Node

## How smoothly the waiting room starts: it is opened in a window and every frame that takes longer than a sixtieth of a second and a half is listed,
## with what the engine was doing then, for the first seconds. The owner found the start of the waiting room a little laggy (2026-11-12).
##
##     godot --path . tests/checks/lab_lag_check.tscn   (needs a window)

const WATCH := 8.0
const SLOW := 1.5 / 60.0

var _t := -1.0
var _slow: Array = []
var _frames := 0


var _wait := 0.0  # wait=SECONDS: the waiting room is opened this long after the game starts, as a person who reads the first screen first does
var _off := ""  # off=ClassName: nodes of that class are kept from running, to find what the waiting room is busy with


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("off="):
			_off = arg.substr(4)
		if arg.begins_with("wait="):
			_wait = arg.substr(5).to_float()
	if _off != "":
		get_tree().node_added.connect(_on_added)
	if _off.begins_with("autoload"):
		for node in get_tree().root.get_children():
			if node != self and (_off == "autoloads" or node.name == _off.substr(9)):
				node.set_process(false)
				node.set_physics_process(false)
	if _wait > 0.0:
		await get_tree().create_timer(_wait).timeout
	_open()


func _on_added(node: Node) -> void:
	if _off == "draw":  # nothing is drawn: what is left is the scripts and physics
		if node is CanvasItem:
			(node as CanvasItem).set_deferred("visible", false)
		elif node is CanvasLayer:
			(node as CanvasLayer).set_deferred("visible", false)
		return
	var script: Script = node.get_script()
	if script != null and (_off == "*" or script.get_global_name() in _off.split(",")):
		node.set_process(false)
		node.set_physics_process(false)


func _open() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/lab.tscn")
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_frames += 1
	if delta > SLOW and _frames > 1:
		_slow.append("%.2f s: %.0f ms (scripts %.0f ms, physics %.0f ms, draw calls %d, nodes %d, pipelines made: canvas %d, surface %d, draw %d, specialised %d)" % [_t, delta * 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
				Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)])
	if _t >= WATCH:
		print("%d frames in %.1f s, %d slow:" % [_frames, _t, _slow.size()])
		for line in _slow:
			print("   ", line)
		get_tree().quit()
