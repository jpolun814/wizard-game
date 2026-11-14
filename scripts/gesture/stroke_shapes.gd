class_name StrokeShapes
extends RefCounted

## The named shapes that are read from the stroke itself, since the recognizer cannot tell them apart reliably: a ring with a line out of it, a V, a coil, a
## feather, a cloud, a cross. Each detector takes the stroke (as points relative to where it began) and says whether it is that shape and what it measured.

const ICICLE_TURN := 30.0  # a stroke must zig or zag this far vertically to count as a V tip
const ICICLE_BACK := 0.22  # and a row of them may go back across at most this share of its width
const WAVE_TILT := 60.0  # how far a wave may be turned from the template (degrees) and still be a wave


## Where a stroke that goes around a closed loop, then runs straight on, leaves the loop.
## Returns the index of the first point of that straight line, or -1 when the stroke is not a ring with a line.
static func ring_then_line_split(points: PackedVector2Array) -> int:
	var walked := 0.0
	var closed_at := -1
	for i in range(1, points.size()):
		walked += points[i].distance_to(points[i - 1])
		if walked > 150.0 and points[i].distance_to(points[0]) < 20.0:
			closed_at = i
			break
	if closed_at < 0:
		return -1
	# The line leaves from the last point still near the start, which skips the little arc past the closing.
	var split := closed_at
	for k in range(closed_at, points.size()):
		if points[k].distance_to(points[0]) < 20.0:
			split = k
	var tail := points.slice(split)
	var chord := tail[tail.size() - 1].distance_to(tail[0])
	if chord >= 30.0 and StrokeMeasure.max_deviation(tail) <= chord * 0.15 + 4.0:
		return split
	return -1


static func loop_end(points: PackedVector2Array, least_walk: float) -> int:
	var walked := 0.0
	var closed_at := -1
	for i in range(1, points.size()):
		walked += points[i].distance_to(points[i - 1])
		if walked > least_walk and points[i].distance_to(points[0]) < 20.0:
			closed_at = i
			break
	if closed_at < 0:
		return -1
	var split := closed_at
	for k in range(closed_at, points.size()):
		if points[k].distance_to(points[0]) < 20.0:
			split = k
	return split


## Thunderclap: a cloud and a bolt out of it. A closed loop, then, from where it began, a zigzag that runs down: a line that bends back and forth
## across its way at least twice, and ends well below where it began. A straight line out of the ring is a Push, and a bend or two with a level
## cloud is a Hailstorm.
static func is_thunderclap(points: PackedVector2Array) -> bool:
	var split := loop_end(points, 100.0)
	if split < 0:
		return false
	var ring := points.slice(0, split)
	if StrokeMeasure.mean_distance(ring, StrokeMeasure.centroid(ring)) < 15.0:
		return false
	var tail := points.slice(split)
	if tail.size() < 6:
		return false
	var drop := tail[tail.size() - 1].y - tail[0].y
	if drop < 40.0:
		return false  # the bolt falls
	var width := GestureTemplates.bounds(tail).size.x
	if width < 14.0 or width > drop * 1.1:
		return false  # it is a zigzag, not a straight line, and not a sweep across
	return turning_points(tail, 0, clampf(width * 0.3, 7.0, 14.0)).size() >= 2


