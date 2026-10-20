extends Node

## Plays a scripted scene in the real game and saves screenshots, so the look of the game can be checked without
## playing it by hand. Run from the project folder with a window (not headless), for example:
##     godot --path . tests/showcase.tscn -- scenario=spells out=C:/temp/shots
## Scenarios:
##   world   - every enemy kind standing around the player, then a wave in progress
##   spells  - every spell cast in turn among some enemies, with a screenshot of each
##   wizard  - the dark wizard dueling a player who stands still and throws bolts at it
## Fixed physics steps make it play the same way each time.

var scenario := "world"
var out_dir := "user://shots"
var wave := 2
var only := ""  # spells scenario: cast just this spell, with a screenshot every tenth of a second
var _arena: Node
var _t := 0.0
var _steps: Array = []  # [time, Callable]
var _next := 0
var _shot := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			match parts[0]:
				"scenario":
					scenario = parts[1]
				"out":
					out_dir = parts[1]
				"wave":
					wave = int(parts[1])
				"only":
					only = parts[1].replace("_", " ")
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps running while the game is paused
	DirAccess.make_dir_recursive_absolute(out_dir)
	Levels.wave_index = wave
	_arena = load("res://scenes/arena.tscn").instantiate()
	add_child(_arena)
	_plan()


func _process(delta: float) -> void:
	if _next == 0 and _t == 0.0:
		_steps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_t += delta
	while _next < _steps.size() and _t >= _steps[_next][0]:
		_steps[_next][1].call()
		_next += 1
	if _next >= _steps.size():
		get_tree().quit()


func _at(time: float, action: Callable) -> void:
	_steps.append([time, action])


func _snap(name := "") -> void:
	var image := get_viewport().get_texture().get_image()
	_shot += 1
	var file := "%s/%s_%02d%s.png" % [out_dir, scenario, _shot, ("_" + name) if name != "" else ""]
	image.save_png(file)
	print("saved ", file)


func _player() -> Node2D:
	return _arena.player


## A stroke made of a shape's points, placed so its bounding box is centred on a point, at a size.
func _stroke(gesture: String, middle: Vector2, size := 1.0) -> PackedVector2Array:
	var shape := GestureTemplates.preview_points(gesture)
	var low := shape[0]
	var high := shape[0]
	for p in shape:
		low = low.min(p)
		high = high.max(p)
	var out := PackedVector2Array()
	for p in shape:
		out.append(middle + (p - (low + high) * 0.5) * size)
	return _densify(out)


func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out


func _cast(spell_name: String, stroke: PackedVector2Array) -> void:
	_player().stamina = _player().MAX_STAMINA
	_arena.caster.cast_stroke(SpellData.SPELLS[spell_name]["buttons"], stroke)


func _summon_at(kind: String, x: float) -> Node2D:
	var ground := SpellTargets.solid_below(_arena.get_world_2d(), Vector2(x, ArenaGen.GROUND_Y - 4.0 * ArenaGen.TILE))
	return _arena._add_mob(kind, ground)


