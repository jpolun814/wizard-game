class_name Tsunami
extends Node2D

## Tsunami: a wall of water sweeps the whole map, the way the crest you drew curls. It puts out every fire, washes away
## smoke and spores, sinks lily pads, and shoves everyone in it a long way, the caster included. High ground (a hill or
## a ledge above the water), a wall or tree in its way, or flying keeps you out of it.

const SPEED := 780.0
const HEIGHT := 125.0      # how high the water stands above the flat ground line
const THICKNESS := 260.0   # how far the wave reaches back from its front
const PUSH := 900.0
const SHELTER_REACH := 200.0  # something solid this close upstream of a body shelters it

var direction := 1.0  # 1 runs right, -1 runs left; set before the wave enters the tree
var _front := 0.0
var _t := 0.0
var _foam: CPUParticles2D
var _splashes: Array[AnimatedSprite2D] = []


func _ready() -> void:
	add_to_group("lasting")
	add_to_group("danger")
	z_index = 7
	_front = ArenaGen.left_edge() - 40.0 if direction > 0.0 else ArenaGen.right_edge() + 40.0
	global_position = Vector2(_front, ArenaGen.GROUND_Y)
	# White foam churning along the top of the water and at its front.
	_foam = CPUParticles2D.new()
	_foam.amount = 60
	_foam.lifetime = 0.6
	_foam.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_foam.emission_rect_extents = Vector2(THICKNESS * 0.5, HEIGHT * 0.3)
	_foam.position = Vector2(-direction * THICKNESS * 0.5, -HEIGHT * 0.55)
	_foam.direction = Vector2.UP
	_foam.spread = 70.0
	_foam.initial_velocity_min = 20.0
	_foam.initial_velocity_max = 90.0
	_foam.gravity = Vector2(0, 160)
	_foam.local_coords = true
	_foam.texture = Fx.tex("circle_05")
	_foam.scale_amount_min = 6.0 / Fx.TEX_SIZE
	_foam.scale_amount_max = 16.0 / Fx.TEX_SIZE
	_foam.color_ramp = Fx.fade_ramp(Color(0.95, 1.0, 1.0, 0.85))
	add_child(_foam)
	_foam.emitting = true
	# Real splash sprites riding the crest.
	for i in 4:
		var splash := PixelFx.sprite("splash", 10.0 + i)
		splash.scale = Vector2(2.0, 2.0)
		splash.position = Vector2(-direction * i * THICKNESS * 0.22, -HEIGHT * 0.9)
		splash.flip_h = direction < 0.0
		add_child(splash)
		_splashes.append(splash)
	Sfx.play("quake", Vector2(_front, ArenaGen.GROUND_Y), 2.0)
	Sfx.play("push", null, 2.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_front += direction * SPEED * delta
	global_position.x = _front
	queue_redraw()
	GameCamera.shake_scene(get_tree(), 0.04)
	var region := _region()
	_sweep_bodies()
	_douse_fires(region)
	for cloud in get_tree().get_nodes_in_group("clouds"):
		if region.has_point(cloud.global_position):
			cloud.dissipate()
	for pad in get_tree().get_nodes_in_group("lily_pads"):
		if region.has_point(pad.global_position):
			pad.sink()
	for item in get_tree().get_nodes_in_group("items"):
		if region.has_point(item.global_position):
			item.knock(Vector2(direction * PUSH * 0.6, -120.0))
	for rock in get_tree().get_nodes_in_group("rocks"):
		if region.has_point(rock.global_position):
			rock.push(Vector2(direction * PUSH * 0.6, 0.0))
	var gone: bool = _front > ArenaGen.right_edge() + THICKNESS + 40.0 if direction > 0.0 else _front < ArenaGen.left_edge() - THICKNESS - 40.0
	if gone:
		queue_free()


## The water's box: from its front back by its thickness, standing HEIGHT above the flat ground line and down below.
func _region() -> Rect2:
	var back := _front - direction * THICKNESS
	var left := minf(_front, back)
	return Rect2(left, ArenaGen.GROUND_Y - HEIGHT, THICKNESS, HEIGHT + 600.0)


func _sweep_bodies() -> void:
	var region := _region()
	for body in SpellTargets.all(get_tree()):
		var middle := SpellTargets.center_of(body)
		if not region.has_point(middle) or _sheltered(middle):
			continue
		if body.is_in_group("mobs"):
			body.knock_back(Vector2(direction * PUSH, -60.0))
		else:
			body.push(Vector2(direction * PUSH, -40.0))


## True when something solid stands between the wave and a point: a hill, a stone wall, a tree, a boulder.
func _sheltered(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(point - Vector2(direction * SHELTER_REACH, 0.0), point)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Every fire the water reaches goes out in a puff of steam.
func _douse_fires(region: Rect2) -> void:
	for fire in get_tree().get_nodes_in_group("fires"):
		if fire is Pond or not region.has_point(fire.global_position):
			continue
		Fx.smoke(get_parent(), fire.global_position, Color(0.9, 0.95, 1.0, 0.6), 4, 24.0, 40.0)
		fire.queue_free()


func danger_at(point: Vector2) -> bool:
	return _region().has_point(point)


## The wave: a body that is lighter at the top and deeper below, a foamy wavy top, and a crest curling over at its front.
func _draw() -> void:
	var foam := Color(0.95, 1.0, 1.0, 0.95)
	var top := PackedVector2Array()
	var steps := 16
	for i in steps + 1:
		var x := -direction * THICKNESS * i / steps
		var swell := sin(_t * 5.0 + i * 0.9) * 4.0
		var rise := HEIGHT * clampf(0.55 + 0.45 * float(i) / 4.0, 0.0, 1.0)  # the front is lower, rising to its full height behind
		top.append(Vector2(x, -rise + swell))
	var body := PackedVector2Array(top)
	body.append(Vector2(-direction * THICKNESS, 60.0))
	body.append(Vector2(0.0, 60.0))
	var colours := PackedColorArray()
	for i in body.size():
		var shade := clampf((body[i].y + HEIGHT) / (HEIGHT + 60.0), 0.0, 1.0)  # 0 at the top, 1 at the bottom
		colours.append(Color(0.45, 0.78, 0.98, 0.62).lerp(Color(0.12, 0.34, 0.68, 0.78), shade))
	draw_polygon(body, colours)
	draw_polyline(top, foam, 4.0)
	# The crest, a thick curl of foam over the front.
	var crest := PackedVector2Array()
	for k in 11:
		var a := deg_to_rad(-150.0 + k * 22.0)
		crest.append(Vector2(direction * (cos(a) * 34.0 - 8.0), top[0].y - 16.0 + sin(a) * 34.0))
	draw_polyline(crest, foam, 5.0)
