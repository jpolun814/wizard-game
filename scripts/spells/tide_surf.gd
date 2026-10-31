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

var caster_node: Wizard  # set by the arena before it enters the tree
var ground: Terrain      # the ground the water will run over when the ride ends
var _carried := 0.0
var direction := 1.0
var _age := 0.0
var _shoved := {}  # who it has shoved lately -> seconds until it can again
var _spray: CPUParticles2D


func _ready() -> void:
	add_to_group("lasting")
	z_index = 6
	caster_node.start_surf(direction, SECONDS)
	_spray = CPUParticles2D.new()
	_spray.amount = 40
	_spray.lifetime = 0.5
	_spray.direction = Vector2(direction * 0.5, -1.0)
	_spray.spread = 40.0
	_spray.initial_velocity_min = 80.0
	_spray.initial_velocity_max = 220.0
	_spray.gravity = Vector2(0, 600)
	_spray.texture = Geyser.DROPLET
	_spray.scale_amount_min = 0.25
	_spray.scale_amount_max = 0.5
	_spray.color_ramp = Fx.fade_ramp(Color(0.85, 0.96, 1.0, 0.95))
	_spray.local_coords = false
	_spray.position = Vector2(direction * FRONT * 0.5, -16.0)
	add_child(_spray)
	_spray.emitting = true
	global_position = caster_node.global_position
	_carried = _take_up()
	Sfx.play("surf", global_position)


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster_node) or caster_node.dead or caster_node.fainted or _age >= SECONDS or caster_node.surf_time <= 0.0:
		_end()
		return
	global_position = caster_node.global_position
	queue_redraw()
	for body in _shoved.keys():
		_shoved[body] -= delta
		if _shoved[body] <= 0.0 or not is_instance_valid(body):
			_shoved.erase(body)
	var front := Rect2(global_position.x + (0.0 if direction > 0.0 else -FRONT), global_position.y - 90.0, FRONT, 100.0)
	for body in SpellTargets.all(get_tree()):
		if body == caster_node or _shoved.has(body) or not front.has_point(SpellTargets.center_of(body)):
			continue
		_shoved[body] = SHOVE_GAP
		var impulse := Vector2(SHOVE.x * direction, SHOVE.y)
		if body.is_in_group("mobs"):
			body.knock_back(impulse)
		else:
			body.push(impulse)
		Fx.burst(get_parent(), SpellTargets.center_of(body), FOAM, 8, 140.0, 0.4, true)
	Flare.snuff_near(get_tree(), global_position + Vector2(direction * 40.0, -30.0), 60.0)
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire is Hazard and absf(fire.global_position.x - global_position.x) < LENGTH * 0.5 + fire.width * 0.5 and absf(fire.global_position.y - global_position.y) < 60.0:
			Fx.smoke(get_parent(), fire.global_position, Color(0.85, 0.85, 0.9, 0.6), 4, 20.0, 40.0)
			fire.queue_free()  # a wave over burning ground puts it out


## The wave takes up the water at the caster's feet, and makes up what is missing from below.
func _take_up() -> float:
	var area := Rect2(global_position + Vector2(-LENGTH * 0.5, -40.0), Vector2(LENGTH, 60.0))
	var got := 0.0
	for pond: Pond in get_tree().get_nodes_in_group("ponds"):
		if not pond.lava and pond.grid != null and pond.region().intersects(area):
			got += pond.draw_off(area, WATER - got)
	return maxf(got, WATER)


func _end() -> void:
	if _carried > 0.0 and ground != null:
		Pond.spill(get_parent(), ground, global_position + Vector2(0.0, -6.0), _carried)
		_carried = 0.0
	if is_instance_valid(caster_node):
		caster_node.surf_time = 0.0
	_spray.emitting = false
	set_physics_process(false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


## The wave, drawn the way the ponds draw their water (see Pond): a swell that rises behind the wizard to a crest that leans over ahead of
## them, shaded from light at the top to dark below, with a bright edge along the top. It rises as the ride begins.
func _draw() -> void:
	var rise := clampf(_age / 0.25, 0.0, 1.0)
	var fade := clampf((SECONDS - _age) / 0.4, 0.0, 1.0)
	var tip := FRONT * 0.5 + 24.0  # where the crest ends
	var top := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var u := lerpf(-LENGTH, tip, float(i) / steps)
		var swell := 10.0 + (HEIGHT - 10.0) * smoothstep(-LENGTH, tip - 20.0, u)
		if u > tip - 20.0:
			swell = lerpf(HEIGHT, HEIGHT * 0.55, smoothstep(tip - 20.0, tip, u))  # the crest curls over and drops away
		swell += sin(_age * 9.0 + u * 0.12) * 2.5
		top.append(Vector2(u * direction, 6.0 - swell * rise))
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for point in top:
		points.append(point)
		colours.append(Pond.WATER_TOP.lerp(Pond.WATER_RIM, clampf((6.0 - point.y) / HEIGHT, 0.0, 1.0) * 0.25))
	var foot := Vector2(top[top.size() - 1].x, 6.0)
	points.append(foot)
	colours.append(Pond.WATER_BOTTOM)
	points.append(Vector2(top[0].x, 6.0))
	colours.append(Pond.WATER_BOTTOM)
	for c in colours.size():
		colours[c].a = fade
	draw_polygon(points, colours)
	var edge := Pond.WATER_RIM
	edge.a = fade
	draw_polyline(top, edge, 2.0)
	# Foam on the crest.
	var foam := FOAM
	foam.a = fade
	draw_polyline(top.slice(top.size() - 7), foam, 3.0)
