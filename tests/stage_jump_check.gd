extends Node

## The F1 panel's way to a world of the match: from the first world, jumps to the third, then back to the first, and checks each lands in
## the world of that stage with its biome.
##
##     godot --headless --fixed-fps 60 --path . tests/stage_jump_check.tscn

var _jumps := [2, 0]
var _arrived := 0
var _failures := 0
var _last: World
var _clock := 0.0


func _ready() -> void:
	MatchState.hurry = 0.0001  # no collapse of its own
	World.random_start = false
	World.next_seed = 11
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _process(delta: float) -> void:
	_clock += delta
	var scene := get_tree().current_scene
	if scene is World and scene != _last and scene.player != null and scene.ledgers.size() > 0 and scene.nav != null:
		_last = scene
		if _arrived > 0:
			var want: int = _jumps[_arrived - 1]
			_verdict(MatchState.stage == want, "landed in stage %d (%d)" % [want, MatchState.stage])
			_verdict(scene.graph.surface["biomes"][0]["name"] == MatchState.biome_of(want), "in its biome (%s)" % scene.graph.surface["biomes"][0]["name"])
		if _arrived == _jumps.size():
			_finish()
		else:
			scene.go_to_stage(_jumps[_arrived])
			_arrived += 1
	if _clock > 90.0:
		_verdict(false, "stuck")
		_finish()


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("jumps between worlds work" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
