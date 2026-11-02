extends Node

## Spells that act on the ground work in the castle too: a dropped boulder rests on a swinging stair, and a Sinkhole and a Stalagmite work on the floor of
## an upper storey.
##
##     godot --headless --fixed-fps 60 --path . tests/castle_spells_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	World.random_start = false
	World.next_seed = 9
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(world.castle_x >= 0, "the world is a castle (seed 9)")
	var space := world.get_world_2d()
	var ground: int = world.graph.rooms[0]["cy"]
	var player: Wizard = world.player
	player.infinite_time = 600.0
	# A boulder dropped on a stair that has come to rest.
	var stair: SwingStair = get_tree().get_nodes_in_group("swing_stairs")[1]
	var waited := 0.0
	while not stair.joins(stair.ways[1]["from"], stair.ways[1]["to"], 4.0) and waited < 120.0:
		await _frames(6)
		waited += 0.1
	var mid := stair.hinge.lerp(stair.ends[1], 0.5)
	player.global_position = mid + Vector2(-300.0, -80.0)
	var boulder := Boulder.new()
	boulder.earth = load("res://art/tiles/castle_brick.png")
	boulder.global_position = mid + Vector2(0.0, -200.0)
	world.add_child(boulder)
	await _frames(90)
	_verdict(boulder.global_position.y < mid.y + 40.0, "a boulder dropped on a stair rests on it (y %.0f, stair %.0f)" % [boulder.global_position.y, mid.y])
	boulder.queue_free()
	# The floor of the first storey, in the first room, to the right of its stairwell.
	var spot := Vector2((world.castle_x + 24 + 0.5) * 32.0, float(ground - 11) * 32.0)
	player.global_position = spot + Vector2(-120.0, -40.0)
	world._ground.watch([spot], true)
	await _frames(20)
	var before := SpellTargets.solid_below(space, spot + Vector2(0.0, -60.0)).y
	_verdict(absf(before - spot.y) < 8.0, "the first storey's floor is where it should be (%.0f, wanted %.0f)" % [before, spot.y])
	var tip := spot + Vector2(0.0, -90.0)
	var peak := PackedVector2Array([tip + Vector2(-30.0, 90.0), tip, tip + Vector2(30.0, 90.0)])
	world._place_shapes("Stalagmite", {"shapes": [peak], "line": peak})
	await _frames(40)
	var spikes := get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is Stalagmite)
	_verdict(spikes.size() == 1 and absf(spikes[0].global_position.y - before) < 16.0, "a Stalagmite rises from that floor (%d, at %s)" % [spikes.size(), spikes[0].global_position if spikes.size() > 0 else Vector2.ZERO])
	for spike in spikes:
		spike.queue_free()
	var drawn := PackedVector2Array()
	for k in 33:
		var u := float(k) / 32.0
		drawn.append(Vector2(spot.x - 60.0 + 120.0 * u, spot.y - 110.0 + 100.0 * (1.0 - pow(absf(2.0 * pow(u, 0.7) - 1.0), 2.0))))
	player.max_stamina = 9999.0
	world.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {"line": drawn}, player)
	await _frames(int(Sinkhole.WARNING * 60.0) + 30)
	var after := SpellTargets.solid_below(space, Vector2(spot.x, before - 60.0)).y
	_verdict(after > before + 12.0, "a Sinkhole lowers that floor (%.0f px)" % (after - before))
	if out != "":  # the pit must be seen as well as felt: the brick over the floor goes with it
		DirAccess.make_dir_recursive_absolute(out)
		player.global_position = spot + Vector2(-200.0, -60.0)
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/castle_sinkhole.png")
	print("the castle takes spells" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
