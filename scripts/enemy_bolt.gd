class_name EnemyBolt
extends Area2D

## A shot fired by an enemy. It stops at walls and hurts the player. A force wall or a push can send it back
## the other way, and a sent-back bolt hurts enemies instead. Some shots fall (gravity) and some slow the player.

const SPEED := 300.0
const LIFE := 3.0
const ROCK := preload("res://art/fx/rock.png")  # held here so it stays loaded between frames

var reflected := false
var _velocity := Vector2.RIGHT * SPEED
var _gravity := 0.0
var _slows := false
var _damage := 6
var _color := Color("#7fd8ff")
var _age := 0.0


## Creates a shot from an enemy toward a target point, and returns it. A gravity above zero makes it arc down.
## A slowing shot slows the player for a moment when it hits.
static func fire(parent: Node, origin: Vector2, target: Vector2, color: Color, damage: int, gravity := 0.0, slows := false, art := "magic_bolt") -> EnemyBolt:
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
	if gravity <= 0.0:
		var trail := Fx.trail(color, 20, 0.25, 10.0, Vector2.ZERO, "circle_05", 7.0)
		bolt.add_child(trail)
		# A pixel-art shot in the enemy's school colour: the sprite is recoloured by the mob shader, so a fire shot
		# is orange, an ice shot blue, whatever art it is drawn with.
		var shot := PixelFx.sprite(art, 14.0)
		shot.scale = Vector2.ONE * (1.0 if art == "fireball" else 2.0)
		var recolour := ShaderMaterial.new()
		recolour.shader = load("res://scripts/mob.gdshader")
		recolour.set_shader_parameter("school_color", color)
		recolour.set_shader_parameter("tint", 1.0)
		shot.material = recolour
		bolt.add_child(shot)
	return bolt


## A force wall has batted this shot: it turns around and now hurts enemies.
func reflect() -> void:
	if reflected:
		return
	reflected = true
	Sfx.play("force", global_position, -4.0)
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
			body.take_damage(_damage, true, true)
			if _slows:
				body.apply_debuff("slow", 2.0)
			_burst()
		return
	if body.is_in_group("mobs"):
		if reflected and not body.is_dead():
			body.take_damage(_damage, "Force")
			_burst()
		return
	_burst()  # terrain and walls stop it


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
