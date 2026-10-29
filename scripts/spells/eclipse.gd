class_name Eclipse
extends Node2D

## Eclipse: darkness settles over the area you drew the crescent in. Anyone inside sees only what is close to them, so
## enemies in it lose sight of you beyond a few steps. A flare lights its patch of the dark and cuts through.

const LIFE := 10.0
const SIGHT := 90.0  # how far you can see inside an eclipse
const COLOR := Color(0.05, 0.0, 0.12)
const VEIL_LIGHTS := 6  # the most lit patches the veil cuts out of the dark at once
const VEIL_SHADER := """
shader_type canvas_item;
uniform vec2 size;
uniform vec2 centre;
uniform float radius;
uniform float strength;
uniform vec4 lights[6];
void fragment() {
	vec2 p = UV * size;
	float dark = mix(0.3, 0.94, smoothstep(radius * 0.75, radius * 1.25, distance(p, centre)));
	for (int i = 0; i < 6; i++) {
		dark *= smoothstep(lights[i].z * 0.45, lights[i].z, distance(p, lights[i].xy));
	}
	COLOR = vec4(0.02, 0.0, 0.06, dark * strength);
}
"""

var radius := 110.0  # set from how big the crescent was drawn
var _age := 0.0
var _veil: ColorRect  # the darkness over the screen, while the one watching is in the eclipse
var _veil_strength := 0.0


func _ready() -> void:
	radius = clampf(radius, 70.0, 200.0)
	add_to_group("eclipses")
	add_to_group("lasting")
	z_index = 8
	# Dark wisps turning slowly inside it.
	var wisps := CPUParticles2D.new()
	wisps.amount = 18
	wisps.lifetime = 3.0
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = radius * 0.8
	wisps.direction = Vector2.UP
	wisps.spread = 180.0
	wisps.initial_velocity_min = 4.0
	wisps.initial_velocity_max = 14.0
	wisps.gravity = Vector2.ZERO
	wisps.tangential_accel_min = 10.0
	wisps.tangential_accel_max = 30.0
	wisps.texture = Fx.tex("smoke_04")
	wisps.scale_amount_min = radius * 0.5 / Fx.TEX_SIZE
	wisps.scale_amount_max = radius * 0.9 / Fx.TEX_SIZE
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.1, 0.0, 0.2, 0.0), Color(0.1, 0.0, 0.2, 0.5), Color(0.1, 0.0, 0.2, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	wisps.color_ramp = ramp
	add_child(wisps)
	wisps.emitting = true
	_make_veil()
	Sfx.play("gravity", global_position, -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	_update_veil(delta)
	if _age >= LIFE:
		queue_free()


## True when a point is in the dark.
func covers(point: Vector2) -> bool:
	return _age > 0.3 and point.distance_to(global_position) <= radius


func _draw() -> void:
	var grow := clampf(_age / 0.5, 0.0, 1.0) * clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	draw_texture_rect(Fx.tex("circle_05"), Rect2(-Vector2.ONE * radius * 1.2, Vector2.ONE * radius * 2.4), false, Color(COLOR.r, COLOR.g, COLOR.b, 0.62 * grow))


## The world goes dark around whoever is watching from inside it, leaving a dim ring of sight about them.
func _make_veil() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2  # over the world, under the interface
	add_child(layer)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color.WHITE
	var shader := Shader.new()
	shader.code = VEIL_SHADER
	_veil.material = ShaderMaterial.new()
	(_veil.material as ShaderMaterial).shader = shader
	layer.add_child(_veil)
	_veil.visible = false


## Fades the veil in while the watched wizard is inside, out when it is not, and keeps the ring on them and the holes on the lit patches.
func _update_veil(delta: float) -> void:
	var watched := get_tree().get_first_node_in_group("player") as Wizard
	var inside := watched != null and not watched.dead and covers(watched.global_position)
	var fade := clampf(_age / 0.5, 0.0, 1.0) * clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	_veil_strength = move_toward(_veil_strength, fade if inside else 0.0, delta * 3.0)
	_veil.visible = _veil_strength > 0.0
	if not _veil.visible:
		return
	var screen := get_viewport().get_visible_rect().size
	var to_screen := get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	_veil.size = screen
	var material := _veil.material as ShaderMaterial
	material.set_shader_parameter("size", screen)
	material.set_shader_parameter("centre", to_screen * watched.center())
	material.set_shader_parameter("radius", SIGHT * zoom)
	material.set_shader_parameter("strength", _veil_strength)
	var lights: Array[Vector4] = []
	for flare in get_tree().get_nodes_in_group("flares"):
		lights.append(_light_hole(to_screen, flare.global_position, Flare.LIGHT_RADIUS))
	for light in get_tree().get_nodes_in_group("lights"):
		lights.append(_light_hole(to_screen, light.global_position, light.light_radius))
	while lights.size() < VEIL_LIGHTS:
		lights.append(Vector4(-10000.0, -10000.0, 1.0, 0.0))  # nowhere on the screen
	material.set_shader_parameter("lights", lights.slice(0, VEIL_LIGHTS))


func _light_hole(to_screen: Transform2D, at: Vector2, reach: float) -> Vector4:
	var spot := to_screen * at
	return Vector4(spot.x, spot.y, reach * to_screen.get_scale().x, 0.0)


## How dark the screen of the one watching is, from 0 (not at all) to 1 (fully).
func veil_strength() -> float:
	return _veil_strength
