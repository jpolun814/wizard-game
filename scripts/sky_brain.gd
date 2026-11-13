class_name SkyBrain
extends WizardBrain

## A rival wizard's mind in the sky world (chapter 19), where nobody walks: it flies. It is the ordinary brain with its legs changed, so it still
## looks about, reads pages, picks its attacks from the same scores and draws them as real strokes, and keeps a person's pace and reactions. What it does not
## have is a map of ways (there is no ground to make one of): it steers straight, round the thunderclouds, to a page it has seen, to a rival
## it means to fight, or, with neither in mind, to look at a part of the sky it has not been to. Clouds of the plain kind do not stop it going through;
## they hide it, as they would a person (see SkyCloud.blocks). It knows a page is going: one that has left the world is dropped from its mind (_goal_lost).

const EXPLORE_REACH := 1100.0   # how far off it picks a place to look at
const EXPLORE_GIVE_UP := 9.0    # seconds it flies toward one place before it picks another
const ARRIVED := 110.0          # pixels from a place it is going to at which it has got there
const STORM_MARGIN := 150.0     # how wide a berth it gives a thundercloud
const DODGE_FOR := 0.45         # seconds it spends getting out of the way of a shot
const HOLD_RANGE := 300.0       # the distance it keeps from a rival it fights: far enough that a blow is seen coming, near enough to strike
const GIVE_UP_PAGE := 12.0      # seconds a page it cannot get near stays off its list

var _target := Vector2.INF      # the place it is flying to
var _target_age := 0.0
var _dodge := 0.0
var _dodge_dir := Vector2.ZERO
var _orbit := 1.0               # which way round a rival it circles


func think(delta: float) -> void:
	_hurt_age += delta
	_note_new_pages(delta)
	hand.tick(delta)
	cast_cooldown -= delta
	_defend_cooldown -= delta
	goal_timer -= delta
	_target_age += delta
	_dodge -= delta
	for key in _rest.keys():
		_rest[key] -= delta
		if _rest[key] <= 0.0:
			_rest.erase(key)
	for key in skip.keys():
		skip[key] -= delta
		if skip[key] <= 0.0:
			skip.erase(key)
	explore.note_sights(delta)
	sight.track_shots()
	sight.look_about(delta)
	sight.notice_decoys()
	_foe = sight.lure.caster if sight.lure != null else sight.nearest_foe()
	_strength_in -= delta
	if _strength_in <= 0.0:
		_strength_in = 1.0
		_strength = _feel_strength(_foe)
	_read_page_underfoot()
	if react > 0.0:
		react -= delta
		if react <= 0.0:
			_act(_reaction)
	var foe: Wizard = _foe
	var to_player := Vector2.ZERO
	var sees := false
	if is_instance_valid(foe):
		to_player = sight.seen_center(foe) - wizard.center()
		sees = (wizard.eyes.sees_point(sight.lure.center()) if sight.lure != null else eyes_see(foe)) and danger.clear_line(wizard.center(), sight.seen_center(foe))
	var fighting := sees and to_player.length() < ENGAGE
	if react <= 0.0 and not wizard.is_drawing():
		var shot := sight.incoming_shot()
		if not shot.is_empty() and _defend_cooldown <= 0.0:
			_threat_dir = shot["dir"]
			var choice := _choose_defence(shot["eta"])
			if choice == "":
				_dodge = DODGE_FOR  # nothing to put up against it: it gets out of the way
				_dodge_dir = _threat_dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
				_defend_cooldown = 0.8
			else:
				_plan(choice, _reaction_time())
		elif _defend_cooldown <= 0.0 and fighting and to_player.length() < TOO_CLOSE and knows("Push") and wizard.stamina >= 10.0:
			_plan("push", _reaction_time())
	var heading := _heading(delta, to_player, sees, fighting)
	var speed := minf(1.0, heading.length())
	if wizard.is_drawing() or holds_still():
		heading = Vector2.ZERO  # it stops to draw: the screen would drag the stroke out of shape
	var way := heading.normalized() * speed if heading != Vector2.ZERO else Vector2.ZERO
	wizard.walk(way.x * Wizard.FLY_SPEED)
	wizard.fly_y = _hold_or(way.y)
	var running := absf(way.x) > 0.05 and not wizard.is_drawing()
	wizard.facing = signf(way.x) if running else (signf(to_player.x) if (fighting or wizard.is_drawing()) and to_player.x != 0.0 else wizard.facing)
	if not fighting or react > 0.0 or wizard.is_drawing():
		return
	if cast_cooldown <= 0.0:
		if _smothering() or _hiding():
			cast_cooldown = 0.3
		elif foe.has_shield():
			cast_cooldown = 0.3
		elif _attack(to_player, sees):
			cast_cooldown = lerpf(2.8, 1.5, skill) + rng.randf() * 0.8
		else:
			cast_cooldown = 0.4


## What the wizard asks of the air up and down: a wizard that wants to stay level leans a little against the drift, or it would sink off the place it is going to.
func _hold_or(ask: float) -> float:
	if absf(ask) < 0.05:
		return -Wizard.FLY_DRIFT / Wizard.FLY_SPEED
	return ask


## Which way, and how hard (0 to 1), it flies this frame: out of a storm or a danger first, then out of the way of a shot, then at a rival it fights, then on its journey.
func _heading(delta: float, to_player: Vector2, sees: bool, fighting: bool) -> Vector2:
	var here := wizard.center()
	var out := _way_out(here)
	if out != Vector2.ZERO:
		return out
	if _dodge > 0.0:
		return _dodge_dir
	if fighting and not wizard.is_drawing():
		return _footwork_in_the_air(to_player)
	if _foe != null and sees and to_player.length() < ENGAGE * 1.4:
		return _aim(here, wizard.center() + to_player - to_player.normalized() * HOLD_RANGE)
	return _journey(delta)


