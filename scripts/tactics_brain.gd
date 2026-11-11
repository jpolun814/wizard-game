class_name TacticsBrain
extends WizardBrain

## A wizard whose tactics are learned: which attack it makes and when, and whether it closes in on a rival, keeps away or stands its ground. Everything
## else is the scripted brain's: its route, its reflexes, its chants, and the strokes it draws (through the same body, screen and eyes as anyone's).
## The policy is asked a few times a second, by the trainer (training/tactics_agent.gd) while it learns, or in a match by a network run here
## (ai/tactics.json, written by training/export_policy.py).
##
## What it senses is what a person in its place could: Sensing (its screen), which of its attacks are ready, and the rival it knows of (where it was
## last seen, and how long ago).

## The attacks it can choose among, in a fixed order (the scripted brain's attack list). The policy's "cast" choice is 0 for the scripted brain's own
## pick, 1 to hold its fire, and 2 + an index into this list for that spell.
const ATTACKS := ["Ignite", "Frostbolt", "Spark", "Stonefall", "Icicles", "Spore Puff", "Stalagmite", "Bramble", "Flytrap", "Sinkhole", "Hex", "Vacuum",
	"Faint", "Fight or Flight", "Silence", "Tide Surf", "Thunderclap", "Tornado", "Ice Prison", "Mudslide", "Black Hole", "Firewall", "Blizzard",
	"Fire Breath", "Earthquake", "Barbs", "Pebble", "Hailstorm", "Thorn Whip", "Insect Plague", "Flaming Sphere", "Mirage", "Raise Dead", "Leech",
	"Eldritch Blast", "Hemorrhage", "Supernova", "Scythe"]
const ATTACK_COUNT := 38  # ATTACKS.size() (a constant must be written out; tests/limits_check.gd checks they agree)
const CASTS := ATTACK_COUNT + 2
const MODES := 4  # 0 the scripted footwork, 1 close in on the rival, 2 keep away from them, 3 stand still
const EXTRA := ATTACK_COUNT + 6
const SIZE := Sensing.SIZE + EXTRA
const DECISION_EVERY := 0.2  # seconds between choices: about the rate a person changes what they are doing

var cast_choice := 0
var mode := 0
var learned := false
var policy: PolicyNet
var _decide_in := 0.0
static var _shared: Dictionary = {}  # path -> PolicyNet


## A network that plays the tactics, loaded once for all who use it.
static func net(path := "res://ai/tactics.json") -> PolicyNet:
	if not _shared.has(path):
		_shared[path] = PolicyNet.load_file(path)
	return _shared[path]


## What it senses: its screen (Sensing), which attacks it is ready to cast, and what it knows of its rival.
func observe() -> PackedFloat32Array:
	var obs := Sensing.observe(wizard)
	for spell_name: String in ATTACKS:
		obs.append(1.0 if _ready_to_cast(spell_name) else 0.0)
	var known := _foe != null and is_instance_valid(_foe)
	obs.append(1.0 if known else 0.0)
	var entry: Dictionary = _known.get(_foe.get_instance_id(), {}) if known else {}
	obs.append(1.0 if known and entry.get("age", 1.0) <= 0.0 else 0.0)  # seen now
	var off := (_foe_feet() - wizard.global_position) if known else Vector2.ZERO
	obs.append(clampf(off.x / 900.0, -2.0, 2.0))
	obs.append(clampf(off.y / 600.0, -2.0, 2.0))
	obs.append(clampf(float(entry.get("age", REMEMBER)) / REMEMBER, 0.0, 1.0))
	obs.append(clampf(_cast_cooldown / 3.0, -1.0, 1.0))
	for i in obs.size():
		if is_nan(obs[i]) or is_inf(obs[i]):
			obs[i] = 0.0
	return obs


func think(delta: float) -> void:
	if policy != null:
		_decide(delta)
	super.think(delta)
	if not learned or mode == 0 or _foe == null or not is_instance_valid(_foe):
		return
	if is_typing() or wizard.is_drawing() or holds_still() or not _lift.is_empty() or not _leap.is_empty() or not _wade.is_empty() or wizard.wild:
		return  # what it is in the middle of comes first
	var off := _foe_feet().x - wizard.global_position.x
	match mode:
		1:
			wizard.walk(signf(off) * WALK_SPEED if absf(off) > 90.0 else 0.0)
		2:
			wizard.walk(-signf(off) * WALK_SPEED if absf(off) < Eyes.HALF.x * 1.4 else 0.0)
		3:
			wizard.walk(0.0)


func _choose_attack(scores: Dictionary) -> String:
	if not learned or cast_choice == 0:
		return super._choose_attack(scores)
	if cast_choice == 1:
		return ""  # it holds its fire
	var spell_name: String = ATTACKS[clampi(cast_choice - 2, 0, ATTACKS.size() - 1)]
	if scores.has(spell_name) and _ready_to_cast(spell_name):
		return spell_name  # its own choice, even where the scripted brain would not have thought of it
	return super._choose_attack(scores)


func _decide(delta: float) -> void:
	_decide_in -= delta
	if _decide_in > 0.0:
		return
	_decide_in = DECISION_EVERY
	var logits := policy.forward(observe())
	cast_choice = policy.choose(logits, "cast", true)
	mode = policy.choose(logits, "mode", true)
	learned = true
