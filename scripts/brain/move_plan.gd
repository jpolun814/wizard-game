class_name MovePlan
extends RefCounted

## The cheapest way from one place to another, by foot and by whatever the wizard's spells do to a body (docs/handoff/23_movement_planning.md, section 2C). One search, over places to
## stand and places it would hang in the air for a moment. The price of everything is seconds: the going, the drawing of a stroke, the stamina (the seconds it takes to come back).
## It reads what a spell does from the spell's own data (`Spell.effect_of`) and knows none by name; what it cannot use is not offered. It is worked on a little at a time (`work`).

const CLEAR := 40.0                     # pixels over a ledge that it climbs before it lets go
const CLIMB_SPEED := VineHold.CLIMB_SPEED
const STAIR_WAIT := 12.0                # seconds it reckons to wait for a swinging stair (it stands 6 to 12 s at each of two or three landings)
const FLOOR_TILES := MoveMap.TILE
const AIR_CASTS := [0.0, 0.2, 0.4]      # seconds after it could first cast in the air that it thinks of doing it
const FLY_MOST := 7.0                   # seconds of a flight it thinks ahead
const STEEPS := [0.0, -20.0, -40.0, -55.0, 25.0]  # the slants of a stroke it thinks of (degrees, below 0 is up)
const THROWS := [-90.0, -65.0, -45.0]
const SETTLE := 0.15                    # seconds to come to rest before a stroke on the ground
const RIDE_MOST := 44                   # columns of water it thinks of going over at once
const LAID_AT_ONCE := 260.0             # pixels of floor it lays at a time: what it can draw of it on its screen
const RIDE_FROM := 3                    # columns from the water's edge it sets out
const TILTS: Array[float] = [-36.0, -6.0]  # degrees a slab is leaned: as steep as a body walks up, and near enough level
const FOOT_AHEAD := 10.0
const STEP_UP := 112.0                  # pixels: a step no higher than this is hopped up onto
const SIGHT := 420.0                    # how far off it draws a thing where it wants it
const STATE_BITS := 6
const PERILS_MOST := 6                  # how many things in the way it bears in mind that it might put an end to
const HARM := 0.5                       # seconds it would rather lose than take one harm, when whole; more the more worn it is
const HURT_MOST := 0.3                  # the share of all it has that it will never go through with losing, where no one says what the goal is worth
const UNDO_WAIT := 2.2                  # seconds it reckons to wait for a thing to burn, blow or die away
const NEAR_PERIL := 9                   # columns: it thinks of its spells when what is in the way is this near
const WADE_LEAP := 2                    # columns a body can leap out of what slows it
const CHANCE_HARM := 15.0               # the harm it reckons on where chance may set it down in what is in the way
const RISK := 2.5                       # seconds it would rather not trust to chance
const JUMP_CARE := 0.6                  # seconds it would rather walk than jump: a jump can be missed
const SURELY := 0.65                     # the share of what a stroke stands that it counts on
const SURE := 0.95                      # the share of a carry it counts on
const SHORT_WALK := 1.6                 # a walk this many times the straight line is a long way round
const SHORTCUT_PLACES := 60             # how many places it looks out from for a shortcut, where it could walk
const GREED := 1.3                      # how much it trusts the straight line to the goal
const UP_PACE := 190.0                  # about how fast spells take a wizard up, all told, in pixels a second (only a guess to steer the search by)
const LEAN_EVERY := 3                   # rows: and at every so many, whether or not there is a ledge
const LEAN_WITHIN := 8                  # columns from which a floor overhead may be leaned over to

## A step of the way that was found.
class Leg extends RefCounted:
	var kind := ""                 # "walk", "jump" (Walkways' own moves), or "fly": what it casts, and which way it holds
	var to := Vector2i.ZERO        # the tile it ends on, or hangs in
	var hangs := false
	var casts: Array[Dictionary] = []   # {"spell", "way" (a unit vector, of a stroke), "far" (its length), "at" (where from), "when" (seconds into the leg)}
	var holds: Array[Dictionary] = []   # {"dir", "from" (seconds into the leg)}
	var seconds := 0.0
	var hurt := 0.0                # the harm it reckons to take on it
	var chancy := false            # where it goes is partly chance
	var undoes: Node               # what in the way it puts an end to, where that is the leg
	var point := Vector2.ZERO      # and where it is struck

## What a spell does from a place: where it leads, how long and at what price. The same for every wizard, so kept on the map.
class Edge extends RefCounted:
	var to := Vector2i.ZERO
	var body: MoveBody
	var leg: Leg
	var seconds := 0.0
	var spent := 0.0

## A place the search has come to.
class Place extends RefCounted:
	var key := 0
	var tile := Vector2i.ZERO
	var body: MoveBody             # where it hangs, or nothing when it stands
	var buffs := 0                 # which of the states it can put on itself it wears, as bits
	var left := Wizard.MAX_STAMINA # stamina in hand
	var price := 0.0
	var hurt := 0.0                # the harm taken so far
	var clock := 0.0               # seconds gone by (a state wears off by these)
	var ends := PackedFloat32Array()
	var parent: Place
	var leg: Leg
	var done := false

var map: MoveMap
var goal := Vector2i.ZERO
var found := false
var finished := false
var places := 0                    # how many it has looked out from
var flights := 0
var effort := 0                    # how much work it has done (see work)
var most_places := 4000

