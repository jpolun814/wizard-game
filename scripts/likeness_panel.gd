class_name LikenessPanel
extends CanvasLayer

## The wizard maker, opened in the waiting room by the words at the glowing spot on the hill: the four figures to be, and the sets of colours to wear.
## What is chosen is put on the wizard at once, kept for next time (see GameSettings) and told to everyone else in the game.

signal closed

const LETTERING := preload("res://fonts/Jersey15-Regular.ttf")
const GOLD := Color("#c89a3c")

var wizard: Wizard  # the one the person plays, which wears what is chosen
var _plate: PanelContainer
var _looks: Dictionary = {}  # look -> its button
var _swatches: Array[Button] = []
var _portraits: Dictionary = {}  # look -> its picture


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.14, 0.94)
	style.border_color = GOLD
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
	column.add_theme_constant_override("separation", 12)
	plate.add_child(column)
	column.add_child(_heading("Your wizard", 30, Color(0.9, 0.8, 1.0)))
	var figures := HBoxContainer.new()
	figures.add_theme_constant_override("separation", 10)
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(figures)
	for look: String in WizardLook.LOOKS:
		figures.add_child(_figure_button(look))
	column.add_child(_heading("Colors", 22, GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(grid)
	for palette in WizardLook.PALETTES.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(52, 36)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = WizardLook.PALETTES[palette]["name"]
		swatch.pressed.connect(_choose_palette.bind(palette))
		grid.add_child(swatch)
		_swatches.append(swatch)
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = &"Choice"
	done.focus_mode = Control.FOCUS_NONE  # the keys are the wizard's: Space must jump, not press a button
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(close)
	column.add_child(done)
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


func _heading(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", LETTERING)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A button showing a figure as it stands, drawn to the height it has in the game, all of them on one line.
func _figure_button(look: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = WizardLook.NAMES[look]
	var sheet: Texture2D = load("res://art/chars/%s/idle_0.png" % look)
	var box := sheet.get_image().get_used_rect()
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = Rect2(box)
	var portrait := TextureRect.new()
	portrait.texture = cut
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var drawn := Vector2(box.size) * WizardLook.scale_of(look)
	portrait.custom_minimum_size = drawn
	portrait.size = drawn
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(maxf(drawn.x, 46.0) + 12.0, 160.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(portrait)
	portrait.position = Vector2((holder.custom_minimum_size.x - drawn.x) * 0.5, 150.0 - drawn.y)
	button.add_child(holder)
	button.custom_minimum_size = holder.custom_minimum_size
	button.pressed.connect(_choose_look.bind(look))
	_looks[look] = button
	_portraits[look] = portrait
	return button


func _choose_look(look: String) -> void:
	Sfx.play("ui_click")
	GameSettings.set_value("look", look)
	_changed()


func _choose_palette(palette: int) -> void:
	Sfx.play("ui_click")
	GameSettings.set_value("palette", palette)
	_changed()


## What was chosen is worn at once, and told to the others.
func _changed() -> void:
	wizard.look = Net.look_of(Net.my_id())
	wizard.palette = Net.palette_of(Net.my_id())
	Net.say_style()
	_show_choice()


## The buttons show what is chosen: a gold edge round the figure and the colours it wears.
func _show_choice() -> void:
	var chosen := Net.look_of(Net.my_id())
	var palette := Net.palette_of(Net.my_id())
	for look: String in _looks:
		var button: Button = _looks[look]
		button.add_theme_stylebox_override("normal", _edge(look == chosen))
		button.add_theme_stylebox_override("hover", _edge(true))
		button.add_theme_stylebox_override("pressed", _edge(true))
		(_portraits[look] as TextureRect).material = WizardLook.material_for(look, palette)
	for k in _swatches.size():
		var swatch := _swatches[k]
		var box := _edge(k == palette)
		box.bg_color = WizardLook.swatch(chosen, k)
		swatch.add_theme_stylebox_override("normal", box)
		swatch.add_theme_stylebox_override("hover", box)
		swatch.add_theme_stylebox_override("pressed", box)


func _edge(chosen: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.09, 0.2)
	box.border_color = GOLD if chosen else Color(0.3, 0.25, 0.4)
	box.set_border_width_all(3)  # always the same width, so that choosing does not change the size of anything
	box.set_corner_radius_all(3)
	return box
