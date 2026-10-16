class_name EnemyBolt
extends Area2D

## A bolt fired by an enemy at the player. It stops at walls and hurts the player. A force wall can bat
## it back; a batted-back bolt flies the other way and hurts the enemies it hits instead.

const SPEED := 300.0
const LIFE := 3.0

var reflected := false
var _dir := Vector2.RIGHT
var _damage := 6
var _color := Color("#7fd8ff")
var _age := 0.0


## Creates a bolt at an enemy, aimed at the target, and returns it.
static func fire(parent: Node, origin: Vector2, target: Vector2, color: Color, damage: int) -> EnemyBolt:
	var bolt := EnemyBolt.new()
	bolt.global_position = origin
	bolt._dir = (target - origin).normalized()
	bolt._color = color
	bolt._damage = damage
	bolt.rotation = bolt._dir.angle()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	bolt.add_child(shape)
	bolt.collision_mask = 5  # terrain and the player; mobs are passed through until it is reflected
	bolt.body_entered.connect(bolt._on_body_entered)
	parent.add_child(bolt)
	return bolt


## A force wall has batted this bolt: it turns around and now hurts enemies.
func reflect() -> void:
	if reflected:
		return
	reflected = true
	_dir = -_dir
	rotation = _dir.angle()
	collision_mask = 7


## A push sends the bolt flying the way the push points. Like a batted-back bolt, it now hurts enemies.
func push(direction: Vector2) -> void:
	reflected = true
	_dir = direction.normalized()
	rotation = _dir.angle()
	collision_mask = 7


func _physics_process(delta: float) -> void:
	_age += delta
	position += _dir * SPEED * delta
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not reflected:
			body.take_damage(_damage)
			queue_free()
		return
	if body.is_in_group("mobs"):
		if reflected:
			body.take_damage(_damage, "Force")
			queue_free()
		return
	queue_free()  # terrain and walls stop it


## A crisp dark orb with a bright core. No glow, so it reads as a solid thing flying at you.
func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(0.1, 0.06, 0.16))
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, _color, 2.0)
	draw_circle(Vector2.ZERO, 2.5, _color.lightened(0.5))
