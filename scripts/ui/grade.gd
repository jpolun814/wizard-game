class_name Grade
extends CanvasLayer

## The color grade every world is seen through (see grade.gdshader): over the world, under the interface. Every world has the same grade, with a
## cast of its own: cold in the peaks, green in the jungle, red in the ashlands, warm in the castle, so the art of each place is held together by one
## light. Shadows take the cast and the lights are tinted a little toward it.

## Per biome: the color the darkest shadows are pulled toward, the color laid over the lights, and how dark the corners of the screen fall.
const CASTS := {
	"graveyard": {"shadow": Vector3(0.09, 0.03, 0.10), "light": Vector3(1.03, 0.97, 1.04), "vignette": 0.42},
	"jungle": {"shadow": Vector3(0.02, 0.08, 0.07), "light": Vector3(0.96, 1.05, 0.97), "vignette": 0.42},
	"mountains": {"shadow": Vector3(0.04, 0.07, 0.15), "light": Vector3(0.95, 1.0, 1.07), "vignette": 0.36},
	"ashlands": {"shadow": Vector3(0.13, 0.04, 0.02), "light": Vector3(1.09, 0.97, 0.88), "vignette": 0.44},
	"castle": {"shadow": Vector3(0.08, 0.05, 0.10), "light": Vector3(1.07, 1.0, 0.89), "vignette": 0.4},
	"underground": {"shadow": Vector3(0.04, 0.05, 0.13), "light": Vector3(0.95, 0.98, 1.05), "vignette": 0.52},
	"portals": {"shadow": Vector3(0.11, 0.03, 0.15), "light": Vector3(1.0, 0.95, 1.07), "vignette": 0.4},
	"ocean": {"shadow": Vector3(0.02, 0.07, 0.10), "light": Vector3(0.93, 1.0, 1.05), "vignette": 0.5},
	"sky": {"shadow": Vector3(0.05, 0.07, 0.15), "light": Vector3(0.98, 1.0, 1.06), "vignette": 0.3},
}

var biome := ""  # the place it is laid over, which others ask for (see Bonfire)


## The wash of gray that takes the color out of the graveyard, as a layer to lay over a view of the world (the screen's own, and the Scrying Eye's window).
static func gray_wash() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 2
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/grayscale.gdshader")
	wash.material = material
	layer.add_child(wash)
	return layer


## The grade with the cast of a biome, or the plain grade for a place with none (the waiting room).
static func for_biome(biome: String) -> Grade:
	var grade := Grade.new()
	grade.biome = biome
	if CASTS.has(biome):
		var cast: Dictionary = CASTS[biome]
		var material := grade.get_child(0).material as ShaderMaterial
		material.set_shader_parameter("shadow_tint", cast["shadow"])
		material.set_shader_parameter("light_tint", cast["light"])
		material.set_shader_parameter("vignette", cast["vignette"])
	return grade


func _init() -> void:
	layer = 2
	add_to_group("grade")
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/ui/grade.gdshader")
	wash.material = material
	add_child(wash)
