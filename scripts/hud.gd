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
var stamina_bar: Bar
var _font: Font
var _title_font: Font
var _status: Label
var _feedback: Label
var _feedback_time := 0.0
var _title_label: Label
var _banner: Label
var _banner_sub: Label
var _boss: Bar
var _boss_name: Label
var _portal_arrow: PortalArrow
var _hex_arrows: HexArrows
var _game_over: Control
var _pause: Control
var _pause_note: Label  # at the bottom of the pause screen: the world's seed words


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Pixel faces to match the art: a plain one for numbers and labels, a blackletter one for titles.
	_font = FloatText.font()
	var blackletter: FontFile = load("res://fonts/Jacquard24-Regular.ttf")
	blackletter.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_title_font = blackletter
	var view := get_viewport().get_visible_rect().size

	stamina_bar = Bar.new(STAMINA, "Stamina", _font)
	stamina_bar.position = Vector2(20, 18)
	stamina_bar.size = Vector2(300, 26)
	add_child(stamina_bar)
	_status = _label(15, Color("#ffb86b"))
	_status.position = Vector2(22, 74)
	add_child(_status)

	_title_label = _label(22, Color.WHITE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size = Vector2(400, 30)
	_title_label.position = Vector2(view.x * 0.5 - 200, 12)
	add_child(_title_label)

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

	_hex_arrows = HexArrows.new()
	_hex_arrows.font = _font
	_hex_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hex_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hex_arrows)

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
		var unlimited: bool = player.infinite_time > 0.0
		stamina_bar.fill = UNLIMITED if unlimited else STAMINA
		stamina_bar.set_value(player.stamina, player.max_stamina, player.MAX_STAMINA)
		_status.text = player.status_text()
	_feedback_time -= delta
	_feedback.modulate.a = clampf(_feedback_time / 0.6, 0.0, 1.0)
	var wizard := _find_wizard()
	_boss.visible = wizard != null
	_boss_name.visible = wizard != null
	if wizard:
		_boss.set_value(wizard.hp, wizard.max_hp)
		_boss_name.text = "The " + wizard.KINDS[wizard.kind]["name"]


func _find_wizard() -> Node:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.KINDS[mob.kind]["role"] == "wizard":
			return mob
	return null


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
	_portal_arrow.portal = portal


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
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and _pause.visible:
		toggle_pause()  # the game is paused, so only the HUD hears Esc: it resumes
		get_viewport().set_input_as_handled()


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
	_pause_note = _label(20, Color("#c8a8ff"))
	_pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_note.size = Vector2(view.x, 28)
	_pause_note.position = Vector2(0, view.y - 56.0)
	_pause.add_child(_pause_note)


## A rounded bar with its name and value written inside it. When the value drops, a pale chunk shows how much
## was lost and then drains away, so you can see how hard a hit was.
class Bar extends Control:
	var fill := Color.WHITE
	var title := ""
	var font: Font
	var _value := 1.0
	var _max := 1.0
	var _cap := 1.0  # the most the bar could ever show: what a hit takes off the most is drawn as a dark gap at its end
	var _chip := 1.0  # the share shown by the draining chunk

	func _init(colour: Color, bar_title: String, bar_font: Font) -> void:
		fill = colour
		title = bar_title
		font = bar_font
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_value(value: float, maximum: float, cap := -1.0) -> void:
		_value = value
		_max = maximum
		_cap = cap if cap > 0.0 else maximum

	func _process(delta: float) -> void:
		var share := clampf(_value / _cap, 0.0, 1.0)
		_chip = share if share > _chip else move_toward(_chip, share, delta * 0.6)
		queue_redraw()

	## A square bar in a dark iron frame, so it sits with the pixel art: the fill, a lighter line along its top, and
	## the chunk just lost draining away behind it.
	func _draw() -> void:
		var share := clampf(_value / _cap, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0710"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("#5c4a3c"), false, 2.0)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#1b1220"), false, 1.0)
		var inner := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var most := clampf(_max / _cap, 0.0, 1.0)
		if most < 1.0:  # what hits have taken off the most: a dull red gap at the end
			var from := roundf(inner.size.x * most)
			draw_rect(Rect2(inner.position + Vector2(from, 0), Vector2(inner.size.x - from, inner.size.y)), Color(0.45, 0.06, 0.1, 0.6))
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


## While anything but the wizard is hexed, an arrow at the edge of the screen points to it whenever it is off screen.
class HexArrows extends Control:
	var font: Font
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var view := get_viewport_rect().size
		var transform := get_viewport().get_canvas_transform()
		var red := Color("#ff6b8a")
		for hex in get_tree().get_nodes_in_group("hexes"):
			var target: Node2D = hex.target
			if not is_instance_valid(target) or target.is_in_group("player"):
				continue
			var screen: Vector2 = transform * SpellTargets.center_of(target)
			if Rect2(Vector2.ZERO, view).grow(-30.0).has_point(screen):
				continue
			var dir := (screen - view * 0.5).normalized()
			var edge := Vector2(clampf(screen.x, 50.0, view.x - 50.0), clampf(screen.y, 90.0, view.y - 50.0))
			var tip := edge + dir * sin(_t * 5.0) * 4.0
			var arrow := PackedVector2Array([tip + dir * 16.0, tip + dir.rotated(2.4) * 14.0, tip + dir.rotated(-2.4) * 14.0])
			draw_colored_polygon(arrow, red)
			draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0.15, 0.03, 0.06), 2.0)
			if font:
				draw_string_outline(font, tip - dir * 30.0 + Vector2(-24, 6), "Hexed", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.08, 0.02, 0.04))
				draw_string(font, tip - dir * 30.0 + Vector2(-24, 6), "Hexed", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, red)


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
