class_name Tutorial
extends Lab

## The tutorial room: a level stretch of ground with one place for each school. Standing at one shows a page of the book on screen with the
## school's mouse, an example spell drawn out and a line to try it on a dummy, a turret or a pond. Two of them go on to a meeting of
## spells: water laid across a pond, and a vine set alight. It is the waiting room's own ground and targets, but stamina runs out here as it does in
## a match, and the portal at the far end leads back to the first screen.

const POND_SPAN := Vector2i(24, 44)   # water too wide to jump, and too deep to wade
const POND_ROWS := 4.0
const REACH := 5.0  # columns either side of a place within which its page shows
const CHUNKS := 52  # the room is wide, so that the places are far apart
const PARCHMENT := Color("#e9d7bb")  # the plate a spell's shape is drawn on
const PANEL := Color("#1f1528")
const PANEL_DONE := Color("#1d2c22")
const WORDS := Color("#efe3cf")
const LETTERING := Lettering.FACE  # the face of the home screen and the spellbook
const WORDS_DONE := Color("#a9dc98")
const MENU := "res://scenes/menu.tscn"

## Each place: the column it stands at, its title and its colour's school, and its steps: the spells to try (one is enough where it says "any").
## A place with `keys` shows keys and what they do instead of spells. A step whose first entry begins "chant:" is a chant, spoken with Enter.
## A place's `note` is the line under its steps. A place with a `goal` is done on standing on the ground within ten columns past that column;
## the Plants place is done when its thorns are gone. Each of those is shut off from the next place by something the spells must clear:
## water and a pit too wide to cross, turrets, thorns too long to walk through, a cliff too high to jump.
const PLACES := [
	{"col": -30, "title": "Controls", "school": "", "keys": [
		["A D", "Move."],
		["W Space", "Jump."],
		["", "Hold a school's mouse buttons and draw its shape."],
		["Tab", "Open the spellbook."],
		["Enter", "Speak a chant."],
		["", "Watch your stamina at the top left. Spells cost stamina."],
		["", "Stamina will recharge while you stand still."]]},
	{"col": -14, "title": "Attack", "school": "Fire", "any": true, "steps": [
		["Ignite"], ["Frostbolt"], ["Stonefall"]],
		"note": "Fell the dummy with one of these."},
	{"col": 4, "title": "Maximum Stamina", "school": "Blood", "steps": [
		["Adrenaline"]],
		"note": "Necromancy spells are more powerful, but they spend maximum stamina that does not come back."},
	{"col": 18, "title": "Cross Water", "school": "Water", "any": true, "goal": 48, "steps": [
		["Frost Bridge"], ["Lily Pads"]],
		"note": "Cross the pond with one of these."},
	{"col": 60, "title": "Block Projectiles", "school": "Air", "any": true, "goal": 106, "steps": [
		["Barrier"], ["Stone Wall"]],
		"note": "Get past the turrets with one of these."},
	{"col": 110, "title": "Burn Plants", "school": "Fire", "any": true, "thicket": true, "steps": [
		["Ignite"], ["Fire Breath"]],
		"note": "Burn the thorns with one of these."},
	{"col": 160, "title": "Higher Ground", "school": "", "goal": 178, "steps": [
		["chant:double_jump"]],
		"note": "Press Enter, type the words, then press Enter. Then climb the cliff."},
	{"col": 192, "title": "Cross a Pit", "school": "Air", "any": true, "goal": 233, "steps": [
		["Rocket Jump"], ["Featherfall"], ["Push"]],
		"note": "Cross the pit with one of these."},
]
const CLIFF_COL := 170       # from here on the ground is this many rows higher than before: too high to jump, near enough for a second jump
const CLIFF_ROWS := 7.0
const GAP_SPAN := Vector2i(204, 229)   # a pit far too wide to jump, on the high ground: the spells listed carry a jump across it
const GAP_ROWS_DOWN := 4.0
const THICKET_SPAN := Vector2i(118, 150)   # thorns across the way, far too long to walk through
const THICKET_LAYERS := 10
const TURRETS := [70, 82, 94]
const DUMMIES := [-6]
const DUMMY_HP := 36  # three fireballs: the tutorial's dummies fall quickly, so each try is seen through

var _done := {}      # place index -> {step index: true}
var _guide: CanvasLayer
var _panel: PanelContainer
var _shown := -1     # the place whose page is up, or -1
var _marks: Array[TutorialMark] = []
var _thickets: Array[Bramble] = []
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
	for col in range(ArenaGen.FIRST_COL, CLIFF_COL):
		heights[col - ArenaGen.FIRST_COL] = CLIFF_ROWS  # the low ground, which the high ground at the end of the room stands over
	_dig_into(heights, POND_SPAN, CLIFF_ROWS, POND_ROWS)
	_dig_into(heights, GAP_SPAN, 0.0, GAP_ROWS_DOWN)
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


## A pit of the same shape as the others, dug down from the ground at `base` rows.
func _dig_into(heights: PackedFloat32Array, span: Vector2i, base: float, rows: float) -> void:
	for col in range(span.x, span.y + 1):
		var edge := mini(col - span.x, span.y - col)
		var t := clampf((edge + 0.5) / 3.0, 0.0, 1.0)
		heights[col - ArenaGen.FIRST_COL] = base + rows * t * t * (3.0 - 2.0 * t)


