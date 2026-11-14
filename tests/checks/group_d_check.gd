extends Node

## Attacking spells, cast in a real world: Eldritch Blast (a beam that strikes the first thing in its line and is stopped by a wall), Hemorrhage (a wound that bleeds a little at a time), Supernova (a sun that
## pulls and burns, then blows up and throws things back) and Scythe (a swing in front that a wall shelters from) and Firewall (a line up and a line out: a wall of flame as wide as the second line, costing more the wider it is).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/group_d_check.tscn
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
	await _eldritch_blast()
	await _hemorrhage()
	await _supernova()
	await _scythe()
	await _firewall()
	print("the attacking spells work" if _failures == 0 else "%d FAILED" % _failures)
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


func _cast(spell: String, targeting: String, aim: float, info := {}) -> void:
	var data := {"length": 90.0, "accuracy": 0.9}
	data.merge(info)
	_world.spawn_spell(spell, targeting, _player.center() + Vector2.from_angle(aim) * 12.0, aim, data, _player)


func _hurt(mob: Mob) -> int:
	return mob.max_hp - mob.hp


## The effects of one kind in the world.
func _made(kind: GDScript) -> Array:
	return _world.get_children().filter(func(n) -> bool: return is_instance_of(n, kind) and not n.is_queued_for_deletion())


func _eldritch_blast() -> void:
	var near := _dummy(250.0)
	var behind := _dummy(420.0)
	await _arrive()
	_cast("Eldritch Blast", "directional", 0.0)
	await _wait(0.3)
	_verdict(_hurt(near) == EldritchBlast.HARM, "a beam strikes the first thing in its line at once (%d hurt)" % _hurt(near))
	_verdict(_hurt(behind) == 0, "and nothing behind it (%d hurt)" % _hurt(behind))
	_cast("Eldritch Blast", "directional", -0.6)
	await _wait(0.3)
	_verdict(_hurt(near) == EldritchBlast.HARM, "and misses what is not in its line")
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20.0, 200.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	wall.position = _spot + Vector2(150.0, -60.0)
	_world.add_child(wall)
	await _wait(0.1)
	_cast("Eldritch Blast", "directional", 0.0)
	await _wait(0.3)
	_verdict(_hurt(near) == EldritchBlast.HARM, "and a wall stops it")
	wall.queue_free()
	near.queue_free()
	behind.queue_free()
	var rival: Wizard = _world.rivals[0]
	rival.global_position = _spot + Vector2(300.0, -8.0)
	var before := rival.max_stamina
	await _wait(0.3)
	_cast("Eldritch Blast", "directional", 0.0)
	await _wait(0.3)
	_verdict(rival.max_stamina < before, "and it strikes a wizard too (%.0f to %.0f)" % [before, rival.max_stamina])
	rival.global_position = Vector2(-9000.0, -9000.0)


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


func _supernova() -> void:
	var near := _dummy(420.0)
	var distant := _dummy(1500.0)
	await _arrive()
	var came_from := _player.global_position.x
	var sun := Supernova.new()
	sun.position = _spot + Vector2(300.0, -20.0)
	_world.add_child(sun)
	await _wait(Supernova.RISE + 2.0)
	_verdict(_hurt(near) >= Supernova.BURN, "a sun scorches whoever is close (%d hurt)" % _hurt(near))
	_verdict(_player.global_position.x > came_from + 10.0, "and draws a wizard some way off toward it (%.0f px)" % (_player.global_position.x - came_from))
	_verdict(_hurt(distant) == 0, "and leaves those well away alone")
	var before := near.hp
	await _wait(Supernova.HANG)
	_verdict(near.hp <= before - Supernova.EXPLODE_DAMAGE, "then blows up and hurts what is near (%d hurt in all)" % (before - near.hp))
	near.queue_free()
	distant.queue_free()


func _scythe() -> void:
	_player.global_position = _spot  # the blast of the sun threw the wizard
	_player.velocity = Vector2.ZERO
	await _wait(0.5)
	var cut := _dummy(70.0)
	var behind := _dummy(-70.0)
	var far := _dummy(260.0)
	_player.facing = 1.0
	await _arrive()
	_cast("Scythe", "positional", 0.0)
	await _wait(0.6)
	_verdict(_hurt(cut) == Scythe.HARM, "a swing of the scythe cuts what is in front (%d hurt)" % _hurt(cut))
	_verdict(_hurt(behind) == 0 and _hurt(far) == 0, "and not what is behind or out of reach")
	var screen := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16.0, 200.0)
	shape.shape = box
	screen.add_child(shape)
	screen.collision_layer = 1
	screen.position = _spot + Vector2(36.0, -40.0)
	_world.add_child(screen)
	var before := cut.hp
	await _wait(0.2)
	_cast("Scythe", "positional", 0.0)
	await _wait(0.6)
	_verdict(cut.hp == before, "and a wall shelters whoever is behind it")
	screen.queue_free()
	cut.queue_free()
	behind.queue_free()
	far.queue_free()


## The strokes of a Firewall, as the caster measures them: from the foot, up to the corner, then out to the end.
func _flame_line(from_x: float, width: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(from_x, _spot.y), Vector2(from_x, _spot.y - 80.0), Vector2(from_x + width, _spot.y - 80.0)])


func _firewall() -> void:
	var narrow_spell: Spell = SpellData.SPELLS["Firewall"]
	var short := _flame_line(_spot.x + 100.0, 60.0)
	var wide := _flame_line(_spot.x + 100.0, 400.0)
	_verdict(narrow_spell.cost_for({"line": wide}) > narrow_spell.cost_for({"line": short}), "a wider wall costs more (%.0f against %.0f)" % [narrow_spell.cost_for({"line": wide}), narrow_spell.cost_for({"line": short})])
	var at_start := _dummy(120.0)
	var at_end := _dummy(450.0)
	await _arrive()
	_world.spawn_spell("Firewall", "positional", short[0], 0.0, {"line": short, "length": 60.0}, _player)
	await _wait(1.2)
	_verdict(_hurt(at_start) > 0 and _hurt(at_end) == 0, "a short wall of flame burns what stands in it and not what stands past it (%d and %d hurt)" % [_hurt(at_start), _hurt(at_end)])
	await _wait(4.0)
	_world.spawn_spell("Firewall", "positional", wide[0], 0.0, {"line": wide, "length": 400.0}, _player)
	await _wait(1.2)
	_verdict(_hurt(at_end) > 0, "and a wide one reaches the far end (%d hurt)" % _hurt(at_end))
	at_start.queue_free()
	at_end.queue_free()



func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
