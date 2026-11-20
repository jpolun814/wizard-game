extends Node

## The streak from the staff to a spell cast across the screen, frame by frame. `-- out=DIR` (needs a window; pass --audio-driver Dummy).


func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 60:
		await get_tree().process_frame
	var player: Wizard = lab.player
	player.ledger.learn_all()
	player.facing = 1.0
	player.play_cast_release()
	await get_tree().create_timer(1.5).timeout
	lab.spawn_spell("Silence", "positional", player.global_position + Vector2(260.0, -20.0), 0.0, {"radius": 100.0}, player)
	for k in 6:
		await get_tree().create_timer(0.04).timeout
		var image := get_viewport().get_texture().get_image()
		var at: Vector2 = get_viewport().get_canvas_transform() * player.global_position
		var c := Vector2i(clampi(int(at.x), 120, 900), clampi(int(at.y), 120, 600))
		image.get_region(Rect2i(c.x - 120, c.y - 120, 440, 220)).save_png(out + "/tracer_%d.png" % k)
	get_tree().quit()
