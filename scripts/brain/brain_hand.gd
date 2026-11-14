class_name BrainHand
extends RefCounted

## The hand of an AI wizard: the strokes it draws for a spell, how they are drawn (in time, wandering as a person's hand does, shaken by the screen)
## and the moment to draw them (it stands still first when the view would drag a stroke out of shape).

const CHORD_GAP_MIN := 0.01  # seconds between the first button of a chord and the last (the middle half of 135 chords recorded)
const CHORD_GAP_MAX := 0.05
const SHOT_SPEED := 650.0     # roughly how fast its bolts fly, for leading a moving target

const HOLD_STILL := 0.4   # seconds it stands still when a stroke would be dragged out of shape

const DRAG_MARGIN := 0.7  # it keeps well inside what a shape stands
var hold_still := 0.0  # seconds more it stands still, when a stroke would be dragged out of shape
var pending := {}  # a stroke it stopped to draw: drawn as soon as it stands still enough (see draw_when_still)

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Once a frame: the stillness it keeps for a stroke runs out, and a stroke waiting for it is drawn.
func tick(delta: float) -> void:
	hold_still -= delta
	draw_when_still()


## It stands still for a moment, to draw a stroke the view would drag.
func stand_still() -> void:
	hold_still = HOLD_STILL


## The gesture for an attack, drawn where the spell should land.
func attack_stroke(spell_name: String) -> PackedVector2Array:
	var foe: Wizard = brain.foe()
	var feet: Vector2 = brain.sight.seen_feet(foe)
	var facing := signf(brain.sight.seen_feet(foe).x - wizard.global_position.x)
	if facing == 0.0:
		facing = 1.0
	for kind: Callable in [_aimed_stroke, _over_the_foe_stroke, _at_its_feet_stroke, _beside_itself_stroke]:
		var stroke: PackedVector2Array = kind.call(spell_name, foe, feet, facing)
		if not stroke.is_empty():
			return stroke
	return PackedVector2Array()


## A stroke that sends something at the rival: a line along the way it is to go, or a breath or a wave toward it.
func _aimed_stroke(spell_name: String, foe: Wizard, feet: Vector2, facing: float) -> PackedVector2Array:
	match spell_name:
		"Pebble":  # lobbed: aimed above the rival by as far as the stone will have fallen on the way
			var start: Vector2 = wizard.center() + Vector2(facing * 12.0, -6.0)
			var flight: float = start.distance_to(brain.sight.seen_center(foe)) / Pebble.SPEED
			var target := brain.predict(flight)
			target.y -= 0.5 * Pebble.FALL * flight * flight
			var aim := (target - start).angle() + brain.rng.randfn(0.0, 0.1 * (1.0 - brain.skill))
			return BrainStrokes.line(start, start + Vector2.from_angle(aim) * 90.0)
		"Ignite", "Frostbolt", "Barbs":
			var start: Vector2 = wizard.center() + Vector2(facing * 12.0, -6.0)
			var target := brain.predict(start.distance_to(brain.sight.seen_center(foe)) / SHOT_SPEED)
			var aim := (target - start).angle() + brain.rng.randfn(0.0, 0.16 * (1.0 - brain.skill))
			return BrainStrokes.line(start, start + Vector2.from_angle(aim) * 90.0)
		"Fire Breath", "Spore Puff":
			return breath_stroke(brain.sight.seen_center(foe))
		"Tide Surf", "Thorn Whip", "Leech":
			return surf_stroke(facing)
		"Eldritch Blast":  # an arrow pointing at the rival
			var pointing: float = (brain.predict(0.4) - wizard.center()).angle() + brain.rng.randfn(0.0, 0.1 * (1.0 - brain.skill))
			return BrainStrokes.offset(turned(GestureTemplates.preview_points("arrow"), pointing), wizard.center(), 0.8)
	return PackedVector2Array()


