class_name Pen
extends RefCounted

## The stroke a brain's wizard is drawing, as a hand draws on a screen: it must lie on the screen when it is begun, only one is drawn at a time, none while a
## chant is being typed, and the view moving with the wizard drags it as it is drawn. Reached as `wizard.pen`. (A person's own strokes are the caster's.)

const DRAW_TIME := 0.8  # how long a brain's wizard takes to draw a spell

var wizard: Wizard
var _stroke := PackedVector2Array()  # the spell being drawn
var _time := 0.0  # what is left of the drawing
var _total := DRAW_TIME
var _on_drawn: Callable
var _drag := PackedVector2Array()  # how far the view had moved when each point of the stroke was drawn: the screen drags the stroke (see Eyes)
var _drag_from := Vector2.ZERO  # the middle of the view when the stroke was begun


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## Starts drawing a stroke in front of the wizard. After draw_time it calls on_done with the stroke. Being hit hard while drawing breaks the spell (see
## WizardBrain.on_hurt). Returns false when the stroke cannot be begun.
func begin(points: PackedVector2Array, colour: Color, on_done: Callable, draw_time := DRAW_TIME) -> bool:
	if active() or (wizard.brain != null and wizard.brain.chant.is_typing()):
		return false
	for point in points:
		if not wizard.eyes.on_screen(point):
			return false  # no one draws off the edge of their screen
	_drag_from = wizard.eyes.center()
	_drag = PackedVector2Array()
	_stroke = points
	wizard.cast_color = colour
	_on_drawn = on_done
	_time = draw_time
	_total = draw_time
	wizard.casting = true  # (no sound here: the same sound for every spell was not liked; each spell makes its own when it is cast)
	return true


func active() -> bool:
	return _time > 0.0


## The spell goes off when the stroke is done.
func tick(delta: float) -> void:
	if _time <= 0.0:
		return
	_time -= delta
	_note_drag()
	if _time <= 0.0:
		var stroke := _dragged()
		_stroke = PackedVector2Array()
		wizard.casting = false
		wizard.play_cast_release()
		_on_drawn.call(stroke)


## The stroke is dropped without a word (a wolf, a faint, a death).
func drop() -> void:
	_time = 0.0
	_stroke = PackedVector2Array()
	wizard.casting = false


## Drops the spell being drawn, and says whether there was one.
func interrupt() -> bool:
	if _time <= 0.0:
		return false
	drop()
	return true


## The part of the stroke drawn so far: it grows as the spell does.
func so_far() -> PackedVector2Array:
	if _time <= 0.0 or _stroke.size() < 2:
		return PackedVector2Array()
	var count := clampi(int(_stroke.size() * (1.0 - _time / _total)), 2, _stroke.size())
	return _dragged().slice(0, count)


## The points the hand has reached this step take the view's travel so far: a person's stroke is recorded in the world, under a moving screen.
func _note_drag() -> void:
	var count := _stroke.size() if _time <= 0.0 else clampi(int(_stroke.size() * (1.0 - _time / _total)), 1, _stroke.size())
	var moved := wizard.eyes.center() - _drag_from
	while _drag.size() < count:
		_drag.append(moved)


## The stroke as it lies in the world: each point where the hand drew it, moved by the view's travel up to then.
func _dragged() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _stroke.size():
		out.append(_stroke[i] + (_drag[i] if i < _drag.size() else (_drag[_drag.size() - 1] if not _drag.is_empty() else Vector2.ZERO)))
	return out
