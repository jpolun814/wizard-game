class_name LikenessPanel
extends CanvasLayer

## The wizard maker, opened in the waiting room by the words at the glowing spot on the hill: a wizard is made of parts, and each is chosen here (see PartsLook).
## What is chosen is put on the wizard at once, kept for next time (see GameSettings) and told to everyone else in the game.

signal closed

## The rows, in order: the option and what the row is called. A color row goes away when what it colors is not there.
const ROWS := [
	["skin", ""], ["outfit", "Outfit"], ["color", ""], ["hair", "Hair"], ["hair_color", ""], ["beard", "Beard"], ["hat", "Hat"], ["weapon", "Weapon"], ["voice", "Voice"],
]
## The options chosen by a color alone, with no words: a row of squares. (The beard takes the hair's color and the hat the robe's: see PartsLook.tied.)
const COLOR_ROWS := ["skin", "color", "hair_color"]
## What each value is called to the person choosing.
const NAMES := {
	"pale": "Pale", "light": "Light", "tan": "Tan", "brown": "Brown", "deep": "Deep", "sage": "Sage",
	"coat": "Coat", "robe": "Robe", "tunic": "Tunic", "cloak": "Cloak", "ceremonial": "Ceremonial robe", "rags": "Rags", "gothic": "Gothic coat", "armored": "Armor",
	"blue": "Blue", "purple": "Purple", "crimson": "Crimson", "emerald": "Emerald", "charcoal": "Charcoal", "ivory": "Ivory",
	"none": "None", "short": "Short", "long": "Long", "ponytail": "Ponytail", "bun": "Bun", "goatee": "Goatee", "mohawk": "Mohawk", "braids": "Braid", "straight": "Straight", "balding": "Balding", "wild": "Wild",
	"braided": "Braided", "handlebar": "Handlebar", "wispy": "Wispy", "stubble": "Stubble",
	"white": "White", "gray": "Gray", "black": "Black", "auburn": "Auburn", "blonde": "Blonde",
	"pointy": "Pointed hat", "wide": "Witch hat", "hood": "Hood", "circlet": "Circlet", "horned": "Horned helm", "skull": "Skull crown", "laurel": "Laurel", "turban": "Turban", "mushroom": "Mushroom cap", "crown": "Crown",
	"staff_orb": "Orb staff", "staff_crystal": "Crystal staff", "staff_branch": "Branch staff", "wand": "Wand", "scepter": "Scepter",
	"voice_1": "Voice 1", "voice_2": "Voice 2", "voice_3": "Voice 3",
	"gown": "Gown", "bodice": "Bodice", "bob": "Bob", "pigtails": "Pigtails", "wavy": "Wavy", "updo": "Updo", "tonsure": "Tonsure", "tiara": "Tiara", "flower_crown": "Flower crown", "headscarf": "Headscarf", "rose_wand": "Rose wand", "staff_flower": "Flower staff",
	"staff_skull": "Skull staff", "staff_moon": "Moon staff", "staff_root": "Root staff", "staff_lantern": "Lantern staff", "crook": "Crook", "book": "Spellbook", "orb_hand": "Orb", "bone_wand": "Bone wand",
}
## The color shown beside a value that is a color (the middle shade of the parts' own).
const SWATCHES := {
	"pale": "#e2bca6", "light": "#cf9877", "tan": "#b87e52", "brown": "#8a5632", "deep": "#784a32", "sage": "#78a45e", "pink": "#ee86b0", "violet": "#9a68d0", "silver": "#c4cad6", "ashen": "#aeaeb8", "frost": "#94bedc", "undead": "#8a9a74", "fair": "#ecc8b4", "olive": "#bc9262", "bronze": "#9a6a3e", "ebony": "#563424", "plum": "#8a6890",
	"blue": "#3f60c8", "purple": "#7e58b6", "crimson": "#b83a46", "emerald": "#2e9a64", "charcoal": "#4a4a60", "ivory": "#d6cdb4", "rose": "#d0607e", "lavender": "#a688d6", "gold": "#d6a83a", "teal": "#2a9ca0", "rust": "#b85a2c",
	"white": "#d4cecd", "gray": "#96949e", "black": "#34343f", "auburn": "#ac4a2c", "blonde": "#e8c870", "platinum": "#e8e4cc", "ginger": "#d27a38", "chestnut": "#8a523a", "espresso": "#46302c", "midnight": "#38406a",
}
const PREVIEW_SIZE := Vector2(300.0, 230.0)
const PREVIEW_SCALE := 2.0  # whole numbers only: it is pixel art