var _keep := 0.0                   # stamina it would rather not go under
var _most := Wizard.MAX_STAMINA
var _knows := Callable()           # whether it has seen a tile
var _price := Callable()           # what standing on a tile costs, in seconds (thorns, lava), where that is asked
var _pace := Wizard.SPEED
var _perils: Array[Dictionary] = []    # {"node", "box", "undone"}: what lies in the way that harms or hinders (Perils)
var _peril_on := {}                    # tile -> [[which, harm a second, pace]], found once asked for
var _rides: Array[Dictionary] = []     # the spells that take it along the top of water
var _waters: Array[Node] = []
var _stands: Array[Dictionary] = []    # the spells that leave something to stand on and leap from: {"tilts": slabs leaned up at an angle} or {"steps": branches at a height}
var _touches: Array[Dictionary] = []   # the spells that reach somewhere, and the stuff they are made of
var _per_harm := HARM
var _worth := HURT_MOST
var _carries: Array[Dictionary] = []
var _launches: Array[Dictionary] = []
var _states: Array[Dictionary] = []
var _climbs: Array[Dictionary] = []
var _sink: Array[Edge] = []
var _todo: Array[Callable] = []    # what is still to be thought of from the place it looks out from, so that a moment's work is never long
var _carry_names := ""
var _heap: Array[Place] = []
var _ranks := PackedFloat32Array()
var _best := {}                    # key -> the Place
var _end: Place
var _from := Vector2i.ZERO
var _foot := false
var _foot_end: Place
var _ceiling := INF                # what it costs on foot: nothing dearer is worth a look
var _walk: MovePlan                # the same question on foot alone, asked first


## kit: {"spells": the Spells held, "stamina", "most", "keep", "pace", "draw": seconds to draw a spell (Callable(Spell) -> float), "knows": Callable(tile) -> bool, "price": Callable(tile) -> float}
func _init(over: MoveMap, from: Vector2i, to: Vector2i, kit: Dictionary) -> void:
	map = over
	goal = to
	_from = from
	_keep = kit.get("keep", 0.0)
	_most = kit.get("most", Wizard.MAX_STAMINA)
	_knows = kit.get("knows", Callable())
	_price = kit.get("price", Callable())
	_worth = kit.get("worth", HURT_MOST)
	_per_harm = HARM * pow(Wizard.MAX_STAMINA / maxf(_most, 1.0), 2.0)
	_bear_in_mind(kit.get("perils", []), from)
	_pace = kit.get("pace", Wizard.SPEED)
	_learn(kit.get("spells", []), kit.get("draw", func(_spell: Spell) -> float: return 0.5))
	for move in _carries:
		_carry_names += "+" + _id_of(move)
	var start := Place.new()
	start.tile = from
	start.key = _key(from, false, 0)
	start.left = kit.get("stamina", _most)
	start.ends.resize(_states.size())
	_best[start.key] = start
	_push(start)
	if not (_carries.is_empty() and _launches.is_empty() and _states.is_empty() and _climbs.is_empty() and _touches.is_empty() and _rides.is_empty() and _stands.is_empty()):
		var bare := kit.duplicate()
		bare["spells"] = []
		_walk = MovePlan.new(over, from, to, bare)


## What the spells held do to a body, as their data says it.
func _learn(spells: Array, draw: Callable) -> void:
	for spell: Spell in spells:
		var dear := _dear(spell)
		if dear + _keep > _most or spell.school == "Blood":
			continue
		var base := {"spell": spell, "cost": dear, "draw": draw.call(spell)}
		for part in spell.parts:
			var lasts: float = part.get("for", INF)
			if not spell.made_of.is_empty() and part["where"] in ["shot", "ray", "spray", "place"]:
				var reach: float = part.get("reach", part.get("long", SIGHT))
				_touches.append({"spell": spell, "cost": dear, "draw": base["draw"], "where": part["where"], "reach": reach, "made_of": spell.made_of})
			for one: Dictionary in part["does"]:
				var effect := part.duplicate()
				effect.erase("does")
				effect.merge(one, true)
				var move := base.duplicate()
				move["effect"] = effect
				match String(one["do"]):
					"carry":
						if part["where"] == "self":
							move["ways"] = _strokes_read(spell)
							_carries.append(move)
					"drive":
						if part["where"] == "self" and one.get("way", "") == "up":
							_launches.append(move)
						elif part["where"] == "self" and one.get("way", "") == "level" and _floats(spell):
							_rides.append({"spell": spell, "cost": dear, "draw": base["draw"], "speed": float(one["speed"]), "lasts": lasts, "laid": false})
					"solid":
						if spell.targeting == "raised":  # a slab from the ground, as the stroke leans: walked up like a ramp
							var long: float = one["most"]
							_stands.append({"spell": spell, "cost": _dear_of(spell, long), "draw": base["draw"], "after": 0.6, "long": long, "half": float(one["thick"]) * 0.5})
					"floor":
						for ledge: Array in one.get("ledges", []):
							if float(ledge[0]) <= STEP_UP and part.get("needs", "") == "ground":
								_stands.append({"spell": spell, "cost": dear, "draw": base["draw"], "after": float(part.get("after", 0.0)) + 0.2, "ledge": ledge})
						if part["where"] == "place" and part.get("needs", "") == "water":
							_rides.append({"spell": spell, "cost": dear, "draw": base["draw"], "speed": _pace, "lasts": lasts, "laid": true, "wide": float(one.get("wide", 0.0)), "after": float(part.get("after", 0.0))})
					"lift":
						_launches.append(move)
					"throw":
						if part["where"] == "place" and part.get("shape", "") != "along" and one.get("way", "") in ["up", "stroke"]:
							_launches.append(move)  # (what throws ahead of the caster is no way for it to go anywhere)
					"climb":
						_climbs.append(move)
					"state":
						if part["where"] == "self" and _moves_better(one["state"]):
							move["state"] = one["state"]
							move["lasts"] = lasts
							_states.append(move)


