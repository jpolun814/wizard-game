extends Check
## Golem, cast in a real world. A golem of stone stands up for the caster at a cost of stamina, never strikes its master, follows them, goes for a rival wizard,
## is replaced by the next one the same wizard makes, and falls when its master is beaten.
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


func _golems_of(who: Wizard) -> Array:
	var out := []
	for mob: Mob in get_tree().get_nodes_in_group("mobs"):
		if mob.master == who and mob.kind == "golem" and not mob.is_dead():
			out.append(mob)
	return out


func _cast(at: Vector2) -> void:
	_world.casting.by("Golem", "positional", at, 0.0, {"accuracy": 0.9}, _player)


func _run() -> void:
	var before := _player.stamina
	_cast(_spot + Vector2(80.0, 0.0))
	await _wait(0.3)
	var mine := _golems_of(_player)
	_verdict(mine.size() == 1, "a golem stands up")
	_verdict(before - _player.stamina >= 80.0, "for a good deal of stamina (%.0f)" % (before - _player.stamina))
	if mine.is_empty():
		return
	var golem: Mob = mine[0]
	_verdict(golem.hp == 140, "with a hundred and forty health (%d)" % golem.hp)
	_player.global_position = golem.global_position + Vector2(-30.0, 0.0)
	var held := _player.max_stamina
	await _wait(4.0)
	_verdict(_player.max_stamina == held and not _player.dead, "it never strikes its master")
	_rival.global_position = golem.global_position + Vector2(200.0, 0.0)
	_rival.velocity = Vector2.ZERO
	_rival.max_stamina = 200.0
	await _wait(0.4)
	_rival.set_physics_process(true)
	var waited := 0.0
	while _rival.max_stamina >= 200.0 and waited < 14.0:
		await _wait(0.5)
		waited += 0.5
	_verdict(_rival.max_stamina < 200.0, "it goes for a rival wizard (%.0f lost)" % (200.0 - _rival.max_stamina))
	_rival.set_physics_process(false)
	_rival.global_position = Vector2(-9000.0, -9000.0)
	_player.stamina = _player.max_stamina
	_player.thaw()
	_player.fainted = false
	_cast(_spot + Vector2(120.0, 0.0))
	await _wait(0.4)
	_verdict(_golems_of(_player).size() == 1, "a second one replaces the first (%d)" % _golems_of(_player).size())
	var doomed: Mob = _golems_of(_player)[0] if not _golems_of(_player).is_empty() else null
	_player.dead = true
	await _wait(1.5)
	_verdict(doomed == null or not is_instance_valid(doomed) or doomed.is_dead(), "when the master is beaten the golem falls")
	_player.dead = false


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