func _add_ponds() -> void:
	var pond := Pond.new()
	pond.width = (POND_SPAN.y - POND_SPAN.x + 1) * float(ArenaGen.TILE)
	pond.depth = POND_ROWS * ArenaGen.TILE + 16.0
	pond.position = Vector2(POND_SPAN.x * float(ArenaGen.TILE), ArenaGen.GROUND_Y + CLIFF_ROWS * ArenaGen.TILE)
	pond.ground = _ground
	add_child(pond)


func _add_targets() -> void:
	for col: int in DUMMIES:
		var mob := _add_mob("dummy", Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		mob.max_hp = DUMMY_HP
		mob.hp = DUMMY_HP
		mob.facing = -1.0 if col < 0 else 1.0
	_plant_thicket()
	for col: int in TURRETS:
		var turret := _add_mob("turret", Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_cells, col)))
		turret.facing = -1.0


## The thorns across the way at the Plants place: planted like the world's own, so fire burns them away.
func _plant_thicket() -> void:
	var points := PackedVector2Array()
	for col in range(THICKET_SPAN.x, THICKET_SPAN.y + 1):
		for half in 2:
			var x := (col + half * 0.5) * float(ArenaGen.TILE)
			points.append(Vector2(x, ArenaGen.surface_y(_cells, col)))
	for layer in THICKET_LAYERS:  # each layer pricks on its own, so that walking all the way through is more than a wizard can take
		var thorns := Bramble.new()
		thorns.planted_ground = points
		add_child(thorns)
		_thickets.append(thorns)


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
			_marks[_shown].lit = _is_done(_shown)
			_show(_shown)  # the page is made again, with the step marked done
			return


## Whoever falls is on their feet again at the place they were working on, and has to get past what shut them off.
func _on_player_died() -> void:
	var column := player.global_position.x / float(ArenaGen.TILE)
	var back: int = PLACES[0]["col"]
	for entry: Dictionary in PLACES:
		if entry["col"] + 0.5 <= column:
			back = entry["col"]
	super()
	_return_to.call_deferred(back)


func _return_to(column: int) -> void:
	player.global_position = Vector2(ArenaGen.column_x(column), ArenaGen.surface_y(_cells, column) - 20.0)
	player.velocity = Vector2.ZERO


## How many layers of thorns still stand at the Plants place.
func thorns_left() -> int:
	var left := 0
	for thorns in _thickets:
		if is_instance_valid(thorns) and not thorns.is_queued_for_deletion():
			left += 1
	return left


## Whether everything a place asks has been done: its goal reached, or its spells tried (one of them, where one is enough).
func _is_done(place: int) -> bool:
	var entry: Dictionary = PLACES[place]
	if _reached.has(place):
		return true
	if entry.has("goal") or entry.get("thicket", false):
		return false
	var steps: Array = entry.get("steps", [])
	var tried: int = _done.get(place, {}).size()
	return not steps.is_empty() and (tried >= 1 if entry.get("any", false) else tried == steps.size())


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


## A place with a goal is done when the wizard stands on solid ground within ten columns past the column it names, or, at the Plants place, when the
## thorns are gone. Whoever has fallen into the pond or the pit is put back on its near edge, where they came from.
func _check_goals(column: float) -> void:
	for k in PLACES.size():
		var entry: Dictionary = PLACES[k]
		if _reached.has(k):
			continue
		var met := false
		if entry.has("goal"):
			met = column >= entry["goal"] and column < entry["goal"] + 6.0 and player.is_on_floor()
		elif entry.get("thicket", false):
			met = thorns_left() == 0
		if met:
			_reached[k] = true
			_marks[k].lit = true
			Sfx.play("pickup")
			if _shown == k:
				_show(k)
	for pit: Array in [[POND_SPAN, POND_ROWS], [GAP_SPAN, GAP_ROWS_DOWN]]:
		var span: Vector2i = pit[0]
		var edge := span.x - 3
		if column >= span.x and column <= span.y and player.global_position.y > ArenaGen.surface_y(_cells, edge) + (float(pit[1]) - 1.0) * ArenaGen.TILE:
			player.global_position = Vector2(ArenaGen.column_x(edge), ArenaGen.surface_y(_cells, edge) - 20.0)
			player.velocity = Vector2.ZERO


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
	style.bg_color = PANEL_DONE if _is_done(place) else PANEL
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
		if k > 0 and entry.get("any", false):
			var either := _ink("or", 24, accent.lightened(0.25))
			either.autowrap_mode = TextServer.AUTOWRAP_OFF
			either.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(either)
		row.add_child(_step(steps[k][0], steps[k][1] if steps[k].size() > 1 else "", _done.get(place, {}).has(k), accent))
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
	top.add_child(name_label)  # the mouse (or the key) comes first, with the name beside it
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(top)
	box.add_child(plate)
	if prompt != "":
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
		label.position = Vector2(-110.0, -140.0)
		label.size = Vector2(220.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var strength := (0.5 if lit else 0.24) + 0.05 * sin(_t * 2.0)
		Fx.draw_glow(self, Vector2(0.0, -8.0), 46.0, Color(colour.r, colour.g, colour.b, strength))
		Fx.draw_glow(self, Vector2(0.0, -8.0), 18.0, Color(colour.r, colour.g, colour.b, strength + 0.2))
