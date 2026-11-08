class_name PlayRecorder
extends Node

## Records how a person plays, for comparing with the AI wizards: F9 starts it and stops it. It writes a file in the game's user folder
## (user://play_logs/) that holds the whole picture, not only the keys of the one playing. Lines (each starts with the seconds since F9):
##   START / WORLD   where the file is, the world and its biome
##   K    a key or mouse button went down or up (the mouse's place in the world, for buttons)
##   M    the mouse in the world, ten times a second
##   S    the wizard of the person, ten times a second: place, speed, on the ground or in the air, stamina, maximum, drawing, pages, animation
##   G    the ground about the wizard (how many pixels below the feet, every 64 px sideways) twice a second
##   W    every other wizard near, four times a second: name, who plays it, place from the person, stamina, maximum, wolf, state, last spell
##   E    everything else near, four times a second: creatures, spells in the world, pages and fires, as a class and a place from the person
##   X    a spell or anything else new in the world, with the wizard who made it and the place it was made
##   C    the last spell of the person changed; R the chant words as they are typed
##   D    the person was hurt: how much, and everything within reach that could have done it
##   N    a wizard fell, and who and what was near
const STATE_GAP := 0.1
const NEAR_GAP := 0.25
const GROUND_GAP := 0.5
const SEE := 900.0
const HURT_REACH := 170.0
const GROUPS := ["mobs", "projectiles", "danger", "fires", "pages", "lasting", "clouds", "rocks"]

var wizard: Wizard
var ritual: RitualInput
var arena: Node  # the world being played now
var _flush_in := 2.0
var _file: FileAccess
var _clock := 0.0
var _state_in := 0.0
var _mouse_in := 0.0
var _near_in := 0.0
var _ground_in := 0.0
var _spell := ""
var _typed := ""
var _seen := {}  # instance id -> true, for what has already been written as new
var _fallen := {}


## Hands the recording to the world now being played. The recorder lives on the tree's root, so that one recording runs through every world of a
## match (and the waiting room, and the next match) until F9 is pressed again.
static func attach(to_arena: Node, person: Wizard, box: RitualInput) -> void:
	var root := to_arena.get_tree().root
	var recorder: PlayRecorder = root.get_node_or_null("PlayRecorder")
	if recorder == null:
		recorder = PlayRecorder.new()
		recorder.name = "PlayRecorder"
		recorder.arena = to_arena
		recorder.wizard = person
		recorder.ritual = box
		root.add_child.call_deferred(recorder)  # (the root is busy while a scene is being set up)
		return
	recorder.rebind(to_arena, person, box)


func rebind(to_arena: Node, person: Wizard, box: RitualInput) -> void:
	arena = to_arena
	wizard = person
	ritual = box
	_spell = ""
	if _file != null:
		_start_world()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_toggle()
		return
	if _file == null:
		return
	if event is InputEventKey and not event.echo:
		_line("K key %s %s" % [OS.get_keycode_string(event.physical_keycode), "down" if event.pressed else "up"])
	elif event is InputEventMouseButton:
		_line("K mouse %d %s %d,%d" % [event.button_index, "down" if event.pressed else "up", _world_mouse().x, _world_mouse().y])


func _process(delta: float) -> void:
	if _file == null or not is_instance_valid(wizard):
		return
	_clock += delta
	_flush_in -= delta
	if _flush_in <= 0.0:
		_flush_in = 2.0
		_file.flush()  # (a recording that is cut short keeps what it had)
	_state_in -= delta
	_mouse_in -= delta
	_near_in -= delta
	_ground_in -= delta
	if _mouse_in <= 0.0:
		_mouse_in = STATE_GAP
		_line("M %d %d" % [_world_mouse().x, _world_mouse().y])
	if ritual != null and ritual.typed() != _typed:
		_typed = ritual.typed()
		_line("R %s" % _typed)
	if wizard.last_spell != _spell:
		_spell = wizard.last_spell
		_line("C %s" % _spell)
	if _state_in <= 0.0:
		_state_in = STATE_GAP
		_news()
		_line("S %d %d %d %d %s %d %d %d %d %s" % [wizard.global_position.x, wizard.global_position.y, wizard.velocity.x, wizard.velocity.y,
			"floor" if wizard.is_on_floor() else "air", wizard.stamina, wizard.max_stamina, 1 if wizard.is_drawing() or wizard.casting else 0,
			wizard.ledger.count(), String(wizard.shown_anim)])
	if _ground_in <= 0.0:
		_ground_in = GROUND_GAP
		_ground()
	if _near_in <= 0.0:
		_near_in = NEAR_GAP
		_near()


