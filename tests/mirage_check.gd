extends Node

## Mirage, cast in a real world. A false page appears among the real ones; every wizard wants it; it fades when anyone comes near, the caster too,
## and cannot be read; a brain that has watched one fade stops going for them.
##
##     godot --headless --fixed-fps 60 --path . tests/mirage_check.tscn
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
	await _mirage()
	print("mirage works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _mirages() -> Array:
	return get_tree().get_nodes_in_group("pages").filter(func(n): return n is Mirage and is_instance_valid(n) and not n.is_queued_for_deletion())


func _cast(dx: float) -> void:
	_world.cast_by("Mirage", "positional", _spot + Vector2(dx, 0.0), 0.0, {"accuracy": 0.9}, _player)


func _mirage() -> void:
	_cast(500.0)
	await _wait(0.3)
	var found := _mirages()
	_verdict(found.size() == 1, "a mirage appears")
	if found.is_empty():
		return
	var mirage: Mirage = found[0]
	_verdict(mirage.gives(_player.ledger) and mirage.gives(Ledger.of([])), "and every wizard wants it, whatever they hold (even one who has read every page)")
	await _wait(2.0)
	_verdict(is_instance_valid(mirage) and not mirage.is_queued_for_deletion(), "it stays while no one is near")
	# Walking up to it makes it fade, the caster included.
	_player.global_position = mirage.global_position + Vector2(-400.0, 0.0)
	await _wait(0.3)
	_player.global_position = mirage.global_position + Vector2(-110.0, 0.0)
	await _wait(0.3)
	_verdict(mirage.is_solid(), "it does not fade for someone only fairly near")
	_stand_at(_player, mirage, -10.0)
	await _wait(0.2)
	_verdict(not mirage.is_solid(), "it shimmers away once someone is right up to it")
	await _wait(0.2)
	_verdict(_mirages().is_empty(), "it fades when its caster comes near")
	await _wait(2.0)
	_verdict(get_tree().get_nodes_in_group("pages").is_empty(), "and it is not there to be had while someone stands at it")
	_player.global_position = mirage.global_position + Vector2(-500.0, 0.0)
	_player.velocity = Vector2.ZERO
	await _wait(3.5)
	_verdict(_mirages().size() == 1 and mirage.is_solid(), "it shimmers back in once everyone has left, and then stands steady")
	_verdict(is_equal_approx(mirage.modulate.a, 0.85), "steady, it does not shimmer")
	mirage._age = Mirage.LIFE - 0.1
	await _wait(2.5)
	_verdict(not is_instance_valid(mirage) or mirage.is_queued_for_deletion(), "after its time it shimmers out for good")
	# A rival wizard fades one too, and a brain nearby learns.
	_player.global_position = _spot
	_cast(300.0)
	await _wait(0.3)
	mirage = _mirages()[0]
	_stand_at(_rival, mirage, -10.0)
	_rival.velocity = Vector2.ZERO
	await _wait(0.3)
	_verdict(_mirages().is_empty(), "it fades when a rival comes near")
	_verdict(_rival.brain.wise_to_mirages, "and the brain that watched it learns the waver")
	# A wise brain does not go for the next, while an unwise one does.
	_rival.global_position = _spot + Vector2(-9000.0, 0.0) + Vector2(9000.0, 0.0)
	_cast(250.0)
	await _wait(0.3)
	mirage = _mirages()[0]
	_rival.global_position = _spot + Vector2(400.0, 0.0)  # near enough to see it on the screen, too far for it to waver
	_rival.velocity = Vector2.ZERO
	await _wait(0.6)
	_rival.brain.travel.choose_goal()
	_verdict(_rival.brain.goal != "page" or _rival.brain.travel.goal_page != mirage, "a brain that has seen one fade does not go for the next")
	_rival.brain.wise_to_mirages = false
	_rival.brain.skip.clear()
	_rival.brain.travel.choose_goal()
	_verdict(_rival.brain.goal == "page" and _rival.brain.travel.goal_page == mirage, "but one that has not does")
	# It cannot be read.
	_verdict(mirage.take(_player.ledger) == "", "reaching it reads nothing")
	_verdict(not mirage.is_in_group("pages") and not mirage.is_solid(), "and it is gone from sight (the earlier ones have come back, as they should)")


## Puts a wizard's middle this far to the side of a mirage's heart, level with it.
func _stand_at(wizard: Wizard, mirage: Mirage, dx: float) -> void:
	var heart := mirage.global_position + Vector2(dx, -PagePickup.FLOAT)
	wizard.global_position += heart - SpellTargets.center_of(wizard)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
