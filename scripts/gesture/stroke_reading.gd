class_name StrokeReading
extends RefCounted

## What a stroke was read as: the gesture (a name from the templates or one of the shapes read from the stroke itself), how sure the read is (a certain read is 1.0),
## and what the arena needs to place the effect.

var gesture: String
var score: float
var info := {"radius": 0.0, "pieces": 1, "shapes": [], "line": PackedVector2Array(), "rect": Rect2()}
var ring_split := -1  # where a ring ends and the line out of it begins, or -1 when it is not a ring with a line
var ring_center := Vector2.ZERO
var latin := false  # a Latin cross was read from the stroke itself


func _init(guess: String, guess_score: float) -> void:
	gesture = guess
	score = guess_score


## The read finds this shape: it is named, and it is certain. What the arena needs for it is put in `info`.
func claim(shape: String, more := {}) -> StrokeReading:
	gesture = shape
	score = 1.0
	info.merge(more, true)
	return self
