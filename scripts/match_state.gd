class_name MatchState
extends RefCounted

## What carries from one world of a match to the next. The portal is growing unstable: after a few minutes it collapses, and the wizards
## who are left are thrown into a new world, smaller than the last; the last is a small open one with nowhere to hide. The pages no one
## has found lie on in the new world; each wizard keeps their own pages and what is left of their stamina.

## Each world of a match: how wide it is in tiles, how long the wizards have in it before it collapses (0: it does not), and whether it has caves.
const STAGES := [
	{"width": 1200, "seconds": 180.0, "caves": true},
	{"width": 800, "seconds": 120.0, "caves": true},
	{"width": 560, "seconds": 60.0, "caves": true},
	{"width": 360, "seconds": 0.0, "caves": false},
]
const HEIGHT := 380  # every world is this deep, in tiles
const WARNING := 6.0  # seconds of shaking and a warning before a world collapses

static var hurry := 1.0  # a test shortens the time in a world by this much
static var stage := 0
static var seed_base := 0
static var pending := false  # the next world to load carries a match on, rather than starting one
static var ledgers: Array[Ledger] = []  # the pages each wizard holds, the player's first
static var vitals: Array[Dictionary] = []  # each wizard's, in the same order: {"alive", "max", "stamina"}


## Starts a match whose first world is built from this seed.
static func begin(seed_value: int) -> void:
	stage = 0
	seed_base = seed_value
	pending = false
	ledgers = []
	vitals = []


## What the world being built is like.
static func plan() -> Dictionary:
	return STAGES[stage]


## True when the world being built is the last of the match.
static func is_last() -> bool:
	return stage == STAGES.size() - 1


## The seed of a stage's world: the same for the same match, and not the first world's own.
static func seed_for(at: int, count: int) -> int:
	return (seed_base * 7919 + at * 104729 + 13) % count


## The collapse: the next world is the one after this, with these ledgers and vitals, built from a seed of its own. Returns that seed.
static func advance(held: Array[Ledger], state: Array[Dictionary], count: int) -> int:
	stage += 1
	pending = true
	ledgers = held
	vitals = state
	return seed_for(stage, count)