## Hailstorm: a ring, then a line out from it that runs level or nearly so, then a line down from the end of that. Returns {"from": the ring's middle,
## "to": the bend, where the cloud ends} (in the stroke's own coordinates), or {} when the stroke is not one.
static func hailstorm(points: PackedVector2Array) -> Dictionary:
	var split := loop_end(points, 100.0)
	if split < 0:
		return {}
	var ring := points.slice(0, split)
	var centre := StrokeMeasure.centroid(ring)
	if StrokeMeasure.mean_distance(ring, centre) < 12.0:
		return {}
	var tail := points.slice(split)
	if tail.size() < 6:
		return {}
	var first := tail[0]
	var last := tail[tail.size() - 1]
	var bend := -1
	var farthest := 0.0
	for i in range(1, tail.size() - 1):
		var away := Geometry2D.get_closest_point_to_segment(tail[i], first, last).distance_to(tail[i])
		if away > farthest:
			farthest = away
			bend = i
	if bend < 0:
		return {}
	var corner := tail[bend]
	var out := corner - first
	var down := last - corner
	if out.length() < 40.0 or down.length() < 30.0:
		return {}
	if StrokeMeasure.max_deviation(tail.slice(0, bend + 1)) > out.length() * 0.15 + 4.0 or StrokeMeasure.max_deviation(tail.slice(bend)) > down.length() * 0.15 + 4.0:
		return {}
	if absf(out.y) > absf(out.x) * 1.2:  # the cloud runs level, or near it
		return {}
	if down.y <= 0.0 or absf(down.x) > down.y * 0.6:  # and the hail falls down
		return {}
	return {"from": centre, "to": corner}


## Featherfall: a feather drifting down. Three sweeps across, one after the other (left to right, back, and again), each bent down in the middle
## like a falling feather's path, and each ending lower than it began. A straight zigzag is not one, and neither is a ring or a flick.
## Returns {} when the stroke is not one.
static func feather(points: PackedVector2Array) -> Dictionary:
	var box := GestureTemplates.bounds(points)
	var width := box.size.x
	if width < 50.0 or box.size.y > width * 1.4:
		return {}
	var turns := turning_points(points, 0, width * 0.22)
	if turns.size() != 2:
		return {}
	var ends := [0, int(turns[0][0]), int(turns[1][0]), points.size() - 1]
	for k in 3:
		var a := points[ends[k]]
		var b := points[ends[k + 1]]
		var span := absf(b.x - a.x)
		if span < width * 0.5 or b.y < a.y - width * 0.05:
			return {}  # each sweep goes right across, and ends lower than it began
		var sag := 0.0
		var sag_at := 0.5
		for i in range(ends[k], ends[k + 1] + 1):
			var along := (points[i].x - a.x) / (b.x - a.x)
			var below := points[i].y - lerpf(a.y, b.y, along)
			if below > sag:
				sag = below
				sag_at = float(i - ends[k]) / float(maxi(ends[k + 1] - ends[k], 1))
		if sag < span * 0.07 or sag_at < 0.2 or sag_at > 0.8:
			return {}  # and bellies downward in the middle
	return {"axis": points[points.size() - 1] - points[0]}


## Mirage: a box taller than it is wide, closed on itself, with four sharp corners and straight sides. A circle or an oval is not one (no corners), and
## neither is a box lying on its side.
static func is_portrait_box(drawn: PackedVector2Array) -> bool:
	# A hand that is not quite square to the page draws a box that leans a little: turn it upright, by whichever turn makes the snuggest box.
	var points := drawn
	var tightest := INF
	for step in range(-6, 7):
		var turned := PackedVector2Array()
		for p in drawn:
			turned.append(p.rotated(deg_to_rad(3.0 * step)))
		var size := GestureTemplates.bounds(turned).size
		if size.x * size.y < tightest:
			tightest = size.x * size.y
			points = turned
	var box := GestureTemplates.bounds(points)
	var width := box.size.x
	var height := box.size.y
	if width < 30.0 or height < width * 1.2 or height > width * 3.4:
		return false
	if points[0].distance_to(points[points.size() - 1]) > 0.3 * height:
		return false  # it must close
	var walked := 0.0
	for i in range(1, points.size()):
		walked += points[i].distance_to(points[i - 1])
	if walked < 2.0 * (width + height) * 0.9 or walked > 2.0 * (width + height) * 1.4:
		return false
	var near := 0.14 * width + 5.0
	for corner in [box.position, box.position + Vector2(width, 0.0), box.position + Vector2(0.0, height), box.end]:
		var covered := false
		for p in points:
			if p.distance_to(corner) < near + 0.04 * width:
				covered = true
				break
		if not covered:
			return false  # a round shape leaves the corners empty
	var off_edge := 0
	for p in points:
		var from_edge := minf(minf(p.x - box.position.x, box.end.x - p.x), minf(p.y - box.position.y, box.end.y - p.y))
		if from_edge > near:
			off_edge += 1
	return off_edge <= points.size() / 10  # and the stroke runs along the edges


