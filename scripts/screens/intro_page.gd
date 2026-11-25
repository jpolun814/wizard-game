class_name IntroPage
extends Sprite2D
## One page of the pile in the opening scene: a sheet of paper that is knocked about, flutters down and is drawn into the portal.

const STRIP := preload("res://art/props/page_tumble_small.png")  # a page turning over, in TURNS frames (`tools/prepare_page_frames.py`); frame 0 is flat
const TURNS := 12

var vel := Vector2.ZERO  # how it is moving; still while it lies in the pile
var spin := 0.0          # how fast it turns while the portal draws at it
var landed := false      # it has come down on the floor since it was last thrown
var flutter := Dice.looks.randf() * TAU  # where it is in its sway, so that no two pages sway together


func _init() -> void:
	texture = STRIP
	hframes = TURNS


## Shows the page turned this far over (radians): paper turns over as it moves and no longer squashes like a board.
func turn_to(angle: float) -> void:
	frame = int(fposmod(angle, TAU) / TAU * float(TURNS)) % TURNS
