class_name WaveDirector
extends Node

## Runs one wave: after a short pause it summons the wave's enemies one after another, then reports once every
## enemy is dead.

signal wave_cleared

const FIRST_DELAY := 2.0
const STAGGER := 0.35  # time between one enemy's arrival and the next

var arena: Node
var _queue: Array[String] = []
var _timer := 0.0
var _done := false


## Readies a wave. Its enemies start arriving after the first delay.
func start(wave: Dictionary) -> void:
	_queue.clear()
	for kind in wave:
		for i in wave[kind]:
			_queue.append(kind)
	_timer = FIRST_DELAY


## How many enemies are still to come or still alive.
func remaining() -> int:
	return _queue.size() + get_tree().get_nodes_in_group("mobs").size()


func is_cleared() -> bool:
	return _done


func _process(delta: float) -> void:
	if _done:
		return
	if not _queue.is_empty():
		_timer -= delta
		if _timer <= 0.0:
			arena.spawn_mob(_queue.pop_front())
			_timer = STAGGER
		return
	if get_tree().get_nodes_in_group("mobs").is_empty():
		_done = true
		wave_cleared.emit()
