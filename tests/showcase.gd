extends Node

## Plays a scripted scene in the real game and saves screenshots, so the look of the game can be checked without
## playing it by hand. Run from the project folder with a window (not headless), for example:
##     godot --path . tests/showcase.tscn -- scenario=spells out=C:/temp/shots
## Scenarios:
##   world   - every enemy kind standing around the player, then a wave in progress
##   spells  - every spell cast in turn in the waiting room, with screenshots of each
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
var _exit_code := 0  # what the run exits with: the checks scenario sets it to 1 when one fails


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
	# The spells are tried in the waiting room, where there is a pond, a gap and dummies for each of them.
	var scene := "lab" if scenario in ["spells", "lab", "climb", "checks"] else "arena"
	_arena = load("res://scenes/%s.tscn" % scene).instantiate()
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
		get_tree().quit(_exit_code)


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
		"climb":
			_plan_climb()
		"checks":
			_plan_checks()
		"book":
			# Every spread of the spellbook, one after another.
			_at(0.3, func() -> void: _arena.spellbook.visible = true)
			for k in 8:
				_at(0.6 + k * 0.5, func() -> void: _snap("spread_%d" % k))
				_at(0.9 + k * 0.5, func() -> void: _arena.spellbook._turn(1))
		"ui":
			_at(0.5, func() -> void: _arena._on_wave_cleared())
			_at(1.0, func() -> void: _snap("portal_arrow"))
			_at(1.1, func() -> void: _player().global_position = _arena._portal.global_position + Vector2(-90, Portal.RY + 4.0))
			_at(1.6, func() -> void: _snap("portal"))
			_at(1.7, func() -> void: _arena.spellbook.visible = true)
			_at(1.9, func() -> void: _snap("book_contents"))
			_at(2.0, func() -> void: _arena.spellbook._turn(1))
			_at(2.08, func() -> void: _snap("book_turning"))
			_at(2.4, func() -> void: _snap("book_second_spread"))
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


## A stroke that starts exactly at a point, rather than being centred on it: for spells placed where the stroke begins.
func _stroke_from(gesture: String, start: Vector2, size := 1.0) -> PackedVector2Array:
	var shape := GestureTemplates.preview_points(gesture)
	var out := PackedVector2Array()
	for p in shape:
		out.append(start + (p - shape[0]) * size)
	return _densify(out)


## Where the feet of someone standing in a column of the room are.
func _feet(col: int) -> Vector2:
	return Vector2(ArenaGen.column_x(col), ArenaGen.surface_y(_arena.map_cells(), col))


