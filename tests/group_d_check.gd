extends Node

## Eight attacking spells, cast in a real world against a dummy: Wind Cutter (a thin blade that hurts and is stopped by a wall), Shadow Bolt (it bends toward a
## rival), Sandblast (a cone: nothing behind it, past it or behind a wall is hurt), Sleet (a spray of shards), Meteor (a rock falls on the spot and a roof is
## shelter), Strangler Vine (it holds and squeezes whoever is in reach when it springs), Hemorrhage (a wound that bleeds a little at a time) and Steam Burst (a
## column that scalds, and wind clears).
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
	await _wind_cutter()
	await _shadow_bolt()
	await _sandblast()
	await _sleet()
	await _meteor()
	await _strangler_vine()
	await _hemorrhage()
	await _steam_burst()
	print("the eight attacking spells work" if _failures == 0 else "%d FAILED" % _failures)
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


func _hurt(mob: Mob) -> int:
	return mob.max_hp - mob.hp


## The effects of one kind in the world.
func _made(kind: GDScript) -> Array:
	return _world.get_children().filter(func(n) -> bool: return is_instance_of(n, kind) and not n.is_queued_for_deletion())


func _wind_cutter() -> void:
	var dummy := _dummy(300.0)
	var shielded := _dummy(-300.0)
	var wall := _wall(-150.0, 200.0)
	await _arrive()
	_cast("Wind Cutter", "directional", 0.0)
	await _wait(0.8)
	_verdict(_hurt(dummy) == WindBlade.HARM, "a blade of wind cuts what it meets (%d hurt)" % _hurt(dummy))
	_cast("Wind Cutter", "directional", PI)
	await _wait(0.8)
	_verdict(_hurt(shielded) == 0, "and a wall stops it (%d hurt)" % _hurt(shielded))
	dummy.queue_free()
	shielded.queue_free()
	wall.queue_free()


func _shadow_bolt() -> void:
	var rival: Wizard = _world._rivals[0]
	rival.global_position = _spot + Vector2(320.0, -150.0)
	var before := rival.max_stamina
	var dummy := _dummy(300.0)
	await _arrive()
	_cast("Shadow Bolt", "directional", 0.0)  # flung level, with the rival well above its line
	await _wait(2.5)
	_verdict(rival.max_stamina < before, "a bolt of darkness bends toward a rival and hurts them (%.0f to %.0f)" % [before, rival.max_stamina])
	rival.global_position = Vector2(-9000.0, -9000.0)
	_cast("Shadow Bolt", "directional", (SpellTargets.center_of(dummy) - _player.center()).angle())  # (the dummy stands a little lower than the wizard)
	await _wait(2.0)
	_verdict(_hurt(dummy) == ShadowBolt.HARM, "and hurts what it meets (%d hurt)" % _hurt(dummy))
	rival.global_position = Vector2(-9000.0, -9000.0)
	dummy.queue_free()


func _sandblast() -> void:
	var near := _dummy(110.0)
	var far := _dummy(330.0)
	var behind := _dummy(-110.0)
	await _arrive()
	_cast("Sandblast", "cone", 0.0, {"aim": 0.0, "spread": 0.7, "reach": 160.0})
	await _wait(1.0)
	_verdict(_hurt(near) >= Sandblast.HARM, "a blast of sand scours what stands in its cone (%d hurt)" % _hurt(near))
	_verdict(_hurt(far) == 0, "and does not reach past it (%d hurt)" % _hurt(far))
	_verdict(_hurt(behind) == 0, "or behind the one who blew it (%d hurt)" % _hurt(behind))
	var wall := _wall(60.0, 200.0)
	var screened := near.hp
	_cast("Sandblast", "cone", 0.0, {"aim": 0.0, "spread": 0.7, "reach": 160.0})
	await _wait(1.0)
	_verdict(near.hp == screened, "and a wall stops it")
	wall.queue_free()
	near.queue_free()
	far.queue_free()
	behind.queue_free()


