class_name StatsScreen
extends Control

## What is shown over the screen when the person falls or wins: a crystal ball seen close, as a wizard would lean over it, with the story of their match in it
## a page at a time. The arrow keys (or the arrows on the sides) turn the pages: where they placed, the damage dealt and taken over time, the spells learned,
## the casting, the wizards felled, the tally and what they cast most. Everything comes from MatchStats. It is an interface: it speaks to the person, not as the world.

signal dismissed

const TEXT := Color("#f0e6d0")
const DIM := Color("#a89cc0")
const BRASS := Color("#c9a45a")
const BRASS_DARK := Color("#6e5426")
const GRID := Color(1, 1, 1, 0.1)
const DEALT := Color("#ff8a3d")
const TAKEN := Color("#e0485a")
const LEARNED := Color("#7fd3ff")
const CAST := Color("#7fe08a")
const MISSED := Color("#b9a0ff")
const KILLS := Color("#ffd85a")
const BODY: Font = preload("res://fonts/Jersey15-Regular.ttf")  # numbers and small words
const HEAD: Font = Lettering.FACE  # the big words and the title of each page
const MIST: Shader = preload("res://scripts/ui/crystal_ball.gdshader")
const PAGES := ["The end", "Blows struck", "Spells learned", "Casting", "The fallen", "The tally", "Favorites"]
const BLOCK := 4.0  # the size of a block of the ball's mist, in pixels

var placement := 1
var field := 4
var _page := 0
var _button: Button
var _ball: ColorRect
var _face: Control  # over the ball, where the writing and the charts are drawn
var _mist: ShaderMaterial
var _charts: Array[Dictionary] = []  # where the chart was drawn this frame, for reading a value off it
var _pointer := Vector2(-1.0, -1.0)
var _center := Vector2.ZERO
var _radius := 200.0
var _left_arrow := Rect2()
var _right_arrow := Rect2()


## Builds the screen from what MatchStats holds now. `place` is where the person came (1 is the winner) among `of_total` wizards, and `watching` says
## whether the match goes on for them to watch.
func show_stats(place: int, of_total: int, watching: bool) -> void:
	placement = place
	field = of_total
	_page = 0
	MatchStats.close()
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		child.queue_free()
	_ball = ColorRect.new()
	_mist = ShaderMaterial.new()
	_mist.shader = MIST
	_ball.material = _mist
	_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ball)
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_face)
	add_child(_face)
	_button = Button.new()
	_button.text = "Keep watching" if watching else "Continue"
	_button.theme_type_variation = &"Choice"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_close)
	add_child(_button)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	_fit()
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)


## The screen lies over the whole window. (Its parent is a layer, not a control, so it does not stretch by itself.) The ball takes what room there is.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var view := size
	_radius = maxf(roundf(minf(view.x * 0.30, view.y * 0.33) / (BLOCK * 2.0)) * BLOCK * 2.0, BLOCK * 20.0)  # a whole number of blocks across
	_center = Vector2(view.x * 0.5, view.y * 0.47)
	if _ball != null:
		_ball.position = _center - Vector2(_radius, _radius)
		_ball.size = Vector2(_radius, _radius) * 2.0
		_mist.set_shader_parameter("cells", _radius * 2.0 / BLOCK)
		_face.position = Vector2.ZERO
		_face.size = view
		_button.size = Vector2(240.0, 44.0)
		_button.position = Vector2(_center.x - 120.0, _center.y + _radius + 62.0)
	_left_arrow = Rect2(_center + Vector2(-_radius - 84.0, -34.0), Vector2(68.0, 68.0))
	_right_arrow = Rect2(_center + Vector2(_radius + 16.0, -34.0), Vector2(68.0, 68.0))
	_redraw()


func _redraw() -> void:
	queue_redraw()
	if _face != null:
		_face.queue_redraw()


func _close() -> void:
	visible = false
	dismissed.emit()


