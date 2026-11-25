extends Node

## A picture of a flare's light in the underground, to see whether the glow is smooth or blocky.
##
##     godot --audio-driver Dummy --path . tests/looks/flare_look.tscn -- out=DIR     (needs a window)

var out_dir := "user://flare_look"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out_dir = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 13  # the underground
	var arena: Node = load("res://scenes/world.tscn").instantiate()
	add_child(arena)
	for k in 90:
		await get_tree().physics_frame
	var flare := Flare.new()
	flare.caster = arena.player
	arena.add_child(flare)
	for k in 60:
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("%s/flare.png" % out_dir)
	get_tree().quit()