## Every spell in the waiting room, one after another. Each is cast from a place that suits it (beside the pond, over the gap,
## in front of the dummies) and photographed as it happens; some get further pictures as they play out.
func _plan_spells() -> void:
	var line := func(a: Vector2, b: Vector2) -> PackedVector2Array: return _densify(PackedVector2Array([a, b]))
	# Each entry: spell, the column the wizard stands in, how to draw it from the wizard's feet, and when to photograph.
	var entries := [
		["Ignite", 14, func(f: Vector2) -> PackedVector2Array: return line.call(f + Vector2(0, -40), f + Vector2(100, -40)), [0.3]],
		["Firewall", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("wall", f + Vector2(90, -60)), [0.5]],
		["Fire Breath", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("cone", f + Vector2(60, -26)), [0.5]],
		["Smoke Screen", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("smoke", f + Vector2(80, -60)), [0.8, 2.0]],
		["Flare", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("flare", f + Vector2(80, -90)), [0.8]],
		["Spark", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("zigzag", f + Vector2(90, -100)), [0.1]],
		["Frostbolt", 14, func(f: Vector2) -> PackedVector2Array: return line.call(f + Vector2(0, -40), f + Vector2(100, -30)), [0.3]],
		["Icicles", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("icicles", f + Vector2(110, -40)), [0.5]],
		["Ice Prison", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("circle", f + Vector2(66, -34), 0.9), [0.6]],
		["Blizzard", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("snowfall", f + Vector2(110, -90)), [0.9]],
		["Frost Bridge", 1, func(f: Vector2) -> PackedVector2Array: return _stroke("wave", Vector2(ArenaGen.column_x(8), f.y - 20.0), 1.5), [0.6, 1.5]],
		["Geyser", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("geyser", f + Vector2(0, -50), 0.8), [0.4, 0.95, 1.2]],
		["Tsunami", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("tsunami", f + Vector2(0, -130), 1.2), [1.0, 1.6, 2.2, 3.4]],
		["Push", 14, func(f: Vector2) -> PackedVector2Array: return _push_stroke(f + Vector2(60, -30)), [0.35]],
		["Barrier", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("circle", f + Vector2(0, -30), 0.8), [0.4]],
		["Tornado", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("tornado", f + Vector2(130, -80)), [1.0]],
		["Gust", 14, func(f: Vector2) -> PackedVector2Array: return line.call(f + Vector2(0, -45), f + Vector2(120, -45)), [0.25, 0.5]],
		["Stonefall", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("stonefall", f + Vector2(110, -150), 0.9), [0.9]],
		["Stone Wall", 14, func(f: Vector2) -> PackedVector2Array: return line.call(f + Vector2(80, -2), f + Vector2(150, -90)), [0.4]],
		["Mudslide", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("pit", f + Vector2(110, -50), 1.2), [0.5]],
		["Earthquake", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("earthquake", f + Vector2(0, -120)), [0.8]],
		["Volcano", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("volcano", f + Vector2(150, -60), 0.9), [1.4]],
		["Bramble", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("bramble", f + Vector2(110, -10), 1.2), [0.8]],
		["Spore Puff", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("cone", f + Vector2(60, -26)), [1.0]],
		["Liana", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("vine", f + Vector2(60, -110)), [0.9]],
		["Great Oak", 14, func(f: Vector2) -> PackedVector2Array: return _stroke_from("tree", f + Vector2(90, -2)), [1.2]],
		["Flytrap", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("jaws", Vector2(ArenaGen.column_x(16), f.y - 40.0)), [1.0, 1.9]],
		["Lily Pads", -13, func(f: Vector2) -> PackedVector2Array: return _stroke("pads", Vector2(ArenaGen.column_x(-7), ArenaGen.GROUND_Y - 30.0), 1.6), [0.6]],
		["Decoy", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("eight", f + Vector2(90, -50), 0.8), [0.6]],
		["Eclipse", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("crescent", f + Vector2(110, -60), 1.2), [1.0]],
		["Hex", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("pentagram", Vector2(ArenaGen.column_x(16), f.y - 40.0), 0.8), [0.7]],
		["Abyss", 14, func(f: Vector2) -> PackedVector2Array: return _stroke("spiral", f + Vector2(110, -40), 1.2), [0.9]],
		["Shadow Step", 14, func(f: Vector2) -> PackedVector2Array: return line.call(f + Vector2(0, -20), f + Vector2(140, -20)), [0.1, 0.3]],
	]
	if only != "":
		entries = entries.filter(func(entry: Array) -> bool: return entry[0] == only)
	var t := 0.3
	for entry in entries:
		var spell_name: String = entry[0]
		var col: int = entry[1]
		var stroke_for: Callable = entry[2]
		var photos: Array = entry[3]
		_at(t, func() -> void: _reset_room(col, spell_name))
		_at(t + 0.4, func() -> void:
			_cast(spell_name, stroke_for.call(_feet(col))))
		if spell_name == "Great Oak":
			# A fireball into the tree sets it alight; it burns, creaks, leans and falls.
			_at(t + 1.6, func() -> void: _cast("Ignite", _stroke("flick", _feet(col) + Vector2(60, -45))))
			for k in 6:
				_at(t + 2.2 + k * 1.2, func() -> void: _snap("Great_Oak_burning_%d" % k))
		for k in photos.size():
			_at(t + 0.4 + photos[k], func() -> void: _snap(spell_name.replace(" ", "_") + ("_%d" % k if photos.size() > 1 else "")))
		if only != "":
			for k in 16:
				_at(t + 0.45 + k * 0.1, func() -> void: _snap("%s_%.1f" % [spell_name.replace(" ", "_"), k * 0.1]))
		t += 10.0 if spell_name == "Great Oak" else (5.0 if spell_name == "Tsunami" else 2.4)


