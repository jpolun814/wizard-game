class_name BallButton
extends Button

## The button on the screen that brings the stats back: a little crystal ball on its stand, the same ball the stats screen looks into. It stirs when the
## pointer is over it. It is an interface piece, so it is made here and not from a picture.

const MIST: Shader = preload("res://scripts/hud/crystal_ball.gdshader")
const BALL := 80.0  # across, in pixels: a whole number of blocks of the mist
const GLOW := 0.4  # how bright the mist is at rest
const BRASS := Color("#c9a45a")
const BRASS_DARK := Color("#6e5426")

var _mist := ShaderMaterial.new()


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(BALL + 16.0, BALL + 28.0)
	var ball := ColorRect.new()
	_mist.shader = MIST
	_mist.set_shader_parameter("cells", BALL / 4.0)
	_mist.set_shader_parameter("pulse", GLOW)
	ball.material = _mist
	ball.position = Vector2(8.0, 0.0)
	ball.size = Vector2(BALL, BALL)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ball)
	mouse_entered.connect(_stir.bind(1.0))
	mouse_exited.connect(_stir.bind(GLOW))


## The mist brightens while the pointer is over the ball and settles when it goes.
func _stir(to: float) -> void:
	create_tween().tween_property(_mist, "shader_parameter/pulse", to, 0.25)


## The stand, under the ball.
func _draw() -> void:
	var middle := size.x * 0.5
	for tier in [[24.0, 12.0, BALL - 6.0], [38.0, 10.0, BALL + 6.0]]:  # [half-width, height, top]
		var box := Rect2(middle - tier[0], tier[2], tier[0] * 2.0, tier[1])
		draw_rect(box, BRASS_DARK)
		draw_rect(Rect2(box.position, Vector2(box.size.x, 3.0)), BRASS)
