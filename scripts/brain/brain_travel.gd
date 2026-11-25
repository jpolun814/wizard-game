class_name BrainTravel
extends RefCounted

## How an AI wizard gets where it is going: choosing a page, a portal, a gate or a rival to go for, planning the way, walking it, swimming, and noticing it is getting nowhere.

var balked := 0.0  # seconds it has been held up by harm on its way, lately
var _out_at := -1000
var _out := 0.0  # the side it is getting out of harm by: one, till it is out
var _perils: Array[Node] = []
var _perils_seen := -1000

const STAIR_LOOKS_ELSEWHERE := 2.5  # seconds it stands at a stair that is not there, only looking about, before it thinks of going elsewhere
const STAIR_AWAY := 14.0            # and how long it then reckons it away
var away := {}                      # landing tile -> seconds it still reckons the stair to it away
var stair_held := 0.0

const RUNS_ON := 72.0
const CLEAR_OF := 40.0
const CLEAR_FOR := 45  # frames it goes on for that
const HELD_UP := 0.4           # seconds it waits for danger to pass before it thinks of another way

var assail_commit := 0.0       # seconds it keeps running from a creature after it is out of reach
var assail_dir := 0.0
var stair_idle := 0.0          # seconds it has stood at a swinging stair that goes up, whatever it is going there for
var stair_cool := 0.0          # seconds before it tries to get up a stairwell by itself again, after it has tried
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
	if brain.go.active():
		read_page_underfoot()
		if (brain.goal == "" or goal_lost()) and not brain.go.braving:  # what it was going for is gone (what it has waded into it wades out of first)
			brain.go.stop()
		else:
			return brain.go.go(delta)
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
	if wizard.pen.active():
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
		if is_instance_valid(goal_portal):  # (a portal that has collapsed since is gone, and there is nothing to give up on)
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
	stair_cool = maxf(stair_cool - delta, 0.0)
	var hop := _hop_up_the_stairwell(delta)
	if not is_nan(hop):
		return hop
	if brain.route.waiting_for_stair and _take_another_way():
		return 0.0
	for tile: Vector2i in away.keys():
		away[tile] -= delta
		if away[tile] <= 0.0:
			away.erase(tile)
	stair_held = stair_held + delta if brain.route.waiting_for_stair else 0.0
	if stair_held > STAIR_LOOKS_ELSEWHERE and brain.goal == "explore" and not brain.route.waiting_way.is_empty() and not BrainProfile.off("stairaway"):
		stair_held = 0.0  # the stair is not there: is there somewhere else to look, by what stands ready?
		away[brain.route.waiting_way["to"]] = STAIR_AWAY
		brain.goal = ""
		brain.goal_timer = 0.0
		brain.route.clear()
		return 0.0
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
	if not BrainProfile.off("movement") and brain.goal == "explore" and not brain.route.done():
		var last := brain.route.last()
		if last != WorldNav.NONE and brain.go.knows(MoveMap.feet(last)) and brain.go.harms(last):  # what it was going to look at is seen now, and is no place to be
			if not _take_another_way():
				if brain.go.thinking():
					brain.route.wait()
					return 0.0
				brain.explore.explored[brain.explore.square_of(MoveMap.feet(last))] = true
				brain.goal = ""
				brain.goal_timer = 0.0
				brain.route.clear()
			return 0.0
	var ahead := signf(steer["dir"])
	balked = maxf(balked - delta * 0.1, 0.0)
	var planned := not BrainProfile.off("movement")
	var within := planned and wizard.is_on_floor() and dash <= 0.0 and _harmed_here()
	if within:
		danger_wait += delta  # it has got into something that harms it without having meant to: it backs out, and thinks again
		brain.route.wait()
		if _out == 0.0 and brain.go.get_out():
			return 0.0
		if _out == 0.0:
			_out = _out_of_harm()
		if _out != 0.0:
			_out_at = Engine.get_physics_frames()
			if wizard.is_on_wall() and wizard.is_on_floor():
				wizard.request_jump()
			return _out * WizardBrain.WALK_SPEED
	elif wizard.is_on_floor() and _out != 0.0:
		if not harms_at(brain.combat.over_ground(-_out * CLEAR_OF)) or Engine.get_physics_frames() - _out_at > CLEAR_FOR:
			_out = 0.0
		else:  # it goes on till it is well clear, or it would only step back into it
			if wizard.is_on_wall():
				wizard.request_jump()
			return _out * WizardBrain.WALK_SPEED
	if ahead != 0.0 and wizard.is_on_floor() and dash <= 0.0 and (planned or not brain.danger.lethal_at(wizard.global_position + Vector2(0, -6))):
		var near := _lethal_ahead(ahead * 40.0) or _lethal_ahead(ahead * 72.0)
		var into: bool = steer["jump"] and not BrainProfile.off("leapover") and _lands_in_harm()  # the leap it is about to make
		if into:
			brain.route.hold_leap()
		if near or into or _lethal_ahead(ahead * 110.0):
			# lava or an eruption lies on the way: it keeps its distance, backing away if it is close, and waits for it to pass or cool; when that takes
			# too long it looks for another way
			danger_wait += delta
			balked = minf(balked + delta, 60.0)
			brain.route.wait()
			if danger_wait > HELD_UP and _take_another_way():
				return 0.0
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
	elif not planned:
		danger_wait = 0.0
	if steer["drop"]:
		wizard.drop_through()
	if steer["jump"] and wizard.is_on_floor():
		wizard.request_jump()
	wizard.pad.climb = steer["climb"]  # at the foot of a rope ladder, the way up it
	wizard.pad.let_go = steer["let_go"] or (wizard.vine.hanging() and not steer["climb"])  # and the hop off it at the top, or wherever its way no longer goes up it
	return steer["dir"] * steer["speed"]


