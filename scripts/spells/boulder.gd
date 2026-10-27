class_name Boulder
extends RigidBody2D

## A boulder from Earth Fall. It drops onto the ground, hurting whoever is under it, then stays where it lands: it rolls
## downhill, can be shoved by a Push, and is solid until enough shots have struck it that it crumbles.

const RADIUS := 18.0
const LANDING_RADIUS := 36.0
const LANDING_DAMAGE := 30
const BREAKING_BLOW := 60.0  # what it takes off a wall or a plug of ice where it lands
const HEALTH := 63.0  # the same as a default stone wall (45% of its length)
const ROCK := preload("res://art/fx/rock.png")

var _health := HEALTH
var _landed := false
var _speed := 0.0  # how fast it was moving last frame, which is how hard it hits
var _last_bump := {}  # when each body was last bumped, so one push does not hurt it every frame


func _ready() -> void:
	add_to_group("rocks")
	add_to_group("breakables")
	collision_layer = 1  # solid, like the ground: walkers and shots meet it
	collision_mask = 1 | 2 | 4  # it rests on the ground, rolls down slopes, and bumps walkers and the player
	mass = 4.0
	var physics := PhysicsMaterial.new()
	physics.friction = 0.6
	physics.bounce = 0.0
	physics_material_override = physics
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_contact)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = ROCK
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 3.0  # a whole-number scale keeps the pixels crisp
	add_child(sprite)
	var strike_zone := Area2D.new()
	var zone := CollisionShape2D.new()
	var reach := CircleShape2D.new()
	reach.radius = RADIUS + 4.0
	zone.shape = reach
	strike_zone.add_child(zone)
	strike_zone.collision_mask = 1  # shots live on layer 1
	strike_zone.area_entered.connect(_on_struck)
	add_child(strike_zone)


func _physics_process(_delta: float) -> void:
	_speed = linear_velocity.length()


## A walker or the player it bumps takes damage in proportion to how fast it was moving, your own boulder included. The first time it touches the
## ground, it hurts whoever is under it.
func _on_contact(body: Node) -> void:
	if body.is_in_group("mobs") or body.is_in_group("player"):
		var now := Time.get_ticks_msec()
		if _speed < 120.0 or now - int(_last_bump.get(body, -10000)) < 600:
			return
		_last_bump[body] = now
		SpellTargets.hurt(body, clampi(int(_speed / 40.0), 4, 40), "Earth")
		return
	if _landed:
		return
	_landed = true
	SpellTargets.hurt_within(get_tree(), global_position, LANDING_RADIUS, LANDING_DAMAGE, "Earth")
	Fx.debris(get_parent(), global_position, Color("#9c7a52"), 12, 200.0)
	Fx.smoke(get_parent(), global_position, Color(0.45, 0.38, 0.3, 0.5), 5, 30.0, 30.0)
	Sfx.play("quake", global_position)
	GameCamera.shake_scene(get_tree(), 0.5)
	for thing in get_tree().get_nodes_in_group("breakables"):
		if thing is IcePlug or thing is RockWall:  # it breaks a plug of ice, or brings a wall down, where it lands
			thing.take_blow_near(global_position + Vector2(0, RADIUS), BREAKING_BLOW)


## A Push shoves it like anything else that is loose.
func push(impulse: Vector2) -> void:
	apply_central_impulse(impulse * 2.5)  # a Push sends a boulder rolling, not just nudged


## Enemy shots and spells that reach it take some of its health.
func _on_struck(area: Area2D) -> void:
	var damage := SpellTargets.shot_damage(area)
	if damage <= 0:
		return
	_take_blow(damage, area.global_position)


## A club swung near the boulder takes its blow. True when the swing reached it.
func take_blow_near(point: Vector2, damage: float) -> bool:
	if global_position.distance_to(point) > RADIUS + 22.0:
		return false
	_take_blow(damage, point)
	return true


func _take_blow(damage: float, at: Vector2) -> void:
	_health -= damage
	if _health <= 0.0:
		Fx.debris(get_parent(), global_position, Color("#6b5a48"), 16, 220.0)
		Sfx.play("stones", global_position)
		queue_free()
	else:
		Fx.debris(get_parent(), at, Color("#6b5a48"), 5, 120.0)
		Sfx.play("stones", global_position, -6.0)
