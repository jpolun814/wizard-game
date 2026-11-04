class_name LikenessGuide
extends CanvasLayer

## The page that comes up at the top of the screen while a wizard stands on the circle of the wizard maker, as a tutorial place's page does: the key that
## opens the box, and the words to type in it.

const LETTERING := Lettering.FACE
const PANEL := Color("#1f1528")
const ACCENT := Color("#b890ff")
const PARCHMENT := Color("#e9d7bb")  # the plate the words are written on
const WORDS := Color("#efe3cf")


func _ready() -> void:
	layer = 4
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = ACCENT.lightened(0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = "Chant of the Magic Mirror"
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", ACCENT.lightened(0.25))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(Spellbook.KeyCap.new("Enter"))
	column.add_child(top)
	var plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = PARCHMENT
	plate_style.set_corner_radius_all(4)
	plate_style.set_content_margin_all(4.0)
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.custom_minimum_size = Vector2(250.0, 104.0)
	var words := Label.new()
	words.text = RitualInput.LIKENESS_WORDS
	words.add_theme_font_override("font", LETTERING)
	words.add_theme_font_size_override("font_size", Lettering.size_near(34))
	words.add_theme_color_override("font_color", Spellbook.HEADING)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(words)
	column.add_child(plate)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 84)