func _plan() -> void:
	_arena._director.set_process(false)  # the showcase chooses its own enemies
	_player().hp = 9999  # nothing ends the showcase early
	match scenario:
		"world":
			_at(0.4, func() -> void:
				var x: float = _player().global_position.x
				var kinds := ["fire_melee", "ice_ranged", "earth_melee", "storm_flyer", "force_ranged", "dark_wizard"]
				for i in kinds.size():
					var mob := _summon_at(kinds[i], x + (i - 2.5) * 70.0)
					mob.set_physics_process(false)
					mob._spawn = 0.0
					mob.modulate.a = 1.0)
			_at(1.5, func() -> void: _snap("standing"))
			_at(1.6, func() -> void:
				for mob in _arena.get_tree().get_nodes_in_group("mobs"):
					mob.set_physics_process(true))
			_at(4.0, func() -> void: _snap("moving"))
			_at(4.2, func() -> void: _arena.debug_panel.visible = true)
			_at(4.4, func() -> void: _snap("debug"))
		"kinds":
			# Every enemy kind in a row, frozen in place, to check colours and sizes.
			_at(0.3, func() -> void:
				var x: float = _player().global_position.x - 330.0
				var i := 0
				for kind in Mob.KINDS:
					if Mob.KINDS[kind]["role"] == "flyer":
						continue
					var mob := _summon_at(kind, x + i * 60.0)
					mob._spawn = 0.0
					mob.modulate.a = 1.0
					mob.set_physics_process(false)
					print(kind, " ", mob._material.get_shader_parameter("school_color") if mob._material else "wizard")
					i += 1)
			_at(1.2, func() -> void: _snap("walkers"))
		"spells":
			_plan_spells()
		"ui":
			_at(0.5, func() -> void: _arena._on_wave_cleared())
			_at(1.0, func() -> void: _snap("portal_arrow"))
			_at(1.1, func() -> void: _player().global_position = _arena._portal.global_position + Vector2(-90, Portal.RY + 4.0))
			_at(1.6, func() -> void: _snap("portal"))
			_at(1.7, func() -> void: _arena.spellbook.visible = true)
			_at(1.9, func() -> void: _snap("book_contents"))
			_at(2.0, func() -> void: _arena.spellbook._turn(1))
			_at(2.08, func() -> void: _snap("book_turning"))
			_at(2.4, func() -> void: _snap("book_ice_force"))
			_at(2.45, func() -> void: _arena.spellbook._turn(1))
			_at(2.85, func() -> void: _snap("book_storm_earth"))
			_at(2.9, func() -> void: _arena.spellbook._turn(1))
			_at(3.3, func() -> void: _snap("book_incantations"))
			_at(3.5, func() -> void:
				_arena.spellbook.visible = false
				_arena.hud.toggle_pause())
			_at(3.7, func() -> void: _snap("pause"))
			_at(3.8, func() -> void:
				_arena.hud.toggle_pause()
				_player().hp = 5
				_player()._grace = 0.0
				_player().take_damage(10))
			_at(5.8, func() -> void: _snap("game_over"))
		"wizard":
			_plan_wizard()
		"soak":
			# The real wave plays while the player, who cannot die, casts random spells at random spots. Only
			# errors in the output matter; run it headless.
			_arena._director.set_process(true)
			var rng := RandomNumberGenerator.new()
			rng.seed = wave
			var names := SpellData.SPELLS.keys()
			for i in 40:
				_at(0.5 + i * 0.3, func() -> void:
					var spell_name: String = names[rng.randi() % names.size()]
					var gesture: String = SpellData.SPELLS[spell_name].get("preview", SpellData.SPELLS[spell_name]["gesture"])
					var spot: Vector2 = _player().global_position + Vector2(rng.randf_range(-250.0, 250.0), rng.randf_range(-160.0, -20.0))
					if gesture == "stone_wall":
						spot.y = ArenaGen.GROUND_Y - 40.0
					_cast(spell_name, _stroke(gesture, spot, rng.randf_range(0.8, 1.3)))
					_player().hp = 9999)
			_at(13.0, func() -> void: print("soak wave %d done, %d enemies left" % [wave, _arena.get_tree().get_nodes_in_group("mobs").size()]))
		"biome":
			_at(2.6, func() -> void: _snap("level"))
		"brawl":
			# A mixed group comes for a player who stands still, to watch them chase, wind up, shoot and dive.
			_at(0.3, func() -> void:
				var x: float = _player().global_position.x
				for entry in [["fire_melee", -220.0], ["storm_melee", 260.0], ["earth_melee", 320.0], ["fire_ranged", -330.0], ["ice_ranged", 380.0], ["fire_flyer", -120.0], ["storm_flyer", 150.0]]:
					_summon_at(entry[0], x + entry[1]))
			for i in 12:
				_at(1.2 + i * 0.6, func() -> void: _snap())


