extends Node

## The setting "Trained AI legs": the AI wizards of a match get the trained network for their legs, decide with it, and move.
##
##     godot --headless --fixed-fps 60 --path . tests/learned_ai_check.tscn

var _failures := 0


func _ready() -> void:
	GameSettings.values["learned_ai"] = true
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 3
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var brains: Array[LearnedBrain] = []
	for rival: Wizard in world._rivals:
		if rival.brain is LearnedBrain and rival.brain.policy != null:
			brains.append(rival.brain)
	_verdict(brains.size() == world._rivals.size() and brains.size() > 0, "every AI wizard has the trained legs (%d of %d)" % [brains.size(), world._rivals.size()])
	var start := {}
	for rival: Wizard in world._rivals:
		start[rival] = rival.global_position
	await get_tree().create_timer(12.0).timeout
	var decided := 0
	var moved := 0
	for b in brains:
		decided += 1 if b.learned else 0
		moved += 1 if b.wizard.global_position.distance_to(start[b.wizard]) > 60.0 else 0
	_verdict(decided == brains.size(), "and they decide with it (%d)" % decided)
	_verdict(moved > 0, "and move about (%d of %d)" % [moved, brains.size()])
	GameSettings.values["learned_ai"] = false
	print("the trained legs hold" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
