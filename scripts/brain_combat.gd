class_name BrainCombat
extends RefCounted

## How an AI wizard fights: when and what it attacks with, the footwork around a rival, how it answers a shot (a dodge, a Barrier, a blink), where it stands and when it goes for a way up to a rival.

var defend_cooldown := 0.0
var escape_commit := 0.0     # seconds it keeps the way it chose out of danger
var escape_dir := 0.0
var escape_time := 0.0
var strafe := 0.0
var strafe_timer := 0.0
var threat_dir := Vector2.ZERO
var recent: Array[String] = []  # its last two attacks, which it avoids repeating
var hop_timer := 1.5  # counting down to its next hop while it walks

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Picks an attack for the situation and starts drawing it. Returns false if nothing is worth casting now.
func attack(to_player: Vector2, sees: bool) -> bool:
	var foe: Wizard = brain.opponent
	if absf(to_player.x) > WizardBrain.ATTACK_RANGE:
		return false  # too far off to aim at you: it waits for you to come within reach
	var gap := absf(to_player.x)
	var still: bool = foe.velocity.length() < 30.0
	var stuck: bool = brain.held(foe)
	var grounded: bool = foe.stands()
	var closing: bool = signf(foe.velocity.x) == signf(-to_player.x) and absf(foe.velocity.x) > 60.0
	var aim_ok := absf(to_player.normalized().x) > 0.4  # a near-vertical stroke is a poor flick
	var scores := {
		"Ignite": (2.0 if gap > 140.0 else 0.8) if sees and aim_ok else 0.0,
		"Frostbolt": (0.4 if foe.is_slowed() else 1.6) if sees else 0.0,
		"Spark": 2.2 if still or stuck else 1.0,
		"Stonefall": 3.0 if stuck else (1.8 if still else 0.5),
		"Icicles": 2.0 if ceiling_over(brain.sight.seen_center(foe)) else 0.0,  # they hang from a ceiling, wherever there is one over you
		"Spore Puff": 1.6 if gap < 240.0 else 0.0,
		"Stalagmite": (2.0 if still or stuck else 1.0) if grounded and gap < 360.0 else 0.0,
		"Bramble": (1.4 if closing else 0.7) if grounded and gap > 100.0 else 0.0,
		"Flytrap": 1.3 if grounded and (still or stuck) else 0.0,  # a trap snaps shut on whoever stands in it
		"Sinkhole": 1.5 if grounded and (still or stuck) and gap < 340.0 else 0.0,
		"Hex": 1.4 if Hex.multiplier(wizard.get_tree(), foe) <= 1.0 else 0.0,
		"Vacuum": 1.5 if not foe.smothered and gap < 400.0 else 0.0,
		"Faint": 1.6 if not foe.fainted and gap < 400.0 else 0.0,
		"Fight or Flight": 0.6 if foe.rage_time <= 0.0 and foe.fear_time <= 0.0 else 0.0,
		"Silence": (1.8 if foe.pen.active() else 0.6) if gap > Silence.RADIUS + 45.0 else 0.0,  # the ring is drawn round you, so well clear of it
		"Tide Surf": 1.0 if grounded and gap > 110.0 and gap < 320.0 else 0.0,
		"Thunderclap": 1.7 if gap < Thunderclap.RADIUS - 40.0 and foe.daze_time <= 0.0 else 0.0,
		"Tornado": (0.6 + brain.pressure * 0.5) if gap < 260.0 else 0.2,
		"Ice Prison": 1.3 if gap < 360.0 and not stuck else 0.0,
		"Mudslide": 1.1 if grounded and not stuck else 0.0,
		"Black Hole": (0.4 + brain.pressure * 0.4) if gap < 300.0 else 0.0,
		"Firewall": (1.6 if closing else 0.5) if gap < 280.0 and gap > 90.0 else 0.0,
		"Blizzard": 0.4 if grounded else 0.0,
		"Fire Breath": 1.8 if gap < 240.0 else 0.0,
		"Earthquake": 1.5 if grounded and gap < 300.0 and own_walkers_near(300.0) < 2 else 0.0,
		"Barbs": 1.7 if sees and aim_ok and gap < 300.0 else 0.0,
		"Pebble": (1.3 if gap < 460.0 else 0.0) if aim_ok else 0.0,  # lobbed, so it needs no clear line
		"Hailstorm": 1.5 if gap < 420.0 and not sheltered() else 0.0,
		"Thorn Whip": 1.3 if sees and aim_ok and gap > 110.0 and gap < 340.0 else 0.0,  # it drags you in
		"Insect Plague": 1.2 if gap < 480.0 else 0.0,
		"Flaming Sphere": 1.3 if grounded and aim_ok and gap > 120.0 and gap < 620.0 else 0.0,  # it rolls along the ground toward you
		"Mirage": 0.9 if gap > 250.0 and grounded and brain.real_page_near(500.0) and brain.mirages_set() < 2 else 0.0,  # a bait set among real pages, with the rival still some way off; nonsense at arm's length, or where no page lies
		"Raise Dead": 1.2 if gap < 560.0 and grounded and wizard.max_stamina > 120.0 and brain.own_raised() < 2 else 0.0,
		"Leech": 1.0 if sees and aim_ok and gap < Leech.REACH - 40.0 and Leech.held_by(wizard.get_tree(), wizard) == null else 0.0,
		"Eldritch Blast": 1.4 if sees and gap > 120.0 and gap < 560.0 else 0.0,  # slow, and it bends toward you
		"Hemorrhage": 1.2 if sees and gap < 420.0 else 0.0,
		"Supernova": 1.4 if gap < 560.0 and wizard.max_stamina > 140.0 and not sheltered() else 0.0,  # a sun that hangs about: it likes a rival who stays near
		"Scythe": 2.0 if sees and gap < 110.0 else 0.0,  # only at arm's length
	}
	if sheltered():
		# Under a platform: lightning from above cannot reach you.
		scores["Spark"] = 0.0
	if not sees:
		# Behind cover: only spells that come from above or along the ground reach you.
		for spell_name in ["Ignite", "Frostbolt", "Ice Prison", "Black Hole", "Firewall", "Fire Breath", "Barbs", "Thorn Whip", "Leech", "Eldritch Blast", "Hemorrhage", "Scythe"]:
			scores[spell_name] = 0.0
	for spell_name in scores.keys():
		if not brain.ready_to_cast(spell_name):
			scores[spell_name] = 0.0
		elif spell_name in recent:
			scores[spell_name] *= 0.25  # it does not keep repeating itself
	var choice := pick(scores)
	if choice == "":
		return false
	recent.push_front(choice)
	if recent.size() > 2:
		recent.pop_back()
	brain.hand.begin_cast(choice, brain.hand.attack_stroke(choice), WizardBrain.ATTACK_DRAW, true)
	return true


