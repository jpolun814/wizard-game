extends Node

## The snowy peaks have a second range of ridges behind the ground: a wizard can walk up one from the ground and stand on its top, and S
## on the top drops them back down. With `-- out=DIR` (and no --headless) it also takes a picture.
##
##     godot --headless --fixed-fps 60 --path . tests/ridge_check.tscn -- seed=4
## It prints PASS or FAIL and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	var seed_value := 4
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.trim_prefix("seed="))
		if argument.begins_with("out="):
			out = argument.trim_prefix("out=")
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var ridges: MountainRidges = null
	for node in world.get_children():
		if node is MountainRidges:
			ridges = node
	_verdict(ridges != null and ridges.ridges.size() >= 6, "the peaks have ridges (%d)" % (ridges.ridges.size() if ridges != null else 0))
	if ridges == null:
		get_tree().quit(1)
		return
	var ridge: PackedVector2Array = ridges.ridges[ridges.ridges.size() / 2]
	var top := ridge[1].lerp(ridge[2], 0.5)
	var low := ridge[0]
	var steepest := 0.0
	for r: PackedVector2Array in ridges.ridges:
		steepest = maxf(steepest, absf((r[1].y - r[0].y) / (r[1].x - r[0].x)))
		steepest = maxf(steepest, absf((r[3].y - r[2].y) / (r[3].x - r[2].x)))
	_verdict(steepest < 1.0, "every slope is one a wizard can walk (%.2f rows a column)" % steepest)
	var player := world.player
	player.max_stamina = 9999.0
	world._ground.watch([top], true)
	player.global_position = top + Vector2(0.0, -80.0)
	player.velocity = Vector2.ZERO
	for k in 90:
		await get_tree().physics_frame
	_verdict(absf(player.global_position.y - top.y) < 6.0 and player.is_on_floor(), "a wizard dropped over a ridge lands on its top (%.0f px from it)" % (player.global_position.y - top.y))
	if out != "":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().get_texture().get_image().save_png(out + "/ridge.png")
	if out != "":
		var foot := SpellTargets.solid_below(world.get_world_2d(), Vector2(low.x - 260.0, low.y - 400.0))
		player.global_position = foot + Vector2(0.0, -30.0)
		world._ground.watch([foot, low, top], true)
		for k in 90:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/ridge_foot.png")
		player.global_position = top + Vector2(0.0, -80.0)
		for k in 60:
			await get_tree().physics_frame
	Input.action_press("move_down")
	for k in 40:
		await get_tree().physics_frame
	Input.action_release("move_down")
	_verdict(player.global_position.y > top.y + 20.0, "and S drops them through it (%.0f px lower)" % (player.global_position.y - top.y))
	# A U drawn on a ridge's top sinks the ridge there, and a wizard standing in the pit stands lower.
	var middle := top
	var drawn := PackedVector2Array([middle + Vector2(-60, -20), middle + Vector2(-40, 50), middle + Vector2(0, 70), middle + Vector2(40, 50), middle + Vector2(60, -20)])
	var fit := Sinkhole.fit(world.get_world_2d(), drawn, 17, ridges)
	_verdict(fit["ridge"] == ridges, "a U drawn on a ridge's top is fitted to the ridge")
	var before := ridges.top_at(middle.x)
	_verdict(ridges.dig(fit["spot"], fit["half_width"], fit["depth"], fit["profile"]), "the pit opens in the ridge")
	_verdict(ridges.top_at(middle.x) > before + 20.0, "and the ridge's top is lower there (%.0f px)" % (ridges.top_at(middle.x) - before))
	_verdict(ridges.top_at(middle.x + 120.0) == before, "and no lower beside it")
	print("the peaks have a second range" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