## Turns to another page, round the end and back.
func _turn(by: int) -> void:
	_page = posmod(_page + by, PAGES.size())
	if _mist != null:  # the mist stirs
		_mist.set_shader_parameter("pulse", 1.0)
		create_tween().tween_property(_mist, "shader_parameter/pulse", 0.0, 0.7)
	_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_left"):
		_turn(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_turn(1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		_redraw()
	var click := event as InputEventMouseButton
	if click != null:
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			if _left_arrow.has_point(click.position):
				_turn(-1)
			elif _right_arrow.has_point(click.position):
				_turn(1)
		accept_event()  # a click on the screen is not a click on the world behind it


# --- Drawing ----------------------------------------------------------------------------------------------------


## Under the ball: the dark room and the stand the ball rests in.
func _draw() -> void:
	if MatchStats.series.is_empty():
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.015, 0.0, 0.03, 0.9))
	for ring in 5:  # a faint glow round the ball
		draw_circle(_center, _radius * (1.5 - 0.1 * ring), Color(0.4, 0.3, 0.8, 0.025))
	var foot := _center.y + _radius * 0.84
	for tier in [[0.62, 30.0, 0.0], [0.82, 22.0, 30.0], [1.02, 16.0, 52.0]]:  # a stand of three stepped tiers
		var box := Rect2(_center.x - _radius * tier[0], foot + tier[2], _radius * tier[0] * 2.0, tier[1])
		draw_rect(box, BRASS_DARK)
		draw_rect(Rect2(box.position, Vector2(box.size.x, 4.0)), BRASS)


func _draw_face() -> void:
	if MatchStats.series.is_empty():
		return
	var f := _face
	var view := get_viewport_rect().size
	_charts.clear()
	f.draw_string(HEAD, Vector2(0.0, _center.y - _radius - 22.0), PAGES[_page], HORIZONTAL_ALIGNMENT_CENTER, view.x, 44, TEXT)
	match _page:
		0:
			_page_end()
		1:
			_chart("Blows struck", [["Dealt", DEALT, "dealt"], ["Taken", TAKEN, "taken"]])
		2:
			_chart("Spells learned", [["Learned", LEARNED, "known"]], true)
		3:
			_chart("Casting", [["Cast", CAST, "casts"], ["Missed", MISSED, "misses"]])
		4:
			_chart("The fallen", [["Kills", KILLS, "kills"]], true)
		5:
			_page_tally()
		6:
			_page_favourites()
	# The turning of the pages: an arrow each side, and a mark for each page.
	_arrow(_left_arrow, -1)
	_arrow(_right_arrow, 1)
	var dots_y := _center.y + _radius * 0.84 + 82.0
	for index in PAGES.size():
		var at := Vector2(_center.x + (index - (PAGES.size() - 1) * 0.5) * 22.0, dots_y)
		f.draw_rect(Rect2(at - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), BRASS if index == _page else Color(1, 1, 1, 0.2))
	_draw_reading(view)


## A triangle pointing the way a page turns.
func _arrow(box: Rect2, way: int) -> void:
	var over := box.has_point(_pointer)
	var middle := box.get_center()
	var points := PackedVector2Array([middle + Vector2(-way * 18.0, -26.0), middle + Vector2(way * 18.0, 0.0), middle + Vector2(-way * 18.0, 26.0)])
	_face.draw_colored_polygon(points, TEXT if over else BRASS)


## The first page: how it ended.
func _page_end() -> void:
	var f := _face
	var width := _radius * 2.0
	var left := _center.x - _radius
	var heading := "Victory" if placement == 1 else "Eliminated"
	f.draw_string(HEAD, Vector2(left, _center.y - 20.0), heading, HORIZONTAL_ALIGNMENT_CENTER, width, 66, KILLS if placement == 1 else TAKEN)
	f.draw_string(BODY, Vector2(left, _center.y + 44.0), "#%d of %d" % [placement, field], HORIZONTAL_ALIGNMENT_CENTER, width, 54, TEXT)  # (Olde Tome has no numbers)
	f.draw_string(BODY, Vector2(left, _center.y + 88.0), "Survived  %s" % _clock(MatchStats.seconds), HORIZONTAL_ALIGNMENT_CENTER, width, 27, DIM)


