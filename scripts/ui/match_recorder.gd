class_name MatchRecorder
extends Node

## Writes down a whole match, for everyone in it, so that it can be read afterwards or played back: the AI's own decisions are in it too. This is not the same as
## `PlayRecorder`, which is how one person plays seen from their screen. One file a world, in user://match_logs/ (a check or a benchmark may write elsewhere, see `folder`).
## The folder is kept under `BUDGET` bytes: the oldest files go first. Lines (each starts with the seconds since the world began):
##   HEAD   the match: seed, stage, the world's name and biome, how many wizards
##   WZ     every wizard, wherever it is, ten times a second: id name kind(person|brain) level x y vx vy facing floor|air stamina max flags anim goal target cooldown
##          then, for an AI: its strength (how fit it thinks itself to fight), its caution and whether it is holding its spells to recharge
##          (flags: letters, W wet B burning O oiled F frozen S slowed Z asleep or fainted D dazed H hasted V veiled M muted L flying, P drawing a spell, C typing a chant, E waiting for a way over water, R resting, G holding its spells to recharge)
##   S      the person at this machine, twenty times a second: place, speed, floor|air, stamina, max, drawing, animation, then where their screen is centered and its zoom (their hands, with the next three)
##   M      the mouse in the world, twenty times a second;  A  the keys asked of the body (left or right -1 0 1, jump held, buttons held 1 left 2 right 4 middle)
##   K      a key or mouse button went down or up;  R  the chant words as typed
##   ST     a wizard's states changed (hexed, silenced, wet ...): wizard then state:seconds_left, comma-separated, or - for none
##   SAY    a person or an AI finished a chant: wizard ritual accuracy unfinished
##   BOOK   a wizard's pages, when they change
##   CAST   a spell went off: wizard spell targeting x y aim stamina_after
##   MISS   a stroke matched nothing
##   DEC    the AI chose a spell: wizard choice, then the scores that were above zero (spell:score), the gap to its rival and whether it saw them
##   HIT    a wizard took a blow: victim by(wizard or -) with(the class that struck) amount max_after place
##   HEAL   a wizard mended: wizard amount
##   FALL   a wizard fell: wizard by cause place
##   PAGE   a wizard read a page: wizard page x y
##   TERR   the ground once, as the world begins: "TERR width height" in 32 px tiles, then one "TR y x0-x1,x2-x3" for each row that holds ground (the tiles that are solid)
##   OB     what is in the world, at a pace of its own: id class owner x y (+ hp for a creature), shots twenty times a second, creatures and clouds four times
##   NEW / GONE   a thing appeared or went: id class owner x y (NEW ends with shot or thing: a shot is anything thrown or cast that travels)
##   DIG    the ground was dug: x y half-width depth
##   SNAP   everything lasting and every page lying about, every few seconds, so a reader can start anywhere
##   END    the world is over

const BUDGET := 400 * 1024 * 1024
const WIZARD_GAP := 0.1
const SHOT_GAP := 0.05
const OBJECT_GAP := 0.25
const SNAP_GAP := 5.0
const HAND_GAP := 0.05
const SHOT_GROUPS := ["shots", "projectiles"]
const OBJECT_GROUPS := ["mobs", "clouds", "rocks", "fires", "lasting", "pages", "danger"]

## True where a benchmark or a check wants a recording (the game itself records only matches someone plays).
static var force := false
## True where a run of simulated games (tests/tools/ai_arena.gd) has not asked for a recording: it must not fill the person's own folder of matches.
static var silent := false
static var folder := "user://match_logs"
static var _active: MatchRecorder
static var _stamp := ""
static var _world_number := 0

var arena: Node
var _path := ""
var _file: FileAccess
var _clock := 0.0
var _wizard_in := 0.0
var _shot_in := 0.0
var _object_in := 0.0
var _snap_in := 2.0
var _hand_in := 0.0
var _typed := ""
var _flush_in := 2.0
var _hooked := {}   # wizard instance id -> true
var _states := {}   # wizard instance id -> the states as last written
var _person_hooked := false
var _fallen := {}   # wizard instance id -> true, once its FALL is written
var _books := {}    # wizard instance id -> the book as last written
var _known := {}    # object instance id -> true, for what has been written as new


