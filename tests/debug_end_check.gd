extends Node

## The F1 panel's Win game and Lose game buttons end the match for real: every other wizard falls and the match is won, or the person falls and the stats come up.
##
##     godot --headless --fixed-fps 60 --path . tests/debug_end_check.tscn -- mode=win      (or mode=lose; `out=DIR` takes a picture, needs a window)
## Prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var mode := "win"
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):
			mode = arg.get_slice("=", 1)
		elif arg.begins_with("out="):
			out = arg.get_slice("=", 1)
	Library.force = true  # the match goes into a library of its own, to see that the Chronicle takes it
	Library.use_file("user://library_end_test.json")
	Library.clear()
	MatchState.hurry = 1.0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 11
	await get_tree().process_frame
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	while not (get_tree().current_scene is World and get_tree().current_scene.nav != null):
		await get_tree().process_frame
	var world: World = get_tree().current_scene
	await get_tree().create_timer(3.0).timeout
	var buttons := _buttons_of(world.debug_panel)
	_verdict(buttons.has("Win game") and buttons.has("Lose game"), "the F1 panel has a Win game and a Lose game button")
	world.debug_panel.visible = true
	buttons["Win game" if mode == "win" else "Lose game"].pressed.emit()
	await get_tree().create_timer(2.0).timeout
	_verdict(not world.debug_panel.visible, "the panel is put away")
	if mode == "win":
		_verdict(world._living().is_empty() and not world.player.dead, "every other wizard has fallen and the person stands (%d left)" % world._living().size())
		_verdict(world._won, "the match is won")
		var at_win := MatchStats.seconds
		await get_tree().create_timer(1.0).timeout
		_verdict(MatchStats.finished and is_equal_approx(MatchStats.seconds, at_win), "the clock stops when the match is won (%.1f s, then %.1f s)" % [at_win, MatchStats.seconds])
		await get_tree().create_timer(World.STATS_AFTER + 1.0).timeout
		_verdict(world._stats != null and world._stats.visible and world._stats.placement == 1, "a few seconds on, the stats come up on their own, in first place")
		_verdict(not world.hud.get_node("StatsButton").visible, "and the crystal ball is not offered: the match is over")
		world._epilogue_when_stats_are_away(world.player.look, world.player.palette)
		await get_tree().create_timer(0.2).timeout
		_verdict(not world._leaving, "the ending waits while the stats are open")
		world._stats._close()
		world._epilogue_when_stats_are_away(world.player.look, world.player.palette)
		await get_tree().create_timer(0.2).timeout
		_verdict(world._leaving, "and goes on once they are put away")
	else:
		_verdict(world.player.dead, "the person has fallen")
		_verdict(world._stats != null and world._stats.visible and world._stats.placement == World.WIZARDS, "and the stats come up, in last place (#%s)" % (world._stats.placement if world._stats != null else "?"))
	var told := Library.history()
	var want := 1 if mode == "win" else World.WIZARDS
	_verdict(told.size() == 1 and int(told[0]["place"]) == want and int(told[0]["field"]) == World.WIZARDS and not (told[0]["worlds"] as Array).is_empty() and int(told[0]["seconds"]) > 0,
			"the Chronicle took the match once, placed %d of the field (%s)" % [want, str(told)])
	Library.clear()
	Library.use_file(Library.PATH)
	Library.force = false
	if out != "":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out.path_join("end_%s.png" % mode))
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _buttons_of(node: Node) -> Dictionary:
	var found := {}
	for child in node.get_children():
		if child is Button:
			found[child.text] = child
		found.merge(_buttons_of(child))
	return found


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
