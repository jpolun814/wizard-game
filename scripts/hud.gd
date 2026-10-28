class_name Hud
extends CanvasLayer

## Everything drawn over the game: the stamina bar, a banner, the dark wizard's health, messages, an arrow to the portal, the pause screen with the controls,
## and the screen you see when you fall.

signal restart_requested

const HEALTH := Color("#b3122e")
const STAMINA := Color("#c08a2c")
const UNLIMITED := Color("#7fe0ff")
const INK := Color(0.07, 0.04, 0.1)
const CONTROLS := [
	["A / D", "Move"], ["W or Space", "Jump (tap to hop)"],
	["Hold mouse buttons + draw", "Cast a spell (the buttons pick the school)"], ["Tab", "Open your spellbook, or read the page you stand on"], ["Left / Right arrows", "Walk your Decoy"],
	["Enter", "Speak an incantation"], ["E", "Swap focus with the one on the ground"], ["M", "Mute sound"],
	["F1", "Open the summon menu (testing)"], ["Esc", "Pause"],
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
	var rows: GridContainer = $Pause/Box/Controls
	for row in CONTROLS:
		var key := Label.new()
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.theme_type_variation = &"Outlined"
		key.add_theme_color_override("font_color", Color("#f2c14e"))
		key.add_theme_font_size_override("font_size", 19)
		rows.add_child(key)
		var what := Label.new()
		what.text = row[1]
		what.theme_type_variation = &"Outlined"
		what.add_theme_color_override("font_color", Color(0.92, 0.9, 1.0))
		what.add_theme_font_size_override("font_size", 19)
		rows.add_child(what)


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


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible


## Words shown at the bottom of the pause screen, such as the incantation that names this world. Empty hides them.
func set_pause_note(text: String) -> void:
	_pause_note.text = text


func is_paused() -> bool:
	return _pause.visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause.visible:
		toggle_pause()  # the game is paused, so only the HUD hears Esc: it resumes
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _game_over.visible or _game_over.modulate.a < 0.5:
		return
	var click := event as InputEventMouseButton
	if event.is_action_pressed("restart") or (click and click.pressed):
		get_viewport().set_input_as_handled()
		restart_requested.emit()
