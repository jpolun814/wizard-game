extends Node

## Anyone who stays in a Blizzard long enough freezes solid, as in an Ice Prison. Frost creeps over them first, so it can be seen coming; the
## ice thaws, and for a moment after that the cold cannot take hold again; leaving the snow lets the chill go; and ice enemies are not held.
##
##     godot --headless --fixed-fps 60 --path . tests/blizzard_freeze_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Wizard = world.player
	var feet := player.global_position
	for each in get_tree().get_nodes_in_group("mobs"):
		each.queue_free()  # nothing else in the world to hurt or distract the wizard
	for rival in world.rivals:
		rival.set_physics_process(false)
		rival.global_position += Vector2(0.0, -4000.0)
	await get_tree().physics_frame
	# A storm over the player.
	var snow := Blizzard.new()
	snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(320, -60), Vector2(320, 60), Vector2(0, 60)])
	world.add_child(snow)
	snow.setup("Blizzard", Vector2(feet.x - 160.0, feet.y - 20.0), 0.0)
	# Another wizard and a skeleton in it.
	var mob: Node2D = world.add_mob("basic", feet + Vector2(60.0, 0.0))
	await _wait(0.5)
	_verdict(snow.danger_at(feet + Vector2(0.0, -10.0)), "the snow is a danger where it falls")
	_verdict(not snow.danger_at(feet + Vector2(600.0, -10.0)), "and not out beside it")
	_verdict(not player.is_frozen(), "a wizard is not frozen at once")
	await _wait(1.5)
	_picture("frost_early")
	await _wait(1.0)
	_picture("frost_late")
	_verdict(not player.is_frozen() and snow._chill.has(player) and snow._chill[player] > 2.0, "after a few seconds the chill has built up and nobody is frozen yet (%.1f)" % snow._chill.get(player, 0.0))
	_verdict(snow._chill.has(mob), "a skeleton in the snow takes the cold too")
	await _wait(2.5)
	_picture("frozen")
	_verdict(player.is_frozen(), "a wizard who stays is frozen solid")
	_verdict(mob.is_frozen(), "and so is the skeleton")
	_verdict(get_tree().get_nodes_in_group("wizards").size() > 0 and world.get_children().any(func(n) -> bool: return n is IcePrison), "in a block of ice, as an Ice Prison makes")
	# Thawed by hand (as a shatter would): the cold cannot take hold again for a moment.
	player.thaw()
	await _wait(0.3)
	_verdict(not player.is_frozen() and not snow._chill.has(player), "thawed, a wizard starts again with no chill")
	await _wait(1.0)
	_verdict(not snow._chill.has(player), "and takes none for a moment (%.1f)" % snow._chill.get(player, 0.0))
	await _wait(1.5)
	_verdict(snow._chill.has(player) and snow._chill[player] > 0.0, "then the cold takes hold again")
	# Leaving the snow lets the chill go.
	player.global_position = feet + Vector2(700.0, 0.0)
	player.velocity = Vector2.ZERO
	await _wait(2.5)
	_verdict(not snow._chill.has(player), "a wizard who leaves the snow loses the chill")
	# Clouds high above the ground: the snow falls all the way down, so whoever stands below is chilled without waiting for a pile.
	snow.queue_free()
	for block in world.get_children().filter(func(n) -> bool: return n is IcePrison):
		block.queue_free()
	player.thaw()
	player.global_position = feet
	player.velocity = Vector2.ZERO
	var high := Blizzard.new()
	high.polygon = PackedVector2Array([Vector2(0, -60), Vector2(900, -60), Vector2(900, 60), Vector2(0, 60)])
	world.add_child(high)
	high.setup("Blizzard", Vector2(feet.x - 450.0, feet.y - 300.0), 0.0)
	await _wait(3.0)
	_verdict(high._chill.has(player) and high._chill[player] > 1.5, "clouds far above still chill a wizard on the ground (%.1f)" % high._chill.get(player, 0.0))
	print("a blizzard freezes whoever stays in it" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## With `out=DIR` on the command line (and a window), saves a picture of the screen.
func _picture(name: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			get_viewport().get_texture().get_image().save_png("%s/blizzard_%s.png" % [arg.substr(4), name])


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
