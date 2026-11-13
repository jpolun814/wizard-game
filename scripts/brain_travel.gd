class_name BrainTravel
extends RefCounted

## How an AI wizard gets where it is going: choosing a page, a portal, a gate or a rival to go for, planning the way, walking it, swimming, and noticing it is getting nowhere.

var assail_commit := 0.0       # seconds it keeps running from a creature after it is out of reach
var assail_dir := 0.0
var stair_wait := 0.0          # seconds it has stood at a swinging stair on its way to look at somewhere new
var danger_wait := 0.0       # seconds it has stood waiting for danger on its way to pass
var dash := 0.0               # seconds it runs on across lava, whatever it does to it
var last_feet := Vector2.INF
var replans := 0                # times in a row it has had to find its way again
var goal_page: PagePickup
var goal_portal: FieldPortal
var page_steps := 0.0         # seconds it has spent walking the last steps to a page that lies just off the end of its way
var portal_jumping := 0.0     # seconds it has stood under a portal in the air, jumping for it
var haste_wait := 0.0
var off_map := false           # it stands on something the map does not hold, over ground that it does
var off_map_check := 0.0
var wander_dir := 1.0
var wander_time := 0.0
var stroke_in := 0.0         # seconds to its next stroke in the water
var for_air := false         # it is on its way up for air
var unsticks := 0               # times in a row it has had to drop what it was after
var anchor := Vector2.INF       # where it was when it last moved any distance
var anchored_for := 0.0         # seconds it has stayed within STUCK_RADIUS of it

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Walks the way to what it is after, and reads a page when it stands under one. Returns the speed to walk at.
func travel(delta: float) -> float:
	var holding := held_up(delta)
	if not is_nan(holding):
		return holding
	var at_the_goal := at_the_goal(delta)
	if not is_nan(at_the_goal):
		return at_the_goal
	var short_of_page := brain.goal == "page" and brain.route.done() and is_instance_valid(goal_page) and brain.tile_of(goal_page.global_position).distance_to(brain.tile_of(wizard.global_position)) > WizardBrain.PAGE_REACH + 2  # (its way stopped at the edge of what it knew: it looks again from there)
	if (brain.goal == "" and brain.goal_timer <= 0.0) or goal_lost() or short_of_page or ((brain.goal == "foe" or brain.goal == "exit" or brain.goal == "explore") and (brain.goal_timer <= 0.0 or brain.route.done())):
		choose_goal()
	if wizard.swim_time > 0.0:
		return swim(delta, false, Vector2.ZERO)
	if brain.goal != "" and not brain.route.done() and wizard.is_on_floor():  # (a wizard in the air cannot stop for it; after the goal is chosen, so that a gate on the way is seen before the first step towards it)
		var crossing := brain.gates.crossing_ahead()
		brain.gates.cross_run = 0.0
		if not crossing.is_empty() and brain.gates.cross(crossing):
			return brain.gates.cross_run
	# Standing on a wooden platform or a ridge that the map does not know, high over the ground it does know: it steps down through it.
	off_map_check -= delta
	if off_map_check <= 0.0 and wizard.is_on_floor():
		off_map_check = 0.4
		var here := brain.tile_of(wizard.global_position)
		var known: Vector2i = wizard.nav.nearest(here, true)
		off_map = known != WorldNav.NONE and known.y - here.y >= 3 and absi(known.x - here.x) <= 6
	if off_map and wizard.is_on_floor():
		wizard.drop_through()
	var volcano := brain.danger.volcano_near(wizard.global_position, WizardBrain.VOLCANO_FLEE) if not brain.moves.busy() else Vector2.INF
	if volcano != Vector2.INF and not wizard.lava_proof() and wizard.is_on_floor():
		brain.goal = ""  # a volcano is awake close by: it goes away from it, and chooses what to do when it is far enough off
		brain.goal_timer = 0.5
		return signf(wizard.global_position.x - volcano.x) * WizardBrain.WALK_SPEED
	return follow_route(delta)


