extends Node

## A wizard crosses a dark stretch of spikes on foot: the ways about the world bar only the strips, and a jump clears one. For the first few
## worlds that have such a stretch, it finds a way from just short of the stretch to just past it, walks it in real physics, and has to arrive
## without being cut more than once.
##
##     godot --headless --path . --fixed-fps 60 tests/dark_check.tscn -- seeds=1-20 stretches=2
## It prints PASS or FAIL for each stretch and exits with code 1 if any failed.

const SECONDS := 40.0

var _first := 1
var _last := 20
var _stretches := 2
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			_first = int(arg.substr(6).get_slice("-", 0))
			_last = int(arg.substr(6).get_slice("-", 1))
		elif arg.begins_with("stretches="):
			_stretches = int(arg.substr(10))
	World.random_start = false
	var tree := get_tree()
	var tried := 0
	var seed_value := _first
	while seed_value <= _last and tried < _stretches:
		World.next_seed = seed_value
		MatchState.hurry = 100.0
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		await tree.process_frame
		await tree.process_frame
		for entry in world._gates:
			if entry["kind"] == "dark" and tried < _stretches:
				tried += 1
				await _cross(world, entry, seed_value)
		world.queue_free()
		await tree.process_frame
		seed_value += 1
	if tried == 0:
		print("FAIL  no dark stretch in seeds %d to %d" % [_first, _last])
		_failures += 1
	print("dark stretches can be crossed" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _cross(world: World, entry: Dictionary, seed_value: int) -> void:
	var tree := get_tree()
	world.player.take_damage(100000)  # the player stands down
	var body: Mob = null
	for mob in tree.get_nodes_in_group("mobs"):
		if mob.kind == "dark_wizard":
			body = mob
		else:
			mob.queue_free()
	body.set_physics_process(false)  # driven from here
	body.set_process(false)
	var strips: Array = entry["strips"]
	var low: int = strips[0]["x"]
	var high: int = strips[strips.size() - 1]["x"] + strips[strips.size() - 1]["width"]
	var inward: int = entry["inward"]
	var from_x := low - 3 if inward > 0 else high + 3
	var to_x := high + 3 if inward > 0 else low - 3
	var row_of := func(x: int) -> int:
		for blocked: Vector2i in entry["blocks"]:
			if blocked.x == x:
				return blocked.y
		return -1
	var from := Vector2i(from_x, row_of.call(from_x))
	var to := Vector2i(to_x, row_of.call(to_x))
	var path := world.nav.path(world.nav.nearest(from), world.nav.nearest(to))
	_verdict(not path.is_empty(), "seed %d: the nav finds a way across the stretch at %s (%d tiles)" % [seed_value, str(entry["at"]), path.size()])
	if path.is_empty():
		return
	var route := WizardRoute.new()
	route.set_path(path)
	body.global_position = Vector2((path[0].x + 0.5) * 32.0, (path[0].y + 1) * 32.0 - 1.0)
	body.velocity = Vector2.ZERO
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var delta := 1.0 / 60.0
	var start_hp: int = body.hp
	for frame in int(SECONDS / delta):
		await tree.physics_frame
		var steer := route.steer(body, delta)
		if steer["jump"] and body.is_on_floor():
			body.velocity.y = -WizardRoute.JUMP_SPEED
		body.velocity.x = steer["dir"] * steer["speed"]
		body.velocity.y += gravity * delta
		body.move_and_slide()
		if route.done():
			break
	var cuts := (start_hp - body.hp) / 30
	_verdict(route.done() and cuts <= 1, "seed %d: it walks across, cut %d times (%s)" % [seed_value, cuts, route.status()])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
