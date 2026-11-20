extends Node

## Raise Dead: a skeleton getting up off the ground, a picture every fifth of a second.
##
##     godot --path . tests/looks/raise_dead_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://raise_dead_look"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().process_frame
	var player: Wizard = get_tree().get_first_node_in_group("player")
	player.facing = 1.0
	var feet := player.global_position
	await get_tree().create_timer(1.8).timeout
	player.casts_made += 1
	lab.spawn_spell("Raise Dead", "positional", feet + Vector2(110.0, 0.0), 0.0, {"length": 90.0, "accuracy": 0.9}, player)
	var last := 0.0
	for k in 9:
		var t := 0.05 + 0.2 * k
		await get_tree().create_timer(t - last).timeout
		last = t
		get_viewport().get_texture().get_image().save_png("%s/rise_%02d.png" % [out_dir, k])
	get_tree().quit()
