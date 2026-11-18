extends Node

## A picture of the streak from a staff to a spell that appears elsewhere, and of a shot and a scythe leaving the staff. `-- out=DIR` (needs a window).


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
	var at := player.global_position + Vector2(260.0, 0.0)
	lab.spawn_spell("Mudslide", "shape", at, 0.0, {"line": PackedVector2Array([at + Vector2(-60.0, -6.0), at + Vector2(60.0, -6.0)])}, player)
	player.thrust(0.4)
	await get_tree().create_timer(0.1).timeout
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/tracer_a.png")
	await get_tree().create_timer(0.6).timeout
	lab.spawn_spell("Scythe", "caster", player.global_position, 0.0, {}, player)
	player.thrust(0.4)
	await get_tree().create_timer(0.12).timeout
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/tracer_b.png")
	get_tree().quit()
