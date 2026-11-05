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
static var cast_by_spell := {}        # spell name -> times cast
static var damage_by_school := {}     # school -> damage dealt
static var accuracy_total := 0.0      # the sum of how well each spell was drawn, for its average
static var killed: Dictionary = {}    # ids of the bodies already counted as a kill
static var series: Array[Dictionary] = []  # {"t", "dealt", "taken", "known", "casts", "misses", "kills"}
static var finished := false          # the match is over, so the clock stops
static var world_starts: Array = []    # [biome, seconds into the match] for each world entered, for the Chronicle's graph
static var recorded := false          # the Chronicle already has this match
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
	cast_by_spell = {}
	damage_by_school = {}
	accuracy_total = 0.0
	killed = {}
	series = []
	finished = false
	recorded = false
	world_starts = []
	_clock = 0.0
	_by = null
	_enter_world()
	_sample()


## The next world of the same match: the person's new body takes the place of the old, and the counts go on.
static func carry_on(person: Wizard) -> void:
	me = person
	_enter_world()


## Notes that the person has come into a new world, and when.
static func _enter_world() -> void:
	world_starts.append([MatchState.biome_of(MatchState.stage), int(seconds)])


## Counts the time, and adds a point to every chart now and then.
static func tick(delta: float) -> void:
	if me == null or not is_instance_valid(me) or me.dead or finished:
		return
	seconds += delta
	_clock += delta
	if _clock >= SAMPLE_EVERY:
		_clock = 0.0
		_sample()


static func _sample() -> void:
	series.append({"t": seconds, "dealt": dealt, "taken": taken, "known": pages_known(), "casts": casts, "misses": misses, "kills": kills})


## A last point at this very moment, so that a chart runs right up to the end.
static func close() -> void:
	_sample()


## The match is won: the clock stops where it is, and the charts end there.
static func finish() -> void:
	if not finished:
		_sample()
		finished = true


## How many pages the person's book holds: spells and incantations both.
static func pages_known() -> int:
	if me == null or not is_instance_valid(me):
		return 0
	return me.ledger.count()


## The wizard a thing belongs to: a wizard, or whoever cast a spell or raised a skeleton. Null for a thing that belongs to no one.
static func owner_of(thing: Variant) -> Wizard:
	if thing == null or not is_instance_valid(thing):
		return null  # (it may be a node that has been freed since, so it is asked about before it is used)
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
		if school != "":
			damage_by_school[school] = float(damage_by_school.get(school, 0.0)) + amount
		# only a wizard felled is a kill: skeletons, whether the graveyard's or raised, are not counted
		var gone: bool = victim is Wizard and (fatal or victim.dead)
		if gone and not killed.has(victim.get_instance_id()):
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


## How well the spells that went off were drawn, on average, from 0 to 1.
static func average_accuracy() -> float:
	return accuracy_total / float(casts) if casts > 0 else 0.0


## The match as it will be kept in the Chronicle: small, plain numbers and names, so each match takes only a little room in the file.
## `place` is where the person came (1 won) among `of_total` wizards.
static func summary(place: int, of_total: int) -> Dictionary:
	close()
	var worlds: Array = []
	for at in range(MatchState.stage + 1):
		worlds.append(MatchState.biome_of(at))
	var spells: Array = []
	for spell: String in cast_by_spell:
		spells.append([spell, int(cast_by_spell[spell])])
	spells.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var strongest := ""
	var most := 0.0
	for school: String in damage_by_school:
		if float(damage_by_school[school]) > most:
			most = float(damage_by_school[school])
			strongest = school
	return {
		"when": int(Time.get_unix_time_from_system()), "place": place, "field": of_total,
		"seconds": int(seconds), "worlds": worlds, "seed": MatchState.seed_base,
		"kills": kills, "dealt": int(dealt), "taken": int(taken), "stages": world_starts.duplicate(), "casts": casts, "misses": misses, "accuracy": snappedf(average_accuracy(), 0.01), "pages": pages_known(),
		"favourites": spells.slice(0, 3), "school": strongest,
		"online": Net.online(),
		"dealt_line": _line("dealt"), "taken_line": _line("taken"),
	}


## A running total from the charts, thinned to 24 points whatever the length of the match.
static func _line(key: String) -> Array:
	var out: Array = []
	if series.is_empty():
		return out
	for k in 24:
		out.append(int(series[roundi(k * (series.size() - 1) / 23.0)][key]))
	return out