## The tally: the plain numbers.
func _page_tally() -> void:
	var rows := [
		["Kills", str(MatchStats.kills), KILLS],
		["Damage dealt", str(roundi(MatchStats.dealt)), DEALT],
		["Damage taken", str(roundi(MatchStats.taken)), TAKEN],
		["Spells cast", str(MatchStats.casts), CAST],
		["Missed", str(MatchStats.misses), MISSED],
		["Accuracy", "%d%%" % roundi(MatchStats.average_accuracy() * 100.0), LEARNED],
		["Spells learned", "%d of %d" % [MatchStats.pages_known(), Pages.every().size()], LEARNED],
	]
	_list(rows, _center.y - 4.0 - 17.0 * rows.size())


## What was cast most, and what the damage came from.
func _page_favourites() -> void:
	var rows := []
	var ranked: Array = MatchStats.cast_by_spell.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(MatchStats.cast_by_spell[a]) > int(MatchStats.cast_by_spell[b]))
	for index in mini(ranked.size(), 3):
		var spell: String = ranked[index]
		var school: String = SpellData.SPELLS[spell].school if SpellData.SPELLS.has(spell) else ""
		rows.append([spell, str(int(MatchStats.cast_by_spell[spell])), SpellData.SCHOOL_COLORS.get(school, TEXT)])
	if rows.is_empty():
		rows.append(["Nothing cast", "", DIM])
	var schools: Array = MatchStats.damage_by_school.keys()
	schools.sort_custom(func(a: String, b: String) -> bool: return float(MatchStats.damage_by_school[a]) > float(MatchStats.damage_by_school[b]))
	var first_of_damage := rows.size()
	for index in mini(schools.size(), 3):
		var school: String = schools[index]
		rows.append([SpellData.school_name(school), str(roundi(float(MatchStats.damage_by_school[school]))), SpellData.SCHOOL_COLORS.get(school, TEXT)])
	var top := _center.y - 4.0 - 17.0 * (rows.size() + (1 if schools.size() > 0 else 0))
	_list(rows.slice(0, first_of_damage), top)
	if schools.size() > 0:
		_face.draw_string(BODY, Vector2(_center.x - _radius * 0.52, top + 34.0 * first_of_damage + 26.0), "Damage by school", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, DIM)
		_list(rows.slice(first_of_damage), top + 34.0 * first_of_damage + 34.0)


## Rows of a colored square, a name and a number, down the middle of the ball.
func _list(rows: Array, top: float) -> void:
	var left := _center.x - _radius * 0.52
	var width := _radius * 1.04
	for index in rows.size():
		var y := top + 34.0 * index
		_face.draw_rect(Rect2(left, y + 8.0, 10.0, 10.0), rows[index][2])
		_face.draw_string(BODY, Vector2(left + 20.0, y + 26.0), rows[index][0], HORIZONTAL_ALIGNMENT_LEFT, width - 20.0, 27, TEXT)
		_face.draw_string(BODY, Vector2(left, y + 26.0), rows[index][1], HORIZONTAL_ALIGNMENT_RIGHT, width, 27, DIM)


