class_name WizardLook
extends RefCounted

## What a wizard can look like: one of seven figures, in one of a few sets of colors. Every figure is drawn to the same height, from the feet to the top
## of the head (their staffs and flames rise above that, and are not counted), so the choice is only for looks. A set of colors turns two groups of the
## figure's own colors (its robe and its trim, picked out by hue) to new hues, in the sprite's shader (see wet.gdshader); skin, wood and outlines stay.

const LOOKS := ["wizard", "dark_wizard", "pyre_wizard", "bone_wizard", "fire_wizard", "wanderer", "lightning_mage"]  # in the order the seats of a match have them
const SCALE := {"wizard": 1.0, "dark_wizard": 1.5, "pyre_wizard": 1.7, "bone_wizard": 1.5, "fire_wizard": 1.2, "wanderer": 1.2, "lightning_mage": 1.25}  # what each is drawn at, to make them one height
const NAMES := {"wizard": "Wizard", "dark_wizard": "Hooded", "pyre_wizard": "Pyre", "bone_wizard": "Pale", "fire_wizard": "Fire", "wanderer": "Wanderer", "lightning_mage": "Lightning"}

## Each figure's two groups of colors: the hue at the middle of the group and how far either side of it the group reaches (both in turns of the
## color wheel), and the least color a pixel must have to be counted. A fourth number, for the figures drawn in dark colors, is how much brighter that group is made when a set of colors recolors it, and a fifth is the brightest a pixel can be and still count (to keep skin out of a group of browns). The first is the robe, the second the trim.
const GROUPS := {
	"wizard": [[0.75, 0.14, 0.25], [0.125, 0.04, 0.35]],        # the purple hood and cloak, and the gold edging
	"dark_wizard": [[0.79, 0.17, 0.15], [0.09, 0.04, 0.35]],    # the purple robe and staff, and the orange trim
	"pyre_wizard": [[0.0, 0.06, 0.3], [0.13, 0.05, 0.62]],       # the red robe, and the gold and flame
	"bone_wizard": [[0.0, 0.06, 0.3], [0.7, 0.0, 2.0]],         # the red cloth (the pale skin and bone are left as they are: no trim)
	"fire_wizard": [[0.65, 0.08, 0.12, 2.2], [0.97, 0.035, 0.42, 1.3]],        # the slate robe, and the red cloth
	"wanderer": [[0.64, 0.07, 0.12, 3.0], [0.04, 0.06, 0.15, 2.4, 0.5]],            # the dark blue robe, and the brown hood and cloth
	"lightning_mage": [[0.985, 0.03, 0.42, 1.6], [0.1, 0.012, 0.3, 1.0]],       # the brown-red robe and the red scarf, and the blond hair
}

## A figure whose cloak is drawn in plain black has no hue to turn, so in a set of colors its black becomes a very dark shade of the robe's hue:
## how much color, and how bright.
const BLACK_CLOAKS := {"wanderer": [0.75, 0.2]}

## The sets of colors, the same for every figure: a name, the hue the robe turns to and how much color it keeps, and the same for the trim. The
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


## The color shown on the button for a set of colors: the robe's, as that figure would wear it.
static func swatch(look: String, palette: int) -> Color:
	var groups: Array = GROUPS.get(look, GROUPS["wizard"])
	var set: Dictionary = PALETTES[clampi(palette, 0, PALETTES.size() - 1)]
	var hue: float = groups[0][0] if set["robe"][0] < 0.0 else set["robe"][0]
	return Color.from_hsv(hue, 0.65 * float(set["robe"][1]), 0.78)


## The sound of a jump, in the figure's own voice: the women have voices of their own, and the rest share the one that every wizard had.
const JUMP_VOICES := {"bone_wizard": "jump_bone_wizard", "lightning_mage": "jump_lightning_mage"}


static func jump_sound(look: String) -> String:
	return JUMP_VOICES.get(look, "jump")


## True for the id of one of the four figures.
static func is_look(look: String) -> bool:
	return LOOKS.has(look)


## The size a look is drawn at (a look that is not one of the four, such as a creature, keeps the size its kind says).
static func scale_of(look: String, fallback := 1.0) -> float:
	return float(SCALE.get(look, fallback))


## Sets a sprite's material to show a look in a set of colors. A material that is already on it keeps its other work.
static func paint(material: ShaderMaterial, look: String, palette: int) -> void:
	var groups: Array = GROUPS.get(look, GROUPS["wizard"])
	var set: Dictionary = PALETTES[clampi(palette, 0, PALETTES.size() - 1)]
	var robe: Array = groups[0]
	var trim: Array = groups[1]
	material.set_shader_parameter("robe_group", Vector4(robe[0], robe[1], robe[2], robe[3] if robe.size() > 3 else 0.0))
	material.set_shader_parameter("trim_group", Vector4(trim[0], trim[1], trim[2], trim[3] if trim.size() > 3 else 0.0))
	var shade := Vector4(-1.0, 0.0, 0.0, 0.0)
	if BLACK_CLOAKS.has(look) and set["robe"][0] >= 0.0:
		shade = Vector4(set["robe"][0], BLACK_CLOAKS[look][0], BLACK_CLOAKS[look][1], 0.0)
	material.set_shader_parameter("shade", shade)
	material.set_shader_parameter("caps", Vector2(robe[4] if robe.size() > 4 else 1.0, trim[4] if trim.size() > 4 else 1.0))
	material.set_shader_parameter("robe_goal", Vector4(set["robe"][0], set["robe"][1], 0.0, 0.0))
	material.set_shader_parameter("trim_goal", Vector4(set["trim"][0], set["trim"][1], 0.0, 0.0))


## A material with the wizard's shader, showing a look in a set of colors: for a figure drawn outside a wizard (a cut-scene's, or a portrait's).
static func material_for(look: String, palette: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/fx/wet.gdshader")
	paint(material, look, palette)
	return material
