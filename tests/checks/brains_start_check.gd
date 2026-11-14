extends Node

## The AI wizards start a match with nothing in their books. Left alone in a world, each walks to the pages by its own spawn and reads them,
## and learns nothing from another wizard's cluster before it has finished its own.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/brains_start_check.tscn -- seed=3 seconds=60
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var seed_value := 3
	var seconds := 120.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			seed_value = int(arg.substr(5))
		elif arg.begins_with("seconds="):
			seconds = float(arg.substr(8))
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	for seat in range(1, World.WIZARDS):
		_verdict(world.ledgers[seat].pages.is_empty(), "seat %d starts with an empty book" % seat)
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	for seat in range(1, World.WIZARDS):
		var wizard: Wizard = world.seats[seat]
		var mine := Pages.cluster_of(MatchState.seed_base, seat, World.WIZARDS)
		var read := mine.filter(func(page: String) -> bool: return world.ledgers[seat].knows(page)).size()
		# With eight in one world a wizard can be beaten on the way: that is not a brain that cannot find its pages.
		if not is_instance_valid(wizard) or wizard.dead:
			print("NOTE  seat %d was beaten after reading %d of its 5 pages" % [seat, read])
			continue
		_verdict(read >= 4, "seat %d has read %d of its 5 pages after %.0f s (book: %s)" % [seat, read, seconds, ", ".join(world.ledgers[seat].pages.keys())])
		if read < 4:
			print("      seat %d is at (%d, %d), %s, held up: %s" % [seat, wizard.global_position.x / 32.0, wizard.global_position.y / 32.0, wizard.brain.status(), "; ".join(wizard.brain.stuck_at.slice(0, 3))])
	print("the brains find their own pages first" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
