extends Node

## Raise Dead, cast in a real world. A skeleton rises with fifty health for thirty-seven of the caster's maximum stamina; it never touches its master,
## attacks a rival wizard, fights the skeleton another wizard raised, stays near its master, and falls when its master is beaten.
##
##     godot --headless --fixed-fps 60 --path . tests/raise_dead_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
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
	for rival in _world._rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	_rival = _world._rivals[0]
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)
	_spot = _player.global_position
	_player.ledger.learn_all()
	_rival.ledger.learn_all()
	await _wait(0.5)
	await _raise()
	print("raise dead works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _cast_by(who: Wizard, at: Vector2) -> void:
	_world.cast_by("Raise Dead", "positional", at, 0.0, {"accuracy": 0.9}, who)


func _risen_of(who: Wizard) -> Array:
	var out := []
	for mob: Mob in get_tree().get_nodes_in_group("mobs"):
		if mob.master == who and not mob.is_dead():
			out.append(mob)
	return out


func _clear_risen() -> void:
	for mob: Mob in get_tree().get_nodes_in_group("mobs"):
		if mob.master != null:
			mob.queue_free()
	await _wait(0.2)


func _raise() -> void:
	var before := _player.max_stamina
	_cast_by(_player, _spot + Vector2(80.0, 0.0))
	await _wait(0.2)
	var mine := _risen_of(_player)
	_verdict(mine.size() == 1, "a skeleton rises")
	_verdict(is_equal_approx(before - _player.max_stamina, 37.0), "for thirty-seven of the maximum (%.0f)" % (before - _player.max_stamina))
	if mine.is_empty():
		return
	var skeleton: Mob = mine[0]
	_verdict(skeleton.hp == 50 and skeleton.max_hp == 50, "with fifty health")
	# It never attacks its master, even right beside them for a good while.
	_player.global_position = skeleton.global_position + Vector2(-30.0, 0.0)
	var stamina_before := _player.max_stamina
	await _wait(5.0)
	_verdict(_player.max_stamina == stamina_before and not _player.dead, "it never strikes its master (%.0f lost)" % (stamina_before - _player.max_stamina))
	# It stays near its master.
	var floor_slab := StaticBody2D.new()  # level ground to walk to (the ground there may be a pit or a slope)
	var floor_shape := CollisionShape2D.new()
	var floor_box := RectangleShape2D.new()
	floor_box.size = Vector2(1400.0, 40.0)
	floor_shape.shape = floor_box
	floor_slab.add_child(floor_shape)
	floor_slab.collision_layer = 1
	floor_slab.position = _spot + Vector2(300.0, 22.0)
	_world.add_child(floor_slab)
	_player.global_position = _spot + Vector2(500.0, 0.0)
	await _wait(5.0)
	_verdict(skeleton.global_position.distance_to(_player.global_position) < 260.0, "it follows its master (%.0f px off)" % skeleton.global_position.distance_to(_player.global_position))
	# It goes for a rival wizard.
	_rival.global_position = skeleton.global_position + Vector2(260.0, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.max_stamina = 200.0
	await _wait(0.4)
	_rival.set_physics_process(true)
	var waited := 0.0
	while _rival.max_stamina >= 200.0 and waited < 14.0:  # (the rival's own brain may walk off first, and the skeleton must catch it up)
		await _wait(0.5)
		waited += 0.5
	_verdict(_rival.max_stamina < 200.0, "it attacks a rival wizard (%.0f lost)" % (200.0 - _rival.max_stamina))
	_rival.set_physics_process(false)
	_rival.global_position = Vector2(-9000.0, -9000.0)
	await _clear_risen()
	_player.thaw()  # (the rival, with every spell, may have frozen the person who stood by its skeleton)
	_player.fainted = false
	if _rival.dead:
		_rival.revive()  # (the skeleton may have felled it)
	# Two masters' dead fight each other.
	_player.global_position = _spot
	_player.max_stamina = 200.0
	_rival.global_position = _spot + Vector2(300.0, 0.0)
	_rival.max_stamina = 200.0
	await _wait(0.3)
	_cast_by(_player, _spot + Vector2(60.0, 0.0))
	_cast_by(_rival, _spot + Vector2(240.0, 0.0))
	await _wait(0.2)
	for tries in 5:  # (a cast may be refused while the wizard is still busy with the last)
		if not _risen_of(_rival).is_empty() and not _risen_of(_player).is_empty():
			break
		for who: Wizard in [_player, _rival]:
			if _risen_of(who).is_empty():
				who.max_stamina = 200.0  # (a cast that was only slow to show must not be paid for twice)
				who.stamina = who.max_stamina
				_cast_by(who, _spot + Vector2(60.0 if who == _player else 240.0, 0.0))
		await _wait(0.3)
	var a: Mob = _risen_of(_player)[0]
	var b: Mob = _risen_of(_rival)[0]
	await _wait(8.0)
	var a_gone := not is_instance_valid(a) or a.is_dead()  # (a fallen skeleton is freed)
	var b_gone := not is_instance_valid(b) or b.is_dead()
	var hurt := (50 - a.hp if not a_gone else 50) + (50 - b.hp if not b_gone else 50)
	_verdict(hurt > 0 and (a_gone or a.hp < 50 or b_gone or b.hp < 50), "skeletons of different masters fight each other (%d hurt)" % hurt)
	# (A skeleton goes for another master's wizard as well as for its skeletons, so what a master loses to the other's is not looked at; that it never strikes its own is, above.)
	await _clear_risen()
	# The master's end is theirs.
	for tries in 5:  # (a cast may be refused while the wizard is still busy with the last)
		_player.max_stamina = 200.0
		_player.stamina = 200.0
		_cast_by(_player, _spot + Vector2(80.0, 0.0))
		await _wait(0.3)
		if not _risen_of(_player).is_empty():
			break
	var doomed: Mob = _risen_of(_player)[0]
	_player.dead = true
	await _wait(1.5)
	_verdict(not is_instance_valid(doomed) or doomed.is_dead(), "when the master is beaten the skeleton falls")
	_player.dead = false
	await _clear_risen()
	# The maximum is the limit: at two hundred, five can be raised and a sixth is refused.
	_player.max_stamina = 200.0
	for k in 7:
		_cast_by(_player, _spot + Vector2(60.0 + 20.0 * k, 0.0))
		await _wait(0.1)
	_verdict(_risen_of(_player).size() == 5, "at two hundred five can be raised and no more (%d)" % _risen_of(_player).size())
	_verdict(_player.max_stamina > 0.0 and _player.max_stamina < 37.0, "and the last of the maximum is never spent (%.0f left)" % _player.max_stamina)
	# Not refunded when one is destroyed.
	var left := _player.max_stamina
	var one: Mob = _risen_of(_player)[0]
	one.hp = 1
	one.take_damage(5)
	await _wait(0.3)
	_verdict(_player.max_stamina == left, "nothing is given back when one is destroyed")


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
