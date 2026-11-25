extends Node2D

## Pictures of the tornado's art being born and then looping, at the size the game draws it.   godot --path . tests/looks/tornado_look.tscn -- out=DIR (needs a window)


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	RenderingServer.set_default_clear_color(Color("#1c2233"))
	var camera := Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child(camera)
	camera.position = Vector2(0.0, -60.0)
	var funnel := PixelFx.sprite("tornado", 14.0, false, 0, 15)
	funnel.offset = Vector2(0, -48)
	funnel.scale = Vector2(2.0, 2.0)
	funnel.position = Vector2(-120.0, 40.0)
	add_child(funnel)
	funnel.play()
	var loop := PixelFx.sprite("tornado", 14.0, true, 16, 59)
	loop.offset = Vector2(0, -48)
	loop.scale = Vector2(2.0, 2.0)
	loop.position = Vector2(120.0, 40.0)
	add_child(loop)
	loop.play()
	await get_tree().create_timer(0.5).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/tornado.png")
	get_tree().quit()
