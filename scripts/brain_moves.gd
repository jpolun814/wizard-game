class_name BrainMoves
extends RefCounted

## The manoeuvres an AI wizard has in hand while it crosses something: a leap over a pit, a wade through lava in black glass, and a lift up a wall
## (a Geyser, a vine, an oak, a whirlwind). Each is a dictionary of where it has got to, empty when it is not at it; `tick` goes on with the one in brain.hand.

const LEAP_AIR_MAX := 4.0     # seconds in the air after which a leap is given up
const LEAP_DRAW := 0.15       # seconds to draw one: it falls the while
const LIFT_WAIT := 1.6         # seconds it stands on a Geyser it has drawn, waiting to be thrown, before it takes it for a miss
const SHOVE_WAIT := 1.0         # seconds it waits to be off the ground after shoving itself up, before it takes it for a miss
const VINE_SCALE := 2.4          # how much bigger than its picture it draws a vine, to grow it taller than a wall
const VINE_OVER := 70.0          # pixels over the top of the wall that it climbs before it lets go, to clear the edge when it drops
const VINE_WAIT := 8.0          # seconds it climbs before it takes the vine for a miss
const WADE_WAIT := 40.0          # seconds it spends in a pit before it takes the crossing for a miss
const LIFT_CLEARANCE := 40.0    # pixels it must be thrown above the top of a wall to get over it
const TORNADO_WAIT := 2.5       # seconds it walks into a whirlwind it has drawn, waiting to be flung, before it takes it for a miss
const OAK_GROW := 1.1           # seconds it waits for a great oak to stand before it climbs
const OAK_WAIT := 9.0           # seconds it climbs an oak before it takes it for a miss

var leap := {}  # a jump over a chasm: {"dir": -1 or 1, "key", "steps": Shadow Steps left to make, "span": the chasm, "jumped", "air": seconds since it left the ground}
var wade := {}  # a walk through the lava of a pit in black glass: {"dir", "key", "span": the pit, "stage", "waited"}
var lift := {}  # a throw up over a wall: {"spell", "dir", "key", "span": the wall, "drawn", "thrown", "waited"}

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Whether one of them is in brain.hand.
func busy() -> bool:
	return not (lift.is_empty() and leap.is_empty() and wade.is_empty())


## Goes on with the one in brain.hand. The speed to go at.
func tick(delta: float) -> float:
	if not leap.is_empty():
		return leaping(delta)
	if not wade.is_empty():
		return wading(delta)
	return lifting(delta)


## Starts a leap over a pit from where it stands (see leaping), with the fields that differ by the way it is made.
func start_leap(key: String, span: Rect2, dir: int, extra: Dictionary) -> void:
	leap = {"dir": dir, "key": key, "span": span, "jumped": false, "air": 0.0}
	leap.merge(extra)


## Starts a lift up a wall from where it stands (see lifting). False, and the wall is given up for a while, when rock overhead would stop it short.
func begin_lift(spell_name: String, key: String, dir: int, span: Rect2) -> bool:
	var needed := wizard.global_position.y - (span.position.y - LIFT_CLEARANCE)
	if wizard.test_move(wizard.global_transform, Vector2(0.0, -needed)):  # rock overhead stops the water short of the top
		brain.gates.give_up_on(key)
		return false
	lift = {"spell": spell_name, "dir": dir, "key": key, "span": span, "drawn": false, "thrown": false, "waited": 0.0}
	return true


## A walk through the lava of a pit in black glass: it waits for the glass, wades to the foot of the far side, and is lifted out of the pit
## as it would be over a wall. Returns the speed to go at.
func wading(delta: float) -> float:
	var span: Rect2 = wade["span"]
	var dir: int = wade["dir"]
	wade["waited"] += delta
	if wizard.pen.active():
		return 0.0
	if wade["waited"] > WADE_WAIT or (wade["stage"] == 0 and wade["waited"] > 3.0 and wizard.obsidian_time <= 0.0):
		brain.gates.give_up_on(wade["key"])
		wade = {}
		return 0.0
	if wade["stage"] == 0:
		if wizard.obsidian_time > 0.0:
			wade["stage"] = 1
		return 0.0
	var foot := (span.end.x if dir > 0 else span.position.x) - dir * 36.0
	if (foot - wizard.global_position.x) * dir > 12.0 or not wizard.is_on_floor():
		return clampf((foot - wizard.global_position.x) * 4.0, -WizardBrain.WALK_SPEED, WizardBrain.WALK_SPEED)
	var floor_y := span.position.y - WizardRoute.TILE * 2.0  # the pit's lava lies two rows under the floor it was dug into
	var side := Rect2(Vector2(span.end.x if dir > 0 else span.position.x - 96.0, floor_y), Vector2(96.0, span.end.y - floor_y))
	var key: String = wade["key"]
	wade = {}
	begin_lift(brain.gates.way_up(), key, dir, side)
	return 0.0


