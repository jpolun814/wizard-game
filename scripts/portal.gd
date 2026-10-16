class_name Portal
extends Area2D

## The way on after a wave: a turning vortex the player walks into. Three spiral arms wind into a dark
## centre, a halo breathes around them, and motes are drawn inward. Its light is meant to glow, so it is
## drawn with additive blending.

const RX := 14.0  # half-width of the vortex
const RY := 28.0  # half-height of the vortex

var _t := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 52)
	shape.shape = rect
	add_child(shape)
	collision_mask = 4  # the player only
	material = Fx.additive()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var violet := Color("#b07cff")
	var breath := 1.0 + 0.06 * sin(_t * 3.0)
	# A soft halo that breathes around the vortex.
	for i in 4:
		var grow := 1.0 + 0.35 * (i + 1) / 4.0
		draw_colored_polygon(_ellipse(RX * grow * breath, RY * grow * breath), Color(violet.r, violet.g, violet.b, 0.07))
	# Spiral arms, each winding from the rim in toward the centre and turning as time passes.
	for arm in 3:
		var points := PackedVector2Array()
		for s in 28:
			var k := s / 27.0
			var angle := _t * 2.6 + arm * TAU / 3.0 + (1.0 - k) * TAU * 1.1
			points.append(Vector2(cos(angle) * RX * k, sin(angle) * RY * k))
		draw_polyline(points, Color(violet.r, violet.g, violet.b, 0.85), 2.5)
		draw_polyline(points, Color(1.0, 0.95, 1.0, 0.7), 1.0)
	# Motes sliding in from the rim and vanishing at the centre.
	for i in 12:
		var k := fmod(_t * 0.45 + i / 12.0, 1.0)
		var angle := i * TAU / 12.0 + _t * 0.7
		var r := 1.0 - k
		var mote := Vector2(cos(angle) * RX * r * 1.6, sin(angle) * RY * r * 1.6)
		draw_circle(mote, 1.6 * (1.0 - k) + 0.4, Color(1.0, 0.9, 1.0, 0.8 * (1.0 - k)))
	# A dark centre with a bright rim.
	draw_colored_polygon(_ellipse(RX * 0.55, RY * 0.55), Color("#120a1e"))
	var rim := PackedVector2Array()
	for i in 33:
		var angle := TAU * i / 32.0
		rim.append(Vector2(cos(angle) * RX, sin(angle) * RY))
	draw_polyline(rim, Color(0.85, 0.7, 1.0, 0.9), 2.0)


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		points.append(Vector2(cos(TAU * i / 32.0) * rx, sin(TAU * i / 32.0) * ry))
	return points