## How far down the ground lies from a height just over the feet, at steps either side ("x" where there is none).
func _ground() -> void:
	var out := PackedStringArray()
	for step in range(-6, 7):
		var from := wizard.global_position + Vector2(step * 64.0, -90.0)
		var hit := SpellTargets.ground_below(wizard.get_world_2d(), from, 500.0)
		out.append("%d" % (hit.y - wizard.global_position.y) if hit.y > from.y + 1.0 and hit.y < from.y + 499.0 else "x")
	_line("G " + " ".join(out))


func _near() -> void:
	for other: Wizard in SpellTargets.wizards(get_tree()):
		if other == wizard or not is_instance_valid(other):
			continue
		var off := other.global_position - wizard.global_position
		if other.dead and not _fallen.has(other.get_instance_id()):
			_fallen[other.get_instance_id()] = true
			_line("N %s fell %s" % [other.name, _near_text(other.global_position, HURT_REACH * 1.5, other)])
		if off.length() > SEE * 1.6 or other.dead:
			continue
		_line("W %s %s %d %d %d %d %s %s %s" % [other.name, "person" if other.brain == null else "brain", off.x, off.y, other.stamina, other.max_stamina,
			"wolf" if other.wild else "-", "faint" if other.fainted else "-", str(other.last_spell).replace(" ", "_")])
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node):
				var off: Vector2 = node.global_position - wizard.global_position
				if off.length() < SEE:
					_line("E %s %s %d %d%s" % [group, _class_of(node), off.x, off.y, _owner_of(node)])


## Anything new in the world since the last look: a spell cast by someone, a creature, a page.
func _news() -> void:
	for node in arena.get_children():
		var id := node.get_instance_id()
		if _seen.has(id) or not node is Node2D or node == wizard:
			continue
		_seen[id] = true
		if node is Wizard:
			continue
		var at: Vector2 = node.global_position - wizard.global_position
		_line("X %s %d %d%s" % [_class_of(node), at.x, at.y, _owner_of(node)])
	if _seen.size() > 4000:
		_seen.clear()


func _owner_of(node: Node) -> String:
	if node.has_meta("caster") and is_instance_valid(node.get_meta("caster")):
		return " by:" + str(node.get_meta("caster").name)
	if "caster" in node and node.caster is Wizard and is_instance_valid(node.caster):
		return " by:" + str(node.caster.name)
	return ""


func _class_of(node: Node) -> String:
	var script: Script = node.get_script()
	var named := script.get_global_name() if script != null else &""
	return String(named) if named != &"" else node.get_class()


## What is near a place, as text: who and what could have done it.
func _near_text(at: Vector2, reach: float, skip: Node) -> String:
	var out := PackedStringArray()
	for other: Wizard in SpellTargets.wizards(get_tree()):
		if other != skip and is_instance_valid(other) and not other.dead and other.global_position.distance_to(at) < reach * 1.6:
			out.append("%s%s@%d,%d" % [other.name, "(wolf)" if other.wild else "", other.global_position.x - at.x, other.global_position.y - at.y])
	for group in GROUPS:
		if group == "pages":
			continue
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and node != skip and is_instance_valid(node) and node.global_position.distance_to(at) < reach:
				out.append("%s%s@%d,%d" % [_class_of(node), _owner_of(node), node.global_position.x - at.x, node.global_position.y - at.y])
	return " ".join(out) if not out.is_empty() else "nothing_near"


func _world_mouse() -> Vector2:
	return wizard.get_global_mouse_position() if is_instance_valid(wizard) else Vector2.ZERO


func _toggle() -> void:
	if _file == null and arena == null:
		return
	if _file != null:
		_line("END")
		_file.close()
		_file = null
		print("play recording stopped")
		return
	DirAccess.make_dir_recursive_absolute("user://play_logs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open("user://play_logs/play_%s.log" % stamp, FileAccess.WRITE)
	_clock = 0.0
	_spell = ""
	_line("START %s" % ProjectSettings.globalize_path("user://play_logs"))
	_start_world()
	print("play recording started: ", ProjectSettings.globalize_path("user://play_logs"))


## Notes the world being played, and starts looking at it afresh.
func _start_world() -> void:
	_seen.clear()
	_fallen.clear()
	_typed = ""
	for node in arena.get_children():
		_seen[node.get_instance_id()] = true  # (what is already there is not news)
	if is_instance_valid(wizard) and not wizard.damaged.is_connected(_on_hurt):
		wizard.damaged.connect(_on_hurt)
	_line("WORLD %s biome %s" % [arena.name, str(arena.get("grade_biome"))])


func _on_hurt(amount: int) -> void:
	_line("D %d %s" % [amount, _near_text(wizard.global_position + Vector2(0, -40), HURT_REACH, wizard)])


func _line(text: String) -> void:
	if _file != null:
		_file.store_line("%.2f %s" % [_clock, text])
