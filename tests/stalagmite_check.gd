extends Node

## A Stalagmite rises out of the ground under the tip of a drawn peak, and hurts whoever touches it.
##
##     godot --headless --fixed-fps 60 --path . tests/stalagmite_check.tscn
##     godot --fixed-fps 60 --path . tests/stalagmite_check.tscn -- out=DIR     (a picture needs a window)

var failed := false


func _ready() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 20:
		await get_tree().process_frame
	var player: Wizard = get_tree().get_first_node_in_group("player")
	var pond: Pond = get_tree().get_nodes_in_group("ponds")[0]
	var ground := SpellTargets.solid_below(lab.get_world_2d(), Vector2(pond.global_position.x + pond.width + 230.0, 100.0))
	player.global_position = ground + Vector2(-200.0, -40.0)
	var tip := ground + Vector2(0.0, -90.0)
	var peak := PackedVector2Array([tip + Vector2(-30.0, 90.0), tip, tip + Vector2(30.0, 90.0)])
	lab._place_shapes("Stalagmite", {"shapes": [peak], "line": peak})
	await get_tree().create_timer(0.6).timeout
	var spikes := get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is Stalagmite)
	_check(spikes.size() == 1, "one spike rises from the drawn peak (%d)" % spikes.size())
	if spikes.size() == 1:
		var spike: Stalagmite = spikes[0]
		_check(absf(spike.global_position.x - tip.x) < 2.0 and absf(spike.global_position.y - ground.y) < 12.0, "and it stands on the ground under the tip (%s, ground %s)" % [spike.global_position, ground])
		_check(spike.danger_at(tip + Vector2(0.0, 30.0)), "and it is dangerous to touch")
	if out_dir != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out_dir)
		get_viewport().get_texture().get_image().save_png(out_dir + "/stalagmite.png")
	print("the stalagmite rises" if not failed else "stalagmite check FAILED")
	get_tree().quit(1 if failed else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true
