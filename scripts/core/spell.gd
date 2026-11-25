class_name Spell
extends Resource

## One fast spell, as data: which school and gesture cast it, what it costs, what the spellbook says about it, and the
## script that makes its effect. Each lives in its own file in res://data/spells/, so a spell is added or tuned in the
## editor's inspector and SpellData finds it by scanning that folder.

## The targeting kinds that leave along the stroke: `directional` along it from its start to its end, `pointed` toward the far end of it (at any angle, as
## an arrow points), and `raised` from where it began, on the ground (a wall).
const DIRECTIONAL := ["directional", "pointed", "raised"]

## What about the stroke makes a spell cost more: its size is measured and compared with size_unit, then clamped.
enum Size { NONE, RADIUS, REACH, LINE_WIDTH, LINE_SPAN, LENGTH, STEP_LENGTH, AREA, PIECES }

@export var spell_name := ""
@export_enum("Fire", "Water", "Air", "Earth", "Flora", "Shadow", "Blood") var school := "Fire"
@export var gesture := ""
@export_enum("directional", "pointed", "raised", "positional", "shape", "cone", "angled") var targeting := "positional"  ## how the stroke aims it: the three first leave along it
@export var cost := 10.0
@export_multiline var effect := ""  ## what it does, for the spellbook
@export var applies: Array[String] = []  ## the states it puts on someone (names as in StatusBubbles), for the spellbook
@export var removes: Array[String] = []  ## the states it takes off someone
@export var damage := ""            ## a short figure for the spellbook
@export var heal := ""              ## what a spell that heals mends, as the spellbook writes it where damage goes, with a plus sign ("+55 max stamina", "+3 max stamina/sec")
## What the AI wizards work a spell's worth out from (see SpellFacts): the damage figures above and these, all in the game's own units. Zero is "does not apply".
@export var speed := 0.0     ## pixels a second the spell travels at; zero for one that strikes at once or lands where it was drawn
@export var warning := 0.0   ## seconds between the cast and the harm, for a spell that takes a moment to land (a boulder falling, a wall catching light)
@export var span := 0.0      ## seconds the harm keeps on coming, for a spell that burns, bleeds or lingers: the "per sec" figure runs this long
@export var hold := 0.0      ## seconds a rival is held or hobbled by a spell that controls (frozen, put down, slowed, silenced): what the spell is worth when it deals no harm of its own
@export var share := 1.0     ## how much of what the rival could do is taken away for those seconds: 1 is all of it (frozen solid), a half is a rival slowed down
@export var lasts := 0.0     ## seconds a defense stands, for a spell that protects for a time (black glass, a wind, a shadow to throw blows at)
@export var absorbs := 0.0   ## the share of the harm that comes at the wizard which it takes away while it stands (a half for black glass), or from each blow it turns away
@export var blows := 0       ## how many blows it turns away, for a spell that stands until they have come (a Crimson Veil)
@export var pellets := 1     ## how many pieces one cast sends (a volley of thorns)
@export var spread := 0.0    ## the angle those pieces fan across, in radians
@export var reach := 0.0     ## how far it carries or reaches, in pixels; zero when that does not matter
## What it does, in the terms of docs/handoff/24_spell_terms.md: each part says where it acts, when (`after`, `for`, `every`, `again`, in seconds), and what it `does`, a list of effects
## each with its `do` (the term) and its numbers. The game runs on these and the AI reads them; a figure here is kept nowhere else. (So far: how a spell moves a body.)
@export var parts: Array[Dictionary] = []
@export var sounds := {}  ## the sounds this spell makes, by event (cast, hit...): each a file of its own, owned by this spell alone (see Sfx.cue)
@export var color := Color(0, 0, 0, 0)  ## the glow of a spell that is not its school's color; transparent means the school's
@export var size_from := Size.NONE
@export var size_unit := 1.0
@export var size_min := 1.0
@export var size_max := 1.0
@export_file("*.gd") var effect_path := ""  ## the SpellEffect script that makes it, for spells placed as one effect; a path, so reading a spell never compiles it


var _effects := {}  # term -> the effect, with its part's own where and when (see effect_of)


## The first effect of this kind that it has, together with where and when its part acts, or nothing.
func effect_of(term: String) -> Dictionary:
	if not _effects.has(term):
		_effects[term] = among(parts, term)
	return _effects[term]


## The first effect of this kind among these parts, together with where its part `needs` to be (when that is said), and where and when the part acts, or nothing.
static func among(parts: Array, term: String, needs := "") -> Dictionary:
	for part: Dictionary in parts:
		if needs != "" and part.get("needs", "") != needs:
			continue
		for one: Dictionary in part["does"]:
			if one["do"] == term:
				var found := part.duplicate()
				found.erase("does")
				found.merge(one, true)
				return found
	return {}


## The mouse buttons that cast it: its school's.
var buttons: int:
	get: return SpellData.SCHOOL_BUTTONS[school]


## What it glows.
func glow() -> Color:
	return color if color.a > 0.0 else SpellData.SCHOOL_COLORS[school]


## True when it is paid for in maximum stamina, which only healing brings back.
func pays_max() -> bool:
	return school == "Blood"


## What the spellbook says it costs: "30 stamina", or "30 max stamina" for a spell paid in maximum stamina; a range when the size drawn sets the price.
func cost_line() -> String:
	var what := "max stamina" if pays_max() else "stamina"
	var span := cost_span()
	if roundi(span.x) == roundi(span.y):
		return "%d %s" % [roundi(span.x), what]
	return "%d to %d %s" % [roundi(span.x), roundi(span.y), what]


## The least and the most it costs, as the spellbook's cost line says (x the least, y the most).
func cost_span() -> Vector2:
	var low := cost
	var high := cost
	match size_from:
		Size.NONE:
			pass
		Size.PIECES:
			pass  # each piece costs this much
		Size.STEP_LENGTH:
			low = size_min
			high = roundf(cost * SpellData.STEP_MAX / size_unit)
		_:
			low = roundf(cost * size_min)
			high = roundf(cost * size_max)
	return Vector2(low, high)


## What the spellbook says it deals ("14 dmg/sec", "30 dmg"), or nothing when it deals no damage.
func damage_line() -> String:
	return damage


## True for a spell that heals.
func heals() -> bool:
	return heal != ""


## What a spell that heals mends, written where the damage of the others is.
func heal_line() -> String:
	return heal


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
