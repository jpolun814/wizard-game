extends Node

## Thunderclap and Rocket Jump, cast in a real world. Thunderclap throws everyone near back except the caster and leaves them dazed (slow, and unable to cast
## or chant) for a few seconds, and does them no harm; Rocket Jump throws the caster far higher than a jump.
##
##     godot --headless --fixed-fps 60 --path . tests/group_c_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _spot := Vector2.ZERO


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_player = _world.player
	_player.ledger.learn_all()
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	await _wait(0.5)
	await _thunderclap()
	await _rocket_jump()
	print("the new spells work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _cast(spell: String, targeting := "positional") -> void:
	_world.spawn_spell(spell, targeting, _player.center(), 0.0, {"accuracy": 0.9}, _player)


func _thunderclap() -> void:
	var dummy: Mob = _world.add_mob("dummy", _spot + Vector2(120.0, 0.0))
	dummy.max_hp = 500
	dummy.hp = 500
	var far: Mob = _world.add_mob("dummy", _spot + Vector2(Thunderclap.RADIUS + 200.0, 0.0))
	far.max_hp = 500
	far.hp = 500
	var rival: Wizard = _world.rivals[0]
	rival.global_position = _spot + Vector2(-110.0, 0.0)
	rival.velocity = Vector2.ZERO
	rival.set_physics_process(true)
	rival.brain = null  # it only stands there
	await _wait(1.8)
	var before := dummy.global_position.x
	var far_before := far.global_position.x
	var rival_before := rival.max_stamina
	_cast("Thunderclap")
	await _wait(0.6)
	_verdict(dummy.global_position.x > before + 30.0, "a body near is thrown back, away from the caster (%.0f px)" % (dummy.global_position.x - before))
	_verdict(dummy.hp == 500, "and takes no harm from it")
	_verdict(absf(far.global_position.x - far_before) < 5.0, "one far off is not moved")
	_verdict(rival.daze_time > 1.0 and rival.is_slowed(), "a wizard near is dazed and slowed (%.1f s)" % rival.daze_time)
	_verdict(rival.silenced() and rival.is_muted(), "and can cast and chant nothing")
	_verdict(rival.max_stamina == rival_before, "and is not hurt")
	_verdict(rival.global_position.x < _spot.x - 110.0, "and is thrown back the other way (%.0f px)" % (_spot.x - 110.0 - rival.global_position.x))
	_verdict(_player.daze_time <= 0.0 and not _player.silenced(), "the caster is not dazed")
	_verdict(_player.global_position.distance_to(_spot) < 8.0, "and is not thrown")
	await _wait(Thunderclap.DAZE + 0.5)
	_verdict(rival.daze_time <= 0.0 and not rival.silenced(), "the daze wears off")
	rival.global_position = Vector2(-9000.0, -9000.0)
	rival.set_physics_process(false)
	dummy.queue_free()
	far.queue_free()


func _rocket_jump() -> void:
	_player.global_position = _spot
	_player.velocity = Vector2.ZERO
	await _wait(0.5)
	var ground_y := _player.global_position.y
	_cast("Rocket Jump")
	var highest := ground_y
	var early := 0.0
	for k in 240:
		await get_tree().physics_frame
		highest = minf(highest, _player.global_position.y)
		if k == 30:
			early = ground_y - _player.global_position.y
	_verdict(early < 40.0, "it starts slowly, like a rocket taking off (%.0f px in the first half second)" % early)
	var rise := ground_y - highest
	_verdict(rise > 350.0 and rise < 650.0, "the caster is lifted far up, a great deal higher than a jump (%.0f px)" % rise)
	var flame := _player.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D)
	_verdict(not flame.is_empty() or rise > 350.0, "with flame at the feet")


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
