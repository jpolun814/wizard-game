class_name PortalField
extends Node2D

## The portal world's portals. Every INTERVAL seconds a handful open on the ground (the ring opens), stay open for LIFETIME, and close (the ring shuts). Anyone who steps
## into one comes out of another that is open. Which open, where and how many all come from the world's seed and age, so every
## machine of a match sees the same portals at the same moment. The first wave is never fewer than two; each later one brings none to eight, spread from one end of the world to the other.
## Some hang in the air, but the first of every wave stands on the ground and some of the rest can be jumped to, so there is always a way in.
## Each portal has a colour of its own: no two that are open at once share a hue.

const INTERVAL := 5.0
const LIFETIME := 15.0     # three intervals
const JUMPABLE := 90.0     # a portal hung no higher than this above the ground can be reached by jumping
const HIGHEST := 200.0     # and the highest one hangs this high
const FIRST_WAVE := 2
const MOST_NEW := 8
const COOLDOWN := 1.0      # seconds before whoever came out may go in again
const SHOT_REACH := Vector2(26.0, 34.0)  # how near the middle of a portal a shot has to be to go in
const SHOT_COOLDOWN := 0.4  # seconds before a shot that came out may go in again
const SPACING := 90.0      # the least distance between two open portals
const HUES := 24           # as many as can be open at once (three waves of eight)

signal carried(body: Node2D)  # someone has gone in at one and come out of another

var seed_value := 0
var seconds := 0.0         # the world's age: the world sets it each frame
var floors: PackedInt32Array
var tile := 32.0
var margin := 40           # columns at either end of the world where none open

var _open := {}            # portal id -> FieldPortal
var _recent := {}          # body -> seconds left before it may go in again
var _had_rivals := false   # more than one wizard has stood in this world
var stable := false        # the match is decided: the portals carry no one any more
var _since_count := 0.0


func _process(delta: float) -> void:
	_sync()
	_since_count += delta
	if _since_count >= 0.5 and not stable:
		_since_count = 0.0
		var standing := SpellTargets.wizards(get_tree()).size()
		if standing > 1:
			_had_rivals = true
		elif _had_rivals:
			stable = true  # someone has won
	for body in _recent.keys():
		_recent[body] -= delta
		if _recent[body] <= 0.0 or not is_instance_valid(body):
			_recent.erase(body)


## How many portals the wave that opens at this number brings.
func wave_size(wave: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + wave * 7919
	if wave == 0:
		return FIRST_WAVE + rng.randi_range(0, 1)
	return rng.randi_range(0, MOST_NEW)


## Every portal that is open at a time, as {"id", "wave", "x", "born"}, found from the seed alone.
func schedule(age: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var newest := floori(age / INTERVAL)
	var oldest := maxi(0, newest - int(LIFETIME / INTERVAL) + 1)
	for wave in range(oldest, newest + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 17 + wave * 104729
		var count := wave_size(wave)
		var strips: Array[int] = []  # every wave gets a stretch of the world to each portal, in an order the seed shuffles: they are spread from one end to the other
		for k in count:
			strips.append(k)
		for k in range(count - 1, 0, -1):
			var swap := rng.randi_range(0, k)
			var kept := strips[k]
			strips[k] = strips[swap]
			strips[swap] = kept
		for k in count:
			var first := margin
			var last := floors.size() - margin - 1
			var share := maxi((last - first + 1) / count, 1)
			var low := first + strips[k] * share
			var column := rng.randi_range(low, mini(low + share - 1, last))
			var chance := rng.randf()
			var lift := 0.0
			if k > 0 and chance > 0.5:  # the first of a wave stands on the ground; of the others, half hang in the air
				lift = rng.randf_range(40.0, JUMPABLE) if chance < 0.75 else rng.randf_range(JUMPABLE + 30.0, HIGHEST)
			out.append({"id": _id_of(wave, k), "wave": wave, "x": (column + 0.5) * tile, "born": wave * INTERVAL, "column": column, "lift": lift})
	return _spread(out)


## A portal that would open on top of an older one is dropped, so two are never too close to tell apart.
func _spread(list: Array[Dictionary]) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for portal in list:
		var crowded := false
		for other in kept:
			if portal["wave"] > 0 and absf(other["x"] - portal["x"]) < SPACING:
				crowded = true
		if not crowded:
			kept.append(portal)
	return kept


func _id_of(wave: int, k: int) -> int:
	return wave * 8 + k


## The colour of a portal: the hues are dealt round in turn, so the ones open together are all different.
static func tint_of(id: int) -> Color:
	var order := (id * 5) % HUES  # five is coprime to twelve: neighbours in time are far apart in hue
	return Color.from_hsv(float(order) / HUES, 0.9, 1.0)


func open_portals() -> Array[FieldPortal]:
	var out: Array[FieldPortal] = []
	for id in _open:
		out.append(_open[id])
	return out


func _sync() -> void:
	var want := {}
	for entry in schedule(seconds):
		want[entry["id"]] = entry
	for id in _open.keys():
		if not want.has(id):
			_open[id].queue_free()
			_open.erase(id)
	for id in want:
		if _open.has(id):
			_open[id].age = seconds - want[id]["born"]
			continue
		var entry: Dictionary = want[id]
		var portal := FieldPortal.new()
		portal.tint = tint_of(id)
		portal.lifetime = LIFETIME
		portal.age = seconds - entry["born"]
		portal.lift = entry["lift"]
		portal.position = Vector2(entry["x"], floors[entry["column"]] * tile - Portal.RY - 4.0 - entry["lift"])
		portal.entered.connect(_on_entered)
		add_child(portal)
		portal.open()
		_open[id] = portal


## A shot that flies into a portal comes out of another one, flying the way it was going. (A shot is not a body, so the portal itself does not notice it.)
func _physics_process(_delta: float) -> void:
	var portals := open_portals()
	if portals.size() < 2 or stable:
		return
	for shot in get_tree().get_nodes_in_group("shots"):
		if not shot is Node2D or _recent.has(shot) or not shot.has_method("heading"):
			continue
		for portal in portals:
			var offset: Vector2 = shot.global_position - portal.global_position
			if portal.is_closing() or absf(offset.x) > SHOT_REACH.x or absf(offset.y) > SHOT_REACH.y:
				continue
			var others := portals.filter(func(p: FieldPortal) -> bool: return p != portal and not p.is_closing())
			if others.is_empty():
				break
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value + int(seconds * 10.0) + portal.get_instance_id()
			var exit: FieldPortal = others[rng.randi_range(0, others.size() - 1)]
			_recent[shot] = SHOT_COOLDOWN
			shot.global_position = exit.global_position + shot.heading() * 36.0
			if shot.has_method("reset_physics_interpolation"):
				shot.reset_physics_interpolation()
			break


## Someone stepped into a portal: they come out of another that is open, if there is one.
func _on_entered(portal: FieldPortal, body: Node2D) -> void:
	if _recent.has(body) or stable:
		return
	if body is Wizard and body.is_likeness():
		return  # another machine drives that wizard, and moves it through on its own copy of the portal
	var others := open_portals().filter(func(p: FieldPortal) -> bool: return p != portal and not p.is_closing())
	if others.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + int(seconds * 10.0) + portal.get_instance_id()
	var exit: FieldPortal = others[rng.randi_range(0, others.size() - 1)]
	_recent[body] = COOLDOWN
	carried.emit(body)
	body.global_position = exit.global_position + Vector2(0.0, Portal.RY)
	if body.has_method("reset_physics_interpolation"):
		body.reset_physics_interpolation()
	if body.get("velocity") != null:
		body.velocity = Vector2.ZERO
