class_name IntroPage
extends Sprite2D
## One page of the pile in the opening scene: a sheet of paper that is knocked about, flutters down and is drawn into the portal.

var vel := Vector2.ZERO  # how it is moving; still while it lies in the pile
var spin := 0.0          # how fast it turns while the portal draws at it
var landed := false      # it has come down on the floor since it was last thrown
var flutter := randf() * TAU  # where it is in its sway, so that no two pages sway together