## Raise Dead: a cross. One long upright stem and a shorter bar across it, nearer the top than the middle, as on a grave. It may be drawn in any order of
## strokes, so this looks at where the ink lies rather than the way it ran: a column of ink down most of the height, a row of it across most of the width,
## and hardly any anywhere else. A plus (the bar in the middle), a T (the bar at the very top) and an X do not pass.
static func is_cross(points: PackedVector2Array) -> bool:
	for turn in [0.0, 0.12, -0.12, 0.24, -0.24, 0.36, -0.36]:  # a cross drawn leaning is turned upright before it is read
		var upright := PackedVector2Array()
		for p in points:
			upright.append(p.rotated(turn))
		if is_upright_cross(upright):
			return true
	return false


static func is_upright_cross(points: PackedVector2Array) -> bool:
	var box := GestureTemplates.bounds(points)
	if box.size.x < 24.0 or box.size.y < 40.0:
		return false
	var ratio := box.size.y / box.size.x
	if ratio < 1.1 or ratio > 2.8:
		return false
	const N := 20
	var cells := {}
	var step := maxf(1.0, box.size.y / 90.0)
	for i in points.size() - 1:
		var span := points[i].distance_to(points[i + 1])
		var pieces := maxi(1, ceili(span / step))
		for k in pieces + 1:
			var p := points[i].lerp(points[i + 1], float(k) / pieces)
			var col := clampi(int((p.x - box.position.x) / box.size.x * N), 0, N - 1)
			var row := clampi(int((p.y - box.position.y) / box.size.y * N), 0, N - 1)
			cells[Vector2i(col, row)] = true
	var col_rows := PackedInt32Array()
	var row_cols := PackedInt32Array()
	col_rows.resize(N)
	row_cols.resize(N)
	for cell: Vector2i in cells:
		col_rows[cell.x] += 1
		row_cols[cell.y] += 1
	# The stem is the column (with a neighbour either side for a wobble) that reaches down the most rows; the bar is the row that reaches across the most columns.
	var stem := 0
	var best := -1
	for c in range(1, N - 1):
		var reach := 0
		for r in N:
			if cells.has(Vector2i(c - 1, r)) or cells.has(Vector2i(c, r)) or cells.has(Vector2i(c + 1, r)):
				reach += 1
		if reach > best:
			best = reach
			stem = c
	if best < int(N * 0.8) or stem < int(N * 0.3) or stem > int(N * 0.7):
		return false
	best = 0
	for r in range(1, N - 1):  # (a bar drawn on a slant lies across a few rows, so a row counts its neighbours too)
		var across := 0
		for c in N:
			if cells.has(Vector2i(c, r - 1)) or cells.has(Vector2i(c, r)) or cells.has(Vector2i(c, r + 1)):
				across += 1
		best = maxi(best, across)
	if best < int(N * 0.7):
		return false
	best = 0
	for r in N:
		best = maxi(best, row_cols[r])
	var bar_sum := 0.0
	var bar_rows := 0
	for r in N:
		if row_cols[r] >= int(best * 0.8):  # the rows the bar lies on, however thick the line was drawn
			bar_sum += r
			bar_rows += 1
	var bar := int(roundf(bar_sum / bar_rows))
	if bar < int(N * 0.12) or bar > int(N * 0.45):
		return false
	var stray := 0
	for cell: Vector2i in cells:
		if absi(cell.x - stem) > 2 and absi(cell.y - bar) > 2:
			stray += 1
	return stray <= cells.size() / 6


