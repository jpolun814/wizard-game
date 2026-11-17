extends Node

## A picture of a Golem standing beside its wizard in the waiting room. `-- out=DIR` (needs a window).


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
	lab.casting.by("Golem", "positional", player.global_position + Vector2(-110.0, 0.0), 0.0, {"accuracy": 0.9}, player)
	await get_tree().create_timer(2.5).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/golem.png")
	get_tree().quit()
