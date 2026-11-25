extends Control

## Every frame of the spellbook, as the game draws it (closed, swinging open, open, a leaf turning), in a row.   godot --path . tests/looks/book_frames_look.tscn -- out=FILE (needs a window)


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	RenderingServer.set_default_clear_color(Color("#1c2233"))
	var pixel := 1.0
	for k in 8:
		var book := BookArt.new()
		book.pixel = pixel
		book.frame = k
		book.size = Spellbook.FRAME * pixel
		book.position = Vector2(float(k % 4) * (Spellbook.FRAME.x * pixel + 4.0), float(k / 4) * (Spellbook.FRAME.y * pixel + 4.0))
		add_child(book)
	await get_tree().create_timer(0.3).timeout
	if out != "":
		get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
