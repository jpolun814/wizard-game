extends Node

## A stress test of the ashlands: every volcano erupting over and over, the ash storm raining fire without a break, and all four wizards in one place with
## every page and casting at one another. It prints how long frames take, second by second, to find what makes an eruption slow. It runs as fast as it
## can in a window (not headless: the cost it looks for is drawing).
##
##     godot --path . tests/eruption_perf.tscn -- seed=5 seconds=60 [near=1] [calm=1]
## near=1 stands the wizards at a volcano; without it they are far from every volcano. calm=1 leaves out the fire rain.

var _off := ""


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var seed_value := 5
	var seconds := 60
	var near := false
	var calm := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
		elif argument.begins_with("seconds="):
			seconds = int(argument.substr(8))
		elif argument == "near=1":
			near = true
		elif argument == "calm=1":
			calm = true
		elif argument.begins_with("off="):
			_off = argument.substr(4)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 6:
		await get_tree().process_frame
	var craters := get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is Eruption)
	print("volcanoes: %d" % craters.size())
	var crater: Eruption = craters[0]
	var spot := crater.global_position + Vector2(-260.0 if near else -3000.0, -80.0)
	var wizards := get_tree().get_nodes_in_group("wizards")
	for k in wizards.size():
		var wizard: Wizard = wizards[k]
		wizard.ledger.learn_all()
		wizard.global_position = spot + Vector2(k * 70.0, 0.0)
		wizard.velocity = Vector2.ZERO
	if world._squall != null and not calm:
		world._squall.delay = 0.0
		world._squall.period = 1e9
		world._squall.length = 1e9  # it rains fire all the time
	for k in 60:
		await get_tree().process_frame
	for second in seconds:
		for volcano: Eruption in craters:
			if volcano._state == "sleeping":
				volcano._phase = minf(volcano._phase, 0.5)
		var started := Time.get_ticks_usec()
		var frames := 0
		var slow := 0
		var worst := 0.0
		var last := started
		while Time.get_ticks_usec() - started < 1000000:
			await get_tree().process_frame
			frames += 1
			var now := Time.get_ticks_usec()
			var ms := (now - last) / 1000.0
			last = now
			worst = maxf(worst, ms)
			if ms > 25.0:
				slow += 1
		if second == 20 and _off != "":
			var kinds := {}
			for node in get_tree().get_nodes_in_group(_off.get_slice(":", 0)):
				var script_name: String = node.get_script().get_global_name() if node.get_script() != null else node.get_class()
				kinds[script_name] = int(kinds.get(script_name, 0)) + 1
				if _off.find(":") < 0 or _off.get_slice(":", 1) == script_name:
					node.set_physics_process(false)
					node.set_process(false)
			print(kinds)
			print("--- %s switched off" % _off)
		if second == 12 or second == 30:
			_profile(world)
		if second % 3 == 0:
			print("t=%2d  %4.0f fps  slowest %5.1f ms  frames over 25 ms: %2d  | %s  calls %d  prims %d  nodes %d  fires %d  shots %d  ponds %d  mobs %d" % [second, frames, worst, slow,
				crater._state, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), get_tree().get_nodes_in_group("fires").size(), get_tree().get_nodes_in_group("shots").size(),
				get_tree().get_nodes_in_group("ponds").size(), get_tree().get_nodes_in_group("mobs").size()])
	get_tree().quit()


## Calls every node's per-frame functions once, timed, and prints which kinds of node take the most.
func _profile(root: Node) -> void:
	var totals := {}
	var counts := {}
	for node in root.find_children("*", "", true, false):
		if node.get_script() == null:
			continue
		var kind: String = node.get_script().get_global_name()
		if kind == "":
			kind = node.get_script().resource_path.get_file()
		var started := Time.get_ticks_usec()
		if node.has_method("_physics_process") and node.is_physics_processing():
			node._physics_process(1.0 / 60.0)
		if node.has_method("_process") and node.is_processing():
			node._process(1.0 / 60.0)
		totals[kind] = float(totals.get(kind, 0.0)) + (Time.get_ticks_usec() - started) / 1000.0
		counts[kind] = int(counts.get(kind, 0)) + 1
	var order := totals.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])
	var line := "   per-frame cost (ms, count):"
	for kind: String in order.slice(0, 8):
		line += "  %s %.2f (%d)" % [kind, totals[kind], counts[kind]]
	print(line)
