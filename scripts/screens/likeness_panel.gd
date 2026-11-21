class_name LikenessPanel
extends CanvasLayer

## The wizard maker, opened in the waiting room by the words at the glowing spot on the hill: a wizard is made of parts, and each is chosen here (see PartsLook).
## What is chosen is put on the wizard at once, kept for next time (see GameSettings) and told to everyone else in the game.

signal closed

## The options chosen by a color alone, with no words: a row of squares. (The beard takes the hair's color: see PartsLook.tied.)
const COLOR_ROWS := ["skin", "color", "trim", "hair_color", "hat_color", "boots"]
## What each value is called to the person choosing.
const NAMES := {
	"coat": "Coat", "robe": "Robe", "tunic": "Tunic", "cloak": "Cloak", "ceremonial": "Ceremonial robe", "rags": "Rags", "gothic": "Gothic coat", "armored": "Armor",
	"vest": "Vest", "pelt": "Pelt", "sash": "Sash", "toga": "Toga",
	"none": "None", "short": "Short", "long": "Long", "ponytail": "Ponytail", "bun": "Bun", "goatee": "Goatee", "mohawk": "Mohawk", "braids": "Braid", "straight": "Straight", "balding": "Balding", "wild": "Wild",
	"handlebar": "Handlebar", "stubble": "Stubble",
	"pointy": "Pointed hat", "wide": "Witch hat", "hood": "Hood", "circlet": "Circlet", "horned": "Horned helm", "skull": "Skull crown", "laurel": "Laurel", "turban": "Turban", "mushroom": "Mushroom cap", "crown": "Crown",
	"voice_1": "Man 1", "voice_3": "Man 2", "voice_4": "Woman 1", "voice_5": "Woman 2",
	"staff_orb": "Orb staff", "staff_crystal": "Crystal staff", "staff_branch": "Branch staff", "wand": "Wand", "scepter": "Scepter",
	"gown": "Gown", "bodice": "Bodice", "bob": "Bob", "pigtails": "Pigtails", "wavy": "Wavy", "updo": "Updo", "tonsure": "Tonsure", "tiara": "Tiara", "flower_crown": "Flower crown", "headscarf": "Headscarf", "rose_wand": "Rose wand", "staff_flower": "Flower staff",
	"staff_skull": "Skull staff", "staff_moon": "Moon staff", "staff_root": "Root staff", "staff_lantern": "Lantern staff", "crook": "Crook", "book": "Spellbook", "orb_hand": "Orb", "bone_wand": "Bone wand",
}
## The color shown beside a value that is a color (the middle shade of the parts' own).
const SWATCHES := {
	"pale": "#f0cdbc", "light": "#c99870", "tan": "#9c6438", "brown": "#624430", "deep": "#4c2c1c", "violet": "#9a68e0", "silver": "#b8c0d0", "frost": "#c4e8f8",
	"fair": "#d8aa8a", "olive": "#a88050", "bronze": "#80502a", "ebony": "#36201a", "blue": "#3f60c8", "purple": "#7e58b6", "crimson": "#b02a3a", "emerald": "#34b070",
	"charcoal": "#4a4a60", "ivory": "#d6cdb4", "rose": "#d0607e", "lavender": "#a688d6", "gold": "#f0c040", "teal": "#2a9ca0", "rust": "#b85a2c", "white": "#d4cecd",
	"gray": "#86848f", "black": "#30303c", "auburn": "#9a3e26", "blonde": "#d8b868", "ginger": "#cc6a2e", "chestnut": "#7a4630", "midnight": "#38447c", "orc": "#667e3e",
	"zombie": "#7c8a6c", "duergar": "#78748c", "vampire": "#bcc6da", "frostborn": "#86b2d6", "infernal": "#a03a38", "spectral": "#6ee0d0", "bone": "#f1ecde",
	"ember": "#ff8a30", "aqua": "#60e8d8",
}
## Boots are colored apart from the cloth and the hair, and share some of their names ("brown", "black"), so they have squares of their own. (Trim is colored like the cloth.)
const BOOT_SWATCHES := {"brown": "#4b2c18", "black": "#2c2c36", "tan": "#a06e3c", "gray": "#6e6e7c", "red": "#8a2e3a", "green": "#466a3c"}
const PREVIEW_SIZE := Vector2(250.0, 440.0)
const PREVIEW_SCALE := 4.0  # whole numbers only: it is pixel art
const SWATCH := 20.0
const INK := Color("#f0e6d0")   # the cream of a plate's writing
const DIM := Color("#a89cc0")   # what a row is called
const EDGE := Color(0.36, 0.26, 0.5)  # the violet edge of the interface's buttons and fields
## The rows set apart in groups, with a rule between each.
const GROUPS := [["skin"], ["hair", "hair_color", "beard"], ["outfit", "color", "trim", "hat", "hat_color", "boots"], ["weapon", "voice"]]
## What each row is called.
const TITLES := {"skin": "Skin", "outfit": "Outfit", "color": "Outfit color", "trim": "Trim", "hair": "Hair", "hair_color": "Hair color", "beard": "Beard", "hat": "Hat", "hat_color": "Hat color", "boots": "Boots", "weapon": "Weapon", "voice": "Voice"}

