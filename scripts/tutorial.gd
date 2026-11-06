class_name Tutorial
extends Lab

## The tutorial room: a level stretch of ground with one place for each school. Standing at one shows a page of the book on screen with the
## school's mouse, an example spell drawn out and a line to try it on a dummy, a turret or a pond. Two of them go on to a meeting of
## spells: water laid across a pond, and a vine set alight. It is the waiting room's own ground and targets, but stamina runs out here as it does in
## a match, and the portal at the far end leads back to the first screen.

const POND_SPAN := Vector2i(12, 24)
const REACH := 5.0  # columns either side of a place within which its page shows
const CHUNKS := 44  # the room is wide, so that the places are far apart
const PARCHMENT := Color("#e9d7bb")  # the plate a spell's shape is drawn on
const PANEL := Color("#1f1528")
const PANEL_DONE := Color("#1d2c22")
const WORDS := Color("#efe3cf")
const LETTERING := Lettering.FACE  # the face of the home screen and the spellbook
const WORDS_DONE := Color("#a9dc98")
const MENU := "res://scenes/menu.tscn"

## Each place: the column it stands at, its title and its colour's school, and its steps: the spell to try and the line that asks for it.
## A place with a `keys` list shows keys and what they do instead of spells. A step whose first entry begins "chant:" is a chant, spoken with Enter.
## A place's `note` is a line under its steps.
const PLACES := [
	{"col": -30, "title": "Tutorial", "school": "", "keys": [
		["A D", "Move."],
		["W Space", "Jump."],
		["", "Hold a school's mouse buttons and draw its shape."],
		["Tab", "Open the spellbook."],
		["Enter", "Speak a chant."],
		["", "Watch your stamina at the top left. Spells cost stamina."],
		["", "Stamina will recharge while you stand still."]]},
	{"col": -14, "title": "Pyromancy", "school": "Fire", "steps": [
		["Ignite", "Draw a short line toward the dummy."]]},
	{"col": 4, "title": "Aquamagy", "school": "Water", "steps": [
		["Frostbolt", "Draw a short line toward the dummy."],
		["Frost Bridge", "Draw a wavy line across the pond, then cross it."]]},
	{"col": 38, "title": "Aerokinesis", "school": "Air", "steps": [
		["Barrier", "Draw a circle round yourself as the turret fires."]]},
	{"col": 60, "title": "Terramancy", "school": "Earth", "steps": [
		["Stonefall", "Draw a circle with a line down, above the dummy."]]},
	{"col": 80, "title": "Druidry", "school": "Flora", "steps": [
		["Liana", "Draw a leaf, then a line up, and climb the vine."],
		["Ignite", "Then draw a short line into the vine."]]},
	{"col": 102, "title": "Umbramancy", "school": "Shadow", "steps": [
		["Decoy", "Draw a figure of eight."]]},
	{"col": 122, "title": "Necromancy", "school": "Blood", "steps": [
		["Adrenaline", "Draw a zigzag."]],
		"note": "Necromancy spells are more powerful, but they spend maximum stamina that does not come back."},
	{"col": 142, "title": "Chants", "school": "", "steps": [
		["chant:minimap", "Press Enter, type the words, then press Enter."],
		["chant:haste", "Press Enter, type the words, then press Enter."]]},
	{"col": 160, "title": "The Gap", "school": "", "goal": 180, "steps": [
		["Push", "Draw a circle, then a line out of it."],
		["Updraft", "Draw an arrow pointing up."],
		["Stone Wall", "Draw a line up from the ground."]],
		"note": "Reach the far side of the gap."},
	{"col": 196, "title": "The Turret", "school": "", "goal": 222, "steps": [
		["Barrier", "Draw a circle round yourself."],
		["Stone Wall", "Draw a line up from the ground."]],
		"note": "Get past the turret."},
]
const GAP_SPAN := Vector2i(166, 177)   # a pit too wide to jump
const GAP_ROWS_DOWN := 4.0
const GAUNTLET_TURRET := 212
const DUMMIES := [-8, -20, 9, 64, 84, 74]
const DUMMY_HP := 36  # three fireballs: the tutorial's dummies fall quickly, so each try is seen through
const TURRET := 46
const SHADOW_GUARD := 116  # a skeleton that comes for whoever is at the Umbramancy place: for a decoy, when there is one

var _done := {}      # place index -> {step index: true}
var _guide: CanvasLayer
var _panel: PanelContainer
var _shown := -1     # the place whose page is up, or -1
var _marks: Array[TutorialMark] = []
var _guard: Node2D
var _reached := {}   # place index -> true once its goal has been reached


