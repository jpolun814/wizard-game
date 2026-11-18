class_name BodyFlames
extends Node2D

## The flames on a burning wizard. They are a fire like any other (the "fires" group): they light the dark, melt ice, set plants alight and set an oil slick off,
## and the AI wizards keep away from them. They ride on the wizard, and Coating puts them out.


func _ready() -> void:
	add_to_group("fires")
	z_index = 5
	position = Vector2(0, -34)


## The place the flames are, for everything that asks where there is fire.
func flame_points() -> PackedVector2Array:
	return PackedVector2Array([global_position])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, 30.0 + 5.0 * sin(Time.get_ticks_msec() * 0.02), Color(1.0, 0.5, 0.15, 0.4))
