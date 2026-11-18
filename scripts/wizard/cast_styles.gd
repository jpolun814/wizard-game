class_name CastStyles
extends RefCounted

## How a wizard made of parts moves its body when a spell goes off: which of the casting animations (see res://art/parts/manifest.json) each spell plays. A spell
## that is not here plays "release", the staff thrust forward. The animations only show the wizard: what the spell does is drawn by the spell.
## (The art session tagged each spell with a style and said some tags may be off and to keep them anyway, so they are kept as they were said.)

const STYLES := {
	# thrown from the free hand: only what a wizard would really throw
	"Pebble": "throw", "Barbs": "throw",
	# a sweep of the staff
	"Thorn Whip": "sweep", "Scythe": "sweep", "Gust": "sweep", "Push": "sweep", "Tornado": "sweep",
	# the staff raised at the sky
	"Spark": "cast_sky", "Stonefall": "cast_sky", "Moonbeam": "cast_sky", "Hailstorm": "cast_sky", "Icicles": "cast_sky", "Blizzard": "cast_sky", "Eclipse": "cast_sky", "Supernova": "cast_sky",
	# the staff driven into the ground
	"Earthquake": "cast_ground", "Stalagmite": "cast_ground", "Stone Wall": "cast_ground", "Sinkhole": "cast_ground", "Geyser": "cast_ground",
	"Bramble": "cast_ground", "Great Oak": "cast_ground", "Glowcap": "cast_ground", "Flytrap": "cast_ground", "Liana": "cast_ground",
	"Mudslide": "cast_ground", "Lily Pads": "cast_ground", "Frost Bridge": "cast_ground", "Firewall": "cast_ground",
	# drawing power into oneself
	"Adrenaline": "empower", "Crimson Veil": "empower", "Obsidian Armor": "empower", "Golem": "empower", "Barrier": "empower", "Hunter's Mark": "empower",
	"Thunderclap": "clap",
	"Raise Dead": "summon", "Invincible Snail": "summon", "Decoy": "summon", "Insect Plague": "summon", "Mirage": "summon",
	"Hex": "curse", "Hemorrhage": "curse", "Faint": "curse", "Fight or Flight": "curse", "Silence": "curse",
	"Sneak": "vanish", "Shadow Step": "appear",  # (a Shadow Step is over at the other end, so the wizard arrives)
	"Rocket Jump": "rocket",
	# kept up for as long as the spell lasts
	"Fire Breath": "exhale", "Spore Puff": "exhale", "Water Jet": "exhale",
	"Eldritch Blast": "beam", "Leech": "beam",
}

## How long the animations that are kept up are held, in seconds: a breath goes on for as long as the fire pours out.
const HELD := {"exhale": 1.1, "beam": 0.6}


## The animation the body plays for a spell, or "release" for one with no style of its own.
static func anim_for(spell: String) -> String:
	return STYLES.get(spell, "release")


## True for a style that is held for a while and that drawing the next spell cuts short, rather than one that is played once.
static func is_held(anim: String) -> bool:
	return HELD.has(anim)
