extends Check
## The Flytrap swallows whoever steps on it: they vanish into its mouth, are held, then spat out in front of it, visible again. If the plant goes
## while it holds someone, they are put back.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/flytrap_check.tscn

var _world: World
var _player: Wizard


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	_world.set_process(false)
	await _wait(0.5)
	var spot := _player.global_position + Vector2(200.0, 0.0)
	var dummy: Mob = _world.add_mob("dummy", spot)
	dummy.max_hp = 500
	dummy.hp = 500
	await _wait(1.6)
	_world.spawn_spell("Flytrap", "positional", dummy.global_position, 0.0, {"length": 90.0, "accuracy": 0.9}, _player)
	await _wait(1.2)
	_verdict(not dummy.visible, "whoever steps on the plant is swallowed: gone from sight")
	await _wait(Flytrap.HOLD_SECONDS + 0.8)
	_verdict(dummy.visible, "and is spat back out, in sight again")
	var trap: Node = null
	for node in get_tree().get_nodes_in_group("danger"):
		if node is Flytrap:
			trap = node
	_verdict(trap == null or trap._state != "holding", "the plant has let go")
	print("the flytrap swallows and spits out" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
