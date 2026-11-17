extends Node

## The waiting room with a wizard made of parts in it, in a few states, through the real wizard and camera. Needs a window:
##   godot --path . tests/looks/parts_game_look.tscn -- out=DIR

func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	GameSettings.path = "user://options_test.cfg"
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.values = GameSettings.DEFAULTS.duplicate()
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().physics_frame
	var player := lab.player
	player.look = PartsLook.seeded_look(7)
	await _wait(30)
	await _shot(out, "idle")
	player.show_cast("Spark")
	await _wait(10)
	await _shot(out, "cast_sky")
	await _wait(40)
	player.show_cast("Earthquake")
	await _wait(10)
	await _shot(out, "cast_ground")
	await _wait(40)
	player.apply_debuff("daze", 2.0)
	await _wait(20)
	await _shot(out, "dazed")
	player.daze_time = 0.0
	player.freeze(3.0)
	await _wait(20)
	await _shot(out, "frozen")
	player.thaw()
	await _wait(60)
	player.show_cast("Fire Breath")
	await _wait(15)
	await _shot(out, "exhale")
	get_tree().quit()


func _wait(frames: int) -> void:
	for k in frames:
		await get_tree().process_frame


func _shot(out: String, name: String) -> void:
	await get_tree().process_frame
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/game_" + name + ".png")
