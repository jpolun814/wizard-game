class_name FallingPage
extends PagePickup

## A page of the sky world (chapter 19), which has no ground to lie on: it drifts. Where it is at a world age is worked out from its home, its rate (up or down, a
## little each second) and that age alone (`seconds`, told every frame by the world), so every machine of a match sees it in the same place, and a page that has
## drifted out of the box the world is made of is lost to everyone at once (it fades, and is gone). A wizard reads it by flying up to it and pressing Tab.
## Its origin is, as for any page, the point FLOAT under where it hangs.

const RATE_LEAST := -8.0   # pixels a second: negative rises
const RATE_MOST := 22.0
const TOUCH := 80.0        # how near a wizard must be to read it

var home := Vector2.ZERO   # where it is at world age zero
var rate := 10.0
var seconds := 0.0         # told every frame by the world
var box := Rect2()         # the room it may drift in; out of it, it is lost
var _fading := -1.0


func _enter_tree() -> void:
	position = _at()


func _at() -> Vector2:
	return home + Vector2(0.0, rate * seconds)


## Where the page hangs.
func shown() -> Vector2:
	return global_position + Vector2(0.0, -FLOAT)


func _physics_process(delta: float) -> void:
	position = _at()
	super._physics_process(delta)
	if _fading >= 0.0:
		_fading -= delta
		modulate.a = clampf(_fading / 1.2, 0.0, 1.0)
		if _fading <= 0.0:
			queue_free()
	elif box.size != Vector2.ZERO and not box.has_point(shown()):
		_fading = 1.2


func is_under(wizard: Node2D) -> bool:
	return _fading < 0.0 and SpellTargets.center_of(wizard).distance_to(shown()) < TOUCH
