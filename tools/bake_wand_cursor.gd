extends SceneTree

## Makes art/ui/wand_turns.png: every turn of the wand cursor (scripts/ui/wand_cursor.gd), with its jewel in the color of every set of mouse buttons, so
## the game cuts them out instead of turning the wand a pixel at a time while it runs. A row for each set of buttons held (0, nothing, to 7, all
## three), a column for each step. The pixels are the cursor's own, made by its own code. Run again after changing the wand or the cursor's code:
##
##     godot --headless -s tools/bake_wand_cursor.gd

func _init() -> void:
	var wand: Node = load("res://scripts/ui/wand_cursor.gd").new()
	wand.use_plain((load("res://art/ui/wand_cursor.png") as Texture2D).get_image())
	var steps: int = wand.STEPS
	var size: int = wand.CANVAS
	var sheet := Image.create_empty(size * steps, size * 8, false, Image.FORMAT_RGBA8)
	for mask in 8:
		for step in steps:
			sheet.blit_rect(wand.picture_of(mask, step), Rect2i(0, 0, size, size), Vector2i(step * size, mask * size))
	sheet.save_png("res://art/ui/wand_turns.png")
	print("wrote art/ui/wand_turns.png, %d by %d" % [sheet.get_width(), sheet.get_height()])
	wand.free()
	quit()