func footwork(delta: float, to_player: Vector2, sees: bool) -> float:
	if wizard.pen.active():
		return 0.0
	var speed := WizardBrain.WALK_SPEED
	if escape_time > 0.0:
		return escape_dir * speed * 1.3
	var gap := absf(to_player.x)
	var toward := signf(to_player.x)
	var dir := 0.0
	if brain.hiding():
		dir = -toward  # slipping away unseen
	elif not sees:
		dir = toward  # get a clear line
	elif gap < WizardBrain.NEAR or (to_player.y < -WizardBrain.CHASE_ABOVE and WizardBrain.LIFT_CLOSE.has(ready_lift()) and gap > WizardBrain.LIFT_CLOSE[ready_lift()] + 30.0):
		# A rival high on a ledge is not backed away from: it stands where its way up is cast from (under them for a rising column of air, right at the foot
		# of the ledge for a vine or an oak, which it must climb and cross within a few steps), and raises itself.
		var lift := ready_lift()
		var high: bool = to_player.y < -WizardBrain.CHASE_ABOVE and lift != ""
		if high and WizardBrain.LIFT_CLOSE.has(lift):
			dir = toward if gap > WizardBrain.LIFT_CLOSE[lift] + 30.0 else 0.0
		else:
			dir = 0.0 if high and gap > WizardBrain.LIFT_STAND.get(lift, 120.0) else -toward  # a rival high on a ledge is not backed away from: it stands under them, and raises itself up
	elif gap > WizardBrain.FAR:
		dir = toward
	else:
		strafe_timer -= delta
		if strafe_timer <= 0.0:
			strafe_timer = brain.rng.randf_range(1.3, 3.2)  # (a person holds a direction, or stands, for a while: they do not change their mind every second)
			strafe = [-1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0][brain.rng.randi() % 7]  # (a recorded person stood still 47% of a fight and went each way about a quarter)
		dir = strafe
	# Never back into the edge of the map; it would rather stand its ground there.
	var x: float = wizard.global_position.x
	if (dir < 0.0 and x < ArenaGen.left_edge() + 60.0) or (dir > 0.0 and x > ArenaGen.right_edge() - 60.0):
		dir = 0.0
	# Never walk into something burning.
	if dir != 0.0 and brain.danger.in_danger(wizard.global_position + Vector2(dir * 34.0, -10.0)):
		dir = 0.0
	if wizard.is_on_floor() and brain.jump_cooldown <= 0.0:
		var blocked: bool = dir != 0.0 and wizard.is_on_wall()
		# Up onto a ledge you are standing on, whether or not it can see you, or when it is blocked.
		var above: bool = to_player.y < -50.0 and absf(to_player.x) < 260.0 and ready_lift() == ""  # (with a way up to cast, it does not hop at the ledge)
		# Now and then, while it moves, it hops: a person does, but not every second.
		hop_timer -= delta
		var hop: bool = dir != 0.0 and hop_timer <= 0.0
		if hop:
			hop_timer = brain.rng.randf_range(2.0, 5.0)  # (a recorded person hops about every three seconds in a fight)
		if blocked or above or hop:
			wizard.request_jump()
			brain.jump_cooldown = 0.9
	return dir * speed


