class_name SnowCloud
extends Node2D

## A cloud of the snowy peaks, drifting past on the wind. It passes in front of whoever is in it, so they cannot be seen until it has gone by.

const PICTURES := [preload("res://art/props/cloud_snow_big.png"), preload("res://art/props/cloud_snow_small_1.png"), preload("res://art/props/cloud_snow_small_2.png")]

var drift := 30.0      # pixels a second, to the right
var left := 0.0        # where it comes back round to, at the world's edges
var right := 0.0


func _ready() -> void:
	z_index = 5
	var sprite := Sprite2D.new()
	sprite.texture = PICTURES[int(absf(position.x)) % PICTURES.size()]
	sprite.scale = Vector2.ONE * (6.0 if sprite.texture == PICTURES[0] else 5.0)  # whole-number scales only
	sprite.modulate = Color(0.82, 0.88, 1.0, 0.93)
	add_child(sprite)


func _process(delta: float) -> void:
	position.x += drift * delta
	if position.x > right:
		position.x = left
