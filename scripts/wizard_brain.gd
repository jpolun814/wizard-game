class_name WizardBrain
extends RefCounted

## The dark wizard's mind. It duels the way a player would: it keeps its distance, reacts to what you throw at it,
## and picks spells that suit the moment. Every spell it casts is drawn in front of it as a real gesture and read
## by the same recognizer as yours, so you can watch it form, learn the shapes from it, and break the spell by
## hitting the wizard before it finishes.
##
## Three layers, checked in order each frame:
##   Reactions: a shot coming at it, standing in something dangerous, or you right on top of it. After a short
##     reaction time (shorter the more skilled it is) it jumps, reflects the shot with a Gust, raises a
##     Barrier, steps away, or pushes you off.
##   Footwork: it holds a dueling range, strafes, jumps to get a clear line at you, and won't walk into fire.
##   Attacks: each spell is scored for the situation (are you moving, behind cover, rooted, close, far?) and one is
##     picked by weight. Projectiles are aimed where you are going, not where you are.

## Every spell a wizard casts, for Insight to list.
const KNOWN := ["Ignite", "Fire Breath", "Firewall", "Spark", "Frostbolt", "Ice Prison", "Blizzard", "Gust", "Push", "Barrier", "Tornado",
		"Stonefall", "Mudslide", "Earthquake", "Volcano", "Abyss", "Shadow Step"]
const STAMINA_REGEN := 16.0
const WALK_SPEED := 170.0
const JUMP := -560.0
const NEAR := 190.0           # closer than this it backs away
const FAR := 330.0            # farther than this it closes in
const TOO_CLOSE := 95.0       # this close it acts to get you off it
const INTERRUPT_DAMAGE := 6   # a hit this big while it draws breaks the spell
const QUICK_DRAW := 0.35      # defensive signs are drawn quickly
const ATTACK_DRAW := 0.8      # attacks take longer, which is your chance to interrupt them
const ATTACK_RANGE := 460.0   # it only casts at you from about a screen away, never across the map
const SHOT_SPEED := 650.0     # roughly how fast its bolts fly, for leading a moving target

var mob: Node2D               # the dark wizard
var skill := 0.6              # 0 to 1: how quick its reactions are and how true its aim is
var _cast_cooldown := 1.8
var _react := 0.0             # counting down to a planned reaction
var _reaction := ""
var _threat_dir := Vector2.ZERO
var _defend_cooldown := 0.0
var _strafe := 0.0
var _strafe_timer := 0.0
var _escape_time := 0.0
var _escape_dir := 0.0
var _jump_cooldown := 0.0
var _hop_timer := 1.5  # counting down to its next hop while it walks
var _pressure := 0.0          # how many shots you have thrown at it lately
var _seen_shots := {}
var _recent: Array[String] = []  # its last two attacks, which it avoids repeating
var _rng := RandomNumberGenerator.new()


func _init(wizard: Node2D) -> void:
	mob = wizard
	_rng.randomize()
	skill = 0.65


## Called when the wizard takes damage. A real hit while it draws breaks its spell, and being badly hurt makes it
## want to get away.
func on_hurt(amount: int) -> void:
	if mob.is_drawing() and amount >= INTERRUPT_DAMAGE:
		mob.interrupt_cast()
		_cast_cooldown = maxf(_cast_cooldown, 0.9)
	if mob.hp < mob.max_hp * 0.4 and _defend_cooldown <= 0.0 and _react <= 0.0 and _rng.randf() < 0.5:
		_plan("blink_away", 0.25)


func think(delta: float) -> void:
	var player: Node2D = mob.player
	_cast_cooldown -= delta
	_defend_cooldown -= delta
	_jump_cooldown -= delta
	_escape_time -= delta
	_pressure *= exp(-delta / 3.0)
	_track_shots()
	if player.dead:
		mob.velocity.x = 0.0
		return
	var to_player: Vector2 = player.center() - mob.center()
	var sees := _clear_line(mob.center(), player.center()) and not SpellTargets.sight_blocked(mob.get_tree(), mob.center(), player.center())

	# Reactions.
	if _react > 0.0:
		_react -= delta
		if _react <= 0.0:
			_act(_reaction)
	elif not mob.is_drawing():
		var shot := _incoming_shot()
		if not shot.is_empty() and _defend_cooldown <= 0.0:
			_threat_dir = shot["dir"]
			_plan(_choose_defence(shot["eta"]), _reaction_time())
		elif _in_danger(mob.global_position + Vector2(0, -6)) or _in_danger(mob.center()):
			_plan("escape", _reaction_time() * 0.6)
		elif to_player.length() < TOO_CLOSE and _defend_cooldown <= 0.0:
			_plan(_choose_repel(), _reaction_time())

	# Footwork.
	mob.velocity.x = _footwork(delta, to_player, sees)

	# Attacks.
	if _cast_cooldown <= 0.0 and not mob.is_drawing() and _react <= 0.0:
		if player.has_shield():
			_cast_cooldown = 0.3  # nothing gets through a Barrier; wait it out
		elif _attack(to_player, sees):
			_cast_cooldown = lerpf(2.8, 1.5, skill) + _rng.randf() * 0.8
		else:
			_cast_cooldown = 0.4


