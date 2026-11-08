extends Node

## A game alone is recorded without F9, from the start of the world, and the file is closed (and kept in user://play_logs) when the person is out.

func _ready() -> void:
	PlayRecorder.force_auto = true
	seed(5)
	World.next_seed = 5
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(2.0).timeout
	var recorder: PlayRecorder = get_tree().root.get_node_or_null("PlayRecorder")
	var ok := recorder != null and recorder._file != null and recorder._solo
	var path := recorder._path if recorder != null else ""
	PlayRecorder.finish(get_tree())
	var text := FileAccess.get_file_as_string(path) if path != "" else ""
	ok = ok and path.contains("solo_") and text.contains(" S ") and text.contains(" G ") and text.contains("END") and recorder._file == null
	DirAccess.remove_absolute(path)  # (this test's own file)
	print("PASS a game alone is recorded by itself and kept" if ok else "FAIL solo recording (%s)" % path)
	get_tree().quit()
