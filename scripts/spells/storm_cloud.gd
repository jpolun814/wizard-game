class_name StormCloud
extends Node2D

## Storm Cloud: the bumpy line of a cloud's top, drawn in the sky. A pixel-art thundercloud gathers along it and
## rains, and every second it flickers and strikes everyone beneath it with lightning: foes, and you too if you stand
## under it. A wider cloud covers more ground and costs more.

const LIFE := 6.0
const STRIKE_EVERY := 1.0
const WARNING := 0.3     # the cloud flickers this long before each strike
const DAMAGE := 10
const MIN_WIDTH := 80.0
const MAX_WIDTH := 280.0
const HEIGHT := 34.0

var team := "player"
var width := 150.0
var _age := 0.0
var _next := 0.6
var _warning := 0.0
var _puffs: Array = []
const CLOUDS := [preload("res://art/props/cloud_storm_big.png"), preload("res://art/props/cloud_storm_small_1.png"),
		preload("res://art/props/cloud_storm_small_2.png")]


func _ready() -> void:
	width = clampf(width, MIN_WIDTH, MAX_WIDTH)
	add_to_group("danger")
	z_index = 4
	# Clouds side by side along the drawn line, big ones and small ones, slightly out of line.
	var x := -width * 0.5
	var i := 0
	while x < width * 0.5:
		var cloud: Texture2D = CLOUDS[0] if i % 2 == 0 else CLOUDS[1 + (i / 2) % 2]
		_puffs.append({"texture": cloud, "x": x, "y": randi_range(-6, 4)})
		x += cloud.get_width() * 0.6
		i += 1
	Sfx.play("thunder", global_position, -6.0)
	# Rain falling out of the bottom of the cloud.
	var rain := CPUParticles2D.new()
	rain.amount = int(width / 4.0)
	rain.lifetime = 0.7
	rain.position = Vector2(0, HEIGHT * 0.3)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(width * 0.45, 4)
	rain.direction = Vector2(0.1, 1)
	rain.spread = 3.0
	rain.initial_velocity_min = 380.0
	rain.initial_velocity_max = 460.0
	rain.gravity = Vector2.ZERO
	rain.particle_flag_align_y = true
	rain.texture = Fx.tex("trace_01")
	rain.scale_amount_min = 10.0 / Fx.TEX_SIZE
	rain.scale_amount_max = 16.0 / Fx.TEX_SIZE
	rain.color = Color(0.7, 0.8, 1.0, 0.45)
	add_child(rain)
	rain.emitting = true


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFE:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
		set_physics_process(false)
		return
	if _warning > 0.0:
		_warning -= delta
		if _warning <= 0.0:
			_strike()
		return
	_next -= delta
	if _next <= 0.0:
		_next = STRIKE_EVERY
		if not _under().is_empty():
			_warning = WARNING


## Everyone under the cloud the spell can hurt, with nothing solid in between: foes, and whoever cast it. Lightning
## cannot come down through a platform or the ground.
func _under() -> Array:
	return SpellTargets.all(get_tree(), team).filter(func(body: Node2D) -> bool:
		var middle := SpellTargets.center_of(body)
		if not _below(middle):
			return false
		var query := PhysicsRayQueryParameters2D.create(Vector2(middle.x, global_position.y + 10.0), middle)
		query.collision_mask = 1 | 16
		return get_world_2d().direct_space_state.intersect_ray(query).is_empty())


func _below(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= width * 0.5 and point.y > global_position.y and point.y - global_position.y < 520.0


## Lightning comes down on everyone under the cloud at once.
func _strike() -> void:
	var struck := false
	for body in _under():
		var hit_at := SpellTargets.center_of(body)
		var ground := SpellTargets.ground_below(get_world_2d(), hit_at)
		var bolt := PixelFx.play(get_parent(), Vector2(hit_at.x, ground.y + 4.0), "lightning", 24.0, 1.0, Color(1.0, 1.0, 0.85), true)
		bolt.z_index = 3
		SpellTargets.hurt(body, DAMAGE, "Storm", team)
		Fx.impact(get_parent(), hit_at, Color("#ffe85a"), 36.0)
		struck = true
	if struck:
		Sfx.play("spark", global_position + Vector2(0, 120))
		GameCamera.shake_scene(get_tree(), 0.12)


func danger_at(point: Vector2) -> bool:
	return _below(point)


## The clouds, lit up white as they flicker before a strike.
func _draw() -> void:
	var flicker := 0.0
	if _warning > 0.0:
		flicker = 0.5 + 0.5 * sin(_age * 60.0)
	var grow := clampf(_age / 0.4, 0.0, 1.0)
	var light := Color(1, 1, 1).lerp(Color(2.2, 2.2, 2.6), flicker * 0.6)
	for puff in _puffs:
		var cloud: Texture2D = puff["texture"]
		draw_texture(cloud, Vector2(puff["x"], puff["y"] - cloud.get_height() * 0.5), Color(light.r, light.g, light.b, grow))
