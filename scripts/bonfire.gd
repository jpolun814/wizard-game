class_name Bonfire
extends Node2D

## A bonfire that burns for a while on the ground. Standing near it slowly restores health.
## The logs are drawn plain; the flames sit on their own layer, which glows, so they read as fire.

const LIFE := 15.0
const REACH := 90.0          # how close the player must stand to be warmed
const HEAL_PER_SECOND := 4.0

var power := 1.0             # set from the chant's accuracy: a truer chant warms more
var _age := 0.0
var _heal_carry := 0.0       # fractional healing kept between frames
var _flames: Node2D


func _ready() -> void:
	_flames = Node2D.new()
	_flames.material = Fx.additive()
	add_child(_flames)
	_flames.draw.connect(_draw_flames)


func _process(delta: float) -> void:
	_age += delta
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(global_position) <= REACH and player.hp < player.MAX_HP:
		_heal_carry += HEAL_PER_SECOND * power * delta
		var whole := int(_heal_carry)
		if whole > 0:
			player.heal(whole)
			_heal_carry -= whole
	queue_redraw()
	_flames.queue_redraw()
	if _age >= LIFE:
		queue_free()


func _fade() -> float:
	return clampf((LIFE - _age) / 1.5, 0.0, 1.0)


func _draw() -> void:
	var fade := _fade()
	# Two logs, crossed, charred, with a lighter edge on top.
	draw_line(Vector2(-16, 1), Vector2(15, -5), Color(0.3, 0.19, 0.1, fade), 6.0)
	draw_line(Vector2(-14, -4), Vector2(16, 2), Color(0.22, 0.13, 0.07, fade), 6.0)
	draw_line(Vector2(-15, -1), Vector2(14, -6), Color(0.45, 0.3, 0.16, 0.8 * fade), 1.5)
	draw_line(Vector2(-13, -6), Vector2(15, 0), Color(0.4, 0.26, 0.14, 0.8 * fade), 1.5)
	# Embers lying in the cracks between the logs.
	for x in [-8.0, 0.0, 7.0]:
		draw_circle(Vector2(x, -2), 1.6, Color(1.0, 0.5, 0.2, 0.9 * fade))


func _draw_flames() -> void:
	var fade := _fade()
	var warm := 1.0 + 0.08 * sin(_age * 5.0)
	# A warm halo that breathes, behind the flames.
	_flames.draw_circle(Vector2(0, -14), 64.0 * warm, Color(1.0, 0.45, 0.12, 0.05 * fade))
	_flames.draw_circle(Vector2(0, -14), 40.0 * warm, Color(1.0, 0.55, 0.18, 0.08 * fade))
	# Tongues of flame, each one a layered shape: a red-orange outer, an orange middle, a yellow core.
	var tongues := [[-12.0, 15.0, 0.8, 0.0], [-5.0, 21.0, 1.0, 1.3], [1.0, 25.0, 1.15, 2.6], [7.0, 20.0, 1.0, 3.9], [12.0, 14.0, 0.75, 5.1]]
	for tongue in tongues:
		var x: float = tongue[0]
		var height: float = tongue[1] * warm
		var width: float = tongue[2] * 5.0
		var phase: float = tongue[3]
		_tongue(x, height * 1.1, width * 1.25, Color(1.0, 0.3, 0.06, 0.45 * fade), phase)
		_tongue(x, height * 0.85, width * 0.8, Color(1.0, 0.6, 0.15, 0.6 * fade), phase)
		_tongue(x, height * 0.45, width * 0.35, Color(1.0, 0.93, 0.55, 0.9 * fade), phase)
	# Embers rising off the fire and fading as they climb.
	for i in 9:
		var k := fmod(_age * 0.55 + i / 9.0, 1.0)
		var drift := sin(i * 2.3 + _age * 2.0) * 12.0 * k
		_flames.draw_circle(Vector2(drift, -20.0 - k * 50.0), 1.5 * (1.0 - k) + 0.5, Color(1.0, 0.7, 0.3, 0.9 * (1.0 - k) * fade))


## One flame tongue: its base is wide at x, it tapers to a tip, and its edges wobble as it burns.
func _tongue(x: float, height: float, width: float, colour: Color, phase: float) -> void:
	var sway := sin(_age * 7.0 + phase) * 3.0
	var points := PackedVector2Array()
	for s in 9:
		var t := s / 8.0
		var edge := 1.0 + 0.25 * sin(t * 6.0 + phase + _age * 5.0)
		points.append(Vector2(x + width * (1.0 - t) * edge + sway * t, -height * t))
	for s in range(8, -1, -1):
		var t := s / 8.0
		var edge := 1.0 + 0.25 * sin(t * 5.0 - phase - _age * 4.0)
		points.append(Vector2(x - width * (1.0 - t) * edge + sway * t, -height * t))
	_flames.draw_colored_polygon(points, colour)
