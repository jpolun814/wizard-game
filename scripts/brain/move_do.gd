class_name MoveDo
extends RefCounted

## An AI wizard getting somewhere by a way it has worked out (MovePlan): it walks the legs on foot, stands where a spell is to be cast, draws the stroke, leans when it should, and
## sees whether it came down where it meant to. When it did not, it thinks again from where it is. Nothing here knows one spell from another: a stroke is made from the spell's own
## picture and how it is aimed (docs/handoff/23_movement_planning.md, section 2D).

const THOUGHT := 60            # how much it thinks in a frame (about 3 ms of work; MovePlan.work)
const DRAW := 0.2              # the least time it takes over a stroke
const CHORD := 0.08            # and more where the buttons are a chord
const ON_THE_SPOT := 5.0       # pixels
const STILL_FOR := 0.12
const FULL_STROKE := 1.12      # a stroke meant to carry it as far as it can is drawn a little longer than it need be
const EDGE := 14.0
const AT_A_FACE := 28.0        # pixels: the foot of a face is rounded, and a body against it may stand no nearer to the middle of the tile than this
const CAST_WAIT := 2.5         # seconds it waits for its spell to go off before it thinks again
const LEG_LONGEST := 14.0
const AIR_TRIES := 0.35        # seconds it goes on trying to begin a stroke in the air
const FORGET := 12.0           # seconds it remembers that it found no way somewhere
const MISSES := 3              # times it thinks again before it gives the place up

var brain: WizardBrain
var wizard: Wizard
var goal := WorldNav.NONE
var fails := 0
var last_miss := ""            # why it last thought again, for the logs
var told := false              # it says what it does, for a person looking into it
var _plan: MovePlan
var _plan_to := WorldNav.NONE
var _no_way := {}              # tile -> seconds it still remembers that there was no way there
var _legs: Array[MovePlan.Leg] = []
var _at := 0
var _from := WorldNav.NONE     # the tile the leg in hand began on
var _stage := ""               # "", "walk", "settle", "cast", "go"
var _t := 0.0                  # seconds into the leg's flight (since its spell went off, where it begins with one)
var _waited := 0.0
var _still := 0.0
var _casts := 0                # how many of the leg's casts are done
var _made := 0                 # the wizard's count of casts when the stroke in hand was begun
var _left := false             # it has left the ground in this leg
var _from_y := 0.0
var _climbed := false
var _hops := 0


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


# --- thinking ------------------------------------------------------------------------------------------------------------

## Whether there is a way to a tile by its spells: "found", "none", or "thinking" (ask again: it goes on thinking in `tick_thought`).
func ask(to: Vector2i) -> String:
	if _no_way.has(to):
		return "none"
	var here := _standing_on()
	if here == WorldNav.NONE:
		return "thinking"
	if _plan == null or _plan_to != to:
		_begin_thought(here, to)
	if not _plan.finished:
		return "thinking"
	if not _plan.found:
		_no_way[to] = FORGET
		_plan = null
		return "none"
	if _plan_from != here:  # it has moved on since: it thinks again from here (what it worked out is remembered, so this is quick)
		_begin_thought(here, to)
		return "thinking"
	return "found"


var _plan_from := WorldNav.NONE


## It has thought of going there lately, and there is no way.
func ask_before(to: Vector2i) -> bool:
	return _no_way.has(to)


func _begin_thought(from: Vector2i, to: Vector2i) -> void:
	_plan_to = to
	_plan_from = from
	_plan = MovePlan.new(wizard.nav.ground(), from, to, kit())


## A frame's thinking, and the forgetting.
func tick_thought(delta: float) -> void:
	for tile: Vector2i in _no_way.keys():
		_no_way[tile] -= delta
		if _no_way[tile] <= 0.0:
			_no_way.erase(tile)
	if _plan != null and not _plan.finished and not active():
		_plan.work(THOUGHT)


## What it has to go by: the spells it holds, its strength, and what it has seen.
func kit() -> Dictionary:
	var spells: Array[Spell] = []
	for spell: Spell in SpellData.SPELLS.values():
		if not spell.parts.is_empty() and wizard.ledger.knows_spell(spell.spell_name):
			spells.append(spell)
	var out := {"spells": spells, "stamina": wizard.stamina, "most": wizard.max_stamina, "draw": draw_time, "keep": brain.reserve() if brain.opponent != null else 0.0}
	if brain.explore.sight_is_limited():
		out["knows"] = func(tile: Vector2i) -> bool: return brain.explore.explored.has(brain.explore.square_of(MoveMap.feet(tile)))
	return out


func draw_time(spell: Spell) -> float:
	var chord: bool = spell.buttons & (spell.buttons - 1) != 0
	return maxf(DRAW, BrainStrokes.quickest_stroke(spell.spell_name) * minf(brain.slow, 1.0)) + (CHORD if chord else 0.0)


