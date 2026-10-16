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


func _draw() -> void:
	var fade := clampf(1.0 - _age / DURATION, 0.0, 1.0)
	for shard in _shards:
		var s: float = shard["size"]
		var rot: float = shard["rot"]
		var origin: Vector2 = shard["pos"]
		# A thin triangle, so each piece reads as a sliver of ice.
		var pts := PackedVector2Array([
			origin + Vector2(s, 0).rotated(rot),
			origin + Vector2(-s * 0.4, s * 0.6).rotated(rot),
			origin + Vector2(-s * 0.4, -s * 0.6).rotated(rot),
		])
		draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.9 * fade))
