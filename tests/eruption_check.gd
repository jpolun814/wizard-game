extends Node

## A volcano of the ashlands erupts: the world shakes, a plume of smoke rises that hides what lies deep behind it (and not what is a little way in),
## lava pours over the rim and runs down the mountain, and when the eruption is over the lava cools and goes.
##
##     godot --headless --fixed-fps 60 --path . tests/eruption_check.tscn -- seed=5
##     godot --fixed-fps 60 --path . tests/eruption_check.tscn -- seed=5 out=DIR     (pictures need a window)

var failed := false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var seed_value := 5
	var out_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
		elif argument.begins_with("out="):
			out_dir = argument.substr(4)
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 6:
		await get_tree().process_frame
	var craters := get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is Eruption)
	_check(not craters.is_empty(), "the world has a volcano (%d)" % craters.size())
	if craters.is_empty():
		get_tree().quit(1)
		return
	var crater: Eruption = craters[0]
	for other: Eruption in craters:
		if other != crater:
			other.set_physics_process(false)  # only the one is watched
	world.player.global_position = crater.global_position + Vector2(-260.0, -60.0)
	world._ground.watch([crater.global_position], true)
	for k in 30:
		await get_tree().process_frame
	crater._wake(1234)
	await get_tree().create_timer(2.0).timeout
	var plumes := get_tree().get_nodes_in_group("sight_blockers").filter(func(n: Node) -> bool: return n is SmokePlume)
	_check(plumes.size() == 1, "a plume of smoke rises as it rumbles (%d)" % plumes.size())
	if plumes.size() == 1:
		var plume: SmokePlume = plumes[0]
		var base := plume.global_position
		var across := SmokePlume.WIDTH * 0.5
		var tall := Vector2(0.0, -100.0)
		_check(not plume.blocks(base + tall + Vector2(-across - 80.0, 0.0), base + tall + Vector2(-across + 40.0, 0.0)), "no one loses sight of what is only a little way into the smoke")
		_check(plume.blocks(base + tall + Vector2(-across - 80.0, 0.0), base + tall + Vector2(across + 80.0, 0.0)), "and cannot see through it to the other side")
		_check(not plume.blocks(base + Vector2(-across - 80.0, 40.0), base + Vector2(across + 80.0, 40.0)), "but sees under it, where there is none")
	await get_tree().create_timer(4.0).timeout
	var veil := get_tree().get_first_node_in_group("smoke_veil") as SmokeVeil
	_check(veil != null, "the screen has a haze for the smoke")
	world.player.global_position = crater.global_position + Vector2(-SmokePlume.WIDTH * 0.5 + 24.0, -60.0)  # a little way into the plume
	await get_tree().create_timer(0.5).timeout
	if veil != null:
		var mask := veil._image
		var hidden := 0
		for y in mask.get_height():
			for x in mask.get_width():
				if mask.get_pixel(x, y).r > 0.5:
					hidden += 1
		_check(hidden > 20 and hidden < mask.get_width() * mask.get_height() / 2, "part of the screen is hidden by it, not all of it (%d of %d cells)" % [hidden, mask.get_width() * mask.get_height()])
	_shot(out_dir, "veil")
	world.player.global_position = crater.global_position + Vector2(-260.0, -60.0)
	await get_tree().create_timer(1.5).timeout
	_shot(out_dir, "eruption_a")
	var hot := 0.0
	var pools := 0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.lava and pond.cools and pond.grid != null:
			pools += 1
			hot += pond.grid.total()
	_check(pools > 0 and hot > 3.0, "lava has poured (%d pools, %.1f cells)" % [pools, hot])
	var widest := 0.0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.lava and pond.cools and pond.grid != null:
			var wet := pond.grid.wet_columns()
			widest = maxf(widest, (wet.y - wet.x + 1) * LiquidGrid.CELL)
	_check(widest > SurfaceGen.CRATER_WIDTH * 32.0 + 96.0, "and it has spilled over the rim of the bowl and down the sides (%.0f px wide, the bowl is %d)" % [widest, SurfaceGen.CRATER_WIDTH * 32])
	await get_tree().create_timer(6.0).timeout
	_shot(out_dir, "eruption_b")
	await get_tree().create_timer(14.0).timeout
	_shot(out_dir, "eruption_c")
	var burning := get_tree().get_nodes_in_group("ponds").filter(func(p: Pond) -> bool: return p.lava and p.cools and p.molten())
	_check(burning.is_empty(), "later the lava has cooled and no longer burns")
	await get_tree().create_timer(14.0).timeout
	var left := get_tree().get_nodes_in_group("ponds").filter(func(p: Pond) -> bool: return p.lava and p.cools)
	_check(left.is_empty(), "and then it is gone (%d pools left)" % left.size())
	_check(get_tree().get_nodes_in_group("sight_blockers").filter(func(n: Node) -> bool: return n is SmokePlume).is_empty(), "and the smoke has cleared")
	print("the volcano erupts and settles" if not failed else "eruption check FAILED")
	get_tree().quit(1 if failed else 0)


func _shot(out_dir: String, name: String) -> void:
	if out_dir != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out_dir)
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
