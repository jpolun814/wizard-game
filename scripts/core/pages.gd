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
const ATTACKS := ["Ignite", "Fire Breath", "Spark", "Frostbolt", "Stonefall", "Spore Puff", "Firewall", "Stalagmite", "Bramble", "Flytrap",
		"Barbs", "Pebble", "Hailstorm", "Thorn Whip", "Insect Plague", "Flaming Sphere", "Thunderclap", "Raise Dead",
		"Eldritch Blast", "Hemorrhage", "Supernova", "Scythe"]
## Attacks that reach a rival from a distance: every wizard starts with one of these (see deal), so nobody begins with only spells that need an enemy close by.
const RANGED := ["Ignite", "Spark", "Frostbolt", "Stonefall", "Barbs", "Pebble", "Hailstorm", "Thorn Whip", "Flaming Sphere", "Eldritch Blast", "Supernova"]
const MOVES := ["Shadow Step", "Push", "Liana", "Geyser", "Updraft", "Tornado", "Great Oak", "Rocket Jump"]
const DEFENCES := ["Barrier", "Decoy", "Stone Wall", "Smoke Screen", "Gust", "Eclipse", "Sneak", "Featherfall", "Mirage"]
const CHANTS := ["chant:bonfire", "chant:rift"]
## Spells that open no gate, and chants that do not: the ones that may lie in a locked area.
const LOCKABLE := ["Frostbolt", "Icicles", "Ice Prison", "Blizzard", "Stonefall", "Mudslide", "Earthquake", "Stalagmite", "Bramble", "Spore Puff",
		"Flytrap", "Hex", "Black Hole", "Tide Surf", "Crimson Veil", "Adrenaline", "Faint", "Vacuum", "Fight or Flight", "Sneak", "Hunter's Mark", "Wild Shape", "Barbs", "Pebble", "Hailstorm", "Featherfall", "Thunderclap", "Thorn Whip", "Insect Plague", "Leech", "Raise Dead", "Mirage", "Eldritch Blast", "Hemorrhage", "Supernova", "Scythe", "chant:boundless", "chant:double_jump", "chant:haste", "chant:dowsing", "chant:scrying_eye"]
## How many pages lie in a world of each biome, in a world 1000 tiles wide: the ones with little height to spread through (a volcano's
## slopes, the portal fields) hold fewer than those with room to climb or dig. Smaller worlds hold fewer (see count_for). The pages that
## are not laid are simply not in that world: nothing carries over. Which pages each world lays is settled when the match begins (see allotment).
const PER_WORLD := {"graveyard": 16, "mountains": 16, "jungle": 18, "ashlands": 12, "castle": 18, "underground": 20, "portals": 10, "ocean": 14, "sky": 14}
const LEAST := 6  # however small the world
const MIN_APART := 40  # columns between two pages lying out in the open of a world with no halls
const ON_SURFACE := 3  # pages that lie out in the open near the start, so the first one is found within a minute
## Where in a castle they lie: a column from its west end, and the height of the floor in rows (the cellar's is below the ground, so negative).
## Deepest and highest first, then the middle floors, so the few of a small match go to the places hardest to reach.
const CASTLE_SPOTS := [Vector2i(76, 44), Vector2i(15, -11), Vector2i(7, 44), Vector2i(65, -11), Vector2i(50, 33), Vector2i(32, -11), Vector2i(24, 33), Vector2i(33, 22), Vector2i(59, 22), Vector2i(7, 11), Vector2i(76, 11), Vector2i(50, 22), Vector2i(24, 11), Vector2i(59, 33)]

## How many pages lie in a world of this biome and width in tiles.
static func count_for(biome: String, width: int) -> int:
	var base: int = PER_WORLD.get(biome, 14)
	return maxi(LEAST, roundi(base * (0.4 + 0.6 * clampf(width / 1000.0, 0.0, 1.0))))


## The pages that open a kind of gate, wherever the spells that do it are listed (the AI's own lists say which ones).
static func openers_of(kind: String) -> Array:
	var out: Array = []
	for list: Dictionary in [WizardBrain.CLEARS, WizardBrain.WAYS]:
		for page: String in list.get(kind, []):
			out.append(page)
	return out