## What keeps it from going on with its journey this frame: a manoeuvre in hand (a leap, a wade, a lift), a creature at its heels, a chant to say, a stroke
## to draw, a place to wander or escape to, a row of pads to walk, or a rest. The speed to walk at when there is one, and NAN when there is none.
func held_up(delta: float) -> float:
	if brain.moves.busy():
		return brain.moves.tick(delta)
	var assailed := assailed(delta)
	if not is_nan(assailed):
		return assailed
	if brain.settle > 0.0:
		return 0.0
	if wizard.is_drawing():
		return 0.0
	watch_progress(delta)
	if brain.goal != "" and brain.route.remaining() > WizardBrain.HASTE_FROM and wizard.haste_time <= 0.0 and haste_wait <= 0.0 and brain.knows("chant:haste") and brain.quiet_here():
		haste_wait = 25.0
		brain.chant.open("haste")  # (it stops to say it, as a person does)
		return 0.0
	haste_wait -= delta
	if wander_time > 0.0:
		wander_time -= delta
		if wizard.is_on_floor() and brain.jump_cooldown <= 0.0 and wizard.is_on_wall():
			wizard.request_jump()
			brain.jump_cooldown = 0.6
		return wander_dir * WizardBrain.WALK_SPEED
	if brain.combat.escape_time > 0.0:
		if wizard.is_on_wall() and wizard.is_on_floor() and brain.jump_cooldown <= 0.0:  # a bank too steep to walk up: it hops
			wizard.request_jump()
			brain.jump_cooldown = 0.5
		return brain.combat.escape_dir * WizardBrain.WALK_SPEED * 1.3
	if brain.gates.walking_pads():
		return brain.gates.cross_run
	if brain.mend.resting and wizard.stamina >= minf(WizardBrain.REST_UNTIL, wizard.max_stamina * 0.9):  # (a wizard worn down to a small maximum rests up to that, not up to more than it can ever hold)
		brain.mend.resting = false
	elif not brain.mend.resting and wizard.stamina < minf(WizardBrain.REST_BELOW, wizard.max_stamina * 0.3) and wizard.is_on_floor():
		brain.mend.resting = true
	if brain.mend.resting:
		return 0.0
	if wizard.nav == null:
		return 0.0
	return NAN


## What it does on coming to its goal (a portal to leap for, a page to walk the last steps to, a gate to work, a creature to clear from the way). The speed to
## walk at when it does one of them, and NAN when it has not come to anything.
func at_the_goal(delta: float) -> float:
	read_page_underfoot()
	if last_feet.distance_to(wizard.global_position) > 250.0 and last_feet != Vector2.INF:  # a portal has carried it off: the way it was going is no use
		brain.goal = ""
		brain.goal_timer = 0.0
	last_feet = wizard.global_position
	if brain.goal == "portal" and brain.route.done():
		if is_instance_valid(goal_portal) and goal_portal.lift > 0.0 and portal_jumping < WizardBrain.PORTAL_JUMP_FOR and not goal_lost():
			return jump_for_portal(delta)  # it stands under a portal hung in the air and leaps for it
		brain.skip[goal_portal.get_instance_id()] = WizardBrain.GIVE_UP  # it has come to the portal and nothing came of it
		brain.goal = ""
		brain.goal_timer = 0.0
	if brain.goal == "page" and brain.route.done() and not goal_lost() and is_instance_valid(goal_page):
		var short: Vector2 = goal_page.global_position - wizard.global_position
		if absf(short.x) > WizardBrain.PAGE_TOUCH and absf(short.x) < WizardBrain.PAGE_STEPS and absf(short.y) < WizardBrain.PAGE_STEPS and page_steps < WizardBrain.PAGE_STEPS_TIME:
			page_steps += delta  # the way ends a little short of it (the ground it lies on is not on the map): the last steps are walked
			return signf(short.x) * WizardBrain.WALK_SPEED
	if brain.goal == "page" and brain.route.done() and not goal_lost():  # it has come to the place, and the page is not to be had from there
		brain.skip[goal_page.get_instance_id()] = WizardBrain.GIVE_UP
		brain.goal = ""
		brain.goal_timer = 0.0
	if brain.goal == "gate":
		if brain.gates.gate_open(brain.gates.goal_gate["entry"]):
			brain.goal = ""
			brain.goal_timer = 0.0
		elif brain.route.done():
			brain.gates.work_gate()
			return 0.0
	var creature := brain.gates.creature_ahead()
	if not creature.is_empty():
		brain.gates.goal_gate = creature
		brain.goal = "gate"
		brain.gates.gate_tries = 0
		brain.gates.clear_gate(creature["target"])
		return 0.0
	return NAN