## A stroke drawn over the rival, or in the air above it, where the spell is to fall or form.
func _over_the_foe_stroke(spell_name: String, foe: Wizard, feet: Vector2, facing: float) -> PackedVector2Array:
	match spell_name:
		"Hailstorm":  # a cloud over the rival's head, and the hail falls from it
			return BrainStrokes.offset(GestureTemplates.preview_points("hailstorm"), Vector2(brain.sight.seen_center(foe).x + 20.0, brain.sight.seen_center(foe).y - 120.0), 1.0)
		"Spark":
			var x := brain.predict(WizardBrain.ATTACK_DRAW * 0.8).x
			return BrainStrokes.offset(GestureTemplates.preview_points("zigzag"), Vector2(x, brain.sight.seen_center(foe).y - 90.0), 1.0)
		"Stonefall":
			var x := brain.predict(WizardBrain.ATTACK_DRAW + 0.6).x
			return BrainStrokes.offset(GestureTemplates.preview_points("stonefall"), Vector2(x, brain.sight.seen_center(foe).y - 130.0), 0.8)
		"Ice Prison":
			return BrainStrokes.offset(GestureTemplates.preview_points("circle"), brain.predict(WizardBrain.ATTACK_DRAW * 0.6), 0.8)
		"Earthquake":
			# Drawn in the air above the middle of the fight, where the peaks read clearly.
			return BrainStrokes.offset(GestureTemplates.preview_points("earthquake"), Vector2(brain.predict(WizardBrain.ATTACK_DRAW * 0.6).x, brain.sight.seen_center(foe).y - 120.0), 1.0)
		"Black Hole":
			# Beyond you if you are close (it drags you away from it), between you if you keep shooting at it.
			var spot: Vector2 = brain.sight.seen_center(foe) + Vector2(facing * 80.0, 0.0)
			if brain.pressure > 1.5:
				spot = wizard.center().lerp(brain.sight.seen_center(foe), 0.4)
			var spiral := GestureTemplates.preview_points("spiral")
			# The black hole forms where the spiral ends, so place the spiral's end on the spot.
			return BrainStrokes.offset(spiral, spot - (spiral[spiral.size() - 1] - BrainStrokes.box_centre(spiral)), 1.0)
		"Blizzard":
			return BrainStrokes.offset(GestureTemplates.preview_points("snowfall"), Vector2(feet.x - 30.0, brain.sight.seen_center(foe).y - 70.0), 0.8)
		"Icicles":  # Vs hung over its head, their tips just above it
			return BrainStrokes.offset(GestureTemplates.preview_points("icicles"), Vector2(brain.sight.seen_center(foe).x, brain.sight.seen_center(foe).y - 35.0), 0.9)
		"Hex":
			return BrainStrokes.offset(GestureTemplates.preview_points("pentagram"), brain.predict(0.3), 0.5)
		"Vacuum":
			return BrainStrokes.offset(GestureTemplates.preview_points("lungs"), brain.sight.seen_center(foe), 0.5)
		"Faint":
			return BrainStrokes.offset(GestureTemplates.preview_points("spiral"), brain.sight.seen_center(foe), 0.5)
		"Fight or Flight":
			return BrainStrokes.offset(GestureTemplates.preview_points("question"), brain.sight.seen_center(foe), 0.6)
		"Silence":
			return BrainStrokes.offset(GestureTemplates.preview_points("silence"), brain.sight.seen_center(foe), 0.6)
		"Hemorrhage":  # a drop of blood drawn over the rival
			return BrainStrokes.offset(GestureTemplates.preview_points("flare"), brain.sight.seen_center(foe), 0.6)
		"Supernova":  # a planet and its ring, drawn where the sun should hang: over the rival
			return BrainStrokes.offset(GestureTemplates.preview_points("saturn"), brain.predict(WizardBrain.ATTACK_DRAW), 0.8)
	return PackedVector2Array()