## Settles, when a match begins, which pages lie in which world of it. The wizards are dealt their own starting pages (see deal), and each world is
## given pages of its own from the others, no page in two places, so no page can lie in a world once a wizard holds it and no two wizards
## start alike. Some pages are given to no one. `counts` is how many pages each world lays, in order. Returns {"worlds": a list of pages for each
## world, "spare": the pages given to no one}.
static func allotment(match_seed: int, wizards: int, counts: Array[int]) -> Dictionary:
	var dealt := deal(match_seed + 31, wizards)
	var pool: Array[String] = []
	for page in every():
		if not dealt.any(func(ledger: Ledger) -> bool: return ledger.knows(page)):
			pool.append(page)
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed + 8191
	_shuffle(pool, rng)
	var worlds: Array = []
	var taken := 0
	for count in counts:
		var mine: Array[String] = []
		mine.assign(pool.slice(taken, mini(taken + count, pool.size())))
		taken += mine.size()
		worlds.append(mine)
	var spare: Array[String] = []
	spare.assign(pool.slice(taken))
	return {"worlds": worlds, "spare": spare}


## A world's allotted pages, with a page that opens each kind of gate it has swapped in from the spare ones where it has none (and no wizard holds one).
static func with_openers(allotted: Array[String], spare: Array[String], held: Array[Ledger], gate_kinds: Array) -> Array[String]:
	var kept := allotted.duplicate()
	for kind: String in gate_kinds:
		var wanted := openers_of(kind)
		if wanted.is_empty() or kept.any(func(p: String) -> bool: return wanted.has(p)) or held.any(func(l: Ledger) -> bool: return wanted.any(func(p: String) -> bool: return l.knows(p))):
			continue
		var extra: Array = spare.filter(func(p: String) -> bool: return wanted.has(p))
		if extra.is_empty() or kept.is_empty():
			continue
		kept.pop_back()
		kept.append(extra[0])
	return kept


## Deals each wizard their starting pages, the same way for the same seed. Wizards are given different spells where the lists are long enough
## (a list shorter than the wizards repeats), so a wizard's starter spell is theirs alone, with no page of it on the map for another to find.
static func deal(seed_value: int, wizards: int) -> Array[Ledger]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shuffled := []
	for list: Array in [RANGED, MOVES, DEFENCES]:
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


## Ledgers with nothing in them, one for each wizard: nobody starts a match with a spell (see cluster_of for where the pages they would
## have been dealt lie instead).
static func start_empty(wizards: int) -> Array[Ledger]:
	var out: Array[Ledger] = []
	for k in wizards:
		out.append(Ledger.new())
	return out


