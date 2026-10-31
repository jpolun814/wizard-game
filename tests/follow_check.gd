extends Node

## Things that live in a pool follow its liquid as it flows: the piranhas keep to the water that is left (and are stranded when it is gone), and
## Frost Bridge lays ice on the surface where it is now.
##
##     godot --headless --fixed-fps 60 --path . tests/follow_check.tscn -- seed=0
## It prints PASS or FAIL for each and exits with code 1 if any failed.

var _failures := 0


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _ready() -> void:
	var seed_value := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var shoals := get_tree().get_nodes_in_group("shoals").filter(func(n: Node) -> bool: return n.pond != null)
	if shoals.is_empty():
		print("SKIP  seed %d has no pond with piranhas" % seed_value)
		get_tree().quit(0)
		return
	var shoal: Piranhas = shoals[0]
	var pond: Pond = shoal.pond
	pond.ensure_grid()
	for k in 30:
		await get_tree().physics_frame
	var in_water := 0
	for fish in shoal._fish:
		if pond.wet_at(fish["pos"]):
			in_water += 1
	_verdict(in_water == shoal._fish.size(), "the fish swim in the water (%d of %d)" % [in_water, shoal._fish.size()])

	# Ice lies on the surface where it is now: dig a pit beside the pool so its level falls, and freeze it.
	var middle := pond.global_position.x + pond.width * 0.5
	var original := pond.surface_at(middle)
	var shore := Vector2(pond.global_position.x - 40.0, pond.global_position.y)
	world._ground.watch([shore], true)
	world._ground.dig(shore + Vector2(0.0, 4.0), 130.0, 96.0)
	for k in 600:
		await get_tree().physics_frame
	var level_before := pond.surface_at(middle)
	_verdict(level_before > original + 2.0, "the pool's level falls when a pit is dug beside it (%.0f to %.0f)" % [original, level_before])
	var froze := pond.freeze_span(middle - 40.0, middle + 40.0)
	_verdict(froze, "a stretch of the water freezes")
	var slab: Dictionary = pond._slabs[pond._slabs.size() - 1] if not pond._slabs.is_empty() else {}
	_verdict(not slab.is_empty() and absf(slab["y"] - level_before) < 1.0, "the ice lies on the surface of the water (%.0f, the water is at %.0f)" % [slab.get("y", 0.0), level_before])

	# A Geyser standing in the pool lifts its water and lets it fall back: the pool loses none.
	for k in 120:
		await get_tree().physics_frame
	var before: float = pond.grid.total()
	var geyser := Geyser.new()
	geyser.ground = world._ground
	geyser.position = Vector2(middle + 60.0, pond.global_position.y + pond.depth - 10.0)
	world.add_child(geyser)
	for k in int((Geyser.LIFE + 1.0) * 60.0):
		await get_tree().physics_frame
	var loose := 0.0
	for other: Pond in get_tree().get_nodes_in_group("ponds"):
		if other.loose:
			loose += other.grid.total()
	_verdict(absf(pond.grid.total() + loose - before) < 0.1, "a geyser in the pool gives back the water it lifts (%.2f before, %.2f after, %.2f spilt elsewhere)" % [before, pond.grid.total(), loose])
	geyser.queue_free()

	# Lily Pads drawn a little above the water float on it.
	var pads := LilyPads.new()
	pads.line = PackedVector2Array([Vector2(middle - 60.0, level_before - 50.0), Vector2(middle + 60.0, level_before - 50.0)])
	world.add_child(pads)
	await get_tree().physics_frame
	var floating := pads._pads.size() > 0
	for pad: Node2D in pads._pads:
		floating = floating and absf(pad.position.y - (pond.grid.surface_at(pad.position.x) - 2.0)) < 1.0
	_verdict(floating, "lily pads drawn above the water settle on its surface (%d pads)" % pads._pads.size())
	pads.queue_free()

	# Drain the pool: the fish are stranded.
	for k in pond.grid.mass.size():
		pond.grid.mass[k] = 0.0
	pond.grid.wake()
	pond.grid.version += 1
	for k in int((Piranhas.STRANDED + 2.0) * 60.0):
		await get_tree().physics_frame
	_verdict(not is_instance_valid(shoal) or shoal.is_queued_for_deletion(), "the fish are stranded when the water is gone")
	print("the fish follow the water" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
