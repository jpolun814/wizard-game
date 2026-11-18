extends Node

## A picture of a Water Jet in the waiting room. `-- out=DIR` (needs a window).


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
	if "geyser" in OS.get_cmdline_user_args():
		var geyser := Geyser.new()
		geyser.position = player.global_position + Vector2(140, 0)
		lab.add_child(geyser)
	else:
		lab.casting.by("Water Jet", "caster", player.global_position, 0.0, {"accuracy": 0.9, "reach": 320.0, "spread": 0.3}, player)
	for shot in [0.9, 0.5]:
		await get_tree().create_timer(shot).timeout
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			get_viewport().get_texture().get_image().save_png(out + "/jet_%d.png" % int(shot * 10))
	get_tree().quit()