func _reaction_time() -> float:
	return lerpf(0.4, 0.15, skill) + _rng.randf() * 0.12


func _plan(reaction: String, delay: float) -> void:
	_reaction = reaction
	_react = delay


# --- Reactions --------------------------------------------------------------------------------------------------


## The nearest of your shots that will hit it soon: {"eta": seconds, "dir": its direction}, or nothing.
func _incoming_shot() -> Dictionary:
	var best := {}
	for node in mob.get_tree().get_nodes_in_group("projectiles"):
		if node.caster != mob.player:
			continue
		var velocity: Vector2 = node.velocity()
		var rel: Vector2 = mob.center() - node.global_position
		var closing := rel.dot(velocity.normalized())
		if closing <= 0.0:
			continue
		var eta := closing / velocity.length()
		var miss := (rel - velocity.normalized() * closing).length()
		if eta < 0.9 and miss < 28.0 and (best.is_empty() or eta < best["eta"]):
			best = {"eta": eta, "dir": velocity.normalized()}
	return best


## Counts how many shots you have thrown lately, so it knows when to put up walls.
func _track_shots() -> void:
	for node in mob.get_tree().get_nodes_in_group("projectiles"):
		if node.caster == mob.player and not _seen_shots.has(node.get_instance_id()):
			_seen_shots[node.get_instance_id()] = true
			_pressure += 1.0
	if _seen_shots.size() > 64:
		_seen_shots.clear()


func _choose_defence(eta: float) -> String:
	var options := {"jump": 1.0}
	if mob.stamina >= 15.0 and eta > QUICK_DRAW + 0.05:
		options["reflect"] = 0.6 + 1.6 * skill  # a skilled wizard sends your spells back at you
	if mob.stamina >= 35.0 and eta > QUICK_DRAW + 0.05:
		options["shield"] = 0.5
	if mob.stamina >= 10.0:
		options["blink_side"] = 0.7
	if not mob.is_on_floor():
		options.erase("jump")
	return _pick(options) if not options.is_empty() else ""


func _choose_repel() -> String:
	var options := {}
	if mob.stamina >= 10.0:
		options["push"] = 1.5
		options["blink_away"] = 1.0
	if mob.stamina >= 16.0 and _clear_line(mob.center(), mob.player.center()):
		options["breath"] = 1.3
	return _pick(options) if not options.is_empty() else "escape"