## What lies in the way, the nearest to the way there first.
func _bear_in_mind(nodes: Array, from: Vector2i) -> void:
	var a := MoveMap.feet(from)
	var b := MoveMap.feet(goal)
	var far := {}
	for node: Node in nodes:
		var box: Rect2 = node.peril_box()
		var middle := box.get_center()
		far[node] = middle.distance_to(Geometry2D.get_closest_point_to_segment(middle, a, b))
	var sorted := nodes.duplicate()
	sorted.sort_custom(func(one: Node, two: Node) -> bool: return far[one] < far[two])
	for node: Node in sorted:
		if node.has_method("is_water") and node.is_water():
			_waters.append(node)
		_perils.append({"node": node, "box": node.peril_box(), "undone": node.undone_by()})


## Whether a spell carries a floor over water along with whoever casts it.
static func _floats(spell: Spell) -> bool:
	for part in spell.parts:
		for one: Dictionary in part["does"]:
			if one["do"] == "floor" and part["where"] == "with" and one.get("over", "") == "water":
				return true
	return false


## The price of a spell drawn so long.
static func _dear_of(spell: Spell, long: float) -> float:
	return spell.cost_for({"line": PackedVector2Array([Vector2.ZERO, Vector2(long, 0.0)]), "length": long, "reach": long})


## Up onto what a spell leaves to stand on, and a leap from there.
func _stand_on(body: MoveBody, stand: Dictionary) -> void:
	for dir: int in [1, -1]:
		for tilt: float in (TILTS if stand.has("long") else [0.0]):
			var foot := body.at
			var tip := Vector2.ZERO
			var way := Vector2(dir, 0.0)
			if stand.has("long"):
				way = Vector2.from_angle(deg_to_rad(tilt)) * Vector2(dir, 1.0)
				foot = body.at + Vector2(dir * FOOT_AHEAD, 4.0)
				if not map.solid_at(foot + Vector2(0.0, 12.0)) or not map.solid_at(foot + Vector2(dir * 60.0, 12.0)):
					continue  # (it stands on the ground)
				tip = foot + way * float(stand["long"]) + Vector2(-dir * 14.0, -float(stand["half"]))
			else:
				var ledge: Array = stand["ledge"]
				tip = body.at + Vector2((float(ledge[1]) + float(ledge[2])) * 0.5 - dir * 0.0, -float(ledge[0]))
				if dir < 0:
					tip.x = body.at.x + (float(ledge[1]) + float(ledge[2])) * 0.5
			if not _open(body.at, tip):
				continue
			var up := body.copy()
			up.at = tip
			up.grounded = true
			var lead := float(stand["draw"]) + SETTLE + float(stand["after"]) + absf(tip.x - body.at.x) / up.pace + (0.5 if stand.has("ledge") else 0.2)
			var cast := {"spell": stand["spell"], "way": way, "far": 0.0, "at": body.at, "when": 0.0, "tip": tip - body.at, "after": stand["after"]}
			if stand.has("long"):
				cast["foot"] = foot - body.at
				cast["long"] = stand["long"]
			up.jump()
			up.air_x = dir * up.pace
			_fly(up, float(dir), [cast], [{"dir": float(dir), "from": lead, "lead": lead}], lead, float(stand["cost"]) + Wizard.JUMP_COST, true)


## Whether a body can go up in a straight line from one place to another: nothing solid in the way of its feet, middle or head.
func _open(from: Vector2, to: Vector2) -> bool:
	for up: float in [-14.0, -34.0, -56.0]:
		if not _clear(from + Vector2(0.0, up), to + Vector2(0.0, up)):
			return false
	return true


## Along the top of water to the bank at the far side: on a wave that carries it, or on a floor laid there.
func _ride(here: Place, ride: Dictionary) -> void:
	for dir: int in [1, -1]:
		var row := here.tile.y
		var most := int(float(ride["speed"]) * float(ride["lasts"]) * 0.8 / MoveMap.TILE)
		var wet_from := INF
		var wet_to := INF
		var level := 0.0
		for k in range(1, mini(most, RIDE_MOST)):
			var x := here.tile.x + dir * k
			var mid := (x + 0.5) * MoveMap.TILE
			var feet := MoveMap.feet(Vector2i(x, row)).y
			var top := INF
			for water in _waters:
				if not is_instance_valid(water):
					continue
				var box: Rect2 = water.peril_box()
				if mid > box.position.x and mid < box.end.x:
					var at: float = water.surface_at(mid)
					if at > feet - 10.0 and at < feet + 52.0:
						top = minf(top, at)
			var dry := WorldNav.NONE
			for dy in [0, -1, 1]:
				var tile := Vector2i(x, row + dy)
				if map.can_stand(tile) and MoveMap.feet(tile).y <= top + 6.0:
					dry = tile
					break
			if dry != WorldNav.NONE:
				row = dry.y
				if wet_from < INF:
					var leg := Leg.new()
					leg.kind = "ride"
					leg.to = dry
					leg.seconds = float(ride["draw"]) + SETTLE + (0.5 if ride["laid"] else 0.0) + k * MoveMap.TILE / float(ride["speed"])
					var cast := {"spell": ride["spell"], "way": Vector2(dir, 0.0), "far": 0.0, "at": MoveMap.feet(here.tile), "when": 0.0}
					if ride["laid"]:
						var a := minf(wet_from, wet_to) - MoveMap.TILE
						cast["after"] = ride["after"]
						cast["wide"] = ride["wide"]  # (a floor in pieces may end a piece short)
						cast["span"] = Rect2(a, level, absf(wet_to - wet_from) + 2.0 * MoveMap.TILE, 8.0)
					leg.casts.append(cast)
					leg.holds.append({"dir": float(dir), "from": 0.0})
					var dear: float = ride["cost"]
					if ride["laid"]:  # a stretch at a time, as much as it can draw at once
						var stretches := ceilf((cast["span"] as Rect2).size.x / LAID_AT_ONCE)
						var long := minf((cast["span"] as Rect2).size.x, LAID_AT_ONCE)
						dear = float(ride["spell"].cost_for({"line": PackedVector2Array([Vector2.ZERO, Vector2(long, 0.0)]), "length": long, "rect": Rect2(0.0, 0.0, long, 8.0), "radius": long * 0.5})) * stretches
						leg.seconds += (stretches - 1.0) * (float(ride["draw"]) + 0.6)
					_come(here, dry, null, leg, leg.seconds, dear, here.buffs)
					break
			elif top < INF and not map.solid(Vector2i(x, row)):
				if wet_from == INF:
					if k > RIDE_FROM:
						break  # (it walks up to the water first)
					wet_from = mid
					level = top
				wet_to = mid
			else:
				break


