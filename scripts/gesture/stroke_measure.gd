class_name StrokeMeasure
extends RefCounted

## Plain measures of a stroke drawn as points: how big, where its middle is, how far it turns, how often it crosses itself. Nothing here knows a spell.

## The same average, in the stroke's own coordinates (relative to where it began).
static func centroid(relative: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in relative:
		sum += p
	return sum / relative.size()


## Where a stroke that goes round a closed loop gets back to its start, and the last point still at the start: the loop is before it, what
## follows is the tail. Returns -1 when the stroke does not close, or goes too short a way before it does.
## True when a stroke runs level, or nearly: within thirty degrees of flat, left or right.
static func runs_level(points: PackedVector2Array) -> bool:
	var run := points[points.size() - 1] - points[0]
	return run.length() > 0.0 and absf(run.y) <= absf(run.x) * tan(deg_to_rad(30.0))


## How far a stroke strays from the straight line between its two ends.
static func max_deviation(points: PackedVector2Array) -> float:
	var a := points[0]
	var b := points[points.size() - 1]
	var worst := 0.0
	for p in points:
		worst = maxf(worst, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return worst


## The average distance of points from their centre: the radius of a drawn circle.
static func mean_distance(points: PackedVector2Array, centre: Vector2) -> float:
	var sum := 0.0
	for p in points:
		sum += p.distance_to(centre)
	return sum / points.size()


## How many times a stroke crosses itself.
static func count_crossings(points: PackedVector2Array) -> int:
	var count := 0
	for i in range(points.size() - 1):
		for j in range(i + 2, points.size() - 1):
			if segments_cross(points[i], points[i + 1], points[j], points[j + 1]):
				count += 1
	return count


static func segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var side_1 := ab.cross(c - a)
	var side_2 := ab.cross(d - a)
	var side_3 := cd.cross(a - c)
	var side_4 := cd.cross(b - c)
	return side_1 * side_2 < 0.0 and side_3 * side_4 < 0.0


## The total angle a stroke turns through, signed: a full clockwise circle is about TAU.
static func total_turning(points: PackedVector2Array, span := 6.0) -> float:
	# Directions are measured over spans of a few pixels, so the tiny jitter of a hand-drawn line cancels out. A longer
	# span smooths more, for shapes that are judged by how far they turn overall.
	var total := 0.0
	var last_dir := Vector2.ZERO
	var anchor := points[0]
	for p in points:
		var step := p - anchor
		if step.length() < span:
			continue
		if last_dir != Vector2.ZERO:
			total += last_dir.angle_to(step)
		last_dir = step
		anchor = p
	return total


## The width and height of a stroke's bounding box.
static func extent(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).size


## Stroke-space points moved to where they were drawn in the world, so that an effect can be placed there.
static func to_world(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(origin + p)
	return out
