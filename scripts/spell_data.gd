class_name SpellData

## Mouse buttons as bits, so a school can be one button or a combination.
const LEFT := 1
const RIGHT := 2
const MIDDLE := 4

## The farthest a Shadow Step carries the caster, in pixels.
const STEP_MAX := 300.0

## Colour of each school: used to tint the enemies of that school and to glow the spells.
const SCHOOL_COLORS := {
	"Fire": Color("#ff6a2a"),
	"Water": Color("#7fd8ff"),
	"Air": Color("#d8e4ee"),
	"Earth": Color("#b8864a"),
	"Flora": Color("#6fcf6a"),
	"Shadow": Color("#7a5aa0"),
	"Blood": Color("#c4162f"),
}

## The schools, each cast with its own mouse buttons.
const SCHOOL_BUTTONS := {
	"Fire": LEFT,
	"Water": RIGHT,
	"Air": MIDDLE,
	"Earth": LEFT | RIGHT,
	"Flora": LEFT | MIDDLE,
	"Shadow": RIGHT | MIDDLE,
	"Blood": LEFT | RIGHT | MIDDLE,  # the school that is paid for in maximum stamina
}

## Every fast spell, by name, each a Spell resource read from res://spells/. The caster, arena and spellbook all read from here.
## Each gesture is a picture of what the spell does.
static var SPELLS: Dictionary = _load_spells()


static func _load_spells() -> Dictionary:
	var out := {}
	for file in ResourceLoader.list_directory("res://spells"):
		file = file.trim_suffix(".remap")  # an exported game lists remapped resources under this name
		if file.ends_with(".tres") or file.ends_with(".res"):
			var spell: Spell = load("res://spells/" + file)
			out[spell.spell_name] = spell
	return out


## mouse button -> gesture -> {spell, targeting}, built from SPELLS for quick lookup.
static func bindings() -> Dictionary:
	var out := {}
	for spell_name in SPELLS:
		var spell: Spell = SPELLS[spell_name]
		if not out.has(spell.buttons):
			out[spell.buttons] = {}
		out[spell.buttons][spell.gesture] = {"spell": spell_name, "targeting": spell.targeting}
	return out


## The horizontal span of a drawn line, which is how wide a snowfall, cloud, crack or pit is.
static func width_of(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0
	var left := points[0].x
	var right := points[0].x
	for p in points:
		left = minf(left, p.x)
		right = maxf(right, p.x)
	return right - left


## Name of a button combination, for the spellbook.
static func button_name(mask: int) -> String:
	var names: Array[String] = []
	if mask & LEFT:
		names.append("Left")
	if mask & MIDDLE:
		names.append("Middle")
	if mask & RIGHT:
		names.append("Right")
	return " + ".join(names)
