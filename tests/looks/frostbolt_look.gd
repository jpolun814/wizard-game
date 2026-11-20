extends Node

## A Frostbolt in flight and bursting on a dummy a long way off, to judge its sprite.
##
##     godot --path . tests/looks/frostbolt_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://frostbolt_look"


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
	var dummy: Mob = lab.add_mob("dummy", feet + Vector2(420.0, 0.0))
	dummy.max_hp = 5000
	dummy.hp = 5000
	await get_tree().create_timer(1.8).timeout
	lab.spawn_spell("Frostbolt", "directional", player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, player)
	var last := 0.0
	for t: float in [0.1, 0.25, 0.4, 0.5, 0.58, 0.64, 0.72, 0.9]:
		await get_tree().create_timer(t - last).timeout
		last = t
		get_viewport().get_texture().get_image().save_png("%s/frostbolt_%d.png" % [out_dir, int(t * 100.0)])
	get_tree().quit()