## What goes on at a tile: each thing in the way that is there.
func _perils_on(tile: Vector2i) -> Array:
	if not _peril_on.has(tile):
		var found := []
		var feet := MoveMap.feet(tile) + Vector2(0.0, -6.0)
		for k in _perils.size():
			if is_instance_valid(_perils[k]["node"]) and (_perils[k]["box"] as Rect2).grow(20.0).has_point(feet):  # (it thinks over many frames, and a flow may be gone by then)
				var does: Dictionary = {}
				for off: Vector2 in [Vector2.ZERO, Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Vector2(0.0, -20.0)]:
					if does.is_empty():
						does = _perils[k]["node"].peril_at(feet + off)
				if not does.is_empty():
					found.append([k, float(does["harm"]), float(does["pace"]), does.get("jump", true), float(does.get("after", 0.0)), String(does.get("shared", ""))])
		_peril_on[tile] = found
	return _peril_on[tile]


## What a moment on a tile costs: [the seconds it is longer by, the harm].
func _toll(tile: Vector2i, seconds: float, buffs: int) -> Vector2:
	var slow := 1.0
	var harm := 0.0
	var as_one := {}  # what harms as one, however much of it lies there
	for one: Array in _perils_on(tile):
		if one[0] < PERILS_MOST and buffs & (1 << (STATE_BITS + int(one[0]))) != 0:
			continue
		slow = minf(slow, one[2])
		if one[5] == "":
			harm += one[1]
		else:
			as_one[one[5]] = maxf(as_one.get(one[5], 0.0), one[1])
	for shared: String in as_one:
		harm += as_one[shared]
	var long := seconds / slow
	return Vector2(long - seconds, harm * long)


## Whether it could jump from a tile, for what is there.
func _jumps_from(tile: Vector2i, buffs: int) -> bool:
	for one: Array in _perils_on(tile):
		if not one[3] and not (one[0] < PERILS_MOST and buffs & (1 << (STATE_BITS + int(one[0]))) != 0):
			return false
	return true


## The share of its pace a body has on a tile.
func _pace_on(tile: Vector2i, buffs: int) -> float:
	var pace := 1.0
	for one: Array in _perils_on(tile):
		if not (one[0] < PERILS_MOST and buffs & (1 << (STATE_BITS + int(one[0]))) != 0):
			pace = minf(pace, one[2])
	return pace


## What it goes on losing after it has got into what is on a tile (a flame that has caught), coming from one where that is not.
func _after(from: Vector2i, tile: Vector2i, buffs: int) -> float:
	var harm := 0.0
	for one: Array in _perils_on(tile):
		if one[4] <= 0.0 or (one[0] < PERILS_MOST and buffs & (1 << (STATE_BITS + int(one[0]))) != 0):
			continue
		if not _perils_on(from).any(func(was: Array) -> bool: return was[4] > 0.0):
			harm = maxf(harm, one[4])
	return harm


func _near_peril(tile: Vector2i, buffs: int) -> bool:
	var feet := MoveMap.feet(tile)
	for k in _perils.size():
		if k < PERILS_MOST and buffs & (1 << (STATE_BITS + k)) != 0:
			continue
		var box: Rect2 = _perils[k]["box"]
		if absf(box.get_center().x - feet.x) < box.size.x * 0.5 + NEAR_PERIL * MoveMap.TILE and absf(box.get_center().y - feet.y) < box.size.y * 0.5 + 200.0:
			return true
	return false


## The price of a spell drawn at its ordinary size.
func _dear(spell: Spell) -> float:
	return spell.cost_for({"radius": spell.size_unit, "length": SpellData.STEP_MAX, "line": PackedVector2Array([Vector2.ZERO, Vector2(spell.size_unit, 0.0)])})


func _moves_better(state: String) -> bool:
	var does: Dictionary = BodyStates.TABLE.get(state, {})
	return does.get("pace", 1.0) > 1.0 or does.has("fall") or does.has("air_jump")


## The ways a stroke may be drawn so that it is still read as this spell.
func _strokes_read(spell: Spell) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var options: Dictionary = SpellData.bindings()[spell.buttons]
	for side: float in [1.0, -1.0]:
		for steep: float in STEEPS:
			var way := Vector2.from_angle(deg_to_rad(steep)) * Vector2(side, 1.0)
			if spell.gesture != "flick" or StrokeReader.straight_means(options, way, Vector2.ZERO, Vector2.ZERO) == "flick":
				out.append(way)
	return out


## Whether there is a way on foot alone, over ground that costs nothing: then spells are only a shortcut, and it does not look long for one.
func on_foot() -> bool:
	return _foot


