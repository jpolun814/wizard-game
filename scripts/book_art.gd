class_name BookArt
extends Control

## The book itself, one frame of its sheet at a time. play() runs a list of frames, then calls back.

var frame := Spellbook.OPEN
var pixel := Spellbook.SCALE  # one pixel of the book is this many screen pixels
var _sheet: Texture2D = preload("res://art/ui/book.png")
var _queue: Array = []
var _clock := 0.0
var _done: Callable

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art scaled up stays sharp

func play(frames: Array, done: Callable) -> void:
	_queue = frames.duplicate()
	_done = done
	_clock = 0.0
	frame = _queue.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	if _queue.is_empty():
		return
	_clock += delta
	if _clock >= Spellbook.FRAME_TIME:
		_clock = 0.0
		frame = _queue.pop_front()
		queue_redraw()
		if _queue.is_empty() and _done.is_valid():
			_done.call()

func _draw() -> void:
	var source := Rect2(Vector2(frame * Spellbook.FRAME.x, 0), Spellbook.FRAME)
	draw_texture_rect_region(_sheet, Rect2(Vector2.ZERO, Spellbook.FRAME * pixel), source)