## The tile it stands on, as the map has it.
func _standing_on() -> Vector2i:
	if not wizard.is_on_floor():
		return WorldNav.NONE
	var ground := wizard.nav.ground()
	var tile := Vector2i(floori(wizard.global_position.x / MoveMap.TILE), floori((wizard.global_position.y - 4.0) / MoveMap.TILE))
	for off: Vector2i in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2)]:
		if ground.can_stand(tile + off):
			return tile + off
	return WorldNav.NONE


## The place to stand nearest a point, within reach of it.
func stand_near(point: Vector2, within: int) -> Vector2i:
	var ground := wizard.nav.ground()
	var tile := Vector2i(floori(point.x / MoveMap.TILE), floori((point.y - 4.0) / MoveMap.TILE))
	var best := WorldNav.NONE
	for dx in range(-within, within + 1):
		for dy in range(-within, within + 1):
			var there := tile + Vector2i(dx, dy)
			if ground.can_stand(there) and (best == WorldNav.NONE or Vector2(there - tile).length_squared() < Vector2(best - tile).length_squared()):
				best = there
	return best


## Whether the way it has found casts anything before it comes to a stair (else it is the way it is on already).
func by_spells() -> bool:
	if _plan == null:
		return false
	var from := _plan_from
	for leg in _plan.legs():
		if not leg.casts.is_empty():
			return true
		if leg.kind != "fly" and wizard.nav.ground().climbs(from, leg.to):
			return false
		from = leg.to
	return false


# --- going ---------------------------------------------------------------------------------------------------------------

func active() -> bool:
	return _at < _legs.size()


## It is in the middle of a leg that cannot be dropped: in the air, or drawing.
func committed() -> bool:
	return active() and (_stage == "cast" or _stage == "go")


## Sets out on the way it has found (see ask).
func set_out() -> void:
	goal = _plan_to
	fails = 0
	_take_up(_plan)


func stop() -> void:
	_legs.clear()
	_at = 0
	_stage = ""
	wizard.pad.climb = false
	wizard.pad.let_go = false


func _take_up(plan: MovePlan) -> void:
	_legs = plan.legs()
	_at = 0
	_from = _plan_from
	_stage = ""
	_plan = null
	if told:
		for leg in _legs:
			if leg.kind == "fly" or leg == _legs[-1]:
				print("      leg %s to %s%s %s %s" % [leg.kind, leg.to, " (hangs)" if leg.hangs else "", leg.casts.map(func(c: Dictionary) -> String: return "%s at %s when %.2f way %s far %.0f" % [c["spell"].spell_name, Vector2i(c["at"]), c["when"], c["way"], c["far"]]), leg.holds])


## Goes on with it. The speed to go at.
func go(delta: float) -> float:
	var leg := _legs[_at]
	_waited += delta
	if _stage == "":
		_begin_leg(leg)
	match _stage:
		"walk":
			return _walk(delta)
		"settle":
			return _settle(leg, delta)
		"cast":
			return _wait_for_cast(leg)
	return _fly(leg, delta)


func _begin_leg(leg: MovePlan.Leg) -> void:
	_waited = 0.0
	_still = 0.0
	_t = 0.0
	_casts = 0
	_left = false
	_climbed = false
	_hops = 0
	if leg.kind != "fly":
		var tiles: Array[Vector2i] = [_from]
		var k := _at
		while k < _legs.size() and _legs[k].kind != "fly":
			tiles.append(_legs[k].to)
			k += 1
		brain.route.set_path(tiles)
		_stage = "walk"
	elif _at > 0 and _legs[_at - 1].hangs:
		_stage = "go"  # it hangs in the air from the one before
		_from_y = wizard.global_position.y
		_left = true
	else:
		_stage = "settle"


func _walk(delta: float) -> float:
	var steer := brain.route.steer(wizard, delta)
	if steer["replan"] or _waited > LEG_LONGEST * 4.0:
		return _miss("walk: " + brain.route.status())
	if brain.route.done():
		while active() and _legs[_at].kind != "fly":
			_from = _legs[_at].to
			_at += 1
		_stage = ""
		return 0.0
	if steer["drop"]:
		wizard.drop_through()
	if steer["jump"] and wizard.is_on_floor():
		wizard.request_jump()
	wizard.pad.climb = steer["climb"]
	wizard.pad.let_go = steer["let_go"]
	return steer["dir"] * steer["speed"]


