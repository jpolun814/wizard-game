extends Node

## Flaming Sphere, cast on a floor built for it: a long level floor, a low wall, a pit with a wall on its far side and a dummy standing past it. The ball
## must roll, climb the wall, drop into the pit and climb out of it, burn the dummy, go out in water, in rain and after a long roll. Add `-- out=DIR`
## for pictures (needs a window).
##
##     godot --headless --fixed-fps 60 --path . tests/sphere_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _spot := Vector2.ZERO
var _out := ""
var _cam: Camera2D
const LIFT := -700.0  # the course hangs high over the ground, so that the pit in it is a real pit


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	for rival in _world._rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	_player.ledger.learn_all()
	_build_course()
	_player.global_position = _spot + Vector2(0.0, LIFT - 30.0)
	_player.velocity = Vector2.ZERO
	await _wait(1.0)
	await _roll()
	print("the flaming sphere rolls" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _slab(x0: float, x1: float, top: float, thick := 40.0) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(x1 - x0, thick)
	shape.shape = box
	body.add_child(shape)
	body.collision_layer = 1
	body.position = _spot + Vector2((x0 + x1) * 0.5, LIFT + top + thick * 0.5)
	_world.add_child(body)


func _build_course() -> void:
	# Level floor from -200 to 700, a gap from 700 to 860 with a deep floor under it, then level floor to 1800. A wall of 90 at 380.
	_slab(-300.0, 700.0, 2.0, 240.0)
	_slab(860.0, 1800.0, 2.0, 240.0)
	_slab(700.0, 860.0, 200.0)
	_slab(374.0, 398.0, -88.0, 90.0)  # a wall 90 high
	# The far side of the pit is a wall of 200 on the lower floor's side: the slabs' edge at 860 already makes it.


func _ball() -> FlamingSphere:
	for n in _world.get_children():
		if n is FlamingSphere and not n._out:
			return n
	return null


func _roll() -> void:
	var dummy: Mob = _world.add_mob("dummy", _spot + Vector2(1100.0, LIFT))
	dummy.max_hp = 500
	dummy.hp = 500
	await _wait(1.6)
	_world.spawn_spell("Flaming Sphere", "directional", _player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, _player)
	var ball := _ball()
	_verdict(ball != null, "a ball of fire is launched")
	if ball == null:
		return
	_verdict(ball.is_in_group("fires") and ball.is_in_group("ground_watchers"), "it is a fire, and one the world keeps the ground round")
	var start_x := ball.global_position.x
	await _wait(1.0)
	_verdict(ball.global_position.x - start_x > 100.0, "it rolls along the ground (%.0f px in a second)" % (ball.global_position.x - start_x))
	await _shot("roll", ball)
	# The wall at 380.
	var cleared := false
	var peak := 0.0
	for k in 360:
		await get_tree().physics_frame
		peak = maxf(peak, _spot.y + LIFT - ball.global_position.y)
		if ball.global_position.x > _spot.x + 450.0:
			cleared = true
			break
	_verdict(cleared, "it climbs a wall in its way and rolls on over the top (rose %.0f px)" % peak)
	await _shot("wall", ball)
	_verdict(peak > 80.0, "it went up the face of the wall")
	# The pit.
	var fell := false
	for k in 360:
		await get_tree().physics_frame
		if ball.global_position.y > _spot.y + LIFT + 100.0:
			fell = true
			break
	_verdict(fell, "it falls into a pit")
	await _shot("pit", ball)
	var out := false
	for k in 600:
		await get_tree().physics_frame

		if ball.global_position.x > _spot.x + 900.0 and ball.global_position.y < _spot.y + LIFT + 20.0:
			out = true
			break
	_verdict(out, "and climbs out the far side (%.0f, %.0f)" % [ball.global_position.x - _spot.x, ball.global_position.y - _spot.y - LIFT])
	# It reaches the dummy and burns it.
	await _wait(2.5)
	_verdict(dummy.hp < dummy.max_hp, "it burns what it touches (%d hurt)" % (dummy.max_hp - dummy.hp))
	await _shot("burn", ball)
	# Water puts it out.
	_verdict(is_instance_valid(ball) and not ball._out, "it is still alight")
	_verdict(ball.get_children().any(func(child: Node) -> bool: return child is PointLight2D), "it lights the dark round it, as every fire does")
	SpellTargets.douse(get_tree(), ball.global_position, 40.0)
	await _wait(0.6)
	_verdict(not is_instance_valid(ball), "water puts it out")
	# Rain puts it out.
	_world.spawn_spell("Flaming Sphere", "directional", _player.center(), PI, {"length": 90.0, "accuracy": 0.9}, _player)
	ball = _ball()
	var squall := Squall.new()
	squall.rain = true
	squall.delay = 0.0
	squall.length = 100.0
	squall.period = 200.0
	squall.seconds = 20.0
	_world.add_child(squall)
	await _wait(0.5)
	_verdict(not is_instance_valid(ball) or ball._out, "rain puts it out")
	squall.queue_free()
	# A long roll wears it out.
	_world.spawn_spell("Flaming Sphere", "directional", _player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, _player)
	ball = _ball()
	ball._rolled = FlamingSphere.REACH - 5.0
	await _wait(0.6)
	_verdict(not is_instance_valid(ball) or ball._out, "after a long roll it burns out")
	# Drawn to the left it rolls left.
	_world.spawn_spell("Flaming Sphere", "directional", _player.center(), PI, {"length": 90.0, "accuracy": 0.9}, _player)
	ball = _ball()
	var left_from := ball.global_position.x
	await _wait(0.8)
	_verdict(ball.global_position.x < left_from - 60.0, "drawn to the left, it rolls left")
	ball.quench()


func _shot(label: String, ball: Node2D) -> void:
	if _out == "" or not is_instance_valid(ball):
		return
	if _cam == null:
		_cam = Camera2D.new()
		_cam.zoom = Vector2(1.5, 1.5)
		_world.add_child(_cam)
	_cam.global_position = ball.global_position + Vector2(0.0, -40.0)
	_cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().get_texture().get_image().save_png("%s/sphere_%s.png" % [_out, label])


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