## Checks that the spells that work through other things do: smoke cuts sight, a decoy draws attacks, a hex adds damage,
## a Gust turns a shot, a Tsunami puts out fire, lily pads burn over lava, ice bears weight. Each prints PASS or FAIL.
func _plan_checks() -> void:
	var failures := [0]
	var check := func(label: String, ok: bool) -> void:
		print("%s  %s" % ["PASS" if ok else "FAIL", label])
		if not ok:
			failures[0] += 1
	var turret := func() -> Node2D:
		for mob in _arena.get_tree().get_nodes_in_group("mobs"):
			if mob.kind == "turret":
				return mob
		return null
	var dummy := func() -> Node2D:
		for mob in _arena.get_tree().get_nodes_in_group("mobs"):
			if mob.kind == "dummy":
				return mob
		return null
	var tree := _arena.get_tree()
	# Smoke between the turret and the wizard cuts the turret's sight.
	_at(0.3, func() -> void: _reset_room(15, "Smoke Screen"))
	_at(0.5, func() -> void: check.call("the turret sees the wizard with nothing between", not SpellTargets.sight_blocked(tree, turret.call().center(), _player().center())))
	_at(0.7, func() -> void: _cast("Smoke Screen", _stroke("smoke", _feet(18) + Vector2(0, -60))))
	_at(1.5, func() -> void: check.call("smoke between them cuts the turret's sight", SpellTargets.sight_blocked(tree, turret.call().center(), _player().center())))
	_at(1.6, func() -> void: _cast("Gust", _densify(PackedVector2Array([_feet(15) + Vector2(0, -45), _feet(15) + Vector2(160, -45)]))))
	_at(2.2, func() -> void: check.call("a Gust blows the smoke clear", not SpellTargets.sight_blocked(tree, turret.call().center(), _player().center())))
	# A decoy draws a walker's attention.
	_at(3.0, func() -> void: _reset_room(10, "Decoy"))
	_at(3.1, func() -> void:
		var walker: Node2D = _arena._add_mob("fire_melee", _feet(16))
		walker._spawn = 0.0)
	_at(3.2, func() -> void: _cast("Decoy", _stroke("eight", _feet(10) + Vector2(150, -50), 0.8)))
	_at(3.8, func() -> void:
		var walker: Node2D = null
		for mob in tree.get_nodes_in_group("mobs"):
			if mob.kind == "fire_melee":
				walker = mob
		check.call("a walker goes for the decoy instead of the wizard", walker != null and walker._target() is Decoy))
	# A hex adds half again to the damage.
	_at(4.5, func() -> void: _reset_room(14, "Hex"))
	_at(4.7, func() -> void: _cast("Hex", _stroke("pentagram", Vector2(_feet(16).x, _feet(16).y - 40.0), 0.8)))
	_at(5.2, func() -> void:
		var target: Node2D = dummy.call()
		check.call("a hexed dummy takes 1.5 times the damage", Hex.multiplier(tree, target) == 1.5 and Hex.multiplier(tree, _player()) == 1.0))
	# A Gust turns a shot round.
	_at(6.0, func() -> void: _reset_room(14, "Gust"))
	_at(6.2, func() -> void:
		var bolt := EnemyBolt.fire(_arena, _feet(14) + Vector2(160, -45), _feet(14) + Vector2(0, -45), Color.WHITE, 5)
		bolt.add_to_group("test_bolt"))
	_at(6.3, func() -> void: _cast("Gust", _densify(PackedVector2Array([_feet(14) + Vector2(0, -45), _feet(14) + Vector2(120, -45)]))))
	_at(6.7, func() -> void:
		var bolt: Node = tree.get_first_node_in_group("test_bolt")
		check.call("a Gust turns an incoming shot back", bolt == null or bolt.heading().x > 0.0))
	# A Tsunami puts out a firewall.
	_at(7.5, func() -> void: _reset_room(14, "Tsunami"))
	_at(7.7, func() -> void: _cast("Firewall", _stroke("wall", _feet(14) + Vector2(150, -60))))
	_at(8.0, func() -> void: check.call("the firewall is burning", tree.get_nodes_in_group("fires").any(func(n: Node) -> bool: return n is Firewall)))
	_at(8.1, func() -> void: _cast("Tsunami", _stroke("tsunami", _feet(14) + Vector2(0, -130), 1.2)))
	_at(11.0, func() -> void: check.call("a Tsunami puts the firewall out", not tree.get_nodes_in_group("fires").any(func(n: Node) -> bool: return n is Firewall)))
	# Lily pads burn over lava, and hold over the gap.
	_at(12.5, func() -> void: _reset_room(-27, "Lily Pads"))
	_at(12.7, func() -> void: _cast("Lily Pads", _stroke("pads", Vector2(ArenaGen.column_x(-20), ArenaGen.GROUND_Y - 30.0), 1.6)))
	_at(12.9, func() -> void: check.call("lily pads appear over the lava", tree.get_first_node_in_group("lily_pads") != null))
	_at(14.2, func() -> void: check.call("lily pads over lava burn away", tree.get_first_node_in_group("lily_pads") == null))
	_at(14.5, func() -> void: _reset_room(-13, "Lily Pads"))
	_at(14.7, func() -> void: _cast("Lily Pads", _stroke("pads", Vector2(ArenaGen.column_x(-7), ArenaGen.GROUND_Y - 30.0), 1.6)))
	_at(15.4, func() -> void:
		var pad := tree.get_first_node_in_group("lily_pads")
		check.call("lily pads over the gap are still there", pad != null)
		# Stand the wizard just above one of the pads: it must land on it, not fall into the gap.
		var spot: Vector2 = pad._pads[1].global_position
		_player().global_position = spot + Vector2(0, -40))
	_at(16.2, func() -> void:
		var pad := tree.get_first_node_in_group("lily_pads")
		check.call("the wizard stands on a lily pad", pad != null and _player().is_on_floor() and _player().global_position.y < ArenaGen.GROUND_Y))
	# Ice bears weight over the pond.
	_at(17.5, func() -> void: _reset_room(1, "Frost Bridge"))
	_at(17.7, func() -> void: _cast("Frost Bridge", _stroke("wave", Vector2(ArenaGen.column_x(8), ArenaGen.GROUND_Y - 20.0), 1.5)))
	_at(18.3, func() -> void: _player().global_position = Vector2(ArenaGen.column_x(8), ArenaGen.GROUND_Y - 60.0))
	_at(19.2, func() -> void: check.call("the wizard stands on the ice over the pond", _player().is_on_floor() and _player().global_position.y < ArenaGen.GROUND_Y + 4.0))
	# A bramble pricks and slows whoever stands in it, and the spores hurt too.
	_at(19.6, func() -> void: _reset_room(10, "Bramble"))
	_at(19.8, func() -> void: _cast("Bramble", _stroke("bramble", Vector2(_feet(16).x, _feet(16).y - 12.0), 1.4)))
	_at(20.1, func() -> void: dummy.call().global_position = _feet(16))
	_at(21.0, func() -> void:
		var target: Node2D = dummy.call()
		check.call("a bramble pricks the dummy standing in it", target.hp < target.max_hp)
		check.call("a bramble slows the dummy standing in it", target._slow_time > 0.0))
	_at(21.5, func() -> void: _reset_room(15, "Spore Puff"))
	_at(21.7, func() -> void: _cast("Spore Puff", _stroke("cone", _feet(15) + Vector2(60, -40))))
	_at(23.0, func() -> void:
		var spores := tree.get_first_node_in_group("clouds")
		check.call("spores pour out of the mouth and hang in the air", spores is SporePuff and not spores._puffs.is_empty())
		check.call("spores hurt the dummy they drift over", tree.get_nodes_in_group("mobs").any(func(m: Node) -> bool: return m.kind == "dummy" and m.hp < m.max_hp)))
	# A fire shot dropped into water goes out.
	_at(23.5, func() -> void: _reset_room(2, "Ignite"))
	_at(23.7, func() -> void:
		var ball := LavaBall.throw(_arena, Vector2(ArenaGen.column_x(8), ArenaGen.GROUND_Y - 80.0), Vector2.ZERO)
		ball.add_to_group("test_ball"))
	_at(24.5, func() -> void: check.call("water puts out a falling lava ball", tree.get_first_node_in_group("test_ball") == null))
	# Smoke only cuts sight when it is between the two.
	_at(25.0, func() -> void: _reset_room(15, "Smoke Screen"))
	_at(25.2, func() -> void: _cast("Smoke Screen", _stroke("smoke", _feet(8) + Vector2(0, -60))))
	_at(26.0, func() -> void: check.call("smoke off to one side does not cut the turret's sight", not SpellTargets.sight_blocked(tree, turret.call().center(), _player().center())))
	_at(26.5, func() -> void:
		print("%d checks failed" % failures[0])
		_exit_code = 1 if failures[0] > 0 else 0)