func _init() -> void:
	ArenaGen.chunk_count = CHUNKS
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * CHUNKS


func _exit_tree() -> void:
	ArenaGen.chunk_count = ArenaGen.CHUNK_COUNT  # the other rooms are their usual width
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * ArenaGen.CHUNK_COUNT


func _build_map() -> Variant:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
	_dig(heights, POND_SPAN, PIT_ROWS)
	_dig(heights, GAP_SPAN, GAP_ROWS_DOWN)
	return ArenaGen.build(_rng, heights)


func _begin_encounter(camera: Camera2D) -> void:
	super(camera)
	player.infinite_time = 0.0  # the waiting room never lets stamina run out, but here it does, as it does in a match: this is where it is learned
	_guide = CanvasLayer.new()
	_guide.layer = 4
	add_child(_guide)
	for k in PLACES.size():
		var mark := TutorialMark.new()
		var col: int = PLACES[k]["col"]
		mark.position = Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col))
		mark.title = PLACES[k]["title"]
		mark.colour = SpellData.SCHOOL_COLORS[PLACES[k]["school"]] if PLACES[k]["school"] != "" else Color("#c8a8ff")
		add_child(mark)
		_marks.append(mark)


func _add_ponds() -> void:
	var pond := Pond.new()
	pond.width = (POND_SPAN.y - POND_SPAN.x + 1) * float(ArenaGen.TILE)
	pond.depth = PIT_ROWS * ArenaGen.TILE + 16.0
	pond.position = Vector2(POND_SPAN.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y)
	pond.ground = _ground
	add_child(pond)


func _add_targets() -> void:
	for col: int in DUMMIES:
		var mob := _add_mob("dummy", Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		mob.max_hp = DUMMY_HP
		mob.hp = DUMMY_HP
		mob.facing = -1.0 if col < 0 else 1.0
	var turret := _add_mob("turret", Vector2(ArenaGen.column_x(TURRET), ArenaGen.surface_y(_cells, TURRET)))
	turret.facing = -1.0
	var gauntlet := _add_mob("turret", Vector2(ArenaGen.column_x(GAUNTLET_TURRET), ArenaGen.surface_y(_cells, GAUNTLET_TURRET)))
	gauntlet.facing = -1.0


func _title() -> String:
	return "Tutorial"


func _scene_name() -> String:
	return "tutorial"


## The book on its stand here does not start a match: touching it leads back to the first screen too.
func _on_book_touched(body: Node2D) -> void:
	_on_portal_entered(body)


## The portal leads back to the first screen.
func _on_portal_entered(body: Node2D) -> void:
	if body != player or _leaving:
		return
	_leaving = true
	Sfx.play("portal_enter")
	var fade := create_tween()
	fade.tween_property(player, "modulate:a", 0.0, 0.25)
	fade.tween_callback(get_tree().change_scene_to_file.bind(MENU))


func spawn_spell(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, caster_node: Wizard) -> void:
	super(spell, targeting, origin, aim, info, caster_node)
	if caster_node != player:
		return
	_try_step(spell)


## Marks the step of the place the wizard stands at that asks for this spell (or "chant:" and a chant's id), if there is one not done yet.
func _try_step(wanted: String) -> void:
	if _shown < 0:
		return
	var steps: Array = PLACES[_shown].get("steps", [])
	for k in steps.size():
		if steps[k][0] == wanted and not _done.get(_shown, {}).has(k):
			if not _done.has(_shown):
				_done[_shown] = {}
			_done[_shown][k] = true
			_marks[_shown].lit = _done[_shown].size() == steps.size()
			_show(_shown)  # the page is made again, with the step marked done
			return


## A chant spoken well enough to take (the rest of it is the room's own) counts for the step that asks for it.
func _on_ritual_finished(id: String, acc: float, unfinished: bool) -> void:
	super(id, acc, unfinished)
	if not unfinished and acc >= RitualInput.BACKFIRE_BELOW:
		_try_step("chant:" + id)


func _process(delta: float) -> void:
	super(delta)
	var near := -1
	var best := REACH
	var column := player.global_position.x / float(ArenaGen.TILE)
	for k in PLACES.size():
		var distance := absf(column - (PLACES[k]["col"] + 0.5))
		if distance < best:
			best = distance
			near = k
	_check_goals(column)
	if near != _shown:
		_shown = near
		_show(near)
		_call_guard(near)


## A place with a goal is done when the wizard stands on solid ground at the column it names, past whatever stood in the way.
func _check_goals(column: float) -> void:
	for k in PLACES.size():
		if PLACES[k].has("goal") and not _reached.has(k) and column >= PLACES[k]["goal"] and player.is_on_floor():
			_reached[k] = true
			_marks[k].lit = true
			Sfx.play("pickup")
			if _shown == k:
				_show(k)


## The skeleton at the Umbramancy place is brought in when the wizard comes to that place and sent away when they leave it, so that it does not
## wander the room after them. It comes for whoever it can see: for a decoy, when there is one.
func _call_guard(place: int) -> void:
	if _guard != null and is_instance_valid(_guard):
		_guard.queue_free()
		_guard = null
	if place >= 0 and PLACES[place]["school"] == "Shadow":
		_guard = _add_mob("basic", Vector2(ArenaGen.column_x(SHADOW_GUARD), ArenaGen.surface_y(_cells, SHADOW_GUARD)))
		_guard.facing = -1.0


## Puts the page for a place up on screen, or takes the page down when the wizard has walked away from every place.
func _show(place: int) -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if place < 0:
		return
	var entry: Dictionary = PLACES[place]
	var school: String = entry["school"]
	var accent: Color = (SpellData.SCHOOL_COLORS[school] if school != "" else Color("#8a6ac8"))
	var steps: Array = entry.get("steps", [])
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_DONE if _reached.has(place) or (not entry.has("goal") and not steps.is_empty() and _done.get(place, {}).size() == steps.size()) else PANEL
	style.border_color = accent.lightened(0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	var heading := Label.new()
	heading.text = entry["title"]
	heading.add_theme_font_override("font", LETTERING)
	heading.add_theme_font_size_override("font_size", Lettering.size_near(46))
	heading.add_theme_color_override("font_color", accent)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	if entry.has("keys"):
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 8)
		for key: Array in entry["keys"]:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 10)
			for cap: String in String(key[0]).split(" ", false):
				line.add_child(Spellbook.KeyCap.new(cap))
			var words := _ink(key[1], 20, WORDS)
			words.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(words)
			lines.add_child(line)
		row.add_child(lines)
	for k in steps.size():
		row.add_child(_step(steps[k][0], steps[k][1], _done.get(place, {}).has(k), accent))
	if entry.has("note"):
		var note := _ink(entry["note"], 19, WORDS)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.custom_minimum_size = Vector2(560.0, 0.0)
		note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(note)
	_guide.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 84)


