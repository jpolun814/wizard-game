class_name Hud
extends CanvasLayer

## Everything drawn over the game: health and stamina, the wave and how many enemies are left, a banner when a
## wave starts, the dark wizard's health, messages, an arrow to the portal, the pause screen with the controls,
## and the screen you see when you fall.

signal restart_requested

const HEALTH := Color("#b3122e")
const STAMINA := Color("#c08a2c")
const UNLIMITED := Color("#7fe0ff")
const INK := Color(0.07, 0.04, 0.1)
const CONTROLS := [
	["A / D", "Move"], ["W or Space", "Jump (tap for a small hop)"], ["S", "Drop through a wooden platform"],
	["Hold mouse buttons + draw", "Cast a spell (the buttons choose the school)"], ["Tab", "Spellbook: every spell and how to draw it"],
	["Enter", "Speak an incantation"], ["E", "Swap your focus for one on the ground"], ["M", "Mute sound"],
	["F1", "Summon menu, for testing"], ["Esc", "Pause and this list"],
]

var player: Node2D
var health_bar: Bar
var stamina_bar: Bar
var _font: Font
var _title_font: Font
var _status: Label
var _feedback: Label
var _feedback_time := 0.0
var _wave_label: Label
var _foes_label: Label
var _banner: Label
var _banner_sub: Label
var _boss: Bar
var _boss_name: Label
var _portal_arrow: PortalArrow
var _game_over: Control
var _pause: Control
var _over_text: Label


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pixel faces to match the art: a plain one for numbers and labels, a blackletter one for titles.
	_font = FloatText.font()
	var blackletter: FontFile = load("res://fonts/Jacquard24-Regular.ttf")
	blackletter.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_title_font = blackletter
	var view := get_viewport().get_visible_rect().size

	health_bar = Bar.new(HEALTH, "Health", _font)
	health_bar.position = Vector2(20, 18)
	health_bar.size = Vector2(250, 26)
	add_child(health_bar)
	stamina_bar = Bar.new(STAMINA, "Stamina", _font)
	stamina_bar.position = Vector2(20, 50)
	stamina_bar.size = Vector2(210, 18)
	add_child(stamina_bar)
	_status = _label(15, Color("#ffb86b"))
	_status.position = Vector2(22, 74)
	add_child(_status)

	_wave_label = _label(22, Color.WHITE)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.size = Vector2(400, 30)
	_wave_label.position = Vector2(view.x * 0.5 - 200, 12)
	add_child(_wave_label)
	_foes_label = _label(15, Color(0.85, 0.82, 0.95))
	_foes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foes_label.size = Vector2(400, 20)
	_foes_label.position = Vector2(view.x * 0.5 - 200, 40)
	add_child(_foes_label)

	_boss = Bar.new(Color("#7b2fb8"), "", _font)
	_boss.size = Vector2(420, 16)
	_boss.position = Vector2(view.x * 0.5 - 210, 86)
	_boss.visible = false
	add_child(_boss)
	_boss_name = _label(16, Color("#e2c6ff"), _title_font)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.size = Vector2(420, 20)
	_boss_name.position = Vector2(view.x * 0.5 - 210, 64)
	_boss_name.text = "The Dark Wizard"
	_boss_name.visible = false
	add_child(_boss_name)

	_banner = _label(54, Color("#fff2d6"), _title_font)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(view.x, 70)
	_banner.position = Vector2(0, view.y * 0.28)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_sub = _label(20, Color(0.9, 0.85, 1.0))
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.size = Vector2(view.x, 30)
	_banner_sub.position = Vector2(0, view.y * 0.28 + 72)
	_banner_sub.modulate.a = 0.0
	add_child(_banner_sub)

	_feedback = _label(17, Color.WHITE)
	_feedback.position = Vector2(22, view.y - 40)
	_feedback.size = Vector2(view.x * 0.6, 24)
	add_child(_feedback)

	_portal_arrow = PortalArrow.new()
	_portal_arrow.font = _font
	_portal_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portal_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portal_arrow)

	_build_game_over(view)
	_build_pause(view)


