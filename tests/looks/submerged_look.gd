extends Node

## Pictures of a wizard, a boulder and a spark in the waiting room's pond and in its lava: whatever lies under the surface should take the liquid's color.
##
##     godot --fixed-fps 60 --path . tests/looks/submerged_look.tscn -- out=DIR     (needs a window)


func _ready() -> void:
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		pond.ensure_grid()
		var at := pond.global_position + Vector2(pond.width * 0.5, 30.0)
		var boulder := Boulder.new()
		boulder.earth = lab.earth_texture()
		boulder.global_position = at + Vector2(-50.0, -40.0)
		lab.add_child(boulder)
		lab.player.global_position = at + Vector2(40.0, 0.0)
		lab.player.velocity = Vector2.ZERO
		for k in 90:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/submerged_%s.png" % [out, "lava" if pond.lava else "water"])
		boulder.queue_free()
	get_tree().quit()
