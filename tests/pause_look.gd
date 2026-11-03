extends Node

## Pictures of the pause screen in each kind of world, to see that it looks the same in all.
##
##     godot --path . tests/pause_look.tscn -- out=DIR   (needs a window)

func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	World.random_start = false
	World.arrive_by_portal = false
	for biome in ["graveyard", "ashlands", "jungle", "castle"]:
		World.next_seed = 3
		MatchState.hurry = 100.0
		MatchState.begin(3)
		MatchState.forced_biome = biome
		MatchState.pending = true
		MatchState.ledgers = Pages.deal(3 + 31, World.WIZARDS)
		for k in 4:
			MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
		var world: World = load("res://scenes/world.tscn").instantiate()
		add_child(world)
		for i in 150:
			await get_tree().process_frame
		world.hud.toggle_pause()
		for i in 10:
			await get_tree().process_frame
		if out != "":
			get_viewport().get_texture().get_image().save_png("%s/pause_%s.png" % [out, biome])
		world.hud.toggle_pause()
		world.queue_free()
		await get_tree().process_frame
	MatchState.forced_biome = ""
	get_tree().quit()
