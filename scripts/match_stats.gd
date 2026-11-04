class_name MatchStats
extends RefCounted

## What the person at this machine did in the match so far, kept to be shown when they fall: damage dealt and taken, kills, the spells learned, cast and
## missed, each sampled every few seconds so that it can be drawn as a line over time. It lives for the whole match (every world of it) and is begun
## afresh with the first world.
##
## Damage is credited to whoever struck: a spell or a skeleton says who it belongs to just before it hurts (see `strike`), and the body that takes the
## blow reports how much it really took (see `hit`). Damage from the ground itself (lava, rocks, bites) belongs to no one.

const SAMPLE_EVERY := 2.0  # seconds between two points of a chart

static var me: Wizard                 # the person at this machine
static var seconds := 0.0             # how long they have been in the match
static var dealt := 0.0
static var taken := 0.0
static var kills := 0
static var casts := 0
static var misses := 0                # strokes that matched nothing, and spells that were too costly to cast
static var biggest_hit := 0.0
static var cast_by_spell := {}        # spell name -> times cast
static var damage_by_school := {}     # school -> damage dealt
static var accuracy_total := 0.0      # the sum of how well each spell was drawn, for its average
static var killed: Dictionary = {}    # ids of the bodies already counted as a kill
static var series: Array[Dictionary] = []  # {"t", "dealt", "taken", "known", "casts", "misses", "kills"}
static var _clock := 0.0
static var _by: Wizard                # who is striking, for the blow that is about to land


## A new match: everything is forgotten.
static func begin(person: Wizard) -> void:
	me = person
	seconds = 0.0
	dealt = 0.0
	taken = 0.0
	kills = 0
	casts = 0
	misses = 0
	biggest_hit = 0.0
	cast_by_spell = {}
	damage_by_school = {}
	accuracy_total = 0.0
	killed = {}
	series = []
	_clock = 0.0
	_by = null
	_sample()


## The next world of the same match: the person's new body takes the place of the old, and the counts go on.
static func carry_on(person: Wizard) -> void:
	me = person


## Counts the time, and adds a point to every chart now and then.
static func tick(delta: float) -> void:
	if me == null or not is_instance_valid(me) or me.dead:
		return
	seconds += delta
	_clock += delta
	if _clock >= SAMPLE_EVERY:
		_clock = 0.0
		_sample()


static func _sample() -> void:
	series.append({"t": seconds, "dealt": dealt, "taken": taken, "known": spells_known(), "casts": casts, "misses": misses, "kills": kills})


## A last point at this very moment, so that a chart runs right up to the end.
static func close() -> void:
	_sample()


## How many spells (not chants) the person's book holds.
static func spells_known() -> int:
	if me == null or not is_instance_valid(me):
		return 0
	var count := 0
	for page: String in me.ledger.pages:
		if SpellData.SPELLS.has(page):
			count += 1
	return count


## The wizard a thing belongs to: a wizard, or whoever cast a spell or raised a skeleton. Null for a thing that belongs to no one.
static func owner_of(thing: Node) -> Wizard:
	if thing == null or not is_instance_valid(thing):
		return null
	if thing is Wizard:
		return thing
	if thing is Mob:
		return owner_of((thing as Mob).master)
	var caster = thing.get("caster")
	if caster != null and caster is Node:
		return owner_of(caster)
	if thing.has_meta("caster"):
		return owner_of(thing.get_meta("caster"))
	return null


## The next blow that lands is struck by whoever this thing belongs to.
static func strike(by: Node) -> void:
	_by = owner_of(by)


## A body has taken a blow of this much. Credited to whoever struck it (if anyone), and counted against the person if it was them.
static func hit(victim: Node, amount: float, school := "", fatal := false) -> void:
	var striker := _by
	_by = null
	if me == null or amount <= 0.0:
		return
	if victim == me:
		taken += amount
	if striker != null and striker == me and victim != me:
		dealt += amount
		biggest_hit = maxf(biggest_hit, amount)
		if school != "":
			damage_by_school[school] = float(damage_by_school.get(school, 0.0)) + amount
		var gone: bool = fatal or victim.dead if victim is Wizard else (victim is Mob and (victim as Mob).is_dead())
		if gone and not killed.has(victim.get_instance_id()) and not (victim is Mob and (victim as Mob).is_training_dummy()):
			killed[victim.get_instance_id()] = true
			kills += 1


## The person cast a spell.
static func cast(spell: String, accuracy: float) -> void:
	casts += 1
	cast_by_spell[spell] = int(cast_by_spell.get(spell, 0)) + 1
	accuracy_total += clampf(accuracy, 0.0, 1.0)


## A stroke matched nothing, or a spell could not be paid for.
static func miss() -> void:
	misses += 1


## The share of all the spells in the game that the person's book holds, from 0 to 1.
static func learned_share() -> float:
	return float(spells_known()) / float(maxi(SpellData.SPELLS.size(), 1))


## The share of tries that went off, from 0 to 1 (1 when nothing was tried).
static func cast_share() -> float:
	var tries := casts + misses
	return 1.0 if tries == 0 else float(casts) / float(tries)


## How well the spells that went off were drawn, on average, from 0 to 1.
static func average_accuracy() -> float:
	return accuracy_total / float(casts) if casts > 0 else 0.0
