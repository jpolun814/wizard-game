extends Node

## TEMPORARY measuring tool (not part of the game): plays one whole match of AI wizards, as match_stats does, and writes every cast,
## every blow (with whose blow it was) and every fall (with who felled them) to a file, for studying what decides fights.
##
##     godot --headless --fixed-fps 60 --path . tests/tools/fight_census.tscn -- seed=3 out=FILE
## Lines: W world biome | C t who spell stamina max | D t victim amount striker | K t victim killer | R winner

const LIMIT := 1500.0

var _seed := 3
var _clock := 0.0
var _world: World
var _out: FileAccess
var _done := false


func _ready() -> void:
	var path := "census.txt"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			_seed = int(argument.trim_prefix("seed="))
		elif argument.begins_with("out="):
			path = argument.trim_prefix("out=")
	_out = FileAccess.open(path, FileAccess.WRITE)
	if _out == null:
		push_error("cannot write " + path)
		get_tree().quit(2)
		return
	seed(_seed)
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = _seed
	call_deferred("_start")


func _line(text: String) -> void:
	_out.store_line(text)
	_out.flush()


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(delta: float) -> void:
	if _done:
		return
	if int(_clock / 60.0) != int((_clock + delta) / 60.0):
		print("t=%.0f standing=%d" % [_clock + delta, _standing().size() if _world != null and is_instance_valid(_world) else -1])
	_clock += delta
	var scene := get_tree().current_scene
	if scene is World and scene != _world and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_arrived(scene)
	if _world == null or not is_instance_valid(_world) or _world.leaving:
		return
	var standing := _standing()
	if standing.size() <= 1 or _clock > LIMIT:
		_done = true
		_line("R %s" % (String(standing[0].name) if standing.size() == 1 else "-"))
		_out.close()
		get_tree().quit(0)


func _arrived(world: World) -> void:
	_world = world
	world.player.dead = true
	world._on_player_died()
	_line("W %.2f %s" % [_clock, MatchState.biome_of(MatchState.stage)])
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == world.player:
			continue
		var who := String(wizard.name)
		if wizard.caster != null:
			wizard.caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void:
				_line("C %.2f %s %s %d %d" % [_clock, who, spell.replace(" ", "_"), wizard.stamina, wizard.max_stamina]))
		wizard.damaged.connect(func(amount: int) -> void:
			_line("D %.2f %s %d %s" % [_clock, who, amount, _striker()]))
		wizard.died.connect(func() -> void:
			_line("K %.2f %s %s" % [_clock, who, _striker()]))


## Whose blow is landing right now (MatchStats keeps it while a blow lands).
func _striker() -> String:
	var by: Variant = MatchStats._by
	if by is Wizard and is_instance_valid(by):
		return String(by.name)
	return "-"


func _standing() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != _world.player and is_instance_valid(wizard) and not wizard.dead:
			out.append(wizard)
	return out
