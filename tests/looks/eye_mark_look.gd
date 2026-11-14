extends Node2D

## A picture of the watching eye over a dark ground, large, with the blink caught. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	RenderingServer.set_default_clear_color(Color("#241a30"))
	var camera := Camera2D.new()
	camera.zoom = Vector2(6.0, 6.0)
	add_child(camera)
	camera.position = Vector2(0.0, -112.0)
	var eye := EyeMark.new()
	add_child(eye)
	await get_tree().create_timer(0.5).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/eye_mark.png")
	get_tree().quit()
