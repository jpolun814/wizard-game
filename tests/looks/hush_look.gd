extends Node

## Whether the sound bus closes inside a Silence ring and opens again outside. (Needs a window; pass --audio-driver Dummy.)


func _ready() -> void:
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 40:
		await get_tree().process_frame
	var player: Wizard = lab.player
	var bus := AudioServer.get_bus_index(&"SFX")
	print("before: ", AudioServer.get_bus_volume_db(bus))
	lab.spawn_spell("Silence", "positional", player.center(), 0.0, {"radius": 130.0}, player)
	await get_tree().create_timer(1.0).timeout
	print("inside: ", AudioServer.get_bus_volume_db(bus), " camera ", get_viewport().get_camera_2d().get_screen_center_position(), " player ", player.center())
	player.global_position += Vector2(400.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	print("outside: ", AudioServer.get_bus_volume_db(bus))
	get_tree().quit()
