extends Node

## A picture of the minimap in a world, for a look at how much of it is ground and how much is sky.
##
##     godot --path . tests/minimap_look.tscn -- seed=0 out=DIR     (needs a window)

func _ready() -> void:
	var seed_value := 0
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.trim_prefix("seed="))
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 30:
		await get_tree().process_frame
	world._minimap.visible = true
	for k in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	var shot := get_viewport().get_texture().get_image()
	var map: Minimap = world._minimap
	var screen := shot.get_size()
	shot.get_region(Rect2i(screen.x - 400, 0, 400, 200)).save_png("%s/minimap_%d.png" % [out, seed_value])
	var picture := map._picture.get_image()
	var solid := 0
	for y in picture.get_height():
		for x in picture.get_width():
			if picture.get_pixel(x, y).a > 0.0:
				solid += 1
	print("saved ", map.size, "; ground is %.0f%% of the map" % (100.0 * solid / float(picture.get_width() * picture.get_height())))
	get_tree().quit()
