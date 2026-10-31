extends Node

## Pictures of a Geyser and a Tide Surf cast by the pond in the waiting room, to judge how the water looks.
##
##     godot --path . tests/water_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://water_look"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 20:
		await get_tree().process_frame
	var pond: Pond = get_tree().get_nodes_in_group("ponds")[0]
	var player: Wizard = get_tree().get_first_node_in_group("player")
	var edge := SpellTargets.solid_below(lab.get_world_2d(), Vector2(pond.global_position.x + pond.width + 90.0, 100.0))
	player.global_position = edge + Vector2(-260.0, -40.0)
	for k in 30:
		await get_tree().process_frame
	var geyser := Geyser.new()
	geyser.position = edge + Vector2(0.0, -10.0)
	geyser.ground = lab._ground if "_ground" in lab else null
	lab.add_child(geyser)
	print("geyser at ", geyser.global_position, " pond at ", pond.global_position, " width ", pond.width, " player ", player.global_position)
	var times := [0.4, 0.8, 1.0, 1.4]
	var last := 0.0
	for t in times:
		await get_tree().create_timer(t - last).timeout
		last = t
		_shot("geyser_%.1f" % t)
	await get_tree().create_timer(2.5).timeout
	player.global_position = Vector2(pond.global_position.x - 120.0, edge.y - 20.0)
	for k in 20:
		await get_tree().process_frame
	var surf := TideSurf.new()
	surf.caster_node = player
	surf.direction = 1.0
	lab.add_child(surf)
	last = 0.0
	for t in [0.3, 0.8, 1.5, 3.5]:
		await get_tree().create_timer(t - last).timeout
		last = t
		_shot("surf_%.1f" % t)
	get_tree().quit()


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
