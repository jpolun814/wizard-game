class_name StatsScreen
extends Control

## What is shown over the screen when the person falls, as in a battle royale: where they placed, how long they lasted, and the story of their match as
## charts over time (damage dealt and taken, spells learned, spells cast and missed, who they felled), with the shares of spells learned, cast and missed
## and a few other things worth knowing. Everything comes from MatchStats. It is an interface: it speaks to the person, not as the world.

signal dismissed

const PANEL := Color(0.05, 0.02, 0.08, 0.94)
const EDGE := Color("#c9a45a")
const TEXT := Color("#f0e6d0")
const DIM := Color("#9a8fa8")
const GRID := Color(1, 1, 1, 0.08)
const DEALT := Color("#ff8a3d")
const TAKEN := Color("#e0485a")
const LEARNED := Color("#7fd3ff")
const CAST := Color("#7fe08a")
const MISSED := Color("#b9a0ff")
const KILLS := Color("#ffd85a")

var placement := 1
var field := 4
var _button: Button
var _charts: Array[Dictionary] = []  # where each chart was drawn this frame, for reading a value off it
var _pointer := Vector2(-1.0, -1.0)


## Builds the screen from what MatchStats holds now. `place` is where the person came (1 is the winner) among `of_total` wizards, and `watching` says
## whether the match goes on for them to watch.
func show_stats(place: int, of_total: int, watching: bool) -> void:
	placement = place
	field = of_total
	MatchStats.close()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		child.queue_free()
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
	get_viewport().size_changed.connect(_fit)
	queue_redraw()


## The screen lies over the whole window. (Its parent is a layer, not a control, so it does not stretch by itself.)
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _close() -> void:
	visible = false
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		queue_redraw()
	if event is InputEventMouseButton:
		accept_event()  # a click on the screen is not a click on the world behind it


# --- Drawing ----------------------------------------------------------------------------------------------------


