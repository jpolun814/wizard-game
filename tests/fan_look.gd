extends Node2D

## A picture of a fan of starting pages lying together. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	RenderingServer.set_default_clear_color(Color("#241a30"))
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.5, 2.5)
	add_child(camera)
	camera.position = Vector2(0.0, -110.0)
	var fan := PagePickup.new()
	fan.spoils.assign(["Ignite", "Frostbolt", "Push", "Stonefall", "Bramble"])
	fan.page = "Ignite"
	fan.fan = true
	add_child(fan)
	await get_tree().create_timer(0.6).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/fan.png")
	get_tree().quit()