func _label(font_size: int, colour: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font if font else _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	if player:
		health_bar.set_value(player.hp, player.MAX_HP)
		var unlimited: bool = player.infinite_time > 0.0
		stamina_bar.fill = UNLIMITED if unlimited else STAMINA
		stamina_bar.set_value(player.stamina, player.MAX_STAMINA)
		_status.text = player.status_text()
	_feedback_time -= delta
	_feedback.modulate.a = clampf(_feedback_time / 0.6, 0.0, 1.0)
	var wizard := _find_wizard()
	_boss.visible = wizard != null
	_boss_name.visible = wizard != null
	if wizard:
		_boss.set_value(wizard.hp, wizard.max_hp)


func _find_wizard() -> Node:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.kind == "dark_wizard":
			return mob
	return null


## A message along the bottom of the screen that fades after a few seconds.
func show_message(text: String, colour: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", colour)
	_feedback_time = 3.0


func set_wave(level: int, wave: int, waves_in_level: int) -> void:
	_wave_label.text = "Level %d  ·  Wave %d of %d" % [level, wave, waves_in_level]


func set_foes(count: int, cleared: bool) -> void:
	_foes_label.text = "The portal is open — walk into it" if cleared else ("%d %s left" % [count, "enemy" if count == 1 else "enemies"] if count > 0 else "")


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
	_portal_arrow.portal = portal


func show_game_over(level: int, wave: int) -> void:
	_over_text.text = "You reached level %d, wave %d." % [level, wave]
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


func is_paused() -> bool:
	return _pause.visible


func _unhandled_input(event: InputEvent) -> void:
	if not _game_over.visible or _game_over.modulate.a < 0.5:
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if (key and key.pressed and key.keycode == KEY_R) or (click and click.pressed):
		get_viewport().set_input_as_handled()
		restart_requested.emit()


func _build_game_over(view: Vector2) -> void:
	_game_over = ColorRect.new()
	(_game_over as ColorRect).color = Color(0.04, 0.0, 0.06, 0.72)
	_game_over.size = view
	_game_over.visible = false
	add_child(_game_over)
	var title := _label(64, Color("#ff6b6b"), _title_font)
	title.text = "You have fallen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(view.x, 80)
	title.position = Vector2(0, view.y * 0.32)
	_game_over.add_child(title)
	_over_text = _label(22, Color(0.92, 0.88, 1.0))
	_over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_text.size = Vector2(view.x, 30)
	_over_text.position = Vector2(0, view.y * 0.32 + 90)
	_game_over.add_child(_over_text)
	var hint := _label(18, Color(0.8, 0.75, 0.9))
	hint.text = "Press R or click to begin a new run"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(view.x, 30)
	hint.position = Vector2(0, view.y * 0.32 + 130)
	_game_over.add_child(hint)


func _build_pause(view: Vector2) -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.03, 0.01, 0.06, 0.78)
	_pause.size = view
	_pause.visible = false
	add_child(_pause)
	var title := _label(48, Color("#fff2d6"), _title_font)
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(view.x, 60)
	title.position = Vector2(0, view.y * 0.12)
	_pause.add_child(title)
	var y := view.y * 0.12 + 90.0
	for row in CONTROLS:
		var key := _label(19, Color("#f2c14e"))
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.size = Vector2(view.x * 0.5 - 16, 26)
		key.position = Vector2(0, y)
		_pause.add_child(key)
		var what := _label(19, Color(0.92, 0.9, 1.0))
		what.text = row[1]
		what.size = Vector2(view.x * 0.5 - 16, 26)
		what.position = Vector2(view.x * 0.5 + 16, y)
		_pause.add_child(what)
		y += 32.0
	var hint := _label(16, Color(0.75, 0.7, 0.85))
	hint.text = "Press Esc to carry on"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(view.x, 24)
	hint.position = Vector2(0, y + 16)
	_pause.add_child(hint)


## A rounded bar with its name and value written inside it. When the value drops, a pale chunk shows how much
## was lost and then drains away, so you can see how hard a hit was.
class Bar extends Control:
	var fill := Color.WHITE
	var title := ""
	var font: Font
	var _value := 1.0
	var _max := 1.0
	var _chip := 1.0  # the share shown by the draining chunk

	func _init(colour: Color, bar_title: String, bar_font: Font) -> void:
		fill = colour
		title = bar_title
		font = bar_font
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_value(value: float, maximum: float) -> void:
		_value = value
		_max = maximum

	func _process(delta: float) -> void:
		var share := clampf(_value / _max, 0.0, 1.0)
		_chip = share if share > _chip else move_toward(_chip, share, delta * 0.6)
		queue_redraw()

	## A square bar in a dark iron frame, so it sits with the pixel art: the fill, a lighter line along its top, and
	## the chunk just lost draining away behind it.
	func _draw() -> void:
		var share := clampf(_value / _max, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0710"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#5c4a3c"), false, 2.0)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#1b1220"), false, 1.0)
		var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if _chip > share:
			draw_rect(Rect2(inner.position, Vector2(roundf(inner.size.x * _chip), inner.size.y)), Color(0.95, 0.85, 0.75, 0.7))
		if share > 0.0:
			var width := roundf(inner.size.x * share)
			draw_rect(Rect2(inner.position, Vector2(width, inner.size.y)), fill)
			draw_rect(Rect2(inner.position, Vector2(width, 2)), fill.lightened(0.35))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(width, 2)), fill.darkened(0.35))
		if title != "" and font:
			var text := "%s  %d / %d" % [title, roundi(_value), roundi(_max)]
			var font_size := int(size.y * 0.78)
			var at := Vector2(10, size.y * 0.5 + font_size * 0.32)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.03, 0.01, 0.04, 0.95))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#f3e6d2"))


## When the portal is off screen, an arrow at the edge of the screen points the way to it.
class PortalArrow extends Control:
	var portal: Node2D
	var font: Font
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if portal == null or not is_instance_valid(portal):
			return
		var screen := get_viewport().get_canvas_transform() * portal.global_position
		var view := get_viewport_rect().size
		if Rect2(Vector2.ZERO, view).grow(-30.0).has_point(screen):
			return
		var middle := view * 0.5
		var dir := (screen - middle).normalized()
		var edge := Vector2(clampf(screen.x, 50.0, view.x - 50.0), clampf(screen.y, 90.0, view.y - 50.0))
		var bob := sin(_t * 5.0) * 4.0
		var tip := edge + dir * bob
		var violet := Color("#c9a3ff")
		var arrow := PackedVector2Array([tip + dir * 16.0, tip + dir.rotated(2.4) * 14.0, tip + dir.rotated(-2.4) * 14.0])
		draw_colored_polygon(arrow, violet)
		draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0.1, 0.05, 0.15), 2.0)
		if font:
			draw_string_outline(font, tip - dir * 30.0 + Vector2(-24, 6), "Portal", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.05, 0.02, 0.08))
			draw_string(font, tip - dir * 30.0 + Vector2(-24, 6), "Portal", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, violet)
