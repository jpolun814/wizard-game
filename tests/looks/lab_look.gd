extends Node

## The waiting room before and after a click, beside the pond and the lava, and after a restart (R). `-- out=DIR` (needs a window; pass --audio-driver Dummy).


func _shot(name: String, out: String) -> void:
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().process_frame
	await _shot("start", out)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(600.0, 300.0)
	Input.parse_input_event(click)
	await get_tree().create_timer(0.1).timeout
	click.pressed = false
	Input.parse_input_event(click)
	await _shot("clicked", out)
	print("width ", ArenaGen.right_wall, " ", ArenaGen.chunk_count)
	var pond: Node2D = lab.get_tree().get_nodes_in_group("ponds")[0] if lab.get_tree().get_nodes_in_group("ponds").size() > 0 else null
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.POND.x + Lab.SHIFT) - 150.0, ArenaGen.GROUND_Y - 120.0)
	await _shot("pond", out)
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.LAVA.x + Lab.SHIFT) - 150.0, ArenaGen.GROUND_Y - 120.0)
	await _shot("lava", out)
	get_tree().quit()
