class_name Tornado
extends Area2D

## A funnel of wind that touches down on the ground under where it was drawn. It bats shots back the way they
## came, and it swirls the foes inside it around until it dissipates. The funnel is pixel-art whirlwinds stacked on
## each other, small at the ground and wide at the top, each spinning out of step with the next.

const RADIUS := 70.0
const LIFE := 6.0
const SWIRL_INTERVAL := 0.3
const SWIRL_SPEED := 420.0
const TIP := 42.0  # the funnel's narrow end is this far below its middle

var team := "player"
var _age := 0.0
var _swirl := 0.0


func _ready() -> void:
	# The funnel's tip rests on the ground.
	var ground := SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0, -40))
	global_position = ground - Vector2(0, TIP)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	collision_mask = 7  # enemies, the player, and terrain
	area_entered.connect(_on_area)
	add_to_group("danger")
	Sfx.play("tornado", global_position)
	# Dust kicked up around the base.
	var dust := CPUParticles2D.new()
	dust.amount = 24
	dust.lifetime = 0.8
	dust.position = Vector2(0, TIP - 4.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(22, 2)
	dust.direction = Vector2.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0
	dust.tangential_accel_min = 200.0
	dust.tangential_accel_max = 300.0
	dust.gravity = Vector2(0, 40)
	dust.texture = Fx.tex("smoke_04")
	dust.scale_amount_min = 10.0 / Fx.TEX_SIZE
	dust.scale_amount_max = 20.0 / Fx.TEX_SIZE
	dust.color_ramp = Fx.fade_ramp(Color(0.8, 0.75, 0.6, 0.5))
	add_child(dust)
	dust.emitting = true
	# Whirlwinds from the tip up: (height above the tip, size).
	var rings := [[0.0, 1.0], [26.0, 1.0], [52.0, 2.0], [84.0, 2.0], [116.0, 3.0]]
	for i in rings.size():
		var spin := PixelFx.sprite("wind", 50.0 + i * 6.0)
		spin.position = Vector2(0, TIP - 8.0 - rings[i][0])
		spin.scale = Vector2(rings[i][1] * (1.0 if i % 2 == 0 else -1.0), rings[i][1] * 0.55)
		spin.frame = i * 11
		spin.modulate = Color(1.0, 1.0, 0.92)
		add_child(spin)


func _physics_process(delta: float) -> void:
	_age += delta
	_swirl -= delta
	# The whirlwinds are sprites; the whole funnel fades in and out.
	modulate.a = clampf((LIFE - _age) / 1.0, 0.0, 1.0) * clampf(_age / 0.3, 0.0, 1.0)
	if _swirl <= 0.0:
		_swirl = SWIRL_INTERVAL
		for body in get_overlapping_bodies():
			if not SpellTargets.affects(body, team):
				continue
			var around: Vector2 = body.global_position - global_position
			var tangent := around.rotated(PI * 0.5).normalized()
			if body.is_in_group("mobs"):
				body.knock_back(Vector2(tangent.x * SWIRL_SPEED, -180.0))
			else:
				body.push(Vector2(tangent.x * SWIRL_SPEED * 0.6, -160.0))
	if _age >= LIFE:
		queue_free()


## A shot from the other side that enters the funnel is sent back out the way it came.
func _on_area(area: Area2D) -> void:
	var away: Vector2 = area.global_position - global_position
	var out := away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	if area is EnemyBolt and team == "player" and not (area as EnemyBolt).reflected:
		(area as EnemyBolt).push(out)
	elif area is SpellEffect and area.team != team and SpellEffect.PROJECTILES.has(area.spell):
		area.reflect(out)


func danger_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < RADIUS
