class_name Volcano
extends Node2D

## A volcano that erupts for a few seconds. It throws lava balls in arcs. Each one that lands sets the ground or
## platform beneath it on fire for a while, and burns whatever is standing there. The rock is drawn plainly;
## the lava, the crater and the lava balls sit on a glowing layer.

const LIFE := 4.5
const ERUPT_INTERVAL := 0.45
const GRAVITY := 900.0
const LAVA_DAMAGE := 12
const LAVA_REACH := 30.0
const FIRE_WIDTH := 40.0
const FIRE_SECONDS := 5.0

var _age := 0.0
var _erupt := 0.0
var _balls: Array = []  # each lava ball is {"pos": world position, "vel": velocity}
var _glow: Node2D


func _ready() -> void:
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


func _physics_process(delta: float) -> void:
	_age += delta
	_erupt -= delta
	if _age < LIFE and _erupt <= 0.0:
		_erupt = ERUPT_INTERVAL
		_balls.append({"pos": global_position + Vector2(0, -30), "vel": Vector2(randf_range(-180.0, 180.0), -480.0)})
	var flying := []
	for ball in _balls:
		var before: Vector2 = ball["pos"]
		var velocity: Vector2 = ball["vel"] + Vector2(0, GRAVITY * delta)
		var after := before + velocity * delta
		var landing := _landing_between(before, after)
		if landing != Vector2.INF:
			_land(landing)
		else:
			flying.append({"pos": after, "vel": velocity})
	_balls = flying
	queue_redraw()
	_glow.queue_redraw()
	if _age >= LIFE and _balls.is_empty():
		queue_free()


## Where a lava ball crosses the ground between two points, or Vector2.INF if it does not.
func _landing_between(from: Vector2, to: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1  # terrain only
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector2.INF


## A lava ball lands: the ground catches fire, and anything standing close by is burned.
func _land(point: Vector2) -> void:
	Hazard.place(get_parent(), point, "fire", FIRE_WIDTH, FIRE_SECONDS)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.global_position.distance_to(point) <= LAVA_REACH:
			mob.take_damage(LAVA_DAMAGE, "Fire")
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(point) <= LAVA_REACH:
		player.take_damage(LAVA_DAMAGE)
	Fx.burst(get_parent(), point, Color("#ff7a2a"), 12, 140.0, 0.35)


## The rock and the smoke.
func _draw() -> void:
	var t := _age
	var peak := -70.0 * (1.0 + 0.03 * sin(t * 2.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-70, 0), Vector2(-8, peak), Vector2(8, peak), Vector2(70, 0)]), Color("#3b2c26"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, peak), Vector2(0, -40), Vector2(-40, 0), Vector2(-70, 0)]), Color("#5a4238"))
	# Ridges down the rock, for texture.
	for i in 3:
		var side := -1.0 if i % 2 == 0 else 1.0
		draw_line(Vector2(side * 10.0, peak + 6.0), Vector2(side * (30.0 + 10.0 * i), -10.0), Color(0.22, 0.16, 0.14, 0.8), 2.0)
	# Smoke rising from the crater and fading.
	for i in 7:
		var k := fmod(t * 0.3 + float(i) / 7.0, 1.0)
		draw_circle(Vector2(sin(float(i) * 2.1 + t) * 10.0, peak - 10.0 - k * 60.0), 6.0 + k * 14.0, Color(0.35, 0.33, 0.33, 0.35 * (1.0 - k)))


## The light: lava streams, the crater, and the lava balls with their trails.
func _draw_glow() -> void:
	var t := _age
	var peak := -70.0 * (1.0 + 0.03 * sin(t * 2.0))
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var reach := 26.0 + 14.0 * float(i / 2)
		var points := PackedVector2Array()
		for s in 12:
			var k := float(s) / 11.0
			points.append(Vector2(side * (6.0 + reach * k), peak + 66.0 * k))
		_glow.draw_polyline(points, Color(1.0, 0.45, 0.15, 0.35), 8.0)
		_glow.draw_polyline(points, Color("#ffb040"), 2.5)
	_glow.draw_circle(Vector2(0, peak + 4.0), 26.0 + 3.0 * sin(t * 6.0), Color(1.0, 0.45, 0.15, 0.10))
	_glow.draw_circle(Vector2(0, peak + 4.0), 14.0, Color(1.0, 0.5, 0.2, 0.25))
	_glow.draw_circle(Vector2(0, peak + 4.0), 5.0 + 2.0 * sin(t * 6.0), Color("#ffe0a0"))
	for ball in _balls:
		var local: Vector2 = ball["pos"] - global_position
		var vel: Vector2 = ball["vel"]
		_glow.draw_line(local, local - vel.normalized() * 18.0, Color(1.0, 0.6, 0.2, 0.5), 5.0)
		_glow.draw_circle(local, 9.0, Color(1.0, 0.45, 0.15, 0.3))
		_glow.draw_circle(local, 5.0, Color("#ff7a2a"))
		_glow.draw_circle(local, 2.5, Color("#ffe6a0"))
