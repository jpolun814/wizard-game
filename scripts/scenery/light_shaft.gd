class_name LightShaft
extends Sprite2D

## A slanting shaft of pale light falling through the jungle canopy, which breathes slowly brighter and dimmer. Only seen.

var phase := 0.0
var _t := 0.0


func _ready() -> void:
	texture = Fx.tex("light_01")
	material = Fx.additive()
	z_index = 3
	rotation = 0.22
	scale = Vector2(0.9, 5.5)
	modulate = Color(0.85, 1.0, 0.7, 0.1)


func _process(delta: float) -> void:
	_t += delta
	modulate.a = 0.1 + 0.07 * sin(_t * 0.5 + phase)
