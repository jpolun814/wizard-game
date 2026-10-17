class_name Tornado
extends Area2D

## A funnel of wind that stays where it was drawn. It bats enemy shots back the way they came, and it swirls
## the enemies inside it around until it dissipates. Drawn crisp, in the Storm colour.

const RADIUS := 70.0
const LIFE := 6.0
const SWIRL_INTERVAL := 0.3
const SWIRL_SPEED := 420.0

var _age := 0.0
var _swirl := 0.0


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	collision_mask = 7  # enemies, enemy shots, and terrain
	area_entered.connect(_on_area)


func _physics_process(delta: float) -> void:
	_age += delta
	_swirl -= delta
	queue_redraw()
	if _swirl <= 0.0:
		_swirl = SWIRL_INTERVAL
		for body in get_overlapping_bodies():
			var around: Vector2 = body.global_position - global_position
			var tangent := around.rotated(PI * 0.5).normalized()
			if body.is_in_group("mobs"):
				body.knock_back(Vector2(tangent.x * SWIRL_SPEED, -180.0))
			elif body.is_in_group("player"):
				body.push(Vector2(tangent.x * SWIRL_SPEED * 0.6, -160.0))
	if _age >= LIFE:
		queue_free()


## An enemy shot that enters the funnel is sent back the way it came, and now hurts the enemies.
func _on_area(area: Area2D) -> void:
	if area is EnemyBolt and not (area as EnemyBolt).reflected:
		var away: Vector2 = area.global_position - global_position
		(area as EnemyBolt).push(away.normalized() if away.length() > 0.01 else Vector2.RIGHT)


func _draw() -> void:
	var fade := clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	var storm := Color("#ffe85a")
	var pale := Color(0.95, 0.98, 1.0)
	# Streaks spin around a cone that narrows toward the bottom, each one a sine wave.
	for i in 9:
		var phase := float(i) / 9.0
		var points := PackedVector2Array()
		for s in 25:
			var k := float(s) / 24.0
			var y := -RADIUS + k * RADIUS * 1.6
			var width := RADIUS * (1.0 - k * 0.8)
			var x := sin(k * 9.0 + _age * 7.0 + phase * TAU) * width * (0.9 if i % 2 == 0 else 0.6)
			points.append(Vector2(x, y))
		var colour := storm.lerp(pale, phase)
		draw_polyline(points, Color(colour.r, colour.g, colour.b, 0.9 * fade), 2.0)
	# Dust swirling at the base.
	for i in 6:
		var a := float(i) / 6.0 * TAU + _age * 3.0
		draw_circle(Vector2(cos(a) * 14.0, RADIUS * 0.7 + sin(a) * 4.0), 2.0, Color(0.8, 0.75, 0.6, 0.7 * fade))
