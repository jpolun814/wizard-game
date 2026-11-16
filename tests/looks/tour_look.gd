extends Node

## A short film of each of the nine places, for the README: every biome is walked into for a moment, one after the other.
##
##     godot --fixed-fps 60 --path . tests/looks/tour_look.tscn -- out=DIR   (needs a window)
##
## Then `python tools/make_gif.py DIR tour.gif --fps 12 --width 440`.

const SECONDS := 3.2          # how long each place is filmed
const LONGER := {"jungle": 7.0, "graveyard": 4.0, "mountains": 5.0, "ashlands": 7.0, "castle": 9.0, "underground": 10.0, "portals": 5.0, "ocean": 13.0, "sky": 9.5}  # the places that need more time to show what they are
const EVERY := 6              # a picture every this many physics frames
## Places where the first world that turns up shows rock instead of the place: the match and the world to use, and the way to walk.
const PICKED := {"mountains": [2, 2, "move_left"]}
const OCEAN_RANGE := 190.0  # how far off the one who sinks is
const OCEAN_AIM := 150.0  # how far under the wizard the shot is aimed
const SKY_RANGE := 360.0  # how far off the rival falls, in the sky
const ZOOM := {"graveyard": 2.2}  # the places filmed closer than the game's 1.5, so that what is small can be seen
const KEEP_PAGES := ["underground", "ocean", "sky"]  # the places where a page is what the wizard goes after
var ORDER := ["jungle", "graveyard", "mountains", "ashlands", "castle", "underground", "portals", "ocean", "sky"]

var _out := ""
var _seen: Node
var _frame := 0
var _color := Color.WHITE
var _only := ""        # only=NAME films just that place
var _seed := -1        # seed=N picks the match
var _finish := -1.0    # when a place's scene sets this (seconds), its film ends then, a moment after what it shows is over


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("only="):
			_only = arg.substr(5)
		elif arg.begins_with("seed="):
			_seed = int(arg.substr(5))
	DirAccess.make_dir_recursive_absolute(_out)
	reparent(get_tree().root)
	get_tree().current_scene = null
	if _only != "":
		ORDER = [_only]
	_next(0)


## Finds a match whose first three worlds hold this biome, and goes into it.
func _next(k: int) -> void:
	if k >= ORDER.size():
		print("RESULT  ok, %d pictures" % _frame)
		get_tree().quit(0)
		return
	var seed_value := 0
	var at := 0
	var picked: bool = PICKED.has(ORDER[k])
	for s in ([] if picked else ([_seed] if _seed >= 0 else range(600))):
		MatchState.begin(s)
		for stage in 3:
			if MatchState.biome_of(stage) == ORDER[k]:
				seed_value = s
				at = stage
				break
		if MatchState.biome_of(at) == ORDER[k]:
			break
	if picked:
		seed_value = PICKED[ORDER[k]][0]
		at = PICKED[ORDER[k]][1]
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = seed_value
	MatchState.begin(seed_value)
	MatchState.stage = at
	MatchState.pending = true
	MatchState.ledgers = Pages.start_empty(World.WIZARDS)
	MatchState.vitals = []
	for j in World.WIZARDS:
		MatchState.vitals.append({"alive": true, "max": 200.0, "stamina": 200.0})
	print("place ", ORDER[k], " seed ", seed_value, " world ", at)
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	_wait_for_world(k)