## Called by each world as it is built. A match someone plays is always recorded; a check is not, unless it set `force`.
static func attach(to_arena: Node) -> void:
	if silent and not force:
		return
	if not force and not Library.real_match():
		return
	if Net.dedicated or (Net.online() and not GameSettings.get_value("share_logs")):
		return
	var recorder := MatchRecorder.new()
	recorder.name = "MatchRecorder"
	recorder.arena = to_arena
	to_arena.add_child.call_deferred(recorder)


func _ready() -> void:
	if MatchStats.world_starts.size() <= 1 or _stamp == "":
		_stamp = Time.get_datetime_string_from_system().replace(":", "-")
		_world_number = 0
	_world_number += 1
	DirAccess.make_dir_recursive_absolute(folder)
	_path = "%s/%s_%s_w%d.log" % [folder, "net" if Net.online() else "match", _stamp, _world_number]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		return
	_active = self
	_line("HEAD seed %d stage %d world %s biome %s" % [MatchState.seed_base, MatchState.stage, arena.name, str(arena.get("grade_biome"))])
	_terrain()
	_forget_old()


func _exit_tree() -> void:
	_close()
	if _active == self:
		_active = null


## The person is out of the match, or has won: the world's file is closed now (in a network match it goes to the machine that keeps the game).
static func finish(_tree: SceneTree) -> void:
	if _active != null:
		_active._close()


## Ends the file. In a network match it is then packed and given to Net, which sends it and deletes the file once the other machine has it.
func _close() -> void:
	if _file == null:
		return
	for w: Wizard in get_tree().get_nodes_in_group("wizards") if is_inside_tree() else []:  # the match may end the file before a fall's own signal is heard
		if is_instance_valid(w) and w.dead:
			_write_fall(w)
	_line("END")
	_file.close()
	_file = null
	if _path.begins_with("%s/net_" % folder):
		var raw := FileAccess.get_file_as_bytes(_path)
		if raw.is_empty():
			DirAccess.remove_absolute(_path)
		else:
			Net.send_play_log("%s.gz" % _path.get_file(), raw.compress(FileAccess.COMPRESSION_GZIP), _path)


## Writes a line from anywhere in the game, when a world is being recorded. Costs nothing when none is.
static func event(text: String) -> void:
	if _active != null and _active._file != null:
		_active._line(text)


## What an AI wizard chose to cast and what each spell scored (called from `BrainCombat.attack`).
static func decision(wizard: Wizard, choice: String, scores: Dictionary, gap: float, sees: bool) -> void:
	if _active == null or _active._file == null:
		return
	var parts: Array[String] = []
	for spell_name: String in scores.keys():
		if float(scores[spell_name]) > 0.0:
			parts.append("%s:%.2f" % [spell_name.replace(" ", "_"), float(scores[spell_name])])
	_active._line("DEC %d %s %d %d %s" % [wizard.get_instance_id(), choice.replace(" ", "_") if choice != "" else "-", gap, 1 if sees else 0, ",".join(parts)])


## A wizard took a blow (called from `MatchStats.hit`): who struck it, with what, and how much.
static func blow(victim: Node, striker: Wizard, with_class: String, amount: float) -> void:
	if _active == null or _active._file == null or not victim is Wizard:
		return
	var v := victim as Wizard
	if with_class == "":
		with_class = _active._nearest_cause(v)
	_active._line("HIT %d %s %s %d %d %d %d" % [v.get_instance_id(), str(striker.get_instance_id()) if is_instance_valid(striker) else "-", with_class if with_class != "" else "-", amount, v.max_stamina, v.global_position.x, v.global_position.y])


