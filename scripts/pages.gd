class_name Pages
extends RefCounted

## The pages of the game: a few spells to start each wizard with (see deal), and a page for each of the rest lying somewhere on the map.
## What a wizard holds is their Ledger. A page is a spell's name, or "chant:" and a chant's id (the Mark and the Return share one page,
## the Mark's).
##
## Where they lie: three lie in the open near the start. Every page that opens a gate is in a hall outside the locked areas, so the way on is never shut behind itself. Pages
## that open no gate may also lie in the locked areas, as the reward for getting in.

## What every wizard starts with: one spell to attack, one to move and one to defend, each drawn by chance from its own list, and the
## incantations of the bonfire and of the rift. Every spell in these lists works alone.
const ATTACKS := ["Ignite", "Fire Breath", "Spark", "Frostbolt", "Stonefall"]
const MOVES := ["Shadow Step", "Push", "Liana"]
const DEFENCES := ["Barrier", "Decoy", "Stone Wall", "Smoke Screen"]
const CHANTS := ["chant:bonfire", "chant:rift"]
## Spells that open no gate, and chants that do not: the ones that may lie in a locked area.
const LOCKABLE := ["Frostbolt", "Icicles", "Ice Prison", "Blizzard", "Stonefall", "Mudslide", "Earthquake", "Bramble", "Spore Puff",
		"Flytrap", "Hex", "Black Hole", "Tide Surf", "Blood Bolt", "Offering", "Burst", "Crimson Veil", "Adrenaline", "Faint", "chant:boundless", "chant:double_jump", "chant:haste"]
const ON_SURFACE := 3  # pages that lie out in the open near the start, so the first one is found within a minute
const IN_CASTLE := 2   # and pages in the castle, up on its second floor: not one to a room, only a reward for the climb
const CASTLE_SPOTS := [Vector2i(52, 22), Vector2i(90, 22)]  # where: a column from the castle's west end, and the height of the floor in rows

## Deals each wizard their starting pages, the same way for the same seed. Wizards are given different spells where the lists are long enough
## (a list shorter than the wizards repeats), so a wizard's starter spell is theirs alone, with no page of it on the map for another to find.
static func deal(seed_value: int, wizards: int) -> Array[Ledger]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shuffled := []
	for list: Array in [ATTACKS, MOVES, DEFENCES]:
		var copy := list.duplicate()
		_shuffle(copy, rng)
		shuffled.append(copy)
	var out: Array[Ledger] = []
	for k in wizards:
		var starters := []
		for copy: Array in shuffled:
			starters.append(copy[k % copy.size()])
		starters.append_array(CHANTS)
		out.append(Ledger.of(starters))
	return out


## Every page there is.
static func every() -> Array[String]:
	var out: Array[String] = []
	for spell in SpellData.SPELLS:
		out.append(spell)
	for id in RitualInput.RITUALS:
		if id != "recall":
			out.append("chant:" + id)
	return out


## A page's name as the reader sees it.
static func title_of(page: String) -> String:
	if page.begins_with("chant:"):
		return RitualInput.RITUALS[page.trim_prefix("chant:")]["name"]
	return page