## A stroke drawn on the ground at the rival's feet, or between them and the wizard.
func _at_its_feet_stroke(spell_name: String, foe: Wizard, feet: Vector2, facing: float) -> PackedVector2Array:
	match spell_name:
		"Tornado":
			var x: float = lerpf(wizard.global_position.x, brain.sight.seen_feet(foe).x, 0.45)
			return BrainStrokes.offset(GestureTemplates.preview_points("tornado"), Vector2(x, feet.y - 90.0), 0.9)
		"Mudslide":
			var x := brain.predict(WizardBrain.ATTACK_DRAW * 0.6).x
			return BrainStrokes.offset(GestureTemplates.preview_points("wave"), Vector2(x, feet.y - 60.0), 1.0)
		"Firewall":
			var x: float = lerpf(wizard.global_position.x, brain.sight.seen_feet(foe).x, 0.5)
			var toward := signf(brain.sight.seen_feet(foe).x - wizard.global_position.x)  # a wall between them: up from the ground, then out across the way
			return BrainStrokes.offset(facing_flipped(GestureTemplates.preview_points("flame_wall"), toward), Vector2(x - toward * 50.0, feet.y - 50.0), 0.8)
		"Stalagmite":
			return BrainStrokes.offset(GestureTemplates.preview_points("stalagmite"), Vector2(brain.predict(WizardBrain.ATTACK_DRAW * 0.6).x, feet.y - 40.0), 0.9)
		"Bramble":
			return BrainStrokes.offset(GestureTemplates.preview_points("bramble"), Vector2(lerpf(wizard.global_position.x, brain.sight.seen_feet(foe).x, 0.8), feet.y - 16.0), 1.0)
		"Flytrap":
			return BrainStrokes.offset(GestureTemplates.preview_points("jaws"), Vector2(brain.predict(WizardBrain.ATTACK_DRAW * 0.6).x, feet.y - 30.0), 0.8)
		"Sinkhole":  # a U drawn into the ground under its feet
			return BrainStrokes.offset(GestureTemplates.preview_points("pit"), Vector2(brain.predict(WizardBrain.ATTACK_DRAW * 0.6).x, feet.y + 20.0), 0.8)
	return PackedVector2Array()


## A stroke drawn by the wizard on itself or on the ground beside it.
func _beside_itself_stroke(spell_name: String, foe: Wizard, feet: Vector2, facing: float) -> PackedVector2Array:
	match spell_name:
		"Flaming Sphere":  # a ring and a level line toward it, along the ground beside the wizard
			return BrainStrokes.offset(facing_flipped(GestureTemplates.preview_points("sphere"), facing), wizard.center() + Vector2(facing * 50.0, 0.0), 0.8)
		"Mirage":  # a tall box drawn on the ground a little ahead of it
			return BrainStrokes.offset(GestureTemplates.preview_points("portrait"), Vector2(wizard.center().x + facing * 90.0, wizard.global_position.y - 60.0), 0.8)
		"Raise Dead":  # a cross drawn upright in the ground beside it: the skeleton rises there, on its way toward you
			return BrainStrokes.offset(GestureTemplates.preview_points("latin_cross"), Vector2(wizard.center().x + facing * 70.0, wizard.global_position.y - 40.0), 0.8)
		"Insect Plague":  # an infinity sign, the wings of a bee, beside it: the swarm sets off from there
			return BrainStrokes.offset(GestureTemplates.preview_points("lungs"), wizard.center() + Vector2(facing * 50.0, -10.0), 0.7)
		"Scythe":  # a crescent drawn in front of the wizard
			return BrainStrokes.offset(GestureTemplates.preview_points("crescent"), wizard.center() + Vector2(facing * 40.0, 0.0), 0.8)
		"Thunderclap":  # a cloud and a bolt, drawn on itself
			return BrainStrokes.offset(GestureTemplates.preview_points("thunderclap"), wizard.center() + Vector2(0.0, -30.0), 0.8)
	return PackedVector2Array()


## A stroke turned by an angle, about its own origin.
func turned(points: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p.rotated(angle))
	return out


## A Tide Surf drawn toward one side: the wave runs the way the stroke runs.
func surf_stroke(side: float) -> PackedVector2Array:
	var wave := GestureTemplates.preview_points("swell")
	var out := PackedVector2Array()
	for p in wave:
		out.append(Vector2(p.x * (side if side != 0.0 else 1.0), p.y))
	return BrainStrokes.offset(out, wizard.center() + Vector2(side * 70.0, -10.0), 1.0)


## A stroke drawn the other way round, for a foe on the left.
func facing_flipped(points: PackedVector2Array, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * (side if side != 0.0 else 1.0), p.y))
	return out


