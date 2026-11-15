extends Node

## A picture of the wall that sets the AI level and the sparring partner beside it (needs a window).
##
##     godot --path . tests/looks/level_wall_look.tscn -- out=DIR

func _ready() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().process_frame
	lab._levels.set_level(4)
	lab.player.global_position = Vector2(ArenaGen.column_x(33), lab.player.global_position.y)
	for k in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("level_wall.png"))
	get_tree().quit()
