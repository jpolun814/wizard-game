class_name Spell
extends Resource

## One fast spell, as data: which school and gesture cast it, what it costs, what the spellbook says about it, and the
## script that makes its effect. Each lives in its own file in res://spells/, so a spell is added or tuned in the
## editor's inspector and SpellData finds it by scanning that folder.

## What about the stroke makes a spell cost more: its size is measured and compared with size_unit, then clamped.
enum Size { NONE, RADIUS, REACH, LINE_WIDTH, LINE_SPAN, LENGTH, STEP_LENGTH, AREA, PIECES }

@export var spell_name := ""
@export_enum("Fire", "Water", "Air", "Earth", "Flora", "Shadow", "Blood") var school := "Fire"
@export var gesture := ""
@export_enum("directional", "positional", "shape", "cone", "angled") var targeting := "positional"
@export var cost := 10.0
@export_multiline var effect := ""  ## what it does, for the spellbook
@export var damage := ""            ## a short figure for the spellbook
@export var preview := ""           ## a gesture to draw in the spellbook instead of `gesture`, when they differ
@export var colour := Color(0, 0, 0, 0)  ## the glow of a spell that is not its school's colour; transparent means the school's
@export var size_from := Size.NONE
@export var size_unit := 1.0
@export var size_min := 1.0
@export var size_max := 1.0
@export_file("*.gd") var effect_path := ""  ## the SpellEffect script that makes it, for spells placed as one effect; a path, so reading a spell never compiles it


## The mouse buttons that cast it: its school's.
var buttons: int:
	get: return SpellData.SCHOOL_BUTTONS[school]


## What it glows.
func glow() -> Color:
	return colour if colour.a > 0.0 else SpellData.SCHOOL_COLORS[school]


## True when it is paid for in maximum stamina, which only healing brings back.
func pays_max() -> bool:
	return school == "Blood"


## What it costs when drawn this big. info is what the gesture measured: radius, reach, line, length, rect, pieces.
func cost_for(info: Dictionary) -> float:
	var line: PackedVector2Array = info.get("line", PackedVector2Array())
	var measure := 0.0
	match size_from:
		Size.NONE:
			return cost
		Size.RADIUS:
			measure = info.get("radius", 0.0)
		Size.REACH:
			measure = info.get("reach", 0.0)
		Size.LINE_WIDTH:
			measure = SpellData.width_of(line)
		Size.LINE_SPAN:
			var height := absf(line[0].y - line[line.size() - 1].y) if line.size() > 1 else 0.0
			measure = maxf(SpellData.width_of(line), height)
		Size.LENGTH:
			measure = info.get("length", 0.0)
		Size.STEP_LENGTH:  # a step costs by how far it carries, and never less than two
			return maxf(size_min, roundf(cost * clampf(info.get("length", 0.0), 0.0, SpellData.STEP_MAX) / size_unit))
		Size.AREA:
			var box: Rect2 = info.get("rect", Rect2())
			measure = box.get_area() if box.has_area() else 0.0
		Size.PIECES:
			return cost * int(info.get("pieces", 1))
	if measure <= 0.0:
		return cost
	return roundf(cost * clampf(measure / size_unit, size_min, size_max))
