class_name PartsLook
extends RefCounted

## A wizard made of parts: skin, outfit and its color, hair, beard, hat and a weapon. The whole choice is kept as one String, the look, which is what
## the game passes around everywhere (the settings, the network, the epilogue). "parts:3:" and then the values in ORDER, joined with dots. (Looks of "parts:1:" and "parts:2:", from before the voices, the trim and the boots were chosen, are still read: see `decode`.)
## The parts themselves, and what each can be, are in res://art/parts/manifest.json (see PartFrames).

const PREFIX := "parts:3:"
const ORDER := ["skin", "outfit", "color", "trim", "hair", "hair_color", "beard", "beard_color", "hat", "hat_color", "boots", "weapon", "voice"]
## The orders of the looks of the older games, and what each is missing.
const ORDER_2 := ["skin", "outfit", "color", "hair", "hair_color", "beard", "beard_color", "hat", "hat_color", "weapon", "voice"]
const ORDER_1 := ["skin", "outfit", "color", "hair", "hair_color", "beard", "beard_color", "hat", "hat_color", "weapon"]
## Beards that were taken out because they looked like another, and the one each is read as.
const BEARD_NOW := {"braided": "short", "wispy": "goatee"}
## What an outfit of the older games was edged in: gold, but silver (here the nearest, ivory) for these colors.
const SILVER_TRIMMED := ["charcoal", "black", "lavender", "gold"]
## The voices (not art, so not in the manifest): the sound a wizard makes when it jumps. See WizardLook.jump_sound.
const VOICES := ["voice_1", "voice_2", "voice_3"]
const DEFAULT := {
	"skin": "tan", "outfit": "coat", "color": "blue", "trim": "charcoal", "hair": "short", "hair_color": "auburn", "beard": "short",
	"beard_color": "auburn", "hat": "wide", "hat_color": "blue", "boots": "brown", "weapon": "staff_orb", "voice": "voice_1",
}


const HAT_NO_COLOR := ["none", "circlet", "horned", "skull", "laurel", "crown", "tiara", "flower_crown"]  # hats with no color of their own (keep in step with tools/wizard_parts/parts.py)
const DEFAULT_LOOK := "parts:3:tan.coat.blue.charcoal.short.auburn.short.auburn.wide.blue.brown.staff_orb.voice_1"  # DEFAULT, written down


## Every option and the values it can have: the parts' (from the manifest) and the voices.
static func options_of_all() -> Dictionary:
	var options: Dictionary = (PartFrames.manifest()["options"] as Dictionary).duplicate()
	options["voice"] = VOICES
	return options


## What a person starting out wears: the test character the art was made with.
static func default_config() -> Dictionary:
	return DEFAULT.duplicate()


static func default_look() -> String:
	return DEFAULT_LOOK


## True for a look made of parts, valid or not.
static func is_parts(look: String) -> bool:
	return look.begins_with("parts:")


## True for a look made of parts whose every value is one the parts have. A look arrives over the network, so this is what is trusted.
static func is_valid(look: String) -> bool:
	return not decode(look).is_empty()


## The look for a choice (see decode for what a choice holds).
static func encode(config: Dictionary) -> String:
	var values := PackedStringArray()
	for option: String in ORDER:
		values.append(str(config.get(option, "")))
	return PREFIX + ".".join(values)


## The choice in a look, as option -> value, or empty when the look is not one of parts or holds a value there is no part for.
static func decode(look: String) -> Dictionary:
	var values: PackedStringArray
	var order: Array = ORDER
	if look.begins_with(PREFIX):
		values = look.substr(PREFIX.length()).split(".")
	elif look.begins_with("parts:2:"):
		values = look.substr(8).split(".")
		order = ORDER_2
	elif look.begins_with("parts:1:"):
		values = look.substr(8).split(".")
		order = ORDER_1
	else:
		return {}
	if values.size() != order.size():
		return {}
	var options := options_of_all()
	var config := {}
	for k in order.size():
		config[order[k]] = values[k]
	if order != ORDER:  # a look from an older game: what it had not yet chosen is what it was drawn with
		config["trim"] = "ivory" if SILVER_TRIMMED.has(config["color"]) else "gold"
		config["boots"] = "brown"
		config["beard"] = BEARD_NOW.get(config["beard"], config["beard"])
		config["beard_color"] = config["beard_color"] if (options["beard_color"] as Array).has(config["beard_color"]) else config["hair_color"]
		if not config.has("voice"):
			config["voice"] = VOICES[0]
	for option: String in ORDER:
		if not (options[option] as Array).has(config[option]):
			return {}
	return config


## A choice made at random: every combination of parts is a good one.
static func random_config(rng: RandomNumberGenerator) -> Dictionary:
	var options := options_of_all()
	var config := {}
	for option: String in ORDER:
		var values: Array = options[option]
		config[option] = values[rng.randi() % values.size()]
	return tied(config)


## A beard is the color of the hair, and a hat the color of the robe.
static func tied(config: Dictionary) -> Dictionary:
	config["beard_color"] = config["hair_color"]
	config["hat_color"] = config["color"]
	return config


## The look of a wizard nobody chose (a seat's, a brain's): the same on every machine for the same seed.
static func seeded_look(seed_value: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return encode(random_config(rng))


## The look with one option set to another value (the creator changes one at a time).
static func with_option(look: String, option: String, value: String) -> String:
	var config := decode(look)
	if config.is_empty():
		config = default_config()
	config[option] = value
	return encode(tied(config))


## The value of one option in a look (the default's when the look is not valid).
static func option_of(look: String, option: String) -> String:
	var config := decode(look)
	if config.is_empty():
		config = DEFAULT
	return config[option]
