extends Node

## The F1 panel's "The ending" button: from a world, the screen goes black on its way to the cut-scene after a win, with the player's own wizard as the winner.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/epilogue_jump_check.tscn

func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for k in 10:
		await get_tree().process_frame
	var panel := world.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "The ending")
	print("%s  the F1 panel has the button (%d)" % ["PASS" if panel.size() == 1 else "FAIL", panel.size()])
	Epilogue.winner_look = "none"
	world.go_to_epilogue()
	for k in 10:  # (the black takes 0.8 s to close, and then the scene changes and this check goes with it)
		await get_tree().process_frame
	var black: Array = world.find_children("*", "ColorRect", true, false).filter(func(c: Node) -> bool: return (c.get_parent() as CanvasLayer) != null and (c.get_parent() as CanvasLayer).layer == 100)
	var checks := {
		"the screen is going black": black.size() == 1,
		"the winner is the player's own wizard": Epilogue.winner_look == world.player.look,
	}
	var failed := panel.size() != 1
	for what: String in checks:
		print("%s  %s" % ["PASS" if checks[what] else "FAIL", what])
		failed = failed or not checks[what]
	get_tree().quit(1 if failed else 0)
