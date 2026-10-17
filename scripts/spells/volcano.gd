class_name Volcano
extends Node2D

## A volcano that erupts for a few seconds. A mound of rock heaves up out of the ground with fire roaring from its
## top, and it throws balls of fire in arcs. Each one that lands sets the ground or platform beneath it on fire for
## a while, and burns whatever is standing there. All of it is pixel art: the rock from the cemetery, the flames
## and fireballs from the effect strips.

const LIFE := 4.5
const ERUPT_INTERVAL := 0.45
const GRAVITY := 900.0
const LAVA_DAMAGE := 12
const LAVA_REACH := 30.0
const FIRE_WIDTH := 40.0
const FIRE_SECONDS := 5.0
const CRATER_Y := -78.0  # the top of the mound, where the fire comes out

var team := "player"
var _age := 0.0
var _erupt := 0.0
var _balls: Array = []  # each lava ball is {"pos": world position, "vel": velocity}
var _glow: Node2D
var _mound: Sprite2D
var _ball_frames: SpriteFrames


func _ready() -> void:
	add_to_group("danger")
	Sfx.play("volcano", global_position)
	Fx.debris(get_parent(), global_position, Color("#5a4238"), 12, 200.0)
	GameCamera.shake_scene(get_tree(), 0.3)
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	# The mound heaves up out of the ground, standing on its bottom edge.
	_mound = Sprite2D.new()
	_mound.texture = load("res://art/props/mound.png")
	_mound.offset = Vector2(0, -_mound.texture.get_height() * 0.5 + 3.0)
	_mound.scale = Vector2(1.0, 0.0)
	add_child(_mound)
	create_tween().tween_property(_mound, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fire roars out of its top for as long as it erupts.
	var vent := PixelFx.sprite("flame", 30.0)
	vent.scale = Vector2.ONE * 2.0
	vent.offset = Vector2(0, -PixelArt.FX["flame"]["size"].y * 0.5)
	vent.position = Vector2(0, CRATER_Y + 8.0)
	vent.z_index = 1
	add_child(vent)
	create_tween().tween_property(vent, "modulate:a", 0.0, 0.5).set_delay(LIFE - 0.4)
	PixelFx.play(get_parent(), global_position + Vector2(0, CRATER_Y + 10.0), "blast_fire", 18.0, 1.5, Color.WHITE, true)
	_ball_frames = PixelFx.frames("fireball", 18.0, true)


func _physics_process(delta: float) -> void:
	_age += delta
	_erupt -= delta
	if _age < LIFE and _erupt <= 0.0:
		_erupt = ERUPT_INTERVAL
		_balls.append({"pos": global_position + Vector2(0, CRATER_Y), "vel": Vector2(randf_range(-180.0, 180.0), -480.0), "age": 0.0})
		Fx.smoke(get_parent(), global_position + Vector2(0, CRATER_Y - 20.0), Color(0.2, 0.17, 0.17, 0.6), 2, 26.0, 60.0)
	var flying := []
	for ball in _balls:
		var before: Vector2 = ball["pos"]
		var velocity: Vector2 = ball["vel"] + Vector2(0, GRAVITY * delta)
		var after := before + velocity * delta
		var landing := _landing_between(before, after)
		if landing != Vector2.INF:
			_land(landing)
		else:
			flying.append({"pos": after, "vel": velocity, "age": ball["age"] + delta})
	_balls = flying
	queue_redraw()
	_glow.queue_redraw()
	if _age >= LIFE and _balls.is_empty() and _mound.scale.y > 0.99:
		# The mound sinks back into the ground before it goes.
		var tween := create_tween()
		tween.tween_property(_mound, "scale:y", 0.0, 0.3)
		tween.tween_callback(queue_free)
		set_physics_process(false)


## Where a lava ball crosses the ground between two points, or Vector2.INF if it does not.
func _landing_between(from: Vector2, to: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1 | 16  # the ground and platforms
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector2.INF


## A lava ball lands: the ground catches fire, and anything standing close by is burned.
func _land(point: Vector2) -> void:
	var hazard := Hazard.place(get_parent(), point, "fire", FIRE_WIDTH, FIRE_SECONDS)
	hazard.team = team
	SpellTargets.hurt_within(get_tree(), point + Vector2(0, -12), LAVA_REACH, LAVA_DAMAGE, "Fire", team)
	PixelFx.play(get_parent(), point, "blast_small", 20.0, 1.0, Color.WHITE, true)
	Sfx.play("fire_hit", point, -6.0)


## The mountain and the ground round it are dangerous while it erupts.
func danger_at(point: Vector2) -> bool:
	return _age < LIFE and absf(point.x - global_position.x) < 110.0 and point.y > global_position.y - 120.0


## The fireballs in flight, each turned along its path.
func _draw() -> void:
	for ball in _balls:
		var local: Vector2 = ball["pos"] - global_position
		var vel: Vector2 = ball["vel"]
		var frame := _ball_frames.get_frame_texture("default", int(ball["age"] * 18.0) % _ball_frames.get_frame_count("default"))
		draw_set_transform(local, vel.angle(), Vector2.ONE)
		draw_texture(frame, -frame.get_size() * 0.5 - Vector2(18, 0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The light the eruption throws: a glow over the crater, and one round each fireball.
func _draw_glow() -> void:
	if _age < LIFE:
		_glow.draw_circle(Vector2(0, CRATER_Y), 30.0 + 4.0 * sin(_age * 6.0), Color(1.0, 0.45, 0.15, 0.12))
	for ball in _balls:
		Fx.draw_glow(_glow, ball["pos"] - global_position, 16.0, Color(1.0, 0.5, 0.15, 0.4))
