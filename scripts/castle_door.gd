class_name CastleDoor
extends Node2D

## A wooden door in a doorway of the castle. It swings open when anyone comes near, and shuts again when they have gone by. Shut, it is as
## solid as the wall: no one walks through it and no shot or spell passes. Its origin is the middle of the doorway, on the floor.
## It swings away from whoever opens it: the hinge is on the far side from them, and opening, the door is drawn narrower and narrower
## toward the hinge, as a door turning edge-on to the eye.

const HEIGHT := 128.0
const WIDTH := 64.0      # the wall's thickness: the doorway
const REACH := 120.0     # how near someone has to come for it to open
const SHUT_AFTER := 1.2  # seconds after the last of them has gone
const SWING := 2.2       # how much of the swing it makes in a second
const OPEN_WIDTH := 0.16 # how narrow it is drawn when wide open, against shut

var _swing := 0.0  # 0 shut, 1 open
var _alone := 99.0
var _hinge := 1.0  # which edge it turns on: 1 the right, -1 the left
var _sprite: Sprite2D
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = 1
	var doorway := Polygon2D.new()  # the dark of the passage, which the door turns away from as it opens
	doorway.color = Color(0.03, 0.02, 0.06, 0.92)
	doorway.polygon = PackedVector2Array([Vector2(-WIDTH * 0.5, -HEIGHT), Vector2(WIDTH * 0.5, -HEIGHT), Vector2(WIDTH * 0.5, 0), Vector2(-WIDTH * 0.5, 0)])
	add_child(doorway)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/props/door.png")
	_sprite.centered = false
	_sprite.position = Vector2(-WIDTH * 0.5, -HEIGHT)
	add_child(_sprite)
	_set_swing()
	var body := StaticBody2D.new()
	body.collision_layer = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, HEIGHT)
	_shape.shape = rect
	_shape.position = Vector2(0, -HEIGHT * 0.5)
	body.add_child(_shape)
	add_child(body)


func _physics_process(delta: float) -> void:
	var close := false
	var in_the_way := false
	var nearest := 1e9
	var from_side := 0.0
	for body in SpellTargets.all(get_tree()):
		var at := SpellTargets.center_of(body)
		if absf(at.x - global_position.x) < REACH and at.y > global_position.y - HEIGHT - 40.0 and at.y < global_position.y + 40.0:
			close = true
			if absf(at.x - global_position.x) < nearest:
				nearest = absf(at.x - global_position.x)
				from_side = signf(at.x - global_position.x)
			in_the_way = in_the_way or absf(at.x - global_position.x) < 40.0
	_alone = 0.0 if close else _alone + delta
	var want := 1.0 if (_alone < SHUT_AFTER or in_the_way) else 0.0
	if _swing <= 0.01 and want > 0.0 and from_side != 0.0:
		_hinge = -from_side  # it opens away from the one at it
	_swing = move_toward(_swing, want, SWING * delta)
	_set_swing()
	_shape.set_deferred("disabled", _swing > 0.2)


func _set_swing() -> void:
	var texture: Texture2D = _sprite.texture
	var eased := smoothstep(0.0, 1.0, _swing)
	var width := lerpf(1.0, OPEN_WIDTH, eased)  # how much of its width shows
	_sprite.scale = Vector2(WIDTH / texture.get_width() * width, HEIGHT / texture.get_height())
	_sprite.position.x = -WIDTH * 0.5 if _hinge < 0.0 else WIDTH * 0.5 - WIDTH * width  # the door stays fixed at its hinge
	var shade := lerpf(1.0, 0.65, eased)  # the face turns from the light
	_sprite.modulate = Color(shade, shade, shade)
