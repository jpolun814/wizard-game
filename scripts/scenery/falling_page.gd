class_name FallingPage
extends PagePickup

## A page of the sky world (chapter 19), which has no ground to lie on: it falls, slower than the wizards, so among them it rises. Where it is at a world age is
## worked out from its home, its rate and that age alone (`seconds`, told every frame by the world), so every machine of a match sees it in the same place. One
## that rises out of the top of the sky comes back in at the bottom (owner, 2026-11-12), as the clouds do. A wizard reads it by flying up to it and pressing Tab.
## Its origin is, as for any page, the point FLOAT under where it hangs.

const RATE_LEAST := -140.0 # pixels a second: negative rises. Every page rises, quickly: a sheet of paper falls slower than a person, so among wizards who are
const RATE_MOST := -70.0   # falling it is left behind above them (owner, 2026-11-12: the pages seemed to fall with the wizards, and then rose too slowly)
const ROOM := 400.0        # how far past the top and the bottom of the sky it goes before it comes round again, out of sight
const SWAY := 46.0         # how far it swings to each side as it falls, as a sheet of paper does, rocking at the ends of each swing
const SWAY_PERIOD := 3.2   # seconds for a swing there and back
const ROCK := 0.4          # how far it tips, in radians
const TOUCH := 80.0        # how near a wizard must be to read it

var home := Vector2.ZERO   # where it is at world age zero
var rate := 10.0
var seconds := 0.0         # told every frame by the world
var box := Rect2()         # the room the wizards fly in: it comes round from the top of it (and ROOM over) to the bottom (and ROOM under)


func _enter_tree() -> void:
	position = _at()


func _at() -> Vector2:
	if rate == 0.0:
		return home  # (a page hung by a starting place stays put)
	var y := home.y + rate * seconds
	if box.size != Vector2.ZERO:
		var top := box.position.y - ROOM
		y = top + fposmod(y - top, box.size.y + ROOM * 2.0)
	return Vector2(home.x + SWAY * sin(_swing()), y)


## Where it is in its swing, in radians: from the world age alone, as everything about it is, and a little different for each page.
func _swing() -> float:
	return seconds * TAU / (SWAY_PERIOD + fposmod(home.x, 0.8)) + home.x * 0.013


## Where the page hangs.
func shown() -> Vector2:
	return global_position + Vector2(0.0, -FLOAT)


func _physics_process(delta: float) -> void:
	position = _at()
	rotation = ROCK * cos(_swing()) if rate != 0.0 else 0.0  # it tips one way at one end of its swing and the other way at the other
	super._physics_process(delta)


func is_under(wizard: Node2D) -> bool:
	return SpellTargets.center_of(wizard).distance_to(shown()) < TOUCH
