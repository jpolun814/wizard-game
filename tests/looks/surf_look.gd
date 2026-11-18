extends Node

## A picture of a Tide Surf wave and a Blizzard. `-- out=DIR` (needs a window).


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
	lab.casting.by("Tide Surf", "caster", player.global_position, 0.0, {"accuracy": 0.9}, player)
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out + "/surf.png")
	get_tree().quit()