## What most likely did a blow that nobody struck (a hazard, the ground): the nearest dangerous thing to the victim, or what the victim stands in.
func _nearest_cause(v: Wizard) -> String:
	var best := ""
	var best_gap := 170.0
	for wall: ClosingWalls in get_tree().get_nodes_in_group("danger").filter(func(n: Node) -> bool: return n is ClosingWalls):
		if v.global_position.x < wall.safe_left() or v.global_position.x > wall.safe_right():
			return "walls"
	for group in ["danger", "fires", "mobs", "projectiles", "clouds", "rocks", "lasting"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node) and node != v:
				var gap: float = (node as Node2D).global_position.distance_to(v.global_position + Vector2(0, -30))
				if gap < best_gap:
					best_gap = gap
					best = _class_of(node)
	if best != "":
		return "near:" + best
	return "open_ground" if v.is_on_floor() else "open_air"


func _process(delta: float) -> void:
	if _file == null:
		return
	_clock += delta
	_flush_in -= delta
	if _flush_in <= 0.0:
		_flush_in = 2.0
		_file.flush()
	_hook_new_wizards()
	_hand_in -= delta
	if _hand_in <= 0.0:
		_hand_in = HAND_GAP
		_hands()
	_wizard_in -= delta
	_shot_in -= delta
	_object_in -= delta
	_snap_in -= delta
	if _wizard_in <= 0.0:
		_wizard_in = WIZARD_GAP
		_wizards()
	if _shot_in <= 0.0:
		_shot_in = SHOT_GAP
		_shots()
	if _object_in <= 0.0:
		_object_in = OBJECT_GAP
		_objects()
	if _snap_in <= 0.0:
		_snap_in = SNAP_GAP
		_snap()
	_news()


## The person at this machine, if there is one: where the hand is and what it presses.
func _person() -> Wizard:
	var w := get_tree().get_first_node_in_group("player") as Wizard
	return w if is_instance_valid(w) and w.brain == null and not w.is_likeness() else null


func _hands() -> void:
	var w := _person()
	if w == null:
		return
	var mouse := w.get_global_mouse_position()
	_line("M %d %d" % [mouse.x, mouse.y])
	var view := w.get_node_or_null("Camera2D") as Camera2D
	var middle := view.get_screen_center_position() if view != null else w.global_position
	_line("S %d %d %d %d %s %d %d %d %s %d %d %.2f" % [w.global_position.x, w.global_position.y, w.velocity.x, w.velocity.y, "floor" if w.is_on_floor() else "air",
		w.stamina, w.max_stamina, 1 if w.pen.active() or w.casting else 0, String(w.shown_anim), middle.x, middle.y, view.zoom.x if view != null else 1.0])
	var buttons := (1 if Input.is_action_pressed("school_left") else 0) | (2 if Input.is_action_pressed("school_right") else 0) | (4 if Input.is_action_pressed("school_middle") else 0)
	_line("A %d %d %d" % [roundi(Input.get_axis("move_left", "move_right")), 1 if Input.is_action_pressed("jump") else 0, buttons])
	var box = arena.get("ritual")
	if box != null and box.typed() != _typed:
		_typed = box.typed()
		_line("R %s" % _typed)


func _input(event: InputEvent) -> void:
	if _file == null or _person() == null:
		return
	if event is InputEventKey and not event.echo:
		_line("K key %s %s" % [OS.get_keycode_string(event.physical_keycode), "down" if event.pressed else "up"])
	elif event is InputEventMouseButton:
		var at := _person().get_global_mouse_position()
		_line("K mouse %d %s %d,%d" % [event.button_index, "down" if event.pressed else "up", at.x, at.y])