## A line chart in the glass: a line for each series (the running total at every sample) and a few levels to read it by.
func _chart(title: String, lines: Array, stepped := false) -> void:
	var f := _face
	var plot := Rect2(_center + Vector2(-_radius * 0.66, -_radius * 0.40), Vector2(_radius * 1.32, _radius * 0.78))
	var last: float = MatchStats.series[MatchStats.series.size() - 1]["t"]
	var top := 1.0
	for line: Array in lines:
		for point: Dictionary in MatchStats.series:
			top = maxf(top, float(point[line[2]]))
	top = _round_up(top)
	for step in 5:  # the levels, with the value of each
		var level := plot.end.y - plot.size.y * step / 4.0
		f.draw_line(Vector2(plot.position.x, level), Vector2(plot.end.x, level), GRID, 1.0)
		f.draw_string(BODY, Vector2(plot.position.x + 4.0, level - 3.0), str(roundi(top * step / 4.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	f.draw_string(BODY, Vector2(plot.position.x, plot.end.y + 22.0), "0:00", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, DIM)
	f.draw_string(BODY, Vector2(plot.end.x - 60.0, plot.end.y + 22.0), _clock(last), HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 18, DIM)
	_charts.append({"box": plot, "plot": plot, "last": last, "top": top, "lines": lines, "title": title})
	var key_x := _center.x - 48.0 * lines.size()
	for line: Array in lines:
		var points := PackedVector2Array()
		var previous := plot.end
		for point: Dictionary in MatchStats.series:
			var at := Vector2(plot.position.x + plot.size.x * (float(point["t"]) / maxf(last, 1.0)), plot.end.y - plot.size.y * float(point[line[2]]) / top)
			if stepped and not points.is_empty():
				points.append(Vector2(at.x, previous.y))  # a count that only goes up in whole steps
			points.append(at)
			previous = at
		if points.size() >= 2:
			var fill := PackedVector2Array(points)
			fill.append(Vector2(points[points.size() - 1].x, plot.end.y))
			fill.append(Vector2(points[0].x, plot.end.y))
			f.draw_colored_polygon(fill, Color(line[1], 0.14))
			f.draw_polyline(points, Color(line[1], 0.35), 7.0, true)  # a glow under the line
			f.draw_polyline(points, line[1], 3.0, true)
		f.draw_string(BODY, Vector2(key_x, plot.position.y - 12.0), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, line[1])
		key_x += 96.0


## Under the pointer on the chart: a guide line at the nearest sample, a dot on each line and a small note with the time and the numbers.
func _draw_reading(view: Vector2) -> void:
	for chart: Dictionary in _charts:
		var plot: Rect2 = chart["plot"]
		if not plot.grow(10.0).has_point(_pointer):
			continue
		var last: float = chart["last"]
		var top: float = chart["top"]
		var wanted := clampf((_pointer.x - plot.position.x) / plot.size.x, 0.0, 1.0) * last
		var sample: Dictionary = MatchStats.series[0]
		for point: Dictionary in MatchStats.series:
			if absf(float(point["t"]) - wanted) < absf(float(sample["t"]) - wanted):
				sample = point
		var x := plot.position.x + plot.size.x * float(sample["t"]) / maxf(last, 1.0)
		_face.draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(1, 1, 1, 0.4), 1.0)
		var rows: Array[String] = [_clock(float(sample["t"]))]
		var colors: Array[Color] = [DIM]
		for line: Array in chart["lines"]:
			var value := float(sample[line[2]])
			_face.draw_circle(Vector2(x, plot.end.y - plot.size.y * value / top), 5.0, line[1])
			rows.append("%s  %d" % [line[0], roundi(value)])
			colors.append(line[1])
		var tip := Rect2(Vector2(x + 12.0, plot.position.y + 8.0), Vector2(120.0, 12.0 + 24.0 * rows.size()))
		if tip.end.x > plot.end.x:
			tip.position.x = x - 12.0 - tip.size.x
		_face.draw_rect(tip, Color(0.02, 0.0, 0.05, 0.95))
		_face.draw_rect(tip, BRASS, false, 1.0)
		for index in rows.size():
			_face.draw_string(BODY, tip.position + Vector2(10.0, 24.0 + 24.0 * index), rows[index], HORIZONTAL_ALIGNMENT_LEFT, tip.size.x - 14.0, 22, colors[index])
		return


## Minutes and seconds: 83 seconds is 1:23.
static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## The next round figure up from a value, so that the top of a chart is a number a person would pick.
static func _round_up(value: float) -> float:
	if value <= 4.0:
		return 4.0
	var scale := pow(10.0, floorf(log(value) / log(10.0)))
	for factor in [1.0, 2.0, 2.5, 4.0, 5.0, 8.0, 10.0]:
		if value <= scale * factor:
			return scale * factor
	return value