func _plan_spells() -> void:
	var t := 0.3
	var p := func() -> Vector2: return _player().global_position
	var ahead := func(dx: float, dy: float) -> Vector2: return _player().global_position + Vector2(dx, dy)
	var spells := [
		["Ignite", func() -> PackedVector2Array: return _densify(PackedVector2Array([ahead.call(0, -40), ahead.call(100, -40)]))],
		["Frostbolt", func() -> PackedVector2Array: return _densify(PackedVector2Array([ahead.call(0, -30), ahead.call(100, -20)]))],
		["Firewall", func() -> PackedVector2Array: return _stroke("wall", ahead.call(120, -60), 1.0)],
		["Volcano", func() -> PackedVector2Array: return _stroke("volcano", ahead.call(200, -60), 0.9)],
		["Fire Breath", func() -> PackedVector2Array: return _stroke("cone", ahead.call(60, -26), 1.0)],
		["Icicles", func() -> PackedVector2Array: return _stroke("icicles", ahead.call(160, -40), 1.0)],
		["Blizzard", func() -> PackedVector2Array: return _stroke("snowfall", ahead.call(150, -90), 1.0)],
		["Ice Prison", func() -> PackedVector2Array: return _stroke("circle", ahead.call(170, -26), 0.8)],
		["Push", func() -> PackedVector2Array:
			var pts := PackedVector2Array()
			var c: Vector2 = ahead.call(150, -26)
			for i in 33:
				pts.append(c + Vector2.from_angle(PI + TAU * i / 32.0) * 40.0)
			pts.append(c + Vector2(-40, 0) + Vector2(140, 0))
			return _densify(pts)],
		["Barrier", func() -> PackedVector2Array: return _stroke("circle", ahead.call(0, -26), 0.8)],
		["Force Wall", func() -> PackedVector2Array: return _densify(PackedVector2Array([ahead.call(70, -90), ahead.call(70, 10)]))],
		["Gravity Well", func() -> PackedVector2Array: return _stroke("spiral", ahead.call(170, -40), 1.2)],
		["Tornado", func() -> PackedVector2Array: return _stroke("tornado", ahead.call(160, -80), 1.0)],
		["Spark", func() -> PackedVector2Array: return _stroke("zigzag", ahead.call(170, -100), 1.0)],
		["Storm Cloud", func() -> PackedVector2Array: return _stroke("cloud", ahead.call(170, -170), 1.0)],
		["Blink", func() -> PackedVector2Array: return _densify(PackedVector2Array([ahead.call(0, -20), ahead.call(160, -20)]))],
		["Stonefall", func() -> PackedVector2Array: return _stroke("stonefall", ahead.call(160, -150), 0.9)],
		["Stone Wall", func() -> PackedVector2Array:
			# One wall from the ground, then a second one grown sideways out of the top of the first.
			var start: Vector2 = ahead.call(90, -2)
			var first := _densify(PackedVector2Array([start, ahead.call(160, -100)]))
			_cast("Stone Wall", first)
			var top: Vector2 = start + (first[first.size() - 1] - start).normalized() * (SpellEffect.STONE_WALL_LENGTH - 6.0)
			return _densify(PackedVector2Array([top, top + Vector2(110, 0)]))],
		["Mudslide", func() -> PackedVector2Array: return _stroke("pit", ahead.call(170, -50), 1.2)],
	]
	if only != "":
		spells = spells.filter(func(entry: Array) -> bool: return entry[0] == only)
	for entry in spells:
		var spell_name: String = entry[0]
		var stroke_for: Callable = entry[1]
		_at(t, func() -> void:
			for mob in _arena.get_tree().get_nodes_in_group("mobs"):
				mob.queue_free()
			for node in _arena.get_children():
				if node is SpellEffect or node is Tornado or node is Volcano or node is Hazard or node is StormCloud or node is Quicksand or node is IcePrison or node is GravityWell or node is FireBreath:
					node.queue_free())
		_at(t + 0.1, func() -> void:
			var x: float = _player().global_position.x
			for dx in [130.0, 180.0, 230.0]:
				var mob := _summon_at("basic" if dx != 180.0 else "fire_flyer", x + dx)
				mob._spawn = 0.0
				mob.modulate.a = 1.0)
		_at(t + 0.4, func() -> void: _cast(spell_name, stroke_for.call()))
		var delay := 0.5
		match spell_name:
			"Stonefall":
				delay = 0.65
			"Volcano", "Storm Cloud":
				delay = 1.4
			"Fire Breath":
				delay = 0.5
			"Spark", "Blink":
				delay = 0.08
			"Gravity Well", "Tornado":
				delay = 0.9
		_at(t + 0.4 + delay, func() -> void: _snap(spell_name.replace(" ", "_")))
		if only != "":
			for k in 16:
				_at(t + 0.45 + k * 0.1, func() -> void: _snap("%s_%.1f" % [spell_name.replace(" ", "_"), k * 0.1]))
		if spell_name == "Fire Breath":
			# The breath follows the mouth: it rises when you jump and turns when you turn.
			_at(t + 0.4 + delay + 0.02, func() -> void: _player().velocity.y = -520.0)
			_at(t + 0.4 + delay + 0.2, func() -> void: _snap("Fire_Breath_jump"))
			_at(t + 0.4 + delay + 0.22, func() -> void: _player()._facing = -1.0)
			_at(t + 0.4 + delay + 0.45, func() -> void: _snap("Fire_Breath_turn"))
		t += 2.2


func _plan_wizard() -> void:
	var wizard: Array = [null]
	_at(0.3, func() -> void:
		wizard[0] = _summon_at("dark_wizard", _player().global_position.x + 260.0))
	for i in 24:
		var at := 1.5 + i * 0.75
		# The player throws a fireball at the wizard now and then, so it has something to react to.
		if i % 3 == 0:
			_at(at, func() -> void:
				if wizard[0] and is_instance_valid(wizard[0]):
					var from: Vector2 = _player().center()
					var dir: Vector2 = (wizard[0].center() - from).normalized()
					_cast("Ignite", _densify(PackedVector2Array([from, from + dir * 100.0]))))
		_at(at + 0.35, func() -> void: _snap())
