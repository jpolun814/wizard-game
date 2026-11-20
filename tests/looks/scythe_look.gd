extends Node

## Pictures of a Scythe swung to the right and to the left, three moments each, side by side. `-- out=DIR` (needs a window; pass --audio-driver Dummy).


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
	DirAccess.make_dir_recursive_absolute(out)
	for facing in [1.0, -1.0]:
		player.facing = facing
		lab.spawn_spell("Scythe", "caster", player.global_position, 0.0, {}, player)
		player.thrust(0.4)
		for t in [0.04, 0.08, 0.1]:
			await get_tree().create_timer(0.04).timeout
			get_viewport().get_texture().get_image().save_png("%s/scythe_%s_%d.png" % [out, "right" if facing > 0.0 else "left", int(t * 100.0)])
		await get_tree().create_timer(0.8).timeout
	get_tree().quit()