## Out of the way of a thundercloud, or of anything else that hurts: away from it. Zero when it is clear of them all.
func _way_out(here: Vector2) -> Vector2:
	for cloud: SkyCloud in wizard.get_tree().get_nodes_in_group("thunderclouds"):
		var room := cloud.region().grow(STORM_MARGIN * 0.5)
		if room.has_point(here):
			var push := here - room.get_center()
			return push.normalized() if push != Vector2.ZERO else Vector2.UP
	if danger.in_danger(here) or danger.in_danger(wizard.global_position):
		for angle in range(0, 360, 45):
			var dir := Vector2.RIGHT.rotated(deg_to_rad(float(angle)))
			if not danger.in_danger(here + dir * 160.0):
				return dir
	return Vector2.ZERO


## Fights at a distance it holds, circling a little: up or down more than along, since there is no ground to keep to.
func _footwork_in_the_air(to_player: Vector2) -> Vector2:
	var gap := to_player.length()
	if gap < 1.0:
		return Vector2.ZERO
	var toward := to_player / gap
	if gap < NEAR:
		return -toward
	if gap > HOLD_RANGE + 100.0:
		return toward * 0.8
	_strafe_timer -= 0.016
	if _strafe_timer <= 0.0:
		_strafe_timer = rng.randf_range(1.2, 2.6)
		_orbit = -_orbit
	return toward.orthogonal() * _orbit * 0.35


## Its journey: to the page it means to have, or to the rival it hunts, or to look at somewhere new.
func _journey(delta: float) -> Vector2:
	if goal_timer <= 0.0 or _goal_lost() or _target == Vector2.INF:
		_choose_where()
	if goal == "page" and is_instance_valid(_goal_page):
		_target = _goal_page.global_position + Vector2(0.0, -PagePickup.FLOAT)
		_page_steps += delta
		if _page_steps > GIVE_UP_PAGE * 3.0:
			skip[_goal_page.get_instance_id()] = GIVE_UP_PAGE
			goal = ""
			goal_timer = 0.0
	elif goal == "foe" and is_instance_valid(_foe):
		_target = sight.seen_center(_foe)
	if _target == Vector2.INF:
		return Vector2.ZERO
	var gap := _target.distance_to(wizard.center())
	if gap < (FallingPage.TOUCH * 0.6 if goal == "page" else ARRIVED):
		if goal == "explore":
			goal_timer = 0.0
		return Vector2.ZERO
	if goal == "explore" and _target_age > EXPLORE_GIVE_UP:
		goal_timer = 0.0
	return _aim(wizard.center(), _target)


## The way to a point, bent round any thundercloud that lies on it.
func _aim(from: Vector2, to: Vector2) -> Vector2:
	var line := to - from
	if line == Vector2.ZERO:
		return Vector2.ZERO
	var dir := line.normalized()
	var ahead := minf(line.length(), 420.0)
	for cloud: SkyCloud in wizard.get_tree().get_nodes_in_group("thunderclouds"):
		var room := cloud.region().grow(STORM_MARGIN)
		var middle := room.get_center()
		var along := (middle - from).dot(dir)
		if along < -60.0 or along > ahead + 200.0:
			continue
		var off := (middle - from) - dir * along
		var close := maxf(room.size.x, room.size.y) * 0.5
		if off.length() < close and (room.has_point(from + dir * clampf(along, 0.0, ahead)) or Geometry2D.segment_intersects_circle(from, from + dir * ahead, middle, close) >= 0.0):
			var side := -1.0 if off.cross(dir) > 0.0 else 1.0  # round whichever side it is already toward
			dir = (dir + dir.orthogonal() * side * 1.6).normalized()
	return dir


## Picks what to go for: the page it has seen that is nearest, or a rival it feels strong enough to hunt, or somewhere to look.
func _choose_where() -> void:
	goal_timer = GOAL_EVERY
	_target_age = 0.0
	_page_steps = 0.0
	goal = ""
	var best: PagePickup = null
	var best_gap := INF
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup.gives(wizard.ledger) or skip.has(pickup.get_instance_id()) or (pickup is Mirage and _wise_to_mirages):
			continue
		if not seen_pages.has(pickup.get_instance_id()):
			continue  # it has not set eyes on that one
		var gap := pickup.global_position.distance_to(wizard.global_position)
		if gap < best_gap:
			best_gap = gap
			best = pickup
	if best != null:
		goal = "page"
		_goal_page = best
		return
	if is_instance_valid(_foe) and _strength >= BOLD_ABOVE:
		goal = "foe"
		return
	goal = "explore"
	_target = _explore_point()


## A place to fly to and look at, not far off, in a part of the sky it has not been to when it can find one.
func _explore_point() -> Vector2:
	var here := wizard.global_position
	var box := wizard.fly_box
	var best := Vector2.INF
	var best_new := false
	for k in 8:
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var spot := here + dir * rng.randf_range(EXPLORE_REACH * 0.5, EXPLORE_REACH)
		if box.size != Vector2.ZERO:
			spot = spot.clamp(box.position + Vector2(200.0, 200.0), box.end - Vector2(200.0, 200.0))
		var fresh := not explore.explored.has(explore.square_of(spot))
		if best == Vector2.INF or (fresh and not best_new):
			best = spot
			best_new = fresh
		if best_new:
			break
	return best


## The screen does not fall with a wizard that flies, so the view's own motion is all that bends a stroke here (see BrainHand.drag_ok).
func drag_gravity() -> float:
	return 0.0


## A wizard that flies is never "on the floor": a shot's dodge by jumping and the rest are left out.
func status() -> String:
	return "sky:" + goal
