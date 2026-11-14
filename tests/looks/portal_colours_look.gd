extends Node

## Pictures of a portal opening and closing, and of the twelve portal colours.   godot --path . tests/looks/portal_colours_look.tscn -- out=DIR (needs a window)

func _ready() -> void:
	var out_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out_dir = argument.substr(4)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.08)
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)
	var life := PortalField.HUES
	for id in PortalField.HUES:
		var portal := FieldPortal.new()
		portal.tint = PortalField.tint_of(id)
		portal.position = Vector2(80 + (id % 6) * 200, 150 + (id / 6) * 200)
		add_child(portal)
		portal.open()
	var lone := FieldPortal.new()  # one that opens, stays a moment and closes
	lone.tint = PortalField.tint_of(3)
	lone.lifetime = 2.0
	lone.position = Vector2(640, 560)
	add_child(lone)
	lone.open()
	var shots: Array[Image] = []
	var clock := 0.0
	for step in 14:
		await get_tree().create_timer(0.17).timeout
		clock += 0.17
		lone.age = clock
		var shot := get_viewport().get_texture().get_image().get_region(Rect2i(590, 500, 100, 120))
		shot.convert(Image.FORMAT_RGBA8)
		shots.append(shot)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		var strip := Image.create(100 * shots.size(), 120, false, Image.FORMAT_RGBA8)
		strip.fill(Color(0.03, 0.02, 0.08))
		for k in shots.size():
			strip.blit_rect(shots[k], Rect2i(0, 0, 100, 120), Vector2i(k * 100, 0))
		strip.save_png(out_dir + "/portal_life.png")
	get_tree().quit()
