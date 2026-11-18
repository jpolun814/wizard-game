extends Node

## A picture of the wizard as a Golem in the waiting room. `-- out=DIR` (needs a window).


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
	player.golem.begin()
	DirAccess.make_dir_recursive_absolute(out if out != "" else "user://")
	for shot in [["rise_a", 0.2], ["rise_b", 0.3], ["rise_c", 0.3], ["stand", 0.9]]:
		await get_tree().create_timer(shot[1]).timeout
		if out != "":
			get_viewport().get_texture().get_image().save_png(out + "/golem_%s.png" % shot[0])
	player.golem.smash()
	await get_tree().create_timer(0.55).timeout
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/golem_smash_up.png")
	await get_tree().create_timer(0.35).timeout
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/golem_smash_down.png")
	get_tree().quit()
