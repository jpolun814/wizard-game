class_name Mudslide
extends Node2D

## Mudslide: a U drawn over the ground, the shape of a pit. The ground under it turns to churning sand. Anyone who
## walks into it is dragged down: slowed to a crawl and hurt a little at a time. Flyers pass over it untouched.
## A wider U makes a wider pit.

const LIFE := 99999.0  # the mud stays until the wave ends
const TICK := 0.5
const MIN_WIDTH := 60.0
const MAX_WIDTH := 240.0
const DEPTH := 18.0  # how far above the surface feet can be and still be caught

var team := "player"
var width := 100.0
var _age := 0.0
var _tick := 0.0
var _surface := PackedFloat32Array()  # the ground's height under the pit, sampled across it, relative to the pit
const SAND := preload("res://art/props/quicksand.png")
const SAMPLES := 17  # ground heights taken across the pit, so the mud follows the slope
const SINK_DEPTH := 14.0  # how deep the mud is drawn under its surface


func _ready() -> void:
	width = clampf(width, MIN_WIDTH, MAX_WIDTH)
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	_surface.resize(SAMPLES)
	for i in SAMPLES:
		var x := lerpf(-width * 0.5, width * 0.5, float(i) / (SAMPLES - 1))
		_surface[i] = SpellTargets.solid_below(get_world_2d(), global_position + Vector2(x, -40)).y - global_position.y
	add_to_group("danger")
	add_to_group("lasting")
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	Sfx.play("quicksand", global_position, -4.0)
	Fx.debris(get_parent(), global_position, Color("#c8a46a"), 10, 160.0)
	# Grains of sand bubbling up from the pit.
	var p := CPUParticles2D.new()
	p.amount = int(width / 6.0)
	p.lifetime = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.42, 2)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 120)
	p.texture = Fx.tex("dirt_01")
	p.scale_amount_min = 4.0 / Fx.TEX_SIZE
	p.scale_amount_max = 8.0 / Fx.TEX_SIZE
	p.color = Color(0.85, 0.7, 0.45, 0.9)
	add_child(p)
	p.emitting = true
	# Bubbles of sand rising and popping across the pit.
	for i in maxi(1, int(width / 50.0)):
		var bubbles := PixelFx.sprite("bubbles", 30.0 + i * 5.0)
		bubbles.position = Vector2((i + 0.5) * width / maxi(1, int(width / 50.0)) - width * 0.5, -10.0)
		bubbles.frame = i * 17
		add_child(bubbles)


func _physics_process(delta: float) -> void:
	_age += delta
	_tick -= delta
	queue_redraw()
	var hurt_tick := _tick <= 0.0
	if hurt_tick:
		_tick = TICK
	for body in SpellTargets.all(get_tree(), team):
		if not _caught(body):
			continue
		if body.is_in_group("mobs"):
			body.apply_slow(0.3)
			body.apply_no_jump(0.3)  # the sand holds them down: slowed, and unable to jump
		else:
			body.apply_debuff("sink", 0.3)  # you can walk, slowly, but not jump out
	if _age >= LIFE:
		queue_free()


## True for a walker standing in the pit. Flyers are never caught.
func _caught(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
		return false
	var feet := body.global_position
	var local_x := feet.x - global_position.x
	if absf(local_x) > width * 0.5:
		return false
	var surface := global_position.y + _surface_at(local_x)
	return feet.y >= surface - DEPTH and feet.y <= surface + 6.0


## The ground's height (relative to the pit) at a point across it, from the samples taken when the pit was made.
func _surface_at(local_x: float) -> float:
	var t := clampf((local_x + width * 0.5) / width, 0.0, 1.0) * (SAMPLES - 1)
	var i := mini(int(t), SAMPLES - 2)
	return lerpf(_surface[i], _surface[i + 1], t - i)


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= width * 0.5 + 10.0 and absf(point.y - global_position.y) < 50.0


## The ground turned to pixel-art sand. The mud is drawn as a band that follows the sampled slope of the ground,
## sliding slowly sideways as it churns.
func _draw() -> void:
	if _surface.is_empty():
		return
	var grow := clampf(_age / 0.3, 0.0, 1.0)
	var fade := clampf((LIFE - _age) / 0.6, 0.0, 1.0)
	var half := width * 0.5 * grow
	var scroll := fmod(_age * 6.0, SAND.get_width())
	var top := PackedVector2Array()
	var uvs := PackedVector2Array()
	var edge := PackedVector2Array()
	for i in SAMPLES:
		var x := lerpf(-half, half, float(i) / (SAMPLES - 1))
		var y := _surface_at(x) - 1.0
		top.append(Vector2(x, y))
		uvs.append(Vector2((x + scroll) / SAND.get_width(), 0.0))
	var bottom := PackedVector2Array()
	var bottom_uvs := PackedVector2Array()
	for i in range(SAMPLES - 1, -1, -1):
		var p := top[i] + Vector2(0, SINK_DEPTH)
		bottom.append(p)
		bottom_uvs.append(Vector2(uvs[i].x, SINK_DEPTH / SAND.get_height()))
	edge = top + bottom
	var all_uvs := uvs + bottom_uvs
	draw_polygon(edge, PackedColorArray([Color(1, 1, 1, fade)]), all_uvs, SAND)
