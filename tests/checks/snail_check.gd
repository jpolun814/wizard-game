extends Check
## The Immortal Snail: drawn over a wizard it crawls after them, slowly, and kills with a touch; nothing hurts it; it fades when the one it hunts is gone; and one that
## was crawling arrives in the exact middle of the next world.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/snail_check.tscn

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
	var prey: Wizard = _world.rivals[0]
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	_world.set_process(false)
	await _wait(0.5)
	prey.global_position = _player.global_position + Vector2(200.0, 0.0)
	await _wait(0.3)
	_world.spawn_spell("Immortal Snail", "positional", prey.center(), 0.0, {"radius": 30.0, "accuracy": 0.9}, _player)
	await _wait(0.3)
	var snails := get_tree().get_nodes_in_group("snails")
	_verdict(snails.size() == 1, "one snail crawls after the one it was drawn over")
	if snails.size() != 1:
		get_tree().quit(1)
		return
	var snail: InvincibleSnail = snails[0]
	_verdict(snail.target == prey, "and it hunts that wizard")
	var before := snail.global_position.x
	await _wait(1.0)
	var pace := absf(snail.global_position.x - before)
	_verdict(pace > 35.0 and pace < 65.0, "it crawls at a sixth of a walk (%.0f px in a second)" % pace)
	SpellTargets.hurt(snail, 500, "Blood")
	_verdict(is_instance_valid(snail) and not snail._fading, "nothing hurts it")
	var carried := InvincibleSnail.carry_on(_world)
	_verdict(carried.size() == 1 and carried[0]["seat"] == _world.seats.find(prey), "it is carried on to the next world, hunting the same seat")
	MatchState.snails = carried
	var mid := ArenaGen.world_size.x * World.TILE * 0.5
	InvincibleSnail.arrive(_world)
	var arrived := get_tree().get_nodes_in_group("snails").filter(func(n) -> bool: return absf(n.global_position.x - mid) < World.TILE)
	_verdict(arrived.size() >= 1, "one that was crawling arrives in the exact middle of a new world")
	await _wait(6.0)
	_verdict(not is_instance_valid(prey) or prey.dead, "a touch kills at once")
	await _wait(1.2)
	_verdict(get_tree().get_nodes_in_group("snails").is_empty(), "and the snails fade when the one they hunted is gone")
	print("the snail crawls, kills and goes" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()