## Goes on searching for so much work: about 20 is a millisecond's. It is counted, not timed, so that a game comes out the same on a quick machine and a slow one.
## True when it has done.
func work(budget := 1 << 40) -> bool:
	var until := effort + budget
	if _walk != null:
		var before := _walk.effort
		var walked := _walk.work(budget)
		effort += _walk.effort - before
		if not walked:
			return false
		_foot = _walk.found and _walk._end.hurt <= 0.0
		if _foot and _walk.cost() < Vector2(goal - _from).length() * MoveMap.TILE / _pace * SHORT_WALK + 1.0:  # (a long way round, or a wait, is worth a better look)
			most_places = mini(most_places, SHORTCUT_PLACES)
		_ceiling = _walk.cost()
		if effort >= until:
			_walk_over()
			return finished
		_walk_over()
	while not finished:
		if not _todo.is_empty():
			(_todo.pop_back() as Callable).call()
			effort += 1
			if effort >= until:
				break
			continue
		if _heap.is_empty() or places >= most_places:
			finished = true
			if _foot_end != null and not found and _ceiling < INF:  # no shortcut was come upon: it walks
				found = true
				_end = _foot_end
			break
		var here := _pop()
		if here.done:
			continue
		here.done = true
		if here.body == null and here.tile == goal:
			_end = here
			found = true
			finished = true
			break
		places += 1
		effort += 1
		if here.body == null:
			_from_ground(here)
		else:
			_from_air(here)
		if effort >= until:
			break
	return finished


## The way that was found, from its beginning.
func legs() -> Array[Leg]:
	var out: Array[Leg] = []
	var here := _end
	while here != null and here.leg != null:
		out.push_front(here.leg)
		here = here.parent
	return out


func cost() -> float:
	return _end.price if _end != null else INF


# --- looking out from a place --------------------------------------------------------------------------------------------

func _from_ground(here: Place) -> void:
	var walk := _walk_speed(here)
	var free := _jumps_from(here.tile, here.buffs)
	var pace := _pace_on(here.tile, here.buffs)
	for to in map.steps(here.tile):
		var across := absi(to.x - here.tile.x)
		var rise := here.tile.y - to.y
		var climbs := map.climbs(here.tile, to)
		var jumps := not climbs and (across >= 2 or rise >= 2)
		if jumps and (here.left < Wizard.JUMP_COST or not free or (pace < 1.0 and across > WADE_LEAP)):
			continue  # (what slows a body slows its leap: in it, a body wades, and hops up onto what is beside it)
		var seconds := Vector2(to - here.tile).length() * MoveMap.TILE / walk
		if climbs:
			seconds = absf(rise) * MoveMap.TILE / CLIMB_SPEED if across <= 2 else seconds + STAIR_WAIT
		var leg := Leg.new()
		leg.kind = "jump" if jumps else "walk"
		leg.to = to
		leg.seconds = seconds
		var toll := _toll(to, seconds if not jumps or pace < 1.0 else 0.3, here.buffs)
		leg.hurt = toll.y + _after(here.tile, to, here.buffs)
		leg.seconds += toll.x
		_come(here, to, null, leg, seconds + toll.x + (JUMP_CARE if jumps else 0.0), Wizard.JUMP_COST if jumps else 0.0, here.buffs)
	if _carries.is_empty() and _launches.is_empty() and _states.is_empty() and _climbs.is_empty() and _touches.is_empty() and _rides.is_empty() and _stands.is_empty():
		return
	var near := _near_peril(here.tile, here.buffs)
	if near:
		_undo(here)
		for ride in _rides:
			_ride(here, ride)
	if not near and not map.turns(here.tile, 9 if not _stands.is_empty() else (6 if not _carries.is_empty() else 3)):
		return
	if not _perils_on(here.tile).is_empty() and _toll(here.tile, 1.0, here.buffs).y > 0.0:
		return  # (no one stands in it to draw)
	for k in _states.size():
		if here.buffs & (1 << k) == 0:
			_put_on(here, k)
	for move in _carries:
		_think(here, _id_of(move), func() -> void: _carry_on(_standing(here), move, [], [], 0.0, SETTLE))
	for move in _launches:
		for way in _launch_ways(move["effect"]):
			_think(here, "%s %s %s" % [_id_of(move), _carry_names, way], func() -> void: _launch(here.tile, _standing(here), move, way))
	for move in _climbs:
		_think(here, _id_of(move), func() -> void: _climb(_standing(here), move))
	for stand in _stands:
		_think(here, "stand %s" % stand["spell"].spell_name, func() -> void: _stand_on(_standing(here), stand))
	if not _carries.is_empty() or here.buffs != 0:
		for dir: float in [1.0, -1.0]:
			_think(here, "leap%d %s" % [int(dir), _carry_names], func() -> void: _leap(_standing(here), dir))


func _from_air(here: Place) -> void:
	for dir: float in [1.0, -1.0, 0.0]:
		_think(here, "hang%d %s" % [int(dir), _carry_names], func() -> void: _drop(here.body.copy(), dir))


func _drop(body: MoveBody, dir: float) -> void:
	body.map = map
	_fly(body, dir, [], [{"dir": dir, "from": 0.0}], 0.0, 0.0, true)


func _leap(leap: MoveBody, dir: float) -> void:
	leap.jump()
	leap.air_x = dir * leap.pace
	_fly(leap, dir, [], [{"dir": dir, "from": 0.0, "leap": true}], 0.0, Wizard.JUMP_COST, true)