## One thing to try: the spell's name beside the mouse that casts it, its shape drawn out on a plate of parchment, and the line that asks for it.
## A chant has the key that opens the box, and the words to type.
func _step(page: String, prompt: String, done: bool, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var plate := PanelContainer.new()
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = PARCHMENT
	plate_style.set_corner_radius_all(4)
	plate_style.set_content_margin_all(4.0)
	plate.add_theme_stylebox_override("panel", plate_style)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := ""
	if page.begins_with("chant:"):
		var chant: Dictionary = RitualInput.RITUALS[page.trim_prefix("chant:")]
		title = chant["name"]
		top.add_child(Spellbook.KeyCap.new("Enter"))
		var words := _ink(chant["text"], 26, Spellbook.HEADING)
		words.autowrap_mode = TextServer.AUTOWRAP_OFF
		plate.add_child(words)
		plate.custom_minimum_size = Vector2(250.0, 104.0)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		var spell: Spell = SpellData.SPELLS[page]
		title = page
		top.add_child(Spellbook.MouseIcon.new(spell.buttons, SpellData.SCHOOL_COLORS[spell.school]))
		var gesture: String = spell.preview if spell.preview != "" else spell.gesture
		plate.add_child(Spellbook.Preview.new(GestureTemplates.preview_points(gesture), GestureTemplates.preview_ground(gesture), 104.0))
	var name_label := _ink(title, 26, WORDS_DONE if done else accent.lightened(0.25))
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.move_child(name_label, 0)
	box.add_child(top)
	box.add_child(plate)
	var text := _ink(prompt, 19, WORDS)
	text.custom_minimum_size = Vector2(250.0, 0.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	return box


func _ink(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A place's mark in the room: its name over a glow of the school's colour, brighter once everything there has been tried.
class TutorialMark extends Node2D:
	var title := ""
	var colour := Color.WHITE
	var lit := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		var label := Label.new()
		label.text = title
		label.theme_type_variation = &"Outlined"
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", colour.lightened(0.3))
		label.position = Vector2(-60.0, -140.0)
		label.size = Vector2(120.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var strength := (0.5 if lit else 0.24) + 0.05 * sin(_t * 2.0)
		Fx.draw_glow(self, Vector2(0.0, -8.0), 46.0, Color(colour.r, colour.g, colour.b, strength))
		Fx.draw_glow(self, Vector2(0.0, -8.0), 18.0, Color(colour.r, colour.g, colour.b, strength + 0.2))