func _draw() -> void:
	if MatchStats.series.is_empty():
		return
	var view := get_viewport_rect().size
	_charts.clear()
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.02, 0.0, 0.04, 0.6))
	var width := minf(view.x - 48.0, 1180.0)
	var height := minf(view.y - 40.0, 700.0)
	var panel := Rect2((view - Vector2(width, height)) * 0.5, Vector2(width, height))
	draw_rect(panel, PANEL)
	draw_rect(panel, EDGE, false, 2.0)
	var font := ThemeDB.fallback_font
	var x := panel.position.x + 24.0
	var top := panel.position.y + 18.0
	# The header: where they placed, and how long they lasted.
	var heading := "Victory" if placement == 1 else "Eliminated"
	draw_string(font, Vector2(x, top + 34.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 40, KILLS if placement == 1 else TAKEN)
	var place_text := "#%d of %d" % [placement, field]
	draw_string(font, Vector2(x + 250.0, top + 34.0), place_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, TEXT)
	draw_string(font, Vector2(panel.end.x - 24.0 - 260.0, top + 30.0), "Survived  %s" % _clock(MatchStats.seconds), HORIZONTAL_ALIGNMENT_RIGHT, 260.0, 26, DIM)
	# The cards: the numbers people look for first.
	var cards := [
		["Kills", str(MatchStats.kills), KILLS],
		["Damage dealt", str(roundi(MatchStats.dealt)), DEALT],
		["Damage taken", str(roundi(MatchStats.taken)), TAKEN],
		["Spells cast", str(MatchStats.casts), CAST],
		["Missed", str(MatchStats.misses), MISSED],
		["Accuracy", "%d%%" % roundi(MatchStats.average_accuracy() * 100.0), LEARNED],
	]
	var card_width := (panel.size.x - 48.0 - 10.0 * (cards.size() - 1)) / cards.size()
	for index in cards.size():
		var box := Rect2(x + index * (card_width + 10.0), top + 56.0, card_width, 66.0)
		draw_rect(box, Color(1, 1, 1, 0.05))
		draw_rect(Rect2(box.position, Vector2(4.0, box.size.y)), cards[index][2])
		draw_string(font, box.position + Vector2(14.0, 26.0), cards[index][0], HORIZONTAL_ALIGNMENT_LEFT, card_width - 18.0, 16, DIM)
		draw_string(font, box.position + Vector2(14.0, 56.0), cards[index][1], HORIZONTAL_ALIGNMENT_LEFT, card_width - 18.0, 32, TEXT)
	# The charts, two by two, and the shares beside them.
	var chart_top := top + 136.0
	var share_width := 270.0
	var area := Rect2(x, chart_top, panel.size.x - 48.0 - share_width - 16.0, panel.end.y - chart_top - 62.0)
	var cell := Vector2((area.size.x - 14.0) * 0.5, (area.size.y - 14.0) * 0.5)
	_chart(Rect2(area.position, cell), "Damage over time",
			[["Dealt", DEALT, "dealt"], ["Taken", TAKEN, "taken"]])
	_chart(Rect2(area.position + Vector2(cell.x + 14.0, 0.0), cell), "Spells learned",
			[["Learned", LEARNED, "known"]], true)
	_chart(Rect2(area.position + Vector2(0.0, cell.y + 14.0), cell), "Spells cast and missed",
			[["Cast", CAST, "casts"], ["Missed", MISSED, "misses"]])
	_chart(Rect2(area.position + cell + Vector2(14.0, 14.0), cell), "Wizards felled",
			[["Kills", KILLS, "kills"]], true)
	_shares(Rect2(Vector2(area.end.x + 16.0, chart_top), Vector2(share_width, area.size.y)))
	# The button sits at the foot of the panel.
	if _button != null:
		_button.size = Vector2(240.0, 44.0)
		_button.position = Vector2(panel.get_center().x - 120.0, panel.end.y - 56.0)
	_draw_reading(view)


## One line chart: a title, a grid, a line for each series (the running total at every sample) and a key.
func _chart(box: Rect2, title: String, lines: Array, stepped := false) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(box, Color(1, 1, 1, 0.04))
	draw_string(font, box.position + Vector2(12.0, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	var plot := Rect2(box.position + Vector2(44.0, 34.0), box.size - Vector2(58.0, 54.0))
	var last: float = MatchStats.series[MatchStats.series.size() - 1]["t"]
	var top := 1.0
	for line: Array in lines:
		for point: Dictionary in MatchStats.series:
			top = maxf(top, float(point[line[2]]))
	top = _round_up(top)
	for step in 5:  # the grid, with the value of each line
		var level := plot.end.y - plot.size.y * step / 4.0
		draw_line(Vector2(plot.position.x, level), Vector2(plot.end.x, level), GRID, 1.0)
		draw_string(font, Vector2(box.position.x + 6.0, level + 5.0), str(roundi(top * step / 4.0)), HORIZONTAL_ALIGNMENT_RIGHT, 32.0, 12, DIM)
	draw_string(font, Vector2(plot.position.x, box.end.y - 6.0), "0:00", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, DIM)
	draw_string(font, Vector2(plot.end.x - 60.0, box.end.y - 6.0), _clock(last), HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 12, DIM)
	_charts.append({"box": box, "plot": plot, "last": last, "top": top, "lines": lines, "title": title})
	var key_x := box.end.x - 12.0
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
			draw_polyline(points, line[1], 2.5, true)
			var fill := PackedVector2Array(points)
			fill.append(Vector2(points[points.size() - 1].x, plot.end.y))
			fill.append(Vector2(points[0].x, plot.end.y))
			draw_colored_polygon(fill, Color(line[1], 0.12))
		draw_string(font, Vector2(key_x - 90.0, box.position.y + 22.0), line[0], HORIZONTAL_ALIGNMENT_RIGHT, 90.0, 14, line[1])
		key_x -= 96.0


## Under the pointer on a chart: a guide line at the nearest sample, a dot on each line and a small box with the time and the numbers.
func _draw_reading(view: Vector2) -> void:
	for chart: Dictionary in _charts:
		var box: Rect2 = chart["box"]
		var plot: Rect2 = chart["plot"]
		if not box.has_point(_pointer):
			continue
		var last: float = chart["last"]
		var top: float = chart["top"]
		var wanted := clampf((_pointer.x - plot.position.x) / plot.size.x, 0.0, 1.0) * last
		var sample: Dictionary = MatchStats.series[0]
		for point: Dictionary in MatchStats.series:
			if absf(float(point["t"]) - wanted) < absf(float(sample["t"]) - wanted):
				sample = point
		var x := plot.position.x + plot.size.x * float(sample["t"]) / maxf(last, 1.0)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(1, 1, 1, 0.35), 1.0)
		var font := ThemeDB.fallback_font
		var rows: Array[String] = [_clock(float(sample["t"]))]
		var colours: Array[Color] = [DIM]
		for line: Array in chart["lines"]:
			var value := float(sample[line[2]])
			draw_circle(Vector2(x, plot.end.y - plot.size.y * value / top), 4.0, line[1])
			rows.append("%s  %d" % [line[0], roundi(value)])
			colours.append(line[1])
		var tip := Rect2(Vector2(x + 12.0, plot.position.y + 4.0), Vector2(120.0, 10.0 + 20.0 * rows.size()))
		if tip.end.x > view.x - 8.0 or tip.end.x > box.end.x:
			tip.position.x = x - 12.0 - tip.size.x
		draw_rect(tip, Color(0.02, 0.0, 0.04, 0.95))
		draw_rect(tip, EDGE, false, 1.0)
		for index in rows.size():
			draw_string(font, tip.position + Vector2(10.0, 22.0 + 20.0 * index), rows[index], HORIZONTAL_ALIGNMENT_LEFT, tip.size.x - 14.0, 16, colours[index])
		return


## The shares beside the charts: how much of the book was found, how many tries went off, and what was cast most.
func _shares(box: Rect2) -> void:
	var font := ThemeDB.fallback_font
	draw_rect(box, Color(1, 1, 1, 0.04))
	var y := box.position.y + 26.0
	var x := box.position.x + 14.0
	var inner := box.size.x - 28.0
	draw_string(font, Vector2(x, y), "Spells learned", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	y += 14.0
	y = _bar(Vector2(x, y), inner, [[MatchStats.learned_share(), LEARNED]], "%d of %d  (%d%%)" % [MatchStats.spells_known(), SpellData.SPELLS.size(), roundi(MatchStats.learned_share() * 100.0)]) + 24.0
	draw_string(font, Vector2(x, y), "Cast and missed", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	y += 14.0
	var cast_share := MatchStats.cast_share()
	y = _bar(Vector2(x, y), inner, [[cast_share, CAST], [1.0 - cast_share, MISSED]], "Cast %d%%    Missed %d%%" % [roundi(cast_share * 100.0), roundi((1.0 - cast_share) * 100.0)]) + 24.0
	draw_string(font, Vector2(x, y), "Most cast", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
	y += 8.0
	var ranked: Array = MatchStats.cast_by_spell.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(MatchStats.cast_by_spell[a]) > int(MatchStats.cast_by_spell[b]))
	if ranked.is_empty():
		draw_string(font, Vector2(x, y + 20.0), "Nothing cast", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, DIM)
		y += 24.0
	for index in mini(ranked.size(), 3):
		var spell: String = ranked[index]
		var school: String = SpellData.SPELLS[spell].school if SpellData.SPELLS.has(spell) else ""
		draw_rect(Rect2(x, y + 9.0, 10.0, 10.0), SpellData.SCHOOL_COLORS.get(school, TEXT))
		draw_string(font, Vector2(x + 18.0, y + 19.0), spell, HORIZONTAL_ALIGNMENT_LEFT, inner - 60.0, 15, TEXT)
		draw_string(font, Vector2(x, y + 19.0), "%d" % int(MatchStats.cast_by_spell[spell]), HORIZONTAL_ALIGNMENT_RIGHT, inner, 15, DIM)
		y += 24.0
	y += 14.0
	var school_rows: Array = MatchStats.damage_by_school.keys()
	if not school_rows.is_empty():
		school_rows.sort_custom(func(a: String, b: String) -> bool: return float(MatchStats.damage_by_school[a]) > float(MatchStats.damage_by_school[b]))
		draw_string(font, Vector2(x, y), "Damage by school", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, TEXT)
		y += 8.0
		for index in mini(school_rows.size(), 3):
			var school: String = school_rows[index]
			draw_rect(Rect2(x, y + 9.0, 10.0, 10.0), SpellData.SCHOOL_COLORS.get(school, TEXT))
			draw_string(font, Vector2(x + 18.0, y + 19.0), SpellData.school_name(school), HORIZONTAL_ALIGNMENT_LEFT, inner - 60.0, 15, TEXT)
			draw_string(font, Vector2(x, y + 19.0), "%d" % roundi(float(MatchStats.damage_by_school[school])), HORIZONTAL_ALIGNMENT_RIGHT, inner, 15, DIM)
			y += 24.0
	if MatchStats.biggest_hit > 0.0 and y < box.end.y - 30.0:
		draw_string(font, Vector2(x, box.end.y - 14.0), "Biggest hit  %d" % roundi(MatchStats.biggest_hit), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, DIM)


## A bar split into shares of the whole (each a fraction and a colour), with a caption under it. Returns the y just under the caption.
func _bar(at: Vector2, width: float, parts: Array, caption: String) -> float:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(at, Vector2(width, 16.0)), Color(1, 1, 1, 0.08))
	var used := 0.0
	for part: Array in parts:
		var span := width * clampf(float(part[0]), 0.0, 1.0)
		draw_rect(Rect2(at + Vector2(used, 0.0), Vector2(span, 16.0)), part[1])
		used += span
	draw_string(font, at + Vector2(0.0, 36.0), caption, HORIZONTAL_ALIGNMENT_LEFT, width, 15, DIM)
	return at.y + 36.0


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
