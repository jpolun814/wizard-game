class_name LavaBall
extends Area2D

## A ball of molten rock thrown by a volcano. It flies in an arc, and where it lands the ground or platform catches
## fire and anything close by is burned. A ball that strikes someone lands on them. It is a shot like any other: a
## Gust, Push or Tornado turns it, an Abyss swallows it, a Barrier stops it, and a stone wall takes the
## blow. Lava burns whoever it lands on, the caster included.

const GRAVITY := 900.0
const DAMAGE := 12
const REACH := 30.0  # how far from where it lands it burns
const FIRE_WIDTH := 40.0
const FIRE_SECONDS := 5.0
const LIFE := 6.0  # one thrown off the map is gone after this

var velocity := Vector2.ZERO
var _age := 0.0
var _spent := false


## Throws a ball of lava from a point, and returns it.
static func throw(parent: Node, from: Vector2, launch: Vector2) -> LavaBall:
	var ball := LavaBall.new()
	ball.global_position = from
	ball.velocity = launch
	parent.add_child(ball)
	return ball


func _ready() -> void:
	add_to_group("shots")
	add_to_group("fires")
	material = Fx.additive()  # its glow adds light to what is behind it; the ball itself is a sprite
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	collision_mask = 6  # the player and enemies; the ground is found by ray, so a fast ball never skips through it
	body_entered.connect(_on_body)
	# The pixel fireball, its head on the node and its tail streaming behind.
	var sprite := PixelFx.sprite("fireball", 18.0)
	sprite.offset = Vector2(-18, 0)
	add_child(sprite)
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	velocity.y += GRAVITY * delta
	var after := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, after)
	query.collision_mask = 1 | 16  # the ground, platforms and anything solid on them
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_land(hit["position"])
		return
	global_position = after
	rotation = velocity.angle()
	queue_redraw()


## It strikes someone in its way. A Barrier stops it dead; otherwise it lands on them.
func _on_body(body: Node2D) -> void:
	if _spent or not SpellTargets.affects(body):
		return
	if body.has_shield():
		reflect(Vector2.from_angle(randf() * TAU))  # a Barrier sends it off in a random direction
		return
	_land(SpellTargets.ground_below(get_world_2d(), global_position), global_position)


## The lava lands: the ground under it catches fire, and anything close to where it struck is burned.
func _land(ground: Vector2, struck := Vector2.INF) -> void:
	if _spent:
		return
	_spent = true
	if struck == Vector2.INF:
		struck = ground
	var hazard := Hazard.place(get_parent(), ground, FIRE_WIDTH, FIRE_SECONDS)
	SpellTargets.hurt_within(get_tree(), struck + Vector2(0, -12), REACH, DAMAGE, "Fire", true, true)
	PixelFx.play(get_parent(), struck, "blast_small", 20.0, 1.0, Color.WHITE, true)
	Sfx.play("fire_hit", struck, -6.0)
	queue_free()


## A Gust, Push or Tornado sends the lava off along a new heading, as fast as it was going.
func reflect(direction: Vector2) -> void:
	velocity = direction.normalized() * velocity.length()
	rotation = velocity.angle()
	Sfx.play("push", global_position, -4.0)


## Which way it is flying right now.
func heading() -> Vector2:
	return velocity.normalized()


func damage() -> int:
	return DAMAGE


## The light the ball throws round itself.
func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, 16.0, Color(1.0, 0.5, 0.15, 0.4))
