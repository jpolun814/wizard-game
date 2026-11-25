class_name WizardPose
extends RefCounted

## Which animation a wizard made of parts plays: it has 46 (see PartFrames and res://art/parts/manifest.json), so this reads the state of the body and picks one.
## It is asked once a frame by Wizard._animate, and told what happens to the body that it could not see for itself (a pull, a shove, a spell going off).
## The first thing in `pick` that holds wins, so they are in order of what matters most to see. Reached as `wizard.pose`.

const KNOCK_TIME := 0.5     # a shove (Push, Gust, a quake) makes the wizard tumble for this long, if it takes them off the ground
const KNOCK_LAND := 0.3     # tumbling at least this long before they land, and they get up off the ground
const KNOCK_FROM := 200.0   # a shove at least this strong is a knock (a nudge is not)
const PULL_TIME := 0.15     # a pull is felt for this long after the last time it is applied (it is applied every frame it holds)
const LAND_SPEED := 420.0   # falling at least this fast, and landing makes the wizard bend their knees
const FIDGET_AFTER := Vector2(4.0, 9.0)  # standing still this long, and the wizard fidgets

var wizard: Wizard
var restart := false  # set when the same animation has to begin again (a second spell of the same style): Wizard._animate clears it
var _shot := ""         # an animation played once, in front of everything but a hit (a wake, a thaw, a spell going off, an arrival)
var _shot_left := 0.0
var _shot_cast := false  # the shot is a spell going off: drawing the next spell takes over from it
var _low := ""          # an animation played once only where nothing else is going on: a landing, standing up, a fidget, a turn
var _low_left := 0.0
var _held := ""         # an animation kept up while a spell lasts (a breath, a beam): drawing the next spell ends it
var _held_left := 0.0
var _pull_left := 0.0
var _knock_left := 0.0
var _knock_air := 0.0   # how long the wizard has been in the air from a shove
var _idle_for := 0.0
var _standing_for := 0.0  # how long the wizard has stood still on the ground
var _fidget_at := 5.0
var _was_fainted := false
var _was_frozen := false
var _cast_face := false  # the body is turned to where the last spell was drawn or went, and stays so until the wizard walks off
var _was_floor := true
var _fall_speed := 0.0
var _last_facing := 1.0


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard
	_fidget_at = Dice.looks.randf_range(FIDGET_AFTER.x, FIDGET_AFTER.y)


## The seconds an animation takes to play once.
static func length_of(anim: String) -> float:
	var spec: Dictionary = PartFrames.manifest()["animations"].get(anim, {})
	return float(spec["count"]) / float(spec["fps"]) if not spec.is_empty() else 0.3


## Plays an animation once, in front of the body's ordinary ones (all but a hit, and a fall into death or a block of ice).
func play_once(anim: String, seconds := 0.0, is_cast := false) -> void:
	_shot = anim
	_shot_cast = is_cast
	_shot_left = seconds if seconds > 0.0 else length_of(anim)
	_low_left = 0.0
	restart = true


## The wizard has just arrived out of the summoning circle (SPAWN_TIME).
func arrive() -> void:
	play_once("spawn", Wizard.SPAWN_TIME)


## A spell goes off: the wizard moves as the spell asks (see CastStyles). The ones that are held (a breath, a beam) are kept up for a while, and drawing the
## next spell ends them.
func cast(spell: String, toward := 0.0) -> void:
	var anim := CastStyles.anim_for(spell)
	if toward != 0.0:
		wizard.look_dir = signf(toward)  # the body turns to where the spell goes, and stays so until the wizard goes some way or is pulled
		_cast_face = true
	if anim == "rocket":
		return  # (the flame has a state of its own: see Wizard.rocket_time)
	if CastStyles.is_held(anim):
		_held = anim
		_held_left = float(CastStyles.HELD[anim])
		_shot_left = 0.0
		wizard._releasing = 0.0
		restart = true
		return
	play_once(anim, minf(length_of(anim), 0.5), true)


## A pull (Black Hole, Thorn Whip) drags the wizard toward `toward`: they face it, as the animation has the pull coming from the front.
func pulled(toward: Vector2) -> void:
	_pull_left = PULL_TIME
	if absf(toward.x) > 1.0:
		wizard.look_dir = signf(toward.x)


## The wizard is thrown by `impulse`. They tumble if it takes them off the ground, facing where it came from (the animation throws them backward).
func shoved(impulse: Vector2) -> void:
	if impulse.length() < KNOCK_FROM:
		return
	_knock_left = KNOCK_TIME
	_knock_air = 0.0
	if absf(impulse.x) > 1.0:
		wizard.look_dir = -signf(impulse.x)


