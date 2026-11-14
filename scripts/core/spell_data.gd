class_name SpellData

## Mouse buttons as bits, so a school can be one button or a combination.
const LEFT := 1
const RIGHT := 2
const MIDDLE := 4

## The farthest a Shadow Step carries the caster, in pixels.
const STEP_MAX := 300.0

## Color of each school: used to tint the enemies of that school and to glow the spells.
const SCHOOL_COLORS := {
	"Fire": Color("#ff6a2a"),
	"Water": Color("#7fd8ff"),
	"Air": Color("#d8e4ee"),
	"Earth": Color("#b8864a"),
	"Flora": Color("#6fcf6a"),
	"Shadow": Color("#7a5aa0"),
	"Blood": Color("#c4162f"),
}

## What the player reads for each school. The ids above stay as they are, because they also name an element (what hurts, what freezes,
## what a mob is made of); only the screen shows these names.
const SCHOOL_NAMES := {
	"Fire": "Pyromancy",
	"Water": "Aquamagy",
	"Air": "Aerokinesis",
	"Earth": "Terramancy",
	"Flora": "Druidry",
	"Shadow": "Umbramancy",
	"Blood": "Necromancy",
}

## The title a wizard earns by casting mostly from a school.
const SCHOOL_TITLES := {
	"Fire": "Pyromancer",
	"Water": "Aquamage",
	"Air": "Aerokinetic",
	"Earth": "Terramancer",
	"Flora": "Druid",
	"Shadow": "Umbramancer",
	"Blood": "Necromancer",
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

## Every fast spell, by name, each a Spell resource read from res://data/spells/. The caster, arena and spellbook all read from here.
## Each gesture is a picture of what the spell does.
static var SPELLS: Dictionary = _load_spells()


## The name of a school as the player reads it.
static func school_name(school: String) -> String:
	return SCHOOL_NAMES.get(school, school)


static func _load_spells() -> Dictionary:
	var out := {}
	for file in ResourceLoader.list_directory("res://data/spells"):
		file = file.trim_suffix(".remap")  # an exported game lists remapped resources under this name
		if file.ends_with(".tres") or file.ends_with(".res"):
			var spell: Spell = load("res://data/spells/" + file)
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
