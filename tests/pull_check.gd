extends Node

## The portal giving way: it tears open high in the middle of the world, and in its last three seconds every wizard still standing is drawn up
## into it (the player's too, with nothing putting them back on the ground), and then the next world loads. The time in a world is shortened.
##
##     godot --headless --path . --fixed-fps 60 tests/pull_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0
var _out := ""  # out=DIR saves pictures of the portal and the pull (needs a window)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
	MatchState.hurry = 0.05
	World.random_start = false
	World.next_seed = 8
	var tree := get_tree()
	await tree.process_frame
	reparent(tree.root)  # this node outlives the scenes that come and go
	tree.current_scene = null
	tree.change_scene_to_file("res://scenes/world.tscn")
	while not (tree.current_scene is World and tree.current_scene.nav != null):
		await tree.process_frame
	var world: World = tree.current_scene
	await tree.process_frame
	var frames := 0
	while world._tear == null and frames < 3000:
		await tree.process_frame
		frames += 1
	_verdict(world._tear != null, "the portal tears open")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
		world.player.global_position = world._tear.global_position + Vector2(-300.0, 380.0)  # to look at it from below
		world.player.velocity = Vector2.ZERO
		world.player.set_physics_process(false)
		await tree.create_timer(0.4).timeout
		_shot("1_opening")
		await tree.create_timer(1.6).timeout
		_shot("2_open")
	var middle: float = ArenaGen.world_size.x * 32.0 * 0.5
	_verdict(absf(world._tear.global_position.x - middle) < 1.0 and world._tear.global_position.y < 600.0, "it is in the middle, high up (%s)" % str(world._tear.global_position))
	while not world._pulling and frames < 6000:
		await tree.process_frame
		frames += 1
	var wizards := SpellTargets.wizards(tree)
	_verdict(wizards.size() == 4, "four wizards are drawn in (%d)" % wizards.size())
	var start := {}
	for body in wizards:
		start[body] = body.global_position.distance_to(world._tear.global_position)
	var player_start: float = start[world.player]
	await tree.create_timer(1.2).timeout
	_shot("3_pull")
	var nearer := 0
	for body in wizards:
		if body.global_position.distance_to(world._tear.global_position) < start[body]:
			nearer += 1
	_verdict(nearer == wizards.size(), "they are on their way up to it (%d of %d nearer)" % [nearer, wizards.size()])
	await tree.create_timer(1.6).timeout
	_verdict(world.player.global_position.distance_to(world._tear.global_position) < player_start * 0.2 or player_start < 600.0, "the player is nearly there, and was not put back on the ground (%.0f of %.0f px left)" % [world.player.global_position.distance_to(world._tear.global_position), player_start])
	_verdict(world.player.modulate.a < 0.9, "they fade as they go in")
	var seen_loading := false
	frames = 0
	var next: World = null
	while next == null and frames < 6000:
		await tree.process_frame
		frames += 1
		var scene := tree.current_scene
		if scene is Loading:
			seen_loading = true
			_verdict(not scene.get_node("Box").visible, "the loading screen shows no words")
		if scene is World and scene != world and scene.nav != null:
			next = scene
	_verdict(next != null, "the next world loads")
	print("the portal draws everyone in" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _shot(name: String) -> void:
	if _out != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
