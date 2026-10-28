extends Node

## Plays a match through its collapses: a world, then the smaller worlds the portal throws everyone into, to the last, which has no caves
## and does not collapse. Checks each world's size, that the pages and the wizards carry over, and that the last is open. The time in each
## world is shortened (hurry=), so it takes a minute or two.
##
##     godot --headless --path . tests/collapse_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _worlds_seen := 0
var _failures := 0
var _clock := 0.0
var _world_clock := 0.0
var _last: World
var _total_pages := 0
var _held_at_start := 0


func _ready() -> void:
	MatchState.hurry = 0.05
	World.random_start = false
	World.next_seed = 11
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)  # this node outlives the scenes that come and go
	get_tree().current_scene = null
	_total_pages = Pages.every().size()
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(delta: float) -> void:
	_clock += delta
	_world_clock += delta
	var scene := get_tree().current_scene
	if scene is World and scene != _last and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_arrived(scene)
	if _last != null and is_instance_valid(_last) and _worlds_seen == MatchState.STAGES.size() and _world_clock > 15.0:
		_verdict(not _last._leaving and MatchState.pending == false, "the last world does not collapse")
		_finish()
	if _world_clock > 120.0:
		_verdict(false, "stuck in world %d" % _worlds_seen)
		_finish()


func _arrived(world: World) -> void:
	_last = world
	_world_clock = 0.0
	var stage := _worlds_seen
	_worlds_seen += 1
	var plan: Dictionary = MatchState.STAGES[stage]
	_verdict(MatchState.stage == stage, "world %d is stage %d (%d)" % [stage + 1, stage, MatchState.stage])
	_verdict(ArenaGen.world_size.x == plan["width"], "world %d is %d tiles wide (%d)" % [stage + 1, plan["width"], ArenaGen.world_size.x])
	_verdict(world.graph.rooms.size() > 1 or not plan["caves"] == true or stage == 0, "world %d has halls (%d)" % [stage + 1, world.graph.rooms.size()])
	if not plan["caves"]:
		_verdict(world.graph.rooms.size() == 1 and world.castle_x == -1 and world._gates.is_empty(), "the last world is all open sky: no halls, no castle, no gates (%d halls)" % world.graph.rooms.size())
	var known := {}  # every page some wizard holds: wizards start with some in common
	for ledger in world.ledgers:
		for page in ledger.pages:
			known[page] = true
	var held := known.size()
	var lying := get_tree().get_nodes_in_group("pages").size()
	_verdict(held + lying == _total_pages, "every page is held or lies on the map (%d held + %d lying = %d of %d)" % [held, lying, held + lying, _total_pages])
	if stage == 0:
		_held_at_start = held
	else:
		_verdict(held >= _held_at_start, "no page has been lost (%d held, %d at the start)" % [held, _held_at_start])
	var wizards := 0
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.KINDS[mob.kind].role == "wizard":
			wizards += 1
			_verdict(mob.global_position.x > 0.0 and mob.global_position.x < ArenaGen.world_size.x * 32.0, "a wizard stands inside world %d" % (stage + 1))
	_verdict(wizards == 3, "three rival wizards in world %d (%d)" % [stage + 1, wizards])
	var spread: Array[float] = [world.player.global_position.x]
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.KINDS[mob.kind].role == "wizard":
			spread.append(mob.global_position.x)
	spread.sort()
	var least := 1.0e9
	for k in range(1, spread.size()):
		least = minf(least, spread[k] - spread[k - 1])
	_verdict(least > 32.0 * 40.0 * plan["width"] / 1200.0, "the wizards land well apart (the nearest pair %.0f px)" % least)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("the match plays through its collapses" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
