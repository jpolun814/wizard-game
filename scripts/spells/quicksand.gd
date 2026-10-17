class_name Quicksand
extends Node2D

## Quicksand: a U drawn over the ground, the shape of a pit. The ground under it turns to churning sand. Anyone who
## walks into it is dragged down: slowed to a crawl and hurt a little at a time. Flyers pass over it untouched.
## A wider U makes a wider pit.

const LIFE := 5.0
const TICK := 0.5
const DAMAGE := 3
const MIN_WIDTH := 60.0
const MAX_WIDTH := 200.0
const DEPTH := 18.0  # how far above the surface feet can be and still be caught

var team := "player"
var width := 100.0
var _age := 0.0
var _tick := 0.0
const SAND := preload("res://art/props/quicksand.png")


func _ready() -> void:
	width = clampf(width, MIN_WIDTH, MAX_WIDTH)
	global_position = SpellTargets.solid_below(get_world_2d(), global_position + Vector2(0, -40))
	add_to_group("danger")
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	Sfx.play("earth", global_position, -4.0)
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
			body.apply_root(0.12)  # stuck fast while in the sand, barely able to crawl out
		else:
			body.apply_debuff("slow", 0.3)
		if hurt_tick:
			SpellTargets.hurt(body, DAMAGE, "Earth", team)
	if _age >= LIFE:
		queue_free()


## True for a walker standing in the pit. Flyers are never caught.
func _caught(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
		return false
	var feet := body.global_position
	return absf(feet.x - global_position.x) <= width * 0.5 and feet.y >= global_position.y - DEPTH and feet.y <= global_position.y + 6.0


func danger_at(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= width * 0.5 + 10.0 and absf(point.y - global_position.y) < 50.0


## The ground turned to pixel-art sand, sliding slowly sideways as it churns.
func _draw() -> void:
	var grow := clampf(_age / 0.3, 0.0, 1.0)
	var fade := clampf((LIFE - _age) / 0.6, 0.0, 1.0)
	var half := floorf(width * 0.5 * grow)
	var scroll := fmod(_age * 6.0, SAND.get_width())
	draw_texture_rect_region(SAND, Rect2(-half, -3.0, half * 2.0, 14.0), Rect2(scroll, 0, half * 2.0, 14.0), Color(1, 1, 1, fade))