## Where on a tile it stands to begin: the middle, but a little in from a drop, whose edge is rounded off and would slide it over.
func _spot(tile: Vector2i) -> float:
	var ground := wizard.nav.ground()
	var x := MoveMap.feet(tile).x
	for dir: int in [-1, 1]:
		if not ground.walks_on(tile, dir) and not ground.solid(tile + Vector2i(dir, 0)) and ground.walks_on(tile, -dir):
			x -= dir * EDGE
	return x


## To the middle of the tile, and still.
func _settle(leg: MovePlan.Leg, delta: float) -> float:
	var off := _spot(_from) - wizard.global_position.x
	if _waited > 5.0 or absf(off) > 160.0 or absf(wizard.global_position.y - MoveMap.feet(_from).y) > 60.0:
		return _miss("settle: %.0f px off" % off)
	if not wizard.is_on_floor():
		_still = 0.0
		return 0.0
	var pressed := absf(off) < AT_A_FACE and (wizard.is_on_wall() or _hops > 0)
	if wizard.is_on_wall() and wizard.velocity.y >= 0.0:
		_hops += 1  # (it keeps from walking at it, which would set it hopping)
	if absf(off) > ON_THE_SPOT and not pressed:
		_still = 0.0
		return clampf(off * 8.0, -WizardBrain.WALK_SPEED, WizardBrain.WALK_SPEED) if absf(off) > 24.0 else signf(off) * 50.0 if absf(off) > ON_THE_SPOT else 0.0
	_still += delta
	if _still < STILL_FOR or wizard.pen.active():
		return 0.0
	_from_y = wizard.global_position.y
	if _leaps(leg):  # it goes with a leap, and casts in the air if at all
		if wizard.stamina < Wizard.JUMP_COST:
			_waited = 0.0
			return 0.0
		wizard.request_jump()
		_stage = "go"
		return float(leg.holds[0]["dir"]) * WizardBrain.WALK_SPEED if not leg.holds.is_empty() else 0.0
	if wizard.stamina < _dear(leg.casts[0]):
		_waited = minf(_waited, 1.0)  # it waits till it has the strength
		return 0.0
	if _draw(leg.casts[0]):
		_stage = "cast"
		_waited = 0.0
	return 0.0


## A leg that begins with a leap, and not with a spell.
func _leaps(leg: MovePlan.Leg) -> bool:
	return not leg.holds.is_empty() and leg.holds[0].get("leap", false)


func _dear(cast: Dictionary) -> float:
	var spell: Spell = cast["spell"]
	return spell.cost_for({"radius": spell.size_unit, "length": cast["far"], "line": PackedVector2Array([Vector2.ZERO, Vector2(spell.size_unit, 0.0)])})


func _draw(cast: Dictionary) -> bool:
	var spell: Spell = cast["spell"]
	_made = wizard.casts_made
	var begun := brain.hand.begin_cast(spell.spell_name, stroke_of(cast), draw_time(spell) - (CHORD if spell.buttons & (spell.buttons - 1) != 0 else 0.0))
	if not begun:
		brain.hand.pending = {}
	_tell("stroke %s%s" % [spell.spell_name, "" if begun else " REFUSED"])
	return begun


## The stroke of a spell, from its picture and how it is aimed.
func stroke_of(cast: Dictionary) -> PackedVector2Array:
	var spell: Spell = cast["spell"]
	var middle := wizard.center()
	var feet := wizard.global_position
	match spell.gesture:
		"flick":
			var most: float = spell.effect_of("carry").get("most", 0.0)
			var far: float = cast["far"]
			return BrainStrokes.line(middle, middle + (cast["way"] as Vector2) * (far * FULL_STROKE if far >= most - 1.0 else far))
		"circle_push":
			return brain.hand.push_stroke(middle, cast["way"])
		"vine":
			return BrainStrokes.offset(GestureTemplates.preview_points("vine"), Vector2(middle.x + 50.0 * BrainMoves.VINE_SCALE, feet.y - 75.0 * BrainMoves.VINE_SCALE), BrainMoves.VINE_SCALE)
		"feather":
			return brain.hand.tend_stroke(spell.spell_name, Vector2.ZERO)
	return BrainStrokes.offset(GestureTemplates.preview_points(spell.gesture), middle, 0.6)


func _wait_for_cast(leg: MovePlan.Leg) -> float:
	if wizard.casts_made > _made:
		_casts = 1
		_tell("cast")
		_t = 0.0
		_stage = "go"
		_waited = 0.0
		if leg.hangs and leg.casts.size() == 1:
			return _done(leg)
		if leg.holds.is_empty() and not _moves(leg):
			return _done(leg)  # it has put something on itself: that is the leg
		return 0.0
	if not wizard.pen.active() and _waited > 0.3 or _waited > CAST_WAIT:
		return _miss("the stroke did not go off")
	return 0.0


func _moves(leg: MovePlan.Leg) -> bool:
	return leg.to != _from


