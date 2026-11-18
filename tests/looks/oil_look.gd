extends Node

## A picture of burning oil in the waiting room. `-- out=DIR` (needs a window).


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
	var at := player.global_position + Vector2(-150.0, 0.0)
	lab.spawn_spell("Oil Slick", "shape", at, 0.0, {"line": PackedVector2Array([at + Vector2(-110.0, -10.0), at + Vector2(110.0, -10.0)])}, player)
	Hazard.place(lab, player.global_position + Vector2(90.0, 0.0), 46.0, 6.0)
	await get_tree().create_timer(0.8).timeout
	for slick in get_tree().get_nodes_in_group("oil_slicks"):
		slick._go_up()
	for shot in [0.2, 0.5]:
		await get_tree().create_timer(shot).timeout
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
			get_viewport().get_texture().get_image().save_png(out + "/oil_%d.png" % int(shot * 10))
	get_tree().quit()
