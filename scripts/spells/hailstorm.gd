class_name Hailstorm
extends SpellEffect

## Hailstorm: a storm cloud along the drawn line from which stones of ice fall, one at a time, for a short while. A stone stops at the first ground or
## platform it meets, so a roof is shelter. A short violent volley, where a Blizzard lingers.

const SECONDS := 4.5
const EVERY := 0.07           # seconds between two stones
const CLOUDS := [preload("res://art/props/cloud_storm_big.png"), preload("res://art/props/cloud_storm_small_1.png"), preload("res://art/props/cloud_storm_small_2.png")]
const FALL_DANGER := 520.0    # how far under the cloud the stones may be met

var line := PackedVector2Array()  # the cloud's line, from where it was drawn: its two ends, in the world
var _left := 0.0
var _right := 0.0
var _y := 0.0
var _dissipating := false


func _begin(origin: Vector2, _aim_angle: float) -> void:
	add_to_group("clouds")
	add_to_group("danger")
	_life = SECONDS
	_left = minf(line[0].x, line[line.size() - 1].x)
	_right = maxf(line[0].x, line[line.size() - 1].x)
	_y = (line[0].y + line[line.size() - 1].y) * 0.5
	global_position = Vector2(_left, _y)
	Sfx.play("thunder", Vector2((_left + _right) * 0.5, _y), -10.0)


func _act(delta: float) -> void:
	_tick -= delta
	while _tick <= 0.0:
		_tick += EVERY
		var stone := HailStone.new()
		stone.caster = caster
		get_parent().add_child(stone)
		stone.global_position = Vector2(randf_range(_left, _right), _y + 8.0)


## True where the stones fall: under the cloud, down as far as they carry.
func danger_at(point: Vector2) -> bool:
	return point.x >= _left and point.x <= _right and point.y >= _y - 10.0 and point.y <= _y + FALL_DANGER and not is_queued_for_deletion()


func span() -> Vector2:
	return Vector2(_left, _right)


## The wind of a tornado or a gust thins the cloud away.
func dissipate() -> void:
	if _dissipating:
		return
	_dissipating = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.8)
	fade.tween_callback(queue_free)


func _draw() -> void:
	var fade := clampf(minf(_age / 0.3, (_life - _age) / 0.6), 0.0, 1.0)
	var x := -10.0
	var i := 0
	var width := _right - _left
	while x < width + 10.0:
		var cloud: Texture2D = CLOUDS[i % CLOUDS.size()]
		var bob := roundf(sin(_age * 1.1 + i) * 2.0)
		var at := Vector2(x, -cloud.get_height() * 0.6 + bob)
		draw_texture(cloud, at + Vector2(3.0, 7.0), Color(0.2, 0.24, 0.34, 0.85 * fade))  # the dark underside
		draw_texture(cloud, at, Color(0.55, 0.6, 0.74, fade))
		x += cloud.get_width() * 0.7
		i += 1
