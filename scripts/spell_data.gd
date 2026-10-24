class_name SpellData

## Mouse buttons as bits, so a school can be one button or a combination.
const LEFT := 1
const RIGHT := 2
const MIDDLE := 4

## The farthest a Shadow Step carries the caster, in pixels.
const STEP_MAX := 300.0

## Short damage figure per spell, for the spellbook.
const DAMAGE := {
	"Ignite": "12 damage", "Firewall": "4 damage per half second", "Fire Breath": "3 damage every 0.2 s while in the cone",
	"Smoke Screen": "hides what is behind it", "Flare": "a following light, harmless", "Spark": "20 damage",
	"Frostbolt": "6 damage, slows", "Icicles": "6 damage every half second", "Ice Prison": "freezes foes solid",
	"Blizzard": "slows what is inside", "Frost Bridge": "freezes water into ice", "Geyser": "launches what stands on it",
	"Tsunami": "puts out fires, shoves everyone far",
	"Push": "moves foes", "Barrier": "blocks damage", "Tornado": "swirls foes", "Gust": "blows light things along",
	"Stonefall": "30 damage", "Stone Wall": "solid · must start on solid ground", "Mudslide": "slows, stops jumping",
	"Earthquake": "shakes the ground", "Volcano": "lava damage, sets ground on fire",
	"Bramble": "slows, 3 damage per half second", "Spore Puff": "poison, 2 damage per half second",
	"Liana": "a vine you can climb", "Great Oak": "a tree that falls, 35 damage", "Flytrap": "snaps shut on whoever steps in",
	"Lily Pads": "floating leaves to walk on",
	"Decoy": "enemies attack it instead of you", "Eclipse": "enemies inside see very little", "Hex": "the marked take 50% more damage",
	"Abyss": "pulls everything in", "Shadow Step": "8 damage to foes in the way",
}

## Colour of each school: used to tint the enemies of that school and to glow the spells.
const SCHOOL_COLORS := {
	"Fire": Color("#ff6a2a"),
	"Water": Color("#7fd8ff"),
	"Air": Color("#d8e4ee"),
	"Earth": Color("#b8864a"),
	"Flora": Color("#6fcf6a"),
	"Shadow": Color("#7a5aa0"),
}

## A spell that is not the colour of its school (Spark is lightning, though it is a Fire spell).
const SPELL_COLORS := {
	"Spark": Color("#ffe85a"),
}

## The schools, each cast with its own mouse buttons.
const SCHOOL_BUTTONS := {
	"Fire": LEFT,
	"Water": RIGHT,
	"Air": MIDDLE,
	"Earth": LEFT | RIGHT,
	"Flora": LEFT | MIDDLE,
	"Shadow": RIGHT | MIDDLE,
}

## Single source of truth for fast spells: which mouse button and gesture cast them, what they cost,
## and the text the spellbook shows. The caster, arena and spellbook all read from here.
## Each gesture is a picture of what the spell does.

