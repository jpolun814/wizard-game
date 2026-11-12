class_name MatchState
extends RefCounted

## What carries from one world of a match to the next. The portal is growing unstable: after a few minutes it collapses, and the wizards
## who are left are thrown into a new world, smaller than the last; the last is a small open one with nowhere to hide. The pages no one
## has found lie on in the new world; each wizard keeps their own pages and what is left of their stamina.

## Each world of a match: how wide it is in tiles and how long the wizards have in it before it collapses (0: it does not).
## Each world is one biome (see biome_of): the first three take three of the nine biomes (the portal fields, the ocean and the sky count) in an order the seed picks, and the last is open sky.
## Whether it has halls underground depends on the biome (SurfaceGen.has_halls): only the castle and the underground do.
const STAGES := [
	{"width": 900, "seconds": 180.0},
	{"width": 660, "seconds": 180.0},
	{"width": 480, "seconds": 180.0},
	{"width": 360, "seconds": 0.0},
]
const LATER_BIOMES := ["portals", "ocean", "sky"]  # the biomes dealt in after the others are shuffled, in the order they were added (see biome_of)
const CASTLE_SHARE := 0.6  # the share of a stage's width that a castle world takes
const HEIGHT := 380  # every world is this deep, in tiles
const WARNING := 18.0 # seconds of shaking and a warning before a world collapses

static var hurry := _hurry_asked()  # a test shortens the time in a world by this much (a program of its own, like a dedicated server, is told so by WIZARD_HURRY)


static func _hurry_asked() -> float:
	var named := OS.get_environment("WIZARD_HURRY")
	return named.to_float() if named.is_valid_float() and named.to_float() > 0.0 else 1.0

static var stage := 0
static var seed_base := 0
static var forced_biome := ""  # the F1 panel's choice of biome for the world being built, whatever the seed would deal (empty: the seed's own)
static var pending := false  # the next world to load carries a match on, rather than starting one
static var ledgers: Array[Ledger] = []  # the pages each wizard holds, the player's first
static var vitals: Array[Dictionary] = []  # each wizard's, in the same order: {"alive", "max", "stamina"}


## Starts a match whose first world is built from this seed.
static func begin(seed_value: int) -> void:
	stage = 0
	seed_base = seed_value
	pending = false
	forced_biome = ""
	ledgers = []
	vitals = []


## What the world being built is like: its size and time from STAGES, its biome, and whether it has halls ("caves").
static func plan() -> Dictionary:
	return plan_of(stage)


## The same for any stage of this match.
static func plan_of(at: int) -> Dictionary:
	var biome := forced_biome if forced_biome != "" and at == stage else biome_of(at)
	var halls := SurfaceGen.has_halls(biome) and at < STAGES.size() - 1  # the last world is all open sky
	var plan: Dictionary = STAGES[at].merged({"biome": biome, "caves": halls})
	if biome == "castle":
		plan["width"] = roundi(plan["width"] * CASTLE_SHARE)  # a castle world is built tall, and takes less width than the rest
	return plan


## The biome of a stage of this match: the biomes shuffled by the match's seed, so every machine in a match gets the same order and no
## biome comes up twice. The last world is all open sky, so it is one of the biomes that have sky and that the match has not been in.
static func biome_of(at: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base
	var rest := SurfaceGen.BIOMES.duplicate()
	for later: String in LATER_BIOMES:
		rest.erase(later)
	var order := _shuffled(rest, rng)
	order.insert(rng.randi_range(0, order.size()), "portals")  # dealt in at any place, after the rest are shuffled, so the seeds that were already in use keep most of their worlds
	var late := RandomNumberGenerator.new()  # and the ocean and the sky the same way, from a rng of their own, so the draws above (and the last world's below) are the ones they always were
	late.seed = seed_base + 6007
	for later: String in LATER_BIOMES.slice(1):
		order.insert(late.randi_range(1, order.size()), later)  # never first: a match always begins in a world that was always there, and the seeds in use keep their first world
	if at < STAGES.size() - 1:
		return order[at]
	for biome: String in _shuffled(SurfaceGen.OPEN_BIOMES, rng):
		if not order.slice(0, at).has(biome):
			return biome
	return SurfaceGen.OPEN_BIOMES[0]


static func _shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var out := list.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: String = out[i]
		out[i] = out[j]
		out[j] = held
	return out


## How many pages each world of this match lays, in order: from its biome and width, as the world would be dealt them by the seed.
static func page_counts() -> Array[int]:
	var out: Array[int] = []
	for at in STAGES.size():
		var biome := biome_of(at)
		var width: int = STAGES[at]["width"]
		out.append(Pages.count_for(biome, roundi(width * CASTLE_SHARE) if biome == "castle" else width))
	return out


## The pages of each world of this match, and the spare ones, settled by its seed: see Pages.allotment.
static func page_allotment(wizards: int) -> Dictionary:
	return Pages.allotment(seed_base, wizards, page_counts())


## True when the world being built is the last of the match.
static func is_last() -> bool:
	return stage == STAGES.size() - 1


## The seed of a stage's world: the same for the same match, and not the first world's own.
static func seed_for(at: int, count: int) -> int:
	return (seed_base * 7919 + at * 104729 + 13) % count


## The collapse: the next world is the one after this, with these ledgers and vitals, built from a seed of its own. Returns that seed.
static func advance(held: Array[Ledger], state: Array[Dictionary], count: int) -> int:
	stage += 1
	forced_biome = ""
	pending = true
	ledgers = held
	vitals = state
	return seed_for(stage, count)
