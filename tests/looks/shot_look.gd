extends Node

## Frames of a Frostbolt leaving the staff. `-- out=DIR` (needs a window).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var player: Wizard = lab.player
	player.ledger.learn_all()
	player.facing = 1.0
	player.thrust(0.5)
	lab.spawn_spell("Frostbolt", "directional", player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, player)
	for k in 4:
		await get_tree().physics_frame
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			get_viewport().get_texture().get_image().save_png(out + "/shot_%d.png" % k)
	get_tree().quit()
