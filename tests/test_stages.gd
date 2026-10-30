extends SceneTree

## Checks every world a match plays through (see MatchState), in every biome: each is built, its ground can be walked from every starting place to every hall
## that no gate shuts off, the starting places are well apart, and every page the wizards do not hold has a place to lie.
##
##     godot --headless --path . -s tests/test_stages.gd -- seeds=6 first=0

var seeds := 6
var first := 0
var _checks := 0
var _failures := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds = int(arg.substr(6))
		elif arg.begins_with("first="):
			first = int(arg.substr(6))
	for stage in MatchState.STAGES.size():
		var plan: Dictionary = MatchState.STAGES[stage]
		WorldGraph.size = Vector2i(plan["width"], MatchState.HEIGHT)
		for s in range(first, first + seeds):
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 31 + stage
			var started := Time.get_ticks_msec()
			var last: bool = stage == MatchState.STAGES.size() - 1
			var pool: Array = SurfaceGen.OPEN_BIOMES if last else SurfaceGen.BIOMES  # the last world is all open sky
			var biome: String = pool[(stage + s) % pool.size()]  # every biome gets its turn
			var halls: bool = SurfaceGen.has_halls(biome)
			var world := WorldBuilder.make(rng, biome, halls)
			var graph: WorldGraph = world["graph"]
			var seconds := (Time.get_ticks_msec() - started) / 1000.0
			var label := "stage %d seed %d" % [stage, s]
			_check(world["size"].x == plan["width"], "%s: %s tiles wide" % [label, world["size"]])
			_check(world["spawns"].size() == WorldGraph.PLAYERS, "%s: %d starting places" % [label, world["spawns"].size()])
			var spawns: Array[Vector2i] = world["spawns"]
			var apart := 1 << 20
			for i in spawns.size():
				for j in range(i + 1, spawns.size()):
					apart = mini(apart, absi(spawns[i].x - spawns[j].x))
			_check(apart >= plan["width"] / 10, "%s: starting places only %d columns apart" % [label, apart])
			var shut := WorldBuilder.shut(world)
			var nav := WorldNav.new()
			nav.build(shut["cells"], world["size"].y, shut["barred"], spawns[0], shut["tolls"], shut["links"], shut["climbs"])
			for spawn in spawns:
				var at := nav.nearest(spawn)
				_check(nav.can_stand(at) and not nav.path(nav.nearest(spawns[0]), at).is_empty() and not nav.path(at, nav.nearest(spawns[0])).is_empty(), "%s: the starting place %s is not joined both ways to the first" % [label, spawn])
			var unreached := 0
			for room in graph.rooms:
				if room["lock"] == -1 and not nav.can_stand(world["markers"][room["id"]]):
					unreached += 1
			_check(unreached == 0, "%s (%s): %d halls outside every locked area cannot be walked to" % [label, biome, unreached])
			if not halls:
				_check(graph.rooms.size() == 1 and world["gates"].is_empty(), "%s: the %s is not all open sky" % [label, biome])
			_check(world["castles"].is_empty() != (biome == "castle"), "%s: %d castles in the %s" % [label, world["castles"].size(), biome])
			_check(world["roofed"] == (biome == "underground"), "%s: roofed is %s in the %s" % [label, world["roofed"], biome])
			var dealt := Pages.deal(s, 4)
			var layout := Pages.plan(graph, rng, dealt)
			var known := {}
			for ledger in dealt:
				for page in ledger.pages:
					known[page] = true
			_check(layout.size() + known.size() == Pages.every().size(), "%s: %d pages laid, %d held, of %d" % [label, layout.size(), known.size(), Pages.every().size()])
			print("%s: %d mouths, %d halls, %d tiles to stand on, built in %.1fs, spawns %d apart" % [label, graph.rooms[0]["mouths"].size(), graph.rooms.size(), nav.size(), seconds, apart])
	print("%d checks" % _checks)
	print("all stage checks passed" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL  " + message)