func act(reaction: String) -> void:
	var foe: Wizard = brain.opponent
	if (not is_instance_valid(foe)) and reaction in ["push", "breath", "spores", "geyser", "surf", "blink_side", "blink_away"]:
		return  # (a reaction planned against a rival who is gone from its mind by the time it comes)
	match reaction:
		"jump":
			if wizard.is_on_floor():
				wizard.request_jump(0.8)
			defend_cooldown = 0.6
		"reflect":
			# A Gust blown toward where the shot came from: it turns the shot round and sends it back.
			var start: Vector2 = wizard.center() - threat_dir * 20.0
			brain.hand.begin_cast("Gust", BrainStrokes.line(start, start - threat_dir * 90.0), WizardBrain.QUICK_DRAW)
			defend_cooldown = 1.4
		"cover":
			var watchers := brain.watchers()
			if not watchers.is_empty():
				brain.gates.cover(watchers[0])
			defend_cooldown = 4.0
		"shield":
			brain.hand.begin_cast("Barrier", BrainStrokes.offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), WizardBrain.QUICK_DRAW)
			defend_cooldown = 2.5
		"blink_side", "blink_away":
			blink_away(foe)
			defend_cooldown = 1.6
		"escape":
			if escape_commit <= 0.0 or escape_dir == 0.0:
				escape_dir = safe_side()  # (once it has chosen a way out, it keeps to it for a while rather than turning back at every lick of flame)
				escape_commit = 1.8
			escape_time = 0.6
			if brain.knows("Shadow Step") and wizard.stamina >= 12.0 and brain.rng.randf() < brain.skill * 0.6:
				var from: Vector2 = wizard.center()
				brain.hand.begin_cast("Shadow Step", BrainStrokes.line(from, from + Vector2(escape_dir * 240.0, -12.0)), WizardBrain.QUICK_DRAW)  # (to the safe side, not away from the rival)
			defend_cooldown = 0.6
		"push":
			var away: Vector2 = (brain.sight.seen_center(foe) - wizard.center()).normalized()
			brain.hand.begin_cast("Push", brain.hand.push_stroke(brain.sight.seen_center(foe), away), WizardBrain.QUICK_DRAW)
			defend_cooldown = 1.5
		"breath":
			brain.hand.begin_cast("Fire Breath", brain.hand.breath_stroke(brain.sight.seen_center(foe)), WizardBrain.QUICK_DRAW + 0.1)
			defend_cooldown = 1.8
		"spores":
			brain.hand.begin_cast("Spore Puff", brain.hand.breath_stroke(brain.sight.seen_center(foe)), WizardBrain.QUICK_DRAW + 0.1)
			defend_cooldown = 1.8
		"geyser":  # the ground bubbles under its feet and throws it off
			brain.hand.begin_cast("Geyser", BrainStrokes.offset(GestureTemplates.preview_points("geyser"), brain.sight.seen_feet(foe) + Vector2(0.0, -24.0), 0.6), WizardBrain.QUICK_DRAW)
			defend_cooldown = 1.8
		"surf":
			brain.hand.begin_cast("Tide Surf", brain.hand.surf_stroke(signf(brain.sight.seen_feet(foe).x - wizard.global_position.x)), WizardBrain.QUICK_DRAW)
			defend_cooldown = 1.8


