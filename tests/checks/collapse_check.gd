extends Check
## Plays a match through its collapses: a world, then the smaller worlds the portal throws everyone into, to the last, which has no caves
## and does not collapse. Checks each world's size, that the pages and the wizards carry over, and that the last is open. The time in each
## world is shortened (hurry=), so it takes a minute or two.
##
##     godot --headless --path . tests/checks/collapse_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _worlds_seen := 0
var _clock := 0.0
var _world_clock := 0.0
var _last: World
var _total_pages := 0
var _standing: Array[bool] = []  # by seat, in the last moment of the world before: who had not been beaten (they fight on the way, and some are)
var _books: Array = []           # and the pages each held
var _biomes_seen: Array[String] = []


func _ready() -> void:
	MatchState.hurry = 0.05
	World.random_start = false
	World.arrive_by_portal = false
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
	if is_instance_valid(_last) and scene == _last:
		_note(_last)
	if _last != null and is_instance_valid(_last) and _worlds_seen == MatchState.STAGES.size() and _world_clock > 15.0:
		_verdict(not _last.leaving and MatchState.pending == false, "the last world does not collapse")
		_finish()
	if _world_clock > 120.0:
		_verdict(false, "stuck in world %d" % _worlds_seen)
		_finish()


## What each seat is and holds now, to be set against what comes into the next world. The person, who only stands there, is kept on their feet: a person beaten ends the match.
func _note(world: World) -> void:
	world.player.max_stamina = Wizard.MAX_STAMINA
	_standing = []
	_books = []
	for seat in world.seats.size():
		var wizard: Wizard = world.seats[seat]
		_standing.append(is_instance_valid(wizard) and not wizard.dead)
		_books.append(world.ledgers[seat].pages.keys())


func _arrived(world: World) -> void:
	_last = world
	_world_clock = 0.0
	var stage := _worlds_seen
	_worlds_seen += 1
	var plan: Dictionary = MatchState.plan_of(stage)
	_verdict(MatchState.stage == stage, "world %d is stage %d (%d)" % [stage + 1, stage, MatchState.stage])
	_verdict(ArenaGen.world_size.x == plan["width"], "world %d is %d tiles wide (%d)" % [stage + 1, plan["width"], ArenaGen.world_size.x])
	_verdict(world.graph.rooms.size() > 1 or not plan["caves"] or stage == 0, "world %d has halls (%d)" % [stage + 1, world.graph.rooms.size()])
	var biome: String = world.graph.surface["biomes"][0]["name"]
	_verdict(biome == MatchState.biome_of(stage), "world %d is the %s the seed picked (%s)" % [stage + 1, MatchState.biome_of(stage), biome])
	_verdict(not _biomes_seen.has(biome), "no biome comes up twice (%s)" % biome)
	_biomes_seen.append(biome)
	if stage == MatchState.STAGES.size() - 1:
		_verdict(world.graph.rooms.size() == 1 and world.castle_x == -1 and world.gates.is_empty(), "the last world is all open sky: no halls, no castle, no gates (%d halls)" % world.graph.rooms.size())
	var known := {}  # every page some wizard holds: wizards start with some in common
	for ledger in world.ledgers:
		for page in ledger.pages:
			known[page] = true
	var held := known.size()
	var repeated := []  # a page that lies in this world and is already in a wizard's book
	for pickup: PagePickup in get_tree().get_nodes_in_group("pages"):
		if pickup.spoils.is_empty() and known.has(pickup.page):
			repeated.append(pickup.page)
	_verdict(repeated.is_empty(), "no page lies in world %d that a wizard already holds %s" % [stage + 1, str(repeated)])
	var lying := get_tree().get_nodes_in_group("pages").size()
	var starting := 0
	if stage == 0:
		for seat in 4:
			starting += Pages.cluster_of(MatchState.seed_base, seat, 4).size()  # the first world also holds each seat's starting pages
	_verdict(lying <= Pages.count_for(MatchState.biome_of(stage), WorldGraph.size.x) + starting + 2, "a world lays no more pages than it is meant to (%d lying, %d held)" % [lying, held])
	for seat in _books.size():
		var lost: Array = _books[seat].filter(func(page: String) -> bool: return not world.ledgers[seat].pages.has(page))
		_verdict(lost.is_empty(), "seat %d still holds every page it had (%d; lost %s)" % [seat, _books[seat].size(), lost])
	var wizards := 0
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != world.player:
			wizards += 1
			_verdict(wizard.global_position.x > 0.0 and wizard.global_position.x < ArenaGen.world_size.x * 32.0, "a wizard stands inside world %d" % (stage + 1))
	var expected := World.WIZARDS - 1 if stage == 0 else _standing.slice(1).count(true)
	_verdict(wizards == expected, "every rival that was standing is in world %d (%d of %d)" % [stage + 1, wizards, expected])
	var spread: Array[float] = [world.player.global_position.x]
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != world.player:
			spread.append(wizard.global_position.x)
	spread.sort()
	var least := 1.0e9
	for k in range(1, spread.size()):
		least = minf(least, spread[k] - spread[k - 1])
	_verdict(least > 32.0 * 40.0 * plan["width"] / 1200.0, "the wizards land well apart (the nearest pair %.0f px)" % least)


func _finish() -> void:
	print("the match plays through its collapses" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
