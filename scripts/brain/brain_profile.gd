class_name BrainProfile
extends RefCounted

## What an AI wizard has learned of each rival by watching: the spells it was seen to cast and when, and whether it has lately cast at it. A person
## who sees a stroke drawn and its effect remembers it ("that one throws fire", "that one drops stones on you"), and picks their own spell and their
## own footing by it. Only what was on its screen when it happened is noted, and it is forgotten after a while: no one reads another's book.

const FORGET := 60.0          # seconds a spell seen is still held against a rival
const AT_ME := 6.0            # seconds a rival is thought to be after it, once it has cast toward it
const SHOOTERS := ["Ignite", "Frostbolt", "Barbs", "Eldritch Blast", "Pebble", "Thorn Whip", "Flaming Sphere"]  # what comes straight at you along a line
const FROM_ABOVE := ["Spark", "Stonefall", "Hailstorm", "Icicles", "Supernova", "Blizzard", "Thunderclap"]       # what comes down from over your head
const CLOSE := ["Scythe", "Fire Breath", "Spore Puff", "Thunderclap", "Insect Plague", "Flytrap"]               # what a rival casts when it is near

## For measuring one change at a time: AI_OFF=crowd,roof,... in the environment turns those changes off.
static func off(change: String) -> bool:
	return OS.get_environment("AI_OFF").contains(change)


var seen := {}     # rival instance id -> {spell name -> {"n": times, "at": time last seen}}
var aimed := {}    # rival instance id -> time on the brain's clock it last cast toward it
var spent := {}    # rival instance id -> a guess at the strength it has used up lately (what its casts cost, less what it has got back)
var wounds := {}   # rival instance id -> damage seen to land on it lately
var worked := {}   # the spell of its own -> times a rival was hurt soon after it was cast
var tried := {}    # the spell of its own -> times it was cast at a rival
var _last_try := ["", -99.0]
var _hearing := {}  # rival instance id -> true, once its blows are listened for
var _wired := {}   # rival instance id -> true, once its caster is listened to

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Starts listening to the casting of the match: it will note what it sees the others do.
func watch_all() -> void:
	if _wired.has(0):
		return
	var parent := wizard.get_parent()
	if parent == null or not ("casting" in parent) or parent.casting == null:
		return
	_wired[0] = true
	parent.casting.cast_made.connect(_cast_by)


## Called every moment: strength comes back to a rival who is not casting, and wounds are forgotten slowly.
func tick(delta: float) -> void:
	for id in spent.keys():
		spent[id] = maxf(spent[id] - 14.0 * delta, 0.0)
	for id in wounds.keys():
		wounds[id] = maxf(wounds[id] - 1.0 * delta, 0.0)
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other != wizard and not _hearing.has(other.get_instance_id()):
			_hearing[other.get_instance_id()] = true
			other.damaged.connect(_hurt_seen.bind(other))


## It has thrown its own attack: noted, to see whether it lands.
func note_try(spell_name: String) -> void:
	tried[spell_name] = tried.get(spell_name, 0) + 1
	_last_try = [spell_name, brain.clock]


func _hurt_seen(amount: int, other: Wizard) -> void:
	if not is_instance_valid(wizard) or not wizard.eyes.sees_wizard(other):
		return
	var id := other.get_instance_id()
	wounds[id] = wounds.get(id, 0.0) + amount
	if brain.clock - float(_last_try[1]) < 1.5 and _last_try[0] != "":
		worked[_last_try[0]] = worked.get(_last_try[0], 0) + 1
		_last_try[1] = -99.0


## How well one of its attacks has gone this match, as a weight: a spell that keeps landing is cast more, one that keeps missing less. (1 until it has tried it a few times.)
func form(spell_name: String) -> float:
	var n: int = tried.get(spell_name, 0)
	if n < 3:
		return 1.0
	var rate := (float(worked.get(spell_name, 0)) + 1.0) / (float(n) + 2.5)
	return clampf(rate / 0.4, 0.5, 1.8)