func choose_defence(eta: float) -> String:
	var options := {"jump": 1.0}
	if brain.knows("Gust") and wizard.stamina >= 15.0 and eta > WizardBrain.QUICK_DRAW + 0.05:
		options["reflect"] = 0.6 + 1.6 * brain.skill  # a skilled wizard sends your spells back at you
	if brain.knows("Barrier") and wizard.stamina >= 35.0 and eta > WizardBrain.QUICK_DRAW + 0.05:
		options["shield"] = 0.5
	if brain.knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_side"] = 0.7
	if not wizard.is_on_floor():
		options.erase("jump")
	return pick(options) if not options.is_empty() else ""


func choose_repel() -> String:
	var options := {}
	if brain.ready_to_cast("Geyser") and brain.opponent.stands():
		options["geyser"] = 1.0
	if brain.ready_to_cast("Tide Surf"):
		options["surf"] = 0.9
	if brain.ready_to_cast("Spore Puff") and brain.danger.clear_line(wizard.center(), brain.sight.seen_center(brain.opponent)):
		options["spores"] = 1.1
	if brain.knows("Push") and wizard.stamina >= 10.0:
		options["push"] = 1.5
	if brain.knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_away"] = 1.0
	if brain.knows("Fire Breath") and wizard.stamina >= 16.0 and brain.danger.clear_line(wizard.center(), brain.sight.seen_center(brain.opponent)):
		options["breath"] = 1.3
	return pick(options) if not options.is_empty() else "escape"


## Steps away from the player along the ground, or past them if its back is to a wall.
func blink_away(foe: Wizard) -> void:
	var away := -signf(brain.sight.seen_feet(foe).x - wizard.global_position.x)
	if away == 0.0:
		away = 1.0
	var room := (ArenaGen.right_edge() - wizard.global_position.x) if away > 0.0 else (wizard.global_position.x - ArenaGen.left_edge())
	if room < 120.0:
		away = -away  # cornered: go past the player instead
	var start: Vector2 = wizard.center()
	brain.hand.begin_cast("Shadow Step", BrainStrokes.line(start, start + Vector2(away * 240.0, -12.0)), WizardBrain.QUICK_DRAW)


## Which way is away from danger: the way to the nearest ground that is not burning or dangerous. It looks as far as a few hundred pixels,
## because a flow of lava down a slope is wider than a step.
func safe_side() -> float:
	var volcano := brain.danger.volcano_near(wizard.global_position, 900.0)  # lava from a volcano pours down its flanks: running up toward it is running into more of it
	if volcano != Vector2.INF and absf(wizard.global_position.x - volcano.x) > 40.0:
		return signf(wizard.global_position.x - volcano.x)
	var reach := [INF, INF]
	for k in 2:
		var dir := -1.0 if k == 0 else 1.0
		for step in range(30, 811, 30):
			var spot := over_ground(dir * step)
			if not brain.danger.in_danger(spot) and not brain.danger.in_danger(spot + Vector2(0.0, 12.0)) and not brain.danger.in_shoal(spot):
				reach[k] = float(step)
				break
	if reach[0] == reach[1]:
		if escape_dir != 0.0:
			return escape_dir
		return -signf(brain.sight.seen_feet(brain.opponent).x - wizard.global_position.x) if brain.opponent != null else 1.0
	var best := -1.0 if reach[0] < reach[1] else 1.0
	if escape_dir != 0.0 and reach[0 if escape_dir < 0.0 else 1] <= reach[0 if best < 0.0 else 1] * 1.6 + 60.0:
		return escape_dir  # the way it was already running is nearly as good: it does not turn back and forth in the flow
	return best


## The point just over the ground at a distance sideways: on a slope, the ground there is higher or lower than where it stands.
func over_ground(dx: float) -> Vector2:
	var from := Vector2(wizard.global_position.x + dx, wizard.global_position.y - 140.0)
	var ground := SpellTargets.ground_below(wizard.get_world_2d(), from, 420.0)
	return Vector2(from.x, ground.y - 10.0)