## The state of the body this frame (call it once a frame before pick).
func tick(delta: float) -> void:
	var w := wizard
	_shot_left = maxf(_shot_left - delta, 0.0)
	_low_left = maxf(_low_left - delta, 0.0)
	_held_left = maxf(_held_left - delta, 0.0)
	_pull_left = maxf(_pull_left - delta, 0.0)
	_knock_left = maxf(_knock_left - delta, 0.0)
	if w.casting and w.is_person():  # drawing a spell: the body is turned toward the pen already
		var toward := w.get_global_mouse_position().x - w.global_position.x
		if absf(toward) > 6.0:
			w.look_dir = signf(toward)
			_cast_face = true
	if _pull_left <= 0.0 and _knock_left <= 0.0:
		if _cast_face and absf(w.velocity.x) > 10.0 and not w.casting:
			_cast_face = false  # it walks off: it faces the way it goes
		if not _cast_face:
			w.look_dir = 0.0  # faces the way it goes again
	var floor_now := w.stands()
	if not floor_now:
		_fall_speed = maxf(_fall_speed, w.velocity.y)
		if _knock_left > 0.0:
			_knock_air += delta
	elif not _was_floor:  # landed
		if _knock_air >= KNOCK_LAND:
			_low = "get_up"
			_low_left = length_of("get_up")
			restart = true
		elif _fall_speed >= LAND_SPEED and not w.flying:
			_low = "land"
			_low_left = length_of("land")
			restart = true
		_knock_air = 0.0
		_fall_speed = 0.0
		_knock_left = 0.0
	_was_floor = floor_now
	if _was_fainted and not w.fainted and not w.dead:
		play_once("wake")
	_was_fainted = w.fainted
	if _was_frozen and not w.is_frozen() and not w.dead:
		play_once("thaw")
	_was_frozen = w.is_frozen()


## The animation for what the wizard is doing.
func pick(delta: float) -> String:
	var w := wizard
	if w.dead or w.fainted:
		return "death"
	if w.is_frozen():
		return "frozen"
	if w._hurt_anim > 0.0:
		return "hit"
	var turned := not is_equal_approx(w.facing, _last_facing)
	_last_facing = w.facing
	if w.casting and _shot_cast:
		_shot_left = 0.0
	if _shot_left > 0.0:
		return _shot
	if w.casting:
		_held_left = 0.0
		return "cast"
	if w._releasing > 0.0:
		return "release"
	if _held_left > 0.0:
		return _held
	if w.lungs.smothered or (w.lungs.submerged() and w.lungs.air <= 0.0 and w.deep_breath_time <= 0.0):
		return "gasping"
	if w.daze_time > 0.0:
		return "dazed"
	var moving := absf(w.velocity.x - w.wind) > 10.0
	if w.fear_time > 0.0 and not moving:
		return "cower"
	if w.vine.hanging():
		return "climb" if w.vine.moving() else "climb_hang"
	if w.rocket_time > 0.0:
		return "rocket"
	if w.surf_time > 0.0:
		return "surf"
	if w.swim_time > 0.0:
		if w.pad.dives():
			return "swim_dive"
		if w.velocity.y < -40.0:
			return "swim_up"  # going up: a hard kick, arms overhead
		if absf(w.velocity.x) > 40.0:
			return "swim_side"  # going along: lying level, pulling through the water
		return "swim"
	if w.flying:
		return "fly" if moving or w.velocity.y < -40.0 else "float"
	if not w.stands():
		_standing_for = 0.0
		if _knock_left > 0.0:
			return "knockback"
		if w.feather_time > 0.0 and w.velocity.y > 0.0:
			return "float"
		return "jump" if w.velocity.y < 0.0 else "fall"
	# On the ground.
	if _low_left > 0.0 and (_low == "get_up" or _low == "land"):
		return _low
	if _pull_left > 0.0:
		return "pulled"
	var trying := absf(w.pad.sideways()) > 0.1
	if (w.root_time > 0.0 or w.tangle_time > 0.0 or w.sink_time > 0.0) and trying:
		return "stuck"
	if moving:
		_standing_for = 0.0
		_idle_for = 0.0
		_low_left = 0.0
		var slow := w.slow_time > 0.0 or w.sink_time > 0.0 or w.tangle_time > 0.0 or w.obsidian_time > 0.0 or w.stamina <= 0.0
		return "walk" if slow else "run"
	# Standing.
	_standing_for += delta
	if turned and _standing_for > 0.1:
		_low = "turn"
		_low_left = length_of("turn")
		_idle_for = 0.0
		restart = true
	if _low_left > 0.0:
		return _low
	_idle_for += delta
	if _idle_for >= _fidget_at:
		_idle_for = 0.0
		_fidget_at = Dice.looks.randf_range(FIDGET_AFTER.x, FIDGET_AFTER.y)
		_low = "idle_fidget"
		_low_left = length_of("idle_fidget")
		restart = true
		return _low
	return "idle"
