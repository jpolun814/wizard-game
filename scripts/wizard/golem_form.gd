class_name GolemForm
extends RefCounted

## Golem: a wizard who has covered themselves in the stone of the world they stand in. The ground grows up around them (GolemRise) and falls away from a
## man of stone. For a while they are slow and heavy, cannot cast, take half of every blow, jump low and shake the ground where they land, and have two
## blows: a click slams a fist, a right click brings both down with their whole weight. When the time is up the stone falls away. Reached as `wizard.golem`.

const DURATION := 10.0   # seconds the stone stays on, after it has risen
const RISE_TIME := 0.55  # the ground grows up around the wizard this long before the golem shows
const STAND_TIME := 0.6  # and the golem gets to its feet this long
const SPEED := 0.5       # how much of a wizard's walking pace a golem has
const JUMP := 0.7        # how much of a wizard's jump a golem has
const TAKEN := 0.5       # the share of every blow that gets through the stone
const SLAM_DAMAGE := 40
const SLAM_COOLDOWN := 0.8
const SLAM_REACH := 90.0   # from the middle of the body, to the front
const SLAM_DELAY := 0.3    # the fist lands this long after the swing begins
const SLAM_PUSH := 520.0   # how hard whoever is hit is thrown back
const SMASH_DAMAGE := 80
const SMASH_COOLDOWN := 2.0
const SMASH_REACH := 130.0
const SMASH_DELAY := 0.65  # both fists come down this long after the swing begins: a long time to see it coming
const SMASH_TIME := 1.15   # the whole swing, from the raised fists to standing again
const SMASH_PUSH := 800.0
const LAND_TIME := 0.4
const QUAKE_REACH := 220.0  # how far from where it lands the ground is shaken
const QUAKE_DAMAGE := 12    # to whoever stands on the ground there
## The golem's picture (art/mobs/golem, drawn by tools/wizard_parts/golem.py) is cut to the names a wizard's animations have.
const ANIMATIONS := {
	"idle": {"fps": 6.0}, "run": {"from": "walk", "fps": 9.0},
	"jump": {"fps": 10.0, "loop": false}, "fall": {"fps": 6.0},
	"cast": {"from": "idle", "fps": 6.0, "first": 0, "last": 0},
	"land": {"fps": 11.0, "loop": false},
	"release": {"from": "attack", "fps": 10.0, "loop": false},
	"smash": {"fps": 8.0, "loop": false},
	"rise": {"fps": 10.0, "loop": false},
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
const FRAMES := "res://art/mobs/golem"

var on := false     # the wizard is a golem now (or is becoming one)
var shown := false  # the golem is drawn: the ground has grown up and fallen away
var wizard: Wizard
var _rise := 0.0
var _left := 0.0
var _slam_cool := 0.0
var _slam_in := -1.0  # time until a swing that has begun lands
var _smash_cool := 0.0
var _smash_in := -1.0
var _smash_left := 0.0
var _land_left := 0.0
var _stand_left := 0.0
var _fall_speed := 0.0
var _was_left := false   # the buttons were down the last frame (a blow is a click)
var _was_right := false


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## The ground grows up around the wizard, and a golem stands up out of it.
func begin() -> void:
	if on or wizard.dead or wizard.is_likeness():
		return
	wizard.wolf.end()
	on = true
	shown = false
	_rise = RISE_TIME
	_left = DURATION
	_slam_cool = 0.0
	_smash_cool = 0.0
	_slam_in = -1.0
	_smash_in = -1.0
	_smash_left = 0.0
	_land_left = 0.0
	_stand_left = 0.0
	wizard.pen.drop()
	wizard.root_time = maxf(wizard.root_time, RISE_TIME + STAND_TIME)  # held where they stand while the stone is made
	GolemRise.spawn(wizard.get_parent(), wizard.global_position, _earth(), RISE_TIME + STAND_TIME)
	Sfx.play("stones", wizard.center(), -2.0)
	GameCamera.shake_near(wizard.get_tree(), wizard.global_position, 0.25, 500.0)


## The stone falls away.
func end() -> void:
	if not on:
		return
	var was_shown := shown
	on = false
	shown = false
	_slam_in = -1.0
	_smash_in = -1.0
	_smash_left = 0.0
	_land_left = 0.0
	_stand_left = 0.0
	wizard.dress()
	if was_shown:
		Fx.debris(wizard.get_parent(), wizard.center(), _dust(), 14, 200.0)
		Fx.burst(wizard.get_parent(), wizard.global_position, _dust(), 18, 140.0, 0.6, false)
	Sfx.play("stones", wizard.center(), -4.0)


## The driving machine has changed shape: a likeness only dresses to match.
func follow(shown_now: bool) -> void:
	if on != shown_now:
		on = shown_now
		shown = shown_now
		wizard.dress()


## Off the bottom of the map: nothing turns back from this.
func lose() -> void:
	on = false
	shown = false


## The time left, for the AI and the tests.
func time_left() -> float:
	return _left if on else 0.0


## Which of the golem's own animations is playing now, if one is: standing up, a smash, a landing. Empty when it is left to the body.
func anim() -> String:
	if _stand_left > 0.0:
		return "rise"
	if _smash_left > 0.0:
		return "smash"
	if _land_left > 0.0:
		return "land"
	return ""


## What a golem's frame does: the clock runs, the buttons swing, a swing lands a moment after it begins, and a landing shakes the ground.
func tick(delta: float) -> void:
	if not shown:
		_rise -= delta
		if _rise <= 0.0:
			shown = true
			_stand_left = STAND_TIME
			wizard.dress()
			Fx.debris(wizard.get_parent(), wizard.center(), _dust(), 12, 180.0)
		return
	_left -= delta
	if _left <= 0.0:
		end()
		return
	_stand_left = maxf(_stand_left - delta, 0.0)
	_land_left = maxf(_land_left - delta, 0.0)
	_smash_left = maxf(_smash_left - delta, 0.0)
	_slam_cool -= delta
	_smash_cool -= delta
	if _slam_in >= 0.0:
		_slam_in -= delta
		if _slam_in < 0.0:
			_land_slam()
	if _smash_in >= 0.0:
		_smash_in -= delta
		if _smash_in < 0.0:
			_land_smash()
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and wizard.is_person()
	if left and not _was_left:
		slam()
	_was_left = left
	var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and wizard.is_person()
	if right and not _was_right:
		smash()
	_was_right = right
	if wizard.is_on_floor():
		if _fall_speed > 150.0:
			_land(clampf(_fall_speed / 420.0, 0.5, 1.3))
		_fall_speed = 0.0
	else:
		_fall_speed = maxf(_fall_speed, wizard.velocity.y)


## A swing of the fist, which a person asks for with a click and a brain asks for in reach of a rival.
func slam() -> void:
	if not _can_swing() or _slam_cool > 0.0:
		return
	_slam_cool = SLAM_COOLDOWN
	_smash_cool = maxf(_smash_cool, 0.5)
	_slam_in = SLAM_DELAY
	wizard.thrust(0.6)


## Both fists brought down together: slow, and it hits much harder, and the ground shakes where it lands.
func smash() -> void:
	if not _can_swing() or _smash_cool > 0.0:
		return
	_smash_cool = SMASH_COOLDOWN
	_slam_cool = maxf(_slam_cool, SMASH_TIME)
	_smash_in = SMASH_DELAY
	_smash_left = SMASH_TIME
	wizard.pen.drop()


func _can_swing() -> bool:
	return on and shown and _stand_left <= 0.0 and not wizard.dead and not wizard.fainted and _smash_left <= 0.0


## The fist reaches whoever is in front of the wizard, close enough, and in the open.
func _land_slam() -> void:
	_strike(SLAM_REACH, SLAM_DAMAGE, SLAM_PUSH, Vector2(wizard.facing * SLAM_PUSH, -160.0))
	Sfx.play("stones", wizard.center() + Vector2(wizard.facing * SLAM_REACH * 0.7, 0.0), 2.0)


func _land_smash() -> void:
	_strike(SMASH_REACH, SMASH_DAMAGE, SMASH_PUSH, Vector2(wizard.facing * SMASH_PUSH, -380.0))
	_quake(wizard.global_position + Vector2(wizard.facing * SMASH_REACH * 0.6, 0.0), 1.4)


func _strike(reach: float, damage: int, _push: float, throw: Vector2) -> void:
	var tree := wizard.get_tree()
	for body in SpellTargets.all(tree):
		if body == wizard:
			continue
		var at := SpellTargets.center_of(body)
		var to := at - wizard.center()
		if absf(to.x) > reach + 20.0 or absf(to.y) > 80.0 or to.x * wizard.facing < -10.0:
			continue
		if SpellTargets.sight_blocked(tree, wizard.center(), at):
			continue
		SpellTargets.hurt(body, damage, "Earth", false, false, wizard)
		if body.has_method("push"):
			body.push(throw)
		elif body.has_method("knock_back"):
			body.knock_back(throw)
		Fx.burst(wizard.get_parent(), at, SpellData.SCHOOL_COLORS["Earth"], 12, 170.0, 0.4, true)


## The golem comes down from a jump or a fall: the ground shakes.
func _land(strength: float) -> void:
	_land_left = LAND_TIME
	_quake(wizard.global_position, strength)


## The ground shaken where something heavy came down: the screens near it shake, dust and rock fly up, and whoever stands on the ground close by is thrown up
## and hurt a little, and a wall or a plug of ice there is knocked about. `strength` is 1 for an ordinary landing.
func _quake(at: Vector2, strength: float) -> void:
	var tree := wizard.get_tree()
	GameCamera.shake_near(tree, at, clampf(0.5 + 0.5 * strength, 0.0, 1.0), 900.0)  # the shake is squared on the way to the screen, so it has to start high to be seen
	Sfx.play("quake", at, -6.0 + 4.0 * strength)
	Fx.burst(wizard.get_parent(), at, _dust(), int(14 * strength), 190.0, 0.6, false)
	Fx.debris(wizard.get_parent(), at, _dust(), int(8 * strength), 240.0)
	var reach := QUAKE_REACH * strength
	for body in SpellTargets.all(tree):
		if body == wizard:
			continue
		var there := SpellTargets.center_of(body)
		if absf(there.x - at.x) > reach or absf(there.y - at.y) > 90.0:
			continue
		if body.has_method("is_on_floor") and not body.is_on_floor():
			continue  # nothing in the air feels the ground
		SpellTargets.hurt(body, roundi(QUAKE_DAMAGE * strength), "Earth", false, false, wizard)
		var side := signf(there.x - at.x) if there.x != at.x else 1.0
		var throw := Vector2(side * 220.0, -300.0 * strength)
		if body.has_method("push"):
			body.push(throw)
		elif body.has_method("knock_back"):
			body.knock_back(throw)
	for thing in tree.get_nodes_in_group("breakables"):
		if thing is IcePlug or thing is RockWall:
			thing.shake(at, reach * 1.2, 14.0 * strength)


func _earth() -> Texture2D:
	var arena := wizard.get_parent()
	var rock: Texture2D = arena.earth_texture() if arena != null and arena.has_method("earth_texture") else null
	return rock if rock != null else Wizard.GOLEM_EARTH


## The color of the ground's dust, from the ground itself.
func _dust() -> Color:
	var rock := _earth()
	var image := rock.get_image() if rock != null else null
	if image == null:
		return Color("#8a6a4a")
	image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return image.get_pixel(0, 0).lightened(0.2)
