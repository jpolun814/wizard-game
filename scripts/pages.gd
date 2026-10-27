class_name Pages
extends RefCounted

## The wizard's spellbook in a world: a few spells to start with, and a page for each of the rest lying somewhere on the map. A spell
## or chant can only be cast once its page has been found. In the waiting room every page is known. A page is a spell's name, or
## "chant:" and a chant's id (the Mark and the Return share one page, the Mark's).
##
## Where they lie: every page that opens a gate is in a hall outside the locked areas, so the way on is never shut behind itself. Pages
## that open no gate may also lie in the locked areas, as the reward for getting in. The dark wizard keeps a few of those: they are
## left out of the map (the stash).

## What every wizard starts with: spells for an attack, a light, a shove, a defence and a way to move, and the chants of the land, of
## insight and of the bonfire.
const STARTER := ["Ignite", "Flare", "Push", "Barrier", "Shadow Step", "chant:minimap", "chant:insight", "chant:bonfire"]
## Spells that open no gate, and chants that do not: the ones that may lie in a locked area or in the dark wizard's stash.
const LOCKABLE := ["Frostbolt", "Icicles", "Ice Prison", "Blizzard", "Stonefall", "Mudslide", "Earthquake", "Bramble", "Spore Puff",
		"Flytrap", "Hex", "Abyss", "chant:boundless", "chant:double_jump", "chant:haste"]
const STASH := 0  # how many pages the dark wizard keeps back; none for now

static var active := false          # true in a world: only the pages found are known
static var known := {}              # page -> true
static var stash: Array[String] = []  # what the dark wizard keeps


## A new run: only the starter spells are known.
static func begin() -> void:
	active = true
	known = {}
	stash = []
	for spell in STARTER:
		known[spell] = true


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
		if not STARTER.has(page):
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
	# The locked areas, but not the boss's own: one page in each, in the room farthest from the way in.
	var inner_locks := graph.locks.filter(func(lock: Dictionary) -> bool: return not lock["boss"])
	for lock: Dictionary in inner_locks:
		if lockable.is_empty():
			break
		var rooms: Array = lock["rooms"]
		var room: int = rooms[rng.randi() % rooms.size()]
		placed.append({"page": lockable.pop_back(), "room": room})
	var free := []  # the halls outside every locked area, off the surface
	for room in graph.rooms:
		if room["lock"] == -1 and not room.has("surface") and room["id"] != graph.boss:
			free.append(room["id"])
	_shuffle(free, rng)
	var rest: Array[String] = open + lockable
	_shuffle(rest, rng)
	for k in rest.size():
		placed.append({"page": rest[k], "room": free[k % free.size()]})
	return {"placed": placed, "stash": kept}


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var held = list[i]
		list[i] = list[j]
		list[j] = held