## In the air, or about to be.
func _fly(leg: MovePlan.Leg, delta: float) -> float:
	_t += delta
	var grounded := wizard.is_on_floor()
	if not grounded:
		_left = true
	if _t > LEG_LONGEST:
		return _miss("the flight did not end")
	var hold: Dictionary = leg.holds[0] if not leg.holds.is_empty() else {}
	if hold.has("climb") and not _climbed:
		wizard.pad.climb = true
		if _from_y - wizard.global_position.y >= float(hold["climb"]) - 4.0:
			wizard.pad.climb = false
			_climbed = true
			_tell("lets go")
			return float(hold["dir"]) * WizardBrain.WALK_SPEED
		if _t > 6.0:
			return _miss("the climb")
		if told and int(_t * 60.0) % 20 == 0:
			_tell("climbing (%s)" % wizard.vine.hanging())
		return 0.0
	if _casts < leg.casts.size() and not wizard.pen.active():  # a stroke in the air
		var cast := leg.casts[_casts]
		if wizard.casts_made > _made and _waited < 0.0:
			_casts += 1
			_tell("cast in the air")
			_waited = 0.0
			if _casts == leg.casts.size() and leg.hangs:
				return _done(leg)
		elif _t >= float(cast["when"]) - _lead(leg):
			if _t > float(cast["when"]) - _lead(leg) + AIR_TRIES:
				return _miss("no stroke in the air")
			if wizard.stamina < _dear(cast):
				return _miss("no strength for a stroke in the air")
			if _draw(cast):
				_waited = -1000.0  # (a stroke is in hand: the next time the pen is down it has gone off, or not)
	elif _casts < leg.casts.size() and _waited < 0.0 and wizard.casts_made > _made:
		_casts += 1
		_tell("cast in the air")
		_waited = 0.0
		if _casts == leg.casts.size() and leg.hangs:
			return _done(leg)
	if not leg.hangs and _left and grounded and _t > 0.1 and not _rising(leg):
		return _down(leg)
	if not _left and _t > 5.0:
		return _miss("it never left the ground")
	if hold.is_empty():
		return 0.0
	var dir: float = hold["dir"]
	if hold.has("rise") and not _leans(hold):
		return 0.0
	if not leg.hangs and wizard.velocity.y > 0.0:  # coming down: it makes for the middle of where it means to land
		var off := MoveMap.feet(leg.to).x - wizard.global_position.x
		if off * dir < 0.0:
			dir = signf(off) if absf(off) > 8.0 else 0.0
	return dir * WizardBrain.WALK_SPEED


## How much of the leg's time was spent before the flight began (the stroke and the settling), for a leg that began with a cast.
func _lead(leg: MovePlan.Leg) -> float:
	if _leaps(leg) or leg.casts.is_empty():
		return 0.0
	return float(leg.holds[0].get("lead", 0.0)) if not leg.holds.is_empty() else 0.0


## Whether the height at which it was to lean over has been reached, or the top of the flight.
func _leans(hold: Dictionary) -> bool:
	if hold.get("leaning", false):
		return true
	var up := _from_y - wizard.global_position.y
	if up >= float(hold["rise"]) - 4.0 or (_left and wizard.velocity.y >= 0.0 and up > 24.0):
		_lean_from = _at
	return _lean_from == _at


var _lean_from := -1


func _rising(leg: MovePlan.Leg) -> bool:
	return wizard.rocket_time > 0.0 and leg.casts.size() > 0 and _t < 0.4


## It has come down.
func _down(leg: MovePlan.Leg) -> float:
	var here := _standing_on()
	if here == WorldNav.NONE:
		return _miss("it came down nowhere it knows")
	if absi(here.x - leg.to.x) > 1 or absi(here.y - leg.to.y) > 1:
		return _miss("it came down at %s and meant to at %s" % [here, leg.to])
	return _done(leg)


func _done(leg: MovePlan.Leg) -> float:
	_from = leg.to
	_at += 1
	_stage = ""
	_lean_from = -1
	wizard.pad.climb = false
	if not active():
		stop()
	return 0.0


func _tell(what: String) -> void:
	if told:
		print("      %s at %s, %.2f s in, %s px/s" % [what, Vector2i(wizard.global_position), _t, Vector2i(wizard.velocity)])


## It did not go as it thought: it thinks again from where it is, or gives the place up.
func _miss(why: String) -> float:
	last_miss = why
	if told:
		print("      miss: %s" % why)
	MatchRecorder.event("MISS %d %s" % [wizard.get_instance_id(), why.replace(" ", "_")])
	stop()
	fails += 1
	if fails >= MISSES:
		_no_way[goal] = FORGET
		fails = 0
		brain.goal = ""
		brain.goal_timer = 0.0
	return 0.0
