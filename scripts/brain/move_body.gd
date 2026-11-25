class_name MoveBody
extends RefCounted

## A wizard's body as the AI pictures it moving: where it is and how fast it goes, carried on a moment at a time by the laws the game moves the real one by (`Motion`), over ground it
## knows as tiles. Nothing here knows one spell from another: it is given their effects (`Spell.effect_of`). docs/handoff/23_movement_planning.md, section 2B.

const STEP := 1.0 / 60.0
const HALF := 11.0     # half the body's width
const TALL := 72.0     # and how much room it needs over the soles
const TILE := float(ArenaGen.TILE)

var at := Vector2.ZERO         # the soles
var speed_y := 0.0
var air_x := 0.0
var shove := Vector2.ZERO
var launched := false          # thrown or pulled: the keys can do less (Motion.steered)
var grounded := false
var fall_most := INF           # the fastest it falls (a state's)
var pace := Wizard.SPEED
var time := 0.0
var drive := {}                # a drive that is on, and when it began
var drive_from := 0.0
var lifts: Array[Dictionary] = []   # places of rising air: {"at": the foot of it, "lift": the effect}
var jets: Array[Dictionary] = []    # places that throw: {"at", "throw", "from", "to", "next"}
var map: MoveMap
var view := Vector2.INF   # where the middle of its screen has got to, following it: a stroke drawn while the view slides is dragged out of shape


func copy() -> MoveBody:
	var other := MoveBody.new()
	other.at = at
	other.speed_y = speed_y
	other.air_x = air_x
	other.shove = shove
	other.launched = launched
	other.grounded = grounded
	other.fall_most = fall_most
	other.pace = pace
	other.time = time
	other.drive = drive
	other.drive_from = drive_from
	other.lifts = lifts
	for jet in jets:
		other.jets.append(jet.duplicate())
	other.map = map
	other.view = view
	return other


## The view follows it for this long.
func look(seconds: float) -> void:
	if view == Vector2.INF:
		view = at
	view += (at - view) * (1.0 - exp(-Eyes.SMOOTHING * seconds))


## It jumps, with this share of a jump.
func jump(share := 1.0) -> void:
	speed_y = Wizard.JUMP_VELOCITY * share
	grounded = false


## A drive takes hold of it.
func driven(effect: Dictionary) -> void:
	drive = effect
	drive_from = time


## It is thrown.
func thrown(impulse: Vector2) -> void:
	shove = impulse
	launched = true


## It is carried along a line at once, as far as rock lets it, and hangs where it ends for a moment, still.
func carried(way: Vector2, far: float) -> void:
	if view == Vector2.INF:
		view = at
	var end := at + way * far
	var ray := Vector2(0.0, -20.0)
	var steps := maxi(1, int(far / 6.0))
	for k in range(1, steps + 1):
		if map.solid_at(at.lerp(end, float(k) / steps) + ray):
			end = at.lerp(end, float(k) / steps) - way * 16.0
			break
	var back := maxi(1, int(at.distance_to(end) / 8.0))
	var to := at
	for k in range(back, -1, -1):
		var spot := at.lerp(end, float(k) / back)
		if not (map.solid_at(spot + Vector2(0.0, -4.0)) or map.solid_at(spot + Vector2(0.0, -36.0)) or map.solid_at(spot + Vector2(0.0, -70.0))):
			to = spot
			break
	at = to
	speed_y = 0.0
	air_x = 0.0  # (a body that stood has its feet under it for a moment yet, as the game has it: `grounded` is found out by the next move)


## Flies on by itself (no drive, lift or jet at work), holding this way, until it lands or this time comes. True when it landed. The same laws as `tick`, written out in one loop,
## since thousands of these are thought through; the ground is looked at only when the body comes to other tiles.
func fly(dir: float, until: float) -> bool:
	var solid := map.grid
	var width := map.width
	var height := map.height
	var left_x := float(map.origin.x) * TILE
	var top_y := float(map.origin.y) * TILE
	var x := at.x - left_x
	var y := at.y - top_y
	var vy := speed_y
	var ax := air_x
	var wanted := dir * pace
	var g := map.gravity * STEP
	var thrown_y := shove.y
	var thrown_x := shove.x
	var old_side := -1
	var old_head := -1
	var old_foot := -1
	var landed := false
	var first := grounded
	while time < until:
		time += STEP
		if first:
			ax = wanted
		else:
			vy = minf(vy + g, fall_most)
			if not launched:
				ax = move_toward(ax, wanted, Wizard.AIR_OWN_ACCEL * STEP)
			else:
				ax = Motion.steered(ax, wanted, true, STEP)
		if thrown_y < 0.0:
			vy = minf(vy, thrown_y)
			thrown_y = move_toward(thrown_y, 0.0, Wizard.SHOVE_SHED * STEP)
		var vx := ax + thrown_x
		if thrown_x != 0.0:
			thrown_x = move_toward(thrown_x, 0.0, Wizard.AIR_DRAG * STEP)
		first = false
		# across
		if vx != 0.0:
			var nx := x + vx * STEP
			var side := int((nx + (HALF if vx > 0.0 else -HALF)) / TILE) if nx > HALF else -1
			var head := int((y - TALL) / TILE) if y > TALL else 0
			var foot := int((y - 3.0) / TILE) if y > 3.0 else 0
			if side < 0 or side >= width:
				nx = x
				ax = 0.0
				thrown_x = 0.0
			elif side != old_side or head != old_head or foot != old_foot:
				var hit := false
				for r in range(head, mini(foot, height - 1) + 1):
					if solid[r * width + side] != 0:
						hit = true
						break
				if hit:
					nx = x
					ax = 0.0
					thrown_x = 0.0
					old_side = -1
				else:
					old_side = side
					old_head = head
					old_foot = foot
			x = nx
		# up or down
		var ny := y + vy * STEP
		var c0 := maxi(int((x - HALF + 2.0) / TILE), 0)
		var c1 := mini(int((x + HALF - 2.0) / TILE), width - 1)
		if vy < 0.0:
			var r := int((ny - TALL) / TILE) if ny > TALL else -1
			if r >= 0 and r < height and (solid[r * width + c0] != 0 or solid[r * width + c1] != 0):
				ny = float(r + 1) * TILE + TALL
				vy = 0.0
		elif ny + 0.5 > 0.0:
			var r := int((ny + 0.5) / TILE)
			if r >= height:
				y = ny
				break
			if solid[r * width + c0] != 0 or solid[r * width + c1] != 0:
				y = float(r) * TILE
				vy = 0.0
				landed = true
				break
		y = ny
	at = Vector2(x + left_x, y + top_y)
	speed_y = vy
	air_x = ax
	shove = Vector2(thrown_x, thrown_y)
	grounded = landed
	if landed:
		launched = false
	return landed


