class_name BrainStrokes
extends RefCounted

## What the AI wizards need to draw like a person, none of it tied to one wizard: the strokes' shapes, how much of a stroke's drift each spell stands, and
## the quickest a person draws each spell.

const DRIFT_FILE := "res://data/ai/stroke_drift.json"
const HUMAN_FILE := "res://data/ai/human_limits.json"  # what people's bodies were measured to do (tools/measure_human.py)

static var _human := {}
static var _drift := {}


static func drift_table() -> Dictionary:
	if _drift.is_empty():
		var file := FileAccess.open(DRIFT_FILE, FileAccess.READ)
		_drift = JSON.parse_string(file.get_as_text()) if file != null else {"": {}}
		if _drift == null or _drift.is_empty():
			_drift = {"": {}}
	return _drift


## The quickest a person draws a spell: the quick end (the 25th percentile) of the strokes recorded for it, where there are enough of them
## (data/ai/human_limits.json, from tools/measure_human.py). Spells people were not recorded drawing often have no floor.
static func quickest_stroke(spell_name: String) -> float:
	if _human.is_empty():
		var file := FileAccess.open(HUMAN_FILE, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
		_human = parsed if parsed is Dictionary else {"strokes": {}}
	var row = _human.get("strokes", {}).get(spell_name)
	if row is Dictionary and row.get("n", 0) >= 3:
		return row["p25"]
	return 0.0


static func line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return densify(PackedVector2Array([a, b]))


## A preview shape, scaled, with the middle of its bounding box moved to a point.
static func offset(shape: PackedVector2Array, middle: Vector2, scale: float) -> PackedVector2Array:
	var center := box_center(shape)
	var out := PackedVector2Array()
	for p in shape:
		out.append(middle + (p - center) * scale)
	return densify(out)


static func box_center(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).get_center()


## The stroke with points every two pixels, as dense as one drawn with the mouse.
static func densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out
