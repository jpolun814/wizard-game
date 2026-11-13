extends Node

## The first world is entered by falling out of a portal: the wizards start in the air under a portal that is open over each, and land on their places.
##
##     godot --headless --fixed-fps 60 --path . tests/arrival_check.tscn   (add `-- out=DIR` for pictures, needs a window)

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.next_seed = 13
	MatchState.hurry = 100.0
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var place: Vector2 = world.places()[world.my_seat()]
	_verdict(world.player.global_position.y < place.y - 40.0, "the player starts in the air over their place (%.0f over)" % (place.y - world.player.global_position.y))
	_verdict(_count(world) > 0, "a portal is open over them")
	for i in 20:
		await get_tree().process_frame
	if out != "":
		get_viewport().get_texture().get_image().save_png(out + "/arrival_falling.png")
	for i in 120:
		await get_tree().process_frame
	_verdict(world.player.is_on_floor() and absf(world.player.global_position.y - place.y) < 12.0, "and lands on it (%.0f off, on floor %s)" % [world.player.global_position.y - place.y, world.player.is_on_floor()])
	print("the arrival works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _count(world: Node) -> int:
	var n := 0
	for child in world.get_children():
		if child is ArrivalPortal:
			n += 1
	return n


func _verdict(ok: bool, what: String) -> void:
	if what == "":
		return
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
