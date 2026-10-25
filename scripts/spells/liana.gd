class_name Liana
extends FloraSpell

## Liana: a vine grows up out of the ground where the line began, as high as the line you drew. Stand at it and press W to take
## hold, then W and S to climb. It stays until fire burns it.

const MAX_RISE := 420.0   # the highest the vine climbs above the ground
const MIN_RISE := 90.0    # even a short line grows a vine you can climb
const GRAB_WIDTH := 18.0  # how close to the vine you must be to take hold
const LINK := 50.0        # each piece of vine, from the pixel art, is this long

var line := PackedVector2Array()  # the drawn leaf and line, in world points; set before the vine enters the tree
var _top := Vector2.ZERO
var _bottom := Vector2.ZERO
var _age := 0.0
var _hang: Node2D


func _ready() -> void:
	add_to_group("climbables")
	# The vine springs from the ground under where the line began and climbs as high as the line you drew went.
	var foot := _ground_at(line[0])
	var high := line[0].y
	for p in line:
		high = minf(high, p.y)
	_bottom = foot
	_top = Vector2(foot.x, clampf(high, foot.y - MAX_RISE, foot.y - MIN_RISE))
	global_position = _top
	# The vine: pieces of the swamp vine turned upright, one above another. It grows up out of the ground.
	_hang = Node2D.new()
	_hang.z_index = -1
	_hang.position = Vector2(0, _bottom.y - _top.y)  # its origin is at the ground, so it grows from there
	add_child(_hang)
	var length := _bottom.y - _top.y
	var pieces := ceili(length / LINK)
	for i in pieces:
		var piece := Sprite2D.new()
		piece.texture = load("res://art/props/swamp_vine.png")
		piece.rotation = PI * 0.5
		piece.flip_v = i % 2 == 1
		piece.modulate = Color(0.8, 1.0, 0.65)
		piece.position = Vector2(0, -(i * LINK + LINK * 0.5))
		_hang.add_child(piece)
	_hang.scale = Vector2(1.0, 0.02)
	create_tween().tween_property(_hang, "scale:y", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	Fx.debris(get_parent(), foot, Color("#4a6a30"), 6, 120.0)
	Sfx.play("earth", foot, -6.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_burn(delta, Rect2(_top.x - 10.0, _top.y, 20.0, _bottom.y - _top.y))


## True when a body's feet (or hands) are on the vine: close enough across, and between where it holds and the ground.
func can_grab(point: Vector2) -> bool:
	return absf(point.x - _top.x) <= GRAB_WIDTH and point.y >= _top.y - 4.0 and point.y <= _bottom.y + 12.0


func vine_x() -> float:
	return _top.x


func top_y() -> float:
	return _top.y


func bottom_y() -> float:
	return _bottom.y