## One step along its route: the way the route points, and the lava that may lie on it, which it waits out, runs over or turns from.
func follow_route(delta: float) -> float:
	var steer := brain.route.steer(wizard, delta)
	if steer["replan"]:
		brain.stuck_at.append("%s %s" % [str(brain.tile_of(wizard.global_position)), brain.route.status()])
		stuck_on_goal()
	if brain.route.waiting_for_stair and brain.goal == "explore":
		stair_wait += delta
		if stair_wait > WizardBrain.STAIR_PATIENCE:  # a person does not stand at a stair for half a minute just to see what lies past it: they look elsewhere
			stair_wait = 0.0
			var far := brain.route.last()
			if far != WorldNav.NONE:  # the place it was going to is given up (a floor above or below as well as one along)
				brain.explore.explored[brain.explore.square_of(Vector2(far.x * WizardRoute.TILE, far.y * WizardRoute.TILE))] = true
			for k in range(0, 3):
				brain.explore.explored[brain.explore.square_of(wizard.global_position + Vector2(signf(brain.explore.explore_dir) * k * 600.0, 0.0))] = true
			brain.explore.explore_dir = -brain.explore.explore_dir
			brain.goal = ""
			brain.goal_timer = 0.0
			brain.route.clear()
	else:
		stair_wait = 0.0
	var ahead := signf(steer["dir"])
	if ahead != 0.0 and wizard.is_on_floor() and dash <= 0.0 and not brain.danger.lethal_at(wizard.global_position + Vector2(0, -6)):
		var near := brain.danger.lethal_at(brain.combat.over_ground(ahead * 40.0)) or brain.danger.lethal_at(brain.combat.over_ground(ahead * 72.0))
		if near or brain.danger.lethal_at(brain.combat.over_ground(ahead * 110.0)):
			# lava or an eruption lies on the way: it keeps its distance, backing away if it is close, and waits for it to pass or cool; when that takes
			# too long it looks for another way
			danger_wait += delta
			brain.route.wait()
			if danger_wait > WizardBrain.DASH_AFTER and wizard.max_stamina >= WizardBrain.DASH_MIN_MAX and lethal_stretch(ahead) <= WizardBrain.DASH_MAX:  # a narrow stretch is not worth a wait: a person runs over it and takes the hit
				dash = 1.6
				danger_wait = 0.0
				return steer["dir"] * WizardBrain.WALK_SPEED
			if danger_wait > WizardBrain.DANGER_WAIT_MAX:
				danger_wait = 0.0
				if brain.goal == "page" and is_instance_valid(goal_page):
					brain.skip[goal_page.get_instance_id()] = WizardBrain.GIVE_UP
				elif brain.goal == "explore":  # it will not look that way again: it turns round and tries the other side
					for k in range(0, 7):
						brain.explore.explored[brain.explore.square_of(wizard.global_position + Vector2(ahead * k * 600.0, 0.0))] = true
					brain.explore.explore_dir = -ahead
				brain.goal = ""
				brain.goal_timer = 0.0
				brain.route.clear()
			return -ahead * WizardBrain.WALK_SPEED * 0.8 if near else 0.0
		danger_wait = maxf(danger_wait - delta * 0.15, 0.0)  # (backing off and coming back does not start the waiting over)
	else:
		danger_wait = 0.0
	if steer["drop"]:
		wizard.drop_through()
	if steer["jump"] and wizard.is_on_floor():
		wizard.request_jump()
	wizard.climb_up = steer["climb"]  # at the foot of a rope ladder, the way up it
	wizard.let_go = steer["let_go"]  # and the hop off it at the top
	return steer["dir"] * steer["speed"]