const SPELLS := {
	# Fire
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
	"Smoke Screen": {
		"buttons": LEFT, "gesture": "smoke", "targeting": "shape", "cost": 18.0,
		"school": "Fire", "draw": "A wavy line going up. The smoke billows along it.",
		"effect": "A bank of smoke for 12 seconds. Enemies cannot see through it, so they lose track of you behind it. Wind (Tornado, Gust) and water clear it. A longer line makes more smoke.",
	},
	"Flare": {
		"buttons": LEFT, "gesture": "flare", "targeting": "positional", "cost": 9.0,
		"school": "Fire", "draw": "A flame: a loop that comes to a point at the top.",
		"effect": "A small harmless flame hovers in front of you, wherever you face, and follows you, lighting the dark for 20 seconds. It cuts through an Eclipse and burns nothing.",
	},
	"Spark": {
		"buttons": LEFT, "gesture": "zigzag", "targeting": "positional", "cost": 10.0,
		"school": "Fire", "draw": "A tall zigzag going down. Start down and to the left, then zig right. The strike lands at its middle.",
		"effect": "Lightning strikes down from the sky through the middle of your stroke and stops at the first platform or ground it meets. 20 damage.",
	},
	# Water
	"Frostbolt": {
		"buttons": RIGHT, "gesture": "flick", "targeting": "directional", "cost": 15.0,
		"school": "Water", "draw": "Straight stroke, not vertical. Same stroke as Ignite.",
		"effect": "Bolt along your stroke. 6 damage and slows the enemy for 2 seconds.",
	},
	"Icicles": {
		"buttons": RIGHT, "gesture": "icicles", "targeting": "shape", "cost": 16.0,
		"school": "Water", "draw": "One or more Vs in a row. Each V hangs one icicle from the ceiling over it, so cast it under a ceiling.",
		"effect": "Each icicle stands until the wave ends, or until fire melts it. An enemy that walks through one takes 6 damage. Costs 8 stamina per icicle.",
	},
	"Ice Prison": {
		"buttons": RIGHT, "gesture": "circle", "targeting": "shape", "cost": 14.0,
		"school": "Water", "draw": "A circle, drawn round your target and closed where you started. The circle fills with ice.",
		"effect": "Enemies inside are frozen solid for 3 seconds; Push or Earth shatters them out for extra damage. Drawn round nobody, it fizzles. Bigger circles cost more.",
	},
	"Blizzard": {
		"buttons": RIGHT, "gesture": "snowfall", "targeting": "shape", "cost": 20.0,
		"school": "Water", "draw": "A five-pointed star drawn in one swift stroke, then a horizontal line. Snow falls along the line.",
		"effect": "Snow falls heavily over the line and keeps falling until the wave ends. Anything inside it is slowed, and keeps slowing for a second or two after leaving the snow.",
	},
	"Frost Bridge": {
		"buttons": RIGHT, "gesture": "wave", "targeting": "shape", "cost": 18.0,
		"school": "Water", "draw": "A wavy line, drawn across the water you want to freeze.",
		"effect": "Water along the line freezes into ice you can walk on. Fire melts it.",
	},
	"Geyser": {
		"buttons": RIGHT, "gesture": "geyser", "targeting": "shape", "cost": 20.0,
		"school": "Water", "draw": "A mountain: an upward-pointing triangle with a line up through its middle, the same shape as a Volcano. Draw it on the ground.",
		"effect": "The ground bubbles, then a jet of water bursts under the middle of the shape and throws whatever stands on it high into the air.",
	},
	"Tsunami": {
		"buttons": RIGHT, "gesture": "tsunami", "targeting": "positional", "cost": 90.0,
		"school": "Water", "draw": "A big wave: a long rise, then the crest curling over. The way the crest curls is the way the wave runs.",
		"effect": "A wall of water sweeps the whole map. It puts out every fire, washes away smoke and spores, sinks lily pads and shoves everyone in it a long way, you included. High ground, a stone wall or flying keeps you out of it.",
	},
	# Air
	"Push": {
		"buttons": MIDDLE, "gesture": "circle_push", "targeting": "angled", "cost": 10.0,
		"school": "Air", "draw": "A circle, then a line going out of it. Everything inside the circle is moved along the line.",
		"effect": "Moves every foe inside the circle along the line, and turns shots. It is the only spell that can lift you. A bigger circle costs more stamina.",
	},
	"Barrier": {
		"buttons": MIDDLE, "gesture": "circle", "targeting": "positional", "cost": 35.0,
		"school": "Air", "draw": "A circle, either way round. The shield wraps around you.",
		"effect": "Shield around you for 6 seconds. Blocks all damage, including enemy contact.",
	},
	"Tornado": {
		"buttons": MIDDLE, "gesture": "tornado", "targeting": "shape", "cost": 30.0,
		"school": "Air", "draw": "A coil going down: a tall, narrow spiral, like a drill bit. A spinning wind touches down under it.",
		"effect": "Lasts 6 seconds. Bats back shots and swirls enemies around inside it.",
	},
	"Gust": {
		"buttons": MIDDLE, "gesture": "flick", "targeting": "directional", "cost": 14.0,
		"school": "Air", "draw": "A straight stroke. The wind blows the way you draw it.",
		"effect": "Wind blows along your stroke for a moment. It sweeps light things away: shots, flyers, smoke and spores, and it knocks you and walkers sideways, but heavy foes hardly move.",
	},
	# Earth
	"Stonefall": {
		"buttons": LEFT | RIGHT, "gesture": "stonefall", "targeting": "positional", "cost": 25.0,
		"school": "Earth", "draw": "A circle, then a line running down from its top. A boulder drops onto the spot.",
		"effect": "A boulder drops onto the ground below after a moment and deals 30 damage to everyone where it lands.",
	},
	"Stone Wall": {
		"buttons": LEFT | RIGHT, "gesture": "stone_wall", "targeting": "directional", "cost": 30.0,
		"school": "Earth", "draw": "A straight stroke that starts on the ground, a platform or another stone wall. It cannot be drawn in mid-air: the wall grows out of whatever solid thing the stroke starts on.",
		"effect": "A solid stone wall that stays up until shots, an Earthquake or a Stonefall wear it down. The wall is as long as the stroke you draw, and longer walls cost more.",
	},
	"Mudslide": {
		"buttons": LEFT | RIGHT, "gesture": "pit", "targeting": "shape", "cost": 36.0,
		"school": "Earth", "draw": "A U: down, round the bottom and up again, over the ground. The mud opens on the ground below it.",
		"effect": "The ground turns to mud until the wave ends. Walkers in it are slowed and cannot jump. Flyers pass over. Wider pits cost more.",
	},
	"Earthquake": {
		"buttons": LEFT | RIGHT, "gesture": "earthquake", "targeting": "positional", "cost": 75.0,
		"school": "Earth", "draw": "Three mountain peaks, drawn in the air.",
		"effect": "The ground shakes for 6 seconds. The screen shakes, everything on the ground is knocked from side to side, drawing is harder, and ranged enemies aim a few degrees off. Stone walls and trees take a beating. Flyers are unaffected.",
	},
	"Volcano": {
		"buttons": LEFT | RIGHT, "gesture": "volcano", "targeting": "shape", "cost": 50.0,
		"school": "Earth", "draw": "A mountain: an upward-pointing triangle, drawn in one stroke.",
		"effect": "Erupts for a few seconds, throwing lava balls. Each one sets the ground or platform it lands on on fire.",
	},
	# Flora
	"Bramble": {
		"buttons": LEFT | MIDDLE, "gesture": "bramble", "targeting": "shape", "cost": 22.0,
		"school": "Flora", "draw": "A low row of sharp thorns: a sawtooth line, drawn along the ground.",
		"effect": "A thicket grows along the line. Whoever walks through is slowed and pricked. Fire burns it away. A longer line makes a longer thicket.",
	},
	"Spore Puff": {
		"buttons": LEFT | MIDDLE, "gesture": "cone", "targeting": "cone", "cost": 20.0,
		"school": "Flora", "draw": "A cone, like <, just as for Fire Breath. The point is you; spores sprays out toward the open end.",
		"effect": "Poison spores pour out of your mouth and drift for about 5 seconds, hurting whoever breathes them. Ground and walls stop them; wind and water clear them. A longer cone reaches farther and costs more.",
	},
	"Liana": {
		"buttons": LEFT | MIDDLE, "gesture": "vine", "targeting": "shape", "cost": 18.0,
		"school": "Flora", "draw": "A leaf, then a line up: an almond standing on its point, drawn round and back to the point, then a straight line up from there.",
		"effect": "A vine grows up out of the ground where the line began, as high as the line you drew, and holds for 30 seconds. Stand at it and press W or S to climb. Fire burns it.",
	},
	"Great Oak": {
		"buttons": LEFT | MIDDLE, "gesture": "tree", "targeting": "shape", "cost": 52.0,
		"school": "Flora", "draw": "A tree: a trunk drawn up from the ground, ending in a big round crown.",
		"effect": "A great tree grows where the trunk began. Its branches are ledges to stand on, and it is a wall until it is broken. Fire, Earthquake and Stonefall bring it down, and when it falls it crushes everything beneath it, you included.",
	},
	"Flytrap": {
		"buttons": LEFT | MIDDLE, "gesture": "jaws", "targeting": "positional", "cost": 26.0,
		"school": "Flora", "draw": "Open jaws: a tall narrow W.",
		"effect": "A plant grows on the ground and waits up to a minute. Whoever steps on it is snapped up and held, you included. Flyers pass over. Fire burns it.",
	},
	"Lily Pads": {
		"buttons": LEFT | MIDDLE, "gesture": "pads", "targeting": "shape", "cost": 18.0,
		"school": "Flora", "draw": "A row of flat ovals, drawn as a chain of low loops.",
		"effect": "Floating leaves appear along the row. You can stand on them for 8 seconds, and then they sink. Fire burns them.",
	},
	# Shadow
	"Decoy": {
		"buttons": RIGHT | MIDDLE, "gesture": "eight", "targeting": "positional", "cost": 20.0,
		"school": "Shadow", "draw": "A figure of eight.",
		"effect": "A shadow of you stands where you drew it for 8 seconds. Enemies that notice it attack it instead of you.",
	},
	"Eclipse": {
		"buttons": RIGHT | MIDDLE, "gesture": "crescent", "targeting": "positional", "cost": 22.0,
		"school": "Shadow", "draw": "A crescent moon: a curve like a C.",
		"effect": "Darkness settles over the area for 10 seconds. Enemies inside see only what is right in front of them. A Flare cuts through it.",
	},
	"Hex": {
		"buttons": RIGHT | MIDDLE, "gesture": "pentagram", "targeting": "positional", "cost": 20.0,
		"school": "Shadow", "draw": "A five-pointed star in one stroke, never lifting: point to point, straight lines, until it closes. Draw it over your target.",
		"effect": "Whoever the star is drawn over is cursed for 8 seconds and takes 50% more damage from everything.",
	},
	"Abyss": {
		"buttons": RIGHT | MIDDLE, "gesture": "spiral", "targeting": "positional", "cost": 22.0,
		"school": "Shadow", "draw": "A spiral that starts wide and winds in to its middle, at least one and a half turns.",
		"effect": "A dark knot forms where the spiral ends and pulls everything around it in for 2 seconds, swallowing shots. It bunches foes up for your next spell. A wider spiral reaches farther.",
	},
	"Shadow Step": {
		"buttons": RIGHT | MIDDLE, "gesture": "flick", "targeting": "directional", "cost": 6.0,
		"school": "Shadow", "draw": "A straight stroke. You slip along it, through anything in your way.",
		"effect": "You vanish and surface along the stroke, up to 300 px, stopping short of walls. Costs more the farther you go. Foes in the way take 8 damage.",
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


## The colour a spell glows: its own, or its school's.
static func color_of(spell_name: String) -> Color:
	if SPELL_COLORS.has(spell_name):
		return SPELL_COLORS[spell_name]
	return SCHOOL_COLORS[SPELLS[spell_name]["school"]]


## What a spell costs. Spells whose size you draw cost more when drawn bigger: a circle's base cost is for one
## 40 px across the middle (Push), a cone's for one reaching 160 px (Fire Breath); lines and boxes scale by their
## width or area.
static func cost_for(spell_name: String, info: Dictionary) -> float:
	var base := cost(spell_name)
	var radius: float = info.get("radius", 0.0)
	var line: PackedVector2Array = info.get("line", PackedVector2Array())
	match spell_name:
		"Shadow Step":
			return maxf(2.0, roundf(base * clampf(info.get("length", 0.0), 0.0, STEP_MAX) / 100.0))
		"Push":
			if radius > 0.0:
				return roundf(base * clampf(radius / 40.0, 0.5, 4.0))
		"Fire Breath", "Spore Puff":
			var reach: float = info.get("reach", 0.0)
			if reach > 0.0:
				return roundf(base * clampf(reach / 160.0, 0.7, 1.4))
		"Blizzard":
			var width := width_of(line)
			if width > 0.0:
				return roundf(base * clampf(width / 100.0, 0.5, 4.0))
		"Smoke Screen", "Bramble", "Frost Bridge", "Lily Pads":
			var span := width_of(line)
			var height := absf(line[0].y - line[line.size() - 1].y) if line.size() > 1 else 0.0
			var length := maxf(span, height)
			if length > 0.0:
				return roundf(base * clampf(length / 120.0, 0.6, 2.0))
		"Stone Wall":
			var length: float = info.get("length", 0.0)
			if length > 0.0:
				return roundf(base * clampf(length / 140.0, 0.5, 1.7))
		"Mudslide":
			var pit := width_of(line)
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