func _wait_for_world(k: int) -> void:
	var world: Node = null
	while true:
		await get_tree().process_frame
		world = get_tree().current_scene
		if world is World and world != _seen and world.player != null and world.ledgers.size() > 0 and world.nav != null:
			break
	_seen = world
	var trail := StrokeTrail.new()  # (the live trail of a person's own wizard is the mouse's; here the pen's stroke is shown growing instead)
	trail.pen = world.player.pen
	trail.owner_tour = self
	trail.z_index = 200
	world.add_child(trail)
	for j in 30:
		await get_tree().process_frame
	if ORDER[k] not in KEEP_PAGES:
		for page in get_tree().get_nodes_in_group("pages"):
			page.queue_free()  # (the fan of pages at the start hides the view)
	for layer: Node in get_tree().get_nodes_in_group("grade"):
		layer.visible = false  # (the graveyard keeps its gray wash: that is how it looks in play)
	if ORDER[k] == "graveyard":
		for mist: Node in world.find_children("*", "MistBank", true, false):
			mist.visible = false  # (the low fog hides the place from the film)
		for dim: Node in get_tree().get_nodes_in_group("darkness"):
			dim.visible = false  # (the night's tint is lifted, so the graveyard can be made out)
	var frames := int(float(LONGER.get(ORDER[k], SECONDS)) * 60.0)
	var player: Wizard = world.player
	_finish = -1.0
	player.ledger.learn_all()
	var scene := _stage(ORDER[k], world)
	for j in 40:
		await get_tree().process_frame
	_after_stage(ORDER[k], world)
	var think := _think(ORDER[k], world, scene)
	for f in frames:
		await get_tree().physics_frame
		think.call(float(f) / 60.0)
		if _finish >= 0.0 and float(f) / 60.0 >= _finish:
			break
		if f % EVERY == 0:
			get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [_out, _frame])
			_frame += 1
	for action in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(action)
	_next(k + 1)


## Where the wizard is put, and what is put round it, in each place. Returns what the place's scene needs to know.
func _stage(place: String, world: World) -> Dictionary:
	var me: Wizard = world.player
	var scene := {}
	var spot := Vector2.INF
	match place:
		"ashlands":  # a good way off a volcano, on the ground
			var crater := _nearest(world, func(n: Node) -> bool: return n is Eruption)
			if crater != null:
				spot = world.floor_under(crater.global_position + Vector2(-340.0, 0.0))
		"portals":  # a good way off a portal, with two of the dead after the wizard
			var portal: Node2D = null
			var best_gap := INF
			for node: Node in world.find_children("*", "FieldPortal", true, false):
				var gap := absf(world.floor_under(node.global_position).y - node.global_position.y)
				if gap < best_gap:
					best_gap = gap
					portal = node
			print("   portal height over the ground: ", best_gap)
			if portal != null:
				spot = world.floor_under(portal.global_position + Vector2(-440.0, 0.0))
				scene["portal"] = portal
		"ocean":  # in the water by a wreck
			var best := INF
			for page: Node in get_tree().get_nodes_in_group("pages"):
				for wreck: Node in world.find_children("*", "Wreck", true, false):
					var apart: float = page.global_position.distance_to(wreck.global_position)
					if apart < best:
						best = apart
						scene["page"] = page
						scene["wreck"] = wreck
			if scene.has("page"):
				var sea := _nearest(world, func(n: Node) -> bool: return n is Pond and n.deep)
				spot = Vector2(scene["page"].global_position.x - 150.0, (sea.global_position.y if sea != null else scene["page"].global_position.y - 700.0) - 120.0)  # (above the sea, where the wizard drops in)
				for near: Node in get_tree().get_nodes_in_group("pages"):
					if near.global_position.distance_to(scene["page"].global_position) < 500.0:
						me.ledger.pages.erase(near.page)  # (pages the book does not hold yet, so reading one is seen)
		"castle":  # a knight on guard, in sight
			var knight := _nearest(world, func(n: Node) -> bool: return n is Mob and n.kind == "knight" and n.guards)
			if knight != null:
				scene["knight"] = knight
				spot = knight.global_position + Vector2(-345.0, 0.0)  # (on the knight's own floor: the floor under that column is the bottom of the castle)
		"jungle":  # at the edge of a pond of piranhas
			var pond := _nearest(world, func(n: Node) -> bool: return n is Pond and not n.lava and not n.deep and not n.loose and n.width >= 200.0 and n.width <= 520.0)
			if pond != null:
				scene["pond"] = pond
				spot = world.floor_under(pond.global_position + Vector2(-40.0, -40.0))
				print("   pond at ", pond.global_position, " width ", pond.width, " depth ", pond.depth)
		"mountains":  # high on a slope that falls away to the left, with one who stands at its foot
			var summit: Node2D = null  # (the highest page lies on a summit, in the open air)
			for page: Node in get_tree().get_nodes_in_group("pages"):
				if summit == null or page.global_position.y < summit.global_position.y:
					summit = page
			print("   summit page at ", summit.global_position if summit != null else "none")
			var found := _slope(world, summit.global_position.x if summit != null else me.global_position.x, summit.global_position.y if summit != null else me.global_position.y)
			if found.has("top"):
				spot = found["top"]
				scene["foot"] = found["foot"]
				scene["way"] = found["way"]
				scene["drop_x"] = found["drop_x"]
				scene["above"] = summit.global_position.y - 220.0
				scene["top"] = found["top"]
		"sky":  # a page that rises, and a rival who only falls
			var rising: FallingPage = null
			for page: Node in get_tree().get_nodes_in_group("pages"):
				if page is FallingPage and absf(page.rate) > 1.0 and (rising == null or page.global_position.distance_to(me.global_position) < rising.global_position.distance_to(me.global_position)):
					rising = page
			scene["page"] = rising
			if rising != null:
				me.ledger.pages.erase(rising.page)  # (a page the book does not hold yet, so reading it is seen)
		"underground":  # a way off a page, in the dark
			var page := _nearest(world, func(n: Node) -> bool: return n is PagePickup and not n.is_queued_for_deletion())
			if page != null:
				scene["page"] = page
				me.ledger.pages.erase(page.page)  # (a page the book does not hold yet: it is not shown as read before it is)
				spot = world.floor_under(page.global_position + Vector2(-720.0, 0.0))  # (a long way off: the page is not on screen, and the wizard comes on it in the dark)
	if spot != Vector2.INF:
		me.global_position = spot + Vector2(0.0, -4.0)
		me.velocity = Vector2.ZERO
		me.reset_physics_interpolation()
	me.facing = float(scene.get("way", 1.0))
	me.get_node("Camera2D").zoom = Vector2.ONE * float(ZOOM.get(place, 1.5))
	if scene.has("way"):
		(me.get_node("Camera2D") as GameCamera).set_rest_offset(Vector2(float(scene["way"]) * 150.0, 20.0))  # (the view looks down the slope, where the boulder goes)
	me.get_node("Camera2D").reset_smoothing()
	me.eyes.snap()
	print("   staged ", place, " at ", me.global_position, " ", scene.keys())
	return scene


