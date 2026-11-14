class_name Shatter
extends Node2D

## Ice breaking: sharp shards fly out from the point of impact and fade. Used when a frost bolt lands.

const DURATION := 0.5

var color := Color("#b8f0ff")
var _shards: Array = []
var _age := 0.0


## Creates a shatter at a point, under the parent, and returns it.
static func spawn(parent: Node, pos: Vector2, shard_color: Color) -> Shatter:
	var s := Shatter.new()
	s.color = shard_color
	s.global_position = pos
	parent.add_child(s)
	return s


func _ready() -> void:
	for i in 10:
		_shards.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(90.0, 220.0),
			"rot": randf() * TAU,
			"size": randf_range(3.0, 6.5),
		})


func _process(delta: float) -> void:
	_age += delta
	for shard in _shards:
		shard["pos"] += shard["vel"] * delta
		shard["vel"] *= 0.9
	queue_redraw()
	if _age >= DURATION:
		queue_free()


## Each shard is a little block of pixels with a darker edge, so it reads as a chip of ice or stone.
func _draw() -> void:
	var fade := clampf(1.0 - _age / DURATION, 0.0, 1.0)
	for shard in _shards:
		var s := floorf(shard["size"] * 0.6) + 1.0
		var at: Vector2 = (shard["pos"] as Vector2).floor()
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(s + 2.0, s + 1.0)), Color(color.darkened(0.55), 0.9 * fade))
		draw_rect(Rect2(at, Vector2(s, s - 1.0)), Color(color, 0.95 * fade))
