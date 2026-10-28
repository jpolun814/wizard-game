extends Node

## The player is struck down while rivals live: the match goes on, the camera follows a living wizard, a click picks the next, the portal still
## collapses into the next world, and only when no rival is left does the game-over screen come.
##
##     godot --headless --path . --fixed-fps 60 tests/spectate_check.tscn [-- collapse]
## With collapse it ends by waiting for the portal to give way, instead of beating the last rivals.
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World


func _ready() -> void:
	MatchState.hurry = 0.05 if OS.get_cmdline_user_args().has("collapse") else 1.0
	World.random_start = false
	World.next_seed = 11
	await get_tree().process_frame
	reparent(get_tree().root)  # this node outlives the scenes that come and go
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	while not (get_tree().current_scene is World and get_tree().current_scene.nav != null):
		await get_tree().process_frame
	_world = get_tree().current_scene
	await get_tree().process_frame
	var tree := get_tree()
	var player := _world.player
	player.take_damage(100000)
	await get_tree().create_timer(1.0).timeout
	_verdict(player.dead, "the player is dead")
	_verdict(not _world.hud.is_game_over(), "no game-over screen while rivals live")
	var living := _world._living()
	_verdict(living.size() == 3, "three rivals live (%d)" % living.size())
	_verdict(player.global_position.distance_to(living[0].global_position) < 40.0, "the camera follows the first rival")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	_world._unhandled_input(click)
	await get_tree().create_timer(0.3).timeout
	_verdict(player.global_position.distance_to(living[1].global_position) < 40.0, "a click moves to the next rival")
	living[1].take_damage(100000)
	await get_tree().create_timer(1.0).timeout
	_verdict(_world._living().size() == 2, "a beaten rival is no longer watched")
	_verdict(not _world.hud.is_game_over(), "still no game-over screen with two left")
	var hint_ok := true
	for page in get_tree().get_nodes_in_group("pages"):
		if page.is_underfoot():
			hint_ok = false
	_verdict(hint_ok, "a page offers nothing to the dead player")
	if OS.get_cmdline_user_args().has("collapse"):
		var frames := 0
		while not _world._leaving and frames < 3000:  # the portal gives way
			await get_tree().process_frame
			frames += 1
		_verdict(_world._leaving, "the portal still collapses while the player watches")
		var next: World = null
		frames = 0
		while next == null and frames < 3000:
			await tree.process_frame
			frames += 1
			var scene := tree.current_scene
			if scene is World and scene != _world and scene.player != null and scene.nav != null:
				next = scene
		_verdict(next != null, "the next world loads")
		if next != null:
			await tree.create_timer(1.0).timeout
			_verdict(next.player.dead and not next.hud.is_game_over(), "the player is still out in the next world, and watching")
			var seen: Array[Mob] = next._living()
			_verdict(seen.size() == 2 and next.player.global_position.distance_to(seen[0].global_position) < 40.0, "the camera follows a rival there (%d live)" % seen.size())
		print("spectating works" if _failures == 0 else "%d FAILED" % _failures)
		tree.quit(1 if _failures > 0 else 0)
		return
	for rival in _world._living():
		rival.take_damage(100000)
	await get_tree().create_timer(1.0).timeout
	_verdict(_world.hud.is_game_over() or _world._leaving, "the game ends when the last rival falls")
	print("spectating works" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
