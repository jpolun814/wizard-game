extends Node

## Pictures of spellbook pages, to see that a long entry still fits on its page.
##
##     godot --path . tests/looks/book_look.tscn -- out=DIR [spells=Supernova,Leech]     (needs a window)

var out_dir := "user://book_look"
var spells := ["Supernova", "Leech", "Firewall", "Insect Plague", "Flaming Sphere", "Vacuum", "Eldritch Blast", "Push", "chant:bonfire", "chant:rift"]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
		if arg.begins_with("spells="):
			spells = arg.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().process_frame
	for page in spells:
		lab.spellbook.show_page(page)
		for k in 12:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, str(page).replace(":", "_").replace(" ", "_")])
	get_tree().quit()
