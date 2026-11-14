class_name EnemyBolt
extends Area2D

## A shot fired by an enemy (a turret's bolt, a sentinel's laser). It stops at walls and hurts whatever it touches: a wizard, or another enemy.
## It can't hit the enemy that fired it until it has flown out of that enemy's body.

const SPEED := 300.0
const LIFE := 3.0
const CLEAR_CHECK_AFTER := 0.05  # the overlaps of a new shot are not known until a few physics frames have passed

var _clear := false  # it has flown out of its shooter's body: from then on it can hit the shooter too
var _shooter: Node
var _speed := SPEED
var _velocity := Vector2.RIGHT * SPEED
var damage := 6
var _color := Color("#7fd8ff")
var _age := 0.0


## Creates a shot from an enemy toward a target point, and returns it.
static func fire(parent: Node, origin: Vector2, target: Vector2, color: Color, damage: int, shooter: Node = null, speed := SPEED) -> EnemyBolt:
	var bolt := EnemyBolt.new()
	bolt.global_position = origin
	var direction := (target - origin).normalized()
	bolt._speed = speed
	bolt._velocity = direction * speed
	bolt._color = color
	bolt._shooter = shooter
	bolt.damage = damage
	bolt.rotation = direction.angle()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	bolt.add_child(shape)
	bolt.collision_mask = 7  # terrain, enemies and the player
	bolt.body_entered.connect(bolt._on_body_entered)
	bolt.add_to_group("shots")
	parent.add_child(bolt)
	bolt.add_child(Fx.trail(color, 20, 0.25, 10.0, Vector2.ZERO, "circle_05", 7.0))
	# A pixel-art shot in the shooter's color: the sprite is recolored by the mob shader.
	var shot := PixelFx.sprite("magic_bolt", 14.0)
	shot.scale = Vector2.ONE * 2.0
	var recolor := ShaderMaterial.new()
	recolor.shader = load("res://scripts/creatures/mob.gdshader")
	recolor.set_shader_parameter("school_color", color)
	recolor.set_shader_parameter("tint", 1.0)
	shot.material = recolor
	bolt.add_child(shot)
	return bolt


## A Gust, Push or Tornado turns this shot: it flies off along the new heading.
func reflect(direction: Vector2) -> void:
	_velocity = direction.normalized() * _speed
	rotation = _velocity.angle()
	Sfx.play("push", global_position, -4.0)


## A steady pull, such as a Black Hole's. Call it every frame the pull lasts.
func pull(force: Vector2, delta: float) -> void:
	_velocity += force * delta


## Which way it is flying right now.
func heading() -> Vector2:
	return _velocity.normalized()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= CLEAR_CHECK_AFTER and not _clear and not get_overlapping_bodies().has(_shooter):
		_clear = true
	position += _velocity * delta
	rotation = _velocity.angle()
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == _shooter and not _clear:
		return
	if (body.is_in_group("mobs") and body.is_dead()) or (body.is_in_group("wizards") and body.dead):
		return
	if body.is_in_group("wizards") and body.has_shield():
		reflect(Vector2.from_angle(randf() * TAU))  # a Barrier sends it off in a random direction
		return
	if body.is_in_group("wizards"):
		body.take_damage(damage, true, true)
	elif body.is_in_group("mobs"):
		body.take_damage(damage, "", true)
	_burst()  # whatever it hits, it stops there


## A small blast where it ends.
func _burst() -> void:
	PixelFx.play(get_parent(), global_position, "blast_ring", 20.0, 2.0, _color.lightened(0.4))
	queue_free()


## A soft glow in the shooter's color behind the sprite.
func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, 14.0, Color(_color.r, _color.g, _color.b, 0.45))