## One moment passes, with the keys asking to go this way (-1, 0 or 1).
func tick(dir: float) -> void:
	time += STEP
	var stood := grounded  # (it finds out that it has left the ground by moving: until then its feet are under it)
	if not grounded:
		speed_y = Motion.fallen(speed_y, map.gravity, STEP, fall_most)
	if not drive.is_empty():
		if time - drive_from <= float(drive["for"]):
			speed_y = -Motion.drive_speed(drive, time - drive_from)
			grounded = false
		else:
			drive = {}
	for place in lifts:
		var lift: Dictionary = place["lift"]
		var off := at + Vector2(0.0, -Wizard.BODY_HEIGHT * 0.5) - (place["at"] as Vector2)
		if absf(off.x) <= float(lift["wide"]) * 0.5 and off.y <= 30.0 and off.y >= -float(lift["high"]):
			speed_y = Motion.lifted(lift, speed_y, STEP)
			grounded = false
	for jet in jets:
		if time < jet["next"] or time < jet["from"] or time > jet["to"]:
			continue
		var throw: Dictionary = jet["throw"]
		var off := at + Vector2(0.0, -Wizard.BODY_HEIGHT * 0.5) - (jet["at"] as Vector2)
		if absf(off.x) <= float(throw.get("wide", 40.0)) * 0.5 + 8.0 and off.y <= 30.0 and off.y >= -float(throw.get("high", 60.0)):
			thrown(Motion.thrown(throw, jet["way"]))
			jet["next"] = time + float(throw["every"]) if throw.has("every") else INF
	if stood:
		air_x = dir * pace
	else:
		air_x = Motion.steered(air_x, dir * pace, launched, STEP)
	if shove.y < 0.0:
		speed_y = minf(speed_y, shove.y)
		grounded = false
	var across := air_x + shove.x
	shove = Motion.shed(shove, not grounded, STEP)
	_move(Vector2(across * STEP, speed_y * STEP))


func _move(by: Vector2) -> void:
	if by.x != 0.0:
		var x := at.x + by.x
		var side := x + signf(by.x) * HALF
		if map.solid_span(side, at.y - TALL, at.y - 3.0):
			var column := floorf(side / TILE)
			x = column * TILE - HALF - 0.1 if by.x > 0.0 else (column + 1.0) * TILE + HALF + 0.1
			air_x = 0.0
			shove.x = 0.0
		at.x = x
	var y := at.y + by.y
	if by.y < 0.0:
		grounded = false
		if map.solid_row(at.x - HALF + 2.0, at.x + HALF - 2.0, y - TALL):
			y = (floorf((y - TALL) / TILE) + 1.0) * TILE + TALL
			speed_y = 0.0
			drive = {}
		at.y = y
	else:
		var hit := map.solid_row(at.x - HALF + 2.0, at.x + HALF - 2.0, y + 0.5)
		if hit:
			at.y = floorf((y + 0.5) / TILE) * TILE
			speed_y = 0.0
			grounded = true
			launched = false
		else:
			at.y = y
			grounded = false


## Forgets what can no longer move it, going this way: air it has left behind, jets that are over.
func leave_behind(dir: float) -> void:
	for k in range(lifts.size() - 1, -1, -1):
		var off: float = at.x - (lifts[k]["at"] as Vector2).x
		if dir != 0.0 and off * dir > float(lifts[k]["lift"]["wide"]) * 0.5:
			lifts = lifts.duplicate()
			lifts.remove_at(k)
	for k in range(jets.size() - 1, -1, -1):
		var off: float = at.x - (jets[k]["at"] as Vector2).x
		if time > jets[k]["to"] or (dir != 0.0 and off * dir > float(jets[k]["throw"].get("wide", 40.0)) * 0.5 + 8.0):
			jets.remove_at(k)


## The tile it stands on, or hangs in.
func tile() -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori((at.y - 1.0) / TILE))
