class_name StaffTracer
extends Node2D

## A streak of light from the gem of a wizard's staff to the place a spell appears, so a stone that rises or a storm that gathers across the screen is plainly
## the wizard's doing and came from somewhere. It is only a picture: it hurts nothing and does nothing.

const TRAVEL := 0.22
const MIN_DISTANCE := 90.0  # nearer than this the spell is at the wizard's own feet and needs no streak

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _color := Color.WHITE
var _head: Sprite2D
var _trail: Sprite2D
var _age := 0.0


## Sends the streak, unless the place is by the wizard already.
static func launch(parent: Node, from: Vector2, to: Vector2, color: Color) -> void:
	if parent == null or from.distance_to(to) < MIN_DISTANCE:
		return
	var tracer := StaffTracer.new()
	tracer._from = from
	tracer._to = to
	tracer._color = color
	parent.add_child(tracer)


func _ready() -> void:
	z_index = 6
	var glow := Fx.tex("light_01")
	_trail = Sprite2D.new()
	_trail.texture = glow
	_trail.material = Fx.additive()
	_trail.modulate = Color(_color.r, _color.g, _color.b, 0.0)
	add_child(_trail)
	_head = Sprite2D.new()
	_head.texture = glow
	_head.material = Fx.additive()
	_head.modulate = Color(minf(_color.r + 0.3, 1.0), minf(_color.g + 0.3, 1.0), minf(_color.b + 0.3, 1.0), 0.95)
	_head.scale = Vector2.ONE * 26.0 / Fx.TEX_SIZE
	_head.position = _from
	add_child(_head)


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / TRAVEL, 0.0, 1.0)
	var spot := _from.lerp(_to, t)
	_head.position = spot
	_head.modulate.a = 0.95 * (1.0 - maxf(t - 0.7, 0.0) / 0.3)
	var length := _from.distance_to(spot)
	_trail.position = (_from + spot) * 0.5
	_trail.rotation = (_to - _from).angle()
	_trail.scale = Vector2(length / Fx.TEX_SIZE, 7.0 / Fx.TEX_SIZE)
	_trail.modulate.a = 0.55 * (1.0 - maxf(_age - TRAVEL * 0.5, 0.0) / (TRAVEL * 1.2))
	if _age >= TRAVEL * 1.8:
		queue_free()