## A jump over a pit: it leaps from the edge, and in the air carries itself on with Shadow Steps until it is across. Returns the speed to go at.
func leaping(delta: float) -> float:
	var span: Rect2 = leap["span"]
	var dir: int = leap["dir"]
	if wizard.is_on_floor():
		if leap["jumped"]:  # down again: over, or in the pit
			var across: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5
			if not across:
				brain.gates.give_up_on(leap["key"])
			brain.gates.crossed(leap["key"])
			leap = {}
			brain.forget_goal()
			return 0.0
		leap["jumped"] = true
		wizard.request_jump()
		return dir * WizardRoute.MAX_AIR_SPEED
	leap["air"] += delta
	var helpers: Array = leap.get("helpers", [])
	if not helpers.is_empty() and not wizard.pen.active():
		if helpers[0] == "Rocket Jump" and wizard.velocity.y < -40.0 and leap["air"] > 0.12:
			helpers.pop_front()
			brain.hand.begin_cast("Rocket Jump", BrainStrokes.offset(GestureTemplates.preview_points("rocket"), wizard.center(), 0.6), LEAP_DRAW)
		elif helpers[0] == "Featherfall" and wizard.velocity.y > -20.0:
			helpers.pop_front()
			brain.hand.begin_cast("Featherfall", brain.hand.tend_stroke("Featherfall", Vector2.ZERO), LEAP_DRAW)
		elif helpers[0] == "Rocket Jump" and wizard.velocity.y > -20.0 and leap["air"] > 0.5:
			helpers.pop_front()  # (it missed the moment)
	if leap.get("double", false) and wizard.air_jump_ready and wizard.velocity.y > -20.0:
		wizard.request_jump()  # the second jump, at the top of the first
		leap["double"] = false
	if leap["air"] > LEAP_AIR_MAX:  # held against a rock face: it lets go of the jump and falls
		brain.gates.give_up_on(leap["key"])
		leap = {}
		return 0.0
	var beyond: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5 - 40.0
	if leap["steps"] > 0 and not wizard.pen.active() and not beyond and (wizard.velocity.y > -40.0 or leap["steps"] < WizardBrain.LEAP_STEPS):
		leap["steps"] -= 1
		var start: Vector2 = wizard.center()
		brain.hand.begin_cast("Shadow Step", BrainStrokes.line(start, start + Vector2(dir * SpellData.STEP_MAX, -10.0).normalized() * SpellData.STEP_MAX), LEAP_DRAW)
	return dir * WizardRoute.MAX_AIR_SPEED


