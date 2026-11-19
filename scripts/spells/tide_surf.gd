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


## The wave is not a picture: it is drawn every frame as a body of water, pixel by pixel in the pond's colors. A swell of columns rises behind the rider to a wall, and
## a lip of water curls over from the top of the wall and forward, with a hollow under it where the rider stands. Nothing in it holds still: the height of the swell
## breathes, ripples run up its back, the lip's edge is thrown about and foam clots and breaks off it, and the spray at its tip falls away behind. It rises out
## of the ground as the ride begins and sinks back when it ends.
const SKIN := Color(0.60, 0.78, 0.88)    # the lit surface
const BODY := Color(0.23, 0.43, 0.59)    # the water just under it
const DEEP := Color(0.05, 0.10, 0.24)    # the water at the bottom
const BACK := -150.0     # where the swell begins, behind the rider
const WALL := -16.0      # where the back wall of the barrel stands
const COLUMN := 2.0      # the width of a column of water: two world pixels, as a pixel of the pond's art


func _draw() -> void:
	var rise := clampf(_age / 0.35, 0.0, 1.0)
	var fade := clampf((SECONDS - _age) / 0.5, 0.0, 1.0)
	var grow := rise * rise * (3.0 - 2.0 * rise) * fade
	if grow <= 0.01:
		return
	var tide := _age * 7.0
	var top := (HEIGHT + 30.0) * grow * (1.0 + 0.07 * sin(tide) + 0.04 * sin(tide * 2.3 + 1.0))
	draw_set_transform(Vector2.ZERO, _slope, Vector2(direction, 1.0))
	var x := BACK
	while x < WALL:
		var along := (x - BACK) / (WALL - BACK)
		# the swell climbs slowly and then steeply, and ripples run up it toward the crest
		var ripple := sin(x * 0.11 - tide * 1.7) * 1.6 * along + sin(x * 0.047 - tide) * 1.2 * along
		var height := maxf(top * pow(along, 1.6) + ripple * grow, 0.0)
		var low := 6.0
		var high := roundf((low - height) / COLUMN) * COLUMN
		_column(x, high, low, grow)
		x += COLUMN
	# the wall of the barrel: a curved edge of lit water from the foot of the swell up to the lip, rippling as it goes
	var y := 6.0
	while y > -top + 18.0 * grow:
		var up := (6.0 - y) / maxf(top, 1.0)
		var bend := -7.0 * sin(up * PI * 0.9) + 1.5 * sin(y * 0.3 - tide * 2.0)
		draw_rect(Rect2(roundf(WALL + bend), roundf(y), 3.0, 2.0), Color(SKIN.r, SKIN.g, SKIN.b, 0.9 * grow))
		draw_rect(Rect2(roundf(WALL + bend) - 4.0, roundf(y), 4.0, 2.0), Color(BODY.r, BODY.g, BODY.b, 0.7 * grow))
		y -= 2.0
	_lip(top, tide, grow)
	draw_set_transform(Vector2.ZERO)


## One column of the swell: bright at the top, going deeper and darker toward the ground, and thinning to nothing at the foot.
func _column(x: float, high: float, low: float, grow: float) -> void:
	if low - high < 2.0:
		return
	var points := PackedVector2Array([Vector2(x, high), Vector2(x + COLUMN, high), Vector2(x + COLUMN, low), Vector2(x, low)])
	var skin := Color(SKIN.r, SKIN.g, SKIN.b, 0.95 * grow)
	var body := Color(BODY.r, BODY.g, BODY.b, 0.93 * grow)
	var deep := Color(DEEP.r, DEEP.g, DEEP.b, 0.8 * grow)
	var skin_depth := minf(4.0, low - high)
	draw_colored_polygon(PackedVector2Array([Vector2(x, high), Vector2(x + COLUMN, high), Vector2(x + COLUMN, high + skin_depth), Vector2(x, high + skin_depth)]), skin)
	var colors := PackedColorArray([body, body, deep, deep])
	draw_polygon(PackedVector2Array([Vector2(x, high + skin_depth), Vector2(x + COLUMN, high + skin_depth), points[2], points[3]]), colors)
	if int(x / COLUMN + _age * 9.0) % 7 == 0 and low - high > 12.0:  # bright flecks slide up the face
		var y := high + 6.0 + fposmod(x * 3.7 - _age * 40.0, maxf(low - high - 10.0, 1.0))
		draw_rect(Rect2(x, roundf(y), COLUMN * 2.0, 1.0), Color(SKIN.r, SKIN.g, SKIN.b, 0.7 * grow))


## The lip: a curl of water from the top of the wall over and forward and down, thrown about as it goes, with foam on its outer edge and drops on its tip.
func _lip(top: float, tide: float, grow: float) -> void:
	var seed := int(_age * 14.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 17
	var centre := Vector2(WALL + 22.0, -top + 24.0 * grow)
	var radius := 24.0 * grow * (1.0 + 0.06 * sin(tide * 1.3))
	var steps := 34
	for k in steps:
		var t := float(k) / float(steps - 1)
		var angle := deg_to_rad(lerpf(-168.0, 52.0, t) + 5.0 * sin(tide + t * 6.0))
		var jitter := Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6)) * (0.4 + t)
		var at := centre + Vector2(cos(angle), sin(angle)) * (radius + 2.0 * sin(t * 9.0 - tide * 2.0)) + jitter
		var thick := lerpf(7.0, 2.0, t) * grow  # the curl is thick where it leaves the wall and thins to a tip
		at = (at / 1.0).round()
		draw_rect(Rect2(at - Vector2(thick, thick) * 0.5, Vector2(thick, thick)), Color(BODY.r, BODY.g, BODY.b, 0.9 * grow))
		draw_rect(Rect2(at - Vector2(thick, thick) * 0.5, Vector2(thick, 2.0)), Color(SKIN.r, SKIN.g, SKIN.b, 0.95 * grow))
		if rng.randf() < 0.55:  # foam on the outside of the curl, clotting and breaking
			var out := at + Vector2(cos(angle), sin(angle)) * (thick * 0.5 + 1.0)
			var size := 2.0 if rng.randf() < 0.7 else 3.0
			draw_rect(Rect2(out.round() - Vector2(size, size) * 0.5, Vector2(size, size)), Color(0.93, 0.98, 1.0, 0.95 * grow))
	# drops thrown off the tip: each one is somewhere along its fall, and the fall begins again as it lands
	for k in 7:
		var life := fposmod(_age * 1.6 + float(k) * 0.143, 1.0)
		var start := centre + Vector2(cos(deg_to_rad(52.0)), sin(deg_to_rad(52.0))) * radius
		var drop := start + Vector2(10.0 * life * (1.0 + 0.3 * float(k % 3)), -14.0 * life + 70.0 * life * life)
		draw_rect(Rect2(drop.round(), Vector2(2.0, 2.0)), Color(0.93, 0.98, 1.0, (1.0 - life) * grow))


