class_name WizardLook
extends RefCounted

## What a wizard can look like: one of three figures, in one of a few sets of colours. Every figure is drawn to the same height, from the feet to the top
## of the head (their staffs and flames rise above that, and are not counted), so the choice is only for looks. A set of colours turns two groups of the
## figure's own colours (its robe and its trim, picked out by hue) to new hues, in the sprite's shader (see wet.gdshader); skin, wood and outlines stay.

const LOOKS := ["wizard", "dark_wizard", "pyre_wizard"]  # in the order the seats of a match have them
const SCALE := {"wizard": 1.2, "dark_wizard": 1.2, "pyre_wizard": 1.25}  # what each is drawn at, to make them one height
const NAMES := {"wizard": "Fire", "dark_wizard": "Wanderer", "pyre_wizard": "Lightning"}

## Each figure's two groups of colours: the hue at the middle of the group and how far either side of it the group reaches (both in turns of the
## colour wheel), and the least colour a pixel must have to be counted. The first is the robe, the second the trim.
const GROUPS := {
	"wizard": [[0.62, 0.05, 0.12], [0.08, 0.04, 0.45]],         # the fire wizard's slate robe, and the orange scarf
	"dark_wizard": [[0.62, 0.06, 0.1], [0.98, 0.05, 0.35]],     # the wanderer's dark blue robe, and the red of the cloth
	"pyre_wizard": [[0.03, 0.04, 0.35], [0.95, 0.04, 0.4]],     # the lightning mage's brown robe, and the crimson scarf
}

## The sets of colours, the same for every figure: a name, the hue the robe turns to and how much colour it keeps, and the same for the trim. The
## first leaves the figure as it was drawn. (A hue of -1 leaves a group alone.)
const PALETTES := [
	{"name": "Original", "robe": [-1.0, 1.0], "trim": [-1.0, 1.0]},
	{"name": "Indigo", "robe": [0.66, 1.0], "trim": [0.13, 1.0]},
	{"name": "Azure", "robe": [0.57, 1.0], "trim": [0.5, 0.3]},
	{"name": "Teal", "robe": [0.48, 0.9], "trim": [0.08, 0.9]},
	{"name": "Emerald", "robe": [0.36, 0.95], "trim": [0.13, 1.0]},
	{"name": "Amber", "robe": [0.08, 1.0], "trim": [0.75, 0.9]},
	{"name": "Rose", "robe": [0.9, 1.0], "trim": [0.14, 0.9]},
	{"name": "Ash", "robe": [-1.0, 0.0], "trim": [-1.0, 0.0]},
]


## The colour shown on the button for a set of colours: the robe's, as that figure would wear it.
static func swatch(look: String, palette: int) -> Color:
	var groups: Array = GROUPS.get(look, GROUPS["wizard"])
	var set: Dictionary = PALETTES[clampi(palette, 0, PALETTES.size() - 1)]
	var hue: float = groups[0][0] if set["robe"][0] < 0.0 else set["robe"][0]
	return Color.from_hsv(hue, 0.65 * float(set["robe"][1]), 0.78)


## The look a wizard in a seat has when nobody has chosen another for it.
static func of_seat(seat: int) -> String:
	return LOOKS[clampi(seat, 0, LOOKS.size() - 1)]


## True for the id of one of the four figures.
static func is_look(look: String) -> bool:
	return LOOKS.has(look)


## The size a look is drawn at (a look that is not one of the four, such as a creature, keeps the size its kind says).
static func scale_of(look: String, fallback := 1.0) -> float:
	return float(SCALE.get(look, fallback))


## Sets a sprite's material to show a look in a set of colours. A material that is already on it keeps its other work.
static func paint(material: ShaderMaterial, look: String, palette: int) -> void:
	var groups: Array = GROUPS.get(look, GROUPS["wizard"])
	var set: Dictionary = PALETTES[clampi(palette, 0, PALETTES.size() - 1)]
	var robe: Array = groups[0]
	var trim: Array = groups[1]
	material.set_shader_parameter("robe_group", Vector4(robe[0], robe[1], robe[2], 0.0))
	material.set_shader_parameter("trim_group", Vector4(trim[0], trim[1], trim[2], 0.0))
	material.set_shader_parameter("robe_goal", Vector4(set["robe"][0], set["robe"][1], 0.0, 0.0))
	material.set_shader_parameter("trim_goal", Vector4(set["trim"][0], set["trim"][1], 0.0, 0.0))


## A material with the wizard's shader, showing a look in a set of colours: for a figure drawn outside a wizard (a cut-scene's, or a portrait's).
static func material_for(look: String, palette: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/wet.gdshader")
	paint(material, look, palette)
	return material
