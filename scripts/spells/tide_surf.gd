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
var _spent := 0.0   # how much of its life the wave has lost to climbing
var _floor := PackedFloat32Array()  # the height of the ground under the wave at points along it (from its tail to its front), relative to the rider's feet
var _shoved := {}  # who it has shoved lately -> seconds until it can again
var _spray: CPUParticles2D
var _sound: AudioStreamPlayer2D  # the sea, heard for as long as the ride lasts


func _ready() -> void:
	_ready_look()
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
		_end(_spent > 0.8 and _age >= SECONDS)
		return
	global_position = caster.global_position
	_read_ground()
	var climb := (_ground_at(0.0) - _ground_at(CREST + ROLL + AHEAD)) / (CREST + ROLL + AHEAD)  # how steeply the ground rises ahead (negative going down)
	if climb >= TOO_STEEP:
		_end(true)  # a wall or a cliff: the wave breaks against it at once
		return
	if climb > 0.12:
		var lost := delta * climb * CLIMB_DRAIN  # water running up a hill gives out sooner, the steeper it is
		_age += lost
		_spent += lost
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


## Reads the ground under the whole length of the wave, a point every `GROUND_STEP` pixels from its tail to its front, so the water lies on a hill, in a dip or at
## a step as it is and does not hang over it or sink into it.
func _read_ground() -> void:
	var space := get_world_2d().direct_space_state
	var count := int((CREST + ROLL + AHEAD - BACK) / GROUND_STEP) + 2
	_floor.resize(count)
	for k in count:
		var along := (BACK + float(k) * GROUND_STEP) * direction
		var from := global_position + Vector2(along, -70.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 190.0))
		query.collision_mask = 1  # the ground
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_floor[k] = NAN  # inside rock, or over a drop: filled in from its neighbors below
			continue
		var bed: float = hit["position"].y
		_floor[k] = clampf(minf(bed, _water_top(Vector2(from.x, bed), from.y)) - global_position.y + 4.0, -60.0, 60.0)
	var here := clampi(int(-BACK / GROUND_STEP), 0, count - 1)  # the point under the rider: a gap takes the value of the nearest point toward it
	if is_nan(_floor[here]):
		_floor[here] = 4.0
	for k in range(here + 1, count):
		if is_nan(_floor[k]):
			_floor[k] = _floor[k - 1]
	for k in range(here - 1, -1, -1):
		if is_nan(_floor[k]):
			_floor[k] = _floor[k + 1]


## Where the water stands over a bed of ground at this x: the wave is water too, so it skids across the top of a pond and does not dip into it. Gives the height of the surface,
## or the bed itself where there is no water over it.
func _water_top(bed: Vector2, from_y: float) -> float:
	var top := bed.y
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if pond.lava or pond.grid == null or not pond.region().has_point(Vector2(bed.x, bed.y - 2.0)):
			continue
		var level := pond.grid.surface_at(bed.x)
		if level < top and level > from_y:
			top = level
	return top


## The height of the ground at a point along the wave (`x` from the rider, toward the front), between the points that were read.
func _ground_at(x: float) -> float:
	if _floor.size() < 2:
		return 4.0
	var spot := clampf((x - BACK) / GROUND_STEP, 0.0, float(_floor.size() - 1))
	var low := int(spot)
	var high := mini(low + 1, _floor.size() - 1)
	return lerpf(_floor[low], _floor[high], spot - float(low))


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


func _end(crashed := false) -> void:
	if is_instance_valid(caster):
		caster.ride_lift(0.0)
		if crashed:  # the wave breaks over the slope: a heap of foam, and the rider is thrown back off it
			var front_at := global_position + Vector2(direction * (CREST + ROLL), -RIDE * 0.5)
			Fx.burst(get_parent(), front_at, FOAM, 22, 220.0, 0.6, true)
			Fx.burst(get_parent(), global_position + Vector2(0.0, -RIDE), FOAM, 10, 140.0, 0.5, true)
			if not caster.dead:
				caster.push(Vector2(-direction * 140.0, -220.0))
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


