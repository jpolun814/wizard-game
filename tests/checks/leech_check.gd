extends Check
## Leech, cast in a real world. The tether needs a wizard in the way the stroke ran, in sight; it costs maximum stamina; while it holds the
## caster pays half of every stamina spell and the other end pays the rest; a wall, distance, a second Leech, or either wizard's death ends it.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/leech_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

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
	await _leech()
	print("leech works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _put_rival(dx: float) -> void:
	_rival.global_position = _spot + Vector2(dx, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.stamina = _rival.max_stamina


func _cast(spell: String, targeting: String, aim: float) -> void:
	_world.casting.by(spell, targeting, _player.center(), aim, {"length": 90.0, "accuracy": 0.9}, _player)


func _wall(dx: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24.0, 300.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.position = _spot + Vector2(dx, -140.0)
	_world.add_child(wall)
	return wall


func _tether() -> Leech:
	return Leech.held_by(get_tree(), _player)


func _leech() -> void:
	# Nobody in the way: refused, and nothing is paid.
	var max_before := _player.max_stamina
	_cast("Leech", "directional", 0.0)
	_verdict(_tether() == null and _player.max_stamina == max_before, "with no one in the way nothing is tethered or paid")
	# Behind the caster: not picked.
	_put_rival(-250.0)
	await _wait(0.3)
	_cast("Leech", "directional", 0.0)
	_verdict(_tether() == null, "a wizard behind the stroke is not picked")
	# In the way and in sight: tethered, and it costs maximum stamina.
	_put_rival(250.0)
	await _wait(0.3)
	_cast("Leech", "directional", 0.0)
	await _wait(0.1)
	_verdict(_tether() != null and _tether().target == _rival, "a wizard in the way is tethered")
	_verdict(_player.max_stamina < max_before, "and it costs maximum stamina (%.0f)" % (max_before - _player.max_stamina))
	# The split.
	_player.stamina = _player.max_stamina
	_rival.stamina = _rival.max_stamina
	var cost: float = SpellData.SPELLS["Ignite"].cost_for({"length": 90.0, "accuracy": 0.9})
	var mine := _player.stamina
	var theirs := _rival.stamina
	_cast("Ignite", "directional", PI)  # aimed away from them
	var paid := mine - _player.stamina
	var taken := theirs - _rival.stamina
	_verdict(is_equal_approx(paid, cost * 0.5), "the caster pays half of a spell (%.1f of %.1f)" % [paid, cost])
	_verdict(is_equal_approx(taken, cost * 0.5), "and the other end pays the other half (%.1f)" % taken)
	# A wall breaks it.
	var wall := _wall(120.0)
	await _wait(0.4)
	_verdict(_tether() == null, "a wall between them breaks the tether")
	wall.queue_free()
	await _wait(0.2)
	# Whole cost again once it is broken.
	_player.stamina = _player.max_stamina
	mine = _player.stamina
	_cast("Ignite", "directional", PI)
	_verdict(is_equal_approx(mine - _player.stamina, cost), "with no tether the caster pays it all (%.1f)" % (mine - _player.stamina))
	# Distance breaks it.
	_player.stamina = _player.max_stamina
	_put_rival(250.0)
	await _wait(0.3)
	_cast("Leech", "directional", 0.0)
	await _wait(0.1)
	_verdict(_tether() != null, "a second tether can be made")
	_put_rival(Leech.REACH + 120.0)
	await _wait(0.4)
	_verdict(_tether() == null, "too far apart breaks it")
	# Two at once: a new one replaces the old.
	_put_rival(250.0)
	await _wait(0.3)
	_cast("Leech", "directional", 0.0)
	await _wait(0.1)
	_cast("Leech", "directional", 0.0)
	await _wait(0.2)
	_verdict(get_tree().get_nodes_in_group("leeches").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size() == 1, "a new tether replaces the old")
	# Death breaks it.
	_rival.dead = true
	await _wait(0.3)
	_verdict(_tether() == null, "the death of the other end breaks it")
	_rival.dead = false
	# It does not last for ever.
	_put_rival(250.0)
	await _wait(0.3)
	_cast("Leech", "directional", 0.0)
	await _wait(0.1)
	_tether()._age = Leech.LONGEST - 0.1
	await _wait(0.4)
	_verdict(_tether() == null, "and it does not last for ever")
	# Too weak: refused when it would take the last of the maximum.
	_player.max_stamina = 20.0
	_player.stamina = 20.0
	_cast("Leech", "directional", 0.0)
	_verdict(_tether() == null and _player.max_stamina == 20.0, "a cast that would take the last of the maximum is refused")


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


