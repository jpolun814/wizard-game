class_name WaveDirector
extends Node

## Runs one wave: after a short pause it spawns the whole wave, then reports once every enemy is dead.

signal wave_cleared

const FIRST_DELAY := 1.5

var arena: Node
var _wave: Dictionary = {}
var _timer := 0.0
var _spawned := false
var _done := false


## Readies a wave. It spawns after the first delay.
func start(wave: Dictionary) -> void:
	_wave = wave
	_timer = FIRST_DELAY


func _process(delta: float) -> void:
	if _done:
		return
	if not _spawned:
		_timer -= delta
		if _timer > 0.0:
			return
		for kind in _wave:
			for i in _wave[kind]:
				arena.spawn_mob(kind)
		_spawned = true
		return
	if get_tree().get_nodes_in_group("mobs").is_empty():
		_done = true
		wave_cleared.emit()
