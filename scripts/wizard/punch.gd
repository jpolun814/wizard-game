class_name Punch
extends RefCounted

## A punch (the P key): a blow with whatever the wizard holds, for no stamina. It is weak on purpose: it does a little harm when nothing else can be done, and
## it is held back by a cooldown of its own. It is not a spell, so it does not use the safety that follows a hit (a punch starts none, and one is not stopped
## by it), which is how a punch and a spell can both land together. Reached as `wizard.punch`.

const DAMAGE := 1
const COOLDOWN := 0.25
const REACH := 46.0       # from the middle of the body, to the front
const HEIGHT := 50.0      # how far above or below the middle of the body it still reaches
const DELAY := 0.08       # the blow lands this long after the swing begins

var wizard: Wizard
var _cool := 0.0
var _land_in := -1.0   # time until a swing that has begun lands
var _was_down := false


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## What a person's frame does: a press of P swings, and a swing lands a moment after it begins.
func tick(delta: float) -> void:
	_cool -= delta
	if _land_in >= 0.0:
		_land_in -= delta
		if _land_in < 0.0:
			_land()
	var down := Input.is_physical_key_pressed(KEY_P) and wizard.is_person()
	if down and not _was_down:
		swing()
	_was_down = down


## A swing, which a person asks for with P and a brain asks for within reach of a rival.
func swing() -> bool:
	if wizard.dead or wizard.fainted or wizard.asleep or wizard.is_frozen() or wizard.wolf.on or wizard.golem.on or wizard.casting or _cool > 0.0:
		return false
	_cool = COOLDOWN
	_land_in = DELAY
	wizard.thrust(0.2)
	Sfx.cue("punch", "swing", wizard.global_position, -8.0)
	return true


## The blow reaches whoever is in front of the wizard, close enough, and in the open.
func _land() -> void:
	var tree := wizard.get_tree()
	for body in SpellTargets.all(tree):
		if body == wizard or not SpellTargets.affects(body):
			continue
		var at := SpellTargets.center_of(body)
		var to := at - wizard.center()
		if absf(to.x) > REACH + 14.0 or absf(to.y) > HEIGHT or to.x * wizard.facing < -6.0:
			continue
		if SpellTargets.sight_blocked(tree, wizard.center(), at):
			continue
		MatchStats.strike(wizard)
		if body.is_in_group("wizards"):
			body.take_damage(DAMAGE, false)  # (false: no safety follows it, and none stops it)
		else:
			body.take_damage(DAMAGE, "", false)
		MatchStats.strike(null)
		Sfx.cue("punch", "hit", at, -4.0)
		Fx.burst(wizard.get_parent(), at, Color(0.9, 0.85, 0.8), 4, 90.0, 0.2, true)