## What is done once the place has had time to load around the wizard.
func _after_stage(place: String, world: World) -> void:
	if place == "ashlands":
		for crater in world.get_children().filter(func(n: Node) -> bool: return n is Eruption):
			crater._wake(7)
			crater._phase = 1.5  # a moment's rumble, then it erupts


## The one nearest the wizard of those the test picks out, among everything in the world and its mobs.
func _nearest(world: World, test: Callable) -> Node2D:
	var best: Node2D = null
	var pool: Array = world.find_children("*", "", true, false) + get_tree().get_nodes_in_group("mobs")
	for node: Node in pool:
		if node is Node2D and is_instance_valid(node) and test.call(node):
			if best == null or node.global_position.distance_to(world.player.global_position) < best.global_position.distance_to(world.player.global_position):
				best = node
	return best


## A slope near this column, with its top, its foot and the way it falls (-1 to the left, 1 to the right). Empty when there is none.
func _slope(world: World, near_x: float, near_y: float) -> Dictionary:
	var best := {}
	var best_gap := INF
	var low := near_y - 220.0  # (above any ridge, so what is found is its top)
	for way in [-1.0, 1.0]:
		for k in range(-200, 200):
			var top_x := near_x + float(k) * 8.0
			var top := world.landing(Vector2(top_x, low))
			var foot := world.landing(Vector2(top_x + way * 200.0, low))
			var mid := world.landing(Vector2(top_x + way * 100.0, low))
			var drop := foot.y - top.y
			var even := absf((mid.y - top.y) - drop * 0.5) < 45.0  # a slope, not a cliff with a ledge in it
			if drop >= 100.0 and drop <= 330.0 and even and absf(top_x - near_x) < best_gap:
				best_gap = absf(top_x - near_x)
				best = {"top": top, "foot": foot, "way": way, "drop_x": top_x + way * 70.0}
	if not best.is_empty():
		print("   slope: top ", best["top"], " foot ", best["foot"], " way ", best["way"])
	return best


