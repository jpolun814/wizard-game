extends Check
## Oil Slick and Water Jet, and what they do with the states on a body (see Coating): a slick oils and slows whoever crosses it, a fire sets the whole slick off and
## whoever is in it burns twice as long, a Water Jet pushes a wizard back and leaves them wet, puts out a burning one and washes a slick away.
##
##     godot --headless --path . --fixed-fps 60 tests/checks/combo_check.tscn

var _caster: Wizard
var _target: Wizard
var _world: World
var _spot: Vector2


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	var person: Wizard = _world.player
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found == person:
			continue
		if _target == null:
			_target = found
		elif _caster == null:
			_caster = found
		else:
			found.set_physics_process(false)
			found.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.set_physics_process(false)
		mob.global_position = Vector2(-9000.0, -9000.0)
	_spot = person.global_position
	person.set_physics_process(false)
	person.global_position = Vector2(-9000.0, -9500.0)
	_world.set_process(false)
	_target.brain = null
	_caster.brain = null
	await _reset()

	# An oil slick oils and slows whoever stands in it.
	_slick(_target.global_position, 160.0)
	await _frames(20)
	_verdict(_target.is_oiled(), "a wizard standing in an oil slick is oiled")
	_verdict(OilSlick.under(get_tree(), _target.global_position) and _target.slow_time <= 0.0, "which makes the ground slippery, not slow")

	# A fire near it sets it all off, and the wizard in it burns, twice as long for the oil.
	Hazard.place(_world, _target.global_position + Vector2(70.0, 0.0), 60.0, 2.0)
	await _frames(12)
	_verdict(get_tree().get_nodes_in_group("oil_slicks").is_empty(), "a fire sets the whole slick off")
	_verdict(_target.is_burning(), "and the wizard in it is alight")
	_verdict(_target.burning_time > Coating.BURN_SECONDS * 1.5, "burning longer for the oil (%.1f s)" % _target.burning_time)

	# A Water Jet puts them out, leaves them wet and pushes them back.
	await _reset()
	_target.coat.ignite()
	var start_x := _target.global_position.x
	_jet(_target)
	await _frames(40)
	_verdict(not _target.is_burning(), "a Water Jet puts out a burning wizard")
	_verdict(_target.is_wet(), "and leaves them wet")
	_verdict(_target.global_position.x - start_x > 20.0, "and pushes them back (%.0f px)" % (_target.global_position.x - start_x))
	_verdict(_target.max_stamina >= 199.0, "and does no harm (%.0f of 200 left)" % _target.max_stamina)

	# A Water Jet washes an oil slick away.
	await _reset()
	_slick(_target.global_position + Vector2(90.0, 0.0), 160.0)
	await _frames(10)
	_jet(_target)
	await _frames(40)
	_verdict(get_tree().get_nodes_in_group("oil_slicks").is_empty(), "a Water Jet washes an oil slick away")

	print("water, oil and fire work together" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _slick(at: Vector2, width: float) -> void:
	var line := PackedVector2Array([at + Vector2(-width * 0.5, -10.0), at + Vector2(width * 0.5, -10.0)])
	_world.spawn_spell("Oil Slick", "shape", at, 0.0, {"line": line}, _caster)


func _jet(target: Wizard) -> void:
	_world.spawn_spell("Water Jet", "cone", _caster.center(), (target.center() - _caster.launch_tip()).angle(), {"spread": 0.5, "reach": 230.0}, _caster)  # (the water leaves the gem of the staff: it is aimed from there)


func _reset() -> void:
	for node in get_tree().get_nodes_in_group("lasting"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("fires"):
		if node is Hazard:
			node.queue_free()
	for body: Wizard in [_target, _caster]:
		body.wet_time = 0.0
		body.burning_time = 0.0
		body.oiled_time = 0.0
		body.slow_time = 0.0
		body.max_stamina = 200.0
		body.stamina = 200.0
		body.velocity = Vector2.ZERO
		body.walk(0.0)
	_caster.global_position = _spot
	_caster.facing = 1.0
	_target.global_position = _spot + Vector2(150.0, 0.0)
	await _frames(60)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
