extends Node

## Two attacking spells, cast in a real world: Shadow Bolt (it bends toward a rival or a creature) and Hemorrhage (a wound that bleeds a little at a time).
##
##     godot --headless --fixed-fps 60 --path . tests/group_d_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World
var _player: Wizard
var _spot := Vector2.ZERO


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
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
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)  # or it carries the wizard back to where it began
	_spot = _player.global_position
	await _wait(0.5)
	await _shadow_bolt()
	await _hemorrhage()
	print("the attacking spells work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A dummy standing on the ground, this far from the wizard.
func _dummy(dx: float) -> Mob:
	var dummy: Mob = _world._add_mob("dummy", _spot + Vector2(dx, 0.0))
	dummy.max_hp = 500
	dummy.hp = 500
	return dummy


## Waits for the mobs just set down to finish arriving, which they do not feel a blow before.
func _arrive() -> void:
	await _wait(1.6)


func _cast(spell: String, targeting: String, aim: float, info := {}) -> void:
	var data := {"length": 90.0, "accuracy": 0.9}
	data.merge(info)
	_world.spawn_spell(spell, targeting, _player.center() + Vector2.from_angle(aim) * 12.0, aim, data, _player)


func _hurt(mob: Mob) -> int:
	return mob.max_hp - mob.hp


## The effects of one kind in the world.
func _made(kind: GDScript) -> Array:
	return _world.get_children().filter(func(n) -> bool: return is_instance_of(n, kind) and not n.is_queued_for_deletion())


func _shadow_bolt() -> void:
	var rival: Wizard = _world._rivals[0]
	rival.global_position = _spot + Vector2(320.0, -150.0)
	var before := rival.max_stamina
	await _wait(0.3)
	_cast("Shadow Bolt", "directional", 0.0)  # flung level, with the rival well above its line
	await _wait(2.5)
	_verdict(rival.max_stamina < before, "a bolt of darkness bends toward a rival and hurts them (%.0f to %.0f)" % [before, rival.max_stamina])
	rival.global_position = Vector2(-9000.0, -9000.0)
	var dummy := _dummy(300.0)
	await _arrive()
	_cast("Shadow Bolt", "directional", -0.45)  # flung up and away, with only a creature to bend toward
	await _wait(2.5)
	_verdict(_hurt(dummy) == ShadowBolt.HARM, "and it bends toward a creature too (%d hurt)" % _hurt(dummy))
	dummy.queue_free()


func _hemorrhage() -> void:
	var cut := _dummy(160.0)
	var away := _dummy(420.0)
	await _arrive()
	var wound := Hemorrhage.new()
	wound.target = cut
	_world.add_child(wound)
	await _wait(3.6)
	var hurt := _hurt(cut)
	_verdict(hurt >= Hemorrhage.HARM * 2 and hurt <= Hemorrhage.HARM * 5, "a wound bleeds a little at a time (%d hurt in a few seconds)" % hurt)
	await _wait(6.0)
	var total := _hurt(cut)
	_verdict(total <= Hemorrhage.HARM * (Hemorrhage.SECONDS + 1.0) and total > hurt, "and stops after a while (%d hurt in all)" % total)
	_verdict(_hurt(away) == 0, "and the one it did not cut is not hurt")
	_verdict(Hemorrhage.nearest_under(get_tree(), _spot + Vector2(0.0, -3000.0)) == null, "and a cut drawn over no one finds no one to bleed")
	cut.queue_free()
	away.queue_free()


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