## Presses a key, or lets it go.
func _hold(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


## A key tapped once, as a person would.
func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Walks (or flies, or swims) toward a point, and says whether it has come close.
func _go_to(me: Wizard, at: Vector2, flying := false) -> bool:
	var to := at - me.global_position
	_hold("move_right", to.x > 14.0)
	_hold("move_left", to.x < -14.0)
	if flying:
		_hold("move_up", to.y < -20.0)
		_hold("move_down", to.y > 20.0)
	return absf(to.x) <= 14.0 and (not flying or absf(to.y) <= 20.0)


## A skeleton that comes for the wizard from this far ahead (behind, when negative), or stands guard where it is put.
func _walker(world: World, ahead: float, stand := false) -> Mob:
	var mob: Mob = world.add_mob("basic", world.floor_under(world.player.global_position + Vector2(ahead, 0.0)))
	if stand:
		mob._spawn = 0.0
		mob._root_time = 99.0
		mob.modulate.a = 1.0
	return mob


## What happens in each place, as it would in play. Returns what is called every frame with the seconds so far.
## A wizard stops to draw a spell (a stroke drawn on the move would be bent by the walking).
func _think(place: String, world: World, scene: Dictionary) -> Callable:
	var me: Wizard = world.player
	var st := {"step": 0, "foe": null}
	match place:
		"jungle":  # lays lily pads across a pond of piranhas, and walks over them
			var pond: Pond = scene.get("pond")
			return func(t: float) -> void:
				if not is_instance_valid(pond):
					return
				if int(st["step"]) == 0 and t > 0.8:
					var line_end := Vector2(me.global_position.x + 330.0, pond.global_position.y - 105.0)
					_cast(world, "Lily Pads", _fit_ending_at("pads", line_end, 290.0))
					st["step"] = 1
				elif int(st["step"]) == 1 and t > 3.0 and not me.pen.active():
					_hold("move_right", true)
					if me.is_on_floor():
						_press("jump")  # (hops from leaf to leaf)
		"graveyard":  # lightning on a guard of the crypts
			var guard := _walker(world, 270.0, true)
			return func(t: float) -> void:
				if int(st["step"]) == 0 and t > 0.4:
					_cast(world, "Spark", _fit("zigzag", guard.global_position + Vector2(0.0, -130.0), 70.0))
					st["step"] = 1
				elif int(st["step"]) == 1 and t > 2.6:
					_hold("move_right", true)
		"mountains":  # a boulder let go on a slope rolls down onto someone at its foot
			var foot: Vector2 = scene.get("foot", Vector2.INF)
			var foe := world.add_mob("basic", foot)
			foe._spawn = 0.0
			foe._root_time = 99.0
			foe.modulate.a = 1.0
			var crest: Vector2 = scene.get("top", Vector2.ZERO)
			return func(t: float) -> void:
				_hold("move_left", me.global_position.x > crest.x + 45.0)  # (the gale blows along the ridge: the wizard leans into it to stay on the crest)
				_hold("move_right", me.global_position.x < crest.x - 45.0)
				if int(st["step"]) == 0 and t > 1.0:
					var up := world.landing(Vector2(scene["drop_x"], scene["above"]))
					_cast(world, "Stonefall", _fit("stonefall", up + Vector2(0.0, -150.0), 56.0))
					st["step"] = 1
		"ashlands":  # puts on armor of black glass and wades into the lava
			return func(t: float) -> void:
				if int(st["step"]) == 0 and t > 0.3:
					_cast(world, "Obsidian Armor", _fit("circle", me.global_position + Vector2(0.0, -40.0), 70.0))
					st["step"] = 1
				elif int(st["step"]) == 1 and t > 2.0 and not me.pen.active():
					_hold("move_right", true)
		"castle":  # freezes a knight at his post, and walks past him
			var knight: Mob = scene.get("knight")
			return func(t: float) -> void:
				if not is_instance_valid(knight):
					return
				if int(st["step"]) == 0 and t > 0.8:
					_cast(world, "Ice Prison", _fit("circle", knight.global_position + Vector2(0.0, -40.0), 96.0))
					st["step"] = 1
				elif int(st["step"]) == 1 and t > 3.2 and not me.pen.active():
					_hold("move_right", knight.global_position.x - me.global_position.x > 120.0)  # (walks up, now that he cannot move)
					if knight.global_position.x - me.global_position.x <= 120.0:
						_hold("move_right", false)
						_cast(world, "Fire Breath", _fit("cone", me.center() + Vector2(70.0, -6.0), 90.0), 0.5)  # (flame on the frozen knight)
						st["step"] = 2
						st["at"] = t
				elif int(st["step"]) == 2 and t > float(st["at"]) + 3.0:
					_finish = t
		"underground":  # lights a flame and goes after a page
			var page: Node2D = scene.get("page")
			return func(t: float) -> void:
				if int(st["step"]) == 0 and t > 0.5:
					_cast(world, "Flare", _fit("flare", me.global_position + Vector2(0.0, -80.0), 34.0))
					st["step"] = 1
				elif int(st["step"]) == 1 and t > 2.4 and not me.pen.active() and is_instance_valid(page):
					if PagePickup.underfoot(get_tree()) == null:
						_go_to(me, page.global_position)
					else:
						for action in ["move_left", "move_right"]:
							Input.action_release(action)
						_press("book")  # reads it
						st["step"] = 2
						st["at"] = t
				elif int(st["step"]) == 2 and t > float(st["at"]) + 1.6:
					_press("book")
					st["step"] = 3
					_finish = t + 0.9
		"portals":  # runs from the dead, into a portal
			_walker(world, -300.0)
			_walker(world, -380.0)
			return func(t: float) -> void:
				if t > 0.8:
					_hold("move_right", true)
		"ocean":  # drops into the sea under the night sky, swims down to the page that lies by a wreck, reads it, and strokes back up toward the air
			var page: PagePickup = scene.get("page")
			return func(t: float) -> void:
				var step := int(st["step"])
				if step == 0 and is_instance_valid(page) and t > 1.4:
					if PagePickup.underfoot(get_tree()) == null:
						_go_to(me, page.global_position + Vector2(0.0, -195.0), true)  # (down through the open water, not along the floor)
					else:
						for action in ["move_left", "move_right", "move_up", "move_down"]:
							Input.action_release(action)
						_press("book")
						st["step"] = 1
						st["at"] = t
				elif step == 1 and t > float(st["at"]) + 1.2:
					_press("book")
					st["step"] = 2
					st["at"] = t
				elif step == 1 and t > float(st["at"]) + 0.6 and not st.has("tapped"):
					st["tapped"] = true
					_press("jump")  # (one stroke keeps the wizard afloat while it reads)
				elif step == 2:
					if int(t * 2.5) != int(st.get("beat", -1)):
						st["beat"] = int(t * 2.5)
						_press("jump")  # (strokes up toward the air)
					if t > float(st["at"]) + 1.6:
						_finish = t
		"sky":  # flies up to a page that rises past, reads it, and shoots at a rival who is falling
			var page: FallingPage = scene.get("page")
			var rival: Wizard = null
			for each: Node in get_tree().get_nodes_in_group("wizards"):
				if each != me and each is Wizard and (rival == null or each.global_position.distance_to(me.global_position) < rival.global_position.distance_to(me.global_position)):
					rival = each
			if rival != null:
				rival.brain = null  # (it only falls: what is shown is the shot, not a fight)
			rival.look = "wizard"  # (a figure with a falling pose of its own)
			rival.palette = 5
			return func(t: float) -> void:
				var step := int(st["step"])
				if step == 0:
					if is_instance_valid(page) and PagePickup.underfoot(get_tree()) == null:
						_go_to(me, page.shown() + Vector2(0.0, 30.0), true)
					elif is_instance_valid(page):
						for action in ["move_left", "move_right", "move_up", "move_down"]:
							Input.action_release(action)
						_press("book")  # reads it
						st["step"] = 1
						st["at"] = t
				elif step == 1 and t > float(st["at"]) + 1.6:
					_press("book")  # shuts the book
					st["step"] = 2
					st["at"] = t
					if rival != null:
						rival.global_position += me.center() + Vector2(SKY_RANGE, -10.0 - (0.5 * Projectile.SKY_LIFT * pow(SKY_RANGE / 700.0, 2.0) - 38.6)) - rival.center()  # (it falls to meet the shot, which has risen against the fall by then)
						rival.velocity = Vector2(0.0, Wizard.FLY_DRIFT)
						rival.reset_physics_interpolation()
				elif step == 2 and t > float(st["at"]) + 0.8 and rival != null and is_instance_valid(rival):
					var lead := me.center() + Vector2(SKY_RANGE, 0.0)  # (aimed level: the shot rises as it flies, against the fall, and the rival has dropped to meet it)
					_cast(world, "Ignite", _toward(me, lead), 0.5)
					st["step"] = 3
					st["at"] = t
				elif int(st["step"]) == 3 and t > float(st["at"]) + 2.4:
					_finish = t
	return func(_t: float) -> void: pass


func _process(delta: float) -> void:
	var world := get_tree().current_scene
	if world is World and world.player != null and world.player.pen.active():  # (a person's wizard has no brain to draw its stroke, so it is drawn here)
		world.player.cast_color = _color
		world.player.pen.tick(delta)


## Draws a spell the way a person does, with the trail showing.
func _cast(world: World, spell_name: String, stroke: PackedVector2Array, seconds := 1.4) -> void:
	var data: Spell = SpellData.SPELLS[spell_name]
	var caster: Caster = world.caster
	world.player.stamina = world.player.max_stamina
	_color = SpellData.SCHOOL_COLORS[data.school]
	if not world.player.pen.begin(stroke, _color, func(points: PackedVector2Array) -> void: caster.cast_stroke(data.buttons, points), seconds):
		print("   (could not begin ", spell_name, ": stroke ", GestureTemplates.bounds(stroke), ", screen ", world.player.eyes.rect(), ")")


## A shape's points, centered on a point, at a size (and turned to face left when `left`).
func _stroke(gesture: String, middle: Vector2, size := 1.0, left := false) -> PackedVector2Array:
	var shape := GestureTemplates.preview_points(gesture)
	var low: Vector2 = shape[0]
	var high: Vector2 = shape[0]
	for p in shape:
		low = low.min(p)
		high = high.max(p)
	var out := PackedVector2Array()
	for p in shape:
		var q: Vector2 = (p - (low + high) * 0.5) * size
		out.append(middle + Vector2(-q.x if left else q.x, q.y))
	var dense := PackedVector2Array()
	for i in out.size() - 1:
		var steps := maxi(1, int(out[i].distance_to(out[i + 1]) / 2.0))
		for j in steps:
			dense.append(out[i].lerp(out[i + 1], float(j) / steps))
	dense.append(out[out.size() - 1])
	return dense


## A shape drawn so that it is this wide.
func _fit(gesture: String, middle: Vector2, width: float) -> PackedVector2Array:
	var shape := GestureTemplates.preview_points(gesture)
	var low: float = shape[0].x
	var high: float = shape[0].x
	for p in shape:
		low = minf(low, p.x)
		high = maxf(high, p.x)
	return _stroke(gesture, middle, width / maxf(high - low, 1.0))


## A shape drawn so that it is this wide and its last point lies on a point (a line drawn along the water, say).
func _fit_ending_at(gesture: String, end: Vector2, width: float) -> PackedVector2Array:
	var drawn := _fit(gesture, Vector2.ZERO, width)
	var shift := end - drawn[drawn.size() - 1]
	var out := PackedVector2Array()
	for point in drawn:
		out.append(point + shift)
	return out


## A flick from the wizard toward a point: a shot goes the way the stroke points.
func _toward(me: Wizard, at: Vector2) -> PackedVector2Array:
	var from := me.center()
	var way := (at - from).normalized()
	var dense := PackedVector2Array()
	for j in 40:
		dense.append(from + way * (30.0 + 120.0 * float(j) / 40.0))
	dense.append(from + way * 150.0)
	return dense


## The stroke being drawn, growing as it is drawn, in the school's color.
class StrokeTrail extends Node2D:
	var pen: Pen
	var owner_tour: Node

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var points := pen.so_far()
		if points.size() < 2:
			return
		var c: Color = owner_tour._color
		var local := PackedVector2Array()
		for point in points:
			local.append(to_local(point))
		draw_polyline(local, Color(c.r, c.g, c.b, 0.3), 7.0)
		draw_polyline(local, Color(c.r, c.g, c.b, 0.95), 3.0)
		draw_polyline(local, Color(1.0, 1.0, 1.0, 0.9), 1.0)
		draw_circle(local[local.size() - 1], 4.0, Color(1.0, 1.0, 1.0, 0.95))
