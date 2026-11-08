class_name FlamingSphere
extends CharacterBody2D

## Flaming Sphere: a ball of fire that rolls along the ground the way the stroke ran. It follows slopes, falls into pits, climbs a wall that stands
## in its way and rolls on over the top, burns whoever it touches (the caster too), and goes out in water, in rain, or after a long roll.
## It is drawn as a swirling ball of fire that turns as it rolls, that leaves licks of flame behind it. It is a fire like any other: it lights, melts and is avoided by everything else (see SpellTargets.fire_points), and water quenches it.
## It is a "ground_watchers" thing, so the world keeps the rock round it made even when no wizard is near (see World._process).

const SPEED := 170.0
const GRAVITY := 1500.0
const FALL_MAX := 900.0
const CLIMB := 130.0           # how fast it goes up a wall
const CLIMB_LIMIT := 4.0       # seconds up a wall before it gives up and turns back (a wall with no top)
const RADIUS := 14.0
const SUN: Texture2D = preload("res://art/fx/sun.png")  # the ball is a sun, which turns as it rolls
const REACH := 4300.0          # how far it rolls before it burns out: about a hundred and thirty tiles
const BURN := 35               # one heavy blow, not a burn that ticks: the sphere rolls on and leaves them behind
const BURN_GAP := 1.5          # seconds before it can strike the same one again: a victim thrown up lands in its path and meets it again
const KNOCK := Vector2(430.0, -430.0)  # how it throws whoever it strikes, away from the way it rolls and up
const STEEP := 0.8             # a face whose normal is this sideways or more is a wall to climb, not a slope to roll up
const RAIN_LEVEL := 0.35
const PUFF_GAP := 0.07         # seconds between the licks of flame it leaves behind

var direction := 1.0
var caster: Wizard
var _rolled := 0.0
var _climbing := 0.0
var _burnt := {}               # who it has burned lately -> seconds until it can again
var _out := false
var _turn := 0.0               # the turn of the ball, for the glow of its heart
var _sun: Sprite2D
var _age := 0.0
var _puff := 0.0


func _ready() -> void:
	material = Fx.additive()  # fire adds light to what is behind it: its glow is drawn on this node, as the Firewall's and the lava's are
	add_to_group("fires")
	add_to_group("danger")
	add_to_group("ground_watchers")
	collision_layer = 0
	collision_mask = 1 | 16
	floor_snap_length = 14.0
	floor_max_angle = deg_to_rad(65.0)
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_sun = Sprite2D.new()
	_sun.texture = SUN
	_sun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sun.material = Fx.additive()  # it adds light to what is behind it, so it blazes
	add_child(_sun)
	Sfx.play("fire_hit", global_position, -8.0)


func _physics_process(delta: float) -> void:
	if _out:
		return
	_age += delta
	var rain := _under_rain()
	var wet := _in_water()
	if rain or wet or _rolled >= REACH or (ArenaGen.world_size.y > 0 and global_position.y > ArenaGen.world_size.y * float(ArenaGen.TILE)):
		_go_out(rain or wet)
		return
	for who in _burnt.keys():
		_burnt[who] -= delta
		if _burnt[who] <= 0.0:
			_burnt.erase(who)
	_move(delta)
	_burn()
	_turn += direction * delta * SPEED / RADIUS
	_sun.rotation = _turn
	_puff -= delta
	if _puff <= 0.0:
		_puff = PUFF_GAP
		PixelFx.play(get_parent(), global_position + Vector2(-direction * 7.0, RADIUS * 0.5), "fire_puff", 14.0, 0.5, Color(1.0, 1.0, 1.0, 0.9), true, false, true)  # a lick of flame is left behind it
	_sun.scale = Vector2.ONE * (1.0 + 0.07 * sin(_age * 17.0))  # it flares and sinks
	queue_redraw()


## Rolls on, climbs a wall that blocks it, falls when there is nothing under it.
func _move(delta: float) -> void:
	var before := global_position
	var wall := KinematicCollision2D.new()
	var blocked := test_move(global_transform, Vector2(direction * 3.0, 0.0), wall) and absf(wall.get_normal().x) >= STEEP
	if blocked and not test_move(global_transform, Vector2(0.0, -4.0)):
		_climbing += delta
		if _climbing > CLIMB_LIMIT:
			direction = -direction  # it cannot find the top: it turns back
			_climbing = 0.0
			return
		velocity = Vector2(direction * 20.0, -CLIMB)  # up the face, pressed to it
	else:
		_climbing = 0.0
		velocity.x = direction * SPEED
		velocity.y = minf(velocity.y + GRAVITY * delta, FALL_MAX)
		if is_on_floor():
			velocity.y = maxf(velocity.y, 0.0)
	move_and_slide()
	_rolled += global_position.distance_to(before)


## Strikes every wizard and enemy it touches, hard, and throws them off ahead of it. Once in a while for each.
func _burn() -> void:
	for body: Node2D in SpellTargets.all(get_tree()):
		if not SpellTargets.affects(body) or _burnt.has(body.get_instance_id()):
			continue
		if SpellTargets.center_of(body).distance_to(global_position) < RADIUS + 18.0:
			_burnt[body.get_instance_id()] = BURN_GAP
			SpellTargets.hurt(body, BURN, "Fire", false, true, self)
			var throw := Vector2(direction * KNOCK.x, KNOCK.y)
			if body.has_method("knock_back"):  # (an enemy, whatever group it is in just now)
				body.knock_back(throw)
			elif body.has_method("push"):
				body.push(throw)


func _under_rain() -> bool:
	for squall: Squall in get_tree().get_nodes_in_group("squalls"):
		if squall.rain and squall.level() > RAIN_LEVEL:
			var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, -900.0))
			query.collision_mask = 1 | 16
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				return true  # nothing over it: the rain falls on it
	return false


func _in_water() -> bool:
	var pond := Pond.water_near(get_tree(), global_position)
	return pond != null and pond.wet_at(global_position)


## Put out by water or cold.
func quench() -> void:
	_go_out(true)


func _go_out(steam: bool) -> void:
	if _out:
		return
	_out = true
	remove_from_group("fires")
	remove_from_group("danger")
	remove_from_group("ground_watchers")
	Fx.smoke(get_parent(), global_position, Color(0.88, 0.92, 0.96, 0.7) if steam else Color(0.3, 0.25, 0.25, 0.6), 5, 22.0, 60.0 if steam else 20.0)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


func danger_at(point: Vector2) -> bool:
	return not _out and point.distance_to(global_position) < RADIUS + 20.0


func _draw() -> void:
	Fx.draw_glow(self, Vector2.ZERO, RADIUS * 3.0, Color(1.0, 0.45, 0.1, 0.28))
	Fx.draw_glow(self, Vector2.ZERO, RADIUS * 1.7, Color(1.0, 0.6, 0.2, 0.55))
	Fx.draw_glow(self, Vector2.from_angle(_turn) * RADIUS * 0.35, RADIUS * 0.8, Color(1.0, 0.9, 0.5, 0.8))