## Silence: a ring with a slash through it, as on a "do not enter" sign. The ring closes on itself, and a straight line then runs from it right
## across the middle and out the far side. A line that stops at the middle makes a spiral instead, which is why this is read before a Black Hole.
static func is_slashed_ring(points: PackedVector2Array) -> bool:
	var split := ring_then_line_split(points)
	if split < 0:
		return false
	var ring := points.slice(0, split)
	var centre := StrokeMeasure.centroid(ring)
	var radius := StrokeMeasure.mean_distance(ring, centre)
	var tail := points.slice(split)
	var tip := tail[tail.size() - 1]
	var line := Geometry2D.get_closest_point_to_segment(centre, tail[0], tip)
	return radius > 12.0 and tail[0].distance_to(tip) >= radius * 1.4 and line.distance_to(centre) <= radius * 0.5


## A cone drawn as <: two straight arms of similar length meeting at a point. Returns {"aim": the way from the
## point out through the open end, "spread": the angle between the arms, "reach": how far the fire goes}, or {} when
## the stroke isn't one. A closed triangle (a volcano) or a hooked line is not a cone.
static func cone(points: PackedVector2Array) -> Dictionary:
	if points.size() < 6:
		return {}
	var a := points[0]
	var b := points[points.size() - 1]
	var tip_index := -1
	var farthest := 0.0
	for i in range(1, points.size() - 1):
		var away := Geometry2D.get_closest_point_to_segment(points[i], a, b).distance_to(points[i])
		if away > farthest:
			farthest = away
			tip_index = i
	if tip_index < 0:
		return {}
	var tip := points[tip_index]
	var first := a.distance_to(tip)
	var second := b.distance_to(tip)
	var shorter := minf(first, second)
	if shorter < 25.0 or maxf(first, second) > shorter * 2.5 or a.distance_to(b) < shorter * 0.25:
		return {}
	if StrokeMeasure.max_deviation(points.slice(0, tip_index + 1)) > maxf(6.0, first * 0.16):
		return {}
	if StrokeMeasure.max_deviation(points.slice(tip_index)) > maxf(6.0, second * 0.16):
		return {}
	var spread := absf(angle_difference((a - tip).angle(), (b - tip).angle()))
	if spread < deg_to_rad(18.0) or spread > deg_to_rad(120.0):
		return {}
	return {"aim": ((a + b) * 0.5 - tip).angle(), "spread": spread, "reach": first + second}