func _act(reaction: String) -> void:
	var player: Node2D = mob.player
	match reaction:
		"jump":
			if mob.is_on_floor():
				mob.velocity.y = JUMP * 0.8
			_defend_cooldown = 0.6
		"reflect":
			# A Gust blown toward where the shot came from: it turns the shot round and sends it back.
			var start: Vector2 = mob.center() - _threat_dir * 20.0
			_begin_cast("Gust", _line(start, start - _threat_dir * 90.0), QUICK_DRAW)
			_defend_cooldown = 1.4
		"shield":
			_begin_cast("Barrier", _offset(GestureTemplates.preview_points("circle"), mob.center(), 0.8), QUICK_DRAW)
			_defend_cooldown = 2.5
		"blink_side", "blink_away":
			_blink_away(player)
			_defend_cooldown = 1.6
		"escape":
			_escape_dir = _safe_side()
			_escape_time = 0.6
			if mob.stamina >= 12.0 and _rng.randf() < skill * 0.6:
				_blink_away(player)
			_defend_cooldown = 0.6
		"push":
			var away: Vector2 = (player.center() - mob.center()).normalized()
			_begin_cast("Push", _push_stroke(player.center(), away), QUICK_DRAW)
			_defend_cooldown = 1.5
		"breath":
			_begin_cast("Fire Breath", _breath_stroke(), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8


## Steps away from the player along the ground, or past them if its back is to a wall.
func _blink_away(player: Node2D) -> void:
	var away := -signf(player.global_position.x - mob.global_position.x)
	if away == 0.0:
		away = 1.0
	var room := (ArenaGen.right_edge() - mob.global_position.x) if away > 0.0 else (mob.global_position.x - ArenaGen.left_edge())
	if room < 120.0:
		away = -away  # cornered: go past the player instead
	var start: Vector2 = mob.center()
	_begin_cast("Shadow Step", _line(start, start + Vector2(away * 240.0, -12.0)), QUICK_DRAW)


# --- Footwork ---------------------------------------------------------------------------------------------------


func _footwork(delta: float, to_player: Vector2, sees: bool) -> float:
	if mob.is_drawing():
		return 0.0
	var speed := WALK_SPEED * (0.5 if mob.is_slowed() else 1.0)
	if _escape_time > 0.0:
		return _escape_dir * speed * 1.3
	var gap := absf(to_player.x)
	var toward := signf(to_player.x)
	var dir := 0.0
	if not sees:
		dir = toward  # get a clear line
	elif gap < NEAR:
		dir = -toward
	elif gap > FAR:
		dir = toward
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(0.6, 1.4)
			_strafe = [-1.0, 0.0, 0.0, 1.0][_rng.randi() % 4]
		dir = _strafe
	# Never back into the edge of the map; it would rather stand its ground there.
	var x: float = mob.global_position.x
	if (dir < 0.0 and x < ArenaGen.left_edge() + 60.0) or (dir > 0.0 and x > ArenaGen.right_edge() - 60.0):
		dir = 0.0
	# Never walk into something burning.
	if dir != 0.0 and _in_danger(mob.global_position + Vector2(dir * 34.0, -10.0)):
		dir = 0.0
	if mob.is_on_floor() and _jump_cooldown <= 0.0:
		var blocked: bool = dir != 0.0 and mob.is_on_wall()
		# Up onto a ledge you are standing on, whether or not it can see you, or when it is blocked.
		var above: bool = to_player.y < -50.0 and absf(to_player.x) < 260.0
		# While it moves it hops every second or two, so it is never a statue on the ground.
		_hop_timer -= delta
		var hop: bool = dir != 0.0 and _hop_timer <= 0.0
		if hop:
			_hop_timer = _rng.randf_range(1.0, 2.2) - 0.3 * skill
		if blocked or above or hop:
			mob.velocity.y = JUMP
			_jump_cooldown = 0.9
	return dir * speed


## Which way is away from danger: the side with fewer dangerous spots near it.
func _safe_side() -> float:
	var left := 0
	var right := 0
	for step in [30.0, 60.0, 90.0]:
		if _in_danger(mob.global_position + Vector2(-step, -10.0)):
			left += 1
		if _in_danger(mob.global_position + Vector2(step, -10.0)):
			right += 1
	if left == right:
		return -signf(mob.player.global_position.x - mob.global_position.x)
	return -1.0 if left < right else 1.0


## True when anything that hurts (any spell, its own included) would reach it at this point.
func _in_danger(point: Vector2) -> bool:
	for node in mob.get_tree().get_nodes_in_group("danger"):
		if node.danger_at(point):
			return true
	return false


func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return mob.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- Attacks ----------------------------------------------------------------------------------------------------


## Picks an attack for the situation and starts drawing it. Returns false if nothing is worth casting now.
func _attack(to_player: Vector2, sees: bool) -> bool:
	var player: Node2D = mob.player
	if absf(to_player.x) > ATTACK_RANGE:
		return false  # too far off to aim at you: it waits for you to come within reach
	var gap := absf(to_player.x)
	var still: bool = player.velocity.length() < 30.0
	var stuck: bool = player.root_time > 0.0 or player.slow_time > 0.0
	var grounded: bool = player.is_on_floor()
	var same_ground: bool = grounded and mob.is_on_floor() and absf(player.global_position.y - mob.global_position.y) < 8.0
	var closing: bool = signf(player.velocity.x) == signf(-to_player.x) and absf(player.velocity.x) > 60.0
	var aim_ok := absf(to_player.normalized().x) > 0.4  # a near-vertical stroke would draw a Firewall instead
	var scores := {
		"Ignite": (2.0 if gap > 140.0 else 0.8) if sees and aim_ok else 0.0,
		"Frostbolt": (0.4 if player.slow_time > 0.0 else 1.6) if sees else 0.0,
		"Spark": 2.2 if still or stuck else 1.0,
		"Stonefall": 3.0 if stuck else (1.8 if still else 0.5),
		"Icicles": 0.0,  # they need a ceiling, and the arenas have none yet
		"Volcano": 1.2 if gap > 160.0 and grounded else 0.2,
		"Tornado": (0.6 + _pressure * 0.5) if gap < 260.0 else 0.2,
		"Ice Prison": 1.3 if gap < 360.0 and not stuck else 0.0,
		"Mudslide": 1.1 if grounded and not stuck else 0.0,
		"Abyss": (0.4 + _pressure * 0.4) if gap < 300.0 else 0.0,
		"Firewall": 1.6 if closing and gap < 280.0 and gap > 90.0 else 0.0,
		"Blizzard": 0.4 if grounded else 0.0,
		"Fire Breath": 1.8 if gap < 240.0 else 0.0,
		"Earthquake": 1.5 if grounded and gap < 300.0 and _own_walkers_near(300.0) < 2 else 0.0,
	}
	if _sheltered():
		# Under a platform: lightning from above cannot reach you.
		scores["Spark"] = 0.0
	if not sees:
		# Behind cover: only spells that come from above or along the ground reach you.
		for spell_name in ["Ignite", "Frostbolt", "Ice Prison", "Abyss", "Firewall", "Fire Breath"]:
			scores[spell_name] = 0.0
	for spell_name in scores.keys():
		if mob.stamina < SpellData.SPELLS[spell_name].cost:
			scores[spell_name] = 0.0
		elif spell_name in _recent:
			scores[spell_name] *= 0.25  # it does not keep repeating itself
	var choice := _pick(scores)
	if choice == "":
		return false
	_recent.push_front(choice)
	if _recent.size() > 2:
		_recent.pop_back()
	_begin_cast(choice, _attack_stroke(choice), ATTACK_DRAW)
	return true


## True when something solid (a platform or the ground) is above you, so nothing from the sky can reach you.
func _sheltered() -> bool:
	var top: Vector2 = mob.player.center() + Vector2(0, -50)
	# Cast from the sky down, the way lightning comes: a one-way platform only stops things from above.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -600), top)
	query.collision_mask = 1 | 16
	return not mob.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Where you will be by the time a spell lands, judged with the wizard's skill: a skilled wizard leads you well.
func _predict(seconds: float) -> Vector2:
	var player: Node2D = mob.player
	var lead: Vector2 = player.velocity * seconds * skill
	lead.y = 0.0 if player.is_on_floor() else lead.y * 0.5
	return player.center() + lead


## The gesture for an attack, drawn where the spell should land.
func _attack_stroke(spell_name: String) -> PackedVector2Array:
	var player: Node2D = mob.player
	var feet: Vector2 = player.global_position
	var facing := signf(player.global_position.x - mob.global_position.x)
	if facing == 0.0:
		facing = 1.0
	match spell_name:
		"Ignite", "Frostbolt":
			var start: Vector2 = mob.center() + Vector2(facing * 12.0, -6.0)
			var target := _predict(start.distance_to(player.center()) / SHOT_SPEED)
			var aim := (target - start).angle() + _rng.randfn(0.0, 0.16 * (1.0 - skill))
			return _line(start, start + Vector2.from_angle(aim) * 90.0)
		"Spark":
			var x := _predict(ATTACK_DRAW * 0.8).x
			return _offset(GestureTemplates.preview_points("zigzag"), Vector2(x, player.center().y - 90.0), 1.0)
		"Stonefall":
			var x := _predict(ATTACK_DRAW + 0.6).x
			return _offset(GestureTemplates.preview_points("stonefall"), Vector2(x, player.center().y - 130.0), 0.8)
		"Volcano":
			var x := _predict(ATTACK_DRAW).x
			return _offset(GestureTemplates.preview_points("volcano"), Vector2(x, feet.y - 60.0), 0.8)
		"Tornado":
			var x: float = lerpf(mob.global_position.x, player.global_position.x, 0.45)
			return _offset(GestureTemplates.preview_points("tornado"), Vector2(x, feet.y - 90.0), 0.9)
		"Ice Prison":
			return _offset(GestureTemplates.preview_points("circle"), _predict(ATTACK_DRAW * 0.6), 0.8)
		"Earthquake":
			# Drawn in the air above the middle of the fight, where the peaks read clearly.
			return _offset(GestureTemplates.preview_points("earthquake"), Vector2(_predict(ATTACK_DRAW * 0.6).x, player.center().y - 120.0), 1.0)
		"Mudslide":
			var x := _predict(ATTACK_DRAW * 0.6).x
			return _offset(GestureTemplates.preview_points("pit"), Vector2(x, feet.y - 60.0), 1.0)
		"Abyss":
			# Beyond you if you are close (it drags you away from it), between you if you keep shooting at it.
			var spot: Vector2 = player.center() + Vector2(facing * 80.0, 0.0)
			if _pressure > 1.5:
				spot = mob.center().lerp(player.center(), 0.4)
			var spiral := GestureTemplates.preview_points("spiral")
			# The abyss forms where the spiral ends, so place the spiral's end on the spot.
			return _offset(spiral, spot - (spiral[spiral.size() - 1] - _centre_of(spiral)), 1.0)
		"Firewall":
			var x: float = lerpf(mob.global_position.x, player.global_position.x, 0.5)
			return _line(Vector2(x, feet.y - 110.0), Vector2(x, feet.y - 20.0))
		"Blizzard":
			return _offset(GestureTemplates.preview_points("snowfall"), Vector2(feet.x - 30.0, player.center().y - 70.0), 0.8)
		"Fire Breath":
			return _breath_stroke()
	return PackedVector2Array()


## A Fire Breath cone with its point at the wizard and its mouth toward you, a little off when it is unskilled.
## It draws the cone longer when you are farther off, so the fire reaches you.
func _breath_stroke() -> PackedVector2Array:
	var gap: float = mob.center().distance_to(mob.player.center())
	var size := clampf(gap / 150.0, 1.0, 1.4)
	var aim: float = (mob.player.center() - mob.center()).angle() + _rng.randfn(0.0, 0.2 * (1.0 - skill))
	var tip: Vector2 = mob.center() + Vector2.from_angle(aim) * 20.0
	var out := PackedVector2Array()
	for p in GestureTemplates.preview_points("cone"):
		out.append(tip + p.rotated(aim) * size)
	return _densify(out)


## A Push: a circle round you, starting on its far side, then a line out of it pointing away from the wizard.
func _push_stroke(around: Vector2, away: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start_angle := away.angle()
	for i in 33:
		pts.append(around + Vector2.from_angle(start_angle + TAU * i / 32.0) * 30.0)
	var exit := pts[pts.size() - 1]
	pts.append(exit + away * 90.0)
	return _densify(pts)


## Starts the wizard drawing a spell's gesture. The spell happens when the drawing is done, if nothing breaks it.
func _begin_cast(spell_name: String, stroke: PackedVector2Array, draw_time: float) -> void:
	if stroke.size() < 2:
		return
	var data: Spell = SpellData.SPELLS[spell_name]
	var mask: int = data.buttons
	var caster: Caster = mob.caster
	mob.start_drawing(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void:
		caster.cast_stroke(mask, _shaken(points)), draw_time)


## While the ground shakes, each point of the wizard's stroke is nudged by the screen's shake, the same amount the
## player's stroke is nudged by the shaking view.
func _shaken(points: PackedVector2Array) -> PackedVector2Array:
	var tree := mob.get_tree()
	if not Earthquake.is_shaking(tree):
		return points
	var px := GameCamera.shake_px(tree)
	var shaken := PackedVector2Array()
	for p in points:
		shaken.append(p + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px)
	return shaken


# --- Shapes -----------------------------------------------------------------------------------------------------


func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return _densify(PackedVector2Array([a, b]))


## A preview shape, scaled, with the middle of its bounding box moved to a point.
func _offset(shape: PackedVector2Array, middle: Vector2, scale: float) -> PackedVector2Array:
	var centre := _box_centre(shape)
	var out := PackedVector2Array()
	for p in shape:
		out.append(middle + (p - centre) * scale)
	return _densify(out)


func _box_centre(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).get_center()


func _centre_of(points: PackedVector2Array) -> Vector2:
	return _box_centre(points)


## The stroke with points every two pixels, as dense as one drawn with the mouse.
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out


## Picks a key at random, weighted by its value. Returns "" when every weight is zero.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return ""
	var roll := _rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0 and weights[key] > 0.0:
			return key
	return ""


## How many of the wizard's own walkers stand within reach of the player: an earthquake would shake them too.
func _own_walkers_near(reach: float) -> int:
	var count := 0
	var target: Node2D = mob.player
	for other in mob.get_tree().get_nodes_in_group("mobs"):
		if other == mob or other.is_dead() or other.KINDS[other.kind]["role"] == "wizard" or other.KINDS[other.kind]["role"] == "flyer":
			continue
		if other.center().distance_to(target.center()) < reach:
			count += 1
	return count
