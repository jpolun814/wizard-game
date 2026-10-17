class_name EnemyBolt
extends Area2D

## A shot fired by an enemy. It stops at walls and hurts the player. A force wall or a push can send it back
## the other way, and a sent-back bolt hurts enemies instead. Some shots fall (gravity) and some slow the player.

const SPEED := 300.0
const LIFE := 3.0

var reflected := false
var _velocity := Vector2.RIGHT * SPEED
var _gravity := 0.0
var _slows := false
var _damage := 6
var _color := Color("#7fd8ff")
var _age := 0.0


## Creates a shot from an enemy toward a target point, and returns it. A gravity above zero makes it arc down.
## A slowing shot slows the player for a moment when it hits.
static func fire(parent: Node, origin: Vector2, target: Vector2, color: Color, damage: int, gravity := 0.0, slows := false) -> EnemyBolt:
	var bolt := EnemyBolt.new()
	bolt.global_position = origin
	var direction := (target - origin).normalized()
	bolt._velocity = direction * SPEED
	bolt._gravity = gravity
	bolt._slows = slows
	bolt._color = color
	bolt._damage = damage
	bolt.rotation = direction.angle()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	bolt.add_child(shape)
	bolt.collision_mask = 5  # terrain and the player; enemies are passed through until it is reflected
	bolt.body_entered.connect(bolt._on_body_entered)
	parent.add_child(bolt)
	return bolt


## A force wall has batted this shot: it turns around and now hurts enemies.
func reflect() -> void:
	if reflected:
		return
	reflected = true
	_velocity = -_velocity
	rotation = _velocity.angle()
	collision_mask = 7


## A push sends the shot flying the way the push points. Like a batted-back shot, it now hurts enemies.
func push(direction: Vector2) -> void:
	reflected = true
	_velocity = direction.normalized() * SPEED
	rotation = _velocity.angle()
	collision_mask = 7


func _physics_process(delta: float) -> void:
	_age += delta
	_velocity.y += _gravity * delta
	position += _velocity * delta
	rotation = _velocity.angle()
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not reflected:
			body.take_damage(_damage)
			if _slows:
				body.apply_debuff("slow", 2.0)
			queue_free()
		return
	if body.is_in_group("mobs"):
		if reflected:
			body.take_damage(_damage, "Force")
			queue_free()
		return
	queue_free()  # terrain and walls stop it


## A crisp dark orb with a coloured rim. No glow, so it reads as a solid thing flying at you.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.1, 0.06, 0.16))
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, _color, 2.0)
	draw_circle(Vector2.ZERO, 2.5, _color.lightened(0.5))
