class_name RitualInput
extends CanvasLayer

## Typed incantation box, opened with Enter. The player types a ritual from memory and the
## box works out which ritual it is from the text. Accuracy (edit distance against the closest
## known incantation) sets how strong the ritual is. The incantations aren't shown here.

## unfinished is true when the words typed are the start of a chant, stopped short.
signal finished(ritual_id: String, accuracy: float, unfinished: bool)
signal cancelled

## "kind" is "ritual" (has an effect) or "toggle" (shows or hides a HUD module). Neither costs stamina.
const RITUALS := {
	"second_wind": {"kind": "ritual", "name": "Chant of the Second Wind", "text": "sanguis redit in venas meas, vita fluit in corpus, anima iterum surgit"},
	"minimap": {"kind": "toggle", "module": "minimap", "name": "Chant of the Land",
		"text": "terram ostende", "shows": "A minimap of the area around you, with mobs and yourself."},
	"insight": {"kind": "toggle", "module": "insight", "name": "Chant of Insight",
		"text": "hostes intellige", "shows": "Hover an enemy to see its health, weaknesses, resistances and what it does."},
	"bonfire": {"kind": "ritual", "name": "Incantation of the Bonfire",
		"text": "ignis hic ardeat, vires reddat"},
	"boundless": {"kind": "ritual", "name": "Chant of Boundless Vigour",
		"text": "vires aeternae fluant in membra, ignis sine fine ardet in sanguine"},
}
const BACKFIRE_BELOW := 0.6  # accuracy under this misfires
const FULL_POWER_AT := 0.9   # accuracy at or above this is full power

var _prompt: Label
var _line: LineEdit


func _ready() -> void:
	visible = false
	# Drawn above the spellbook (which is on layer 5), so the book never covers the text you're typing.
	layer = 10
	var view := get_viewport().get_visible_rect().size
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.05, 0.92)
	style.border_color = Color("#8a6a3a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(620, 0)
	box.position = Vector2((view.x - 620.0) * 0.5, view.y - 120.0)
	add_child(box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	box.add_child(column)
	_prompt = Label.new()
	_prompt.text = "Speak an incantation."
	column.add_child(_prompt)
	_line = LineEdit.new()
	_line.custom_minimum_size = Vector2(596, 32)
	_line.placeholder_text = "incantation..."
	_line.text_submitted.connect(_on_submit)
	column.add_child(_line)


func open() -> void:
	_line.text = ""
	visible = true
	# Focus after the key that opened the box has finished, so that key isn't typed into it.
	_line.grab_focus.call_deferred()


func cancel() -> void:
	if visible:
		visible = false
		_line.release_focus()
		cancelled.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		get_viewport().set_input_as_handled()


func _on_submit(typed: String) -> void:
	if typed.strip_edges().is_empty():
		cancel()  # Enter on an empty box just closes it
		return
	visible = false
	_line.release_focus()
	var best_id := ""
	var best_acc := 0.0
	var best_start := 0.0
	for id in RITUALS:
		var text: String = RITUALS[id]["text"]
		var acc := accuracy(typed, text)
		var start := start_accuracy(typed, text)
		if maxf(acc, start) > maxf(best_acc, best_start) or best_id == "":
			best_id = id
			best_acc = acc
			best_start = start
	var unfinished := best_acc < BACKFIRE_BELOW and best_start >= BACKFIRE_BELOW
	finished.emit(best_id, best_acc, unfinished)


## How well the typed words match the start of a chant, as far as they go. Stopping partway through a chant is
## bailing out, not getting it wrong.
static func start_accuracy(typed: String, target: String) -> float:
	var a := typed.strip_edges().to_lower()
	if a.is_empty() or a.length() >= target.length():
		return 0.0
	return accuracy(a, target.substr(0, a.length()))


## Power scales from 0 at the backfire threshold to 1 at full-power accuracy.
static func power_for(acc: float) -> float:
	if acc < BACKFIRE_BELOW:
		return 0.0
	return clampf((acc - BACKFIRE_BELOW) / (FULL_POWER_AT - BACKFIRE_BELOW), 0.0, 1.0)


static func accuracy(typed: String, target: String) -> float:
	var a := typed.strip_edges().to_lower()
	var b := target.to_lower()
	if b.is_empty():
		return 0.0
	return clampf(1.0 - float(levenshtein(a, b)) / b.length(), 0.0, 1.0)


static func levenshtein(a: String, b: String) -> int:
	var prev: Array = []
	for j in range(b.length() + 1):
		prev.append(j)
	for i in range(1, a.length() + 1):
		var cur: Array = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost))
		prev = cur
	return prev[b.length()]
