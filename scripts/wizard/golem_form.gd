class_name GolemForm
extends RefCounted

## Golem: a wizard who has covered themselves in the stone of the world they stand in. For a while they are slow, cannot jump or cast, take half of every
## blow, and slam a fist that hits very hard. When the time is up the stone falls away. Reached as `wizard.golem`.

const DURATION := 10.0   # seconds the stone stays on
const SPEED := 0.5       # how much of a wizard's walking pace a golem has
const TAKEN := 0.5       # the share of every blow that gets through the stone
const SLAM_DAMAGE := 40
const SLAM_COOLDOWN := 1.3
const SLAM_REACH := 90.0   # from the middle of the body, to the front
const SLAM_DELAY := 0.4    # the fist lands this long after the swing begins
const SLAM_PUSH := 520.0   # how hard whoever is hit is thrown back
## The golem's picture (drawn for the game, art/mobs/golem) is cut to the names a wizard's animations have. It has no jump, fall or spell of its own: it stands still.
const ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"from": "walk", "fps": 8.0},
	"jump": {"from": "idle", "fps": 8.0, "first": 0, "last": 0}, "fall": {"from": "idle", "fps": 8.0, "first": 0, "last": 0},
	"cast": {"from": "idle", "fps": 8.0, "first": 0, "last": 0},
	"release": {"from": "attack", "fps": 12.0, "loop": false},
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
const FRAMES := "res://art/mobs/golem"

var on := false  # the wizard is a golem now
var wizard: Wizard
var _left := 0.0
var _slam_cool := 0.0
var _slam_in := -1.0  # time until a swing that has begun lands
var _was_left := false  # the left button was down the last frame (a swing is a click)


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## The wizard is covered in stone.
func begin() -> void:
	if on or wizard.dead or wizard.is_likeness():
		return
	wizard.wolf.end()
	on = true
	_left = DURATION
	wizard.pen.drop()
	_slam_cool = 0.0
	_slam_in = -1.0
	wizard.dress()
	Fx.burst(wizard.get_parent(), wizard.center(), SpellData.SCHOOL_COLORS["Earth"], 22, 150.0, 0.6, true)
	Sfx.play("stones", wizard.center(), -2.0)


## The stone falls away.
func end() -> void:
	if not on:
		return
	on = false
	_slam_in = -1.0
	wizard.dress()
	Fx.burst(wizard.get_parent(), wizard.center(), SpellData.SCHOOL_COLORS["Earth"], 22, 150.0, 0.6, true)
	Sfx.play("stones", wizard.center(), -4.0)


## The driving machine has changed shape: a likeness only dresses to match.
func follow(shown: bool) -> void:
	if on != shown:
		on = shown
		wizard.dress()


## Off the bottom of the map: nothing turns back from this.
func lose() -> void:
	on = false


## The time left, for the AI and the tests.
func time_left() -> float:
	return _left if on else 0.0


## What a golem's frame does: the clock runs, a click of the left button swings, and a swing lands a moment after it begins.
func tick(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		end()
		return
	_slam_cool -= delta
	if _slam_in >= 0.0:
		_slam_in -= delta
		if _slam_in < 0.0:
			_land()
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and wizard.is_person()
	if left and not _was_left:
		slam()
	_was_left = left


## A swing of the fist, which a person asks for with a click and a brain asks for in reach of a rival.
func slam() -> void:
	if not on or wizard.dead or wizard.fainted or _slam_cool > 0.0:
		return
	_slam_cool = SLAM_COOLDOWN
	_slam_in = SLAM_DELAY
	wizard.thrust(0.5)


## The fist reaches whoever is in front of the wizard, close enough, and in the open.
func _land() -> void:
	var tree := wizard.get_tree()
	for body in SpellTargets.all(tree):
		if body == wizard:
			continue
		var at := SpellTargets.center_of(body)
		var to := at - wizard.center()
		if absf(to.x) > SLAM_REACH + 20.0 or absf(to.y) > 70.0 or to.x * wizard.facing < -10.0:
			continue
		if SpellTargets.sight_blocked(tree, wizard.center(), at):
			continue
		SpellTargets.hurt(body, SLAM_DAMAGE, "Earth", false, false, wizard)
		var throw := Vector2(wizard.facing * SLAM_PUSH, -160.0)
		if body.has_method("push"):
			body.push(throw)
		elif body.has_method("knock_back"):
			body.knock_back(throw)
		Fx.burst(wizard.get_parent(), at, SpellData.SCHOOL_COLORS["Earth"], 10, 160.0, 0.4, true)
	Sfx.play("stones", wizard.center() + Vector2(wizard.facing * SLAM_REACH * 0.7, 0.0), 2.0)