func out_is(side: float) -> void:
	_out = side


## It is on its way out of something that harms it.
func getting_out() -> bool:
	var ago := Engine.get_physics_frames() - _out_at
	return _out != 0.0 and ago >= 0 and ago < 4


## It stands in what harms it (the same measure, whether it is stepping in or stepping out).
func _harmed_here() -> bool:
	for up: float in [-6.0, -10.0]:
		if harms_at(wizard.global_position + Vector2(0.0, up)):
			return true
	return false


## Which way the nearer edge of the harm it stands in lies.
func _out_of_harm() -> float:
	var off := 16.0
	while off < 600.0:
		for side: float in [-1.0, 1.0]:
			if not harms_at(brain.combat.over_ground(side * off)):
				return side
		off += 16.0
	return 0.0


## The leap it is at comes down in something that kills or harms.
func _lands_in_harm() -> bool:
	var tile := brain.route.leap_to()
	if tile == WorldNav.NONE:
		return false
	var there := MoveMap.feet(tile) + Vector2(0.0, -10.0)
	if brain.danger.lethal_at(there):
		return true
	if BrainProfile.off("movement"):
		return false
	var on := signf(there.x - wizard.global_position.x) * RUNS_ON  # (it runs on a little where it comes down)
	return harms_at(there) or harms_at(brain.combat.over_ground(there.x + on - wizard.global_position.x))


## Something deadly lies that far off along the ground, and the way does not go over it in a leap.
func _lethal_ahead(off: float) -> bool:
	var there := brain.combat.over_ground(off)
	var landing := WorldNav.NONE if BrainProfile.off("leapover") else brain.route.leap_over(wizard.global_position.x + off)
	if landing != WorldNav.NONE:
		there = MoveMap.feet(landing) + Vector2(0.0, -10.0)  # (it is where the leap comes down that matters)
	return brain.danger.lethal_at(there) or (not BrainProfile.off("movement") and harms_at(there))


## Something it has seen harms whoever walks there (Perils), and it does not bear that.
func harms_at(point: Vector2) -> bool:
	var now := Engine.get_physics_frames()
	if now - _perils_seen > 20 or now < _perils_seen:
		_perils_seen = now
		_perils = Perils.all(wizard.get_tree())
	for node in _perils:
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not (node.peril_box() as Rect2).grow(8.0).has_point(point):
			continue
		var does: Dictionary = node.peril_at(point)
		if does.get("harm", 0.0) > 0.0 and not (does.get("kind", "") == "heat" and wizard.lava_proof()):
			return true
	return false


