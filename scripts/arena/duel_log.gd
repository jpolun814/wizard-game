class_name DuelLog
extends Node

## Writes down one round of a Duel in detail, so the way a person fights and dodges can be read afterwards and set against the AI's. One file a round, in
## user://duel_logs/. Lines (each begins with the seconds since the round began):
##   ROUND n seed level / BOOK who pages     at the start
##   P who x y vx vy stamina max drawing floor [mx my | brain status]   both wizards, twenty times a second; the person's line ends with the mouse in the world,
##                                                                     the AI's with what its brain is doing
##   F owner class x y                       every shot in the world, twenty times a second (owner: person, ai or -)
##   C who spell                             a spell went off (M person: a stroke that matched nothing)
##   H who amount from...                    a wizard was hurt, with every shot and spell within reach of it then (class, owner, place from the one hurt)
##   END winner                              who won the round

const GAP := 0.05
const REACH := 140.0
static var folder := "user://duel_logs"  # (a check writes its rounds elsewhere, so they are never taken for a person's)

var _file: FileAccess
var _person: Wizard
var _ai: Wizard
var _clock := 0.0
var _next := 0.0
var _done := false
var _flush_in := 1.0


func begin(arena: Arena, person: Wizard, ai: Wizard, round_number: int, seed_value: int, level: int) -> void:
	_person = person
	_ai = ai
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open("%s/duel_%s_r%d.log" % [folder, stamp, round_number], FileAccess.WRITE)
	if _file == null:
		return
	_line("ROUND %d %d %d" % [round_number, seed_value, level])
	_line("BOOK person %s" % _book(person))
	_line("BOOK ai %s" % _book(ai))
	arena.caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _line("C person %s" % spell.replace(" ", "_")))
	arena.caster.misfired.connect(func() -> void: _line("M person"))
	ai.ensure_caster().cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _line("C ai %s" % spell.replace(" ", "_")))
	person.damaged.connect(_hurt.bind(person))
	ai.damaged.connect(_hurt.bind(ai))


func _book(wizard: Wizard) -> String:
	var names: Array[String] = []
	for page: String in wizard.ledger.pages.keys():
		names.append(page.replace(" ", "_"))
	return "|".join(names)


func _physics_process(delta: float) -> void:
	if _file == null or _done:
		return
	_clock += delta
	_flush_in -= delta
	if _flush_in <= 0.0:
		_flush_in = 1.0
		_file.flush()  # (so a round cut short, or read while it goes on, is all there)
	if _clock < _next:
		return
	_next = _clock + GAP
	for who in [["person", _person], ["ai", _ai]]:
		var w: Wizard = who[1]
		if not is_instance_valid(w) or w.dead:
			continue
		var tail := ""
		if w == _person:
			var mouse := w.get_global_mouse_position()
			tail = "%d %d" % [mouse.x, mouse.y]
		elif w.brain != null:
			tail = str(w.brain.status()).replace(" ", "_")
		_line("P %s %d %d %d %d %d %d %d %d %s" % [who[0], w.global_position.x, w.global_position.y, w.velocity.x, w.velocity.y, w.stamina, w.max_stamina,
			1 if w.pen.active() else 0, 1 if w.is_on_floor() else 0, tail])
	for shot in get_tree().get_nodes_in_group("shots"):
		if shot is Node2D and is_instance_valid(shot):
			_line("F %s %s %d %d" % [_owner(shot), _class(shot), shot.global_position.x, shot.global_position.y])


func _hurt(amount: int, victim: Wizard) -> void:
	var near := PackedStringArray()
	for group in ["shots", "danger", "fires", "lasting", "rocks"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_instance_valid(node) and node != victim and node.global_position.distance_to(victim.global_position) < REACH:
				var entry := "%s:%s@%d,%d" % [_class(node), _owner(node), node.global_position.x - victim.global_position.x, node.global_position.y - victim.global_position.y]
				if not near.has(entry):
					near.append(entry)
	_line("H %s %d %s" % ["person" if victim == _person else "ai", amount, " ".join(near) if not near.is_empty() else "-"])


func _owner(node: Node) -> String:
	var by: Variant = node.get("caster")
	if by == null:
		by = node.get("_shooter")
	if by == _person:
		return "person"
	if by == _ai:
		return "ai"
	return "-"


func _class(node: Node) -> String:
	var script: Script = node.get_script()
	return str(script.get_global_name()) if script != null and str(script.get_global_name()) != "" else node.get_class()


func finish(winner: String) -> void:
	if _file == null or _done:
		return
	_line("END %s" % winner)
	_done = true
	_file.close()
	_file = null


func _exit_tree() -> void:
	if _file != null and not _done:
		_line("END left")
		_done = true
		_file.close()
		_file = null


func _line(text: String) -> void:
	if _file != null:
		_file.store_line("%.2f %s" % [_clock, text])
