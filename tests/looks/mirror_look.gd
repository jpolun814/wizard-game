extends Node

## A picture of the magic mirror of the waiting room with a wizard before it, to see the reflection. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var mark: LikenessMark = lab._mark
	lab.player.global_position = mark.global_position + Vector2(-8.0, -4.0)
	await get_tree().create_timer(1.2).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/mirror.png")
	get_tree().quit()
