class_name Dice
extends RefCounted

## Everything left to chance comes from the world's seed (the owner, 2026-11-25). Nothing in the game calls `randf()`, `randi()`, `pick_random()` or `shuffle()` of its own
## (tests/unit/dice_test.gd): it takes its dice from here.
##
##   Dice.of([who, what...])  dice of their own for one thing in the world (a creature, a volcano, a brain): the same seed and the same thing throw the same, whatever else has thrown
##   Dice.branch()            dice of their own for what a spell makes; they come from the cast (who cast it, and their how-manieth it is), so every machine of a match has the same
##   wizard.dice()            what befalls one wizard
##   Dice.looks               what is only seen or heard. How often these are thrown follows the frames, so nothing that touches the play may use them
##   Dice.fresh()             a new number that no seed decides: only to choose a seed, or for what a person asks to be picked for them
##
## The dice of one thing do not hang on another's, or a spark more on a slow machine would change who is hit.

static var seed_value := 0   # the seed of the world (or of the room) that is now
static var salt := OS.get_environment("WIZARD_SEED").to_int()  # 0 in a game; a test's runs are told apart by it (see SteadyRun)
static var begun := 0        # how many places have begun, so that what keeps dice knows when they are of a place that is gone
static var looks := _any()
static var _cast := _any()
static var _fresh := _any()


## A world, or a room, begins: from here on everything is thrown from its seed.
static func begin(world_seed: int) -> void:
	seed_value = world_seed
	begun += 1
	looks = of(["looks"])
	_cast = of(["cast"])
	seed(hash([salt, seed_value]))  # (the engine's own particles and sounds throw the global dice)


static func of(thing: Array) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([salt, seed_value, thing])
	return dice


## The luck of one cast of one wizard, which is sent to every machine with it.
static func luck_of(wizard_name: String, cast_number: int) -> int:
	return hash([salt, seed_value, "cast", wizard_name, cast_number])


## What is made from now on is made by a cast with this luck.
static func cast(luck: int) -> void:
	_cast.seed = luck


static func branch() -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = _cast.randi()
	return dice


static func fresh() -> int:
	return _fresh.randi()


## For a test: everything is thrown anew from this number (with the world's seed, when one begins).
static func reset(number: int) -> void:
	salt = number
	begin(seed_value)
	_fresh.seed = hash([salt, "fresh"])


static func _any() -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	if OS.get_environment("WIZARD_SEED") != "":  # a steady run comes out the same every time
		dice.seed = hash(OS.get_environment("WIZARD_SEED").to_int())
	else:
		dice.randomize()
	return dice
