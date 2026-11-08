class_name SettingsPanel
extends Control

## The page of choices about sound, the window and the cut-scenes, over whatever is behind it. The first screen and the pause screen both open it.
## Each choice takes hold at once and is kept (see GameSettings). Esc or Done closes it.

signal closed

const LETTERING := preload("res://fonts/Jersey15-Regular.ttf")
const GOLD := Color("#c89a3c")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # it works while the game is paused
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.06, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(middle)
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.14)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(26)
	plate.add_theme_stylebox_override("panel", style)
	middle.add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	plate.add_child(column)
	column.add_child(_heading("Settings", 34))
	column.add_child(_heading("Sound", 22))
	column.add_child(_row("Volume", _slider("master")))
	column.add_child(_row("Effects", _slider("effects")))
	column.add_child(_heading("Window", 22))
	column.add_child(_row("Screen", _choice("window", ["Windowed", "Fullscreen", "Borderless"])))
	column.add_child(_row("Vertical sync", _toggle("vsync")))
	column.add_child(_row("Frame rate", _choice("frame_cap", ["Unlimited", "60", "120", "144"])))
	column.add_child(_heading("Match", 22))
	column.add_child(_row("Rival skill", _choice("rival_skill", ["Easy", "Normal", "Hard"])))
	column.add_child(_row("Share play logs", _toggle("share_logs")))
	column.add_child(_heading("Cut-scenes", 22))
	column.add_child(_row("Skip the opening", _toggle("skip_opening")))
	column.add_child(_row("Skip the ending", _toggle("skip_ending")))
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = &"Choice"
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(close)
	column.add_child(done)
	done.grab_focus.call_deferred()


func close() -> void:
	Sfx.play("ui_click")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _heading(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", LETTERING)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD if size < 30 else Color(0.9, 0.8, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", LETTERING)
	label.add_theme_font_size_override("font_size", 22)
	label.custom_minimum_size.x = 190.0
	row.add_child(label)
	control.custom_minimum_size.x = 220.0
	row.add_child(control)
	return row


func _slider(key: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(GameSettings.get_value(key))
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(key, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("ui_click"))  # so a change to the effects can be heard
	return slider


func _toggle(key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(GameSettings.get_value(key))
	toggle.toggled.connect(func(on: bool) -> void:
		Sfx.play("ui_click")
		GameSettings.set_value(key, on))
	return toggle


func _choice(key: String, names: Array) -> OptionButton:
	var choice := OptionButton.new()
	for name: String in names:
		choice.add_item(name)
	choice.selected = int(GameSettings.get_value(key))
	choice.item_selected.connect(func(index: int) -> void:
		Sfx.play("ui_click")
		GameSettings.set_value(key, index))
	return choice
