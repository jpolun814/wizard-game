class_name Squall
extends CanvasLayer

## A spell of bad weather that comes and goes over a world: a downpour in the jungle, an ash storm in the ashlands. It follows a fixed
## timetable of the world's age, so every machine of a match has it at the same time. While it lasts it darkens the view; what falls is
## chosen by the world from `level()`.

const RAMP := 4.0  # seconds it takes to build up, and to die away

var period := 70.0   # seconds from the start of one to the start of the next
var length := 18.0   # seconds each lasts
var delay := 25.0   # seconds into the world before the first
var tint := Color(0.04, 0.07, 0.1)
var strength := 0.4  # how dark the view gets at its worst
var seconds := 0.0   # the world's age: the world sets it each frame

var _veil: ColorRect


func _ready() -> void:
	layer = 1
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(tint, 0.0)
	add_child(_veil)


## How strong it is now, from 0 (clear) to 1 (at its worst).
func level() -> float:
	if seconds < delay:
		return 0.0
	var into := fmod(seconds - delay, period)
	if into >= length:
		return 0.0
	return clampf(minf(into, length - into) / RAMP, 0.0, 1.0)


func _process(_delta: float) -> void:
	_veil.color = Color(tint, level() * strength)
