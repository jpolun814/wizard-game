class_name Pages
extends RefCounted

## The wizard's spellbook in a world: a few spells to start with, and a page for each of the rest lying somewhere on the map. A spell
## or chant can only be cast once its page has been found. In the waiting room every page is known. A page is a spell's name, or
## "chant:" and a chant's id (the Mark and the Return share one page, the Mark's).
##
## Where they lie: three lie in the open near the start. Every page that opens a gate is in a hall outside the locked areas, so the way on is never shut behind itself. Pages
## that open no gate may also lie in the locked areas, as the reward for getting in. The dark wizard keeps a few of those: they are
## left out of the map (the stash).

## What every wizard starts with: one spell to attack, one to move and one to defend, each drawn by chance from its own list, and the
## incantations of the bonfire and of the rift. Every spell in these lists works alone.
const ATTACKS := ["Ignite", "Fire Breath", "Spark", "Frostbolt", "Stonefall"]
const MOVES := ["Shadow Step", "Push", "Liana"]
const DEFENCES := ["Barrier", "Decoy", "Stone Wall", "Smoke Screen"]
const CHANTS := ["chant:bonfire", "chant:rift"]
## Spells that open no gate, and chants that do not: the ones that may lie in a locked area or in the dark wizard's stash.
const LOCKABLE := ["Frostbolt", "Icicles", "Ice Prison", "Blizzard", "Stonefall", "Mudslide", "Earthquake", "Bramble", "Spore Puff",
		"Flytrap", "Hex", "Abyss", "Tide Surf", "Blood Bolt", "Transfusion", "Adrenaline", "Hemorrhage", "Clot", "Faint", "chant:boundless", "chant:double_jump", "chant:haste"]
const ON_SURFACE := 3  # pages that lie out in the open near the start, so the first one is found within a minute
const IN_CASTLE := 2   # and pages in the castle, up on its second floor: not one to a room, only a reward for the climb
const CASTLE_SPOTS := [Vector2i(52, 22), Vector2i(90, 22)]  # where: a column from the castle's west end, and the height of the floor in rows
const STASH := 0  # how many pages the dark wizard keeps back; none for now

static var active := false          # true in a world: only the pages found are known
static var known := {}              # page -> true
static var stash: Array[String] = []  # what the dark wizard keeps


## A new run: only the starter pages are known, which the seed picks.
static func begin(seed_value := 0) -> void:
	active = true
	known = {}
	stash = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for list: Array in [ATTACKS, MOVES, DEFENCES]:
		known[list[rng.randi() % list.size()]] = true
	for chant in CHANTS:
		known[chant] = true


## The waiting room: everything is known.
static func end() -> void:
	active = false


static func knows(page: String) -> bool:
	return not active or known.has(page)


## A spell, by its name, or a chant by its id.
static func knows_spell(spell: String) -> bool:
	return knows(spell)


static func knows_chant(ritual_id: String) -> bool:
	return knows("chant:" + ("mark" if ritual_id == "recall" else ritual_id))


static func learn(page: String) -> void:
	known[page] = true


static func learn_all() -> void:
	for page in every():
		known[page] = true


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


## Where each page lies: {"placed": [{"page", "room": a room's id}], "stash": [pages]}, from the graph and a rng.
static func plan(graph: WorldGraph, rng: RandomNumberGenerator) -> Dictionary:
	var items: Array[String] = []
	for page in every():
		if not known.has(page):
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
	var kept: Array[String] = []
	for k in mini(STASH, lockable.size()):
		kept.append(lockable.pop_back())
	var placed := []
	# The locked areas, but not the boss's own: only pages that open no gate lie in them, one to a room, as the reward for getting in.
	var inner_rooms := []
	for lock: Dictionary in graph.locks:
		if not lock["boss"]:
			inner_rooms.append_array(lock["rooms"])
	_shuffle(inner_rooms, rng)
	for room: int in inner_rooms:
		if lockable.is_empty():
			break
		placed.append({"page": lockable.pop_back(), "room": room})
	var free := []  # the halls outside every locked area, off the surface
	for room in graph.rooms:
		if room["lock"] == -1 and not room.has("surface") and room["id"] != graph.boss:
			free.append(room["id"])
	_shuffle(free, rng)
	var rest: Array[String] = open + lockable
	_shuffle(rest, rng)
	for column in _surface_columns(graph, ON_SURFACE):
		placed.append({"page": rest.pop_back(), "room": 0, "x": column})  # room 0 is the surface
	if graph.surface["castle"] >= 0:
		for spot in CASTLE_SPOTS.slice(0, IN_CASTLE):
			placed.append({"page": rest.pop_back(), "room": 0, "castle": spot})
	for k in rest.size():
		placed.append({"page": rest[k], "room": free[k % free.size()]})  # one to a hall until every hall has one
	return {"placed": placed, "stash": kept}


## Columns of open ground close to the start, away from the castle and the pools, a stretch apart, nearest first.
static func _surface_columns(graph: WorldGraph, count: int) -> Array[int]:
	var out: Array[int] = []
	var start: int = graph.surface["start"]
	var castle: int = graph.surface["castle"]
	for step in 40:
		var column := start + (step / 2 + 1) * 28 * (1 if step % 2 == 0 else -1)
		var clear: bool = column < castle - 6 or column > castle + SurfaceGen.CASTLE_WIDTH + 6
		for pond: Dictionary in graph.surface["ponds"]:
			clear = clear and (column < pond["a"] - 4 or column > pond["b"] + 4)
		if clear:
			out.append(column)
			if out.size() == count:
				break
	return out


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var held = list[i]
		list[i] = list[j]
		list[j] = held
