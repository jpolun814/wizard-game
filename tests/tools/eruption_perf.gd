extends Node

## A stress test of the ashlands: every volcano erupting over and over, the ash storm raining fire without a break, and all four wizards in one place with
## every page and casting at one another. It prints how long frames take, second by second, to find what makes an eruption slow. It runs as fast as it
## can in a window (not headless: the cost it looks for is drawing).
##
##     godot --path . tests/tools/eruption_perf.tscn -- seed=5 seconds=60 [near=1] [calm=1]
## near=1 stands the wizards at a volcano; without it they are far from every volcano. calm=1 leaves out the fire rain.

var _off := ""
var _hunter: Hunter
var _tick_start := 0
var _idle_start := 0
var _idle_ms: Array[float] = []
var _script_ms: Array[float] = []  # how long the scripts of each physics tick took, from the first node to the last


## A node that runs first or last among everything in a physics tick, so the time between them is the game's own scripts.
class Bookend extends Node:
	var last := false
	var owner_test: Node

	func _process(_delta: float) -> void:
		if last:
			owner_test._idle_ms.append((Time.get_ticks_usec() - owner_test._idle_start) / 1000.0)
		else:
			owner_test._idle_start = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		if last:
			owner_test._script_ms.append((Time.get_ticks_usec() - owner_test._tick_start) / 1000.0)
		else:
			owner_test._tick_start = Time.get_ticks_usec()


## `hunt=1`: takes over every node's physics function and calls each one itself, timed, so that a slow tick can be blamed on the node that made it.
class Hunter extends Node:
	var driven := []
	var kinds := {}  # script name -> total microseconds this second
	var spikes: Array[String] = []

	func _ready() -> void:
		process_physics_priority = -90000
		get_tree().node_added.connect(_adopt)

	func _adopt(node: Node) -> void:
		if node == self or node is Bookend or node.get_script() == null or not node.has_method("_physics_process"):
			return
		node.set_physics_process.call_deferred(false)
		driven.append(node)

	func adopt_all(root: Node) -> void:
		for node in root.find_children("*", "", true, false):
			_adopt(node)

	func _physics_process(delta: float) -> void:
		var tick_total := 0
		var worst := 0
		var worst_name := ""
		var top: Array = []
		for node in driven:
			if not is_instance_valid(node) or not node.is_inside_tree():
				continue
			node.set_physics_process(false)  # (some switch themselves back on)
			var t0 := Time.get_ticks_usec()
			node._physics_process(delta)
			var used := Time.get_ticks_usec() - t0
			tick_total += used
			var kind: String = node.get_script().get_global_name()
			if kind == "":
				kind = node.get_script().resource_path.get_file()
			kinds[kind] = int(kinds.get(kind, 0)) + used
			top.append([used, "%s %s" % [kind, node.name]])
		driven = driven.filter(func(n) -> bool: return is_instance_valid(n))
		if tick_total > 12000:
			top.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			spikes.append("%.1f ms: %s %.1f | %s %.1f | %s %.1f" % [tick_total / 1000.0, top[0][1], top[0][0] / 1000.0, top[1][1], top[1][0] / 1000.0, top[2][1], top[2][0] / 1000.0])


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var seed_value := 5
	var seconds := 60
	var near := false
	var calm := false
	var hunt := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
		elif argument.begins_with("seconds="):
			seconds = int(argument.substr(8))
		elif argument == "near=1":
			near = true
		elif argument == "calm=1":
			calm = true
		elif argument == "hunt=1":
			hunt = true
		elif argument.begins_with("off="):
			_off = argument.substr(4)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	for end in [false, true]:
		var bookend := Bookend.new()
		bookend.last = end
		bookend.owner_test = self
		bookend.process_physics_priority = 100000 if end else -100000
		bookend.process_priority = 100000 if end else -100000
		add_child(bookend)
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
	if world.scenery.squall != null and not calm:
		world.scenery.squall.delay = 0.0
		world.scenery.squall.period = 1e9
		world.scenery.squall.length = 1e9  # it rains fire all the time
	for k in 60:
		await get_tree().process_frame
	if hunt:
		_hunter = Hunter.new()
		add_child(_hunter)
		_hunter.adopt_all(world)
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
		if not _script_ms.is_empty():
			var tick_worst := 0.0
			var tick_total := 0.0
			var tick_over := 0
			for ms in _script_ms:
				tick_worst = maxf(tick_worst, ms)
				tick_total += ms
				tick_over += 1 if ms > 12.0 else 0
			print("   script time of a tick: avg %.1f ms  worst %.1f ms  ticks over 12 ms: %d of %d" % [tick_total / _script_ms.size(), tick_worst, tick_over, _script_ms.size()])
			_script_ms.clear()
		if _hunter != null:
			var parts := []
			var order := _hunter.kinds.keys()
			order.sort_custom(func(a: String, b: String) -> bool: return _hunter.kinds[a] > _hunter.kinds[b])
			for kind in order.slice(0, 6):
				parts.append("%s %.1f" % [kind, _hunter.kinds[kind] / 1000.0])
			print("   per second (ms): ", ", ".join(parts), "  driven ", _hunter.driven.size())
			for line in _hunter.spikes.slice(0, 4):
				print("   SPIKE ", line)
			_hunter.kinds.clear()
			_hunter.spikes.clear()
		if not _idle_ms.is_empty():
			var idle_total := 0.0
			var idle_worst := 0.0
			for ms in _idle_ms:
				idle_total += ms
				idle_worst = maxf(idle_worst, ms)
			print("   _process scripts of a frame: avg %.1f ms  worst %.1f ms (%d frames)" % [idle_total / _idle_ms.size(), idle_worst, _idle_ms.size()])
			_idle_ms.clear()
		print("   process %.1f ms  physics %.1f ms  physics-active objects %d  2D collision pairs %d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)])
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
