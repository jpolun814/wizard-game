extends Node

## Plays a scripted scene in the real game and saves screenshots, so the look of the game can be checked without
## playing it by hand. Run from the project folder with a window (not headless), for example:
##     godot --path . tests/showcase.tscn -- scenario=spells out=C:/temp/shots
## Scenarios:
##   world   - every enemy kind standing around the player, with their health bars
##   cave    - a generated world: the start hall, then the wizard climbing a shaft by jumping from platform to platform
##   spells  - every spell cast in turn in the waiting room, with screenshots of each
##   wizard  - the dark wizard dueling a player who stands still and throws bolts at it
## Fixed physics steps make it play the same way each time.

var scenario := "world"
var out_dir := "user://shots"
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
				"only":
					only = parts[1].replace("_", " ")
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps running while the game is paused
	DirAccess.make_dir_recursive_absolute(out_dir)
	# The spells are tried in the waiting room, where there is a pond, a gap and dummies for each of them.
	var scene := "world" if scenario in ["cave", "gates", "castle", "pages", "tornado", "extras"] else "lab"
	if scenario in ["cave", "gates", "castle", "pages", "tornado", "extras"]:
		World.random_start = false
		World.next_seed = int(OS.get_environment("WORLD_SEED")) if OS.get_environment("WORLD_SEED") != "" else 11  # the same world each time
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
	_arena.caster.cast_stroke(SpellData.SPELLS[spell_name].buttons, stroke)


func _summon_at(kind: String, x: float) -> Node2D:
	var ground := SpellTargets.solid_below(_arena.get_world_2d(), Vector2(x, ArenaGen.GROUND_Y - 4.0 * ArenaGen.TILE))
	return _arena._add_mob(kind, ground)


