extends Node

## F9 starts a recording of a person's play: a file with the keys pressed and the wizard's state, and F9 again ends it.

func _ready() -> void:
	var arena: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(arena)
	await get_tree().create_timer(1.0).timeout
	var recorder: PlayRecorder = _find(arena)
	var ok := recorder != null
	if ok:
		var f9 := InputEventKey.new()
		f9.keycode = KEY_F9
		f9.physical_keycode = KEY_F9
		f9.pressed = true
		recorder._input(f9)
		var d := InputEventKey.new()
		d.physical_keycode = KEY_D
		d.keycode = KEY_D
		d.pressed = true
		recorder._input(d)
		await get_tree().create_timer(1.0).timeout
		recorder._input(f9)
		var dir := DirAccess.open("user://play_logs")
		var text := ""
		if dir != null:
			var newest := ""
			for name in dir.get_files():
				if name > newest:
					newest = name
			text = FileAccess.get_file_as_string("user://play_logs/" + newest)
		ok = text.contains("K key D down") and text.contains(" S ") and text.contains(" G ") and text.contains("WORLD") and text.contains("END")
		if not ok:
			print("log was: ", text.substr(0, 600))
	print("PASS recorder writes keys and state" if ok else "FAIL recorder")
	get_tree().quit()


func _find(node: Node) -> PlayRecorder:
	for child in node.get_children():
		if child is PlayRecorder:
			return child
		var found := _find(child)
		if found != null:
			return found
	return null