## The ways a thing that takes it up may be pointed.
func _launch_ways(effect: Dictionary) -> Array[Vector2]:
	var ways: Array[Vector2] = [Vector2.UP]
	if effect["do"] == "throw" and effect.get("way", "") == "stroke":
		for side: float in [1.0, -1.0]:
			for steep: float in THROWS:
				if steep > -90.0:
					ways.append(Vector2.from_angle(deg_to_rad(steep)) * Vector2(side, 1.0))
	if effect.has("aside"):  # it throws to a side by chance: it reckons on half of what it may, either way, and with the least speed
		ways.clear()
		for side: float in [1.0, -1.0]:
			ways.append(Vector2(side * float(effect["aside"]) * 0.5, -float(effect["speed"]) * float(effect["least"])) / float(effect["speed"]))
	return ways


func _think(here: Place, what: String, work_out: Callable) -> void:
	_todo.append(func() -> void: _take(here, _edges(here, what, work_out)))


func _id_of(move: Dictionary) -> String:
	return str((move["spell"] as Spell).get_instance_id())


## What is to be had from a place, worked out the first time anyone asks.
func _edges(here: Place, what: String, work_out: Callable) -> Array:
	var states := ""
	for k in _states.size():
		if here.buffs & (1 << k) != 0:
			states += String(_states[k]["state"])
	var key := "%d %s %s %d" % [(here.key >> 12) if here.body != null else map.id(here.tile) * 2, what, states, int(_pace)]
	if not map.edges.has(key):
		_sink = []
		work_out.call()
		map.edges[key] = _sink
	return map.edges[key]


func _take(here: Place, edges: Array) -> void:
	for edge: Edge in edges:
		_come(here, edge.to, edge.body, edge.leg, edge.seconds, edge.spent, here.buffs)


func _emit(to: Vector2i, body: MoveBody, leg: Leg, spent: float) -> void:
	var edge := Edge.new()
	edge.to = to
	edge.body = body
	if body != null:
		body.map = null  # (it is kept on the map: holding it too, neither would ever be let go)
	edge.leg = leg
	edge.seconds = leg.seconds
	edge.spent = spent
	_sink.append(edge)


## Puts an end to what is in the way with whatever it holds that does, from where it stands.
func _undo(here: Place) -> void:
	var feet := MoveMap.feet(here.tile)
	var eye := feet + Vector2(0.0, -40.0)
	for k in mini(_perils.size(), PERILS_MOST):
		var bit := 1 << (STATE_BITS + k)
		if here.buffs & bit != 0 or not is_instance_valid(_perils[k]["node"]):
			continue
		var box: Rect2 = _perils[k]["box"]
		var near := Vector2(clampf(feet.x, box.position.x, box.end.x), clampf(feet.y - 10.0, box.position.y, box.end.y))
		var off := near.distance_to(eye)
		if off < 60.0 or absf(near.x - feet.x) < 30.0:
			continue
		for touch in _touches:
			if off > float(touch["reach"]) - 20.0 or not _any(touch["made_of"], _perils[k]["undone"]):
				continue
			if touch["where"] != "place" and not _clear(eye, near + Vector2(0.0, -8.0)):
				continue
			var leg := Leg.new()
			leg.kind = "undo"
			leg.to = here.tile
			leg.undoes = _perils[k]["node"]
			leg.point = near + Vector2(signf(near.x - feet.x) * minf(box.size.x * 0.5, 40.0), 0.0)
			leg.seconds = float(touch["draw"]) + SETTLE + UNDO_WAIT
			leg.casts.append({"spell": touch["spell"], "way": (leg.point - eye).normalized(), "far": 0.0, "at": feet, "when": 0.0})
			_come(here, here.tile, null, leg, leg.seconds, touch["cost"], here.buffs | bit)


static func _any(some: Array, of: Array) -> bool:
	for one in some:
		if of.has(one):
			return true
	return false


func _clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(1, int(from.distance_to(to) / 16.0))
	for k in steps + 1:
		if map.solid_at(from.lerp(to, float(k) / steps)):
			return false
	return true


## Puts a state on itself, standing.
func _put_on(here: Place, k: int) -> void:
	var move := _states[k]
	var leg := Leg.new()
	leg.kind = "fly"
	leg.to = here.tile
	leg.seconds = float(move["draw"]) + SETTLE
	leg.casts.append({"spell": move["spell"], "way": Vector2.ZERO, "far": 0.0, "at": MoveMap.feet(here.tile), "when": 0.0})
	_come(here, here.tile, null, leg, leg.seconds, move["cost"], here.buffs | (1 << k), k)


## Carried along a stroke, from the ground or the air. `since` is how long into the leg the stroke is drawn, `held` what it had in hand.
func _carry_on(body: MoveBody, move: Dictionary, casts: Array, holds: Array, spent: float, seconds: float) -> void:
	var most: float = move["effect"]["most"]
	for far: float in ([most, most * 0.55] if body.grounded else [most]):
		var dear: float = move["spell"].cost_for({"length": far})
		for way: Vector2 in move["ways"]:
			if way.y > 0.0 and body.grounded:
				continue
			var ends := body.copy()
			ends.carried(way, far * SURE)
			if ends.at.distance_to(body.at) < 40.0:
				continue
			ends.grounded = false
			var leg := Leg.new()
			leg.kind = "fly"
			leg.to = ends.tile()
			leg.hangs = true
			leg.seconds = seconds + float(move["draw"])
			leg.holds.assign(holds)
			leg.casts.assign(casts)
			leg.casts.append({"spell": move["spell"], "way": way, "far": far, "at": body.at, "when": seconds})
			_emit(ends.tile(), ends, leg, spent + dear)


