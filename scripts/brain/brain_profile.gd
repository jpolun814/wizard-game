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
	return OS.get_environment("AI_OFF").contains(change) or seat_off.contains(change)


## The same, for one wizard only (the measuring arena sets `WizardBrain.off_here`, and each wizard's turn to think puts it here): two brains that differ by one change play each other.
static var seat_off := ""

## A number of the brain that a measurement may change for one seat alone: `kn_NAME=VALUE` among the seat's switches (`off0=kn_thrift=3.0,kn_gap_q=0.5`), else the figure stored in
## data/ai/knobs.json, else the one given. (tools/ai_tune.py moves them one at a time and keeps what wins.) The brain's own constants stay the figures it plays with.
const KNOB_FILE := "res://data/ai/knobs.json"
static var _stored := {}
static var _stored_read := false
static var _knob_source := "<unset>"
static var _knobs := {}


static func knob(name: String, base: float) -> float:
	if not _stored_read:
		_stored_read = true
		var file := FileAccess.open(KNOB_FILE, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_stored = parsed if parsed is Dictionary else {}
	if seat_off != _knob_source:
		_knob_source = seat_off
		_knobs = {}
		for token in seat_off.split(","):
			if token.begins_with("kn_") and token.contains("=") and token.get_slice("=", 1).is_valid_float():
				_knobs[token.get_slice("=", 0).substr(3)] = token.get_slice("=", 1).to_float()
	return float(_knobs.get(name, _stored.get(name, base)))


var seen := {}     # rival instance id -> {spell name -> {"n": times, "at": time last seen}}
var aimed := {}    # rival instance id -> time on the brain's clock it last cast toward it
var spent := {}    # rival instance id -> a guess at the strength it has used up lately (what its casts cost, less what it has got back)
var wounds := {}   # rival instance id -> damage seen to land on it lately
var dodge := {}    # rival instance id -> which way it tends to step when a shot of its own comes at it, from -1 (left) to 1 (right), as a running average
var worked := {}   # the spell of its own -> times a rival was hurt soon after it was cast
var tried := {}    # the spell of its own -> times it was cast at a rival
var tried_at := {}   # "spell|range band" -> times it was cast at a rival that far off
var worked_at := {}  # the same, times a rival was hurt soon after
var dear_at := {}    # rival instance id -> time on the clock of the brain that it was seen to cast a dear spell
var _last_try := ["", -99.0, 0]
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
	_watch_dodging()
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other != wizard and not _hearing.has(other.get_instance_id()):
			_hearing[other.get_instance_id()] = true
			other.damaged.connect(_hurt_seen.bind(other))


## What a person who has thrown a few shots at someone sees: which way they step as it comes. A rival it can see, with a shot of its own coming at them, is
## noted a stride at a time, and the habit is kept as a running average.
func _watch_dodging() -> void:
	var foe := brain.foe()
	if not is_instance_valid(foe) or not wizard.eyes.sees_wizard(foe) or absf(foe.velocity.x) < 80.0:
		return
	for shot in wizard.get_tree().get_nodes_in_group("projectiles"):
		if shot.caster == wizard and shot.global_position.distance_to(foe.center()) < 240.0 and absf(shot.velocity().y) < absf(shot.velocity().x):
			var id := foe.get_instance_id()
			dodge[id] = lerpf(dodge.get(id, 0.0), signf(foe.velocity.x), 0.08)
			return


## How far, from -1 to 1, a rival has been seen to step to one side as shots come at it.
func dodge_lean(other: Wizard) -> float:
	return dodge.get(other.get_instance_id(), 0.0) if is_instance_valid(other) else 0.0


## It has thrown its own attack: noted, to see whether it lands.
func note_try(spell_name: String, gap := 0.0) -> void:
	tried[spell_name] = tried.get(spell_name, 0) + 1
	var key := _band(spell_name, gap)
	tried_at[key] = tried_at.get(key, 0) + 1
	_last_try = [spell_name, brain.clock, gap]


func _band(spell_name: String, gap: float) -> String:
	return "%s|%d" % [spell_name, int(gap / 180.0)]


func _hurt_seen(amount: int, other: Wizard) -> void:
	if not is_instance_valid(wizard) or not wizard.eyes.sees_wizard(other):
		return
	var id := other.get_instance_id()
	wounds[id] = wounds.get(id, 0.0) + amount
	if brain.clock - float(_last_try[1]) < 1.5 and _last_try[0] != "":
		worked[_last_try[0]] = worked.get(_last_try[0], 0) + 1
		var key := _band(_last_try[0], float(_last_try[2]))
		worked_at[key] = worked_at.get(key, 0) + 1
		_last_try[1] = -99.0


## How well one of its attacks has gone this match, as a weight: a spell that keeps landing is cast more, one that keeps missing less. (1 until it has tried it a few times.)
func form(spell_name: String, gap := -1.0) -> float:
	var n: int = tried.get(spell_name, 0)
	var weight := 1.0
	if n >= 3:
		var rate := (float(worked.get(spell_name, 0)) + 1.0) / (float(n) + 2.5)
		weight = clampf(rate / 0.4, 0.5, 1.8)
	if gap >= 0.0 and not BrainProfile.off("range_memory"):  # a spell that missed twice from about this far off is not tried again from there: it has been seen not to work at that range
		var key := _band(spell_name, gap)
		var m: int = tried_at.get(key, 0)
		if m >= 2:
			weight *= clampf(((float(worked_at.get(key, 0)) + 1.0) / (float(m) + 2.5)) / 0.4, 0.4, 1.4)
	return weight


## The rival has just been seen to cast a dear spell: it is busy getting its breath back, and a quick shot is not answered.
func recovering(other: Wizard) -> bool:
	return is_instance_valid(other) and brain.clock - float(dear_at.get(other.get_instance_id(), -99.0)) < 3.0


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


## How dangerous it takes a rival to be, 0 to 1, from what it has seen of them and nothing else: the spells it has watched them cast (and how hard those hit), whether they
## have been casting at it, and whether they look worn down. A rival it has seen nothing of is middling (0.5). Its caution and how much stamina it keeps in hand follow this.
func threat(other: Wizard) -> float:
	if not is_instance_valid(other):
		return 0.5
	var arms := 0.0
	for spell_name: String in seen.get(other.get_instance_id(), {}):
		if _fresh(other, spell_name) and SpellData.SPELLS.has(spell_name):
			var spell: Spell = SpellData.SPELLS[spell_name]
			arms += clampf(spell.damage.get_slice(" ", 0).to_float(), 4.0, 40.0) / 40.0
	var t := 0.5 + (clampf(arms / 2.5, 0.0, 1.0) - 0.4) * 0.5 if arms > 0.0 else 0.5
	if after_me(other):
		t += 0.1
	if hurt(other):
		t -= 0.2
	if winded(other) or recovering(other):
		t -= 0.1
	return clampf(t, 0.0, 1.0)


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
		if spell.cost >= 50.0:
			dear_at[id] = brain.clock
	var to_me := wizard.center() - origin
	if absf(angle_difference(aim, to_me.angle())) < 0.7 and to_me.length() < 700.0:
		aimed[id] = brain.clock


func _fresh(other: Wizard, spell_name: String) -> bool:
	var entry: Dictionary = seen.get(other.get_instance_id(), {}).get(spell_name, {})
	return not entry.is_empty() and brain.clock - float(entry["at"]) < FORGET * brain.memory


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
