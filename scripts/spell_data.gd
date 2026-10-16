class_name SpellData

## Mouse buttons as bits, so a school can be one button or a combination.
const LEFT := 1
const RIGHT := 2
const MIDDLE := 4

## The farthest a Blink carries the caster, in pixels.
const BLINK_MAX := 300.0

## Short damage figure per spell, for the spellbook.
const DAMAGE := {
	"Ignite": "12 damage", "Firewall": "4 damage per half second", "Cinderburst": "25 damage",
	"Frostbolt": "6 damage, slows", "Blink": "8 damage to foes in the way", "Chain Lightning": "12 damage, less on each hop", "Icicles": "6 damage every half second", "Snowfall": "slows what is inside", "Push": "no damage, moves foes",
	"Barrier": "blocks damage", "Spark": "20 damage",
	"Force Wall": "no damage, bats back bolts", "Stonefall": "30 damage", "Stone Wall": "solid, no damage",
}

## Colour of each school: used to tint the mobs of that school and to glow the spells.
const SCHOOL_COLORS := {
	"Fire": Color("#ff6a2a"),
	"Ice": Color("#7fd8ff"),
	"Force": Color("#b07cff"),
	"Lightning": Color("#ffe85a"),
	"Earth": Color("#b8864a"),
	"Shadow": Color("#7a5aa0"),
}

## Single source of truth for fast spells: which mouse button and gesture cast them, what they cost,
## and the text the spellbook shows. The caster, arena and spellbook all read from here.

const SPELLS := {
	"Ignite": {
		"buttons": LEFT, "gesture": "flick", "targeting": "directional", "cost": 15.0,
		"school": "Fire", "draw": "Straight stroke, not vertical. Draw it in the direction you want to throw.",
		"effect": "Bolt that flies along your stroke from your character. 12 damage.",
	},
	"Firewall": {
		"buttons": LEFT, "gesture": "wall", "targeting": "positional", "cost": 20.0,
		"school": "Fire", "draw": "Straight vertical line. The wall appears at the middle of the stroke.",
		"effect": "A wall of fire for 4 seconds. Mobs cannot pass it. You can walk through it, and it burns you and any mob in it, 4 damage every half second.",
	},
	"Cinderburst": {
		"buttons": LEFT, "gesture": "circle_cw", "targeting": "positional", "cost": 30.0,
		"school": "Fire", "draw": "Clockwise circle. The burst goes off at its center.",
		"effect": "Burst at the circle's center. 25 damage to everything inside.",
	},
	"Frostbolt": {
		"buttons": RIGHT, "gesture": "flick", "targeting": "directional", "cost": 15.0,
		"school": "Ice", "draw": "Straight stroke, not vertical. Same stroke as Ignite.",
		"effect": "Bolt along your stroke. 6 damage and slows the mob for 2 seconds.",
	},
	"Blink": {
		"buttons": LEFT | RIGHT, "gesture": "flick", "targeting": "directional", "cost": 6.0,
		"school": "Lightning", "draw": "A straight stroke. You zip along it, through anything in your way.",
		"effect": "Teleports you along the stroke, up to 300 px, stopping short of walls. Costs more the farther you go. Foes in the way take 8 damage."
	},
	"Chain Lightning": {
		"buttons": LEFT | RIGHT, "gesture": "chain", "targeting": "shape", "cost": 6.0,
		"school": "Lightning", "draw": "A wave, like a lowercase m. Each hump is one bounce, and you can draw as many as you want.",
		"effect": "A bolt hops from hump to hump, striking foes near each one. Costs 6 stamina per hump."
	},
	"Icicles": {
		"buttons": RIGHT, "gesture": "icicles", "targeting": "shape", "cost": 8.0,
		"school": "Ice", "draw": "A V hangs an icicle from above it. An upside-down V grows one up from below. Each V is one icicle, so a row like VVVVVV is six.",
		"effect": "Each icicle stands for 4 seconds, then melts. A mob that walks through one takes 6 damage. Costs 8 stamina per icicle."
	},
	"Snowfall": {
		"buttons": RIGHT, "gesture": "snowfall", "targeting": "shape", "cost": 20.0,
		"school": "Ice", "draw": "A five-pointed star drawn in one swift stroke, then a horizontal line. Snow falls along the line.",
		"effect": "Snow falls over the line for 6 seconds. Anything inside it is slowed."
	},
	"Push": {
		"buttons": MIDDLE, "gesture": "circle_push", "targeting": "angled", "cost": 10.0,
		"school": "Force", "draw": "A circle, then a line going out of it. Everything inside the circle is moved along the line.",
		"effect": "Moves every foe inside the circle along the line, no damage, and knocks down stone walls inside it. A bigger circle costs more stamina.",
	},
	"Barrier": {
		"buttons": MIDDLE, "gesture": "circle_ccw", "targeting": "positional", "cost": 25.0,
		"school": "Force", "draw": "Counter-clockwise circle. The shield wraps around you.",
		"effect": "Shield around you for 2.5 seconds. Blocks all damage, including mob contact.",
	},
	"Spark": {
		"buttons": LEFT | RIGHT, "gesture": "zigzag", "targeting": "positional", "cost": 10.0,
		"school": "Lightning", "draw": "A tall zigzag going down. Start down and to the left, then zig right. The strike lands at its middle.",
		"effect": "Lightning strikes down from above through the middle of your stroke. 20 damage.",
	},
	"Force Wall": {
		"buttons": MIDDLE, "gesture": "flick", "targeting": "angled", "cost": 15.0,
		"school": "Force", "draw": "Any straight slash. A short-lived force wall appears along its angle.",
		"effect": "Lasts under a second. Foes are shoved off it, and enemy bolts are batted back the way they came.",
		"preview": "wall"
	},
	"Stonefall": {
		"buttons": LEFT | MIDDLE, "gesture": "stonefall", "targeting": "positional", "cost": 25.0,
		"school": "Earth", "draw": "A circle, then a line running down from its top. A boulder drops onto the spot.",
		"effect": "A boulder drops after a moment and deals 30 damage to foes around where it lands. Its dust is crisp rock, not smoke."
	},
	"Stone Wall": {
		"buttons": LEFT | MIDDLE, "gesture": "stone_wall", "targeting": "directional", "cost": 30.0,
		"school": "Earth", "draw": "A straight stroke drawn starting from the ground. A stone wall rises along it.",
		"effect": "A solid stone wall that stays up until a force blast, a Push, knocks it down."
	},
}