## Cast where it stands, and then up: it may lean either way at any height on the way, or at the top.
func _launch(tile: Vector2i, body: MoveBody, move: Dictionary, along: Vector2) -> void:
	var effect: Dictionary = move["effect"]
	for way: Vector2 in [along]:
		var up := body.copy()
		match String(effect["do"]):
			"drive":
				up.driven(effect)
			"lift":
				up.lifts = up.lifts.duplicate()
				up.lifts.append({"at": up.at, "lift": effect})
			"throw":
				var begins := up.time + float(effect.get("after", 0.0))
				up.jets.append({"at": up.at, "throw": effect, "way": way, "from": begins, "to": begins + float(effect.get("for", 0.1)), "next": 0.0})
		var lead := float(move["draw"]) + SETTLE + (RISK if effect.has("aside") else 0.0)
		var casts := [{"spell": move["spell"], "way": way, "far": 0.0, "at": body.at, "when": 0.0, "chancy": effect.has("aside")}]
		if absf(way.x) > 0.01:  # thrown to a side: it leans that way, or not
			_fly(up.copy(), signf(way.x), casts, [{"dir": signf(way.x), "from": lead, "lead": lead}], lead, move["cost"], true)
			continue
		var from_y := up.at.y
		var rows := {}  # dir -> the heights (in rows) at which to lean that way
		for dir: int in [1, -1]:
			rows[dir] = map.ledges(tile, dir, LEAN_WITHIN, 24)
			for rise in range(LEAN_EVERY, 25, LEAN_EVERY):
				if not rows[dir].has(rise):
					rows[dir].append(rise)
		var left := false
		var began := up.time
		while up.time - began < FLY_MOST:
			up.tick(0.0)
			if not up.grounded:
				left = true
			var rising := from_y - up.at.y
			var top := left and up.speed_y >= 0.0 and up.drive.is_empty()
			if left:
				var since := up.time - began
				for dir: int in [1, -1]:
					var leans := top
					for k in range(rows[dir].size() - 1, -1, -1):
						if rising >= rows[dir][k] * MoveMap.TILE + 4.0:
							rows[dir].remove_at(k)
							leans = true
					if leans:
						_fly(up.copy(), float(dir), casts, [{"dir": float(dir), "from": lead + since, "rise": rising, "lead": lead}], lead + since, move["cost"], top)
			if top or (left and up.grounded):
				break
			if up.at.y < -100000.0:
				break


## Up what a spell leaves to climb, and off it either way.
func _climb(body: MoveBody, move: Dictionary) -> void:
	var effect: Dictionary = move["effect"]
	var rise := 2.0 * MoveMap.TILE + CLEAR
	while rise <= float(effect["most"]):
		var up := body.copy()
		up.at.y -= rise
		if map.solid_span(up.at.x, up.at.y - MoveBody.TALL, up.at.y):
			break
		up.grounded = false
		var since := rise / CLIMB_SPEED + 0.6  # (it grows first)
		var lead := float(move["draw"]) + SETTLE + since
		for dir: float in [1.0, -1.0]:
			_fly(up.copy(), dir, [{"spell": move["spell"], "way": Vector2.UP, "far": rise, "at": body.at, "when": 0.0}], [{"dir": dir, "from": lead, "climb": rise, "lead": lead}], lead, move["cost"], false)
		rise += 2.0 * MoveMap.TILE


## A flight, holding one way, from here to where it lands; where `may_cast`, it also thinks of being carried on from the air.
func _fly(body: MoveBody, dir: float, casts: Array, holds: Array, seconds: float, spent: float, may_cast: bool) -> void:
	flights += 1
	effort += 2
	var began := body.time
	var marks: Array[float] = []
	var draw := 0.0
	var pieces: Array[float] = []      # the moments at which it looks where its view has got to
	var view_at := {}                  # the moment a stroke would begin -> where the view was
	if may_cast and not _carries.is_empty():
		draw = _carries[0]["draw"]
		for wait: float in AIR_CASTS:
			marks.append(wait + draw)
		if body.speed_y < 0.0:
			marks.append(maxf(-body.speed_y / map.gravity, draw))  # at the top of it
		for mark in marks:
			for k in 5:
				pieces.append(mark - draw + draw * 0.25 * k)
		pieces.sort()
		body.look(0.0)
		view_at[0.0] = body.view
	var still := 0
	while body.time - began < FLY_MOST:
		var was := body.at
		if body.drive.is_empty() and body.lifts.is_empty() and body.jets.is_empty():
			var next := began + FLY_MOST
			while not pieces.is_empty() and began + pieces[0] <= body.time + 0.001:
				pieces.pop_front()
			if not pieces.is_empty():
				next = minf(next, began + pieces[0])
			var before := body.time
			body.fly(dir, next)
			body.look(body.time - before)
			still = 0
		else:
			body.tick(dir)
			body.leave_behind(dir)
		var since := body.time - began
		if body.grounded and (body.speed_y == 0.0) and since > 0.05 and body.shove.y >= 0.0 and body.drive.is_empty():
			var tile := body.tile()
			if not map.can_stand(tile):
				for off: Vector2i in [Vector2i(0, -1), Vector2i(signi(int(dir)), 0), Vector2i(-signi(int(dir)), 0), Vector2i(0, 1)]:
					if map.can_stand(tile + off):
						tile += off
						break
			if map.can_stand(tile):
				var leg := Leg.new()
				leg.kind = "fly"
				leg.to = tile
				leg.seconds = seconds + since
				leg.casts.assign(casts)
				leg.holds.assign(holds)
				leg.chancy = not casts.is_empty() and casts[0].get("chancy", false)
				_emit(tile, null, leg, spent)
			return
		if body.at.y > map.bottom_y():
			return
		still = still + 1 if body.at.distance_squared_to(was) < 0.01 else 0
		if still > 90:
			return
		if not marks.is_empty():
			view_at[since] = body.view
		for k in range(marks.size() - 1, -1, -1):
			if since >= marks[k] - 0.009:
				var begins := marks[k] - draw
				marks.remove_at(k)
				if not _steady(_view_then(view_at, begins), body.view):
					continue
				for move in _carries:
					_carry_on(body, move, casts, holds, spent, seconds + since - float(move["draw"]))


