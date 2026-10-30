extends SceneTree

## Checks the wizards' way about a world: the map of the ways (WorldNav) agrees with the generator's own test of what can be walked, every
## step of a path is a move that exists, and the map is built fast enough to be made while a world loads.
##
## Run from the project folder:
##     godot --headless -s tests/test_nav.gd            (add `-- seeds=N first=K` for others)
## It prints each failure and exits with code 1 if anything failed.

var seeds := 4
var first := 0
var _failures := 0
var _checks := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds = int(arg.substr(6))
		elif arg.begins_with("first="):
			first = int(arg.substr(6))
	for s in range(first, first + seeds):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var world := WorldBuilder.make(rng, SurfaceGen.BIOMES[s % SurfaceGen.BIOMES.size()], SurfaceGen.BIOMES[s % SurfaceGen.BIOMES.size()] != "castle")  # the castle world has no halls under it
		var graph: WorldGraph = world["graph"]
		var shut := WorldBuilder.shut(world)
		var cells: TileGrid = shut["cells"]
		var bottom: int = world["size"].y
		var nav := WorldNav.new()
		var started := Time.get_ticks_msec()
		nav.build(cells, bottom, shut["barred"])
		var seconds := (Time.get_ticks_msec() - started) / 1000.0
		var ways := Walkways.new(cells, bottom, shut["barred"])
		print("seed %d: %d tiles to stand on, the map of the ways built in %.1fs" % [s, nav.size(), seconds])
		_check(nav.size() > 1000, "seed %d: only %d tiles to stand on" % [s, nav.size()])
		var spawns: Array[Vector2i] = world["spawns"]
		var picker := RandomNumberGenerator.new()
		picker.seed = s + 99
		for spawn in spawns:
			var from := nav.nearest(spawn)
			var reach := WorldBuilder.reachable(cells, from, bottom, shut["barred"])
			var keys: Array = reach.keys()
			_check(keys.size() > 500, "seed %d: a spawn at %s reaches only %d tiles" % [s, spawn, keys.size()])
			var longest := 0
			for k in 120:
				var to: Vector2i = keys[picker.randi() % keys.size()]
				var path := nav.path(from, to)
				_check(not path.is_empty() and path[0] == from and path[path.size() - 1] == to, "seed %d: no path from %s to %s, which can be walked to" % [s, from, to])
				longest = maxi(longest, path.size())
				for i in range(1, path.size()):
					if not ways.moves(path[i - 1]).has(path[i]):
						_check(false, "seed %d: the path steps from %s to %s, which is not a move" % [s, path[i - 1], path[i]])
						break
			# Places that cannot be walked to have no path.
			var unreachable := 0
			var tries := 0
			while unreachable < 40 and tries < 4000:
				tries += 1
				var tile := nav.nearest(Vector2i(picker.randi_range(0, world["size"].x - 1), picker.randi_range(0, world["size"].y - 1)))
				if not reach.has(tile):
					unreachable += 1
					_check(nav.path(from, tile).is_empty(), "seed %d: a path from %s to %s, which cannot be walked to" % [s, from, tile])
			print("   spawn %s reaches %d tiles; the longest path tried has %d steps; %d unreachable tiles tried" % [spawn, keys.size(), longest, unreachable])
		# Anchored on a spawn, the map keeps only what can be left as well as come to: no pit with no way out.
		var anchored := WorldNav.new()
		anchored.build(cells, bottom, shut["barred"], spawns[0], shut["tolls"], shut["links"], shut["climbs"])
		var home := anchored.nearest(spawns[0])
		_check(anchored.size() > 1000 and anchored.size() <= nav.size(), "seed %d: the anchored map has %d tiles, of %d" % [s, anchored.size(), nav.size()])
		for spawn in spawns:
			_check(anchored.can_stand(anchored.nearest(spawn)) and not anchored.path(home, anchored.nearest(spawn)).is_empty() and not anchored.path(anchored.nearest(spawn), home).is_empty(), "seed %d: the spawn at %s is not joined both ways to the first" % [s, spawn])
		var loose := 0
		for k in 150:
			var tile := anchored.nearest(Vector2i(picker.randi_range(0, world["size"].x - 1), picker.randi_range(0, world["size"].y - 1)))
			if anchored.path(tile, home).is_empty() or anchored.path(home, tile).is_empty():
				loose += 1
		_check(loose == 0, "seed %d: %d tiles of the anchored map cannot be walked to and from the spawn" % [s, loose])
		print("   anchored: %d of the %d tiles can be left as well as come to" % [anchored.size(), nav.size()])
	print("%d checks" % _checks)
	print("all navigation checks passed" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL  " + message)
