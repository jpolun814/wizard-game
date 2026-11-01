class_name SnowDrift
extends Node2D

## A drift of snow a cloud has let fall on the ground: a low mound that settles over a few seconds, lies for a while, and is melted by fire. It is
## not solid; it is only snow lying on the ground. Its origin is the ground under its middle.

const SNOW := preload("res://art/tiles/earth_snow.png")
const SETTLE := 4.0   # seconds it takes to settle to its full size
const LIFE := 55.0
const MOST := 90      # drifts lying in the world at once: no more are laid beyond this

var width := 44.0
var height := 9.0
var _age := 0.0
var _shape := PackedVector2Array()  # the mound's outline at full height, from its left foot to its right


static func count(tree: SceneTree) -> int:
	return tree.get_nodes_in_group("drifts").size()


func _ready() -> void:
	add_to_group("drifts")
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0)
	var points := 10
	for k in points + 1:
		var u := float(k) / points
		var lumpy := rng.randf_range(0.75, 1.1)
		_shape.append(Vector2((u - 0.5) * width, -height * pow(sin(PI * u), 0.7) * lumpy))
	_shape.append(Vector2(width * 0.5, 4.0))
	_shape.append(Vector2(-width * 0.5, 4.0))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < LIFE - 2.0 and _age > SETTLE and SpellTargets.fire_touching(get_tree(), Rect2(global_position + Vector2(-width * 0.5, -height), Vector2(width, height + 4.0))):
		_age = LIFE - 2.0  # melts
	if _age >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var rise := smoothstep(0.0, SETTLE, _age)
	var fade := clampf((LIFE - _age) / 2.0, 0.0, 1.0)
	var outline := PackedVector2Array()
	var uvs := PackedVector2Array()
	var shades := PackedColorArray()
	for point in _shape:
		var shown := Vector2(point.x, point.y * rise if point.y < 0.0 else point.y)
		outline.append(shown)
		uvs.append((global_position + shown) / SNOW.get_size())
		shades.append(Color(1.0, 1.0, 1.0, fade) if point.y <= -height * 0.5 else Color(0.82, 0.88, 1.0, fade))  # lit on the crown, bluer toward the ground
	draw_polygon(outline, shades, uvs, SNOW)
