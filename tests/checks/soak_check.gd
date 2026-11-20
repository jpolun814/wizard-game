extends Check

## Random play, in every kind of world: a player who casts random spells at random places, walks and jumps, in a world full of rivals who are playing too, for a
## stretch of game time. It does not look for one thing; it looks for anything that goes wrong that nobody thought to write a case for: a script error (the runner fails on
## one), a position or health that stops being a number, nodes piling up without end (a leak), a wizard that falls out of the world, a spell that never ends.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/soak_check.tscn [-- seconds=40] [-- only=ocean,sky] [-- seed=7]
## The dice are seeded, so a failure comes again with the same seed.

const BIOMES := ["graveyard", "mountains", "jungle", "ashlands", "castle", "underground", "portals", "ocean", "sky"]
const WORLD_SEEDS := {"graveyard": 1, "mountains": 4, "jungle": 0, "ashlands": 5, "castle": 3, "underground": 13, "portals": 6, "ocean": 7, "sky": 8}
const GROWTH_LIMIT := 1.6   # the node count at the end may be this many times the busiest it was in the first quarter (spells end; leaks do not)

var _seconds := 40.0
var _only := ""
var _dice := RandomNumberGenerator.new()
var _scene: Node


func _ready() -> void:
	var seed_of := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seconds="):
			_seconds = float(a.get_slice("=", 1))
		elif a.begins_with("only="):
			_only = a.get_slice("=", 1)
		elif a.begins_with("seed="):
			seed_of = int(a.get_slice("=", 1))
	_dice.seed = seed_of
	Library.use_file("user://soak_check.json")
	Library.clear()
	for biome in BIOMES:
		if _only == "" or biome in _only.split(","):
			await _soak(biome)
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _soak(biome: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	MatchState.forced_biome = biome
	MatchState.stage = 0
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = WORLD_SEEDS[biome]
	MatchState.hurry = 100.0
	seed(WORLD_SEEDS[biome])
	var world: World = load("res://scenes/world.tscn").instantiate()
	_scene = world
	add_child(world)
	for k in 60:
		await get_tree().physics_frame
	var player: Wizard = world.player
	player.ledger.learn_all()
	player.grant_unlimited(1.0e9)
	var spells: Array = SpellData.SPELLS.keys()
	var time := 0.0
	var next_cast := 1.0
	var nodes_early := 0
	var nodes_peak_early := 0
	var casts := 0
	var worst_frame := 0.0
	var bad_number := ""
	var fell := false
	var started := Time.get_ticks_msec()
	var walking := 0.0
	while time < _seconds and is_instance_valid(player) and not player.dead:
		var before := Time.get_ticks_msec()
		await get_tree().physics_frame
		time += 1.0 / 60.0
		worst_frame = maxf(worst_frame, float(Time.get_ticks_msec() - before))
		if time >= walking:
			walking = time + _dice.randf_range(0.4, 2.0)
			player.walk(_dice.randf_range(-1.0, 1.0) * 220.0 if _dice.randf() < 0.8 else 0.0)
			if _dice.randf() < 0.4:
				player.request_jump(_dice.randf_range(0.4, 1.0))
		if time >= next_cast:
			next_cast = time + _dice.randf_range(0.4, 1.4)
			var data: Spell = SpellData.SPELLS[spells[_dice.randi() % spells.size()]]
			var shape := GestureTemplates.preview_points(data.gesture)
			var at: Vector2 = player.center() + Vector2(_dice.randf_range(-260.0, 260.0), _dice.randf_range(-160.0, 60.0))
			if not world.caster.is_drawing() and not player.pen.active():
				world.caster.cast_stroke(data.buttons, BrainStrokes.offset(shape, at, _dice.randf_range(0.6, 1.4)))
				casts += 1
		if int(time * 60.0) % 30 == 0:
			player.max_stamina = Wizard.MAX_STAMINA  # (it is hurt by everything it casts and by the rivals: it is mended so that the soak runs its whole length)
			player.stamina = player.max_stamina
			for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
				if not is_instance_valid(wizard):
					continue
				var p := wizard.global_position
				if not (is_finite(p.x) and is_finite(p.y)) or not is_finite(wizard.stamina) or not is_finite(wizard.max_stamina):
					bad_number = "%s at %s with stamina %s" % [wizard.name, p, wizard.stamina]
				if p.y > ArenaGen.GROUND_Y + 9000.0 and biome != "sky" and not wizard.dead:
					fell = true
		var count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if time < _seconds * 0.25:
			nodes_peak_early = maxi(nodes_peak_early, count)
		nodes_early = count
	var wall := (Time.get_ticks_msec() - started) / 1000.0
	var label := "%s (%d casts, %.0f s of play in %.0f s)" % [biome, casts, time, wall]
	_verdict(bad_number == "", "%s: every wizard's place and stamina stay numbers %s" % [label, bad_number])
	_verdict(not fell, "%s: nobody falls out of the world" % label)
	_verdict(nodes_early <= maxi(int(nodes_peak_early * GROWTH_LIMIT), nodes_peak_early + 400), "%s: the world does not fill with nodes (%d at the end, %d at the busiest early on)" % [label, nodes_early, nodes_peak_early])
	_verdict(worst_frame < 1500.0, "%s: no single step takes a second and a half (worst %.0f ms)" % [label, worst_frame])
	_verdict(casts > 5 or player.dead, "%s: the player was able to cast (%d)" % [label, casts])
