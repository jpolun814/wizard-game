class_name Eclipse
extends Node2D

## Eclipse: the whole world goes dark, as long as an earthquake lasts. Everyone sees only what is close to them, so no one can pick out anyone
## beyond a few steps. A flare lights its patch of the dark and cuts through.

const LIFE := 6.0  # as long as an Earthquake
const DEEPEN := 1.8  # seconds the dark takes to settle in full
const SIGHT := 90.0  # how far you can see inside an eclipse
const VEIL_LIGHTS := 16  # the most lit patches the veil cuts out of the dark at once (the nearest to the one watching, when there are more)
const VEIL_SHADER := """
shader_type canvas_item;
uniform vec2 size;
uniform vec2 center;
uniform float radius;
uniform float strength;
uniform vec4 lights[16];
void fragment() {
	vec2 p = UV * size;
	float dark = mix(0.3, 1.0, smoothstep(radius * 0.75, radius * 1.25, distance(p, center)));
	for (int i = 0; i < 16; i++) {
		dark *= smoothstep(lights[i].z * 0.45, lights[i].z, distance(p, lights[i].xy));
	}
	COLOR = vec4(0.02, 0.0, 0.06, dark * strength);
}
"""

var _age := 0.0
var _veil: ColorRect  # the darkness over the screen of the one watching
var _veil_strength := 0.0


func _ready() -> void:
	add_to_group("eclipses")
	add_to_group("lasting")
	_make_veil()
	Sfx.cue("Eclipse", "dark_whoosh", global_position, -8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_update_veil(delta)
	if _age >= LIFE:
		queue_free()


## The whole world is in the dark while an eclipse lasts, wherever the spell was drawn.
func covers(_point: Vector2) -> bool:
	return _age > 0.3


## The world goes dark round whoever is watching, leaving a dim ring of sight about them.
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


## Fades the veil in as the dark settles and out as it lifts, and keeps the ring on the watched wizard and the holes on the lit patches.
func _update_veil(delta: float) -> void:
	var watched := get_tree().get_first_node_in_group("player") as Wizard
	var inside := watched != null and not watched.dead
	var fade := clampf(_age / DEEPEN, 0.0, 1.0) * clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	_veil_strength = move_toward(_veil_strength, fade if inside else 0.0, delta * 3.0)
	_veil.visible = _veil_strength > 0.0 and ScreenFlash.lifting(get_tree()) < 1.0
	if not _veil.visible:
		return
	var screen := get_viewport().get_visible_rect().size
	var to_screen := get_viewport().get_canvas_transform()
	var zoom := to_screen.get_scale().x
	_veil.size = screen
	var material := _veil.material as ShaderMaterial
	material.set_shader_parameter("size", screen)
	material.set_shader_parameter("center", to_screen * watched.center())
	var sees_far := false  # Darkvision is not a light: it only widens the ring the watched wizard sees in, as far as a flare's light would have reached
	for flare: Flare in get_tree().get_nodes_in_group("flares"):
		sees_far = sees_far or (flare.unseen and flare.caster == watched and not flare.is_queued_for_deletion())
	material.set_shader_parameter("radius", (Flare.LIGHT_RADIUS if sees_far else SIGHT) * zoom)
	material.set_shader_parameter("strength", _veil_strength * (1.0 - ScreenFlash.lifting(get_tree())))  # (a flash of lightning lifts the dark: the world is seen as it is)
	var lights: Array[Vector4] = []
	for flare: Flare in get_tree().get_nodes_in_group("flares"):
		if not flare.unseen:  # (sight cuts no hole of its own: it widened the ring above)
			lights.append(_light_hole(to_screen, flare.global_position, Flare.LIGHT_RADIUS))
	for light in get_tree().get_nodes_in_group("lights"):
		lights.append(_light_hole(to_screen, light.global_position, light.light_radius))
	# Whatever glows in any other dark (a fireball, a wall of fire, lava: the world gives each a light of its own) glows in this one too.
	for glow in get_tree().get_nodes_in_group("fires"):
		for child in glow.get_children():
			if child is PointLight2D and child.visible and child.texture != null:
				var lamp: PointLight2D = child
				lights.append(_light_hole(to_screen, lamp.global_position, lamp.texture_scale * lamp.texture.get_width() * 0.5))
	var watched_spot: Vector2 = to_screen * watched.center()
	lights.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x, a.y).distance_to(watched_spot) < Vector2(b.x, b.y).distance_to(watched_spot))
	while lights.size() < VEIL_LIGHTS:
		lights.append(Vector4(-10000.0, -10000.0, 1.0, 0.0))  # nowhere on the screen
	material.set_shader_parameter("lights", lights.slice(0, VEIL_LIGHTS))


func _light_hole(to_screen: Transform2D, at: Vector2, reach: float) -> Vector4:
	var spot := to_screen * at
	return Vector4(spot.x, spot.y, reach * to_screen.get_scale().x, 0.0)


## How dark the screen of the one watching is, from 0 (not at all) to 1 (fully).
func veil_strength() -> float:
	return _veil_strength
