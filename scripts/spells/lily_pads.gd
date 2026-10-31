class_name LilyPads
extends FloraSpell

## Lily Pads: a row of floating leaves appears along the line you drew. Each one holds your weight, so you can walk
## across water or a pit on them. After 8 seconds they sink. Fire burns them, so they will not cross lava, and a flood
## washes them away.

const SECONDS := 8.0
const SINK_SECONDS := 1.0
const PAD_WIDTH := 52.0
const PAD_FLOAT_REACH := 100.0  # how far from the drawn line a pool's surface can be for the leaf to settle on it
const LEAF := preload("res://art/props/swamp_vine.png")

var line := PackedVector2Array()  # the drawn line, in world points; set before the pads enter the tree
var _age := 0.0
var _sinking := -1.0  # counts up once the pads have begun to sink
var _pads: Array[Node2D] = []
var _statics: Array[StaticBody2D] = []
var _box := Rect2()


func _ready() -> void:
	add_to_group("lily_pads")
	var span := GestureTemplates.bounds(line)
	var count := clampi(roundi(span.size.x / (PAD_WIDTH + 8.0)), 2, 8)
	var low := span.end.y
	var high := span.position.y
	for i in count:
		var x := span.position.x + (i + 0.5) * span.size.x / count
		var y := _line_height_at(x)
		var water := Pond.surface_near(get_tree(), x, y, PAD_FLOAT_REACH)
		if water < INF:
			y = water - 2.0  # a leaf floats on the water as it is now, not at the height it was drawn
		low = maxf(low, y)
		high = minf(high, y)
		var pad := Node2D.new()
		pad.position = Vector2(x, y)
		var leaf := Sprite2D.new()
		leaf.texture = LEAF
		leaf.modulate = Color(0.7, 1.0, 0.6)
		leaf.scale = Vector2(1.0, 0.9)
		leaf.z_index = 1
		pad.add_child(leaf)
		var platform := StaticBody2D.new()
		platform.collision_layer = 16  # a one-way platform
		platform.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(PAD_WIDTH, 8.0)
		shape.shape = rect
		shape.position = Vector2(0, 4.0)
		shape.one_way_collision = true
		shape.one_way_collision_margin = 6.0
		platform.add_child(shape)
		pad.add_child(platform)
		pad.scale = Vector2(0.05, 0.05)
		add_child(pad)
		var grow := pad.create_tween()
		grow.tween_interval(i * 0.06)
		grow.tween_property(pad, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_pads.append(pad)
		_statics.append(platform)
	_box = Rect2(span.position.x - 10.0, high - 10.0, span.size.x + 20.0, low - high + 34.0)
	Sfx.play("snow", Vector2(span.get_center().x, high), -6.0)


## The height of the drawn line at an x position, averaged over the points near it.
func _line_height_at(x: float) -> float:
	var sum := 0.0
	var count := 0
	for p in line:
		if absf(p.x - x) < PAD_WIDTH * 0.6:
			sum += p.y
			count += 1
	return sum / count if count > 0 else line[0].y


func _physics_process(delta: float) -> void:
	_age += delta
	if _sinking >= 0.0:
		_sinking += delta
		for pad in _pads:
			pad.position.y += 22.0 * delta
			pad.modulate.a = clampf(1.0 - _sinking / SINK_SECONDS, 0.0, 1.0)
		if _sinking >= SINK_SECONDS:
			queue_free()
		return
	_burn(delta, _box)
	if _age >= SECONDS - 1.5:
		for pad in _pads:
			pad.modulate.a = 0.6 + 0.4 * sin(_age * 16.0)  # the leaves flicker before they go
	if _age >= SECONDS:
		sink()


## The pads go under: they stop being solid at once, and drift down out of sight. A flood does this too.
func sink() -> void:
	if _sinking >= 0.0:
		return
	_sinking = 0.0
	for platform in _statics:
		platform.queue_free()
	_statics.clear()


func _burned_down() -> void:
	for platform in _statics:
		platform.queue_free()
	queue_free()
