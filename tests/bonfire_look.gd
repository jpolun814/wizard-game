extends Node

## Pictures of a bonfire beside a wizard, in the waiting room or, with `seed=N`, in the world of that seed (needs a window). Seeds that deal each
## kind of world: 0 jungle, 1 graveyard, 4 mountains, 5 ashlands, 9 castle, 13 underground.
##
##     godot --path . tests/bonfire_look.tscn -- out=DIR [seed=N]

func _ready() -> void:
	var out := ""
	var seed_wanted := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
		if argument.begins_with("seed="):
			seed_wanted = int(argument.trim_prefix("seed="))
	var scene: Node
	if seed_wanted >= 0:
		World.random_start = false
		World.arrive_by_portal = false
		World.next_seed = seed_wanted
		scene = load("res://scenes/world.tscn").instantiate()
	else:
		scene = load("res://scenes/lab.tscn").instantiate()
	add_child(scene)
	await _frames(40)
	var player: Wizard = scene.player
	player.infinite_time = 600.0
	var fire := Bonfire.new()
	scene.add_child(fire)
	fire.global_position = player.global_position + Vector2(90.0, 0.0)
	await _frames(60)
	DirAccess.make_dir_recursive_absolute(out)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/bonfire.png")
	get_tree().quit()


func _frames(count: int) -> void:
	for k in count:
		await get_tree().physics_frame
