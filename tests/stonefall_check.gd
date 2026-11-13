extends Node

## A Stonefall's boulder starts where the circle was drawn (not above it), and hits as hard as it was falling: drawn high it lands hard on whoever is under it,
## drawn low it hardly hurts, and drawn on the ground it only lies there.
## (The dummy under it is 70 px tall, so a boulder drawn that far over its feet does not fall at all.)
##
##     godot --headless --path . --fixed-fps 60 tests/stonefall_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 0  # a jungle, with level ground to start on
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
	_world.set_process(false)
	_player.ledger.learn_all()
	var ground := _world.ground_below(Vector2(_player.global_position.x + 300.0, _player.global_position.y - 200.0))
	var high := await _drop(ground, 420.0)
	var low := await _drop(ground, 160.0)
	var none := await _drop(ground, 8.0)
	_verdict(high > low and low > none, "the higher it was drawn, the harder it lands (%d, %d and %d hurt)" % [high, low, none])
	_verdict(high >= 30 and low >= 8, "a boulder drawn high hits hard, a lower one still hurts (%d, %d)" % [high, low])
	_verdict(none <= 6, "one drawn on the ground hardly hurts (%d hurt)" % none)
	var start := ground + Vector2(0.0, -250.0)
	_world.spawn_spell("Stonefall", "positional", start, 0.0, {}, _player)
	var boulder := _newest_boulder()
	_verdict(boulder != null and boulder.global_position.distance_to(start) < 12.0, "it starts where the circle was drawn, not above it (%s)" % (str(boulder.global_position - start) if boulder != null else "none"))
	print("stonefall hits by the fall" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Draws a boulder `height` px over the ground at `at`, with a dummy under it, and says how much it hurt the dummy.
func _drop(at: Vector2, height: float) -> int:
	var dummy: Mob = _world._add_mob("dummy", at)
	dummy.max_hp = 1000
	dummy.hp = 1000
	for f in 90:
		await get_tree().physics_frame  # (a new creature takes no harm for a moment)
	_world.spawn_spell("Stonefall", "positional", at + Vector2(0.0, -height), 0.0, {}, _player)
	var lowest := dummy.hp
	for f in 150:
		await get_tree().physics_frame
		lowest = mini(lowest, dummy.hp)  # (a practice dummy mends itself when left alone)
	var hurt := dummy.max_hp - lowest
	dummy.queue_free()
	var boulder := _newest_boulder()
	if boulder != null:
		boulder.queue_free()
	await get_tree().physics_frame
	return hurt


func _newest_boulder() -> Boulder:
	var found: Boulder = null
	for rock in get_tree().get_nodes_in_group("rocks"):
		if rock is Boulder and not rock.is_queued_for_deletion():
			found = rock
	return found


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
