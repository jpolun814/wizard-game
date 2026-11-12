class_name HandAgent
extends TacticsAgent

## The link between a wizard played through a person's controls (HandBrain) and the trainer (training/train_duel.py, Godot RL Agents). It senses what
## HandBrain.observe gives (the screen, and the mask of what its hand can do now) and chooses what HandBrain.HEADS lists: keys, a spell, where.
## The reward is TacticsAgent's in a duel: the strength it takes from the other against what it loses, and the bout won or lost. Nothing says how.

var hand: HandBrain


## Each point of strength taken or lost is worth five times the tactics learner's: a Fireball that lands (12) is worth about a bout won. At 0.02 a hit
## was worth 0.24 against swings of 1 for a bout, and four in a hundred shots hit: the lesson of aiming was too faint to learn (2026-11-11).
const HAND_HARM := 0.1


## A shot of its own that passes near the other wizard earns a little, more the nearer it came: a miss by an inch and a miss by a mile are not the same,
## and with only the hits to learn from (four in a hundred at first) aiming was learned too slowly (2026-11-11). It is kept small (a very near
## miss earns NEAR_MOST, under a third of a Fireball's hit) so that hitting always pays clearly more, and it fades as aiming is learned: the trainer
## passes --near=F (1 at first, 0 once a quarter of its shots hit the dummy), so the network that comes out has learned from real outcomes alone.
const NEAR_MOST := 0.36
const NEAR_REACH := 160.0  # px from the middle of the other wizard: a shot that comes no nearer earns nothing

## A stroke drawn while too tired to pay for it costs the learner a little (the game charges nothing: the owner keeps it free, 2026-11-11). It drew
## them anyway, aimed anywhere (at a wall, while backing away), because nothing said not to; a person would not. Ten of them cost about one hit.
const TIRED_COST := 0.1

var near_scale := 0.0
var _tired_seen := -100.0  # when the last "Too tired" this body was told of was counted
var spells_cast := {}  # spell -> times the learner cast it, over every body it has had (a measure says which spells it uses)
var _flying := {}  # instance id of a shot of its own -> the nearest it has come to the other wizard


func init_for(body: Wizard) -> void:
	super.init_for(body)
	hand = body.brain as HandBrain
	duel_harm = HAND_HARM
	cause["near"] = 0.0
	cause["tired"] = 0.0
	_tired_seen = float(body.told.get("too_tired", -100.0))
	if body.caster != null and not body.caster.cast_resolved.is_connected(_count_cast):
		body.caster.cast_resolved.connect(_count_cast)
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--near="):
			near_scale = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_watch_shots()
	_watch_tired()


## A "Too tired" since the last look costs TIRED_COST.
func _watch_tired() -> void:
	if wizard == null or not is_instance_valid(wizard):
		return
	var at := float(wizard.told.get("too_tired", -100.0))
	if at > _tired_seen:
		_tired_seen = at
		_add("tired", -TIRED_COST)


## Follows its own shots in flight, and when one is gone, pays for how near it came.
func _watch_shots() -> void:
	if near_scale <= 0.0 or wizard == null or not is_instance_valid(wizard):
		return
	if opponent != null and is_instance_valid(opponent) and not opponent.dead:
		for shot in wizard.get_tree().get_nodes_in_group("shots"):
			if shot is SpellEffect and shot.caster == wizard:
				var id: int = shot.get_instance_id()
				var gap: float = (shot as Node2D).global_position.distance_to(opponent.center())
				_flying[id] = minf(float(_flying.get(id, INF)), gap)
	for id: int in _flying.keys():
		if not is_instance_valid(instance_from_id(id)):
			var nearest: float = _flying[id]
			_flying.erase(id)
			if nearest < NEAR_REACH:
				_add("near", NEAR_MOST * near_scale * (1.0 - nearest / NEAR_REACH))


func get_obs_space() -> Dictionary:
	return {"obs": {"size": [HandBrain.SIZE], "space": "box"}}


## What it senses, packed as TacticsAgent packs it (only what is not zero; training/gd_launch.py unpacks it).
func get_obs() -> Dictionary:
	var seen := PackedFloat32Array()
	if hand != null and wizard != null and is_instance_valid(wizard) and wizard.is_inside_tree():
		seen = hand.observe()
	if seen.size() != HandBrain.SIZE:
		seen.resize(HandBrain.SIZE)
	var places := PackedInt32Array()
	var values := PackedFloat32Array()
	for i in seen.size():
		var value := seen[i]
		if value != 0.0 and not is_nan(value) and not is_inf(value):
			places.append(i)
			values.append(value)
	return {"obs": {"n": seen.size(), "i": places, "v": values}}


func get_action_space() -> Dictionary:
	var out := {}
	for head: String in HandBrain.HEADS:
		out[head] = {"size": HandBrain.HEADS[head], "action_type": "discrete"}
	return out


func set_action(action) -> void:
	if hand == null:
		return
	hand.move = int(action["move"])
	hand.jump = int(action["jump"])
	hand.cast = int(action["cast"])
	hand.aim = Vector2i(int(action["aim_x"]), int(action["aim_y"]))
	hand.fresh = true


## A stroke read as a spell not in the book comes to nothing (Arena.cast_by): it is counted as a misread, not as that spell.
func _count_cast(spell: String, _targeting: String, _origin: Vector2, _aim: float, _info: Dictionary) -> void:
	var key := spell if wizard != null and is_instance_valid(wizard) and wizard.ledger.knows_spell(spell) else "misread"
	spells_cast[key] = int(spells_cast.get(key, 0)) + 1


## TacticsAgent's counts, and how often each spell was cast ("cast Frostbolt": 12).
func get_info() -> Dictionary:
	var out := super.get_info()
	for spell: String in spells_cast:
		out["cast " + spell] = spells_cast[spell]
	return out
