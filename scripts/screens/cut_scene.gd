class_name CutScene
extends Node2D
## What the scene before a match and the scene after one have in common: a clock with cues that go off at their times, a camera that cuts from shot to
## shot, a fade to black, the "press any key" hint, and leaving when it is over or a key is pressed.

signal finished  # the scene is over, and the next one is about to load

var next_scene := ""  # where it goes when it is over; empty to stay on (a test does that)
var _t := 0.0
var _cues: Array = []  # [seconds, Callable], in order
var _leaving := false
var _camera: Camera2D
var _following: Node2D  # the camera runs beside this one, when it is set
var _shot_tween: Tween
var _hint: Label
var _black: ColorRect


func _cue(seconds: float, action: Callable) -> void:
	_cues.append([seconds, action])


## Moves the clock on and sets off every cue that is due.
func _run_cues(delta: float) -> void:
	_t += delta
	while not _cues.is_empty() and _cues[0][0] <= _t:
		_cues.pop_front()[1].call()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	_cues.clear()
	_fade(1.0, 0.3)
	_cue(_t + 0.3, _leave)


## Cuts the camera to a place and a zoom over a few seconds, easing in and out.
func _shot(at: Vector2, zoom: float, seconds: float) -> void:
	_following = null
	if _shot_tween != null:
		_shot_tween.kill()
	_shot_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.tween_property(_camera, "position", at, seconds)
	_shot_tween.tween_property(_camera, "zoom", Vector2(zoom, zoom), seconds)


## Fades the black over everything to this much (0 clear, 1 black).
func _fade(to: float, seconds: float) -> void:
	create_tween().tween_property(_black, "color:a", to, seconds)


## The layer over the scene: the hint that any key skips it, and the black it fades through.
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_hint = Label.new()
	_hint.theme_type_variation = &"Outlined"
	_hint.text = "Press any key to skip"
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9, 0.7))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -260.0
	_hint.offset_top = -40.0
	_hint.offset_right = -20.0
	_hint.offset_bottom = -12.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.visible = false
	layer.add_child(_hint)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	finished.emit()
	if next_scene != "":
		_go_on()


## Loads what comes next.
func _go_on() -> void:
	get_tree().change_scene_to_file(next_scene)
