extends Node

## How long a frame's scripts take while a volcano of the ashlands erupts, a second at a time (rendering is not counted: run it without --headless to
## see what the picture costs in `Performance.TIME_PROCESS`).
##
##     godot --headless --fixed-fps 60 --path . tests/eruption_perf.tscn -- seed=5

func _ready() -> void:
	var seed_value := 5
	var drop := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
		elif argument.begins_with("drop="):
			drop = argument.substr(5)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 6:
		await get_tree().process_frame
	var craters := get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is Eruption)
	var crater: Eruption = craters[0]
	for other: Eruption in craters:
		if other != crater:
			other.set_physics_process(false)
	world.player.global_position = crater.global_position + Vector2(-260.0, -60.0)
	world._ground.watch([crater.global_position], true)
	for k in 30:
		await get_tree().process_frame
	for k in 120:
		await get_tree().process_frame
	_sample("asleep")
	crater._wake(1234)
	for second in 18:
		var started := Time.get_ticks_usec()
		for k in 60:
			await get_tree().process_frame
			_remove(drop)
		print("second %2d: %.2f ms a frame, gpu %.1f ms" % [second + 1, (Time.get_ticks_usec() - started) / 60000.0, RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
		if second == 9:
			_ponds()
			var kinds := {}
			for light in get_tree().root.find_children("*", "PointLight2D", true, false):
				var key: String = "%s r=%d" % [light.get_parent().get_class() + ":" + str(light.get_parent().get_script().get_global_name()), int(light.texture_scale * Fx.TEX_SIZE * 0.5)]
				kinds[key] = kinds.get(key, 0) + 1
			print(kinds)
	get_tree().quit()


func _sample(label: String) -> void:
	print("%-10s gpu %.1f ms cpu-render %.1f ms fps %d draws %d script %.2f ms  physics %.2f ms  nodes %d  objects %d" % [label, RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()), int(Engine.get_frames_per_second()), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])


## What one pool costs to work out and to flow, as it is at this moment.
func _ponds() -> void:
	for pond: Pond in get_tree().get_nodes_in_group("fires").filter(func(n: Node) -> bool: return n is Pond and n.lava and n.grid != null):
		var top := Color(0.92, 0.4, 0.1)
		var started := Time.get_ticks_usec()
		var keep := pond._mesh  # the picture still being drawn holds the old mesh until it is drawn again
		pond._build_shapes(top, top)
		keep = keep
		var shapes := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		pond.grid.step()
		var step := Time.get_ticks_usec() - started
		print("  pool %s: shapes %d us (%d triangles), one flow step %d us, columns %d" % [pond.name, shapes, (pond._mesh.surface_get_array_index_len(0) / 3 if pond._mesh != null else 0), step, pond.grid.cols])


## For finding what costs: takes one kind of thing out of the world as it appears.
func _remove(what: String) -> void:
	if what == "":
		return
	if what == "lights":
		for light in get_tree().root.find_children("*", "PointLight2D", true, false):
			light.queue_free()
		return
	for node in get_tree().get_nodes_in_group("fires") + get_tree().get_nodes_in_group("lasting") + get_tree().get_nodes_in_group("shots"):
		if (what == "plume" and node is SmokePlume) or (what == "hazard" and node is Hazard) or (what == "balls" and node is LavaBall) or (what == "ponds" and node is Pond and node.loose):
			node.queue_free()

