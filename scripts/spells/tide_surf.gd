class_name TideSurf
extends Node2D

## Tide Surf: a wave rises under the caster and carries them along the ground the way the crest leans, for a few seconds. They can jump
## off it, but cannot stop or turn back. Whoever stands in the front of it is shoved aside, and it washes out flares and burning ground.
## It does no damage. Its origin is the caster's feet.
## The water is real (see LiquidGrid): the wave takes up what water lies at the caster's feet, or, where there is none, brings some up from below,
## and spills it where the ride ends.

const WATER := 2.0           # how much liquid the wave carries (a cell holds 1)
const SECONDS := 4.0
const LENGTH := 150.0        # how far the wave reaches behind its crest
const FRONT := 80.0          # how far ahead of the caster it shoves
const SHOVE := Vector2(620.0, -260.0)
const SHOVE_GAP := 0.8       # seconds before it shoves the same one again
const HEIGHT := 44.0         # how tall the crest stands
const FOAM := Color(0.92, 0.98, 1.0, 0.9)
const WAVE := preload("res://art/fx/water_wave.png")
const WAVE_SIZE := Vector2(176.0, 56.0)

var caster: Wizard  # set by the arena before it enters the tree
var ground: Terrain      # the ground the water will run over when the ride ends
var _carried := 0.0
var direction := 1.0
var _age := 0.0
var _slope := 0.0  # the angle of the ground under the wave, left to right: the wave lies along it
var _shoved := {}  # who it has shoved lately -> seconds until it can again
var _spray: CPUParticles2D
var _sound: AudioStreamPlayer2D  # the sea, heard for as long as the ride lasts


func _ready() -> void:
	add_to_group("lasting")
	z_index = 6
	caster.start_surf(direction, SECONDS)
	_spray = CPUParticles2D.new()
	_spray.amount = 40
	_spray.lifetime = 0.5
	_spray.direction = Vector2(direction * 0.5, -1.0)
	_spray.spread = 40.0
	_spray.initial_velocity_min = 80.0
	_spray.initial_velocity_max = 220.0
	_spray.gravity = Vector2(0, 600)
	_spray.texture = Fx.pixel_drop()
	_spray.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spray.scale_amount_min = 0.8
	_spray.scale_amount_max = 1.4
	_spray.color_ramp = Fx.fade_ramp(Color(0.85, 0.96, 1.0, 0.95))
	_spray.local_coords = false
	_spray.position = Vector2(direction * FRONT * 0.5, -16.0)
	add_child(_spray)
	_spray.emitting = true
	global_position = caster.global_position
	_carried = _take_up()
	_start_sound()


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster) or caster.dead or caster.fainted or _age >= SECONDS or caster.surf_time <= 0.0:
		_end()
		return
	global_position = caster.global_position
	_slope = lerp_angle(_slope, _ground_angle(), minf(1.0, delta * 12.0))
	caster.coat.soak()  # whoever rides the wave is wet
	queue_redraw()
	for body in _shoved.keys():
		_shoved[body] -= delta
		if _shoved[body] <= 0.0 or not is_instance_valid(body):
			_shoved.erase(body)
	var front := Rect2(global_position.x + (0.0 if direction > 0.0 else -FRONT), global_position.y - 90.0, FRONT, 100.0)
	for body in SpellTargets.all(get_tree()):
		if body == caster or _shoved.has(body) or not front.has_point(SpellTargets.center_of(body)):
			continue
		_shoved[body] = SHOVE_GAP
		var impulse := Vector2(SHOVE.x * direction, SHOVE.y)
		if body.is_in_group("mobs"):
			body.knock_back(impulse)
		else:
			body.push(impulse)
			body.coat.soak()  # the wave leaves them wet
		Fx.burst(get_parent(), SpellTargets.center_of(body), FOAM, 8, 140.0, 0.4, true)
	Flare.snuff_near(get_tree(), global_position + Vector2(direction * 40.0, -30.0), 60.0)
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire is Hazard and absf(fire.global_position.x - global_position.x) < LENGTH * 0.5 + fire.width * 0.5 and absf(fire.global_position.y - global_position.y) < 60.0:
			Fx.smoke(get_parent(), fire.global_position, Color(0.85, 0.85, 0.9, 0.6), 4, 20.0, 40.0)
			fire.queue_free()  # a wave over burning ground puts it out


## The slope of the ground under the wave, from the ground a little way behind the wizard and a little way ahead of them (0 on the flat), so the wave lies along a
## hill and does not hang over it or sink into it.
func _ground_angle() -> float:
	var space := get_world_2d().direct_space_state
	var ends := []
	for along in [-LENGTH * 0.4, FRONT * 0.5]:
		var from := global_position + Vector2(along * direction, -50.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 140.0))
		query.collision_mask = 1  # the ground
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return 0.0
		ends.append(hit["position"])
	var run: Vector2 = ends[1] - ends[0]
	if direction < 0.0:
		run = -run
	return clampf(atan2(run.y, run.x), -0.7, 0.7)


## The wave takes up the water at the caster's feet, and makes up what is missing from below.
func _take_up() -> float:
	var area := Rect2(global_position + Vector2(-LENGTH * 0.5, -40.0), Vector2(LENGTH, 60.0))
	var got := 0.0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if not pond.lava and pond.grid != null and pond.region().intersects(area):
			got += pond.draw_off(area, WATER - got)
	return maxf(got, WATER)


## The recording swells and then holds the sea at its fullest for longer than a ride lasts, and is faded out when the ride ends.
func _start_sound() -> void:
	if Sfx.muted:
		return
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = load("res://audio/surf.ogg")
	_sound.bus = Sfx.BUS
	_sound.volume_db = Sfx.VOLUME["surf"]
	_sound.max_distance = Sfx.MAX_DISTANCE
	_sound.attenuation = 0.6
	add_child(_sound)
	_sound.play()


func _end() -> void:
	if _sound != null:
		var quiet := create_tween()
		quiet.tween_property(_sound, "volume_db", -40.0, 0.4)
	if _carried > 0.0 and ground != null:
		Pond.spill(get_parent(), ground, global_position + Vector2(0.0, -6.0), _carried)
		_carried = 0.0
	if is_instance_valid(caster):
		caster.surf_time = 0.0
	_spray.emitting = false
	set_physics_process(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


## The wave: a picture of a curling wave in pixel art (art/fx/water_wave.png, made by tools/wizard_parts/water.py in the pond's colors), tail behind the wizard and
## crest leaning over ahead of them. It rises out of the ground as the ride begins.
func _draw() -> void:
	var rise := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((SECONDS - _age) / 0.4, 0.0, 1.0)
	var tip := FRONT * 0.5 + 24.0  # where the crest ends
	var shown := maxi(int(ceilf(WAVE_SIZE.y * rise)), 1)
	var frame := int(_age * 8.0) % 4
	draw_set_transform(Vector2.ZERO, _slope, Vector2(direction, 1.0))
	draw_texture_rect_region(WAVE, Rect2(Vector2(tip - WAVE_SIZE.x, 6.0 - shown), Vector2(WAVE_SIZE.x, shown)), Rect2(0.0, frame * WAVE_SIZE.y + WAVE_SIZE.y - shown, WAVE_SIZE.x, shown), Color(1.0, 1.0, 1.0, fade))
	draw_set_transform(Vector2.ZERO)
