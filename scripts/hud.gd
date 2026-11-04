class_name Hud
extends CanvasLayer

## Everything drawn over the game: the stamina bar, a banner, the dark wizard's health, messages, an arrow to the portal, the pause screen with the controls,
## and the screen you see when you fall.


signal stats_requested  # the person asked to see the story of their match again

const HEALTH := Color("#b3122e")
const STAMINA := Color("#c08a2c")
const UNLIMITED := Color("#7fe0ff")
const INK := Color(0.07, 0.04, 0.1)
const LETTERING := preload("res://fonts/PirataOne-Regular.ttf")  # the face of the home screen and the spellbook
const CONTROLS := [
	["W A S D", "Move"], ["Space", "Jump"],
	["Mouse buttons", "Hold mouse buttons and draw a spell"], ["Tab", "Open the spellbook"],
	["Enter", "Speak an incantation"], ["M", "Mute sound"],
	["F1", "Open the debug menu"], ["Esc", "Pause/Resume"],
]

var player: Node2D
var _feedback_time := 0.0

@onready var stamina_bar: HudBar = $StaminaBar
@onready var _status: Label = $Status
@onready var _feedback: Label = $Feedback
@onready var _title_label: Label = $Title
@onready var _banner: Label = $Banner
@onready var _banner_sub: Label = $BannerSub
@onready var _game_over: Control = $GameOver
@onready var _pause: Control = $Pause
@onready var _pause_note: Label = $Pause/Box/Note


## The list of controls is data, so its rows are filled in here; the rest of the screen is laid out in scenes/hud.tscn.
func _ready() -> void:
	add_to_group(&"hud")  # the wand cursor asks whether the game is paused
	$Pause/Box/Leave.pressed.connect(_on_leave)
	$Pause/Box/Settings.pressed.connect(_on_settings)
	$StatsButton.pressed.connect(_on_stats)
	$Pause/Box/Quit.pressed.connect(func() -> void: get_tree().quit())
	var rows: GridContainer = $Pause/Box/Controls
	_lay_on_parchment(rows)
	for row in CONTROLS:
		if row[0] == "F1" and not OS.is_debug_build():
			continue  # the summon menu is a testing tool
		var key := Label.new()
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.add_theme_font_override("font", LETTERING)
		key.add_theme_color_override("font_color", Color("#6e1420"))  # the crimson of the book's headings
		key.add_theme_font_size_override("font_size", 26)
		rows.add_child(key)
		var what := Label.new()
		what.text = row[1] if not (row[0] == "Esc" and Net.online()) else "Open the menu"  # a network game goes on while it is open
		what.add_theme_font_override("font", LETTERING)
		what.add_theme_color_override("font_color", Color("#3a1d1a"))
		what.add_theme_font_size_override("font_size", 26)
		rows.add_child(what)


## The controls are written on a sheet of the book's parchment, in the book's ink and lettering, as the home screen is.
func _lay_on_parchment(rows: GridContainer) -> void:
	var sheet := PanelContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#d8b690")
	paper.border_color = Color("#3a1d1a")
	paper.set_border_width_all(4)
	paper.set_corner_radius_all(3)
	paper.set_content_margin_all(18.0)
	sheet.add_theme_stylebox_override("panel", paper)
	var box: Node = rows.get_parent()
	box.add_child(sheet)
	box.move_child(sheet, rows.get_index())
	rows.reparent(sheet, false)


func _process(delta: float) -> void:
	if player:
		var unlimited: bool = player.infinite_time > 0.0
		stamina_bar.fill = UNLIMITED if unlimited else STAMINA
		stamina_bar.set_value(player.stamina, player.max_stamina, player.MAX_STAMINA)
		stamina_bar.extra = player.temp_stamina
		_status.text = player.status_text()
	_feedback_time -= delta
	_feedback.modulate.a = clampf(_feedback_time / 0.6, 0.0, 1.0)


## A message along the bottom of the screen that fades after a few seconds.
func show_message(text: String, colour: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", colour)
	_feedback_time = 3.0


## Writes any words at the top of the screen.
func set_title(text: String) -> void:
	_title_label.text = text


## A large title that fades in, holds, and fades out.
func banner(title: String, subtitle := "") -> void:
	_banner.text = title
	_banner_sub.text = subtitle
	for label in [_banner, _banner_sub]:
		var tween: Tween = label.create_tween()
		label.modulate.a = 0.0
		tween.tween_property(label, "modulate:a", 1.0, 0.35)
		tween.tween_interval(1.6)
		tween.tween_property(label, "modulate:a", 0.0, 0.6)


func point_to_portal(portal: Node2D) -> void:
	portal.add_to_group(&"portals")  # the PortalArrow points at everything in this group


func show_game_over() -> void:
	_game_over.visible = true
	_game_over.modulate.a = 0.0
	var tween := _game_over.create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_game_over, "modulate:a", 1.0, 0.8)


func is_game_over() -> bool:
	return _game_over.visible


## Opens or closes the menu. Playing alone it stops the world; in a network game the world goes on for the others.
func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible and not Net.online()


## Back to the first screen, out of the game (a network game goes on without you; one you host ends for everyone).
func _on_leave() -> void:
	Sfx.play("ui_click")
	Net.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file(Net.MENU)


## Words shown at the bottom of the pause screen, such as the incantation that names this world. Empty hides them.
## The match is over for the person: a button stays on the screen to pull its stats up again.
func offer_stats() -> void:
	$StatsButton.visible = true


func _on_stats() -> void:
	Sfx.play("ui_click")
	stats_requested.emit()


## The Settings button on the pause screen opens the page of settings over it.
func _on_settings() -> void:
	Sfx.play("ui_click")
	$Pause.add_child(SettingsPanel.new())


func set_pause_note(text: String) -> void:
	_pause_note.text = text


func is_paused() -> bool:
	return _pause.visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause.visible:
		toggle_pause()  # the game is paused, so only the HUD hears Esc: it resumes
		get_viewport().set_input_as_handled()


