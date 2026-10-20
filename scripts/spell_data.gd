class_name SpellData

## Mouse buttons as bits, so a school can be one button or a combination.
const LEFT := 1
const RIGHT := 2
const MIDDLE := 4

## The farthest a Blink carries the caster, in pixels.
const BLINK_MAX := 300.0

## Short damage figure per spell, for the spellbook.
const DAMAGE := {
	"Ignite": "12 damage", "Firewall": "4 damage per half second", "Volcano": "lava damage, sets ground on fire",
	"Fire Breath": "3 damage every 0.2 s while in the cone",
	"Frostbolt": "6 damage, slows", "Icicles": "6 damage every half second", "Blizzard": "slows what is inside",
	"Ice Prison": "freezes foes solid",
	"Push": "moves foes", "Barrier": "blocks damage", "Force Wall": "bats back shots only",
	"Gravity Well": "pulls foes together",
	"Tornado": "swirls foes", "Blink": "8 damage to foes in the way", "Spark": "20 damage",
	"Storm Cloud": "10 damage per strike",
	"Stonefall": "30 damage", "Stone Wall": "solid · must start on solid ground", "Earthquake": "shakes the ground",
	"Mudslide": "slows, stops jumping",
}

## Colour of each school: used to tint the enemies of that school and to glow the spells.
const SCHOOL_COLORS := {
	"Fire": Color("#ff6a2a"),
	"Ice": Color("#7fd8ff"),
	"Force": Color("#b07cff"),
	"Storm": Color("#ffe85a"),
	"Earth": Color("#b8864a"),
	"Shadow": Color("#7a5aa0"),
}

## Single source of truth for fast spells: which mouse button and gesture cast them, what they cost,
## and the text the spellbook shows. The caster, arena and spellbook all read from here.
## Each school has four spells, and each gesture is a picture of what the spell does.

