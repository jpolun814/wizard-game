extends Node

## Plays one whole match of AI wizards alone (the player's wizard stands down), at the real times, through every collapse, and prints what
## it shows about the game's pacing and its balance, one line each, so that several seeds can be put side by side:
##
##     godot --headless --fixed-fps 60 --path . tests/match_stats.tscn -- seed=3
## Per world: how long it lasted, who fell and when, how often the nearest two wizards were within a fight's reach, how much of the time a
## wizard stood still (camping), and the pages lying on the map at the start and the end. At the end: the winner, and how the winner
## ranked among the wizards by pages held and by spells cast (the answer to "does the winner win by fighting, or by finding pages?").
## It prints a line beginning RESULT with the numbers a summary needs. Exits with code 1 if the match never ends.

const SAMPLE := 0.5            # seconds between looks at the wizards
const FIGHT_REACH := 500.0     # two wizards this close are in a fight's reach
const STILL_SPEED := 8.0       # a wizard slower than this is standing still
const LIMIT := 1500.0          # seconds of play after which the match is given up on

var _seed := 3
var _clock := 0.0
var _since_sample := 0.0
var _world: World
var _worlds := 0
var _world_start := 0.0
var _first_blood := -1.0      # seconds into the match when the first wizard fell
var _falls: Array[Dictionary] = []   # {"who", "at": match seconds, "world", "in_world": seconds into that world}
var _samples := 0
var _near_samples := 0
var _still_samples := 0
var _world_rows: Array[Dictionary] = []
var _pages_at_first_collapse := {}   # wizard name -> pages held when the first world collapsed
var _casts := {}              # wizard name -> spells cast
var _max_pages := {}
var _winner := ""
var _done := false
var _closed := false         # this world's numbers have been written down


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			_seed = int(argument.trim_prefix("seed="))
	seed(_seed)
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = _seed
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)  # this node outlives the scenes that come and go
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(delta: float) -> void:
	if _done:
		return
	_clock += delta
	var scene := get_tree().current_scene
	if scene is World and scene != _world and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_arrived(scene)
	if _world == null or not is_instance_valid(_world):
		return
	_since_sample += delta
	if _since_sample >= SAMPLE:
		_since_sample = 0.0
		_look()
	if _world._leaving:  # the portal is giving way: everyone is on their way to the next world
		if not _closed:
			_closed = true
			_close_world(true)
		return
	var standing := _standing()
	if standing.size() <= 1 or _clock > LIMIT:
		_finish(standing)


func _arrived(world: World) -> void:
	_closed = false
	_world = world
	_worlds += 1
	_world_start = _clock
	_samples = 0
	_near_samples = 0
	_still_samples = 0
	world.player.dead = true  # a wizard that is down is no one's target, and the world goes on without them (the portal's clock runs while they watch)
	world._on_player_died()
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard == world.player:
			continue
		wizard.died.connect(_fell.bind(wizard))
	_world_rows.append({"pages_start": get_tree().get_nodes_in_group("pages").size(), "biome": MatchState.biome_of(MatchState.stage)})


func _fell(wizard: Wizard) -> void:
	if _first_blood < 0.0:
		_first_blood = _clock
	_falls.append({"who": wizard.look, "at": _clock, "world": _worlds, "in_world": _clock - _world_start})


func _standing() -> Array[Wizard]:
	var out: Array[Wizard] = []
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if wizard != _world.player and is_instance_valid(wizard) and not wizard.dead:
			out.append(wizard)
	return out


func _look() -> void:
	var standing := _standing()
	var row: Dictionary = _world_rows[_world_rows.size() - 1]
	var lying := get_tree().get_nodes_in_group("pages").size()
	if not row.has("t_half") and lying * 2 <= row["pages_start"]:
		row["t_half"] = _clock - _world_start  # when half the pages were gone
	if not row.has("t_empty") and lying == 0:
		row["t_empty"] = _clock - _world_start
	for wizard in standing:
		var key: String = wizard.look
		_max_pages[key] = maxi(_max_pages.get(key, 0), wizard.ledger.count())
		_casts[key] = maxi(_casts.get(key, 0), wizard.casts_made)
		_samples += 1
		if wizard.velocity.length() < STILL_SPEED:
			_still_samples += 1
	if standing.size() >= 2:
		var nearest := INF
		for a in standing:
			for b in standing:
				if a != b:
					nearest = minf(nearest, a.center().distance_to(b.center()))
		if nearest < FIGHT_REACH:
			_near_samples += 1


func _close_world(collapsed: bool) -> void:
	var row: Dictionary = _world_rows[_world_rows.size() - 1]
	row["seconds"] = _clock - _world_start
	row["fights"] = float(_near_samples) / maxf(float(_samples) / maxf(float(_standing_count_hint()), 1.0), 1.0)
	row["still"] = float(_still_samples) / maxf(float(_samples), 1.0)
	row["pages_end"] = get_tree().get_nodes_in_group("pages").size()
	row["falls"] = _falls.filter(func(f: Dictionary) -> bool: return f["world"] == _worlds).size()
	if collapsed and _worlds == 1:
		for wizard: Wizard in _standing():
			_pages_at_first_collapse[wizard.look] = wizard.ledger.count()


func _standing_count_hint() -> int:
	return maxi(_standing().size(), 1)


func _finish(standing: Array[Wizard]) -> void:
	_done = true
	if _world != null and is_instance_valid(_world) and not _closed:
		_close_world(false)
	if standing.size() == 1:
		_winner = standing[0].look
	print("--- seed %d: %d worlds, %.0f seconds, %s" % [_seed, _worlds, _clock, ("won by " + _winner) if _winner != "" else "no winner (%d standing)" % standing.size()])
	for k in _world_rows.size():
		var row: Dictionary = _world_rows[k]
		print("    world %d (%s): %.0fs; %d falls; %.0f%% of looks had two wizards within reach of each other; %.0f%% of wizard-looks were standing still; pages lying %d -> %d (half gone at %.0fs, all gone at %.0fs)" % [k + 1, row["biome"], row.get("seconds", 0.0), row.get("falls", 0), row.get("fights", 0.0) * 100.0, row.get("still", 0.0) * 100.0, row["pages_start"], row.get("pages_end", 0), row.get("t_half", -1.0), row.get("t_empty", -1.0)])
	for fall: Dictionary in _falls:
		print("    %s fell at %.0fs (%.0fs into world %d)" % [fall["who"], fall["at"], fall["in_world"], fall["world"]])
	var winner_pages_rank := -1
	var winner_casts_rank := -1
	if _winner != "":
		winner_pages_rank = _rank(_max_pages, _winner)
		winner_casts_rank = _rank(_casts, _winner)
	print("    most pages held: %s; spells cast: %s; pages when the first world collapsed: %s" % [str(_max_pages), str(_casts), str(_pages_at_first_collapse)])
	print("RESULT seed=%d worlds=%d seconds=%.0f first_fall=%.0f winner=%s pages_rank=%d casts_rank=%d falls=%d" % [_seed, _worlds, _clock, _first_blood, _winner, winner_pages_rank, winner_casts_rank, _falls.size()])
	get_tree().quit(0 if _winner != "" or standing.size() <= 1 else 1)


## 1 for the one with the most among those listed, 2 for the next.
func _rank(table: Dictionary, who: String) -> int:
	var better := 0
	for other: String in table:
		if other != who and table[other] > table.get(who, 0):
			better += 1
	return better + 1