var wizard: Wizard  # the one the person plays, which wears what is chosen
var _plate: PanelContainer
var _values: Dictionary = {}   # option -> the label with the value's name
var _rows: Dictionary = {}     # option -> the whole row of colors, so one can be hidden
var _squares: Dictionary = {}  # option -> {value -> its square}, for the rows of colors
var _sprite: AnimatedSprite2D  # the picture of the wizard being made
var _magic: MagicLayer
var _shown := ""               # the look the picture shows


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()  # the plate stands at the left, halfway down
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 64)  # (clear of the stamina bar)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(side)
	_plate = PanelContainer.new()  # a gold frame, and inside it a second, finer one, as a ruled page has
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if ThemeDB.get_project_theme().has_stylebox("panel", "Plate"):  # a skinned look: the interface's own plate
		var skin: StyleBox = ThemeDB.get_project_theme().get_stylebox("panel", "Plate").duplicate()  # (a little less room round the writing than a plain plate has: the maker is tall)
		skin.set_content_margin_all(22.0)
		_plate.add_theme_stylebox_override("panel", skin)
	else:
		_plate.add_theme_stylebox_override("panel", _box(Color(0.09, 0.05, 0.14, 0.96), Lettering.GOLD, 3, 8))
	side.add_child(_plate)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0), Color(Lettering.GOLD, 0.35), 1, 4))
	_plate.add_child(inner)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	inner.add_child(page)
	page.add_child(_title())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	page.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.add_child(_make_preview())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	left.add_child(buttons)
	buttons.add_child(_button("Random", _randomize))
	buttons.add_child(_button("Done", close))
	body.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 392.0
	right.add_theme_constant_override("separation", 4)
	for group: Array in GROUPS:
		if group != GROUPS[0]:
			right.add_child(_rule())
		for option: String in group:
			var title: String = TITLES[option]
			right.add_child(_make_squares(option, title) if COLOR_ROWS.has(option) else _make_row(option, title))
	body.add_child(right)
	_show_choice()


## A flat box of the interface's: its color, edge and how far the writing stands from it.
func _box(fill: Color, edge: Color, width: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_content_margin_all(margin)
	return box


## The name of the plate, in the book's own lettering, with a rule and a small diamond under it.
func _title() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = "Magic Mirror"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Lettering.FACE)
	label.add_theme_font_size_override("font_size", Lettering.size_near(44))
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.8, 0.1, 0.35, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(label)
	var flourish := Control.new()
	flourish.custom_minimum_size = Vector2(0.0, 12.0)
	flourish.draw.connect(func() -> void:
		var middle := flourish.size.x * 0.5
		var y := flourish.size.y * 0.5
		flourish.draw_line(Vector2(0.0, y), Vector2(middle - 12.0, y), Color(Lettering.GOLD, 0.6), 2.0)
		flourish.draw_line(Vector2(middle + 12.0, y), Vector2(flourish.size.x, y), Color(Lettering.GOLD, 0.6), 2.0)
		flourish.draw_colored_polygon(PackedVector2Array([Vector2(middle - 6.0, y), Vector2(middle, y - 5.0), Vector2(middle + 6.0, y), Vector2(middle, y + 5.0)]), Lettering.GOLD))
	column.add_child(flourish)
	return column


## A fine line between groups of rows.
func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(EDGE, 0.55)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	return line


## What a row is called, in the interface's pixel font.
func _caption(text: String, color := DIM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Lettering.PIXEL)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	return label


## Where the plate is on the screen.
func plate_rect() -> Rect2:
	return _plate.get_global_rect()


func close() -> void:
	Sfx.cue("likeness_panel", "click")
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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