## Grows a vine, stands the wizard at it and holds W: the wizard should climb it. The heights are printed, since a
## climb is something to measure rather than to look at.
func _plan_climb() -> void:
	_at(0.3, func() -> void: _reset_room(14, "Liana"))
	_at(0.7, func() -> void: _cast("Liana", _stroke("vine", _feet(14) + Vector2(60, -110))))
	_at(1.6, func() -> void:
		var vine: Node2D = _arena.get_tree().get_first_node_in_group("climbables")
		print("vine from y=%.0f to y=%.0f at x=%.0f" % [vine.top_y(), vine.bottom_y(), vine.vine_x()])
		_player().global_position = Vector2(vine.vine_x(), vine.bottom_y()))
	_at(1.8, func() -> void: _hold_key(KEY_W, true))
	for k in 8:
		_at(2.0 + k * 0.25, func() -> void: print("climbing: wizard at y=%.0f" % _player().global_position.y))
	_at(3.4, func() -> void: _snap("climbing"))
	_at(3.6, func() -> void:
		_hold_key(KEY_W, false)
		_hold_key(KEY_S, true))
	_at(4.6, func() -> void: print("after S: wizard at y=%.0f" % _player().global_position.y))
	_at(4.7, func() -> void: _hold_key(KEY_S, false))