func _plan() -> void:
	_player().max_stamina = 9999.0  # nothing ends the showcase early
	_player().died.connect(func() -> void:
		for gate in (_arena._gates if "_gates" in _arena else []):
			if absf(gate["at"].x * 32.0 - _player().global_position.x) < 1500.0 and absf(gate["at"].y * 32.0 - _player().global_position.y) < 1000.0:
				print("  DEBUG near gate ", gate["kind"], gate["at"]))
	_player().died.connect(func() -> void: print("  DEBUG the wizard died at %s, max %s, underwater %s, t=%.1f" % [str(_player().global_position), str(_player().max_stamina), str(_player().underwater()), _t]))
	if scenario == "cave":
		for q in range(1, 400):  # the checks walk through gates; a wizard nearly spent is filled up again, so none ends the run
			_at(q * 1.0, func() -> void:
				if _player().max_stamina < 100.0 and not _player().dead:
					_player().max_stamina = 9999.0
					_player().stamina = 9999.0)
	if scenario != "pages" and _arena.has_method("learn_every_page"):
		_arena.learn_every_page()  # the checks cast whatever they need
	match scenario:
		"gates":
			_plan_gates()
		"castle":
			var tile := float(ArenaGen.TILE)
			var ground_y := WorldGraph.SURFACE_ROW * tile
			var views := [["gate", -8.0, 0.0, 1.0], ["entry", 8.0, 0.0, 1.0], ["hall", 26.0, 0.0, 1.0], ["first", 26.0, 11.0, 1.0], ["first2", 66.0, 11.0, 1.0],
					["great", 50.0, 22.0, 1.0], ["great2", 90.0, 22.0, 1.0], ["back", 126.0, 0.0, 1.0], ["whole", 68.0, 20.0, 0.2], ["roofwest", 22.0, 24.0, 0.6]]
			var t := 0.6
			for view: Array in views:
				var at := Vector2((_arena.castle_x + view[1]) * tile, ground_y - (view[2] + 1.0) * tile)
				var name: String = view[0]
				var zoom: float = view[3]
				_at(t, func() -> void:
					_player().global_position = at
					_player().velocity = Vector2.ZERO
					_arena._dark.hide()
					_arena._ground.watch([at] as Array[Vector2], true)
					_arena.get_node("Player/Camera2D").zoom = Vector2(zoom, zoom)
					_arena.get_node("Player/Camera2D").reset_smoothing())
				_at(t + 1.2, func() -> void: _snap(name))
				t += 1.8
			# The rope ladders: climb the first (ground to first floor) and the last (first to second floor).
			var ladders: Array = _arena._castle_ladders
			var press := func(code: Key, down: bool) -> void:
				var event := InputEventKey.new()
				event.keycode = code
				event.physical_keycode = code
				event.pressed = down
				Input.parse_input_event(event)
			for pick in [0, ladders.size() - 1]:
				var entry: Dictionary = ladders[pick]
				_at(t, func() -> void:
					var at := Vector2((entry["x"] + 1) * tile, entry["bottom"] * tile - 4.0)
					_player().global_position = at
					_player().velocity = Vector2.ZERO
					_arena._ground.watch([at] as Array[Vector2], true)
					_arena._dark.hide()
					_arena.get_node("Player/Camera2D").reset_smoothing()
					press.call(KEY_W, true))
				_at(t + 4.0, func() -> void:
					var feet: float = _player().global_position.y
					var top_y: float = entry["top"] * tile
					var ok: bool = feet < top_y + 6.0
					print("%s  the rope ladder lifts the wizard to the floor above (feet %d, floor %d)" % ["PASS" if ok else "FAIL", int(feet), int(top_y)])
					if not ok:
						_exit_code = 1
					_snap("ladder")
					press.call(KEY_W, false)
					Input.action_press("move_right"))
				_at(t + 4.6, func() -> void:
					Input.action_release("move_right"))
				_at(t + 6.0, func() -> void:
					var feet: float = _player().global_position.y
					var top_y: float = entry["top"] * tile
					var ok: bool = absf(feet - top_y) < 6.0 and _player().is_on_floor()
					print("%s  and steps off onto it (feet %d, floor %d)" % ["PASS" if ok else "FAIL", int(feet), int(top_y)])
					if not ok:
						_exit_code = 1)
				t += 7.0
		"tornado":
			var flung := {"up": 0.0, "side": []}
			for k in 4:
				_at(1.0 + k * 3.0, func() -> void:
					var wizard: Node2D = _player()
					wizard.velocity = Vector2.ZERO
					var storm := Tornado.new()
					_arena.add_child(storm)
					storm.global_position = wizard.global_position + Vector2(0, -60)
					storm.set_physics_process(true))
				_at(1.0 + k * 3.0 + 0.5, func() -> void:
					var wizard: Node2D = _player()
					flung["up"] = minf(flung["up"], wizard.velocity.y)
					flung["side"].append(wizard.velocity.x))
			_at(14.0, func() -> void:
				var sides: Array = flung["side"]
				var ok: bool = flung["up"] < -300.0
				print("%s  a tornado throws whoever is in it upward (best %d), sideways by chance (%s)" % ["PASS" if ok else "FAIL", int(flung["up"]), str(sides)])
				if not ok:
					_exit_code = 1)
		"extras":
			# The castle door, a steered decoy, the F1 gate teleports, a flare in water, the bonfire and the Insight list.
			var tile := float(ArenaGen.TILE)
			var box := []  # the westmost door, once the world is built
			var key := func(code: Key, down: bool) -> void:
				var event := InputEventKey.new()
				event.keycode = code
				event.physical_keycode = code
				event.pressed = down
				Input.parse_input_event(event)
			var put := func(at: Vector2) -> void:
				_player().global_position = at
				_player().velocity = Vector2.ZERO
				_arena._ground.watch([at] as Array[Vector2], true)  # the ground there is built before the wizard stands on it
				_arena._safe_spot = at
				_arena._dark.hide()
				_arena.get_node("Player/Camera2D").zoom = Vector2(1.0, 1.0)
				_arena.get_node("Player/Camera2D").reset_smoothing()
			var west := func() -> Vector2:  # on the ground west of the castle gate
				var x: float = box[0].global_position.x - 330.0
				return SpellTargets.solid_below(_arena.get_world_2d(), Vector2(x, box[0].global_position.y - 700.0), 1400.0) + Vector2(0, -4)
			var verdict := func(ok: bool, text: String) -> void:
				print("%s  %s" % ["PASS" if ok else "FAIL", text])
				if not ok:
					_exit_code = 1
			_at(0.3, func() -> void:
				var doors: Array = []
				for node in _arena.get_children():
					if node is CastleDoor:
						doors.append(node)
				doors.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.x < b.global_position.x)
				box.append(doors[0]))
			_at(0.5, func() -> void: put.call(west.call()))
			_at(1.5, func() -> void:
				verdict.call(box[0]._swing < 0.05, "the door is shut with no one near it (%.2f)" % box[0]._swing)
				verdict.call(not box[0]._shape.disabled, "and it is solid")
				_snap("door_shut")
				put.call(box[0].global_position + Vector2(-90, -10)))
			_at(1.85, func() -> void: _snap("door_swinging"))
			_at(3.0, func() -> void:
				verdict.call(box[0]._swing > 0.95, "the door is wide open with someone at it (%.2f)" % box[0]._swing)
				verdict.call(box[0]._shape.disabled, "and it lets them through")
				_snap("door_open")
				put.call(west.call()))
			_at(6.5, func() -> void:
				verdict.call(box[0]._swing < 0.05 and not box[0]._shape.disabled, "the door shuts again when they have gone (%.2f)" % box[0]._swing))
			# The decoy walks with the arrow keys.
			var decoy := []
			_at(7.0, func() -> void:
				var made := Decoy.new()
				_arena.add_child(made)
				made.global_position = _player().global_position + Vector2(60, 0)
				decoy.append(made)
				decoy.append(made.global_position.x))
			_at(7.4, func() -> void: key.call(KEY_RIGHT, true))
			_at(8.4, func() -> void:
				var moved: float = decoy[0].global_position.x - decoy[1]
				verdict.call(moved > 120.0, "the right arrow walks the decoy (%d px)" % int(moved))
				_snap("decoy")
				key.call(KEY_RIGHT, false)
				decoy.append(decoy[0].global_position.x))
			_at(9.2, func() -> void:
				var drift: float = absf(decoy[0].global_position.x - decoy[2])
				verdict.call(drift < 6.0, "and it stops when the key is let go (%d px)" % int(drift))
				key.call(KEY_LEFT, true))
			_at(10.0, func() -> void:
				verdict.call(decoy[0].global_position.x < decoy[2] - 80.0, "the left arrow walks it back")
				key.call(KEY_LEFT, false))
			# The F1 teleports.
			var t := 11.0
			for kind in WorldGraph.GATES:
				_at(t, func() -> void:
					_arena.go_to_gate(kind)
					_arena._dark.hide())
				_at(t + 0.4, func() -> void:
					var near := 1e9
					for entry in _arena._gates:
						if entry["kind"] == kind:
							near = minf(near, (Vector2(entry["at"]) * tile).distance_to(_player().global_position))
					if near == 1e9:
						return  # this world has no gate of the kind: with fewer halls a seed holds only some of the nine
					verdict.call(near < 2000.0 and not _player().dead, "F1 takes the wizard to a %s gate (%d px away)" % [kind, int(near)]))
				t += 0.6
			# A wall gate comes down under boulders; an earthquake brings down a wall too.
			var wall := []
			_at(t, func() -> void:
				_arena.go_to_gate("wall")
				_arena._dark.hide()
				var nearest := 1e9
				for node in _arena.get_children():
					if node is RockWall and node._box.get_center().distance_to(_player().global_position) < nearest:
						nearest = node._box.get_center().distance_to(_player().global_position)
						wall.assign([node]))
			_at(t + 0.5, func() -> void: verdict.call(not wall.is_empty(), "the wall gate stands in the passage as a wall that can be broken"))
			for k in 4:
				_at(t + 1.0 + k * 2.5, func() -> void:
					if wall.is_empty() or not is_instance_valid(wall[0]):
						return
					for old in get_tree().get_nodes_in_group("rocks"):
						old.queue_free()  # the last one has done its work; a new one lands on the wall, not on it
					var rock := Boulder.new()
					rock.global_position = Vector2(wall[0]._box.get_center().x, wall[0]._box.position.y - 90.0)
					_arena.add_child(rock))
			_at(t + 12.0, func() -> void:
				verdict.call(not wall.is_empty() and not is_instance_valid(wall[0]), "boulders break the wall down")
				_snap("wall_down"))
			t += 13.0
			var quake_wall := []
			_at(t, func() -> void:
				var made := RockWall.new()
				var x := int(_player().global_position.x / 32.0) + 4
				var row := int(_player().global_position.y / 32.0)
				made.columns = [{"x": x, "top": row - 6, "bottom": row + 1}]
				_arena.add_child(made)
				quake_wall.append(made)
				var shake := Earthquake.new()
				_arena.add_child(shake))
			_at(t + 7.5, func() -> void: verdict.call(not is_instance_valid(quake_wall[0]), "an earthquake brings a wall down"))
			t += 8.0
			# A flare goes out in water.
			var pond: Pond = null
			for candidate in get_tree().get_nodes_in_group("ponds"):
				if not candidate.lava and candidate.width > 150.0:
					pond = candidate
					break
			var flare := []
			_at(t, func() -> void:
				put.call(pond.global_position + Vector2(pond.width * 0.5, pond.depth * 0.5)))
			_at(t + 0.3, func() -> void:
				var made := Flare.new()
				made.caster_node = _player()
				_arena.add_child(made)
				made.global_position = _player().global_position + Vector2(0, -20)
				flare.append(made))
			_at(t + 1.5, func() -> void:
				verdict.call(not is_instance_valid(flare[0]) or flare[0].is_queued_for_deletion(), "a flare goes out in water"))
			t += 2.5
			# The bonfire stands beside the wizard, on logs, not under them.
			_at(t, func() -> void:
				put.call(west.call()))
			_at(t + 1.0, func() -> void: _arena._on_ritual_finished("bonfire", 1.0, false))
			_at(t + 2.2, func() -> void:
				var fire: Node2D = null
				for node in _arena.get_children():
					if node is Bonfire:
						fire = node
				var gap := 0.0 if fire == null else absf(fire.global_position.x - _player().global_position.x)
				verdict.call(fire != null and gap > 40.0, "the bonfire stands beside the wizard (%d px)" % int(gap))
				_snap("bonfire"))
			t += 3.0
			# Insight lists a dark wizard's spells.
			_at(t, func() -> void:
				_arena._revealed["insight"] = true
				var wizard := _summon_at("dark_wizard", _player().global_position.x + 200.0)
				wizard.set_physics_process(false)
				wizard.global_position = _arena.get_global_mouse_position() - (wizard.center() - wizard.global_position))
			_at(t + 0.5, func() -> void:
				_arena._update_insight()
				verdict.call(_arena._insight_tip.visible and "Knows" in _arena._insight_text.text, "Insight lists what a dark wizard knows")
				_snap("insight"))
		"pages":
			var tile := float(ArenaGen.TILE)
			var pickups := get_tree().get_nodes_in_group("pages")
			print("%s  pages lie on the map (%d), and only the starter spells are known (%d of %d)" % ["PASS" if pickups.size() > 25 and Pages.known.size() == 5 else "FAIL", pickups.size(), Pages.known.size(), Pages.every().size()])
			var near := 1e9
			for pickup: PagePickup in pickups:
				if pickup.global_position.y < float(WorldGraph.SURFACE_ROW + 6) * tile:
					near = minf(near, absf(pickup.global_position.x - float(_arena.graph.surface["start"]) * tile))
			print("%s  the nearest page is %d px from the start, under a minute's walk" % ["PASS" if near < 3000.0 else "FAIL", near])
			var buried := 0
			for pickup: PagePickup in pickups:
				var floor_y: float = _arena._floor_under(pickup.global_position).y
				if absf(floor_y - pickup.global_position.y) > 2.0 or _arena._in_rock(pickup.global_position + Vector2(0, -16.0)):
					buried += 1
			print("%s  every page lies on the floor, out of the rock (%d off)" % ["PASS" if buried == 0 else "FAIL", buried])
			if buried > 0:
				_exit_code = 1
			var first: PagePickup = pickups[0]
			var page := first.page
			var holder := [first]
			_at(0.6, func() -> void:
				_player().global_position = first.global_position + Vector2(-120, -10)
				_arena._ground.watch([first.global_position] as Array[Vector2], true)
				_arena._dark.hide()
				_arena.get_node("Player/Camera2D").reset_smoothing())
			_at(2.0, func() -> void: _snap("page"))
			_at(2.2, func() -> void:
				_player().global_position = first.global_position + Vector2(-60, -4)
				Input.action_press("move_right"))
			_at(2.4, func() -> void: Input.action_release("move_right"))
			_at(2.8, func() -> void:
				var before_tab: bool = Pages.knows(page)
				print("  wizard walked to %s, the page lies at %s" % [str(_player().global_position), str(first.global_position)])
				var under: bool = first.is_underfoot()
				print("%s  a wizard who has walked onto a page stands on it, and it is not read yet" % ["PASS" if under and not before_tab else "FAIL"])
				if before_tab or not under:
					_exit_code = 1
				_snap("hint")
				var tab := InputEventKey.new()
				tab.keycode = KEY_TAB
				tab.physical_keycode = KEY_TAB
				tab.pressed = true
				Input.parse_input_event(tab))
			_at(4.5, func() -> void: _snap("read"))
			_at(5.0, func() -> void:
				var ok: bool = Pages.knows(page) and not is_instance_valid(holder[0]) and _arena.spellbook.visible
				print("%s  pressing Tab on a page reads it (%s), takes it off the map and opens the book" % ["PASS" if ok else "FAIL", page])
				if not ok:
					_exit_code = 1
				var before := get_tree().get_nodes_in_group("pages").size()
				_arena.learn_every_page()
				var after := get_tree().get_nodes_in_group("pages").size()
				var all: bool = Pages.known.size() == Pages.every().size() and Pages.knows_chant("recall")
				print("%s  the F1 button gives every spell and leaves the pages on the map (%d, then %d)" % ["PASS" if all and before == after else "FAIL", before, after])
				if not (all and before == after):
					_exit_code = 1)
			_at(5.4, func() -> void: _arena.spellbook._toggle())  # shuts the book
			_at(6.8, func() -> void:
				var other: PagePickup = get_tree().get_nodes_in_group("pages")[0]
				_player().global_position = other.global_position + Vector2(0, -4)
				_arena._ground.watch([other.global_position] as Array[Vector2], true))
			_at(7.8, func() -> void:
				var tab := InputEventKey.new()
				tab.keycode = KEY_TAB
				tab.physical_keycode = KEY_TAB
				tab.pressed = true
				Input.parse_input_event(tab))
			_at(9.2, func() -> void:
				var kept := get_tree().get_nodes_in_group("pages").size()
				var ok: bool = _arena.spellbook.visible and kept > 40
				print("%s  Tab on a page the book already has opens the book and leaves the page (%d pages)" % ["PASS" if ok else "FAIL", kept])
				if not ok:
					_exit_code = 1
				_snap("known"))
		"water":
			# Wading, then diving, in the pond and the lava pit: only the part under the surface takes the colour.
			var spots := [[8, 0.0], [8, 30.0], [8, 90.0], [-20, 30.0]]
			for i in spots.size():
				_at(0.5 + i * 0.8, func() -> void:
					var x: float = ArenaGen.column_x(spots[i][0])
					_player().global_position = Vector2(x, ArenaGen.GROUND_Y + spots[i][1] + 30.0)
					_player().velocity = Vector2.ZERO)
				_at(0.9 + i * 0.8, func() -> void: _snap("dip"))
			_at(5.0, func() -> void:
				_player().global_position = Vector2(ArenaGen.column_x(8), ArenaGen.GROUND_Y + 90.0))
			_at(11.5, func() -> void:
				print("breath ", _player().breath, " max ", _player().max_stamina)
				_snap("drowning"))
		"world":
			_at(0.4, func() -> void:
				var x: float = _player().global_position.x
				var kinds := ["fire_melee", "ice_ranged", "earth_melee", "storm_flyer", "force_ranged", "dark_wizard", "pyre_wizard", "bone_wizard", "ninja"]
				for i in kinds.size():
					var mob := _summon_at(kinds[i], x + (i - 4.5) * 90.0)
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
		"cave":
			_plan_cave()
		"kinds":
			# Every enemy kind in a row, frozen in place, to check colours and sizes.
			_at(0.3, func() -> void:
				var x: float = _player().global_position.x - 330.0
				var i := 0
				for kind in Mob.KINDS:
					if Mob.KINDS[kind].role == "flyer":
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
		"newspells":
			_plan_new_spells()
		"book":
			# Every spread of the spellbook, one after another.
			_at(0.3, func() -> void: _arena.spellbook.visible = true)
			var shown := [0, 1, 2, 8, 17, 19, 20, 21, 22]
			for n in shown.size():
				var k: int = shown[n]
				_at(0.6 + n * 0.5, func() -> void:
					_arena.spellbook._spread = k
					_arena.spellbook._show_spread())
				_at(0.9 + n * 0.5, func() -> void: _snap("spread_%d" % k))
		"ui":
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
				_player().max_stamina = 5.0
				_player()._grace = 0.0
				_player().take_damage(10))
			_at(5.8, func() -> void: _snap("game_over"))
		"wizard":
			_plan_wizard()
		"soak":
			# A few enemies stand about while the player, who cannot die, casts random spells at random spots. Only
			# errors in the output matter; run it headless.
			for kind in ["fire_melee", "ice_ranged", "earth_melee", "storm_flyer", "ninja", "dark_wizard"]:
				_summon_at(kind, _player().global_position.x + randf_range(-300.0, 300.0))
			var rng := RandomNumberGenerator.new()
			rng.seed = 2
			var names := SpellData.SPELLS.keys()
			for i in 40:
				_at(0.5 + i * 0.3, func() -> void:
					var spell_name: String = names[rng.randi() % names.size()]
					var gesture: String = SpellData.SPELLS[spell_name].preview if SpellData.SPELLS[spell_name].preview != "" else SpellData.SPELLS[spell_name].gesture
					var spot: Vector2 = _player().global_position + Vector2(rng.randf_range(-250.0, 250.0), rng.randf_range(-160.0, -20.0))
					if gesture == "stone_wall":
						spot.y = ArenaGen.GROUND_Y - 40.0
					_cast(spell_name, _stroke(gesture, spot, rng.randf_range(0.8, 1.3)))
					_player().max_stamina = 9999.0)
			_at(13.0, func() -> void: print("soak done, %d enemies left" % [_arena.get_tree().get_nodes_in_group("mobs").size()]))
		"brawl":
			# A mixed group comes for a player who stands still, to watch them chase, wind up, shoot and dive.
			_at(0.3, func() -> void:
				var x: float = _player().global_position.x
				for entry in [["ninja", -180.0], ["giant", 260.0], ["pyre_wizard", -330.0], ["bone_wizard", 420.0], ["fire_melee", 120.0]]:
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


## The Blood school and the newer spells (Glowcap, Moonbeam, Tide Surf, Obsidian Armor), each cast in the waiting room and judged on what it
## does, with pictures.
func _plan_new_spells() -> void:
	var failures := [0]
	var check := func(label: String, ok: bool) -> void:
		print("%s  %s" % ["PASS" if ok else "FAIL", label])
		if not ok:
			failures[0] += 1
			_exit_code = 1
	var tree := _arena.get_tree()
	var wizard := _player()
	var dummy := func() -> Node2D:
		for mob in tree.get_nodes_in_group("mobs"):
			if mob.kind == "dummy" and not mob.is_queued_for_deletion():  # not one the reset has just let go of
				return mob
		return null
	var line := func(a: Vector2, b: Vector2) -> PackedVector2Array: return _densify(PackedVector2Array([a, b]))
	var memo := {}
	var reset := func(col: int, spell_name: String) -> void:  # the waiting room as it is, less its turret, with stamina that can run out
		_reset_room(col, spell_name)
		var kept := false
		for mob in tree.get_nodes_in_group("mobs"):
			if mob.is_queued_for_deletion():
				continue
			if mob.kind == "turret" or (mob.kind == "dummy" and kept):
				mob.queue_free()  # one dummy is enough, and nothing shoots back
			elif mob.kind == "dummy":
				kept = true
		wizard.infinite_time = 0.0
	_arena._since_hurt = -100000.0  # the waiting room heals a wizard after a few seconds; here the damage has to stay
	_arena.caster.feedback.connect(func(t: String, _c: Color) -> void: print("  feedback: ", t))
	# Blood Bolt: 30 damage, paid for in maximum stamina.
	_at(0.5, func() -> void:
		reset.call(15, "Blood Bolt")
		wizard.max_stamina = 200.0
		wizard.stamina = 200.0
		dummy.call().global_position = _feet(19)
		memo["hp"] = dummy.call().hp)
	_at(0.8, func() -> void: _cast("Blood Bolt", line.call(_feet(15) + Vector2(0, -40), _feet(15) + Vector2(100, -40))))
	_at(1.5, func() -> void:
		check.call("a Blood Bolt costs 12 of the maximum stamina (max %d)" % wizard.max_stamina, absf(wizard.max_stamina - 188.0) < 0.5)
		check.call("a Blood Bolt does 30 damage (hp %d -> %d)" % [memo["hp"], dummy.call().hp], memo["hp"] - dummy.call().hp == 30)
		_snap("blood_bolt"))
	# A spent wizard cannot pay: blood is never spent to the last drop.
	_at(2.0, func() -> void:
		wizard.max_stamina = 9.0
		wizard.stamina = 9.0)
	_at(2.1, func() -> void: _cast("Blood Bolt", line.call(_feet(15) + Vector2(0, -40), _feet(15) + Vector2(100, -40))))
	_at(2.3, func() -> void: check.call("a wizard with too little maximum stamina is refused (max %d)" % wizard.max_stamina, wizard.max_stamina == 9.0))
	# Transfusion: the foe loses 20, the caster's stamina comes back.
	_at(2.6, func() -> void:
		reset.call(15, "Transfusion")
		wizard.max_stamina = 200.0
		dummy.call().global_position = _feet(19)
		memo["hp"] = dummy.call().hp)
	_at(3.0, func() -> void:
		wizard.stamina = 20.0
		_arena.caster.cast_stroke(SpellData.SPELLS["Transfusion"].buttons, _stroke("circle", _feet(19) + Vector2(0, -30), 0.9)))  # not _cast, which fills the stamina first
	_at(3.6, func() -> void:
		check.call("a Transfusion takes 20 from the foe (hp %d -> %d)" % [memo["hp"], dummy.call().hp], memo["hp"] - dummy.call().hp >= 20)
		check.call("and gives the caster stamina back (%d)" % wizard.stamina, wizard.stamina >= 55.0)
		_snap("transfusion"))
	# Adrenaline: hasted and recovering quicker.
	_at(4.0, func() -> void: reset.call(15, "Adrenaline"))
	_at(4.2, func() -> void: _cast("Adrenaline", _stroke("zigzag", _feet(15) + Vector2(60, -80), 1.0)))
	_at(4.5, func() -> void:
		check.call("Adrenaline hastes the wizard and quickens recovery", wizard.adrenaline_time > 5.0 and wizard.haste_time > 5.0)
		_snap("adrenaline"))
	# Hemorrhage: a wound that bleeds the wizard's stamina and never the most they can have.
	_at(5.0, func() -> void:
		reset.call(15, "Hemorrhage")
		wizard.max_stamina = 200.0
		wizard.stamina = 150.0
		wizard.adrenaline_time = 0.0
		memo["max"] = wizard.max_stamina)
	_at(5.2, func() -> void: _cast("Hemorrhage", _stroke("cross", wizard.center() + Vector2(0, -4), 0.8)))
	_at(5.25, func() -> void: wizard.stamina = 150.0)
	_at(6.2, func() -> void:
		check.call("a wound bleeds the wizard's current stamina (%d)" % wizard.stamina, Bleed.of(tree, wizard) != null and wizard.stamina < 148.0)
		check.call("and never the maximum (%d)" % wizard.max_stamina, wizard.max_stamina == memo["max"] - 10.0)
		_snap("bleeding"))
	# Clot closes it.
	_at(6.4, func() -> void: _cast("Clot", _stroke("wall", wizard.center(), 1.0)))
	_at(6.7, func() -> void: check.call("a Clot closes the wound", Bleed.of(tree, wizard) == null))
	# A bleeding dummy loses health; fire cauterizes the wound.
	_at(7.0, func() -> void:
		reset.call(15, "Hemorrhage")
		wizard.max_stamina = 200.0
		dummy.call().global_position = _feet(19)
		memo["hp"] = dummy.call().hp)
	_at(7.2, func() -> void: _cast("Hemorrhage", _stroke("cross", _feet(19) + Vector2(0, -30), 0.8)))
	_at(9.2, func() -> void: check.call("a plain foe bleeds health (hp %d -> %d)" % [memo["hp"], dummy.call().hp], dummy.call().hp < memo["hp"]))
	_at(9.3, func() -> void: Hazard.place(_arena, dummy.call().global_position, 80.0, 3.0))
	_at(9.6, func() -> void: check.call("fire seals the wound", Bleed.of(tree, dummy.call()) == null))
	# Faint: the wizard drops, and stands up again once stamina has come back to 10.
	_at(11.0, func() -> void:
		reset.call(15, "Faint")
		wizard.max_stamina = 200.0
		wizard.stamina = 150.0
		memo["max"] = wizard.max_stamina)
	_at(11.2, func() -> void: _cast("Faint", _stroke("spiral", wizard.center(), 1.0)))
	_at(11.5, func() -> void:
		check.call("a Faint drops the wizard with no stamina and the maximum kept (max %d, stamina %d)" % [wizard.max_stamina, wizard.stamina], wizard.fainted and wizard.stamina < 10.0 and wizard.max_stamina == memo["max"] - 30.0)
		_snap("fainted"))
	_at(12.0, func() -> void:
		var pos: Vector2 = wizard.global_position
		Input.action_press("move_right")
		memo["x"] = pos.x)
	_at(12.4, func() -> void:
		Input.action_release("move_right")
		check.call("a fainted wizard cannot walk", absf(wizard.global_position.x - memo["x"]) < 5.0))
	_at(14.5, func() -> void: check.call("and stands up once the stamina is back (stamina %d)" % wizard.stamina, not wizard.fainted and wizard.stamina >= 10.0))
	# Faint on a foe.
	_at(15.0, func() -> void:
		reset.call(15, "Faint")
		wizard.max_stamina = 200.0
		dummy.call().global_position = _feet(19))
	_at(15.2, func() -> void: _cast("Faint", _stroke("spiral", _feet(19) + Vector2(0, -30), 1.0)))
	_at(15.5, func() -> void: check.call("a Faint drops a foe", dummy.call().is_fainted()))
	_at(18.5, func() -> void: check.call("and the foe gets up again", not dummy.call().is_fainted()))
	# Glowcap: a mushroom on the hat that is a light, and a second one replaces it.
	_at(19.0, func() -> void:
		reset.call(15, "Glowcap")
		wizard.max_stamina = 200.0)
	_at(19.2, func() -> void: _cast("Glowcap", _stroke("circle", _feet(15) + Vector2(80, -60), 1.0)))
	_at(19.8, func() -> void:
		var caps := tree.get_nodes_in_group("glowcaps")
		check.call("a Glowcap grows on the hat", caps.size() == 1 and caps[0].global_position.distance_to(wizard.global_position + Vector2(0, -80)) < 14.0)
		check.call("and lights what is hidden near it", SpellTargets.lit_near(tree, wizard.global_position + Vector2(100, 0), 20.0) and not SpellTargets.lit_near(tree, wizard.global_position + Vector2(900, 0), 20.0))
		_snap("glowcap"))
	_at(20.0, func() -> void:
		wizard.focus = "staff"
		_cast("Glowcap", _stroke("circle", _feet(15) + Vector2(80, -60), 1.0)))
	_at(20.6, func() -> void:
		check.call("a second Glowcap replaces the first, and sits on the staff", tree.get_nodes_in_group("glowcaps").size() == 1)
		_snap("glowcap_staff")
		wizard.focus = "wand")
	# Moonbeam: a dim light on the ground where it was drawn.
	_at(21.0, func() -> void:
		reset.call(15, "Moonbeam")
		_arena._night.visible = true
		_arena._player_light.enabled = true)
	_at(21.2, func() -> void: _cast("Moonbeam", _stroke("wall", _feet(15) + Vector2(200, -60), 1.0)))
	_at(22.0, func() -> void:
		var beams := tree.get_nodes_in_group("moonbeams")
		check.call("a Moonbeam stands on the ground where it was drawn", beams.size() == 1 and absf(beams[0].global_position.x - (_feet(15).x + 200.0)) < 40.0)
		check.call("it lights its patch of the ground, dimly", beams.size() == 1 and SpellTargets.lit_near(tree, beams[0].global_position, 20.0) and not SpellTargets.lit_near(tree, beams[0].global_position + Vector2(400, 0), 20.0))
		_snap("moonbeam"))
	# Tide Surf: a wave carries the wizard, and the foe in its way is shoved.
	_at(22.5, func() -> void:
		reset.call(15, "Tide Surf")
		wizard.max_stamina = 200.0
		memo["x"] = wizard.global_position.x
		dummy.call().global_position = _feet(19)
		memo["dx"] = dummy.call().global_position.x)
	_at(22.7, func() -> void: _cast("Tide Surf", _stroke("tsunami", wizard.center() + Vector2(0, -20), 1.0)))
	_at(23.5, func() -> void:
		check.call("a wave carries the wizard along (moved %d px)" % (wizard.global_position.x - memo["x"]), wizard.global_position.x - memo["x"] > 200.0 and wizard.surf_time > 2.0)
		_snap("tide_surf"))
	_at(23.9, func() -> void: wizard.surf_time = 0.0)  # the portal at the far end of the room starts a run
	_at(24.6, func() -> void:
		check.call("the foe in the way is shoved aside", dummy.call().global_position.x - memo["dx"] > 20.0))
	_at(27.5, func() -> void:
		check.call("the wave is gone when the ride is over", wizard.surf_time <= 0.0 and tree.get_nodes_in_group("lasting").filter(func(n: Node) -> bool: return n is TideSurf).is_empty()))
	# Obsidian Armor: half damage from shots, lava harmless, slower.
	_at(28.0, func() -> void:
		reset.call(15, "Obsidian Armor")
		wizard.max_stamina = 200.0
		wizard.stamina = 200.0)
	_at(28.2, func() -> void: _cast("Obsidian Armor", _stroke("circle", wizard.center(), 1.0)))
	_at(28.6, func() -> void:
		wizard._grace = 0.0
		var before: float = wizard.max_stamina
		wizard.take_damage(10, true, true)
		check.call("black glass takes half of a shot's damage (%d)" % (before - wizard.max_stamina), before - wizard.max_stamina == 5.0)
		wizard._grace = 0.0
		before = wizard.max_stamina
		SpellTargets.hurt(wizard, 12, "Fire", false, true)
		check.call("and lava does nothing", wizard.max_stamina == before)
		wizard._grace = 0.0
		wizard.take_damage(10, true, false)
		check.call("a blow that is not a shot lands in full", before - wizard.max_stamina == 10.0)
		memo["x"] = wizard.global_position.x
		Input.action_press("move_right")
		_snap("obsidian"))
	_at(29.6, func() -> void:
		Input.action_release("move_right")
		var walked: float = wizard.global_position.x - memo["x"]
		check.call("the wizard walks slower (%d px in a second)" % walked, walked > 150.0 and walked < 260.0))
	_at(49.7, func() -> void:
		check.call("black glass wears off", wizard.obsidian_time <= 0.0)
		print("%d new-spell checks failed" % failures[0]))

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
		t += 10.0 if spell_name == "Great Oak" else 2.4


## Checks that the spells that work through other things do: smoke cuts sight, a decoy draws attacks, a hex adds damage,
## a Gust turns a shot, lily pads burn over lava, ice bears weight. Each prints PASS or FAIL.
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
			if mob.kind == "dummy" and not mob.is_queued_for_deletion():
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
		check.call("a bramble leaves a dummy standing still in it unhurt (only a walker is pricked)", target.hp == target.max_hp)
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
	# A Great Oak drawn on top of the hill, starting a little above, on, and a little under its surface, takes root on it.
	var oaks := [[-30.0, 27.0], [0.0, 27.5], [14.0, 28.0]]
	for k in oaks.size():
		_at(26.1 + k * 2.0, func() -> void:
			_arena.get_tree().call_group("breakables", "queue_free"))
		_at(26.2 + k * 2.0, func() -> void:
			var col: int = int(oaks[k][1])
			var foot := _feet(col)
			_cast("Great Oak", _stroke_from("tree", foot + Vector2(0, oaks[k][0]))))
		_at(27.4 + k * 2.0, func() -> void:
			var oak: Node = null
			for node in tree.get_nodes_in_group("breakables"):
				if node is GreatOak:
					oak = node
			var foot := _feet(int(oaks[k][1]))
			check.call("a Great Oak drawn at %d px takes root on the hill" % int(oaks[k][0]), oak != null and absf(oak.global_position.y - foot.y) < 40.0)
			if k == 1:
				_player().global_position = foot + Vector2(-300.0, -30.0))
		if k == 1:
			_at(28.4, func() -> void: _snap("oak_on_hill"))
	_at(31.6, func() -> void:
		_arena.get_tree().call_group("breakables", "queue_free")
		_player().global_position = _feet(20) + Vector2(0.0, -30.0)
		_arena._on_ritual_finished("bonfire", 1.0, false))
	_at(33.2, func() -> void: _snap("bonfire"))
	_at(33.6, func() -> void:
		_arena.get_tree().call_group("mobs", "queue_free"))
	_at(33.7, func() -> void:
		var x: float = _player().global_position.x + 200.0
		var thrower := _summon_at("ninja", x)
		var friend := _summon_at("ninja", x + 120.0)
		for mob in [thrower, friend]:
			mob._spawn = 0.0
			mob.set_physics_process(false)
		EnemyBolt.fire(_arena, thrower.center(), friend.center(), Color.WHITE, 5, 0.0, false, "ninja_star", thrower))
	_at(34.4, func() -> void:
		var friend: Node2D = null
		for mob in _arena.get_tree().get_nodes_in_group("mobs"):
			friend = mob if friend == null or mob.global_position.x > friend.global_position.x else friend
		check.call("a ninja's star flies through another ninja", friend != null and friend.hp == friend.max_hp))
	_at(35.0, func() -> void:
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


## The generated world: a look at the start, the castle, a lake and a lava pool, then a real walk: the steepest tunnel, on foot,
## holding only the walk key.
func _plan_cave() -> void:
	_at(0.8, func() -> void: _snap("start"))
	var graph: WorldGraph = _arena.graph
	# A Great Oak drawn on the surface hills, from above, on and under the ground, takes root on the ground there.
	for k in 4:
		var offset: float = [-60.0, -10.0, 20.0, 80.0][k]
		_at(0.9 + k * 0.1, func() -> void:
			var x: float = ArenaGen.column_x(ArenaGen.world_size.x / 2 - 40 + k * 7)
			var ground := SpellTargets.solid_below(_arena.get_world_2d(), Vector2(x, (WorldGraph.SURFACE_ROW - 12) * ArenaGen.TILE))
			_cast("Great Oak", _stroke_from("tree", Vector2(x, ground.y + offset)))
			var oak: Node = null
			for node in _arena.get_tree().get_nodes_in_group("breakables"):
				if node is GreatOak and absf(node.global_position.x - x) < 4.0:
					oak = node
			print("%s  a Great Oak drawn %d px from the ground takes root on the ground (oak %s, ground y %d)" % ["PASS" if oak != null and absf(oak.global_position.y - ground.y) < 40.0 else "FAIL", int(offset), str(oak.global_position.y) if oak else "none", int(ground.y)]))
	_at(0.85, func() -> void:
		var before: Vector2 = _player().global_position
		_player().max_stamina = 200.0
		_player().stamina = 80.0
		_arena._on_ritual_finished("rift", 1.0, false)
		var moved: bool = _player().global_position.distance_to(before) > 400.0
		var ok: bool = moved and _player().max_stamina == 150.0 and _player().stamina == 0.0 and not _arena._body_in_rock(_player().global_position)
		print("%s  a Rift moves the wizard far, empties stamina and takes 50 off the most (max %d, stamina %d)" % ["PASS" if ok else "FAIL", _player().max_stamina, _player().stamina])
		_player().global_position = before
		_player().max_stamina = 100.0)
	_at(0.87, func() -> void:
		var flare := Flare.new()
		flare.caster_node = _player()
		_arena.add_child(flare)
		var held: bool = not flare.is_queued_for_deletion()
		_arena.spawn_spell("Frostbolt", "directional", flare.global_position + Vector2(-40, 0), 0.0, {"length": 300.0}, _player())
		print("%s  a Frostbolt cast through a flare puts it out" % ["PASS" if held and flare.is_queued_for_deletion() else "FAIL"])
		var second := Flare.new()
		second.caster_node = _player()
		_arena.add_child(second)
		Flare.snuff_near(_arena.get_tree(), second.global_position, 0.0)
		print("%s  a click on a flare puts it out" % ["PASS" if second.is_queued_for_deletion() else "FAIL"]))
	_at(0.88, func() -> void:
		var wizard: Node2D = _player()
		var home: Vector2 = wizard.global_position
		_arena._on_ritual_finished("haste", 1.0, false)
		print("%s  the Chant of Swift Feet makes the wizard faster for a while" % ["PASS" if wizard.haste_time > 15.0 else "FAIL"])
		_arena._on_ritual_finished("recall", 1.0, false)
		var nothing: bool = _arena.get_tree().get_nodes_in_group("gateways").is_empty()
		_arena._on_ritual_finished("mark", 1.0, false)
		wizard.global_position = home + Vector2(700.0, -40.0)
		_arena._on_ritual_finished("recall", 1.0, false)
		var pair := _arena.get_tree().get_nodes_in_group("gateways")
		var linked: bool = pair.size() == 2 and pair[0].partner == pair[1] and pair[1].partner == pair[0] and pair[0].tint == pair[1].tint
		print("%s  the Return opens a linked pair of portals only after a mark (none before: %s, pair: %d)" % ["PASS" if nothing and linked else "FAIL", str(nothing), pair.size()])
		if linked:
			pair[0]._on_body_entered(wizard)
			print("%s  stepping into one portal comes out of the other" % ["PASS" if wizard.global_position.distance_to(pair[1].global_position) < 80.0 else "FAIL"])
		wizard.global_position = home
		wizard.haste_time = 0.0
		for gateway in pair:
			gateway.queue_free())
	_at(0.89, func() -> void:
		var empty := 0
		var total := 0
		for pond: Pond in _arena.get_tree().get_nodes_in_group("ponds"):
			total += 1
			empty += 1 if pond._pieces.is_empty() else 0
		print("%s  every pond has a hollow to be drawn in (%d of %d have none)" % ["PASS" if empty == 0 else "FAIL", empty, total]))
	var seen_kinds := {}
	var look := 0.9
	for pond in _arena._ponds:
		if seen_kinds.has(pond["lava"]):
			continue
		seen_kinds[pond["lava"]] = true
		var at := Vector2((pond["a"] - 2) * float(ArenaGen.TILE), pond["surface"] * float(ArenaGen.TILE) - 4.0)
		_at(look, func() -> void:
			_player().global_position = at
			_player().velocity = Vector2.ZERO
			_arena.get_node("Player/Camera2D").reset_smoothing())
		_at(look + 0.4, func() -> void: _snap("lava" if pond["lava"] else "lake"))
		look += 0.1
	var t := 2.0
	# Each biome of the surface, with its backdrop faded in: standing in the middle of it, and for the mountains on the highest peak.
	for biome in graph.surface["biomes"]:
		var name: String = biome["name"]
		var column: int = (biome["a"] + biome["b"]) / 2
		if name == "mountains":
			var best := 99999
			for c in range(biome["a"], biome["b"] + 1):
				if graph.surface["floor"][c] < best:
					best = graph.surface["floor"][c]
					column = c
		var row: int = graph.surface["floor"][column]
		_at(t, func() -> void:
			_player().global_position = Vector2((column + 0.5) * float(ArenaGen.TILE), (row - 3) * float(ArenaGen.TILE))
			_player().velocity = Vector2.ZERO
			_arena.get_node("Player/Camera2D").reset_smoothing())
		_at(t + 3.6, func() -> void: _snap("biome_" + name))
		t += 4.2
	if _arena.castle_x >= 0:
		var ground_y := WorldGraph.SURFACE_ROW * float(ArenaGen.TILE)
		for view in [["gate", -6.0, 0.0], ["entry", 8.0, 0.0], ["stair", 21.0, 6.0], ["gallery", 31.0, 11.0], ["hall", 70.0, 0.0], ["back", 134.0, 0.0]]:
			var at := Vector2((_arena.castle_x + view[1]) * float(ArenaGen.TILE), ground_y - (view[2] + 1.0) * float(ArenaGen.TILE))
			var name: String = view[0]
			_at(t, func() -> void:
				_player().global_position = at
				_player().velocity = Vector2.ZERO
				_arena.get_node("Player/Camera2D").reset_smoothing())
			_at(t + 1.0, func() -> void: _snap(name))
			t += 1.6
		_at(t, func() -> void:
			_player().global_position = Vector2((_arena.castle_x + 65) * float(ArenaGen.TILE), ground_y - 15.0 * float(ArenaGen.TILE))
			var camera: Camera2D = _arena.get_node("Player/Camera2D")
			camera.zoom = Vector2(0.27, 0.27)
			camera.reset_smoothing())
		_at(t + 1.0, func() -> void: _snap("castle_whole"))
		_at(t + 1.2, func() -> void: _arena.get_node("Player/Camera2D").zoom = Vector2(1.5, 1.5))
		t += 1.6
	# The three gates, each from a little way off. Then the thorns on foot, without and with the Chant of Swift Feet: the damage a walk
	# through all of them costs, from a wizard who cannot die, against the 200 of a whole stamina bar.
	var shown := {}
	for gate in _arena._gates:
		if shown.has(gate["kind"]):
			continue
		shown[gate["kind"]] = true
		var kind: String = gate["kind"]
		var spot: Vector2i = gate["at"]
		_at(t, func() -> void:
			var camera: Camera2D = _arena.get_node("Player/Camera2D")
			_player().global_position = Vector2((spot.x + (14 if kind == "brambles" else (-3 if kind == "chasm" else 1))) * float(ArenaGen.TILE), (gate["floors"][14] if kind == "brambles" else spot.y) * float(ArenaGen.TILE) - 4.0)
			_arena._dark.hide()  # the caves are dark; a look at them is not
			_player().velocity = Vector2.ZERO
			camera.zoom = Vector2(0.6, 0.6)
			camera.reset_smoothing())
		_at(t + 1.2, func() -> void:
			_snap("gate_" + kind)
			_arena.get_node("Player/Camera2D").zoom = Vector2.ONE)
		t += 1.6
	for hasted in [false, true]:
		var field: Dictionary = {}
		for gate in _arena._gates:
			if gate["kind"] == "brambles":
				field = gate
				break
		if field.is_empty():
			break
		var inward: int = field["inward"]  # walked the way into the locked area
		var near_end: int = 0 if inward > 0 else field["floors"].size() - 1
		var start := Vector2((field["first"] + near_end + 0.5) * float(ArenaGen.TILE), field["floors"][near_end] * float(ArenaGen.TILE) - 4.0)
		var end_x: float = (field["first"] + field["floors"].size() + 1) * float(ArenaGen.TILE) if inward > 0 else (field["first"] - 1) * float(ArenaGen.TILE)
		var thorn_key := "move_right" if inward > 0 else "move_left"
		var crossing := {"damage": 0.0, "time": 0.0}
		_at(t, func() -> void:
			var wizard: Node2D = _player()
			wizard.max_stamina = 1000.0
			wizard.stamina = 1000.0
			wizard.global_position = start
			wizard.velocity = Vector2.ZERO
			wizard.haste_time = 20.0 if hasted else 0.0
			_arena.get_node("Player/Camera2D").reset_smoothing()
			Input.action_press(thorn_key))
		for i in 80:
			_at(t + 1.0 + i * 0.5, func() -> void:
				var wizard: Node2D = _player()
				if crossing["time"] == 0.0 and (wizard.global_position.x >= end_x if inward > 0 else wizard.global_position.x <= end_x):
					crossing["time"] = (i + 1) * 0.5
					crossing["damage"] = 1000.0 - wizard.max_stamina)
		_at(t + 41.0, func() -> void:
			Input.action_release(thorn_key)
			var hurt: float = crossing["damage"] if crossing["time"] > 0.0 else 1000.0 - _player().max_stamina
			var ok: bool = crossing["time"] > 0.0 and (hurt < 190.0 if hasted else hurt >= 200.0)
			print("%s  walking across the thorns %s costs %d of the 200 (%s)" % ["PASS" if ok else "FAIL", "with the Chant of Swift Feet" if hasted else "at a walk", int(hurt), "across in %.1f s" % crossing["time"] if crossing["time"] > 0.0 else "did not get across"])
			if not ok:
				_exit_code = 1
			_player().max_stamina = 200.0
			_player().stamina = 200.0
			_player().haste_time = 0.0)
		t += 42.0
	# A tunnel's slope, on foot: from the low mouth to the high one, holding only the walk key.
	var steepest := {}
	var rise := -1
	for link in graph.links:
		var drop: int = absi(link["pa"].y - link["pb"].y)
		if drop > rise and link["lock"] < 0:  # a gated passage is not meant to be walked
			rise = drop
			steepest = {"low": link["pa"] if link["pa"].y > link["pb"].y else link["pb"], "high": link["pb"] if link["pa"].y > link["pb"].y else link["pa"]}
	if not steepest.is_empty():
		var low: Vector2i = steepest["low"]
		var high: Vector2i = steepest["high"]
		var going := 1.0 if high.x > low.x else -1.0
		var from_x: float = (low.x - going * 3.0) * float(ArenaGen.TILE)  # on the hall floor, just outside the mouth
		var to_x: float = high.x * float(ArenaGen.TILE)
		var key := "move_right" if going > 0.0 else "move_left"
		_at(t, func() -> void:
			_player().max_stamina = 9999.0  # the steepest tunnel may have a gate in it: walk it unhurt
			_player().stamina = 9999.0
			_player().deep_breath_time = 100.0
			_player().global_position = Vector2(from_x, low.y * float(ArenaGen.TILE))
			_player().velocity = Vector2.ZERO
			_arena.get_node("Player/Camera2D").reset_smoothing()
			Input.action_press(key))
		var walk: float = absf(to_x - from_x) / _player().SPEED * 1.8 + 2.0
		var arrived := {"ok": false}
		for i in int(walk / 0.25):
			_at(t + i * 0.25, func() -> void:
				var at: Vector2 = _player().global_position
				var climbed: float = low.y * float(ArenaGen.TILE) - at.y
				if (at.x - to_x) * going >= 0.0 and climbed > (rise - 4) * float(ArenaGen.TILE):
					arrived["ok"] = true)
		_at(t + walk * 0.5, func() -> void: _snap("slope"))
		_at(t + walk, func() -> void:
			Input.action_release(key)
			var at: Vector2 = _player().global_position
			print("%s  the wizard walks up a %d row tunnel with no jumping (ended x %.0f, y %.0f)" % ["PASS" if arrived["ok"] else "FAIL", rise, at.x, at.y])
			if not arrived["ok"]:
				_exit_code = 1)
		t += walk + 1.0
	_at(t, func() -> void: _snap("top"))
	_at(t + 0.5, func() -> void:
		_arena.get_node("Player/Camera2D").zoom = Vector2.ONE
		_player().global_position = _arena._stand_at(_arena._markers[graph.boss]) + Vector2(-380.0, 0.0))
	_at(t + 1.5, func() -> void: _snap("boss_hall"))
	# An Earth Fall cast in a cave starts under its roof and lands on the floor, never inside rock.
	_at(t + 1.8, func() -> void:
		var spot: Vector2 = _arena._stand_at(_arena._markers[graph.boss]) + Vector2(-380.0, -60.0)
		_cast("Stonefall", _stroke("stonefall", spot)))
	_at(t + 3.8, func() -> void:
		var rock: Node2D = null
		for node in _arena.get_tree().get_nodes_in_group("rocks"):
			rock = node
		var floor_y: float = _arena._stand_at(_arena._markers[graph.boss]).y
		print("%s  an Earth Fall cast in a cave lands on the floor (rock at %s)" % ["PASS" if rock != null and not _arena._in_rock(rock.global_position) and absf(rock.global_position.y - floor_y) < 200.0 else "FAIL", str(rock.global_position) if rock else "none"]))



## The newer gates in the world of WORLD_SEED (19 has eight of the nine, 2 has the chasm; fewer halls means fewer gates): each seen from a little way off, then tried on foot.
func _plan_gates() -> void:
	var t := 4.0  # after the world has set the wizard down
	var by_kind := {}
	for gate in _arena._gates:
		if not by_kind.has(gate["kind"]):
			by_kind[gate["kind"]] = gate
	if OS.get_environment("GATE_ONLY") != "":
		for kind in by_kind.keys():
			if kind != OS.get_environment("GATE_ONLY"):
				by_kind.erase(kind)
	var tile := float(ArenaGen.TILE)
	var stand := func(kind: String, back: float) -> Vector2:  # a place on the floor some columns before the gate
		var gate: Dictionary = by_kind[kind]
		var at: Vector2i = gate["at"]
		var floor_row: int = at.y
		match kind:
			"ice":
				floor_row = gate["columns"][0]["bottom"]
			"gas":
				floor_row = gate["banks"][0]["floors"][0]
			"dark":
				floor_row = gate["strips"][0]["floors"][0]
		if kind in ["gas", "dark"]:
			back = 0.0  # these lie on slopes, so the floor is only known where they begin
		if not kind in ["gas", "dark"]:
			while back > 1.0 and _arena._in_rock(Vector2((at.x - back) * tile, (floor_row - 0.5) * tile)):
				back -= 1.0  # the passage may begin with a wall that far back: come nearer
		var spot := Vector2((at.x - back) * tile, floor_row * tile - 4.0)
		if not kind in ["gas", "dark"]:
			spot = _arena._floor_under(spot + Vector2(0, -0.5 * tile)) - Vector2(0, 4.0)  # the passage may slope: the floor is where this column has it (searched from just above, since the roof may be low)
		_arena._ground.watch([spot] as Array[Vector2], true)  # the ground there is built before the wizard is set down on it
		return spot
	for kind in ["chasm", "flood", "piranhas", "sentinel", "ice", "dark", "gas"]:
		if not by_kind.has(kind):
			print("SKIP  no %s gate in this world" % kind)
			continue
		var k: String = kind
		_at(t, func() -> void:
			_player().global_position = stand.call(k, 6.0)
			_arena._dark.hide()
			_player().velocity = Vector2.ZERO
			_arena.get_node("Player/Camera2D").zoom = Vector2(0.6, 0.6)
			_arena.get_node("Player/Camera2D").reset_smoothing())
		_at(t + 1.2, func() -> void:
			_snap("gate_" + k)
			_arena._dark.show())
		_at(t + 1.8, func() -> void:
			_snap("gate_%s_dark" % k)
			_arena.get_node("Player/Camera2D").zoom = Vector2.ONE)
		t += 2.2
	if by_kind.has("ice"):
		var plug_gate: Dictionary = by_kind["ice"]
		var left: float = plug_gate["columns"][0]["x"] * tile
		var right: float = (plug_gate["columns"][-1]["x"] + 1) * tile
		var plug: Array = [null]
		_at(t - 0.6, func() -> void: stand.call("ice", 5.0))  # builds the ground there a moment before the wizard is set down on it
		_at(t, func() -> void:
			for node in _arena.get_children():
				if node is IcePlug and node.columns[0]["x"] == plug_gate["columns"][0]["x"]:
					plug[0] = node
			_player().global_position = stand.call("ice", 5.0)
			_player().velocity = Vector2.ZERO
			Input.action_press("move_right"))
		_at(t + 3.0, func() -> void:
			Input.action_release("move_right")
			var ok: bool = _player().global_position.x < left
			print("%s  the ice is as solid as rock (the wizard stopped at x %d, ice from %d)" % ["PASS" if ok else "FAIL", int(_player().global_position.x), int(left)])
			if not ok:
				_exit_code = 1
			Hazard.place(_arena, Vector2((left + right) * 0.5, plug_gate["columns"][0]["bottom"] * tile), 120.0, 12.0))
		_at(t + 12.0, func() -> void:
			var gone: bool = not is_instance_valid(plug[0])
			print("%s  fire melts the ice" % ["PASS" if gone else "FAIL"])
			if not gone:
				_exit_code = 1
			_player().global_position = stand.call("ice", 5.0)
			Input.action_press("move_right"))
		_at(t + 16.0, func() -> void:
			Input.action_release("move_right")
			var ok: bool = _player().global_position.x > right
			print("%s  and then the way is open (x %d, ice ended at %d)" % ["PASS" if ok else "FAIL", int(_player().global_position.x), int(right)])
			if not ok:
				_exit_code = 1)
		t += 17.0
	if by_kind.has("sentinel"):
		var post: Dictionary = by_kind["sentinel"]
		var post_x: float = (post["stands"].x + 0.5) * tile
		var inward: int = post["inward"]
		var move_key := "move_right" if inward > 0 else "move_left"
		var floor_at := {}  # the passage's floor row in each column
		for cell: Vector2i in post["blocks"]:
			floor_at[cell.x] = cell.y + 1
		var column_back := func(back: int) -> int:  # the column this far back from the statue, kept inside the passage
			return clampi(post["stands"].x - inward * back, floor_at.keys().min(), floor_at.keys().max())
		for mode in 2:
			var lured := mode == 1
			var crossing := {"damage": -1.0}
			_at(t, func() -> void:
				var wizard: Node2D = _player()
				wizard.max_stamina = 1000.0
				wizard.stamina = 1000.0
				wizard.global_position = Vector2((column_back.call(11) + 0.5) * tile, floor_at[column_back.call(11)] * tile - 4.0)
				wizard.velocity = Vector2.ZERO
				if lured:
					var decoy := Decoy.new()
					_arena.add_child(decoy)
					decoy.position = Vector2((column_back.call(5) + 0.5) * tile, floor_at[column_back.call(5)] * tile)
				Input.action_press(move_key))
			for q in range(1, 64):
				_at(t + q * 0.125, func() -> void:
					var wizard: Node2D = _player()
					if crossing["damage"] < 0.0 and ((wizard.global_position.x - post_x) * inward > 11.0 * tile):
						crossing["damage"] = 1000.0 - wizard.max_stamina)
			_at(t + 8.0, func() -> void:
				Input.action_release(move_key)
				var statues := get_tree().get_nodes_in_group("sentinels")
				print("  statues %d at %s, wizard at %s" % [statues.size(), str(statues[0].global_position) if statues.size() > 0 else "-", str(_player().global_position)])
				var hurt: float = crossing["damage"]
				var ok: bool = hurt >= 0.0 and (hurt < 40.0 if lured else hurt >= 40.0)
				print("%s  walking past the statue %s costs %d" % ["PASS" if ok else "FAIL", "with a decoy standing in view" if lured else "in plain view", int(hurt)])
				if not ok:
					_exit_code = 1
				_player().max_stamina = 200.0
				_player().stamina = 200.0)
			t += 9.0
	if by_kind.has("piranhas"):
		var pit_gate: Dictionary = by_kind["piranhas"]
		var pit: Rect2i = pit_gate["pit"]
		var shoal: Array = [null]
		var end_x: float = (pit.end.x + 1) * tile
		for mode in 2:
			var killed := mode == 1
			var crossing := {"damage": -1.0, "base": 1000.0}
			_at(t - 0.6, func() -> void: stand.call("piranhas", 5.0))
			_at(t + 0.4, func() -> void: crossing["base"] = _player().max_stamina)  # whatever the setting down cost is not the pit's
			_at(t, func() -> void:
				var wizard: Node2D = _player()
				for node in _arena.get_children():
					if node is Piranhas and node.water.position.x == pit.position.x * tile:
						shoal[0] = node
				wizard.max_stamina = 1000.0
				wizard.stamina = 1000.0
				wizard.global_position = stand.call("piranhas", 5.0)
				wizard.velocity = Vector2.ZERO
				Input.action_press("move_right")
				Input.action_press("jump"))  # jumping out of the far side of the pit
			for q in range(1, 120):
				_at(t + q * 0.125, func() -> void:
					var wizard: Node2D = _player()
					if crossing["damage"] < 0.0 and wizard.global_position.x > end_x and wizard.global_position.x < end_x + 600.0:
						crossing["damage"] = crossing["base"] - wizard.max_stamina)
			_at(t + 15.0, func() -> void:
				Input.action_release("move_right")
				Input.action_release("jump")
				print("  wizard at %s, pit x %d..%d y %d" % [str(_player().global_position), pit.position.x * 32, pit.end.x * 32, pit.position.y * 32])
				var hurt: float = crossing["damage"]
				var ok: bool = hurt == 0.0 if killed else hurt >= 20.0
				print("%s  wading the pit %s costs %d (%d fish left)" % ["PASS" if ok else "FAIL", "with the fish dead" if killed else "full of fish", int(hurt), shoal[0]._fish.size()])
				if not ok:
					_exit_code = 1
				_player().max_stamina = 200.0
				_player().stamina = 200.0)
			if not killed:
				for strike in 4:
					var x: float = (pit.position.x + 3 + strike * 6) * tile
					_at(t + 16.0 + strike * 0.6, func() -> void:
						var spell := SparkStrike.new()
						_arena.add_child(spell)
						spell.setup("Spark", Vector2(x, (pit.position.y - 2) * tile), 0.0))
				_at(t + 19.5, func() -> void:
					var dead: bool = not shoal[0].alive()
					print("%s  lightning in the water kills the fish" % ["PASS" if dead else "FAIL"])
					if not dead:
						_exit_code = 1)
				t += 20.0
			else:
				t += 16.0
	if by_kind.has("gas"):
		var field: Dictionary = by_kind["gas"]
		var banks: Array = field["banks"]
		var inward: int = field["inward"]  # the way in to the locked area: that is the way it is walked
		var last_col: int = banks[-1]["x"] + banks[-1]["floors"].size()
		var rows := []
		for bank in banks:
			rows.append_array(bank["floors"])
		var end_x: float = (last_col + 1) * tile if inward > 0 else (banks[0]["x"] - 1) * tile
		var move_key := "move_right" if inward > 0 else "move_left"
		for mode in 3:
			var hasted := mode == 1
			var held := mode == 2
			var start := t
			_at(t, func() -> void:
				var wizard: Node2D = _player()
				wizard.max_stamina = 1000.0
				wizard.stamina = 1000.0
				wizard.haste_time = 20.0 if hasted else 0.0
				wizard.deep_breath_time = 45.0 if held else 0.0
				wizard.global_position = stand.call("gas", 0.0) if inward > 0 else Vector2(last_col * tile, banks[-1]["floors"][-1] * tile - 4.0)
				wizard.velocity = Vector2.ZERO
				Input.action_press(move_key))
			var crossing := {"damage": -1.0}
			for q in range(1, 64):
				_at(t + q * 0.125, func() -> void:
					var wizard: Node2D = _player()
					if crossing["damage"] < 0.0 and ((wizard.global_position.x > end_x) == (inward > 0)) and wizard.global_position.y > 0.0 and absf(wizard.global_position.x - end_x) < 600.0:
						crossing["damage"] = 1000.0 - wizard.max_stamina)
			_at(t + 8.0, func() -> void:
				Input.action_release(move_key)
				var wizard: Node2D = _player()
				var hurt: float = crossing["damage"] if crossing["damage"] >= 0.0 else 1000.0 - wizard.max_stamina
				var across: bool = crossing["damage"] >= 0.0
				var ok: bool = hurt < 1.0 if held else (hurt < 190.0 if hasted else hurt >= 150.0)
				print("%s  walking through the gas %s costs %d of the 200 (%s)" % ["PASS" if ok else "FAIL", "holding the breath" if held else ("hasted" if hasted else "at a walk"), int(hurt), "across" if across else "not across"])
				if not ok:
					_exit_code = 1
				wizard.deep_breath_time = 0.0
				wizard.haste_time = 0.0
				wizard.max_stamina = 200.0
				wizard.stamina = 200.0)
			t += 9.0
		_at(t, func() -> void:
			Hazard.place(_arena, Vector2((banks[0]["x"] + 3.0) * tile, banks[0]["floors"][3] * tile), 120.0, 5.0))
		_at(t + 3.0, func() -> void:
			var left_over := 0
			for node in _arena.get_children():
				if node is GasBank and node._thinning < 0.0 and node.column >= banks[0]["x"] and node.column <= banks[-1]["x"]:
					left_over += 1
			print("%s  fire burns the gas off a bank (%d of %d banks still hang)" % ["PASS" if left_over < banks.size() else "FAIL", left_over, banks.size()])
			if left_over >= banks.size():
				_exit_code = 1)
		t += 4.0
	if by_kind.has("dark"):
		var field: Dictionary = by_kind["dark"]
		var bed: Array = [null]
		var shown_before := {"value": true}
		_at(t, func() -> void:
			for node in _arena.get_children():
				if node is SpikeBed and node.strips[0]["x"] == field["strips"][0]["x"]:
					bed[0] = node
			var wizard: Node2D = _player()
			wizard.dead = false  # the gas test before this one may have killed the wizard on purpose
			wizard.movement_enabled = true
			wizard.max_stamina = 1000.0
			wizard.stamina = 1000.0
			wizard.global_position = stand.call("dark", 0.0)
			wizard.velocity = Vector2.ZERO
			shown_before["value"] = bed[0].shown()
			Input.action_press("move_right"))
		_at(t + 9.0, func() -> void:
			Input.action_release("move_right")
			var hurt: float = 1000.0 - _player().max_stamina
			var ok: bool = not shown_before["value"] and hurt >= 60.0
			print("%s  the spikes are unseen in the dark (%s) and cost %d walking through" % ["PASS" if ok else "FAIL", "hidden" if not shown_before["value"] else "SHOWN", int(hurt)])
			if not ok:
				_exit_code = 1
			_player().max_stamina = 200.0
			_player().stamina = 200.0
			var first: Dictionary = field["strips"][0]
			Hazard.place(_arena, Vector2((first["x"] + 2.5) * tile, first["floors"][2] * tile), 60.0, 5.0))
		_at(t + 10.2, func() -> void:
			print("%s  a fire shows them (shown %s)" % ["PASS" if bed[0].shown() else "FAIL", bed[0].shown()])
			if not bed[0].shown():
				_exit_code = 1
			_player().global_position = stand.call("dark", 0.0)
			_player().velocity = Vector2.ZERO
			_arena._dark.hide()
			_arena.get_node("Player/Camera2D").reset_smoothing())
		_at(t + 11.4, func() -> void: _snap("spikes_lit"))
		t += 12.0