## Where each page lies: [{"page", "room": a room's id}], from the graph and a rng. The pages the wizards start with are left off the map.
static func plan(graph: WorldGraph, rng: RandomNumberGenerator, dealt: Array[Ledger]) -> Array:
	var items: Array[String] = []
	for page in every():
		if not dealt.any(func(ledger: Ledger) -> bool: return ledger.knows(page)):
			items.append(page)
	var lockable: Array[String] = []
	var open: Array[String] = []
	for page in items:
		if LOCKABLE.has(page):
			lockable.append(page)
		else:
			open.append(page)
	_shuffle(lockable, rng)
	_shuffle(open, rng)
	var placed := []
	var spots: Array[Vector2] = []  # where pages already lie, in tiles, so the next one goes as far from them as it can
	var rest: Array[String] = open + lockable
	_shuffle(rest, rng)
	for column in _surface_columns(graph, mini(ON_SURFACE, rest.size())):  # late in a match few pages are left
		placed.append({"page": rest.pop_back(), "room": 0, "x": column})  # room 0 is the surface
		spots.append(Vector2(column, 0))
	var castles: Array = graph.surface["castles"]
	if not castles.is_empty():  # the pages up in the castles are shared out among them, one to a castle before any has a second
		for k in mini(IN_CASTLE, rest.size()):
			var castle_at: int = castles[k % castles.size()]
			var spot: Vector2i = CASTLE_SPOTS[(k / castles.size()) % CASTLE_SPOTS.size()]
			placed.append({"page": rest.pop_back(), "room": 0, "castle": spot, "castle_x": castle_at})
			spots.append(Vector2(castle_at + spot.x, 0))
	# The locked areas: only pages that open no gate lie in them, one to a room, as the reward for getting in.
	var inner_rooms := []
	for lock: Dictionary in graph.locks:
		inner_rooms.append_array(lock["rooms"])
	_shuffle(inner_rooms, rng)
	for page in lockable.duplicate():
		if not rest.has(page):
			lockable.erase(page)  # already out on the surface or in the castle
	_shuffle(lockable, rng)
	while not inner_rooms.is_empty() and not lockable.is_empty():
		var room := _farthest(graph, inner_rooms, spots)
		inner_rooms.erase(room)
		var page: String = lockable.pop_back()
		rest.erase(page)
		placed.append({"page": page, "room": room})
		spots.append(Vector2(graph.rooms[room]["cx"], graph.rooms[room]["cy"]))
	var free := []  # the halls outside every locked area, off the surface
	for room in graph.rooms:
		if room["lock"] == -1 and not room.has("surface"):
			free.append(room["id"])
	if free.is_empty():  # a world with no caves: the rest lie out in the open, spread along it
		for column in _spread_columns(graph, rest.size()):
			placed.append({"page": rest.pop_back(), "room": 0, "x": column})
		return placed
	var open_halls := free.duplicate()
	while not rest.is_empty():
		if open_halls.is_empty():
			open_halls = free.duplicate()  # more pages than halls: the second round doubles up, as far apart as can be
		var room := _farthest(graph, open_halls, spots)
		open_halls.erase(room)
		placed.append({"page": rest.pop_back(), "room": room})
		spots.append(Vector2(graph.rooms[room]["cx"], graph.rooms[room]["cy"]))
	return placed


## The room, of those given, whose middle is farthest from every spot already taken (the first when nothing is).
static func _farthest(graph: WorldGraph, candidates: Array, spots: Array[Vector2]) -> int:
	var best: int = candidates[0]
	var best_gap := -1.0
	for room: int in candidates:
		var at := Vector2(graph.rooms[room]["cx"], graph.rooms[room]["cy"])
		var gap := 1.0e9
		for spot in spots:
			gap = minf(gap, at.distance_to(spot))
		if gap > best_gap:
			best_gap = gap
			best = room
	return best


## Columns of open ground close to the start, away from the castle and the pools, a stretch apart, nearest first.
static func _surface_columns(graph: WorldGraph, count: int) -> Array[int]:
	var out: Array[int] = []
	var start: int = graph.surface["start"]
	var castles: Array = graph.surface["castles"]
	for step in 40:
		var column := start + (step / 2 + 1) * 28 * (1 if step % 2 == 0 else -1)
		var clear := true
		for castle: int in castles:
			clear = clear and (column < castle - 6 or column > castle + SurfaceGen.CASTLE_WIDTH + 6)
		for pond: Dictionary in graph.surface["ponds"]:
			clear = clear and (column < pond["a"] - 4 or column > pond["b"] + 4)
		if clear:
			out.append(column)
			if out.size() == count:
				break
	return out


## Columns evenly spread along the surface, each moved off the pools.
static func _spread_columns(graph: WorldGraph, count: int) -> Array[int]:
	var out: Array[int] = []
	var first := SurfaceGen.MARGIN + 10
	var width := WorldGraph.size.x - first * 2
	for k in count:
		var column := first + roundi(width * (k + 0.5) / count)
		for pond: Dictionary in graph.surface["ponds"]:
			if column >= pond["a"] - 4 and column <= pond["b"] + 4:
				column = pond["b"] + 5
		out.append(column)
	return out


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var held = list[i]
		list[i] = list[j]
		list[j] = held
