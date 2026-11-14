extends Node

## A wizard goes into a Sinkhole dug in the castle: dropped over its middle, it sinks to the bottom and stays there, and where the pit was dug through
## a floor, it falls on to the floor below. It prints each spot's floor before and after, and where the wizard comes to rest.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/castle_sinkhole_fall_check.tscn

const SPOTS := {
	"first_floor": [24, 11], "ground_solid": [24, 0], "ground_over_cellar": [50, 0], "cellar": [50, -11],
	"second_floor": [76, 22],
}
var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 9
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await _frames(2)
	var ground: int = world.graph.rooms[0]["cy"]
	var player: Wizard = world.player
	player.infinite_time = 600.0
	player.max_stamina = 9999.0
	var space := player.get_world_2d()
	for name: String in SPOTS:
		var spot := Vector2((world.castle_x + SPOTS[name][0] + 0.5) * 32.0, float(ground - SPOTS[name][1]) * 32.0)
		player.global_position = spot + Vector2(-140.0, -40.0)
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		world._ground.watch([spot], true)
		await _frames(30)
		var before := SpellTargets.solid_below(space, spot + Vector2(0.0, -60.0)).y
		var drawn := PackedVector2Array()
		for k in 33:
			var u := float(k) / 32.0
			drawn.append(Vector2(spot.x - 60.0 + 120.0 * u, spot.y - 110.0 + 100.0 * (1.0 - pow(absf(2.0 * pow(u, 0.7) - 1.0), 2.0))))
		world.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {"line": drawn}, player)
		await _frames(int(Sinkhole.WARNING * 60.0) + 40)
		var columns := []
		for dx in [-50.0, -25.0, 0.0, 25.0, 50.0]:
			columns.append(int(SpellTargets.solid_below(space, Vector2(spot.x + dx, before - 60.0)).y - before))
		# drop the wizard over the middle, with the physics on
		player.global_position = Vector2(spot.x, before - 70.0)
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)
		await _frames(150)
		var rest := player.global_position
		print("%s: floor %.0f, drop at each 25 px across the pit %s, wizard rests at (%.0f, %.0f), %.0f px from the pit's middle" % [name, before, columns, rest.x, rest.y, absf(rest.x - spot.x)])
		_verdict(rest.y > before + 20.0, "%s: the wizard is down in the pit, not on its edge" % name)
		_verdict(absf(rest.x - spot.x) < 60.0, "%s: and still over the pit" % name)
		player.set_physics_process(false)
	print("a wizard goes into a castle pit" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, text: String) -> void:
	print(("ok   " if ok else "FAIL ") + text)
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame
