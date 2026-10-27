extends Node

## Times a generated world while the wizard runs along the surface, then down a tunnel.
##   godot --path . tests/perf.tscn -- seed=11
## Prints, each second: frames per second, the slowest frame, and what the engine says it spent.

var _arena: Node
var _t := 0.0
var _frames := 0
var _worst := 0.0
var _sum := 0.0
var _second := 0
var _mode := ""
var _scene := "world"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_scene = arg.split("=")[1]
		if arg.begins_with("mode="):
			_mode = arg.split("=")[1]
		if arg.begins_with("seed="):
			World.next_seed = int(arg.split("=")[1])
	var begun := Time.get_ticks_msec()
	_arena = load("res://scenes/%s.tscn" % _scene).instantiate()
	add_child(_arena)
	print("built in %d ms" % (Time.get_ticks_msec() - begun))


func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	_sum += delta
	_worst = maxf(_worst, delta)
	if _t > 1.0 and _mode != "" and _t - delta <= 1.0:
		match _mode:
			"nophys":
				_arena.player.set_physics_process(false)
			"hide":
				for c in _arena.get_children():
					if c is Terrain:
						c.visible = false
			"hiderock":
				for c in _arena.get_children():
					if c is Terrain:
						for d in c.get_children():
							if d is RockWorld:
								d.visible = false
			"hidequad":
				for c in _arena.get_children():
					if c is Terrain:
						for d in c.get_children():
							if d is Terrain.CaveDraw:
								d.visible = false
			"nohud":
				_arena.hud.visible = false
			"noproc":
				_arena.set_process(false)
				_arena.player.set_process(false)
	if _t > 2.0 and not Input.is_action_pressed("move_right"):
		Input.action_press("move_right")
	if _t > 14.0:
		get_tree().quit()
	if _sum >= 1.0:
		_second += 1
		print("t=%2d  %3d fps  worst %5.1f ms  process %4.1f ms  physics %4.1f ms  draws %4d  primitives %7d  nodes %d  x=%d" % [_second, _frames, _worst * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), int(_arena.player.global_position.x)])
		_frames = 0
		_sum = 0.0
		_worst = 0.0
