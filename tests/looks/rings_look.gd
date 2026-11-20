extends Node

## Pictures of the big rings: Silence, a Thunderclap and the blast of a Supernova. `-- out=DIR` (needs a window; pass --audio-driver Dummy).


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
	var at := player.global_position + Vector2(200.0, -20.0)
	lab.spawn_spell("Silence", "positional", at, 0.0, {"radius": 120.0}, player)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(out + "/silence.png")
	lab.spawn_spell("Thunderclap", "positional", at, 0.0, {}, player)
	await get_tree().create_timer(0.15).timeout
	get_viewport().get_texture().get_image().save_png(out + "/thunderclap.png")
	await get_tree().create_timer(1.0).timeout
	lab.spawn_spell("Supernova", "positional", at + Vector2(0.0, -60.0), 0.0, {}, player)
	await get_tree().create_timer(5.2).timeout
	get_viewport().get_texture().get_image().save_png(out + "/supernova.png")
	get_tree().quit()
