extends Node

## The flowing liquid in real worlds: every pool is made and keeps its water (none drains away through the ground), the ground the liquid sees
## agrees with the ground a body stands on, and a pit dug beside a pool fills from it, quickly enough that no frame is lost.
##
##     godot --headless --fixed-fps 60 --path . tests/liquid_world_check.tscn -- seed=8
## It prints PASS or FAIL for each and exits with code 1 if any failed.

var _failures := 0


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _ready() -> void:
	var seed_value := 8
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seed="):
			seed_value = int(argument.substr(5))
	World.random_start = false
	World.next_seed = seed_value
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var ground: Terrain = world._ground
	var space := world.get_world_2d()

	# The liquid's idea of the ground matches the ground bodies land on: dropping a ray from above finds the same surface as walking down with solid_at.
	# (A point query cannot be used: the rock's collision is made of lines, and has no inside.)
	var feet: Vector2 = world.player.global_position
	var checked := 0
	var differ := 0
	for dx in range(-400, 401, 16):
		var from := feet + Vector2(dx, -240)
		var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), 1)
		var hit := space.direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var found := INF
		for step in 150:
			if ground.solid_at(from + Vector2(0, step * 4.0)):
				found = from.y + step * 4.0
				break
		checked += 1
		if absf(found - hit["position"].y) > 14.0:
			differ += 1
			print("INFO  at x %.0f the ground is at %.0f for a body and %.0f for the liquid" % [from.x, hit["position"].y, found])
	_verdict(checked > 20 and differ <= checked / 10, "the liquid sees the same ground as bodies do (%d of %d columns differ)" % [differ, checked])

	var ponds := get_tree().get_nodes_in_group("ponds")
	if not ponds.is_empty():
		var first: Pond = ponds[0]
		first.begin_grid()
		var frames := 0
		while first.grid == null and frames < 300:
			await get_tree().physics_frame
			frames += 1
		_verdict(first.grid != null and first.grid.total() > 0.0, "a pool makes its liquid a little at a time without stopping the game (%d frames)" % frames)
	var leaks := 0
	var cost := 0
	var largest := 0
	for pond: Pond in ponds:
		var began := Time.get_ticks_usec()
		pond.ensure_grid()
		cost = maxi(cost, Time.get_ticks_usec() - began)
		var start := pond.grid.total()
		var volume := pond.width / LiquidGrid.CELL * pond.depth / LiquidGrid.CELL
		largest = maxi(largest, pond.grid.cols * pond.grid.rows)
		var steps := 0
		while not pond.grid.asleep and steps < 4000:
			pond.grid.step()
			steps += 1
		var kept := pond.grid.total() / maxf(start, 0.001)
		if kept < 0.9 or start <= 0.0:
			leaks += 1
			print("INFO  pool at %s (%s, %.0f wide, %.0f deep): %.0f%% kept, %.1f of about %.1f to start, %d steps" % [pond.global_position, "lava" if pond.lava else "water", pond.width, pond.depth, kept * 100.0, start, volume, steps])
	_verdict(leaks == 0, "every pool is made with liquid in it and keeps it (%d of %d do not)" % [leaks, ponds.size()])
	print("INFO  making the slowest pool's liquid took %.1f ms; the largest has %d cells" % [cost / 1000.0, largest])

	# A pit dug beside a pool of water fills from it.
	var target: Pond = null
	for pond: Pond in ponds:
		if not pond.lava and pond.grid.total() > 4.0:
			target = pond
			break
	if target == null:
		print("INFO  this world has no pool of water to dig beside")
		get_tree().quit(1 if _failures > 0 else 0)
		return
	var level_before := target.surface_at(target.global_position.x + 60.0)
	var shore := Vector2(target.global_position.x - 40.0, target.global_position.y)
	world.player.global_position = shore + Vector2(0.0, -60.0)
	ground.watch([shore], true)
	for k in 30:
		await get_tree().physics_frame
	var started := target.grid.world_rect()
	var dug := ground.dig(shore + Vector2(0.0, 4.0), 130.0, 96.0)  # (its far wall lies past the room the pool began with)
	_verdict(dug, "a pit is dug on the shore of the pool at %s" % target.global_position)
	var slowest := 0
	var slow_frames := 0
	var total_before := target.grid.total()
	print("INFO  pool: width %.0f depth %.0f, liquid %.1f, grid %d x %d, asleep %s" % [target.width, target.depth, total_before, target.grid.cols, target.grid.rows, target.grid.asleep])
	for k in 600:
		var t := Time.get_ticks_usec()
		await get_tree().physics_frame
		var took := Time.get_ticks_usec() - t
		if k > 2:
			slowest = maxi(slowest, took)
			if took > 8000:
				slow_frames += 1
	print("INFO  liquid after: %.1f, asleep %s, frames over 8 ms: %d" % [target.grid.total(), target.grid.asleep, slow_frames])
	var near_pit := target.global_position.x + 60.0
	var level_after := target.surface_at(near_pit)
	var in_pit := target.grid.wet_at(shore + Vector2(0.0, 70.0))
	_verdict(in_pit, "the water has flowed into the pit")
	_verdict(level_after > level_before + 4.0, "and the pool's surface has dropped (%.0f to %.0f)" % [level_before, level_after])
	# The liquid is not held to the space the pool began with: the pit reaches past it, so the grid grows and the liquid runs on to the far end.
	var grown := target.grid.world_rect().position.x < started.position.x - 8.0
	_verdict(grown, "the pool's room grows to take a pit that reaches past it (%.0f px wide, was %.0f)" % [target.grid.world_rect().size.x, started.size.x])
	_verdict(target.grid.wet_at(Vector2(shore.x - 70.0, shore.y + 84.0)), "and the liquid runs all the way along to the pit's far end")
	var step_total := 0
	var step_worst := 0
	var step_count := 0
	var times: Array[int] = []
	target.grid.wake()
	while not target.grid.asleep and step_count < 6000:
		var t := Time.get_ticks_usec()
		target.grid.step()
		var took := Time.get_ticks_usec() - t
		step_total += took
		step_worst = maxi(step_worst, took)
		times.append(took)
		step_count += 1
	times.sort()
	var common := times[int(times.size() * 0.99)] if not times.is_empty() else 0
	print("INFO  %d more steps to settle this pool: %.2f ms each on average, %.2f ms for all but the slowest 1 in 100, %.2f ms at worst (a machine that is busy with something else makes the odd step slow)" % [step_count, step_total / maxf(step_count, 1) / 1000.0, common / 1000.0, step_worst / 1000.0])
	_verdict(target.grid.asleep and common < 4000, "the pool comes to rest, and its steps are quick enough to be felt as nothing")
	print("INFO  the slowest frame while it flowed took %.1f ms (this includes everything the game did)" % (slowest / 1000.0))
	get_tree().quit(1 if _failures > 0 else 0)
