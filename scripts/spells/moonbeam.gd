class_name Moonbeam
extends Node2D

## Moonbeam: a pale light falling from the sky onto the ground where the line was drawn, dim as the moon's. It shows what is hidden in the dark
## near it, but not far, and it burns nothing. It lasts half a minute. Its origin is on the ground.

const SECONDS := 30.0
const LIGHT_RADIUS := 230.0  # dimmer and narrower than a flare's
const BEAM_HEIGHT := 520.0
const BEAM_WIDTH := 64.0
const PALE := Color(0.72, 0.82, 1.0)

var light_radius := LIGHT_RADIUS
var _age := 0.0


func _ready() -> void:
	add_to_group("moonbeams")
	add_to_group("lights")
	add_to_group("lasting")
	z_index = 4
	if get_tree().get_first_node_in_group("darkness") != null:
		var light := PointLight2D.new()
		light.texture = Fx.tex("light_01")
		light.texture_scale = light_radius * 2.0 / Fx.TEX_SIZE
		light.color = PALE
		light.energy = 0.7
		light.shadow_enabled = false
		light.position = Vector2(0, -30)
		add_child(light)
	# Motes of dust drifting down in the beam.
	var motes := CPUParticles2D.new()
	motes.amount = 16
	motes.lifetime = 3.0
	motes.position = Vector2(0, -BEAM_HEIGHT * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(BEAM_WIDTH * 0.4, BEAM_HEIGHT * 0.5)
	motes.direction = Vector2.DOWN
	motes.spread = 20.0
	motes.initial_velocity_min = 6.0
	motes.initial_velocity_max = 16.0
	motes.gravity = Vector2.ZERO
	motes.texture = Fx.tex("circle_05")
	motes.scale_amount_min = 2.0 / Fx.TEX_SIZE
	motes.scale_amount_max = 4.0 / Fx.TEX_SIZE
	motes.color_ramp = Fx.fade_ramp(Color(PALE.r, PALE.g, PALE.b, 0.7))
	add_child(motes)
	Sfx.play("gravity", global_position, -12.0)
	Fx.burst(get_parent(), global_position, PALE, 8, 60.0, 0.6, true)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS:
		queue_free()
		return
	queue_redraw()


## A column of pale light, brightest where it meets the ground and thinning toward the sky, with a pool of light at its foot.
func _draw() -> void:
	var fade := clampf(_age / 0.6, 0.0, 1.0) * clampf((SECONDS - _age) / 1.5, 0.0, 1.0)
	var shimmer := 0.9 + 0.1 * sin(_age * 2.0)
	var clear := Color(PALE.r, PALE.g, PALE.b, 0.0)
	for layer in 6:  # nested columns, each narrower and a little brighter, so the beam has no hard edge
		var share := 1.0 - layer / 6.0
		var half := BEAM_WIDTH * 0.5 * share
		var strong := Color(PALE.r, PALE.g, PALE.b, 0.05 * fade * shimmer)
		draw_polygon(PackedVector2Array([Vector2(-half * 0.6, -BEAM_HEIGHT * (0.5 + 0.5 * share)), Vector2(half * 0.6, -BEAM_HEIGHT * (0.5 + 0.5 * share)), Vector2(half, 0), Vector2(-half, 0)]), PackedColorArray([clear, clear, strong, strong]))
	Fx.draw_glow(self, Vector2(0, -6), light_radius * 0.45, Color(PALE.r, PALE.g, PALE.b, 0.16 * fade * shimmer))