const SPELLS := {
	"Ignite": {
		"buttons": LEFT, "gesture": "flick", "targeting": "directional", "cost": 15.0,
		"school": "Fire", "draw": "Straight stroke, not vertical. Draw it in the direction you want to throw.",
		"effect": "Bolt that flies along your stroke from your character. 12 damage.",
	},
	"Firewall": {
		"buttons": LEFT, "gesture": "wall", "targeting": "positional", "cost": 20.0,
		"school": "Fire", "draw": "Straight vertical line. The wall rises from the ground under it.",
		"effect": "A wall of fire for 4 seconds. Anyone can walk through it, but it burns whoever is in it, you included: 4 damage every half second.",
	},
	"Fire Breath": {
		"buttons": LEFT, "gesture": "cone", "targeting": "cone", "cost": 16.0,
		"school": "Fire", "draw": "A cone, like <: down one side to its point, then back out the other. The point is you; fire sprays out toward the open end.",
		"effect": "Fire pours out of your mouth for a second, like a flamethrower. It comes from wherever you are: jump and it rises with you, turn round and it turns too. Ground, stone walls and ice stop it, and a Barrier keeps it off. A longer cone reaches farther and costs more.",
	},
	"Volcano": {
		"buttons": LEFT, "gesture": "volcano", "targeting": "shape", "cost": 50.0,
		"school": "Fire", "draw": "A mountain: an upward-pointing triangle, drawn in one stroke.",
		"effect": "Erupts for a few seconds, throwing lava balls. Each one sets the ground or platform it lands on on fire.",
	},
	"Frostbolt": {
		"buttons": RIGHT, "gesture": "flick", "targeting": "directional", "cost": 15.0,
		"school": "Ice", "draw": "Straight stroke, not vertical. Same stroke as Ignite.",
		"effect": "Bolt along your stroke. 6 damage and slows the enemy for 2 seconds.",
	},
	"Icicles": {
		"buttons": RIGHT, "gesture": "icicles", "targeting": "shape", "cost": 16.0,
		"school": "Ice", "draw": "A V hangs an icicle from above it. An upside-down V grows one up from below. Each V is one icicle, so a row like VVVVVV is six.",
		"effect": "Each icicle stands for 4 seconds, then melts. An enemy that walks through one takes 6 damage. Costs 8 stamina per icicle.",
	},
	"Ice Prison": {
		"buttons": RIGHT, "gesture": "circle", "targeting": "shape", "cost": 14.0,
		"school": "Ice", "draw": "A circle, drawn round your target and closed where you started. The circle fills with ice.",
		"effect": "Enemies inside are frozen solid for 3 seconds; Force or Earth shatters them out for extra damage. Drawn round nothing, it is a block of ice you can stand on or hide behind. Bigger circles cost more.",
	},
	"Blizzard": {
		"buttons": RIGHT, "gesture": "snowfall", "targeting": "shape", "cost": 20.0,
		"school": "Ice", "draw": "A five-pointed star drawn in one swift stroke, then a horizontal line. Snow falls along the line.",
		"effect": "Snow falls heavily over the line and keeps falling until the wave ends. Anything inside it is slowed, and keeps slowing for a second or two after leaving the snow.",
	},
	"Push": {
		"buttons": MIDDLE, "gesture": "circle_push", "targeting": "angled", "cost": 10.0,
		"school": "Force", "draw": "A circle, then a line going out of it. Everything inside the circle is moved along the line.",
		"effect": "Moves every foe inside the circle along the line. A bigger circle costs more stamina.",
	},
	"Barrier": {
		"buttons": MIDDLE, "gesture": "circle", "targeting": "positional", "cost": 35.0,
		"school": "Force", "draw": "A circle, either way round. The shield wraps around you.",
		"effect": "Shield around you for 6 seconds. Blocks all damage, including enemy contact.",
	},
	"Force Wall": {
		"buttons": MIDDLE, "gesture": "flick", "targeting": "angled", "cost": 15.0,
		"school": "Force", "draw": "Any straight slash. A short-lived force wall appears along its angle.",
		"effect": "Lasts under a second. Shots bounce off it, even the dark wizard's spells. It touches nothing else: you and your foes pass straight through.",
		"preview": "wall",
	},
	"Gravity Well": {
		"buttons": MIDDLE, "gesture": "spiral", "targeting": "positional", "cost": 22.0,
		"school": "Force", "draw": "A spiral that starts wide and winds in to its middle, at least one and a half turns.",
		"effect": "A knot of force forms where the spiral ends and pulls everything around it in for 2 seconds, swallowing shots. It bunches foes up for your next spell. A wider spiral reaches farther.",
	},
	"Blink": {
		"buttons": LEFT | RIGHT, "gesture": "flick", "targeting": "directional", "cost": 6.0,
		"school": "Storm", "draw": "A straight stroke. You zip along it, through anything in your way.",
		"effect": "Teleports you along the stroke, up to 300 px, stopping short of walls. Costs more the farther you go. Foes in the way take 8 damage.",
	},
	"Spark": {
		"buttons": LEFT | RIGHT, "gesture": "zigzag", "targeting": "positional", "cost": 10.0,
		"school": "Storm", "draw": "A tall zigzag going down. Start down and to the left, then zig right. The strike lands at its middle.",
		"effect": "Lightning strikes down from the sky through the middle of your stroke and stops at the first platform or ground it meets. 20 damage.",
	},
	"Storm Cloud": {
		"buttons": LEFT | RIGHT, "gesture": "cloud", "targeting": "shape", "cost": 52.0,
		"school": "Storm", "draw": "The bumpy top of a cloud, drawn across: two or more round bumps in a row.",
		"effect": "A thundercloud hangs there for 6 seconds and every second strikes everyone beneath it, you included, for 10 damage. Platforms shelter whoever is under them. Wider clouds cost more.",
	},
	"Tornado": {
		"buttons": LEFT | RIGHT, "gesture": "tornado", "targeting": "shape", "cost": 30.0,
		"school": "Storm", "draw": "A zigzag going back and forth, wide at the top and narrow at the bottom. A spinning wind touches down under it.",
		"effect": "Lasts 6 seconds. Bats back shots and swirls enemies around inside it.",
	},
	"Stonefall": {
		"buttons": LEFT | MIDDLE, "gesture": "stonefall", "targeting": "positional", "cost": 25.0,
		"school": "Earth", "draw": "A circle, then a line running down from its top. A boulder drops onto the spot.",
		"effect": "A boulder drops onto the ground below after a moment and deals 30 damage to everyone where it lands.",
	},
	"Stone Wall": {
		"buttons": LEFT | MIDDLE, "gesture": "stone_wall", "targeting": "directional", "cost": 30.0,
		"school": "Earth", "draw": "A straight stroke that starts on the ground, a platform or another stone wall. It cannot be drawn in mid-air: the wall grows out of whatever solid thing the stroke starts on.",
		"effect": "A solid stone wall that stays up until a force blast, a Push, knocks it down. The wall is as long as the stroke you draw, and longer walls cost more.",
	},
	"Mudslide": {
		"buttons": LEFT | MIDDLE, "gesture": "pit", "targeting": "shape", "cost": 36.0,
		"school": "Earth", "draw": "A U: down, round the bottom and up again, over the ground. The mud opens on the ground below it.",
		"effect": "The ground turns to mud for 5 seconds. Walkers in it are slowed and cannot jump. Flyers pass over. Wider pits cost more.",
	},
	"Earthquake": {
		"buttons": LEFT | MIDDLE, "gesture": "earthquake", "targeting": "positional", "cost": 75.0,
		"school": "Earth", "draw": "Three mountain peaks, drawn in the air.",
		"effect": "The ground shakes for 6 seconds. The screen shakes, everything on the ground is knocked from side to side, drawing is harder, and ranged enemies aim a few degrees off. Flyers are unaffected.",
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


## What a spell costs. Spells whose size you draw cost more when drawn bigger: a circle's base cost is for one
## 40 px across the middle (Push), a cone's for one reaching 160 px (Fire Breath); lines and boxes scale by their
## width or area.
static func cost_for(spell_name: String, info: Dictionary) -> float:
	var base := cost(spell_name)
	var radius: float = info.get("radius", 0.0)
	var line: PackedVector2Array = info.get("line", PackedVector2Array())
	match spell_name:
		"Blink":
			return maxf(2.0, roundf(base * clampf(info.get("length", 0.0), 0.0, BLINK_MAX) / 100.0))
		"Push":
			if radius > 0.0:
				return roundf(base * clampf(radius / 40.0, 0.5, 4.0))
		"Fire Breath":
			var reach: float = info.get("reach", 0.0)
			if reach > 0.0:
				return roundf(base * clampf(reach / 160.0, 0.7, 1.4))
		"Blizzard":
			var width := _width_of(line)
			if width > 0.0:
				return roundf(base * clampf(width / 100.0, 0.5, 4.0))
		"Storm Cloud":
			var cloud := _width_of(line)
			if cloud > 0.0:
				return roundf(base * clampf(cloud / 150.0, 0.7, 1.8))
		"Stone Wall":
			var length: float = info.get("length", 0.0)
			if length > 0.0:
				return roundf(base * clampf(length / 140.0, 0.5, 1.7))
		"Mudslide":
			var pit := _width_of(line)
			if pit > 0.0:
				return roundf(base * clampf(pit / 140.0, 0.5, 1.7))
		"Ice Prison":
			var box: Rect2 = info.get("rect", Rect2())
			if box.has_area():
				return roundf(base * clampf(box.get_area() / 4900.0, 0.6, 2.5))
		"Icicles":
			return base * int(info.get("pieces", 1))
	return base


## The horizontal span of a drawn line, which is how wide a snowfall, cloud, crack or pit is.
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