## The wave is the pond's own water, heaped up and moving: a low surge drawn with the pond's colors, its dithered shading (pixel_liquid.gdshader) and its bright edge on top,
## so it matches the ponds, the Geyser and the Water Jet. It is long and low behind the rider and rolls over at the front, where foam breaks off it and spray is thrown up.
## The surface ripples as it goes. It rises out of the ground as the ride begins and sinks back when it ends.
const BACK := -140.0     # where the surge begins, behind the rider
const CREST := 14.0      # where it is highest, just ahead of the rider
const ROLL := 22.0       # how far the front rolls over and down ahead of the crest
const RIDE := 24.0       # how high the water lifts the rider's feet, at its fullest
const AHEAD := 44.0       # how far past its front the wave reads the ground: it feels a hill coming
const TOO_STEEP := 1.0     # a climb this steep (a rise as long as the run, 45 degrees) and the wave breaks at once
const CLIMB_DRAIN := 5.0   # on a climb the wave spends itself this much faster for each unit of steepness
const GROUND_STEP := 8.0  # the distance between the points where the ground is read
const STEP := 4.0        # the distance between the points of its outline


func _ready_look() -> void:
	var made := ShaderMaterial.new()
	made.shader = preload("res://scripts/terrain/pixel_liquid.gdshader")
	made.set_shader_parameter("levels", 14.0)
	material = made


func _draw() -> void:
	var rise := clampf(_age / 0.35, 0.0, 1.0)
	var fade := clampf((SECONDS - _age) / 0.5, 0.0, 1.0)
	var grow := rise * rise * (3.0 - 2.0 * rise) * fade
	if is_instance_valid(caster):
		caster.ride_lift(RIDE * 0.8 * grow + clampf(4.0 - _ground_at(0.0), 0.0, 60.0))  # the rider stands on top of the water, not in it
	if grow <= 0.01:
		return
	var tide := _age * 6.0
	var top := RIDE * grow * (1.0 + 0.06 * sin(tide))
	var surface := PackedVector2Array()
	var x := BACK
	while x < CREST:
		var along := (x - BACK) / (CREST - BACK)
		var swell := top * pow(along, 1.4)
		var ripple := (sin(x * 0.13 - tide * 1.6) * 1.2 + sin(x * 0.05 - tide) * 1.0) * along * grow
		surface.append(Vector2(x, _ground_at(x) - maxf(swell + ripple, 0.0)))
		x += STEP
	var front := PackedVector2Array()  # the front rolls over and down, a little past straight down at its foot
	for k in 9:
		var t := float(k) / 8.0
		var at_x := CREST + sin(t * PI * 0.5) * ROLL
		front.append(Vector2(at_x, _ground_at(at_x) - top * cos(t * PI * 0.5) - sin(t * PI) * 1.5 * grow))
	var outline := PackedVector2Array(surface)
	outline.append_array(front)
	var body := PackedVector2Array(outline)
	var foot_at := int((CREST + ROLL - BACK) / GROUND_STEP)  # the foot of the body follows the ground back to the tail
	while foot_at >= 0:
		var foot := BACK + float(foot_at) * GROUND_STEP
		body.append(Vector2(minf(foot, CREST + ROLL), _ground_at(foot) + 2.0))
		foot_at -= 1
	var colors := PackedColorArray()
	for point in body:
		var depth := clampf((point.y - (_ground_at(point.x) - top)) / maxf(top, 1.0), 0.0, 1.0)
		var shade := Pond.WATER_TOP.lerp(Pond.WATER_BOTTOM, depth)
		colors.append(Color(shade.r, shade.g, shade.b, 0.92 * grow * clampf((point.x - BACK) / 30.0, 0.2, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, 1.0))
	draw_polygon(body, colors)
	draw_polyline(outline, Color(Pond.WATER_RIM.r, Pond.WATER_RIM.g, Pond.WATER_RIM.b, grow), 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_age * 12.0) * 7919 + 11
	for k in 16:  # foam breaks off the roll at the front and clots along the crest, and is different every moment
		var at := front[rng.randi_range(0, front.size() - 1)] if k < 9 else surface[maxi(surface.size() - 1 - rng.randi_range(0, 8), 0)]
		var size := 2.0 if rng.randf() < 0.7 else 3.0
		var spot := (at + Vector2(rng.randf_range(-2.0, 3.0), rng.randf_range(-3.0, 1.0))).round()
		draw_rect(Rect2(spot, Vector2(size, size)), Color(0.93, 0.98, 1.0, 0.95 * grow))
	for k in 6:  # drops thrown off the front, each one somewhere along its fall
		var life := fposmod(_age * 1.7 + float(k) * 0.167, 1.0)
		var drop := Vector2(CREST + ROLL * 0.7 + 8.0 * life * (1.0 + 0.25 * float(k % 3)), _ground_at(CREST) - top - 4.0 - 14.0 * life + 60.0 * life * life)
		draw_rect(Rect2(drop.round(), Vector2(2.0, 2.0)), Color(0.93, 0.98, 1.0, (1.0 - life) * grow))
	draw_set_transform(Vector2.ZERO)