func _hook_new_wizards() -> void:
	var person := _person()
	if person != null and not _person_hooked:  # a person's strokes go through the arena's own caster, not the wizard's
		_person_hooked = true
		var pid := person.get_instance_id()
		var hand = arena.get("caster")
		if hand is Caster:
			hand.cast_resolved.connect(func(spell: String, targeting: String, origin: Vector2, aim: float, _info: Dictionary) -> void:
				_line("CAST %d %s %s %d %d %.2f %d" % [pid, spell.replace(" ", "_"), targeting, origin.x, origin.y, aim, person.stamina if is_instance_valid(person) else 0]))
			hand.misfired.connect(func() -> void: _line("MISS %d" % pid))
		var box = arena.get("ritual")
		if box != null:
			box.finished.connect(func(ritual_id: String, accuracy: float, unfinished: bool) -> void:
				_line("SAY %d %s %.2f %d" % [pid, ritual_id.replace(" ", "_"), accuracy, 1 if unfinished else 0]))
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if not is_instance_valid(w) or _hooked.has(w.get_instance_id()):
			continue
		if w == person:  # (the person's own hooks are above; the wizard's caster is not theirs to use)
			_hooked[w.get_instance_id()] = true
			w.died.connect(func() -> void: _write_fall(w))
			continue
		_hooked[w.get_instance_id()] = true
		var id := w.get_instance_id()
		w.ensure_caster().cast_resolved.connect(func(spell: String, targeting: String, origin: Vector2, aim: float, _info: Dictionary) -> void:
			_line("CAST %d %s %s %d %d %.2f %d" % [id, spell.replace(" ", "_"), targeting, origin.x, origin.y, aim, w.stamina if is_instance_valid(w) else 0]))
		w.ensure_caster().misfired.connect(func() -> void: _line("MISS %d" % id))
		w.died.connect(func() -> void: _write_fall(w))


## The ground's outline, so that a replay can draw it: every 32 px tile of the world that is solid at its middle, written as runs along each row.
func _terrain() -> void:
	var ground = arena.call("ground") if arena.has_method("ground") else null
	if not ground is Terrain or ArenaGen.world_size.x <= 0:
		return
	var width := ArenaGen.world_size.x
	var height := ArenaGen.world_size.y
	_line("TERR %d %d" % [width, height])
	for y in height:
		var runs: Array[String] = []
		var start := -1
		for x in width + 1:
			var solid: bool = x < width and ground.solid_at(Vector2((x + 0.5) * ArenaGen.TILE, (y + 0.5) * ArenaGen.TILE))
			if solid and start < 0:
				start = x
			elif not solid and start >= 0:
				runs.append("%d-%d" % [start, x - 1])
				start = -1
		if not runs.is_empty():
			_line("TR %d %s" % [y, ",".join(runs)])


func _write_fall(w: Wizard) -> void:
	if not is_instance_valid(w) or _fallen.has(w.get_instance_id()):
		return
	_fallen[w.get_instance_id()] = true
	_line("FALL %d %d %d" % [w.get_instance_id(), w.global_position.x, w.global_position.y])


func _flags(w: Wizard) -> String:
	var out := ""
	if w.is_wet(): out += "W"
	if w.is_burning(): out += "B"
	if w.is_oiled(): out += "O"
	if w.is_frozen(): out += "F"
	if w.is_slowed(): out += "S"
	if w.asleep or w.fainted: out += "Z"
	if w.daze_time > 0.0: out += "D"
	if w.haste_time > 0.0: out += "H"
	if w.veil > 0: out += "V"
	if w.is_muted(): out += "M"
	if w.flying: out += "L"
	if w.pen.active() or w.casting: out += "P"  # drawing a spell
	if w.brain != null and w.brain.chant.typing != "": out += "C"  # typing a chant
	if w.brain != null and w.brain.settle > 0.0: out += "E"  # standing while a way over water grows
	if w.brain != null and w.brain.mend.resting: out += "R"
	if w.brain != null and w.brain.recharging: out += "G"  # holding its spells to get its stamina back
	return out if out != "" else "-"


func _wizards() -> void:
	for w: Wizard in get_tree().get_nodes_in_group("wizards"):
		if not is_instance_valid(w):
			continue
		var id := w.get_instance_id()
		var brain := w.brain
		var level: int = brain.level if brain != null else 0
		var goal := "-"
		var target := "-"
		var cooldown := 0.0
		var mind := ""
		if brain != null:
			mind = " %.2f %.2f %d" % [brain.strength, brain.caution(), 1 if brain.recharging else 0]
			goal = (brain.goal if brain.goal != "" else "none")
			target = str(brain.opponent.get_instance_id()) if is_instance_valid(brain.opponent) else "-"
			cooldown = brain.cast_cooldown
		_line("WZ %d %s %s %d %d %d %d %d %d %s %d %d %s %s %s %s %.1f%s" % [id, str(w.name).replace(" ", "_"), "brain" if brain != null else "person", level,
			w.global_position.x, w.global_position.y, w.velocity.x, w.velocity.y, w.facing, "floor" if w.is_on_floor() else "air", w.stamina, w.max_stamina,
			_flags(w), String(w.shown_anim), goal, target, cooldown, mind])
		var state_text := _state_text(w)
		if _states.get(id, "-") != state_text:
			_states[id] = state_text
			_line("ST %d %s" % [id, state_text])
		var book := _book_of(w)
		if _books.get(id, "") != book:
			_books[id] = book
			_line("BOOK %d %s" % [id, book])


