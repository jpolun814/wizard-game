class_name UnistrokeRecognizer
extends RefCounted

## $1 Unistroke Recognizer (Wobbrock et al., 2007), ported to GDScript.
## Matching is invariant to rotation, scale and translation. Stroke direction
## and order still matter, so a clockwise circle is not a counter-clockwise one.

const NUM_POINTS := 64
const SQUARE_SIZE := 250.0
const HALF_DIAGONAL := 176.7767  # 0.5 * sqrt(2) * SQUARE_SIZE
const ANGLE_RANGE := 0.785398    # 45 degrees, in radians
const ANGLE_PRECISION := 0.0349  # 2 degrees, in radians
const PHI := 0.618034            # golden ratio conjugate

var templates: Dictionary = {}  # name -> normalized PackedVector2Array


static func path_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
	return length


func add_template(template_name: String, points: PackedVector2Array) -> void:
	templates[template_name] = _normalize(points)


## Returns {"name": String, "score": float}. Score is 1.0 for a perfect match.
## Name is "" when there are no templates or the stroke is degenerate.
func recognize(points: PackedVector2Array) -> Dictionary:
	if templates.is_empty() or points.size() < 2 or path_length(points) <= 0.0:
		return {"name": "", "score": 0.0}
	var candidate := _normalize(points)
	var best_distance := INF
	var best_name := ""
	for template_name in templates:
		var d := _distance_at_best_angle(candidate, templates[template_name])
		if d < best_distance:
			best_distance = d
			best_name = template_name
	return {"name": best_name, "score": 1.0 - best_distance / HALF_DIAGONAL}


func _normalize(points: PackedVector2Array) -> PackedVector2Array:
	var pts := _resample(points, NUM_POINTS)
	pts = _rotate_by(pts, -(_centroid(pts) - pts[0]).angle())
	pts = _scale_to_square(pts, SQUARE_SIZE)
	pts = _translate_to_origin(pts)
	return pts


func _resample(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var interval := path_length(points) / (n - 1)
	var pts := points.duplicate()
	var out := PackedVector2Array([pts[0]])
	var accumulated := 0.0
	var i := 1
	while i < pts.size():
		var d := pts[i - 1].distance_to(pts[i])
		if accumulated + d >= interval:
			var q := pts[i - 1].lerp(pts[i], (interval - accumulated) / d)
			out.append(q)
			pts.insert(i, q)  # Next iteration measures from the new point.
			accumulated = 0.0
		else:
			accumulated += d
		i += 1
	# Floating-point drift can leave us one point short; pad with the endpoint.
	while out.size() < n:
		out.append(pts[pts.size() - 1])
	return out


func _centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()


func _rotate_by(points: PackedVector2Array, theta: float) -> PackedVector2Array:
	var c := _centroid(points)
	var out := PackedVector2Array()
	for p in points:
		out.append((p - c).rotated(theta) + c)
	return out


## Uniform scale by the larger bounding-box side. The original $1 scales each
## axis to fill the square, which blows up hand wobble on near-straight strokes
## (a slightly wavy line becomes a zigzag). Keeping the aspect ratio avoids that.
func _scale_to_square(points: PackedVector2Array, size: float) -> PackedVector2Array:
	var min_p := points[0]
	var max_p := points[0]
	for p in points:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var extent := maxf(maxf(max_p.x - min_p.x, max_p.y - min_p.y), 1.0)
	var out := PackedVector2Array()
	for p in points:
		out.append(p * size / extent)
	return out


func _translate_to_origin(points: PackedVector2Array) -> PackedVector2Array:
	var c := _centroid(points)
	var out := PackedVector2Array()
	for p in points:
		out.append(p - c)
	return out


func _path_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var total := 0.0
	for i in a.size():
		total += a[i].distance_to(b[i])
	return total / a.size()


func _distance_at_angle(points: PackedVector2Array, template: PackedVector2Array, theta: float) -> float:
	return _path_distance(_rotate_by(points, theta), template)


## Golden-section search for the rotation that best aligns the candidate.
func _distance_at_best_angle(points: PackedVector2Array, template: PackedVector2Array) -> float:
	var a := -ANGLE_RANGE
	var b := ANGLE_RANGE
	var x1 := PHI * a + (1.0 - PHI) * b
	var f1 := _distance_at_angle(points, template, x1)
	var x2 := (1.0 - PHI) * a + PHI * b
	var f2 := _distance_at_angle(points, template, x2)
	while absf(b - a) > ANGLE_PRECISION:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(points, template, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(points, template, x2)
	return minf(f1, f2)