## Out of its depth there is no walking: it swims, as a person does, the jump key a stroke at a time and S to dive (Wizard.swim). The map of ways
## (WizardRoute) is made for legs, and in the sea a jump is a stroke and a fall a slow sink: following it, wizards bobbed at the top of the sea over
## the floor they meant to reach, and three drowned against the edge of the world. So it swims straight for where it is going (the end of its route,
## the page it wants, a place a little short of the rival it fights), over whatever is in the way, and goes for air when its breath would only just
## last the way there: straight up when nothing is over it, else to an air pocket or to open water to one side. Returns its speed sideways.
func swim(delta: float, fighting: bool, to_player: Vector2) -> float:
	stroke_in -= delta
	wizard.swim_down = false
	var here := wizard.center()
	var air := nearest_air(here)
	if wizard.deep_breath_time > 0.0:
		for_air = false
	elif wizard.underwater() and wizard.breath < (absf(air.x - here.x) + absf(air.y - here.y)) / WizardBrain.SWIM_RISE + WizardBrain.AIR_SPARE:  # (the way across and then up, which it may have to take)
		for_air = true
	elif for_air and wizard.breath >= Wizard.BREATH * 0.95:
		for_air = false
	var target := air
	if not for_air:
		if fighting and to_player.length() > 1.0:
			target = here + to_player - to_player.normalized() * WizardBrain.SWIM_HOLD
		else:
			target = swim_goal()
	if target == Vector2.INF:
		return 0.0
	var line := target - here
	if not for_air and not fighting and line.length() < WizardBrain.SWIM_ARRIVE:
		brain.route.clear()  # it is there: what comes next is chosen afresh
		return 0.0
	var blocked := wizard.is_on_wall() and absf(line.x) > WizardBrain.SWIM_ARRIVE  # (a stroke takes it up over what is in the way)
	var keep_up := for_air and not wizard.underwater() and wizard.velocity.y > 0.0  # (its head over the water while it breathes)
	var overhead := line.y < -24.0 and absf(line.x) > 12.0 and not brain.danger.clear_line(here, target)  # something solid over the straight way (a wreck's hull): across under it first, then up
	if ((line.y < -24.0 and not overhead) or blocked or keep_up) and stroke_in <= 0.0:
		stroke_in = Wizard.STROKE_EVERY
		wizard.request_jump()
	elif line.y > 40.0 and not blocked:
		wizard.swim_down = true
		if wizard.is_on_floor():
			wizard.drop_through()  # (on a deck or driftwood over where it is going: it goes down through it, as a person does with S)
	return signf(line.x) * WizardBrain.WALK_SPEED if absf(line.x) > 12.0 else 0.0


## Where its journey goes, swimming: the page it wants, or the end of its route (a place to look at, the rival it hunts). INF when it has none.
func swim_goal() -> Vector2:
	if brain.goal == "page" and is_instance_valid(goal_page):
		return goal_page.global_position + Vector2(0.0, -20.0)
	if not brain.route.done():
		var end := brain.route.last()
		if end != WorldNav.NONE:
			var at := Vector2((end.x + 0.5) * WizardRoute.TILE, (end.y + 1) * WizardRoute.TILE) + wizard.center() - wizard.global_position
			if inside_solid(at):  # the map of the ways does not know a wreck's hull: a place inside one is given up as seen, and another is chosen
				brain.explore.explored[brain.explore.square_of(at)] = true
				brain.route.clear()
				brain.goal = ""
				return Vector2.INF
			return at
	return Vector2.INF