## The wizard as they are made, standing in a small dim room of their own, at four times their size.
func _make_preview() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0.04, 0.02, 0.07), EDGE, 2, 0))
	var stage := Control.new()
	stage.custom_minimum_size = PREVIEW_SIZE
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)
	var feet := Vector2(PREVIEW_SIZE.x * 0.5, PREVIEW_SIZE.y - 70.0)
	stage.draw.connect(func() -> void:  # a faint glow behind them, and the slab they stand on
		for ring in 6:
			var grow := 1.0 - float(ring) / 6.0
			stage.draw_circle(feet - Vector2(0.0, 130.0), 50.0 + 150.0 * grow, Color(0.45, 0.2, 0.6, 0.018))
		stage.draw_rect(Rect2(0.0, feet.y, PREVIEW_SIZE.x, PREVIEW_SIZE.y - feet.y), Color(0.11, 0.07, 0.16))
		stage.draw_rect(Rect2(0.0, feet.y, PREVIEW_SIZE.x, 2.0), Color(EDGE, 0.9))
		for k in 5:
			stage.draw_line(Vector2(k * 60.0 + 14.0, feet.y + 2.0), Vector2(k * 60.0 - 6.0, PREVIEW_SIZE.y), Color(0, 0, 0, 0.35), 2.0))
	var stand := Node2D.new()
	stand.position = feet
	stand.scale = Vector2.ONE * PREVIEW_SCALE
	stand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(stand)
	_sprite = AnimatedSprite2D.new()
	_sprite.offset = PartFrames.OFFSET
	stand.add_child(_sprite)
	_magic = MagicLayer.new()
	stand.add_child(_magic)
	return frame


## A row of colors: what it is called, and under it a square for each, the chosen one ringed. (Colors are not given names: they are plain to see.)
func _make_squares(option: String, title: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.add_child(_caption(title))
	var values: Array = PartFrames.manifest()["options"][option]
	var flow := GridContainer.new()
	flow.columns = values.size()
	flow.add_theme_constant_override("h_separation", 3)
	column.add_child(flow)
	var squares := {}
	for value: String in values:
		var square := Button.new()
		square.focus_mode = Control.FOCUS_NONE
		square.custom_minimum_size = Vector2(SWATCH, SWATCH)
		if value == "bare":
			square.tooltip_text = "Bare feet"
		square.pressed.connect(_choose.bind(option, value))
		flow.add_child(square)
		squares[value] = square
	_squares[option] = squares
	_rows[option] = column
	return column


## The color a square shows: the paint of the cloth, the hair or the skin, or the trim's or the boots', or, for bare feet, the skin of the wizard.
func _swatch_of(option: String, value: String) -> Color:
	if option == "boots":
		return Color(BOOT_SWATCHES[value]) if BOOT_SWATCHES.has(value) else Color(SWATCHES[PartsLook.option_of(_current(), "skin")])
	return Color(SWATCHES[value])


## Paints a square: its color, with a gold ring when it is the one chosen and a pale one under the pointer.
func _paint_square(square: Button, color: Color, chosen: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := _box(color.lightened(0.12 if state == "hover" else 0.0), Color(0, 0, 0, 0.75), 1, 0)
		if chosen:
			box.set_border_width_all(2)
			box.border_color = Lettering.GOLD
		elif state == "hover":
			box.set_border_width_all(2)
			box.border_color = Color(0.784, 0.659, 1.0)
		square.add_theme_stylebox_override(state, box)


## A row: what it is called, and at the right an arrow to the one before, what it is now and an arrow to the next.
func _make_row(option: String, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := _caption(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_arrow("<", _step.bind(option, -1)))
	var value := _caption("", INK)
	value.custom_minimum_size = Vector2(140.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	row.add_child(_arrow(">", _step.bind(option, 1)))
	_values[option] = value
	return row


func _arrow(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"Choice"
	button.add_theme_font_override("font", Lettering.PIXEL)  # (the book's lettering has no arrows)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30.0, 28.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 0.0
		box.content_margin_right = 0.0
		box.content_margin_top = 0.0
		box.content_margin_bottom = 0.0
		button.add_theme_stylebox_override(state, box)
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
	Sfx.cue("likeness_panel", "click")
	GameSettings.set_value("look", PartsLook.with_option(_current(), option, value))
	_changed()
	if option == "voice":
		Sfx.play(WizardLook.jump_sound(_current()))  # a voice is heard when it is chosen


func _randomize() -> void:
	Sfx.cue("likeness_panel", "click")
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
	for option: String in _values:
		var value: String = config[option]
		(_values[option] as Label).text = NAMES.get(value, value.capitalize())
	for option: String in _squares:
		var squares: Dictionary = _squares[option]
		for each: String in squares:
			_paint_square(squares[each], _swatch_of(option, each), each == config[option])
	(_rows["hat_color"] as Control).visible = not PartsLook.HAT_NO_COLOR.has(config["hat"])  # a hat with no color of its own has no row for it
	if look != _shown:
		_shown = look
		_sprite.sprite_frames = PartFrames.body(look, true)
		_sprite.play("idle")
		_magic.attach(_sprite, config["weapon"])
		_magic.paint(SpellData.SCHOOL_COLORS["Fire"])
