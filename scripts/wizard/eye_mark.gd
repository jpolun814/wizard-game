class_name EyeMark
extends Node2D

## A watching eye that floats over a wizard's head while another is watching them through the Chant of the Scrying Eye: an almond-shaped eye with a
## golden iris and a slit pupil, in a faint glow, that now and then blinks. It is an interface sign, drawn from pixel squares, so that whoever is
## watched can tell.

const HALF_WIDTH := 8.5      # in pixels of the sign
const HALF_HEIGHT := 4.6
const PIXEL := 2.0
const HEIGHT := 112.0        # how far over the wizard's feet it floats
const OUTLINE := Color("#1a0d22")
const WHITE := Color("#e9e2c8")
const SHADE := Color("#b7ad8f")
const IRIS := Color("#e0a82e")
const IRIS_DARK := Color("#a8681c")
const SLIT := Color("#0b0610")
const GLOW := Color(1.0, 0.75, 0.25)

var _t := 0.0


func _ready() -> void:
	add_to_group("eye_marks")
	z_index = 20


func _process(delta: float) -> void:
	_t += delta
	position = Vector2(0.0, -HEIGHT + sin(_t * 2.4) * 3.0)
	queue_redraw()


## How far open the lid is, from 0 (shut) to 1.
func _openness() -> float:
	var since := fmod(_t, 4.0) - 3.8  # a blink every four seconds: shut, then open
	if since < 0.0 or since > 0.2:
		return 1.0
	return 0.15 + 0.85 * absf(since - 0.1) / 0.1


## Whether a cell (its middle, in pixels of the sign from the middle of the eye) lies inside the lids.
func _inside(dx: float, dy: float, open: float) -> bool:
	var reach := 1.0 - pow(absf(dx) / HALF_WIDTH, 2.0)
	return reach > 0.0 and absf(dy) <= HALF_HEIGHT * open * pow(reach, 0.85)


func _draw() -> void:
	var open := _openness()
	for ring in 6:  # a soft glow, in rings that each add a little
		draw_circle(Vector2.ZERO, 20.0 - 2.5 * ring, Color(GLOW, 0.025 + 0.006 * sin(_t * 3.0)))
	var look := Vector2(sin(_t * 0.9) * 1.2, 0.0)  # the eye wanders a little
	for cy in range(-6, 7):
		for cx in range(-9, 10):
			var dx := float(cx)
			var dy := float(cy)
			if not _inside(dx, dy, open):
				continue
			var color := WHITE if dy <= 1.5 else SHADE
			var edge := not (_inside(dx - 1.0, dy, open) and _inside(dx + 1.0, dy, open) and _inside(dx, dy - 1.0, open) and _inside(dx, dy + 1.0, open))
			var from_iris := Vector2(dx, dy) - look
			if from_iris.length() <= 3.6:
				color = IRIS if from_iris.y < 1.0 else IRIS_DARK
				if absf(from_iris.x) <= 0.6 and absf(from_iris.y) <= 3.0:
					color = SLIT
				elif from_iris.x < -1.0 and from_iris.y < -1.5:
					color = WHITE  # a glint
			if edge:
				color = OUTLINE
			draw_rect(Rect2(Vector2(dx - 0.5, dy - 0.5) * PIXEL, Vector2(PIXEL, PIXEL)), color)