## Held up on its way: it thinks of another by its spells to where it is going, and takes it when there is one. True when it has set out.
func _take_another_way() -> bool:
	if BrainProfile.off("movement") or not wizard.is_on_floor() or wizard.pen.active() or brain.route.done():
		return false
	var end := brain.route.last()
	if end == WorldNav.NONE:
		return false
	var to := brain.go.stand_near(MoveMap.feet(end), 2)
	if to != WorldNav.NONE and brain.go.harms(to):  # nobody goes to stand in what harms them: it is the far side of it that is meant
		to = brain.go.safe_beside(to, 1 if end.x >= brain.tile_of(wizard.global_position).x else -1, MoveDo.WAY_OUT)
	if to == WorldNav.NONE or brain.go.ask(to) != "found" or (brain.route.waiting_for_stair and not brain.go.by_spells()):  # (at a stair, a way on foot is the way it is on already)
		return false
	brain.route.clear()
	brain.go.set_out()
	return true


## A person who has stood a while at a stair that is not coming, and has a rocket, uses it: it steps off the landing over the open stairwell, lights the rocket,
## and comes down on the landing above. NAN when it is not doing this, otherwise the speed to go at.
func _hop_up_the_stairwell(delta: float) -> float:
	var way: Dictionary = brain.route.waiting_way
	if way.is_empty() or BrainProfile.off("stairs") or not wizard.is_on_floor():
		stair_idle = 0.0 if way.is_empty() else stair_idle
		return NAN
	var from: Vector2i = way["from"]
	var to: Vector2i = way["to"]
	var rise := from.y - to.y
	if rise < WizardRoute.CLIMB_ROWS or not brain.knows("Rocket Jump"):
		return NAN
	stair_idle += delta
	if stair_idle < WizardBrain.STAIR_IMPATIENCE or stair_cool > 0.0 or wizard.pen.active() or brain.react > 0.0:
		return NAN
	var cost: float = SpellData.SPELLS["Rocket Jump"].cost + (SpellData.SPELLS["Featherfall"].cost if brain.knows("Featherfall") else 0.0)
	if wizard.stamina < cost + 10.0:
		return NAN
	var dir := 1 if to.x > from.x else -1
	var tile := float(WizardRoute.TILE)
	var near := float(from.x + 1) * tile if dir > 0 else float(from.x) * tile  # the edge of the landing, over the stairwell
	var far := float(to.x) * tile if dir > 0 else float(to.x + 1) * tile  # the edge of the landing above
	if (near - wizard.global_position.x) * dir > 20.0:
		return dir * WizardBrain.WALK_SPEED  # walks out to the edge first
	if wizard.rocket_time <= 0.0:  # it lights the rocket standing at the edge, still (a stroke drawn on the move is dragged out of shape, and the rocket lifts slowly at first)
		brain.hand.begin_cast("Rocket Jump", BrainStrokes.offset(GestureTemplates.preview_points("rocket"), wizard.center(), 0.6), WizardBrain.QUICK_DRAW)
		return 0.0
	var shaft := Rect2(minf(near, far), float(to.y + 1) * tile, absf(far - near), float(rise) * tile)
	var helpers: Array = ["Featherfall"] if brain.knows("Featherfall") else []
	brain.moves.start_leap("stair %s %s" % [from, to], shaft, dir, {"steps": 0, "helpers": helpers, "jumped": true, "rise_to": float(to.y + 1) * tile - 40.0})  # the rocket is lit: it goes out over the stairwell as it climbs and drifts down on a feather
	stair_idle = 0.0
	stair_cool = 25.0  # (whether it gets across or not: it does not try again at once)
	return 0.0


