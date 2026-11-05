extends Node

## The stats screen shown when the person falls: the counts MatchStats keeps (damage dealt and taken, casts, misses, spells learned, kills), the charts built
## from them, and the overlay that comes up over the world while the match goes on for the others.
##
##     godot --headless --fixed-fps 60 --path . tests/stats_check.tscn [-- out=DIR]      (a picture needs a window)
## Prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _world: World


func _ready() -> void:
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
	_world = get_tree().current_scene
	await get_tree().process_frame
	var player := _world.player
	player.ledger.learn_all()
	await get_tree().create_timer(5.0).timeout
	_verdict(MatchStats.seconds > 4.0, "the clock runs (%.1f s)" % MatchStats.seconds)
	_verdict(MatchStats.series.size() >= 2, "a point is added to the charts now and then (%d)" % MatchStats.series.size())
	_verdict(MatchStats.pages_known() > SpellData.SPELLS.size(), "spells and incantations are both counted as learned (%d)" % MatchStats.pages_known())
	# A spell cast, a stroke that matched nothing, a blow dealt to a rival and a blow taken.
	_world.cast_by("Ignite", "directional", player.center(), 0.0, {"length": 90.0, "accuracy": 0.9}, player)
	_verdict(MatchStats.casts == 1 and MatchStats.cast_by_spell.get("Ignite", 0) == 1, "a cast is counted by spell (%d)" % MatchStats.casts)
	MatchStats.miss()
	_verdict(MatchStats.misses == 1, "a miss is counted")
	var rival: Wizard = _world._living()[0]
	var before := MatchStats.dealt
	SpellTargets.hurt(rival, 10.0, "Fire", false, false, player)
	_verdict(MatchStats.dealt > before, "a blow dealt to a rival is counted (%.0f)" % (MatchStats.dealt - before))
	var taken := MatchStats.taken
	SpellTargets.hurt(player, 7.0, "Fire", false, false, rival)
	_verdict(MatchStats.taken > taken, "a blow taken is counted (%.0f)" % (MatchStats.taken - taken))
	await get_tree().create_timer(1.5).timeout  # (a wizard just struck cannot be struck again at once)
	var kills := MatchStats.kills
	SpellTargets.hurt(rival, 100000.0, "Fire", false, false, player)
	await get_tree().create_timer(0.5).timeout
	_verdict(MatchStats.kills == kills + 1, "a felled rival is counted as a kill (%d)" % MatchStats.kills)
	await get_tree().create_timer(2.5).timeout
	_verdict(not _world.hud.get_node("StatsButton").visible, "no stats can be asked for while the match goes on")
	# The fall.
	player.take_damage(100000)
	await get_tree().create_timer(1.5).timeout
	var screen: StatsScreen = _world._stats
	_verdict(screen != null and screen.visible, "the stats screen comes up when the player falls")
	_verdict(screen != null and screen.placement == 3 and screen.field == 4, "and says where they came: third of four (#%s of %s)" % [screen.placement if screen else "?", screen.field if screen else "?"])
	_verdict(not _world.hud.is_game_over(), "no game-over screen while rivals live")
	_verdict(StatsScreen._clock(83.0) == "1:23", "a time reads as minutes and seconds")
	_verdict(StatsScreen._round_up(37.0) == 40.0 and StatsScreen._round_up(3.0) == 4.0, "a chart tops out at a round figure")
	await get_tree().process_frame
	_verdict(screen._charts.is_empty(), "the first page of the ball is writing, not a chart")
	var first_key := InputEventKey.new()
	first_key.keycode = KEY_RIGHT
	first_key.pressed = true
	screen._input(first_key)
	await get_tree().process_frame
	_verdict(screen._page == 1 and screen._charts.size() == 1, "the right arrow turns to a chart, laid out for reading (page %d, %d charts)" % [screen._page, screen._charts.size()])
	first_key.keycode = KEY_LEFT
	screen._input(first_key)
	screen._input(first_key)
	_verdict(screen._page == StatsScreen.PAGES.size() - 1, "and the left arrow turns back, round past the first page (page %d)" % screen._page)
	screen._page = 1
	screen._turn(0)
	await get_tree().process_frame
	_verdict(screen.size.x > 100.0 and screen.size.y > 100.0, "the screen covers the window, so the pointer reaches it (%s)" % screen.size)
	var plot: Rect2 = screen._charts[0]["plot"]
	screen._pointer = plot.position + plot.size * Vector2(0.8, 0.5)  # the pointer rests on a chart
	screen.queue_redraw()
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			var dir := arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(dir)
			for page in StatsScreen.PAGES.size():
				screen._page = page
				screen._turn(0)
				screen._pointer = plot.position + plot.size * Vector2(0.8, 0.5)
				await get_tree().create_timer(0.9).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(dir.path_join("stats_%d.png" % page))
			screen._page = 1
			screen._turn(0)
	# Dismissed, it can be pulled up again, from the pause screen or the end screen.
	screen._close()
	_verdict(not screen.visible, "the screen is put away")
	_verdict(_world.hud.get_node("StatsButton").visible, "a crystal ball for them stays on the screen")
	_world.hud.get_node("StatsButton").pressed.emit()
	await get_tree().process_frame
	_verdict(_world._stats.visible, "and a request for it brings it back")
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## The buttons of a node's whole tree, by their words.
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