## Presses or releases a key as if the player had.
func _hold_key(keycode: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = down
	Input.parse_input_event(event)


## Puts the room back as it was and the wizard in a column, ready for the next spell.
func _reset_room(col: int, spell_name: String) -> void:
	for group in ["lasting", "walls", "rocks", "fires", "flora", "clouds", "decoys", "hexes", "shots", "flares", "eclipses", "mobs"]:
		for node in _arena.get_tree().get_nodes_in_group(group):
			if not node is Pond:
				node.queue_free()
	for node in _arena.get_children():
		if node is SpellEffect or node is Tornado or node is Volcano or node is Hazard or node is Mudslide or node is IcePrison or node is Abyss or node is FireBreath or node is Earthquake:
			node.queue_free()
	for pond in _arena.get_tree().get_nodes_in_group("ponds"):
		for slab in pond._slabs:
			slab["age"] = 999.0
	_arena._add_targets()
	for mob in _arena.get_tree().get_nodes_in_group("mobs"):
		mob._spawn = 0.0
		mob.modulate.a = 1.0
	var player: Node2D = _player()
	player.global_position = _feet(col)
	player.velocity = Vector2.ZERO
	player.facing = 1.0
	player.get_node("Camera2D").reset_smoothing()
	_arena._night.visible = spell_name in ["Flare", "Eclipse"]
	_arena._player_light.enabled = _arena._night.visible


## A Push drawn round a point, then out to the right.
func _push_stroke(around: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(around + Vector2.from_angle(PI + TAU * i / 32.0) * 40.0)
	pts.append(around + Vector2(-40, 0) + Vector2(140, 0))
	return _densify(pts)


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
