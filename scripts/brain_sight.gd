class_name BrainSight
extends RefCounted

## What an AI wizard knows of the others from what its eyes have shown it: where each was last seen, the shadow it takes for a rival, and the shots it sees
## coming. A person looks at one thing at a time and takes in the rest a moment late, and so does this.

const REMEMBER := 8.0         # seconds a rival gone out of sight is still thought to be where it was last seen
const ATTENTION_CONE := 0.8  # radians either side of the way to its rival that it watches closely
const ATTENTION_LAG := 0.25  # seconds before it takes in a shot from elsewhere (on top of the time it takes to answer it)

var first_seen := {}             # shot instance id -> the time on clock it first came on its screen (see noticed)
var seen_shots := {}
var lure: Decoy                 # a shadow it takes for a rival, and deals with as if it were them (see notice_decoys)
var shadows := {}                # decoy instance id -> true when it knows it for a shadow, false when it is fooled
var known := {}                  # rival instance id -> {"wizard", "at" (feet when last seen), "age" (seconds since)} (see look_about)

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## What it knows of the others, as a person knows it: where each was when it last saw them. A rival on its screen and in plain sight is seen
## where they are; one that goes out of sight is thought to be where it was last seen, and is forgotten after a while. A brain.scent (Hunter's Mark) shows
## them wherever they are, as it would show a person. The Chant of the Scrying Eye does not: a person's window shows someone, but not where they are.
func look_about(delta: float) -> void:
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other == wizard:
			continue
		var id := other.get_instance_id()
		if (brain.eyes_see(other) or brain.scent > 0.0) and not (lure != null and lure.caster == other):
			known[id] = {"wizard": other, "at": other.global_position, "age": 0.0}
		elif known.has(id):
			known[id]["age"] += delta
	for id in known.keys():
		var entry: Dictionary = known[id]
		if entry["age"] > REMEMBER or not is_instance_valid(entry["wizard"]) or entry["wizard"].dead:
			known.erase(id)


## Where it thinks its rival stands: where they are when it sees them, where it last saw them, or where the shadow it takes for them stands.
func foe_feet() -> Vector2:
	if not is_instance_valid(brain.foe()):
		return wizard.global_position
	return seen_feet(brain.foe())


## Where a rival looks to be standing, to it (see foe_feet).
func seen_feet(other: Wizard) -> Vector2:
	if not is_instance_valid(other):
		return wizard.global_position
	if other == brain.foe() and is_instance_valid(lure) and not lure.is_dead():
		return lure.global_position
	var entry: Dictionary = known.get(other.get_instance_id(), {})
	return entry["at"] if entry.get("age", 0.0) > 0.0 else other.global_position


## The middle of a rival's body, where it thinks they stand.
func seen_center(other: Wizard) -> Vector2:
	return seen_feet(other) + other.center_offset()


## A Decoy looks like any wizard to everyone but its caster. It takes one for its caster unless it saw it come out of nothing, or it is its own;
## the nearest figure it sees, real or shadow, is the one it deals with. A shadow that wears through is known for what it was.
func notice_decoys() -> void:
	if lure != null and (not is_instance_valid(lure) or lure.is_dead()):
		lure = null
	var nearest_gap := INF
	for id in known:
		if known[id]["age"] <= 0.0:
			nearest_gap = minf(nearest_gap, wizard.global_position.distance_to(known[id]["at"]))
	var best: Decoy = null
	for node in wizard.get_tree().get_nodes_in_group("decoys"):
		var decoy := node as Decoy
		if decoy.is_dead() or not is_instance_valid(decoy.caster) or decoy.caster == wizard:
			continue
		var id := decoy.get_instance_id()
		var seen := wizard.eyes.sees_point(decoy.center())
		if seen and not shadows.has(id):
			shadows[id] = decoy.age() < 0.4  # it watched it come: it knows it for a shadow
		if not seen or shadows.get(id, true):
			continue
		var gap := wizard.global_position.distance_to(decoy.global_position)
		if gap < nearest_gap:
			nearest_gap = gap
			best = decoy
	lure = best
	if lure != null:
		known[lure.caster.get_instance_id()] = {"wizard": lure.caster, "at": lure.global_position, "age": 0.0}
	if shadows.size() > 64:
		shadows.clear()


## The nearest of the other wizards it knows of (sees, or saw a little while ago), or null when it knows of none.
func nearest_foe() -> Wizard:
	var best: Wizard = null
	var best_gap := INF
	for id in known:
		var entry: Dictionary = known[id]
		var gap: float = wizard.global_position.distance_to(entry["at"])
		if gap < best_gap:
			best = entry["wizard"]
			best_gap = gap
	return best


## The nearest of your shots that will hit it soon: {"eta": seconds, "dir": its direction}, or nothing.
func incoming_shot() -> Dictionary:
	var best := {}
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster == wizard or not wizard.eyes.sees_node(node):
			continue  # (a shot off its screen, or in smoke or the dark, is not seen coming)
		if not noticed(node):
			continue
		var velocity: Vector2 = node.velocity()
		var rel: Vector2 = wizard.center() - node.global_position
		var closing := rel.dot(velocity.normalized())
		if closing <= 0.0:
			continue
		var eta := closing / velocity.length()
		var miss := (rel - velocity.normalized() * closing).length()
		if eta < 0.9 and miss < 28.0 and (best.is_empty() or eta < best["eta"]):
			best = {"eta": eta, "dir": velocity.normalized()}
	return best


## Attention: a person watches the rival they are fighting, and takes in what comes from elsewhere a moment late. A shot from the side of its rival is
## seen at once; one from anywhere else only after it has been on the screen a little while.
func noticed(node: Node2D) -> bool:
	var id := node.get_instance_id()
	if not first_seen.has(id):
		first_seen[id] = brain.clock
		if first_seen.size() > 64:
			first_seen.clear()
			first_seen[id] = brain.clock
	if not is_instance_valid(brain.foe()):
		return true  # nothing holds its eye: it sees what comes
	var to_foe := seen_center(brain.foe()) - wizard.center()
	var to_shot := node.global_position - wizard.center()
	if to_foe.length() < 1.0 or absf(to_foe.angle_to(to_shot)) < ATTENTION_CONE:
		return true
	return brain.clock - float(first_seen[id]) >= ATTENTION_LAG


## Counts how many shots you have thrown lately, so it knows when to put up walls.
func track_shots() -> void:
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster != wizard and not seen_shots.has(node.get_instance_id()) and wizard.eyes.sees_node(node):
			seen_shots[node.get_instance_id()] = true
			brain.pressure += 1.0
	if seen_shots.size() > 64:
		seen_shots.clear()