## Out of its depth there is no walking: it swims, as a person does, the jump key a stroke at a time and S to dive (Wizard.swim). The map of ways
## (WizardRoute) is made for legs, and in the sea a jump is a stroke and a fall a slow sink: following it, wizards bobbed at the top of the sea over
## the floor they meant to reach, and three drowned against the edge of the world. So it swims straight for where it is going (the end of its route,
## the page it wants, a place a little short of the rival it fights), over whatever is in the way, and goes for air when its breath would only just
## last the way there: straight up when nothing is over it, else to an air pocket or to open water to one side. Returns its speed sideways.
func swim(delta: float, fighting: bool, to_player: Vector2) -> float:
	stroke_in -= delta
	wizard.pad.dive = false
	var here := wizard.center()
	var air := nearest_air(here)
	if wizard.deep_breath_time > 0.0:
		for_air = false
	elif wizard.lungs.submerged() and wizard.lungs.air < (absf(air.x - here.x) + absf(air.y - here.y)) / WizardBrain.SWIM_RISE + WizardBrain.AIR_SPARE:  # (the way across and then up, which it may have to take)
		for_air = true
	elif for_air and wizard.lungs.air >= Lungs.BREATH * 0.95:
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
	var keep_up := for_air and not wizard.lungs.submerged() and wizard.velocity.y > 0.0  # (its head over the water while it breathes)
	var overhead := line.y < -24.0 and absf(line.x) > 12.0 and not brain.danger.clear_line(here, target)  # something solid over the straight way (a wreck's hull): across under it first, then up
	if ((line.y < -24.0 and not overhead) or blocked or keep_up) and stroke_in <= 0.0:
		stroke_in = Wizard.STROKE_EVERY
		wizard.request_jump()
	elif line.y > 40.0 and not blocked:
		wizard.pad.dive = true
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
	var top := wizard.lungs.surface()
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
	if not away.is_empty():
		var round_about := wizard.nav.path(from, to, shut, away.keys())
		if not round_about.is_empty():
			return round_about
	return wizard.nav.path(from, to, shut)


## A creature is on it: it does what a person does, and strikes it down with a spell that kills, or, with none to hand, runs. Returns the
## speed to walk at, or NAN when nothing is upon it.
func assailed(delta: float) -> float:
	assail_commit -= delta
	var douse := _toward_water()
	if douse != 0.0:
		MatchRecorder.event("DOUSE %d %d" % [wizard.get_instance_id(), douse])
		brain.settle = 0.0  # nobody stands typing while alight
		brain.chant.typing = ""
		return douse * WizardBrain.WALK_SPEED * 1.2
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
	if spell_name != "" and not wizard.pen.active() and brain.cast_cooldown <= 0.0 and brain.react <= 0.0:
		brain.gates.goal_gate = {"kind": "giant" if mob.max_hp >= 1000 else "creature", "entry": {"mob": mob, "nodes": [mob]}, "target": mob.center()}
		brain.cast_cooldown = 1.4
		brain.hand.begin_cast(spell_name, brain.hand.gate_stroke(spell_name, mob.center()), WizardBrain.ATTACK_DRAW)
		return 0.0
	if wizard.pen.active():
		return 0.0
	if spell_name != "" and mob.max_hp < 1000.0:
		return away * WizardBrain.WALK_SPEED * 0.6 if absf(mob.global_position.x - wizard.global_position.x) < 70.0 else 0.0  # it gives ground while its spell is ready again
	assail_dir = away
	assail_commit = 1.2
	if wizard.is_on_wall() and wizard.is_on_floor() and brain.jump_cooldown <= 0.0:
		wizard.request_jump()
		brain.jump_cooldown = 0.5
	return away * WizardBrain.WALK_SPEED * 1.2