func _sleet() -> void:
	var dummy := _dummy(180.0)
	var behind := _dummy(-180.0)
	_player.facing = 1.0
	await _arrive()
	_cast("Sleet", "positional", 0.0)
	await _wait(1.0)
	var hurt := _hurt(dummy)
	_verdict(hurt > 0 and hurt % SleetShard.HARM == 0 and hurt <= SleetShard.HARM * Sleet.COUNT, "a spray of ice shards hurts what it meets (%d hurt)" % hurt)
	var wall := _wall(100.0, 220.0)
	var before := dummy.hp
	_cast("Sleet", "positional", 0.0)
	await _wait(1.0)
	_verdict(dummy.hp == before, "and a wall stops them")
	_verdict(_hurt(behind) == 0, "and nothing behind the caster is hurt")
	wall.queue_free()
	dummy.queue_free()
	behind.queue_free()


func _meteor() -> void:
	var open := _dummy(200.0)
	var sheltered := _dummy(450.0)
	var roof := StaticBody2D.new()
	var slab := CollisionShape2D.new()
	var plate := RectangleShape2D.new()
	plate.size = Vector2(160.0, 20.0)
	slab.shape = plate
	roof.add_child(slab)
	roof.collision_layer = 1
	roof.position = _spot + Vector2(450.0, -120.0)
	_world.add_child(roof)
	await _arrive()
	var rock := Meteor.new()
	rock.position = _spot + Vector2(200.0, -40.0)
	_world.add_child(rock)
	await _wait(2.5)
	_verdict(_hurt(open) >= LavaBall.DAMAGE, "a burning rock falls on the spot and hurts what it lands on (%d hurt)" % _hurt(open))
	var covered := Meteor.new()
	covered.position = _spot + Vector2(450.0, -260.0)  # drawn above the roof
	_world.add_child(covered)
	await _wait(2.5)
	_verdict(_hurt(sheltered) == 0, "and a roof over the spot is shelter (%d hurt)" % _hurt(sheltered))
	roof.queue_free()
	open.queue_free()
	sheltered.queue_free()


func _strangler_vine() -> void:
	var caught := _dummy(150.0)
	var clear := _dummy(330.0)
	await _arrive()
	var vine := StranglerVine.new()
	vine.position = _spot + Vector2(150.0, 0.0)
	_world.add_child(vine)
	await _wait(StranglerVine.RISE + 0.5)
	_verdict(caught.is_rooted(), "vines wrap whoever is in reach when they spring")
	_verdict(not clear.is_rooted(), "and not whoever stood clear")
	await _wait(StranglerVine.HOLD)
	_verdict(_hurt(caught) >= StranglerVine.HARM * 2, "and squeeze them (%d hurt)" % _hurt(caught))
	await _wait(1.5)
	_verdict(_hurt(clear) == 0, "while the one clear is not hurt (%d hurt)" % _hurt(clear))
	_verdict(_made(StranglerVine).is_empty(), "and the vines wither")
	caught.queue_free()
	clear.queue_free()


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


func _steam_burst() -> void:
	var scalded := _dummy(140.0)
	var clear := _dummy(260.0)
	await _arrive()
	var steam := SteamBurst.new()
	steam.position = _spot + Vector2(140.0, 0.0)
	_world.add_child(steam)
	await _wait(2.0)
	_verdict(_hurt(scalded) >= SteamBurst.HARM, "a column of steam scalds whoever stands in it (%d hurt)" % _hurt(scalded))
	_verdict(_hurt(clear) == 0, "and not whoever stands clear (%d hurt)" % _hurt(clear))
	steam.dissipate()  # the wind takes it
	await _wait(1.0)
	var settled := _hurt(scalded)
	await _wait(1.0)
	_verdict(_hurt(scalded) == settled and _made(SteamBurst).is_empty(), "and the wind clears it")
	scalded.queue_free()
	clear.queue_free()


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