## Where the view was at a moment, from those that were noted (the nearest).
func _view_then(noted: Dictionary, when: float) -> Vector2:
	var best := INF
	var view := Vector2.ZERO
	for at: float in noted:
		if absf(at - when) < best:
			best = absf(at - when)
			view = noted[at]
	return view


## Whether a stroke begun with the view at one place and ended with it at another keeps its shape (BrainHand.drag_ok: how much each shape stands has been measured).
func _steady(from: Vector2, to: Vector2) -> bool:
	var stands: Dictionary = BrainStrokes.drift_table().get(_carries[0]["spell"].spell_name, {})
	if not stands.has("right"):
		return true
	var slide := to - from
	return absf(slide.x) <= float(stands["right"] if slide.x >= 0.0 else stands["left"]) * BrainHand.DRAG_MARGIN * SURELY and absf(slide.y) <= float(stands["down"] if slide.y >= 0.0 else stands["up"]) * BrainHand.DRAG_MARGIN * SURELY


# --- the search's own ------------------------------------------------------------------------------------------------------

func _walk_speed(here: Place) -> float:
	return _pace * _pace_of(here.buffs)


func _pace_of(buffs: int) -> float:
	var share := 1.0
	for k in _states.size():
		if buffs & (1 << k) != 0:
			share *= BodyStates.pace(_states[k]["state"])
	return share


func _standing(here: Place) -> MoveBody:
	var body := MoveBody.new()
	body.map = map
	body.at = MoveMap.feet(here.tile)
	body.grounded = true
	body.pace = _walk_speed(here)
	for k in _states.size():
		if here.buffs & (1 << k) != 0:
			body.fall_most = minf(body.fall_most, BodyStates.fall(_states[k]["state"]))
	return body


func _key(tile: Vector2i, hangs: bool, buffs: int) -> int:
	if hangs:  # (a body in the air is much the same a tile off)
		tile = Vector2i(tile.x & ~1, tile.y & ~1)
	return (map.id(tile) * 2 + int(hangs)) * 4096 + buffs


func _come(here: Place, tile: Vector2i, body: MoveBody, leg: Leg, seconds: float, spent: float, buffs: int, put_on := -1) -> void:
	if body == null and not map.can_stand(tile):
		return
	if _knows.is_valid() and not _knows.call(tile):
		return
	var price := here.price + seconds + spent / Wizard.STAMINA_REGEN
	if body == null and _price.is_valid():
		price += _price.call(tile)
	var hurt := leg.hurt
	if body == null and leg.kind in ["fly", "ride"] and not _perils.is_empty():  # it comes down in it, and has to get out
		hurt = _toll(tile, 0.3, buffs).y + _after(here.tile, tile, buffs)
		if leg.chancy and _near_peril(here.tile, here.buffs):
			hurt += CHANCE_HARM
	price += hurt * _per_harm
	if here.hurt + hurt > _most * _worth:
		return
	var clock := here.clock + seconds
	var ends := here.ends
	if put_on >= 0:
		ends = ends.duplicate()
		ends[put_on] = clock + float(_states[put_on]["lasts"])
	for k in _states.size():  # what has worn off by then
		if buffs & (1 << k) != 0 and ends[k] < clock:
			buffs &= ~(1 << k)
	if price >= _ceiling:
		return
	var key := _key(tile, body != null, buffs)
	var old: Place = _best.get(key)
	if old != null and (old.done or old.price <= price):
		return
	var place := Place.new()
	place.key = key
	place.tile = tile
	place.body = body
	place.buffs = buffs
	place.left = maxf(here.left, spent + _keep if here.body == null else 0.0) - spent  # (on the ground it can wait until it has enough: the waiting is in the price)
	if place.left < 0.0:
		return
	place.price = price
	place.hurt = here.hurt + hurt
	place.clock = clock
	place.ends = ends
	place.parent = here
	place.leg = leg
	if old != null:
		old.done = true  # (the dearer way there is dropped when it comes up)
	_best[key] = place
	_push(place)


func _rank(place: Place) -> float:
	var off := Vector2(place.tile - goal).abs() * MoveMap.TILE
	return place.price + (off.x / _pace + off.y / (UP_PACE if place.tile.y > goal.y else 700.0)) * GREED


func _walk_over() -> void:
	_foot_end = _walk._end
	_walk = null


func _push(place: Place) -> void:
	var rank := _rank(place)
	_heap.append(place)
	_ranks.append(rank)
	var k := _heap.size() - 1
	while k > 0:
		var up := (k - 1) >> 1
		if _ranks[up] <= rank:
			break
		_heap[k] = _heap[up]
		_ranks[k] = _ranks[up]
		k = up
	_heap[k] = place
	_ranks[k] = rank


func _pop() -> Place:
	var top := _heap[0]
	var last: Place = _heap.pop_back()
	var rank := _ranks[_ranks.size() - 1]
	_ranks.resize(_ranks.size() - 1)
	var size := _heap.size()
	if size > 0:
		var k := 0
		while true:
			var down := 2 * k + 1
			if down >= size:
				break
			if down + 1 < size and _ranks[down + 1] < _ranks[down]:
				down += 1
			if _ranks[down] >= rank:
				break
			_heap[k] = _heap[down]
			_ranks[k] = _ranks[down]
			k = down
		_heap[k] = last
		_ranks[k] = rank
	return top