## A line up and then a line out to either side, each straight: returns where it began, where it turned and where it ended, or nothing.
static func up_and_out(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 6:
		return PackedVector2Array()
	var a := points[0]
	var b := points[points.size() - 1]
	var chord := b - a
	if chord.length() < 40.0:
		return PackedVector2Array()
	var corner := 0
	var far := 0.0
	for i in points.size():
		var away := absf(chord.cross(points[i] - a)) / chord.length()
		if away > far:
			far = away
			corner = i
	var up := points.slice(0, corner + 1)
	var out := points.slice(corner)
	if up.size() < 2 or out.size() < 2:
		return PackedVector2Array()
	var rise := points[corner] - a
	var run := b - points[corner]
	if rise.length() < 30.0 or run.length() < 30.0:
		return PackedVector2Array()
	if rise.y >= 0.0 or absf(rise.x) > absf(rise.y) * 0.55:
		return PackedVector2Array()  # the first line goes up
	if absf(run.y) > absf(run.x) * 0.55:
		return PackedVector2Array()  # and the second goes out, level
	if StrokeMeasure.max_deviation(up) > rise.length() * 0.2 or StrokeMeasure.max_deviation(out) > run.length() * 0.2:
		return PackedVector2Array()  # and each is straight
	return PackedVector2Array([a, points[corner], b])


## How close a stroke is to the spell's own picture, from 0 to 1. Shapes the recognizer matched report its score; shapes
## read by a detector are judged against the spellbook's drawing of them, the same way. 0.95 and above is a perfect cast.
static func accuracy(points: PackedVector2Array, gesture: String, score: float) -> float:
	var picture := GestureTemplates.preview_points(gesture)
	if picture.size() < 2:
		return score if score < 1.0 else 0.0
	var judge := UnistrokeRecognizer.new()
	judge.add_template("shape", picture)
	return judge.recognize(points).score


## One or more Vs (point down) in a stroke; upside-down Vs do not count. Each tip is one icicle, and its triangle is
## the space between the tip and the two arm ends. Returns the triangles in stroke space.
static func icicle_triangles(points: PackedVector2Array, want_bottoms := true) -> Array:
	var turns := turning_points(points)
	var triangles: Array = []
	if turns.is_empty() or not goes_one_way(points, turns):
		return triangles
	# want_bottoms: only Vs for icicles, which hang down; only upside-down Vs (peaks) for stalagmites, which stand up
	for k in turns.size():
		var turn: Array = turns[k]
		if turn[1] != want_bottoms:
			continue
		# An arm ends at the nearest opposite turn on its side, or at the end of the stroke.
		var left := points[0]
		for j in range(k - 1, -1, -1):
			if turns[j][1] != want_bottoms:
				left = points[turns[j][0]]
				break
		var right := points[points.size() - 1]
		for j in range(k + 1, turns.size()):
			if turns[j][1] != want_bottoms:
				right = points[turns[j][0]]
				break
		var apex: Vector2 = points[turn[0]]
		if (left - apex).normalized().dot((right - apex).normalized()) < cos(deg_to_rad(50.0)):
			continue  # an apex wider than 50 degrees is a triangle, not an icicle
		triangles.append(PackedVector2Array([left, apex, right]))
	return triangles


## True when a stroke's turns move on across in one direction, never back over themselves, as a row of icicles does. A star drawn in one
## stroke zigzags up and down just as a row of Vs does, but it doubles back across itself, so it is not a row.
static func goes_one_way(points: PackedVector2Array, turns: Array) -> bool:
	var direction := signf(points[points.size() - 1].x - points[0].x)
	if direction == 0.0:
		return false  # it ends where it began: a loop, not a row
	var back_most := ICICLE_BACK * StrokeMeasure.extent(points).x + 3.0  # a little give: a hand drifts back a pixel or two
	var along: Array[float] = [points[0].x]
	for turn: Array in turns:
		along.append(points[turn[0]].x)
	along.append(points[points.size() - 1].x)
	for k in along.size() - 1:
		if (along[k + 1] - along[k]) * direction < -back_most:
			return false
	return true


## Where a stroke turns vertically by a real amount. Each entry is [point index, true for a bottom
## (lowest on screen) or false for a top].
static func turning_points(points: PackedVector2Array, axis := 1, threshold := ICICLE_TURN) -> Array:
	var turns: Array = []
	var ext := 0
	var state := 0  # 1 going down the screen, -1 going up, 0 not decided yet
	for i in range(1, points.size()):
		var y: float = points[i][axis]
		var ext_y: float = points[ext][axis]
		if state == 0:
			if y > ext_y + threshold:
				state = 1
				ext = i
			elif y < ext_y - threshold:
				state = -1
				ext = i
		elif state == 1:
			if y > ext_y:
				ext = i
			elif ext_y - y > threshold:
				turns.append([ext, true])
				state = -1
				ext = i
		else:
			if y < ext_y:
				ext = i
			elif y - ext_y > threshold:
				turns.append([ext, false])
				state = 1
				ext = i
	return turns


## Snowfall: a stroke that crosses itself at least four times (a five-pointed star drawn in one go), then
## runs on level. Returns the level part, in stroke space, or nothing.
static func snowfall_line(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3 or StrokeMeasure.count_crossings(points) < 4:
		return PackedVector2Array()
	# The level line is the run at the end of the stroke that stays close to the height it finishes at.
	var end_y := points[points.size() - 1].y
	var start := points.size() - 1
	while start > 0 and absf(points[start - 1].y - end_y) <= 18.0:
		start -= 1
	var line := points.slice(start)
	if line.size() < 2 or absf(line[line.size() - 1].x - line[0].x) < 40.0:
		return PackedVector2Array()
	return line


## Black Hole: a spiral wound inward, turning very nearly twice round while it closes in on its middle, a little tighter each time. A ring, a ring
## and a line, a loop and a half, or two rings of the same size are not one. Returns {"center", "reach"} in stroke space, or nothing.
static func inward_spiral(points: PackedVector2Array) -> Dictionary:
	if points.size() < 16 or absf(StrokeMeasure.total_turning(points)) < deg_to_rad(650.0):
		return {}
	# The middle is where the stroke ends up: the average of its last few points.
	var tail := points.slice(int(points.size() * 0.85))
	var centre := StrokeMeasure.centroid(tail)
	var reach := points[0].distance_to(centre)
	if reach < 30.0:
		return {}
	# Its distance from the middle must fall away: on average the second half is a good deal nearer than the first, and the last third than the
	# first third. (Averages, since a hand-drawn spiral is never an even one.) It must also begin on the outside, not the middle of an outward one.
	var third := points.size() / 3
	var half := points.size() / 2
	if StrokeMeasure.mean_distance(points.slice(half), centre) > StrokeMeasure.mean_distance(points.slice(0, half), centre) * 0.75:
		return {}
	if StrokeMeasure.mean_distance(points.slice(points.size() - third), centre) > StrokeMeasure.mean_distance(points.slice(0, third), centre) * 0.62:
		return {}
	return {"center": centre, "reach": reach}


## Storm Cloud: the bumpy top of a cloud, drawn across. Wide and low, always moving the same way across, with at
## least two bumps. Returns the stroke, or nothing.
static func cloud_line(points: PackedVector2Array) -> PackedVector2Array:
	var size := StrokeMeasure.extent(points)
	if size.x < 70.0 or size.x < size.y * 2.0 or size.y < 10.0:
		return PackedVector2Array()
	if not turning_points(points, 0, 14.0).is_empty():
		return PackedVector2Array()  # it doubles back across: a zigzag, not a cloud
	if turning_points(points, 1, 8.0).size() < 3:
		return PackedVector2Array()
	return points


## Mudslide: a U, down one side and up the other, with both ends well above its bottom. Returns the stroke, or
## nothing.
static func pit_stroke(points: PackedVector2Array) -> PackedVector2Array:
	var turns := turning_points(points)
	if turns.size() != 1 or not turns[0][1]:
		return PackedVector2Array()
	var bottom: Vector2 = points[turns[0][0]]
	var first := points[0]
	var last := points[points.size() - 1]
	if bottom.y - first.y < 25.0 or bottom.y - last.y < 25.0 or absf(last.x - first.x) < 40.0:
		return PackedVector2Array()
	if bottom.x < minf(first.x, last.x) or bottom.x > maxf(first.x, last.x):
		return PackedVector2Array()  # the bottom must lie between the two ends
	return points


## Smoke Screen: a wavy line going up. It climbs at least 70 px and sways side to side at least three times.
static func rising_wave(points: PackedVector2Array) -> PackedVector2Array:
	var rise := points[0].y - points[points.size() - 1].y
	if rise < 70.0 or turning_points(points, 0, 8.0).size() < 3:
		return PackedVector2Array()
	var climbing := 0
	for i in range(1, points.size()):
		if points[i].y <= points[i - 1].y + 0.5:
			climbing += 1
	if climbing < 0.6 * (points.size() - 1) or StrokeMeasure.extent(points).x > rise:
		return PackedVector2Array()
	return points


## What a stroke that starts by going up and then curls over looks like, whatever its size: which way it set off, how
## tall and wide it is, how far it turns (in degrees), and whether it ends by touching its own path again (a loop).
## A tree (a trunk that ends in a crown) is this kind of stroke.
static func stem_and_arc(points: PackedVector2Array) -> Dictionary:
	if points.size() < 12:
		return {}
	var first := 1
	while first < points.size() - 1 and points[0].distance_to(points[first]) < 16.0:
		first += 1
	var extent := StrokeMeasure.extent(points)
	var top := points[0].y
	for p in points:
		top = minf(top, p.y)
	return {
		"dir": (points[first] - points[0]).normalized(), "extent": extent, "rise": points[0].y - top,
		"ratio": extent.x / maxf(extent.y, 1.0), "turn": rad_to_deg(absf(StrokeMeasure.total_turning(points, 16.0))),
		"looped": touches_earlier(points),
	}


## True when a stroke ends on a point it passed earlier, so it has drawn a loop that closes.
static func touches_earlier(points: PackedVector2Array) -> bool:
	var end := points[points.size() - 1]
	var walked := 0.0
	var cut := points.size() - 1
	while cut > 0 and walked < 40.0:
		walked += points[cut].distance_to(points[cut - 1])
		cut -= 1
	for i in cut:
		if points[i].distance_to(end) < 14.0:
			return true
	return false


## Which spell a stroke that sets off upward is, among the ones this button can cast: a trunk that ends in a closed loop
## is a tree. "" when it is none.
static func stem_gesture(stem: Dictionary, options: Dictionary) -> String:
	if stem["dir"].dot(Vector2.UP) < cos(deg_to_rad(35.0)) or stem["rise"] < 40.0:
		return ""
	var turn: float = stem["turn"]
	var extent: Vector2 = stem["extent"]
	if options.has("tree") and stem["looped"] and turn >= 180.0 and extent.x >= 36.0:
		return "tree"
	return ""


## The "swell" shape (Tide Surf, Leech, Thorn Whip): a big wave, a long rise to a crest that curls over. Returns {"aim": the way the wave runs, which is the
## way the crest curls}, or {} when the stroke is not a wave. A sharp corner (a V) is not a curl.
static func swell(drawn: PackedVector2Array) -> Dictionary:
	if drawn.size() < 20:
		return {}
	# The wave is read the way the template lies: drawn toward the left it is the mirror of one drawn toward the right, and turned until the way it
	# goes (from where it starts to the point farthest from it) is the way the template goes. A whip is aimed at whatever it is to drag in, up a
	# slope or down it, so the wave may be tilted either way.
	var far := drawn[0]
	for p in drawn:
		if p.distance_squared_to(drawn[0]) > far.distance_squared_to(drawn[0]):
			far = p
	var leftward := far.x < drawn[0].x
	var points := PackedVector2Array()
	for p in drawn:
		var q := p - drawn[0]
		points.append(Vector2(-q.x, q.y) if leftward else q)
	var heading := Vector2(-(far - drawn[0]).x if leftward else (far - drawn[0]).x, (far - drawn[0]).y).angle()
	var turn := wrapf(heading - wave_heading(), -PI, PI)
	if absf(turn) > deg_to_rad(WAVE_TILT):
		return {}
	for k in points.size():
		points[k] = points[k].rotated(-turn)
	var extent := StrokeMeasure.extent(points)
	if extent.x < 110.0 or extent.y < 40.0 or points[0].distance_to(points[points.size() - 1]) < 0.3 * extent.x:
		return {}
	var crest := points[0]
	for p in points:
		if p.y < crest.y:
			crest = p
	var end := points[points.size() - 1]
	if points[0].y - crest.y < 40.0 or end.y - crest.y < 25.0:
		return {}
	if rad_to_deg(absf(StrokeMeasure.total_turning(points))) < 140.0 or sharpest_turn(points, 12.0) > deg_to_rad(70.0):
		return {}
	var peak := drawn[0]
	for p in drawn:
		if p.y < peak.y:
			peak = p
	return {"aim": 0.0 if peak.x > drawn[0].x else PI}  # (a Thorn Whip is aimed on its own, along the heading: see cast_stroke)


## The way the template wave goes, from its start to the point farthest from it: the heading a drawn wave is turned to match.
static func wave_heading() -> float:
	var shape := GestureTemplates.preview_points("swell")
	var far := shape[0]
	for p in shape:
		if p.distance_squared_to(shape[0]) > far.distance_squared_to(shape[0]):
			far = p
	return (far - shape[0]).angle()


## The sharpest turn a stroke makes within a short stretch of path, in radians: a corner scores high, a curve low.
static func sharpest_turn(points: PackedVector2Array, stretch: float) -> float:
	var worst := 0.0
	var i := 0
	while i < points.size() - 2:
		var j := i + 1
		while j < points.size() - 1 and points[i].distance_to(points[j]) < stretch:
			j += 1
		var k := j + 1
		while k < points.size() and points[j].distance_to(points[k]) < stretch:
			k += 1
		if k >= points.size():
			break
		worst = maxf(worst, absf((points[j] - points[i]).angle_to(points[k] - points[j])))
		i += 1
	return worst


## Tornado: a coil going down like a drill bit, at least a turn and a half, tall and narrow.
static func coil(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 20 or rad_to_deg(absf(StrokeMeasure.total_turning(points))) < 500.0:
		return PackedVector2Array()
	var extent := StrokeMeasure.extent(points)
	var down := points[points.size() - 1].y - points[0].y
	if down < 40.0 or extent.y < 1.2 * extent.x:
		return PackedVector2Array()
	return points


## Bramble: a low row of sharp thorns, a sawtooth line that keeps going the same way across.
static func sawtooth(points: PackedVector2Array) -> PackedVector2Array:
	var extent := StrokeMeasure.extent(points)
	if extent.x < 80.0 or extent.y > 0.5 * extent.x or extent.y < 10.0:
		return PackedVector2Array()
	if not turning_points(points, 0, 14.0).is_empty() or StrokeMeasure.count_crossings(points) > 0:
		return PackedVector2Array()  # it doubles back across itself: not a row of teeth
	if turning_points(points, 1, 8.0).size() < 3:  # two teeth are a row of them
		return PackedVector2Array()
	return points


## Flytrap: open jaws, a W (or an M) about as tall as it is wide, moving the same way across.
static func w_shape(points: PackedVector2Array) -> PackedVector2Array:
	var extent := StrokeMeasure.extent(points)
	if extent.x < 40.0 or extent.y < 50.0 or extent.y < 0.7 * extent.x or extent.y > 2.5 * extent.x:
		return PackedVector2Array()
	if not turning_points(points, 0, 14.0).is_empty():
		return PackedVector2Array()
	var turns := turning_points(points, 1, 20.0).size()
	if turns != 3 and turns != 4:
		return PackedVector2Array()
	return points


## Lily Pads: a pad drawn as a ring, then a line across, level, where the pads are to grow. Returns the line.
static func pad_line(points: PackedVector2Array) -> PackedVector2Array:
	var split := ring_then_line_split(points)
	if split < 0:
		return PackedVector2Array()
	var tail := points.slice(split)
	var across := tail[tail.size() - 1] - tail[0]
	if absf(across.x) < 60.0 or absf(across.y) > 0.45 * absf(across.x):
		return PackedVector2Array()
	return tail


## A flame is a loop that comes to a point, and the point is at the top: the top of the stroke is narrower than the
## bottom, however fat or thin the flame is.
static func flame_points_up(points: PackedVector2Array) -> bool:
	var top := INF
	var bottom := -INF
	for p in points:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var band := (bottom - top) * 0.25
	if band <= 0.0:
		return false
	var top_low := INF
	var top_high := -INF
	var bottom_low := INF
	var bottom_high := -INF
	for p in points:
		if p.y <= top + band:
			top_low = minf(top_low, p.x)
			top_high = maxf(top_high, p.x)
		if p.y >= bottom - band:
			bottom_low = minf(bottom_low, p.x)
			bottom_high = maxf(bottom_high, p.x)
	return (top_high - top_low) < 0.75 * (bottom_high - bottom_low)
