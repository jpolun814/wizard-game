extends Node

## Tries the way wizards follow a route, one move at a time: for moves picked at random from a world's map of ways (see WorldNav), stands a
## wizard's body at the start, sends it along the move, and sees whether it gets to the end within a few seconds. Reports how often each kind
## of move works, and the first few that do not (with a picture of the map round them). It needs the game's own scenes, so it runs as a scene:
##
##     godot --headless --path . --fixed-fps 60 tests/route_check.tscn -- seed=7 moves=400 look=dark_wizard
## It exits with code 1 when any kind of move works less than MIN_RATE of the time.

const MIN_RATE := 0.9
const SECONDS := 4.0
const SHOW := 3  # failures to draw for each kind

var seed_value := 7
var count := 400
var look := "dark_wizard"
var _trace := []  # trace=X,Y,TX,TY follows one move and prints where the body is on the way
var _world: World
var _kinds := {}  # kind of move -> {"tried", "worked", "failed": [text]}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("moves="):
			count = int(arg.substr(6))
		elif arg.begins_with("trace="):
			_trace = [int(arg.get_slice(",", 0).substr(6)), int(arg.get_slice(",", 1)), int(arg.get_slice(",", 2)), int(arg.get_slice(",", 3))]
		elif arg.begins_with("look="):
			look = arg.substr(5)
	seed(seed_value)
	World.next_seed = seed_value
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_world.player.dead = true
	_world.player.hide()
	var body: Wizard = null
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found.look == look:
			body = found
	if body == null:
		print("FAIL  no %s in the world" % look)
		get_tree().quit(1)
		return
	body.set_physics_process(false)  # driven from here
	body.set_process(false)
	await _run(body)


func _run(body: Wizard) -> void:
	var nav := _world.nav
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if not _trace.is_empty():
		var worked := await _try(body, Vector2i(_trace[0], _trace[1]), Vector2i(_trace[2], _trace[3]), true)
		print("worked" if worked else "did not work")
		get_tree().quit()
		return
	var tried := 0
	while tried < count:
		var tile := Vector2i(rng.randi_range(40, 1150), rng.randi_range(40, 340))
		if not nav.can_stand(tile):
			continue
		var moves := nav.moves(tile)
		if moves.is_empty():
			continue
		var hard: Array[Vector2i] = moves.filter(func(m: Vector2i) -> bool: return tile.y - m.y >= 2 or absi(m.x - tile.x) >= 3 or m.y - tile.y >= 2)
		var to := moves[rng.randi() % moves.size()] if hard.is_empty() or rng.randf() < 0.3 else hard[rng.randi() % hard.size()]
		tried += 1
		var worked := await _try(body, tile, to)
		var kind := _kind(tile, to)
		if not _kinds.has(kind):
			_kinds[kind] = {"tried": 0, "worked": 0, "failed": []}
		var entry: Dictionary = _kinds[kind]
		entry["tried"] += 1
		if worked:
			entry["worked"] += 1
		else:
			entry["failed"].append("from %s to %s, ended at (%.1f, %.1f) tile units, wanted (%.1f, %.1f)\n%s" % [str(tile), str(to), body.global_position.x / 32.0, body.global_position.y / 32.0, to.x + 0.5, to.y + 1.0, nav.sketch(tile)])
	var bad := false
	for kind: String in _kinds:
		var entry: Dictionary = _kinds[kind]
		var rate: float = float(entry["worked"]) / float(entry["tried"])
		print("%-22s %3d of %3d  (%.0f%%)" % [kind, entry["worked"], entry["tried"], rate * 100.0])
		if rate < MIN_RATE:
			bad = true
			for text: String in entry["failed"].slice(0, SHOW):
				print(text)
	print("FAIL  some moves do not work" if bad else "every kind of move works")
	get_tree().quit(1 if bad else 0)


func _kind(from: Vector2i, to: Vector2i) -> String:
	var across := absi(to.x - from.x)
	var up := from.y - to.y
	if across <= 1 and up >= -1 and up <= 1:
		return "walk" if up == 0 else ("step up" if up == 1 else "step down")
	if across <= 1 and up < -1:
		return "fall"
	return "jump %s %s" % ["up %d" % up if up > 0 else ("down" if up < 0 else "level"), "far" if across > 4 else "near"]


## A tile next to this one that leads to it by a walk, so that a move can be tried with a run-up; the tile itself when there is none.
func _before(tile: Vector2i) -> Vector2i:
	for step in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		var near: Vector2i = tile + step
		if _world.nav.can_stand(near) and _world.nav.moves(near).has(tile):
			return near
	return tile


## Sets the body at the start of a move and sees whether the route takes it to the end.
func _try(body: Wizard, from: Vector2i, to: Vector2i, trace := false) -> bool:
	var route := WizardRoute.new()
	body.velocity = Vector2.ZERO
	var before := _before(from)  # it comes to the start of the move as a wizard does: along the way, not set down on the spot
	body.global_position = Vector2((before.x + 0.5) * 32.0, (before.y + 1) * 32.0 - 1.0)
	var path: Array[Vector2i] = []
	if before != from:
		path.append(before)
	path.append(from)
	path.append(to)
	route.set_path(path)
	var delta := 1.0 / 60.0
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	for frame in int(SECONDS / delta):
		await get_tree().physics_frame
		var steer := route.steer(body, delta)
		if steer["jump"] and body.is_on_floor():
			body.velocity.y = -WizardRoute.JUMP_SPEED
		body.velocity.x = steer["dir"] * steer["speed"]
		body.velocity.y += gravity * delta
		body.move_and_slide()
		if trace and frame % 6 == 0:
			print("%3d  feet (%.2f, %.2f)  v (%d, %d)  floor %s  wall %s  %s" % [frame, body.global_position.x / 32.0, body.global_position.y / 32.0, body.velocity.x, body.velocity.y, body.is_on_floor(), body.is_on_wall(), route.status()])
		if route.done():
			return true
		if steer["replan"]:
			return false
	return false
