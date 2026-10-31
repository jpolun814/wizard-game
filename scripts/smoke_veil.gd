class_name SmokeVeil
extends CanvasLayer

## What a thick plume of smoke (SmokePlume) does to a person's own screen: everything a wizard cannot see past the smoke is hidden behind a haze
## of drifting ash. It is not the plume's smoke: the plume is the dark column itself, with its edge, and this is the haze over the ground the
## column hides, in a paler, browner smoke that drifts sideways. A wizard sees as far into the plume as sight goes (SmokePlume.DEPTH); the
## haze begins there. It is only on the screen of the person looking, and goes when the last plume does.

const COLS := 96   # the haze is worked out for this many cells across the screen, and made smooth
const ROWS := 54
const FEATHER := 70.0  # how much more smoke than DEPTH it takes for the haze to be complete
const NEAR := 1800.0  # a plume farther than this from the wizard is nowhere near the screen
const HAZE := preload("res://art/particles/smoke_07.png")
const SHADER := """
shader_type canvas_item;
uniform sampler2D mask : filter_linear, repeat_disable;
uniform sampler2D haze : filter_linear, repeat_enable;
uniform vec2 drift;
void fragment() {
	float hidden = texture(mask, UV).r;
	vec4 near = texture(haze, UV * vec2(2.2, 1.3) + drift);
	vec4 far = texture(haze, UV * vec2(3.4, 2.0) - drift * 0.6 + vec2(0.37, 0.61));
	float cloud = clamp(near.a * 0.6 + far.a * 0.5, 0.0, 1.0);
	vec3 ash = mix(vec3(0.30, 0.25, 0.22), vec3(0.50, 0.44, 0.38), cloud);
	COLOR = vec4(ash, hidden * (0.9 + cloud * 0.1));
}
"""

var _image := Image.create(COLS, ROWS, false, Image.FORMAT_L8)
var _mask := ImageTexture.create_from_image(_image)
var _rect: TextureRect
var _material := ShaderMaterial.new()
var _drift := Vector2.ZERO
var _shown := false  # the haze is on the screen (so it must be cleared when it is not needed)


## The veil of this scene, made if there is none yet.
static func ensure(tree: SceneTree) -> void:
	if tree.get_first_node_in_group("smoke_veil") != null:
		return
	var veil := SmokeVeil.new()
	tree.current_scene.add_child(veil)


func _ready() -> void:
	add_to_group("smoke_veil")
	layer = 2  # over the world, under the interface
	var shader := Shader.new()
	shader.code = SHADER
	_material.shader = shader
	_material.set_shader_parameter("mask", _mask)
	_material.set_shader_parameter("haze", HAZE)
	_rect = TextureRect.new()
	_rect.texture = _mask
	_rect.material = _material
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _process(delta: float) -> void:
	var plumes := get_tree().get_nodes_in_group("smoke_plumes")
	if plumes.is_empty():
		queue_free()
		return
	var camera := get_viewport().get_camera_2d()
	var viewer := _viewer(camera)
	var near := false
	for plume: SmokePlume in plumes:
		near = near or plume.global_position.distance_to(viewer) < NEAR
	if not near:  # no plume within a screen or two: nothing is hidden
		if _shown:
			_image.fill(Color(0.0, 0.0, 0.0))
			_mask.update(_image)
			_shown = false
		return
	_shown = true
	_drift += Vector2(0.05, 0.01) * delta
	_material.set_shader_parameter("drift", _drift)
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	for y in ROWS:
		for x in COLS:
			var point: Vector2 = to_world * (Vector2((x + 0.5) / COLS, (y + 0.5) / ROWS) * size)
			var smoke := 0.0
			for plume: SmokePlume in plumes:
				smoke += plume.smoke_along(viewer, point)
			_image.set_pixel(x, y, Color(clampf((smoke - SmokePlume.DEPTH) / FEATHER, 0.0, 1.0), 0.0, 0.0))
	_mask.update(_image)


## Where the person looking is: their wizard, or the middle of the screen when they are not in a body.
func _viewer(camera: Camera2D) -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		return SpellTargets.center_of(player)
	return camera.get_screen_center_position() if camera != null else Vector2.ZERO