## The pages that lie in a cluster by the spawn of a seat, in the first world of a match: the ones the seat would have been dealt (see deal).
static func cluster_of(match_seed: int, seat: int, wizards: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(deal(match_seed + 31, wizards)[seat].pages.keys())
	return out


## Every page there is.
static func every() -> Array[String]:
	var out: Array[String] = []
	for spell in SpellData.SPELLS:
		out.append(spell)
	for id in RitualInput.RITUALS:
		out.append("chant:" + id)
	return out


## A page's name as the reader sees it.
static func title_of(page: String) -> String:
	if page.begins_with("chant:"):
		return RitualInput.RITUALS[page.trim_prefix("chant:")]["name"]
	return page


## Where each page lies: [{"page", "room": a room's id}], from the graph and a rng. The pages the wizards start with are left off the map.
## `allotted` is the world's own pages from the match's allotment; without it every page no one was dealt lies in the world.
static func plan(graph: WorldGraph, rng: RandomNumberGenerator, dealt: Array[Ledger], allotted: Array = [], gate_kinds := [], spare: Array[String] = [], held: Array[Ledger] = []) -> Array:
	var items := _pages_to_lay(dealt, allotted, gate_kinds, spare, held)
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
	var castles: Array = graph.surface["castles"]
	var outdoors: Array[int] = []  # none lie out of doors in the castle world, which has no out of doors
	if castles.is_empty():
		outdoors = _surface_columns(graph, mini(ON_SURFACE, rest.size()))  # late in a match few pages are left
	for column in outdoors:
		placed.append({"page": rest.pop_back(), "room": 0, "x": column})  # room 0 is the surface
		spots.append(Vector2(column, 0))
	if not castles.is_empty():  # the pages up in the castles are shared out among them, one to a castle before any has a second; in the castle world they all lie there
		for k in rest.size():
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
	if free.is_empty():  # a world with no caves: some lie at the landmarks (a volcano's rim, a mountain's top), the rest out in the open, spread along it
		_lay_in_the_open(graph, rest, outdoors, placed)
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


## The pages this world lays: its own from the match's allotment (with the ones that open its gates), or, with no allotment, every page no one was dealt.
static func _pages_to_lay(dealt: Array[Ledger], allotted: Array, gate_kinds: Array, spare: Array[String], held: Array[Ledger]) -> Array[String]:
	var items: Array[String] = []
	if not allotted.is_empty():
		var mine: Array[String] = []
		mine.assign(allotted)
		items = with_openers(mine, spare, held, gate_kinds)
	else:
		for page in every():
			if not dealt.any(func(ledger: Ledger) -> bool: return ledger.knows(page)):
				items.append(page)
	return items


## A world with no caves: some pages lie at the landmarks (a volcano's rim, a mountain's top), the rest out in the open, spread along the world.
## `rest` is what is still to be laid; `outdoors` the columns already taken.
static func _lay_in_the_open(graph: WorldGraph, rest: Array[String], outdoors: Array[int], placed: Array) -> void:
	var landmarks: Array = graph.surface["landmarks"]
	var in_trees: bool = not graph.surface["trees"].is_empty()  # the jungle's pages are nearly all up in its trees, spread along them
	var wanted := mini(landmarks.size(), rest.size() * 3 / 4 if in_trees else rest.size() / 2)
	var taken: Array[int] = outdoors.duplicate()  # where pages lie so far: out in the open, none lies close to another
	if in_trees:
		for k in wanted:
			placed.append({"page": rest.pop_back(), "room": 0, "x": landmarks[k * landmarks.size() / wanted]})
	else:
		for landmark: int in landmarks:
			if placed.size() - outdoors.size() >= wanted:
				break
			if _far_from(landmark, taken):
				placed.append({"page": rest.pop_back(), "room": 0, "x": landmark})
				taken.append(landmark)
	for column in _spread_columns(graph, rest.size()):
		if not in_trees:
			column = _moved_apart(graph, column, taken)
			taken.append(column)
		placed.append({"page": rest.pop_back(), "room": 0, "x": column})


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
		clear = clear and not in_the_way(graph, column)
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
		for castle: int in graph.surface["castles"]:  # not in the stone: on whichever side of the castle is the nearer
			if column >= castle - 4 and column <= castle + SurfaceGen.CASTLE_WIDTH + 4:
				column = castle - 5 if column - castle < SurfaceGen.CASTLE_WIDTH / 2 else castle + SurfaceGen.CASTLE_WIDTH + 5
		for pit: Dictionary in graph.surface["mud"] + graph.surface["thorns"]:
			if column >= pit["a"] - 2 and column <= pit["b"] + 2:
				column = pit["b"] + 3
		out.append(column)
	return out


## True when a column is at least MIN_APART from every one of these.
static func _far_from(column: int, taken: Array[int]) -> bool:
	for other in taken:
		if absi(column - other) < MIN_APART:
			return false
	return true


## The column, or the nearest one to it, to either side, that is far enough from the pages already lying and not in the way of a pool or a pit.
static func _moved_apart(graph: WorldGraph, column: int, taken: Array[int]) -> int:
	for step in range(0, 200, 4):
		for side in [1, -1]:
			var moved: int = column + step * side
			if moved > SurfaceGen.MARGIN + 6 and moved < WorldGraph.size.x - SurfaceGen.MARGIN - 6 and _far_from(moved, taken) and not in_the_way(graph, moved):
				return moved
	return column


## True when a page could not lie at the column: in a pool, or in a pit of mud or a thicket.
static func in_the_way(graph: WorldGraph, column: int) -> bool:
	for span: Dictionary in graph.surface["ponds"]:
		if column >= span["a"] - 4 and column <= span["b"] + 4:
			return true
	for span: Dictionary in graph.surface["mud"] + graph.surface["thorns"]:
		if column >= span["a"] - 2 and column <= span["b"] + 2:
			return true
	return false


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var held = list[i]
		list[i] = list[j]
		list[j] = held
