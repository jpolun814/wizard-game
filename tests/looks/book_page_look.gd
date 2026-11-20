extends Node

## A picture of one spellbook page, for looking at how it is set: godot --path . --audio-driver Dummy tests/looks/book_page_look.tscn -- page=Barrier out=FILE

func _ready() -> void:
	var page := "Barrier"
	var out := "res://../book_page.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("page="):
			page = a.substr(5)
		if a.begins_with("out="):
			out = a.substr(4)
	Library.use_file("user://book_page_look.json")
	Library.clear()
	Lab.plain_room = false
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	lab.spellbook.show_page(page)
	for k in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	Library.clear()
	get_tree().quit()
