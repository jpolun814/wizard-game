class_name EnemyBolt
extends Area2D

## A shot fired by an enemy. It stops at walls and hurts whatever it touches: the player, or another enemy. It can't hit
## the enemy that fired it until it has flown out of that enemy's body. Some shots fall (gravity) and some slow the player.

const SPEED := 300.0
const LIFE := 3.0
const CLEAR_CHECK_AFTER := 0.05  # the overlaps of a new shot are not known until a few physics frames have passed
const ROCK := preload("res://art/fx/rock.png")  # held here so it stays loaded between frames

var _clear := false  # it has flown out of its shooter's body: from then on it can hit the shooter too
var _shooter: Node
var _kin := ""  # the kind of enemy this shot passes through, when its shooter spares its own
var _speed := SPEED
var _velocity := Vector2.RIGHT * SPEED
var _gravity := 0.0
var _slows := false
var damage := 6
var _color := Color("#7fd8ff")
var _age := 0.0


## Creates a shot from an enemy toward a target point, and returns it. A gravity above zero makes it arc down.
## A slowing shot slows the player for a moment when it hits.
static func fire(parent: Node, origin: Vector2, target: Vector2, color: Color, damage: int, gravity := 0.0, slows := false, art := "magic_bolt", shooter: Node = null, speed := SPEED) -> EnemyBolt:
	var bolt := EnemyBolt.new()
	bolt.global_position = origin
	var direction := (target - origin).normalized()
	bolt._speed = speed
	bolt._velocity = direction * speed
	bolt._gravity = gravity
	bolt._slows = slows
	bolt._color = color
	bolt._shooter = shooter
	if shooter != null and shooter.KINDS[shooter.kind].shot.get("spare_kin", false):
		bolt._kin = shooter.kind
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
	if gravity <= 0.0:
		var trail := Fx.trail(color, 20, 0.25, 10.0, Vector2.ZERO, "circle_05", 7.0)
		bolt.add_child(trail)
		# A pixel-art shot in the enemy's school colour: the sprite is recoloured by the mob shader, so a fire shot
		# is orange, an ice shot blue, whatever art it is drawn with.
		var shot := PixelFx.sprite(art, 14.0)
		shot.scale = Vector2.ONE * (1.0 if art in ["fireball", "ninja_star"] else 2.0)
		var recolour := ShaderMaterial.new()
		recolour.shader = load("res://scripts/mob.gdshader")
		recolour.set_shader_parameter("school_color", color)
		recolour.set_shader_parameter("tint", 1.0)
		shot.material = recolour
		bolt.add_child(shot)
	return bolt


## A force wall, push or tornado turns this shot: it flies off along the new heading.
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
	_velocity.y += _gravity * delta
	position += _velocity * delta
	rotation = _velocity.angle()
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == _shooter and not _clear:
		return
	if body.is_in_group("mobs") and body.is_dead():
		return
	if _kin != "" and body.is_in_group("mobs") and body.kind == _kin:
		return  # a ninja's star flies through its own kind
	if (body.is_in_group("player") or body.is_in_group("mobs")) and body.has_shield():
		reflect(Vector2.from_angle(randf() * TAU))  # a Barrier sends it off in a random direction
		return
	if body.is_in_group("player"):
		body.take_damage(damage, true, true)
		if _slows and not body.has_shield():  # a Barrier negates the whole shot
			body.apply_debuff("slow", 2.0)
	elif body.is_in_group("mobs"):
		body.take_damage(damage, "", true)
	_burst()  # whatever it hits, it stops there


## A small blast where it ends.
func _burst() -> void:
	PixelFx.play(get_parent(), global_position, "blast_ring", 20.0, 2.0, _color.lightened(0.4))
	queue_free()


## A heavy shot (one that falls in an arc) is a tumbling rock; the others are sprites (see fire()), with a soft
## glow in the enemy's colour behind them.
func _draw() -> void:
	if _gravity > 0.0:
		var rock: Texture2D = ROCK
		draw_set_transform(Vector2.ZERO, floorf(_age * 10.0) * PI * 0.5, Vector2.ONE * 2.0)
		draw_texture(rock, -rock.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	Fx.draw_glow(self, Vector2.ZERO, 14.0, Color(_color.r, _color.g, _color.b, 0.45))