## Which way to run to put out a fire it is burning with: toward water it can see, near enough to reach before the fire is out (the match logs showed a burn lasting
## its full length, about 4 to 5 s and 30 damage, every time: nobody ran to a pond). 0 when it is not alight, or sees no water in reach.
func _toward_water() -> float:
	if BrainProfile.off("nodouse") or not wizard.is_burning() or wizard.burning_time < 1.0 or wizard.swim_time > 0.0:
		return 0.0
	var reach := minf(wizard.burning_time * WizardBrain.WALK_SPEED * 0.8, 360.0)
	var best := INF
	var dir := 0.0
	for water in wizard.get_tree().get_nodes_in_group("waters"):
		if not is_instance_valid(water) or not water.has_method("wets"):
			continue
		for step in range(-12, 13):
			var point: Vector2 = Vector2(wizard.global_position.x + step * 30.0, wizard.global_position.y + 10.0)
			if absf(step * 30.0) < best and absf(step * 30.0) <= reach and water.wets(point) and wizard.eyes.sees_point(point):
				best = absf(step * 30.0)
				dir = signf(step) if step != 0 else 0.0
	return dir if best < INF else 0.0


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
	if best_page == null and take_to_its_spells():
		return
	var portal := brain.explore.nearest_portal(start)
	if portal.has("portal") and (best_page == null or (portal["path"].size() < best_path.size() and brain.rng.randf() < WizardBrain.PORTAL_CHANCE)):
		brain.goal = "portal"
		goal_portal = portal["portal"]
		portal_jumping = 0.0
		brain.route.set_path(portal["path"])
		return
	if brain.opponent != null and brain.strength >= BrainProfile.knob("bold", WizardBrain.BOLD_ABOVE) and (best_page == null or best_path.size() > WizardBrain.HUNT_PAGE_NEAR or (brain.aggression * BrainProfile.knob("aggr", 1.0) >= 0.5 and not BrainProfile.off("press") and BrainProfile.off("oldhunt"))):  # feeling strong, it goes after a rival rather than a page that lies far off
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


## No page can be walked to: the nearest it knows of that there is a way to by its spells. True when it has set out, and not while it is still thinking.
func take_to_its_spells() -> bool:
	if BrainProfile.off("movement"):
		return false
	var best: PagePickup = null
	var best_tile := WorldNav.NONE
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup.gives(wizard.ledger) or (pickup is Mirage and brain.wise_to_mirages) or (brain.explore.sight_is_limited() and not brain.seen_pages.has(pickup.get_instance_id())):
			continue
		var tile := brain.go.stand_near(pickup.global_position, WizardBrain.PAGE_REACH)
		if tile == WorldNav.NONE or brain.go.ask_before(tile):
			continue
		if best == null or pickup.global_position.distance_to(wizard.global_position) < best.global_position.distance_to(wizard.global_position):
			best = pickup
			best_tile = tile
	if best == null:
		return false
	match brain.go.ask(best_tile):
		"found":
			brain.goal = "page"
			goal_page = best
			page_steps = 0.0
			brain.go.set_out()
			return true
		"thinking":
			brain.goal_timer = 0.2  # (it looks again soon)
	return false


## The page it was going to has gone: someone else read it, or it has it already.
func goal_lost() -> bool:
	if brain.goal == "page" and brain.wise_to_mirages and is_instance_valid(goal_page) and goal_page is Mirage:
		return true
	if brain.goal == "portal":
		return not is_instance_valid(goal_portal) or goal_portal.is_closing() or goal_portal.remaining() < WizardBrain.PORTAL_LEFT * 0.5
	return brain.goal == "page" and (not is_instance_valid(goal_page) or not goal_page.gives(wizard.ledger))


## How much a page is wanted for the kit it would add to, from its color alone (a page is outlined in its school's color, and the spell inside is not shown): a school it
## holds little of counts for more, so a wizard of all fire goes a little farther for water or air. 1 for a page of a school it holds plenty of, up to 1.6.
func kit_want(pickup: PagePickup) -> float:
	if BrainProfile.off("kit"):
		return 1.0
	var best := 1.0
	for school: String in pickup.schools():
		var held := 0
		for spell: Spell in SpellData.SPELLS.values():
			if spell.school == school and wizard.ledger.knows_spell(spell.spell_name):
				held += 1
		best = maxf(best, 1.0 + 0.6 / (1.0 + held))
	return lerpf(1.0, best, minf(brain.skill / 0.65, 1.0))


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
		var worth := length / sqrt(maxf(1.0, float(pickup.new_pages(wizard.ledger).size()))) / kit_want(pickup)  # a dropped book is worth the walk: the more pages it would give, the nearer it counts
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
		if brain.skip.has(brain.gates.gate_key(gate)) or brain.gates.clearing_spell(gate["kind"]) == "" or brain.gates.gate_open(gate["entry"]):  # (a creature put to sleep is cleared, though the world may still list it)
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
