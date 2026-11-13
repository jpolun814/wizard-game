extends Node

## The first four new spells, cast in a real world against a dummy: Barbs (thorns that hurt, are stopped by a wall and are burned by a flame),
## Pebble (a stone that falls as it flies, and so goes over a wall that stops a flat shot), Hailstorm (stones fall from a cloud and a roof is
## shelter) and Featherfall (a long fall becomes a slow one, and ends).
##
##     godot --headless --fixed-fps 60 --path . tests/group_a_check.tscn
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
	for rival in _world.rivals:
		rival.set_physics_process(false)
		rival.global_position = Vector2(-9000.0, -9000.0)
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	_world.set_process(false)  # or it carries the wizard back to where it began
	_spot = _player.global_position
	await _wait(0.5)
	await _barbs()
	await _pebble()
	await _hailstorm()
	await _featherfall()
	print("the first new spells work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A dummy standing on the ground, this far from the wizard.
func _dummy(dx: float) -> Mob:
	var dummy: Mob = _world.add_mob("dummy", _spot + Vector2(dx, 0.0))
	dummy.max_hp = 500
	dummy.hp = 500
	return dummy


## Waits for the mobs just set down to finish arriving, which they do not feel a blow before.
func _arrive() -> void:
	await _wait(1.6)


func _wall(dx: float, height: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24.0, height)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.position = _spot + Vector2(dx, 4.0 - height * 0.5)
	_world.add_child(wall)
	return wall


func _cast(spell: String, targeting: String, aim: float, info := {}) -> void:
	var data := {"length": 90.0, "accuracy": 0.9}
	data.merge(info)
	_world.spawn_spell(spell, targeting, _player.center() + Vector2.from_angle(aim) * 12.0, aim, data, _player)


func _barbs() -> void:
	var dummy := _dummy(160.0)
	await _arrive()
	_cast("Barbs", "directional", 0.0)
	await _wait(0.8)
	var hurt: int = dummy.max_hp - dummy.hp
	_verdict(hurt >= Thorn.HARM and hurt % Thorn.HARM == 0, "a volley of thorns hurts what it reaches (%d)" % hurt)
	_verdict(hurt <= Thorn.HARM * Barbs.COUNT, "and no thorn hurts twice (%d at most %d)" % [hurt, Thorn.HARM * Barbs.COUNT])
	dummy.hp = dummy.max_hp
	var wall := _wall(70.0, 220.0)
	await _wait(0.2)
	_cast("Barbs", "directional", 0.0)
	await _wait(0.8)
	_verdict(dummy.hp == dummy.max_hp, "a wall stops thorns (%d hurt)" % (dummy.max_hp - dummy.hp))
	wall.queue_free()
	await _wait(0.2)
	var flame := Hazard.place(_world, _spot + Vector2(90.0, 14.0), 120.0, 5.0)
	_cast("Barbs", "directional", 0.0)
	await _wait(0.8)
	_verdict(dummy.hp == dummy.max_hp, "and a flame burns them up in the air (%d hurt)" % (dummy.max_hp - dummy.hp))
	if is_instance_valid(flame):
		flame.queue_free()
	_verdict(get_tree().get_nodes_in_group("shots").is_empty(), "no thorn is left flying")
	dummy.queue_free()
	# A rival wizard at close range takes the thorns that find it one after another, not only the first.
	var rival: Wizard = _world.rivals[0]
	rival.global_position = _spot + Vector2(40.0, 0.0)
	rival.velocity = Vector2.ZERO
	var before := rival.max_stamina
	await _wait(0.2)
	_cast("Barbs", "directional", 0.0)
	await _wait(0.6)
	var lost := before - rival.max_stamina
	_verdict(lost > Thorn.HARM and int(lost) % Thorn.HARM == 0, "at close range several thorns land on a wizard (%d of at most %d)" % [lost, Thorn.HARM * Barbs.COUNT])
	rival.global_position = Vector2(-9000.0, -9000.0)


func _pebble() -> void:
	var dummy := _dummy(260.0)
	await _arrive()
	# Aimed as the brain aims it: above the dummy by as far as the stone falls on the way.
	var start: Vector2 = _player.center() + Vector2(12.0, 0.0)
	var flight: float = start.distance_to(dummy.center()) / Pebble.SPEED
	var aim: float = (dummy.center() - Vector2(0.0, 0.5 * Pebble.FALL * flight * flight) - start).angle()
	_cast("Pebble", "directional", aim)
	await _wait(1.2)
	_verdict(dummy.max_hp - dummy.hp == Pebble.HARM, "a lobbed pebble hits and hurts (%d hurt)" % (dummy.max_hp - dummy.hp))
	dummy.queue_free()
	# A flat throw is stopped by a low wall; a lob goes over it and lands beyond.
	var wall := _wall(150.0, 60.0)
	var lob_aim := -0.3
	var velocity := Vector2.from_angle(lob_aim) * Pebble.SPEED
	var time := -2.0 * velocity.y / Pebble.FALL  # in the air until it is back at the height it left from
	var lands := velocity.x * time
	var floor_slab := StaticBody2D.new()  # level ground to land on, whatever the land is like out there
	var floor_shape := CollisionShape2D.new()
	var floor_box := RectangleShape2D.new()
	floor_box.size = Vector2(400.0, 40.0)
	floor_shape.shape = floor_box
	floor_slab.add_child(floor_shape)
	floor_slab.collision_layer = 1
	floor_slab.position = _spot + Vector2(lands, 20.0 + 2.0)
	_world.add_child(floor_slab)
	var beyond := _dummy(lands + 12.0)
	await _arrive()
	_cast("Pebble", "directional", 0.0)
	await _wait(1.5)
	_verdict(beyond.hp == beyond.max_hp, "a flat throw is stopped by a low wall (%d hurt)" % (beyond.max_hp - beyond.hp))
	_cast("Pebble", "directional", lob_aim)
	await _wait(2.5)
	_verdict(beyond.max_hp - beyond.hp == Pebble.HARM, "a lob goes over it and lands beyond (%d hurt, landing %.0f px off)" % [beyond.max_hp - beyond.hp, lands])
	wall.queue_free()
	floor_slab.queue_free()
	beyond.queue_free()


func _hailstorm() -> void:
	var open := _dummy(150.0)
	var sheltered := _dummy(250.0)
	var roof := StaticBody2D.new()
	var slab := CollisionShape2D.new()
	var plate := RectangleShape2D.new()
	plate.size = Vector2(110.0, 20.0)
	slab.shape = plate
	roof.add_child(slab)
	roof.collision_layer = 1
	roof.position = _spot + Vector2(250.0, -110.0)
	_world.add_child(roof)
	await _arrive()
	var line := PackedVector2Array([_spot + Vector2(110.0, -220.0), _spot + Vector2(290.0, -220.0)])
	_cast("Hailstorm", "shape", 0.0, {"line": line})
	await _wait(1.0)
	_verdict(get_tree().get_nodes_in_group("clouds").any(func(n) -> bool: return n is Hailstorm), "a storm cloud hangs along the drawn line")
	await _wait(4.5)
	var open_hurt: int = open.max_hp - open.hp
	_verdict(open_hurt >= HailStone.HARM and open_hurt % HailStone.HARM == 0, "hail falls on whoever stands under the cloud (%d hurt)" % open_hurt)
	_verdict(sheltered.hp == sheltered.max_hp, "and a roof is shelter (%d hurt)" % (sheltered.max_hp - sheltered.hp))
	await _wait(1.0)
	_verdict(not get_tree().get_nodes_in_group("clouds").any(func(n) -> bool: return n is Hailstorm and is_instance_valid(n) and not n.is_queued_for_deletion()), "the cloud passes")
	_verdict(not _world.get_children().any(func(n) -> bool: return n is HailStone), "and no stone is left in the air")
	roof.queue_free()
	open.queue_free()
	sheltered.queue_free()


func _featherfall() -> void:
	_player.global_position = _spot + Vector2(0.0, -900.0)
	_player.velocity = Vector2.ZERO
	await _wait(0.8)
	var plain := _player.velocity.y
	_verdict(plain > Wizard.FEATHER_FALL * 2.0, "without it a wizard falls fast (%.0f px/s)" % plain)
	_player.global_position = _spot + Vector2(0.0, -900.0)
	_player.velocity = Vector2.ZERO
	_cast("Featherfall", "positional", 0.0)
	_verdict(_player.feather_time > 0.0, "the cast puts the wizard's fall under a feather's")
	await _wait(1.5)
	var fastest := 0.0
	for k in 60:
		await get_tree().physics_frame
		fastest = maxf(fastest, _player.velocity.y)
	_verdict(fastest <= Wizard.FEATHER_FALL + 1.0 and fastest > 10.0, "and they drift down slowly (%.0f px/s)" % fastest)
	_player.feather_time = 0.0
	await _wait(0.8)
	_verdict(_player.velocity.y > Wizard.FEATHER_FALL * 2.0 or _player.is_on_floor(), "and when it ends they fall as before (%.0f px/s)" % _player.velocity.y)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
