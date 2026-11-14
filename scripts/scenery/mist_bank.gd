class_name MistBank
extends Node2D

## A bank of low fog lying along the ground of the graveyard, drifting slowly. It hangs in front of the ground and the wizards, so whoever
## stands in it is half veiled, and it lies lowest and thickest over the low ground. It is only seen: wizards walk through it.

var floors := PackedInt32Array()  # the first solid row of each column
var first := 0  # the column the first of those is
var seed_value := 0

var _puffs: Array[Sprite2D] = []
var _homes := PackedFloat32Array()   # where each puff drifts about
var _phases := PackedFloat32Array()  # and where it is in its drift
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var column := 0
	while column < floors.size():
		var puff := Sprite2D.new()
		puff.texture = Fx.tex("smoke_01")
		puff.scale = Vector2(rng.randf_range(2.2, 3.4), rng.randf_range(0.7, 1.1))
		puff.modulate = Color(0.8, 0.82, 0.88, rng.randf_range(0.2, 0.34))
		puff.position = Vector2((first + column) * float(ArenaGen.TILE), floors[column] * float(ArenaGen.TILE) - rng.randf_range(4.0, 26.0))
		puff.z_index = 2
		_homes.append(puff.position.x)
		_phases.append(rng.randf() * TAU)
		add_child(puff)
		_puffs.append(puff)
		column += rng.randi_range(5, 9)


func _process(delta: float) -> void:
	_t += delta
	for i in _puffs.size():
		_puffs[i].position.x = _homes[i] + sin(_t * 0.2 + _phases[i]) * 60.0