## The states a wizard is in, as the status bubbles know them: hexed:6.2,wet:-1 (-1 is a state with no clock); the seconds left are not rewritten as they fall.
func _state_text(w: Wizard) -> String:
	if w.bubbles == null:
		return "-"
	var names: Array[String] = []
	var states: Dictionary = w.bubbles.states()
	for state: String in states.keys():
		names.append(state)
	names.sort()
	var out: Array[String] = []
	for state in names:
		out.append("%s:%.1f" % [state, float(states[state])])
	return ",".join(out) if not out.is_empty() else "-"


func _book_of(w: Wizard) -> String:
	var names: Array[String] = []
	for page: String in w.ledger.pages.keys():
		names.append(page.replace(" ", "_"))
	names.sort()
	return "|".join(names) if not names.is_empty() else "-"


func _shots() -> void:
	for group in SHOT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node):
				_line("OB %d %s %s %d %d" % [node.get_instance_id(), _class_of(node), _owner_of(node), node.global_position.x, node.global_position.y])


func _objects() -> void:
	for group in OBJECT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node) and not node.is_in_group("shots"):
				var extra := ""
				if node is Mob:
					extra = " %d" % (node as Mob).hp
				_line("OB %d %s %s %d %d%s" % [node.get_instance_id(), _class_of(node), _owner_of(node), node.global_position.x, node.global_position.y, extra])


func _snap() -> void:
	var seen := {}
	for group in ["lasting", "pages", "fires"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node) and not seen.has(node.get_instance_id()):
				seen[node.get_instance_id()] = true
				_line("SNAP %d %s %s %d %d" % [node.get_instance_id(), _class_of(node), _owner_of(node), node.global_position.x, node.global_position.y])


## Things that appear and go: written as they happen.
func _news() -> void:
	var now := {}
	for group in SHOT_GROUPS + OBJECT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node):
				var id := node.get_instance_id()
				now[id] = node
				if not _known.has(id):
					_known[id] = [_class_of(node), _owner_of(node), node.global_position]
					_line("NEW %d %s %s %d %d %s" % [id, _class_of(node), _owner_of(node), node.global_position.x, node.global_position.y, "shot" if node.is_in_group("shots") or node.is_in_group("projectiles") else "thing"])
	for id in _known.keys():
		if not now.has(id):
			var info: Array = _known[id]
			_line("GONE %d %s %s %d %d" % [id, info[0], info[1], info[2].x, info[2].y])
			_known.erase(id)
		elif is_instance_valid(now[id]):
			_known[id][2] = (now[id] as Node2D).global_position


func _owner_of(node: Node) -> String:
	var owner_wizard := MatchStats.owner_of(node)
	return str(owner_wizard.get_instance_id()) if owner_wizard != null else "-"


func _class_of(node: Node) -> String:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() != &"":
		return String(script.get_global_name())
	return node.get_class()


func _line(text: String) -> void:
	if _file != null:
		_file.store_line("%.2f %s" % [_clock, text])


## The folder is kept under the budget: the oldest files are removed first.
func _forget_old() -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	var files: Array = []
	var total := 0
	for name in dir.get_files():
		if not name.begins_with("match_"):
			continue
		var path := "%s/%s" % [folder, name]
		var size := _size_of(path)
		files.append([FileAccess.get_modified_time(path), path, size])
		total += size
	files.sort()
	var i := 0
	while total > BUDGET and i < files.size():
		DirAccess.remove_absolute(files[i][1])
		total -= int(files[i][2])
		i += 1


static func _size_of(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n