## True when a point lies inside something solid that is not the ground: a wreck's hull, a wall of stone. (The ground's outlines have no inside
## for a query to find, so it is asked of the map instead.)
func inside_solid(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return not wizard.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


## The nearest air from under the water: the surface straight over it when nothing solid is in the way, else over open water a little to one side,
## or an air pocket (AirPocket) if one is nearer.
func nearest_air(here: Vector2) -> Vector2:
	var top := wizard.water_surface()
	if top == INF:
		return here  # (in no water: it is breathing)
	var best := Vector2.INF
	for dx: float in [0.0, -96.0, 96.0, -224.0, 224.0, -384.0, 384.0, -WizardBrain.AIR_SCAN, WizardBrain.AIR_SCAN]:
		var below := Vector2(here.x + dx, here.y)
		var over := Vector2(below.x, top - 30.0)  # (its head out of the water)
		if (dx == 0.0 or brain.danger.clear_line(here, below)) and brain.danger.clear_line(below, over):
			best = over
			break
	for pocket: AirPocket in wizard.get_tree().get_nodes_in_group("air_pockets"):
		var inside := pocket.global_position + Vector2(0.0, -pocket.size.y * 0.5)
		if not brain.danger.clear_line(here, inside):
			continue  # (a pocket behind a wreck's hull is no use: it is reached round the hull, not through it)
		if best == Vector2.INF or here.distance_to(inside) < here.distance_to(best):
			best = inside
	return best if best != Vector2.INF else Vector2(here.x, top - 30.0)


## The width in pixels of the lava (or other danger) that starts within reach ahead, or INF when it is wider than it is worth, or no ground lies past it.
func lethal_stretch(ahead: float) -> float:
	var start := -1.0
	var d := 16.0
	while d <= 480.0:
		var bad := brain.danger.lethal_at(brain.combat.over_ground(ahead * d))
		if bad and start < 0.0:
			start = d
		elif not bad and start >= 0.0:
			var landing := brain.combat.over_ground(ahead * (d + 32.0))
			return d - start if not brain.danger.lethal_at(landing) and absf(landing.y - wizard.global_position.y) < 120.0 else INF
		d += 16.0
	return INF


## The way to a place, as a person would know it (owner, 2026-11-12: the brain planned its ways with the whole world's map, ground it had never
## seen included). In a match, when the way goes over ground it has not seen, it goes only as far toward the place as the ground it has seen
## takes it (`BrainExplore.toward_known`); there it sees more, and finds the way on from there. In a room (the tutorial, the waiting room) the ground is all in view.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var full := raw_path(from, to)
	if full.is_empty() or not brain.explore.sight_is_limited() or brain.explore.through_known(full, from, to):
		return full
	return brain.explore.toward_known(from, to)


func no_path() -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	return none


## The way from one tile to another that it can walk, over the whole world's map: not over a crossing it holds no spell for.
func raw_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := []
	var world := brain.the_world()
	if world != null:
		for crossing: Dictionary in world.crossings():
			if brain.gates.way_over(crossing) == "" or brain.gates.cannot.has(crossing["key"]):
				shut.append(crossing["key"])
	return wizard.nav.path(from, to, shut)


## A creature is on it: it does what a person does, and strikes it down with a spell that kills, or, with none to hand, runs. Returns the
## speed to walk at, or NAN when nothing is upon it.
func assailed(delta: float) -> float:
	assail_commit -= delta
	var mob := brain.assailant()
	if mob == null:
		if assail_commit > 0.0 and assail_dir != 0.0:
			return assail_dir * WizardBrain.WALK_SPEED * 1.2  # (it runs on a moment, and does not turn straight back to it)
		return NAN
	brain.settle = 0.0  # no one stands typing with a blade at their back
	brain.chant.typing = ""
	brain.mend.camped = false
	brain.mend.resting = false
	var away := signf(wizard.global_position.x - mob.global_position.x)
	if away == 0.0:
		away = -wizard.facing
	var spell_name := brain.gates.clearing_spell("giant" if mob.max_hp >= 1000 else "creature")
	if spell_name != "" and not wizard.is_drawing() and brain.cast_cooldown <= 0.0 and brain.react <= 0.0:
		brain.gates.goal_gate = {"kind": "giant" if mob.max_hp >= 1000 else "creature", "entry": {"mob": mob, "nodes": [mob]}, "target": mob.center()}
		brain.cast_cooldown = 1.4
		brain.hand.begin_cast(spell_name, brain.hand.gate_stroke(spell_name, mob.center()), WizardBrain.ATTACK_DRAW)
		return 0.0
	if wizard.is_drawing():
		return 0.0
	if spell_name != "" and mob.max_hp < 1000.0:
		return away * WizardBrain.WALK_SPEED * 0.6 if absf(mob.global_position.x - wizard.global_position.x) < 70.0 else 0.0  # it gives ground while its spell is ready again
	assail_dir = away
	assail_commit = 1.2
	if wizard.is_on_wall() and wizard.is_on_floor() and brain.jump_cooldown <= 0.0:
		wizard.request_jump()
		brain.jump_cooldown = 0.5
	return away * WizardBrain.WALK_SPEED * 1.2


## Picks what to go for: the page nearest by the way it must walk, and when there is none to be had, the nearest wizard.
func choose_goal() -> void:
	brain.goal_timer = WizardBrain.GOAL_EVERY
	brain.explore.sight_timer = 0.0
	brain.explore.note_sights(0.0)  # (what lies in view now is known now)
	brain.goal = ""
	var start: Vector2i = wizard.nav.nearest(brain.tile_of(wizard.global_position), true)
	if start == WorldNav.NONE:
		return
	var found := pick_page(start)
	var best_page: PagePickup = found["page"]
	var best_path: Array[Vector2i] = []
	best_path.assign(found["path"])
	var portal := brain.explore.nearest_portal(start)
	if portal.has("portal") and (best_page == null or (portal["path"].size() < best_path.size() and brain.rng.randf() < WizardBrain.PORTAL_CHANCE)):
		brain.goal = "portal"
		goal_portal = portal["portal"]
		portal_jumping = 0.0
		brain.route.set_path(portal["path"])
		return
	if brain.opponent != null and brain.strength >= WizardBrain.BOLD_ABOVE and (best_page == null or best_path.size() > WizardBrain.HUNT_PAGE_NEAR):  # feeling strong, it goes after a rival rather than a page that lies far off
		var hunt: Array[Vector2i] = find_path(start, wizard.nav.nearest(brain.tile_of(brain.sight.foe_feet())))
		if not hunt.is_empty():
			brain.goal = "foe"
			brain.route.set_path(hunt)
			return
	if best_page != null:
		brain.goal = "page"
		goal_page = best_page
		page_steps = 0.0
		brain.route.set_path(best_path)
		return
	if brain.explore.choose_explore(start):
		return
	if choose_gate(start):
		return
	var exit := wizard.get_tree().get_first_node_in_group(&"exit_points")  # a room's way out, when nothing is left to take
	if exit != null:
		var way: Array[Vector2i] = find_path(start, wizard.nav.nearest(brain.tile_of(exit.global_position)))
		if not way.is_empty():
			brain.goal = "exit"
			brain.route.set_path(way)
			return
	if brain.opponent != null:
		var path: Array[Vector2i] = find_path(start, wizard.nav.nearest(brain.tile_of(brain.sight.foe_feet())))
		if not path.is_empty():
			brain.goal = "foe"
			brain.route.set_path(path)


## The page it was going to has gone: someone else read it, or it has it already.
func goal_lost() -> bool:
	if brain.goal == "page" and brain.wise_to_mirages and is_instance_valid(goal_page) and goal_page is Mirage:
		return true
	if brain.goal == "portal":
		return not is_instance_valid(goal_portal) or goal_portal.is_closing() or goal_portal.remaining() < WizardBrain.PORTAL_LEFT * 0.5
	return brain.goal == "page" and (not is_instance_valid(goal_page) or not goal_page.gives(wizard.ledger))


## The page it will go for from where it stands: the one that seems nearest of those it knows of and can reach, and the way to it ({"page", "path"}). The
## page is null when it knows of none worth the walk. Pages it cannot reach are given up for a while on the way.
func pick_page(start: Vector2i) -> Dictionary:
	var best_page: PagePickup = null
	var best_path: Array[Vector2i] = []
	var best_worth := INF
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup.gives(wizard.ledger) or brain.skip.has(pickup.get_instance_id()) or (pickup is Mirage and brain.wise_to_mirages):
			continue
		if brain.explore.sight_is_limited() and not brain.seen_pages.has(pickup.get_instance_id()):
			continue  # it has not set eyes on that one
		if brain.danger.volcano_near(pickup.global_position, WizardBrain.VOLCANO_KEEP_OFF) != Vector2.INF and not wizard.lava_proof():
			continue  # a page by a volcano that is erupting is left until it is over
		var tile := brain.tile_of(pickup.global_position)
		var stand: Vector2i = wizard.nav.nearest(tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - tile.x) + absi(stand.y - tile.y) <= WizardBrain.PAGE_REACH:
			path = raw_path(start, stand)
			if path.is_empty() and stand == start:
				path = [start]  # it stands where the way to the page ends: nothing to walk, though the page may lie a few steps off
		if path.is_empty():
			brain.skip[pickup.get_instance_id()] = WizardBrain.GIVE_UP  # no way there that a wizard can walk
			continue
		# How far it seems: the way, when it knows the ground the way goes over; else as the crow flies, all a person can guess of ground unseen.
		var known := not brain.explore.sight_is_limited() or brain.explore.through_known(path, start, stand)
		var length := float(path.size()) if known else Vector2(stand - start).length()
		var worth := length / sqrt(maxf(1.0, float(pickup.new_pages(wizard.ledger).size())))  # a dropped book is worth the walk: the more pages it would give, the nearer it counts
		if best_page == null or worth < best_worth:
			best_page = pickup
			best_path = path if known else no_path()
			best_worth = worth
	if best_page != null and best_path.is_empty():  # it knows of the page but not the way: as far toward it as the ground it has seen takes it
		best_path = brain.explore.toward_known(start, wizard.nav.nearest(brain.tile_of(best_page.global_position)))
		if best_path.is_empty():
			brain.skip[best_page.get_instance_id()] = WizardBrain.LOOK_AGAIN  # nothing it knows leads nearer: it looks about, and comes back to it
			best_page = null
	return {"page": best_page, "path": best_path}


## When no page is to be had, the nearest gate that it holds a spell for: it goes to the place short of it. True when it has set out.
func choose_gate(start: Vector2i) -> bool:
	var world := brain.the_world()
	if world == null:
		return false
	var best := {}
	var best_path: Array[Vector2i] = []
	for gate: Dictionary in world.closed_gates():
		if brain.skip.has(brain.gates.gate_key(gate)) or brain.gates.clearing_spell(gate["kind"]) == "":
			continue
		var floor_tile: Vector2i = gate["outside"] + Vector2i(0, -1)
		var stand: Vector2i = wizard.nav.nearest(floor_tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - floor_tile.x) + absi(stand.y - floor_tile.y) <= 3:
			path = find_path(start, stand)
		if path.is_empty():
			brain.skip[brain.gates.gate_key(gate)] = WizardBrain.GIVE_UP
			continue
		if best.is_empty() or path.size() < best_path.size():
			best = gate
			best_path = path
	if best.is_empty():
		return false
	brain.goal = "gate"
	brain.gates.goal_gate = best
	brain.gates.gate_tries = 0
	brain.gates.gate_gone = 0
	brain.route.set_path(best_path)
	return true


## Reads the page it stands under, if it does not have it.
func read_page_underfoot() -> void:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if pickup.gives(wizard.ledger) and pickup.is_under(wizard):
			wizard.get_parent().read_page(pickup, wizard)
			replans = 0
			brain.goal = ""
			brain.goal_timer = 0.0
			return


## Stands under the portal it is after and jumps until it is carried off. Returns the speed to go at.
func jump_for_portal(delta: float) -> float:
	portal_jumping += delta
	if wizard.is_on_floor() and brain.jump_cooldown <= 0.0:
		wizard.request_jump()
		brain.jump_cooldown = 0.7
	var off := goal_portal.global_position.x - wizard.global_position.x
	return signf(off) * WizardBrain.WALK_SPEED * 0.5 if absf(off) > 14.0 else 0.0


## It is getting nowhere on its way: find the way again, and after a few tries give the page up for a while.
func stuck_on_goal() -> void:
	replans += 1
	if brain.goal == "portal" and replans >= 3 and is_instance_valid(goal_portal):
		brain.skip[goal_portal.get_instance_id()] = WizardBrain.GIVE_UP
		replans = 0
		choose_goal()
		return
	if brain.goal == "page" and replans >= 3 and is_instance_valid(goal_page):
		brain.skip[goal_page.get_instance_id()] = WizardBrain.GIVE_UP
		replans = 0
		choose_goal()
		return
	var start: Vector2i = wizard.nav.nearest(brain.tile_of(wizard.global_position), true)
	var path: Array[Vector2i] = find_path(start, brain.route.goal())
	if path.is_empty():
		brain.goal = ""
	else:
		brain.route.set_path(path)


## When it has got nowhere for a long time (a way its map has wrong, a ledge it cannot reach, a wind it cannot walk against), it drops what it was
## after and goes after something else, and if that does not help either it wanders a few steps, as a person does who has no idea what is wrong.
func watch_progress(delta: float) -> void:
	if wizard.global_position.distance_to(anchor) > WizardBrain.STUCK_RADIUS or brain.mend.resting or brain.goal == "":
		anchor = wizard.global_position
		anchored_for = 0.0
		return
	anchored_for += delta
	if anchored_for < WizardBrain.STUCK_FOR:
		return
	anchored_for = 0.0
	unsticks += 1
	if brain.goal == "page" and is_instance_valid(goal_page):
		brain.skip[goal_page.get_instance_id()] = WizardBrain.GIVE_UP
	elif brain.goal == "portal" and is_instance_valid(goal_portal):
		brain.skip[goal_portal.get_instance_id()] = WizardBrain.GIVE_UP
	elif brain.goal == "gate":
		brain.skip[brain.gates.gate_key(brain.gates.goal_gate)] = WizardBrain.GIVE_UP
	brain.goal = ""
	brain.goal_timer = 0.0
	brain.route.clear()
	if unsticks >= 2:
		unsticks = 0
		wander_dir = -1.0 if brain.rng.randf() < 0.5 else 1.0
		wander_time = brain.rng.randf_range(1.5, 3.0)
		wizard.request_jump()