## The rival has used a good deal of its strength just now (a person sees it throw the dear spells one after another): it is the time to press it.
func winded(other: Wizard) -> bool:
	return is_instance_valid(other) and spent.get(other.get_instance_id(), 0.0) > 70.0


## A rival that has been hurt a good deal in front of it, and not yet mended.
func hurt(other: Wizard) -> bool:
	return is_instance_valid(other) and wounds.get(other.get_instance_id(), 0.0) > 45.0


## Seconds since it last saw this rival cast anything (a large number when it has not).
func cast_age(other: Wizard) -> float:
	var youngest := 999.0
	if is_instance_valid(other):
		for entry: Dictionary in seen.get(other.get_instance_id(), {}).values():
			youngest = minf(youngest, brain.clock - float(entry["at"]))
	return youngest


## How many different spells it has seen this rival cast lately.
func known_count(other: Wizard) -> int:
	var n := 0
	if is_instance_valid(other):
		for spell_name: String in seen.get(other.get_instance_id(), {}):
			if _fresh(other, spell_name):
				n += 1
	return n


## A rival typing a chant: it stands still with the words over its head, and cannot answer a blow.
func chanting(other: Wizard) -> bool:
	return is_instance_valid(other) and other.shown_words != ""


func _cast_by(spell_name: String, origin: Vector2, aim: float, other: Wizard) -> void:
	if other == wizard or not is_instance_valid(wizard) or not is_instance_valid(other) or not wizard.eyes.sees_wizard(other):
		return  # (what it did not see, it does not know)
	var id := other.get_instance_id()
	var row: Dictionary = seen.get_or_add(id, {})
	var entry: Dictionary = row.get_or_add(spell_name, {"n": 0, "at": 0.0})
	entry["n"] += 1
	entry["at"] = brain.clock
	if SpellData.SPELLS.has(spell_name):
		var spell: Spell = SpellData.SPELLS[spell_name]
		spent[id] = spent.get(id, 0.0) + (spell.cost * 0.5 if spell.pays_max() else spell.cost)
	var to_me := wizard.center() - origin
	if absf(angle_difference(aim, to_me.angle())) < 0.7 and to_me.length() < 700.0:
		aimed[id] = brain.clock


func _fresh(other: Wizard, spell_name: String) -> bool:
	var entry: Dictionary = seen.get(other.get_instance_id(), {}).get(spell_name, {})
	return not entry.is_empty() and brain.clock - float(entry["at"]) < FORGET


## Whether it has seen this rival cast this spell lately.
func shown(other: Wizard, spell_name: String) -> bool:
	return is_instance_valid(other) and _fresh(other, spell_name)


## Whether it has seen this rival cast any spell of a school ("Fire", "Water", ...) lately.
func shown_school(other: Wizard, school: String) -> bool:
	if not is_instance_valid(other):
		return false
	for spell_name: String in seen.get(other.get_instance_id(), {}):
		if _fresh(other, spell_name) and SpellData.SPELLS.has(spell_name) and SpellData.SPELLS[spell_name].school == school:
			return true
	return false


## Whether it has seen the rival cast any of the spells in a list lately.
func shown_any(other: Wizard, spell_names: Array) -> bool:
	for spell_name: String in spell_names:
		if shown(other, spell_name):
			return true
	return false


## Whether the rival has lately cast at it.
func after_me(other: Wizard) -> bool:
	return is_instance_valid(other) and brain.clock - float(aimed.get(other.get_instance_id(), -99.0)) < AT_ME


## How a rival is thought to fight: how much of what it was seen casting is a thing for close range, from -1 (all far) to 1 (all near), 0 when unknown.
func closeness(other: Wizard) -> float:
	var near := 0.0
	var far := 0.0
	for spell_name: String in seen.get(other.get_instance_id(), {}):
		if not _fresh(other, spell_name):
			continue
		if spell_name in CLOSE:
			near += 1.0
		elif spell_name in SHOOTERS or spell_name in FROM_ABOVE:
			far += 1.0
	return 0.0 if near + far == 0.0 else (near - far) / (near + far)