## True when something solid (a platform or the ground) is above you, so nothing from the sky can reach you.
func sheltered() -> bool:
	var top: Vector2 = brain.sight.seen_center(brain.opponent) + Vector2(0, -50)
	# Cast from the sky down, the way lightning comes: a one-way platform only stops things from above.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -600), top)
	query.collision_mask = 1 | 16
	return not wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## How far it would fall from here before it met ground or a platform (a long way, when there is nothing under it).
func drop_below() -> float:
	var from := wizard.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 2000.0), 1 | 16)
	query.exclude = [wizard.get_rid()]
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return 2000.0 if hit.is_empty() else from.distance_to(hit["position"])


## A long fall ahead: a Featherfall is drawn the moment it begins, while the view still keeps up with the stroke. Once the wizard is falling
## fast the screen drags the stroke out of shape, as it would a person's, and it is too late. Walking on as it drops would drag the stroke
## sideways too: it lets go of the keys, as a person does to draw on the way down, and draws as soon as the view keeps up.
func catch_fall() -> void:
	if wizard.is_on_floor() or wizard.velocity.y <= 0.0 or wizard.feather_time > 0.0 or wizard.pen.active() or brain.chant.is_typing() or not brain.ready_to_cast("Featherfall"):
		return
	if drop_below() <= WizardBrain.LONG_FALL:
		return
	if not brain.hand.drag_ok("Featherfall", WizardBrain.QUICK_DRAW):
		brain.hand.stand_still()
		return
	brain.hand.begin_cast("Featherfall", brain.hand.tend_stroke("Featherfall", Vector2.ZERO), WizardBrain.QUICK_DRAW)


## A rival standing over its head, on a ledge: it raises itself up to them with the first spell it holds that does it. True when it has begun.
func chase(to_player: Vector2) -> bool:
	if not wizard.is_on_floor() or brain.rest.has("chase") or not brain.moves.lift.is_empty():
		return false
	var rise := wizard.global_position.y - brain.sight.seen_feet(brain.opponent).y
	if rise < WizardBrain.CHASE_ABOVE or absf(to_player.x) > 320.0:
		return false
	var dir := 1 if to_player.x >= 0.0 else -1
	var span := Rect2(brain.sight.seen_feet(brain.opponent).x - 24.0, brain.sight.seen_feet(brain.opponent).y - 6.0, 48.0, 12.0)
	for spell_name: String in WizardBrain.LIFTS:
		if not brain.ready_to_cast(spell_name) or (spell_name == "Great Oak" and rise > WizardBrain.OAK_CHASE_MAX):
			continue
		if WizardBrain.LIFT_CLOSE.has(spell_name) and absf(to_player.x) > WizardBrain.LIFT_CLOSE[spell_name] + 60.0:
			continue  # a vine, an oak or a column of air is raised only once it has walked up to the foot of the ledge
		brain.rest["chase"] = WizardBrain.CHASE_REST
		if brain.moves.begin_lift(spell_name, "chase", dir, span):
			return true
	return false


## Picks a key at random, weighted by its value. Returns "" when every weight is zero.
func pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return ""
	var roll := brain.rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0 and weights[key] > 0.0:
			return key
	return ""


## The first of the spells that raise it up that it is ready to cast, or "".
func ready_lift() -> String:
	for spell_name: String in WizardBrain.LIFTS:
		if brain.ready_to_cast(spell_name):
			return spell_name
	return ""


## How many of the wizard's own walkers stand within reach of the player: an earthquake would shake them too.
func own_walkers_near(reach: float) -> int:
	var count := 0
	var target: Wizard = brain.opponent
	for other in wizard.get_tree().get_nodes_in_group("mobs"):
		if other.is_dead():
			continue
		if other.center().distance_to(target.center()) < reach:
			count += 1
	return count



## A werewolf's turn: straight at the rival, and a swipe once they are in reach.
func wolf(to_player: Vector2, sees: bool) -> void:
	var near := absf(to_player.x) < WildShape.CLAW_REACH * 0.8
	wizard.walk(0.0 if near else signf(to_player.x) * Wizard.SPEED * WildShape.SPEED)
	wizard.facing = signf(to_player.x) if to_player.x != 0.0 else wizard.facing
	if sees and absf(to_player.x) < WildShape.CLAW_REACH and absf(to_player.y) < 60.0:
		wizard.wolf.claw()


## Whether there is a ceiling over a point that an icicle could hang from.
func ceiling_over(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0.0, -SpellSpawner.ICICLE_REACH))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["normal"].y > 0.3
