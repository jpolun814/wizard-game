extends SceneTree

## Saves large pictures of what RockArt makes (spires, icicles, a boulder, a wall), so they can be looked at: godot -s tests/looks/rock_art_look.gd -- out=DIR
func _init() -> void:
	var out := "user://rock_art"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var earth: Texture2D = load("res://art/tiles/earth_cemetery.png")
	var ice: Texture2D = load("res://art/props/ice_fill.png")
	var sheet := Image.create(900, 300, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.1, 0.2))
	var x := 10
	for k in 5:
		var tall := 60.0 + k * 22.0
		var picture := RockArt.spike(earth, 28.0 + k * 4.0, tall, true, false, k * 11)
		var image := picture.get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, 290 - image.get_height()))
		x += image.get_width() + 14
	for k in 4:
		var picture := RockArt.spike(ice, 20.0 + k * 4.0, 70.0 + k * 20.0, false, true, k * 5)
		var image := picture.get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, 10))
		x += image.get_width() + 14
	sheet.save_png(out + "/spikes.png")
	var parts := Image.create(700, 200, false, Image.FORMAT_RGBA8)
	parts.fill(Color(0.12, 0.1, 0.2))
	var boulder := RockArt.boulder(earth, 18.0, 3).get_image()
	boulder.resize(boulder.get_width() * 2, boulder.get_height() * 2, Image.INTERPOLATE_NEAREST)
	parts.blend_rect(boulder, Rect2i(Vector2i.ZERO, boulder.get_size()), Vector2i(10, 10))
	var wall := RockArt.slab(earth, 140.0, 22.0, 0.0, 4, Vector2(100, 400)).get_image()
	wall.resize(wall.get_width() * 2, wall.get_height() * 2, Image.INTERPOLATE_NEAREST)
	parts.blend_rect(wall, Rect2i(Vector2i.ZERO, wall.get_size()), Vector2i(150, 20))
	var worn := RockArt.slab(earth, 140.0, 22.0, 0.5, 4, Vector2(100, 400)).get_image()
	worn.resize(worn.get_width() * 2, worn.get_height() * 2, Image.INTERPOLATE_NEAREST)
	parts.blend_rect(worn, Rect2i(Vector2i.ZERO, worn.get_size()), Vector2i(150, 100))
	parts.save_png(out + "/parts.png")
	quit()