## A Fire Breath cone with its point at the wizard and its mouth toward you, a little off when it is unskilled.
## It draws the cone longer when you are farther off, so the fire reaches you.
func breath_stroke(target: Vector2) -> PackedVector2Array:
	var gap: float = wizard.center().distance_to(target)
	var size := clampf(gap / 150.0, 1.0, 1.4)
	var aim: float = (target - wizard.center()).angle() + brain.rng.randfn(0.0, 0.2 * (1.0 - brain.skill))
	var tip: Vector2 = wizard.center() + Vector2.from_angle(aim) * 20.0
	var out := PackedVector2Array()
	for p in GestureTemplates.preview_points("cone"):
		out.append(tip + p.rotated(aim) * size)
	return BrainStrokes.densify(out)


## A Push: a circle round you, starting on its far side, then a line out of it pointing away from the wizard.
func push_stroke(around: Vector2, away: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start_angle := away.angle()
	for i in 33:
		pts.append(around + Vector2.from_angle(start_angle + TAU * i / 32.0) * 30.0)
	var exit := pts[pts.size() - 1]
	pts.append(exit + away * 90.0)
	return BrainStrokes.densify(pts)


## Starts the wizard drawing a spell's gesture. The spell happens when the drawing is done, if nothing breaks it.
func begin_cast(spell_name: String, stroke: PackedVector2Array, draw_time: float, sloppy := false) -> bool:
	if stroke.size() < 2 or wizard.silenced() or wizard.rage_time > 0.0:
		return false
	for point in stroke:
		if not point.is_finite():
			push_warning("a stroke for %s with a point that is not a number (%s): not drawn" % [spell_name, point])
			return false
	if brain.chant.is_typing():  # the chant box is open: a person closes it to draw, and the chant is lost
		brain.chant.close()
		return false
	if not drag_ok(spell_name, draw_time):  # the screen would drag the stroke out of shape: it stands still first, as a person learns to,
		stand_still()  # and draws it once it has stopped (see draw_when_still)
		pending = {"spell": spell_name, "stroke": stroke, "time": draw_time, "sloppy": sloppy, "from": wizard.global_position}
		return false
	var data: Spell = SpellData.SPELLS[spell_name]
	var mask: int = data.buttons
	var caster: Caster = wizard.caster
	draw_time = maxf(draw_time, BrainStrokes.quickest_stroke(spell_name))  # never quicker than people draw it
	if mask & (mask - 1) != 0:
		draw_time += brain.rng.randf_range(CHORD_GAP_MIN, CHORD_GAP_MAX)  # the buttons of a chord go down one after another, not in one instant
	return wizard.pen.begin(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void:
		caster.cast_stroke(mask, shaken(handed(points) if sloppy else points)), draw_time)


## Whether a stroke drawn now, over this long, keeps its shape: the view follows the wizard, so whatever way the wizard is going the stroke is dragged,
## and each spell's shape stands only so much of it (measured with the recognizer: tests/measure_drift.gd, ai/stroke_drift.json). A person learns
## which spells they can draw on the run; this is that knowledge.
func drag_ok(spell_name: String, draw_time: float) -> bool:
	var row: Dictionary = BrainStrokes.drift_table().get(spell_name, {})
	if not row.has("right"):
		return true  # a stroke that is read only in the world (a ceiling, water): not measured
	var slide := wizard.eyes.slide_over(draw_time, wizard.velocity, brain.drag_gravity())
	var allow_x: float = row["right"] if slide.x >= 0.0 else row["left"]
	var allow_y: float = row["down"] if slide.y >= 0.0 else row["up"]
	return absf(slide.x) <= allow_x * DRAG_MARGIN and absf(slide.y) <= allow_y * DRAG_MARGIN


## A stroke it has stopped to draw is drawn once it is still enough, where it meant it to be (moved with it, if it slid on while stopping);
## if it has not come to a stop in time, the moment has passed.
func draw_when_still() -> void:
	if pending.is_empty():
		return
	if hold_still <= 0.0 or wizard.pen.active():
		pending = {}
		return
	if not drag_ok(pending["spell"], pending["time"]):
		return
	var shift: Vector2 = wizard.global_position - pending["from"]
	var stroke := PackedVector2Array()
	for point: Vector2 in pending["stroke"]:
		stroke.append(point + shift)
	var spell_name: String = pending["spell"]
	var draw_time: float = pending["time"]
	var sloppy: bool = pending["sloppy"]
	pending = {}
	begin_cast(spell_name, stroke, draw_time, sloppy)


## A hand is not a template: the stroke wanders a little, as a stroke drawn with a mouse does. The hastier the wizard (the less skilled), the
## more it wanders. It never botches a stroke on purpose (owner, 2026-11-09: no made-up mistakes); a stroke goes wrong only as a person's does,
## from the view moving under it or the ground shaking. Only in a fight: the strokes it
## draws to cross a gate or to get on are drawn with care.
func handed(points: PackedVector2Array) -> PackedVector2Array:
	var wander := lerpf(5.0, 2.0, brain.skill)
	var phase_a := brain.rng.randf() * TAU
	var phase_b := brain.rng.randf() * TAU
	var squash := Vector2.ONE
	var turn := 0.0
	var middle := Vector2.ZERO
	for p in points:
		middle += p
	middle /= maxf(float(points.size()), 1.0)
	var out := PackedVector2Array()
	for i in points.size():
		var k := float(i) / maxf(float(points.size() - 1), 1.0)
		var off := Vector2(sin(k * 7.0 + phase_a), cos(k * 5.0 + phase_b)) * wander + Vector2(brain.rng.randf_range(-1.0, 1.0), brain.rng.randf_range(-1.0, 1.0)) * 0.8
		var rel := (points[i] - middle) * squash
		out.append(middle + rel.rotated(turn) + off)
	return out


## While its screen shakes (an earthquake, an eruption or an avalanche near it, a boulder landing, a thunderclap: whatever shakes a person's
## screen, see Eyes.shake), each point of the wizard's stroke is nudged by the shake, as a person's stroke is nudged by the shaking view.
func shaken(points: PackedVector2Array) -> PackedVector2Array:
	var px := wizard.eyes.shake_px() if wizard.eyes != null else 0.0
	if px < 0.5:
		return points
	var shaken := PackedVector2Array()
	for p in points:
		shaken.append(p + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px)
	return shaken


## The stroke of a spell it casts for itself.
func tend_stroke(spell_name: String, to_player: Vector2) -> PackedVector2Array:
	var dir := signf(to_player.x) if to_player.x != 0.0 else 1.0
	var here: Vector2 = wizard.center()
	var feet: Vector2 = wizard.global_position
	match spell_name:
		"Flare":
			return BrainStrokes.offset(GestureTemplates.preview_points("flare"), here + Vector2(0.0, -40.0), 0.6)
		"Glowcap":
			return BrainStrokes.offset(GestureTemplates.preview_points("circle"), here + Vector2(dir * 60.0, 0.0), 0.6)
		"Moonbeam":
			var at: Vector2 = brain.sight.seen_feet(brain.foe()) if brain.foe() != null else feet
			return BrainStrokes.line(Vector2(at.x, at.y - 70.0), Vector2(at.x, at.y + 10.0))
		"Adrenaline":
			return BrainStrokes.offset(GestureTemplates.preview_points("zigzag"), here, 0.6)
		"Wild Shape":
			return BrainStrokes.offset(GestureTemplates.preview_points("eclipse"), here, 0.9)
		"Hunter's Mark":
			return BrainStrokes.offset(GestureTemplates.preview_points("arrow"), here, 0.6)
		"Sneak":  # a wave deep enough not to be read as a flick, which is a Shadow Step on the same buttons
			var wave := PackedVector2Array()
			for i in 61:
				wave.append(here + Vector2(180.0 * i / 60.0 - 90.0, 28.0 * sin(TAU * 3.0 * i / 60.0)))
			return BrainStrokes.densify(wave)
		"Stone Wall":  # begun in the ground a step toward you, and drawn up and a little toward you
			var x := feet.x + dir * 70.0
			return BrainStrokes.line(Vector2(x, brain.ground_under(Vector2(x, feet.y)) + 4.0), Vector2(x + dir * 20.0, brain.ground_under(Vector2(x, feet.y)) - 90.0))
		"Smoke Screen":
			var middle := lerpf(feet.x, feet.x + to_player.x, 0.5)
			return BrainStrokes.offset(GestureTemplates.preview_points("smoke"), Vector2(middle, feet.y - 50.0), 0.9)
		"Decoy":
			return BrainStrokes.offset(GestureTemplates.preview_points("eight"), here + Vector2(-dir * 50.0, 0.0), 0.7)
		"Eclipse":
			return BrainStrokes.offset(GestureTemplates.preview_points("eclipse"), brain.sight.seen_center(brain.foe()), 1.0)
		"Crimson Veil":
			return BrainStrokes.line(Vector2(here.x, here.y - 50.0), Vector2(here.x, here.y + 20.0))
		"Obsidian Armor":
			return BrainStrokes.offset(GestureTemplates.preview_points("circle"), here, 0.8)
		"Featherfall":
			return BrainStrokes.offset(GestureTemplates.preview_points("feather"), here, 0.9)
	return PackedVector2Array()


## The stroke that makes a way over a pit of water, along the width of it at its surface: a wave for Frost Bridge, a row of loops for Lily Pads.
func bridge_stroke(spell_name: String, span: Rect2) -> PackedVector2Array:
	var level := span.position.y
	var out := PackedVector2Array()
	if spell_name == "Frost Bridge":
		var steps := 80
		for i in steps + 1:
			var x := span.size.x * i / steps
			out.append(Vector2(span.position.x + x, level + 14.0 * sin(x / 22.0)))
	else:
		var loops := maxi(roundi(span.size.x / 31.0), 2)  # small loops, two to a pad, so that the pad's height is the line's own
		var steps := loops * 16
		for i in steps + 1:
			var angle := TAU * loops * i / steps
			out.append(Vector2(span.position.x + span.size.x * i / steps - 10.0 * sin(angle), level - 8.0 - 10.0 * cos(angle)))
	return BrainStrokes.densify(out)


## The stroke of a spell that strikes a point.
func gate_stroke(spell_name: String, point: Vector2) -> PackedVector2Array:
	match spell_name:
		"Ignite", "Frostbolt":
			var start: Vector2 = wizard.center() + Vector2(signf(point.x - wizard.center().x) * 12.0, -6.0)
			return BrainStrokes.line(start, start + (point - start).normalized() * 90.0)
		"Faint":
			return BrainStrokes.offset(GestureTemplates.preview_points("spiral"), point, 0.5)
		"Fire Breath":
			return breath_stroke(point)
		"Stonefall":
			return BrainStrokes.offset(GestureTemplates.preview_points("stonefall"), Vector2(point.x, point.y - 130.0), 0.8)
		"Earthquake":
			return BrainStrokes.offset(GestureTemplates.preview_points("earthquake"), Vector2(point.x, point.y - 120.0), 1.0)
		"Firewall":  # a line up and then a line out over the place: a short wall
			var ground := brain.ground_under(point)
			return BrainStrokes.offset(GestureTemplates.preview_points("flame_wall"), Vector2(point.x - 40.0, ground - 50.0), 0.8)
		"Tornado":
			return BrainStrokes.offset(GestureTemplates.preview_points("tornado"), Vector2(point.x, brain.ground_under(point) - 90.0), 0.9)
		"Spark":
			return BrainStrokes.offset(GestureTemplates.preview_points("zigzag"), Vector2(point.x, point.y - 90.0), 1.0)
		"Gust":
			var from: Vector2 = wizard.center()
			var cloud := point  # the wind takes a cloud by its middle, which may lie off the point struck, down a slope
			var near := INF
			for node in brain.gates.gate_nodes():  # (untyped: it may be a freed object)
				if is_instance_valid(node) and not node.is_queued_for_deletion() and node.global_position.distance_to(from) < near:
					near = node.global_position.distance_to(from)
					cloud = node.global_position
			return BrainStrokes.line(from, from + (cloud - from).normalized() * 90.0)
	return PackedVector2Array()
