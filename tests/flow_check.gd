extends Node

## Walks the whole way into a run: the waiting room, its portal, the cut-scene (skipped with a key), the loading screen and the world. Checks each
## scene in turn and that the world is dealt four wizards' pages.
##
##     godot --headless --path . tests/flow_check.tscn
## It prints PASS or FAIL for each step and exits with code 1 if any failed.

var _stage := "lab"
var _clock := 0.0
var _stage_clock := 0.0
var _failures := 0
var _pressed := false


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	reparent(get_tree().root)  # this node outlives the scenes that come and go
	get_tree().current_scene = null  # so changing the scene does not free it
	get_tree().change_scene_to_file("res://scenes/lab.tscn")


func _process(delta: float) -> void:
	_clock += delta
	_stage_clock += delta
	var scene := get_tree().current_scene
	match _stage:
		"lab":
			if scene is Lab and scene.player != null and scene._portal != null and _stage_clock > 1.0:
				_verdict(true, "the waiting room opens with its portal")
				scene.player.global_position = scene._portal.global_position + Vector2(0.0, Portal.RY)
				_next("intro")
		"intro":
			if scene is Intro:
				_verdict(true, "the portal leads to the cut-scene after %.1fs" % _stage_clock)
				_next("skip")
		"skip":
			if _stage_clock > 1.5 and not _pressed:
				_pressed = true
				var key := InputEventKey.new()
				key.keycode = KEY_SPACE
				key.physical_keycode = KEY_SPACE
				key.pressed = true
				Input.parse_input_event(key)
			if scene is Loading:
				_verdict(true, "a key skips the cut-scene and the loading screen follows")
				_next("world")
		"world":
			if scene is World and scene.player != null and scene.ledgers.size() > 0:
				_verdict(scene.ledgers.size() == 4, "the world deals four wizards their pages (%d)" % scene.ledgers.size())
				_verdict(scene.player.ledger == scene.ledgers[0] and not scene.player.ledger.everything, "the player holds the first ledger and not every page")
				_verdict(get_tree().get_nodes_in_group("pages").size() > 25, "pages lie on the map (%d)" % get_tree().get_nodes_in_group("pages").size())
				_finish()
	var limits := {"lab": 30.0, "intro": 20.0, "skip": 20.0, "world": 120.0}
	if _stage_clock > limits.get(_stage, 30.0):
		_verdict(false, "stuck in the '%s' stage (current scene: %s)" % [_stage, scene.name if scene else "none"])
		_finish()


func _next(stage: String) -> void:
	_stage = stage
	_stage_clock = 0.0


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("the whole way in works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
