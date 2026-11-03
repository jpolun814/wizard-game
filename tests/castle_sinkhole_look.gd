extends Node

## Pictures of Sinkholes dug in the castle, each before and after, on every kind of floor: the first floor, a ground floor over solid stone, a ground floor over the
## cellar, the cellar's floor, a second pit beside the first, and one at a wall. Needs a window.
##
##     godot --fixed-fps 60 --path . tests/castle_sinkhole_look.tscn -- out=DIR

const SPOTS := {  # name: [column from the castle's west end, floor height in rows]
	"first_floor": [24, 11], "ground_solid": [24, 0], "ground_over_cellar": [50, 0], "cellar": [50, -11],
	"second_floor": [76, 22], "at_wall": [6, 11], "third_floor": [30, 33], "fourth_floor": [58, 44], "fourth_b": [84, 44],
	"ground_c": [60, 0], "ground_d": [80, 0], "first_c": [56, 11], "first_d": [82, 11], "second_a": [8, 22], "second_b": [32, 22],
	"third_c": [58, 33], "third_d": [83, 33], "cellar_b": [30, -11], "cellar_c": [76, -11],
}


var _failed := 0
var randoms := 0
var _half := 60.0
var last_column := 30
var last_row := 11


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
		if argument.begins_with("random="):
			randoms = int(argument.trim_prefix("random="))
	DirAccess.make_dir_recursive_absolute(out)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 9
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground: int = world.graph.rooms[0]["cy"]
	var player: Wizard = world.player
	player.infinite_time = 600.0
	player.max_stamina = 9999.0
	for name: String in (SPOTS if randoms == 0 else {}):
		var spot := Vector2((world.castle_x + SPOTS[name][0] + 0.5) * 32.0, float(ground - SPOTS[name][1]) * 32.0)
		await _dig(world, player, spot, out, name, 1)
		if name == "first_floor" or name == "ground_c":  # more pits beside, over and between the first
			var n := 2
			for shift in [70.0, -80.0, 30.0, 150.0, -170.0, 0.0]:
				await _dig(world, player, spot + Vector2(shift, 0.0), out, "%s_more%d" % [name, n], n)
				n += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in randoms:  # pits anywhere in the castle, one after another, some beside others
		var floors := [-11, 0, 11, 22, 33, 44]
		var column := rng.randi_range(5, 85)
		if k % 3 != 0:
			column = clampi(last_column + rng.randi_range(-4, 4), 5, 85)  # near the last, so that pits meet
		last_column = column
		var row: int = floors[rng.randi_range(0, floors.size() - 1)] if k % 3 == 0 else last_row
		last_row = row
		var spot := Vector2((world.castle_x + column + 0.5) * 32.0, float(ground - row) * 32.0 - rng.randf_range(0.0, 260.0))  # from the floor up to the ceiling
		_half = rng.randf_range(50.0, 120.0)
		await _dig(world, player, spot, out, "random%d" % k, k)
	print("a pit is seen to be a pit" if _failed == 0 else "%d spots still show the floor over a pit" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _dig(world: World, player: Wizard, spot: Vector2, out: String, name: String, _n: int) -> void:
	player.global_position = spot + Vector2(-140.0, -40.0)
	player.get_node("Camera2D").zoom = Vector2(0.8, 0.8)
	player.get_node("Camera2D").position_smoothing_enabled = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	world._ground.watch([spot], true)
	for k in 40:
		await get_tree().physics_frame
	await _shot(out, name + "_before")
	await RenderingServer.frame_post_draw
	var before_image := get_viewport().get_texture().get_image()
	var grid := []  # the points round the spot that are stone before the pit
	for gx in range(-90, 91, 6):
		for gy in range(-200, 200, 6):
			var at := spot + Vector2(gx, gy)
			if world._ground.solid_at(at):
				grid.append(at)
	var drawn := PackedVector2Array()
	for k in 33:
		var u := float(k) / 32.0
		drawn.append(Vector2(spot.x - _half + 2.0 * _half * u, spot.y - 110.0 + 100.0 * (1.0 - pow(absf(2.0 * pow(u, 0.7) - 1.0), 2.0))))
	world.spawn_spell("Sinkhole", "positional", spot + Vector2(0.0, -20.0), 0.0, {"line": drawn}, player)
	for k in int(Sinkhole.WARNING * 60.0) + 60:
		await get_tree().physics_frame
	await _shot(out, name + "_after")
	await RenderingServer.frame_post_draw
	var after_image := get_viewport().get_texture().get_image()
	var opened := 0
	var still_drawn := 0
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	for at: Vector2 in grid:
		if world._ground.solid_at(at):
			continue
		var pixel := Vector2i(to_screen * at)
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= after_image.get_width() or pixel.y >= after_image.get_height():
			continue
		opened += 1
		after_image.set_pixelv(pixel, Color(1, 0, 0))  # (the picture of the after, with the opened points marked, is kept)
		var was := before_image.get_pixelv(pixel)
		var now := after_image.get_pixelv(pixel)
		if absf(was.r - now.r) + absf(was.g - now.g) + absf(was.b - now.b) < 0.03:
			still_drawn += 1
	after_image.save_png("%s/%s_marks.png" % [out, name])
	if still_drawn * 20 > opened:
		_failed += 1
	print("%s: %d points opened by the pit, %d of them look just as they did before" % [name, opened, still_drawn])


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