## mouse button -> gesture -> {spell, targeting}, built from SPELLS for quick lookup.
static func bindings() -> Dictionary:
	var out := {}
	for spell_name in SPELLS:
		var s: Dictionary = SPELLS[spell_name]
		if not out.has(s["buttons"]):
			out[s["buttons"]] = {}
		out[s["buttons"]][s["gesture"]] = {"spell": spell_name, "targeting": s["targeting"]}
	return out


static func cost(spell_name: String) -> float:
	return SPELLS[spell_name]["cost"] if SPELLS.has(spell_name) else 10.0


## What a spell costs. A circle-drawn spell that scales (Push) costs more for a bigger circle: its base cost is for a circle 40 px across the middle.
static func cost_for(spell_name: String, info: Dictionary) -> float:
	var base := cost(spell_name)
	if spell_name == "Blink":
		return maxf(2.0, roundf(base * clampf(info.get("length", 0.0), 0.0, BLINK_MAX) / 100.0))
	var radius: float = info.get("radius", 0.0)
	if (spell_name == "Push" or spell_name == "Cinderburst") and radius > 0.0:
		return roundf(base * clampf(radius / 40.0, 0.5, 4.0))
	if spell_name == "Snowfall":
		var width := _width_of(info.get("line", PackedVector2Array()))
		if width > 0.0:
			return roundf(base * clampf(width / 100.0, 0.5, 4.0))
	if spell_name == "Icicles" or spell_name == "Chain Lightning":
		return base * int(info.get("pieces", 1))
	return base


## The horizontal span of a drawn line, which is how wide a snowfall is.
static func _width_of(points: PackedVector2Array) -> float:
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
