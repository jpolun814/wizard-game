class_name VineHold
extends RefCounted

## A wizard hanging on a vine (Liana): W takes hold when it is at one, W and S climb, and Space or a sideways key lets go. Reached as `wizard.vine`.

const CLIMB_SPEED := 170.0  # how fast the wizard climbs a vine
const RETRY := 0.3  # after letting go, a vine cannot be grabbed again for this long

var wizard: Wizard
var _vine: Node2D  # the vine the wizard is hanging on, if any
var _cooldown := 0.0
var _moved := 0.0  # above zero for a moment after the wizard last climbed up or down


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


func tick(delta: float) -> void:
	_cooldown -= delta
	_moved = maxf(_moved - delta, 0.0)


## True while the wizard hangs on a vine.
func hanging() -> bool:
	return _vine != null and is_instance_valid(_vine)


## True while the wizard goes up or down the vine they hang on (and not while they hang still).
func moving() -> bool:
	return _moved > 0.0


## Takes the whole frame's movement while the wizard is on a vine, and says so.
func climb() -> bool:
	var pad := wizard.pad
	var hands := wizard.global_position + Vector2(0, -20)
	var sideways := pad.sideways()
	if _vine != null and (not is_instance_valid(_vine) or not _vine.can_grab(hands)):
		_vine = null  # the top of the vine: the wizard steps off it, at a walking pace the way a key leans
		wizard.carry(sideways * Wizard.SPEED)
	var up := pad.wants_up()
	var down := pad.wants_down()
	var letting_go := pad.lets_go()
	if _vine == null:
		if _cooldown > 0.0 or not up:
			return false
		for vine in wizard.get_tree().get_nodes_in_group("climbables"):
			if vine.can_grab(hands):
				_vine = vine
				break
		if _vine == null:
			return false
	if letting_go or absf(sideways) > 0.5:
		# Let go: a hop off the vine in the way the wizard was leaning.
		wizard.velocity = Vector2(sideways * Wizard.SPEED, Wizard.JUMP_VELOCITY * 0.6 if letting_go else 0.0)
		wizard.carry(sideways * Wizard.SPEED)  # the push off the vine is the speed it goes on with through the air
		_vine = null
		_cooldown = RETRY
		return false
	if down and wizard.is_on_floor():
		_vine = null
		_cooldown = RETRY
		return false
	wizard.global_position.x = _vine.vine_x() if absf(wizard.global_position.x - _vine.vine_x()) < 8.0 else lerpf(wizard.global_position.x, _vine.vine_x(), 0.7)  # at once, not a slide onto the vine
	wizard.velocity = Vector2(0.0, (1.0 if down else 0.0) * CLIMB_SPEED - (1.0 if up else 0.0) * CLIMB_SPEED)
	if up != down:
		_moved = 0.15
	wizard.move_and_slide()
	return true
