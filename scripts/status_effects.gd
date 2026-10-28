class_name StatusEffects
extends Node

## The timed conditions on a body (slowed, hasted, muted, shielded...). Each one is a Timer node that counts itself down
## in the physics step, so nothing has to decrement it by hand: ask has() or left(), and start() to set or lengthen one.

var _timers := {}  # name -> Timer


## Starts a condition for this many seconds, or lengthens it if it is already on for less.
func start(status: StringName, seconds: float) -> void:
	if seconds > left(status):
		set_left(status, seconds)


## Sets what is left of a condition outright; zero or less ends it.
func set_left(status: StringName, seconds: float) -> void:
	var timer := _timer(status)
	if seconds <= 0.0:
		timer.stop()
	else:
		timer.start(seconds)


func left(status: StringName) -> float:
	var timer: Timer = _timers.get(status)
	return 0.0 if timer == null or timer.is_stopped() else timer.time_left


func has(status: StringName) -> bool:
	return left(status) > 0.0


func _timer(status: StringName) -> Timer:
	if not _timers.has(status):
		var timer := Timer.new()
		timer.one_shot = true
		timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		timer.name = status
		add_child(timer)
		_timers[status] = timer
	return _timers[status]