## A throw over a wall: it draws a Geyser under its feet and stands while the ground bubbles, and once the water has thrown it up it goes
## on across, over the top. Returns the speed to go at.
func lifting(delta: float) -> float:
	var span: Rect2 = lift["span"]
	var dir: int = lift["dir"]
	if not lift["drawn"]:
		if wizard.pen.active():
			return 0.0
		lift["drawn"] = true
		var feet: Vector2 = wizard.center()
		if lift["spell"] == "Push":
			brain.hand.begin_cast("Push", brain.hand.push_stroke(feet, Vector2(dir * 0.2, -1.0).normalized()), WizardBrain.QUICK_DRAW)
		elif lift["spell"] == "Liana":  # a vine from the ground at its feet, taller than the wall
			brain.hand.begin_cast("Liana", BrainStrokes.offset(GestureTemplates.preview_points("vine"), Vector2(feet.x + 50.0 * VINE_SCALE, wizard.global_position.y - 75.0 * VINE_SCALE), VINE_SCALE), WizardBrain.QUICK_DRAW)
		elif lift["spell"] == "Rocket Jump":  # an arrow up drawn at its feet: the flame throws it high
			brain.hand.begin_cast("Rocket Jump", BrainStrokes.offset(GestureTemplates.preview_points("rocket"), feet, 0.6), WizardBrain.QUICK_DRAW)
		elif lift["spell"] == "Updraft":  # a column of air where it stands
			brain.hand.begin_cast("Updraft", BrainStrokes.offset(GestureTemplates.preview_points("updraft"), feet, 0.6), WizardBrain.QUICK_DRAW)
		elif lift["spell"] == "Tornado":  # a whirlwind a step ahead of it, to walk into
			brain.hand.begin_cast("Tornado", BrainStrokes.offset(GestureTemplates.preview_points("tornado"), Vector2(feet.x + dir * 60.0, wizard.global_position.y - 90.0), 0.9), WizardBrain.ATTACK_DRAW)
		elif lift["spell"] == "Great Oak":  # a trunk drawn up from the ground a step ahead of it
			var shape := GestureTemplates.preview_points("tree")
			var foot := Vector2(feet.x + dir * 50.0, wizard.global_position.y - 4.0)
			var moved := PackedVector2Array()
			for p in shape:
				moved.append(foot + (p - shape[0]) * 0.7)
			brain.hand.begin_cast("Great Oak", BrainStrokes.densify(moved), WizardBrain.ATTACK_DRAW)
		else:
			brain.hand.begin_cast("Geyser", BrainStrokes.offset(GestureTemplates.preview_points("geyser"), feet, 0.6), WizardBrain.QUICK_DRAW)
		return 0.0
	if lift["spell"] == "Great Oak" and not lift["thrown"]:  # it climbs the oak's ledges one by one
		var step := climb_oak(delta, span, dir)
		if lift.is_empty():
			return 0.0
		if not lift["thrown"]:
			return step
	if lift["spell"] == "Liana" and not lift["thrown"]:  # it takes hold of the vine and climbs until its feet are over the top
		lift["waited"] += delta
		if wizard.global_position.y < span.position.y - VINE_OVER:
			lift["thrown"] = true
			wizard.climb_up = false
		elif lift["waited"] > VINE_WAIT:
			wizard.climb_up = false
			brain.gates.give_up_on(lift["key"])
			lift = {}
			return 0.0
		else:
			wizard.climb_up = true
			return 0.0
	if wizard.is_on_floor():
		var wait := LIFT_WAIT if lift["spell"] == "Geyser" or lift["spell"] == "Updraft" else (TORNADO_WAIT if lift["spell"] == "Tornado" else SHOVE_WAIT)
		if not lift["thrown"] and lift["waited"] < wait:  # the ground bubbles for a moment before the burst
			lift["waited"] += delta
			return dir * WizardBrain.WALK_SPEED if lift["spell"] == "Tornado" else 0.0  # (a whirlwind is walked into)
		var past: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5
		var on_top: bool = wizard.global_position.y < span.position.y + 4.0
		if lift["spell"] == "Great Oak" and lift["thrown"] and on_top and not past:  # on a ledge over the top: it jumps off toward the far side
			wizard.request_jump()
			return dir * WizardRoute.MAX_AIR_SPEED
		var across: bool = past or on_top  # (or on top of the wall)
		if not across:  # down again on the near side: the water did not throw it high enough
			brain.gates.give_up_on(lift["key"])
		brain.gates.crossed(lift["key"])
		lift = {}
		brain.forget_goal()
		return 0.0
	lift["thrown"] = true
	var clear: bool = wizard.global_position.y < span.position.y - 10.0
	return dir * WizardRoute.MAX_AIR_SPEED if clear else 0.0


## A climb up the ledges of an oak: it goes to the highest one it can jump onto, and jumps, until the top is within a jump. Returns the speed to go at.
func climb_oak(delta: float, span: Rect2, dir: int) -> float:
	lift["waited"] += delta
	if lift["waited"] < OAK_GROW:
		return 0.0
	var feet: Vector2 = wizard.global_position
	if feet.y - span.position.y <= WizardBrain.JUMP_REACH - 20.0:  # the top is a jump away
		lift["thrown"] = true
		wizard.request_jump()
		return dir * WizardRoute.MAX_AIR_SPEED
	var best := Rect2()
	var best_rise := 0.0
	for oak: GreatOak in wizard.get_tree().get_nodes_in_group("oaks"):
		for ledge in oak.ledge_tops():
			var rise := feet.y - ledge.position.y
			if rise > 6.0 and rise <= WizardBrain.JUMP_REACH and rise > best_rise and absf(feet.x - ledge.get_center().x) < 220.0:
				best = ledge
				best_rise = rise
	if best_rise == 0.0 or lift["waited"] > OAK_WAIT:  # no ledge it can reach: the oak is given up
		brain.gates.give_up_on(lift["key"])
		lift = {}
		return 0.0
	var under := clampf(feet.x, best.position.x + 12.0, best.end.x - 12.0)
	if wizard.is_on_floor() and absf(feet.x - under) < 8.0:
		wizard.request_jump()
	return clampf((under - feet.x) * 4.0, -WizardBrain.WALK_SPEED, WizardBrain.WALK_SPEED)
