class_name WildShape
extends RefCounted

## Wild Shape: a wizard who has become a werewolf. Their own stamina is put aside, the wolf has a pool of its own, and it can only run, jump and claw. When
## the pool is gone, from time, swipes or blows, the wizard is back with what they had. Reached as `wizard.wolf`.

const STAMINA := 1.0   # the wolf has a pool of strength of its own, and the wizard keeps theirs aside: a single blow ends the shape, and nothing else does
const SPEED := 1.25    # how much faster a werewolf runs
const SCALE := 1.4     # the werewolf is drawn this large
const CLAW_DAMAGE := 12
const CLAW_COOLDOWN := 0.55
const CLAW_REACH := 80.0   # from the middle of the body, to the front
const CLAW_DELAY := 0.15   # the swipe lands this long after it begins

var on := false  # the wizard has taken the shape of a werewolf
var wizard: Wizard
var _kept_stamina := 0.0  # what stamina and most stamina the wizard had before, which they have again when the shape is gone
var _kept_max := 0.0
var _claw_cool := 0.0
var _claw_in := -1.0  # time until a swipe that has begun lands
var _was_left := false  # the left button was down the last frame (a swipe is a click)


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## The wizard becomes a wolf.
func begin() -> void:
	if on or wizard.dead or wizard.is_likeness():
		return
	on = true
	_kept_stamina = wizard.stamina
	_kept_max = wizard.max_stamina
	wizard.max_stamina = STAMINA
	wizard.stamina = STAMINA
	wizard.pen.drop()
	_claw_cool = 0.0
	_claw_in = -1.0
	wizard.dress()
	Fx.burst(wizard.get_parent(), wizard.center(), Color(0.55, 0.5, 0.7), 18, 160.0, 0.5, true)
	Sfx.play("summon", wizard.center())


## The wolf is gone: the wizard stands as they were, with the stamina they had.
func end() -> void:
	if not on:
		return
	on = false
	wizard.max_stamina = _kept_max
	wizard.stamina = minf(_kept_stamina, wizard.max_stamina)
	_claw_in = -1.0
	wizard.dress()
	Fx.burst(wizard.get_parent(), wizard.center(), Color(0.55, 0.5, 0.7), 18, 160.0, 0.5, true)


## The driving machine has changed shape: a likeness only dresses to match.
func follow(shown: bool) -> void:
	if on != shown:
		on = shown
		wizard.dress()


## Off the bottom of the map: nothing turns back from this.
func lose() -> void:
	on = false


## A heal while a wolf: the wizard under it is mended, and has it when the shape ends.
func mend(amount: int) -> void:
	_kept_max = minf(_kept_max + amount, Wizard.MAX_STAMINA)
	_kept_stamina = minf(_kept_stamina + amount, _kept_max)


## What a werewolf's frame does: a click of the left button swipes, a swipe lands a moment after it begins.
func tick(delta: float) -> void:
	_claw_cool -= delta
	if _claw_in >= 0.0:
		_claw_in -= delta
		if _claw_in < 0.0:
			_land()
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and wizard.is_person()
	if left and not _was_left:
		claw()
	_was_left = left


## A swipe of the claws, which a person asks for with a click and a brain asks for in reach of a rival.
func claw() -> void:
	if not on or wizard.dead or wizard.fainted or _claw_cool > 0.0:
		return
	_claw_cool = CLAW_COOLDOWN
	_claw_in = CLAW_DELAY
	wizard.thrust(0.4)


## The claws reach whoever is in front of the wizard, close enough, and in the open.
func _land() -> void:
	var tree := wizard.get_tree()
	for body in SpellTargets.all(tree):
		if body == wizard:
			continue
		var at := SpellTargets.center_of(body)
		var to := at - wizard.center()
		if absf(to.x) > CLAW_REACH + 20.0 or absf(to.y) > 60.0 or to.x * wizard.facing < -10.0:
			continue
		if SpellTargets.sight_blocked(tree, wizard.center(), at):
			continue
		SpellTargets.hurt(body, CLAW_DAMAGE, "", false, false, wizard)
		Sfx.play("mob_hurt", at, 3.0)  # only a swipe that lands is heard
		Fx.burst(wizard.get_parent(), at, Color(0.9, 0.25, 0.3), 6, 120.0, 0.3, true)
