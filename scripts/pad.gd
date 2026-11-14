class_name Pad
extends RefCounted

## What is asked of a wizard's body: by a person's keys, or by the brain that plays it. Both are said the same way here, so that the body (walking, climbing,
## swimming, flying) does not have to know which it is. A brain sets what it asks; a person's keys are read as they are asked for. Reached as `wizard.pad`.

var wizard: Wizard
var walk := 0.0  # the speed a brain asks to walk at, left or right, in pixels a second
var climb := false  # a brain asks to take hold of a vine and go up it
var let_go := false  # a brain asks to hop off the vine
var fly := 0.0  # a brain asks of the air, up and down: -1 is up, 1 is down
var dive := false  # a brain asks to dive


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


func _by_brain() -> bool:
	return wizard.brain != null


## The speed along the ground the body is asked for, held to what it can do.
func walking(limit: float) -> float:
	return Input.get_axis("move_left", "move_right") * limit if not _by_brain() else clampf(walk, -limit, limit)


## Which way the body is leaned, -1 to 1.
func sideways() -> float:
	return Input.get_axis("move_left", "move_right") if not _by_brain() else clampf(walk / Wizard.SPEED, -1.0, 1.0)


func wants_up() -> bool:
	return Input.is_action_pressed("move_up") if not _by_brain() else climb


func wants_down() -> bool:
	return Input.is_action_pressed("move_down") if not _by_brain() else false


func lets_go() -> bool:
	return Input.is_action_pressed("let_go") if not _by_brain() else let_go


func dives() -> bool:
	return Input.is_action_pressed("move_down") if not _by_brain() else dive


## Up and down through the air: -1 up, 1 down.
func flying_ask() -> float:
	return Input.get_axis("move_up", "move_down") if not _by_brain() else clampf(fly, -1.0, 1.0)


## A person's jump key (a brain's jump is asked for with Wizard.request_jump).
func jump_pressed() -> bool:
	return not _by_brain() and Input.is_action_just_pressed("jump")


func jump_released() -> bool:
	return not _by_brain() and Input.is_action_just_released("jump")


## A person holding S on the ground stands down through a wooden platform.
func drops() -> bool:
	return not _by_brain() and Input.is_action_pressed("move_down")
