extends Check
## Golem, cast in a real world. The wizard is covered in the stone of the world they stand in: it costs stamina, they cannot cast or jump, they are slow,
## they take half of every blow, a slam hits hard, the stone is the world's own ground, and it falls away with time, a Faint or a new world.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/golem_check.tscn

var _world: World
var _player: Wizard
var _rival: Wizard
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
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	_rival = _world.rivals[0]
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	_player.ledger.learn_all()
	await _wait(0.5)
	await _run()
	print("golem works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	var before := _player.stamina
	_world.casting.by("Golem", "caster", _spot, 0.0, {"accuracy": 0.9}, _player)
	await _wait(0.3)
	_verdict(_player.golem.on and _player.shifted(), "the wizard is covered in stone")
	_verdict(before - _player.stamina >= 55.0 and before - _player.stamina <= 65.0, "for a good deal of stamina (%.0f)" % (before - _player.stamina))
	_verdict(_player.silenced(), "and cannot cast")
	var material: ShaderMaterial = _player._sprite.material
	_verdict(material.get_shader_parameter("stone") == 1.0 and material.get_shader_parameter("ground") == _world.earth_texture(), "the stone is the very ground of this world")
	var held := _player.max_stamina
	_player.take_damage(20, true)
	_verdict(held - _player.max_stamina == 10.0, "it takes half of a blow (%.0f of 20)" % (held - _player.max_stamina))
	_player.facing = 1.0
	_player.global_position = _spot
	_player.velocity = Vector2.ZERO
	await _wait(0.4)
	Input.action_press("jump")
	var rose := false
	for k in 20:
		await get_tree().physics_frame
		rose = rose or _player.velocity.y < -50.0
	Input.action_release("jump")
	_verdict(not rose, "and cannot jump")
	_rival.global_position = _player.global_position + Vector2(60.0, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.max_stamina = 200.0
	_rival.stamina = 200.0
	_player.facing = 1.0
	_player.golem.slam()
	await _wait(0.8)
	_verdict(200.0 - _rival.max_stamina >= 35.0, "a slam hits hard (%.0f lost)" % (200.0 - _rival.max_stamina))
	_rival.global_position = Vector2(-9000.0, -9000.0)
	_player.golem.end()
	_verdict(not _player.golem.on and material.get_shader_parameter("stone") == 0.0 and not _player.silenced(), "when it ends the wizard is as they were")

	_player.thaw()
	_player.fainted = false
	_player.stamina = _player.max_stamina
	_player.golem.begin()
	await _wait(GolemForm.DURATION + 1.0)
	_verdict(not _player.golem.on, "it wears off with time")
	_player.stamina = _player.max_stamina
	_player.golem.begin()
	_player.faint()
	await _wait(0.2)
	_verdict(not _player.golem.on, "a Faint brings the stone down")
	_player.fainted = false


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