var wizard: Wizard  # the one the person plays, which wears what is chosen
var _plate: PanelContainer
var _rows: Dictionary = {}     # option -> its row
var _values: Dictionary = {}   # option -> the label with the value's name
var _dots: Dictionary = {}     # option -> the swatch beside it
var _sprite: AnimatedSprite2D  # the picture of the wizard being made
var _magic: MagicLayer
var _shown := ""               # the look the picture shows


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.14, 0.94)
	style.border_color = Lettering.GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(18)
	plate.add_theme_stylebox_override("panel", style)
	_plate = plate
	var margin := MarginContainer.new()  # the plate stands at the left, halfway down
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(side)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	plate.add_child(column)
	column.add_child(Lettering.heading("Your wizard", 30, Color(0.9, 0.8, 1.0)))
	column.add_child(_make_preview())
	for row: Array in ROWS:
		column.add_child(_make_squares(row[0]) if COLOR_ROWS.has(row[0]) else _make_row(row[0], row[1]))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	buttons.add_child(_button("Random", _randomize))
	buttons.add_child(_button("Done", close))
	_show_choice()


## Where the plate is on the screen.
func plate_rect() -> Rect2:
	return _plate.get_global_rect()


func close() -> void:
	Sfx.play("ui_click")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"Choice"
	button.focus_mode = Control.FOCUS_NONE  # the keys are the wizard's: Space must jump, not press a button
	button.pressed.connect(action)
	return button


## The wizard as they are made, standing in a frame, at twice their size.
func _make_preview() -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = PREVIEW_SIZE
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feet := Node2D.new()
	feet.position = Vector2(PREVIEW_SIZE.x * 0.5, PREVIEW_SIZE.y - 14.0)
	feet.scale = Vector2.ONE * PREVIEW_SCALE
	feet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(feet)
	_sprite = AnimatedSprite2D.new()
	_sprite.offset = PartFrames.OFFSET
	feet.add_child(_sprite)
	_magic = MagicLayer.new()
	feet.add_child(_magic)
	return frame


## A row of squares of color, one to a choice, the chosen one ringed.
func _make_squares(option: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if option == "skin":
		var name_label := Label.new()  # (the others are plain to see on the wizard; skin is the one that is not)
		name_label.text = "Skin"
		name_label.custom_minimum_size = Vector2(50.0, 0.0)
		row.add_child(name_label)
	var squares := {}
	for value: String in PartFrames.manifest()["options"][option]:
		var square := Button.new()
		square.focus_mode = Control.FOCUS_NONE
		square.custom_minimum_size = Vector2(30.0, 30.0)
		square.pressed.connect(_choose.bind(option, value))
		row.add_child(square)
		squares[value] = square
	_rows[option] = row
	_dots[option] = squares
	return row


## Paints a square: its color, with a gold ring when it is the one chosen.
func _paint_square(square: Button, value: String, chosen: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(SWATCHES[value]).lightened(0.12 if state == "hover" else 0.0)
		box.set_border_width_all(3 if chosen else 1)
		box.border_color = Lettering.GOLD if chosen else Color(0.0, 0.0, 0.0, 0.7)
		square.add_theme_stylebox_override(state, box)


## A row: what it is called, an arrow to the one before, what it is now (with its color), and an arrow to the next.
func _make_row(option: String, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(120.0, 0.0)
	row.add_child(label)
	row.add_child(_arrow("<", _step.bind(option, -1)))
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(14.0, 14.0)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var value := Label.new()
	value.custom_minimum_size = Vector2(108.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	row.add_child(_arrow(">", _step.bind(option, 1)))
	_rows[option] = row
	_values[option] = value
	_dots[option] = dot
	return row


func _arrow(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30.0, 0.0)
	button.pressed.connect(action)
	return button


## The wizard this person is making: what they chose, or what they start with.
func _current() -> String:
	return Net.look_of(Net.my_id())


## Moves an option to the next value, or the one before it (it comes round).
func _step(option: String, way: int) -> void:
	var values: Array = PartsLook.options_of_all()[option]
	var at := values.find(PartsLook.option_of(_current(), option))
	_choose(option, values[posmod(at + way, values.size())])


func _choose(option: String, value: String) -> void:
	Sfx.play("ui_click")
	GameSettings.set_value("look", PartsLook.with_option(_current(), option, value))
	_changed()
	if option == "voice":
		Sfx.play(WizardLook.jump_sound(_current()))  # a voice is heard when it is chosen


func _randomize() -> void:
	Sfx.play("ui_click")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	GameSettings.set_value("look", PartsLook.encode(PartsLook.random_config(rng)))
	_changed()


## What was chosen is worn at once, and told to the others.
func _changed() -> void:
	wizard.look = _current()
	Net.say_style()
	_show_choice()


## The rows show what is chosen, and the picture is of it.
func _show_choice() -> void:
	var look := _current()
	var config := PartsLook.decode(look)
	for option: String in _rows:
		var value: String = config[option]
		if COLOR_ROWS.has(option):
			var squares: Dictionary = _dots[option]
			for each: String in squares:
				_paint_square(squares[each], each, each == value)
			continue
		(_values[option] as Label).text = NAMES.get(value, value.capitalize())
		var dot: ColorRect = _dots[option]
		dot.visible = SWATCHES.has(value)
		if dot.visible:
			dot.color = Color(SWATCHES[value])
	if look != _shown:
		_shown = look
		_sprite.sprite_frames = PartFrames.body(look, true)
		_sprite.play("idle")
		_magic.attach(_sprite, config["weapon"])
		_magic.paint(SpellData.SCHOOL_COLORS["Fire"])
