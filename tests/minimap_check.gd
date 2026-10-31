extends Node

## The minimap stays in the top right corner when the window is resized.
##
##     godot --headless --fixed-fps 60 --path . tests/minimap_check.tscn

var failed := false


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failed = true


func _ready() -> void:
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 10:
		await get_tree().process_frame
	var map: Minimap = lab._minimap
	map.visible = true
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540)]:
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = size
		for k in 4:
			await get_tree().process_frame
		var screen := get_viewport().get_visible_rect().size
		var gap := screen.x - (map.position.x + map.size.x)
		_check(absf(gap - Minimap.MARGIN) < 1.0 and absf(map.position.y - (Minimap.MARGIN + 60.0)) < 1.0, "at %s the map is in the top right corner (%.0f from the right edge of %.0f)" % [size, gap, screen.x])
	print("the map keeps its corner" if not failed else "minimap check FAILED")
	get_tree().quit(1 if failed else 0)
