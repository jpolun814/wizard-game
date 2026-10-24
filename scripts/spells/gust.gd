class_name Gust
extends SpellEffect

## A blast of wind along the stroke. It carries light things: shots are turned along it, flyers are swept away, smoke
## and spores are blown clear, and the wizard and walkers are shoved sideways (never up: only Push lifts). Heavy
## things hardly move.

const LIFE := 0.7
const LENGTH := 340.0
const WIDTH := 130.0
const SPEED := 620.0  # how hard it shoves a flyer; walkers and the wizard feel less of it
const WALKER_SHARE := 0.35
const PLAYER_SHARE := 0.7

var _aim := Vector2.RIGHT
var _turned := {}  # shots already turned, so each is sent along once
var _streaks: Array[AnimatedSprite2D] = []


func _begin(origin: Vector2, aim_angle: float) -> void:
	_life = LIFE
	_aim = Vector2.from_angle(aim_angle)
	rotation = aim_angle
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH, WIDTH)
	_add_shape(rect, Vector2(LENGTH * 0.5, 0))
	collision_mask = 7  # shots, enemies and the wizard
	# Streaks of wind racing along the gust, from the pixel-art wind.
	for i in 5:
		var streak := PixelFx.sprite("wind_bolt", 14.0)
		streak.scale = Vector2.ONE * 2.0
		streak.modulate = Color(0.9, 0.95, 1.0, 0.85)
		streak.position = Vector2(0, (i - 2) * WIDTH * 0.2)
		streak.frame = i
		add_child(streak)
		_streaks.append(streak)
	Sfx.play("push", origin, -4.0)


func _act(delta: float) -> void:
	for i in _streaks.size():
		var x := fmod(_age * 700.0 + i * LENGTH * 0.37, LENGTH)
		_streaks[i].position.x = x
		_streaks[i].modulate.a = 0.85 * _fade()
	for area in get_overlapping_areas():
		if area.is_in_group("shots") and not _turned.has(area):
			_turned[area] = true
			area.reflect(_aim)
	for body in get_overlapping_bodies():
		_blow(body, delta)
	for cloud in get_tree().get_nodes_in_group("clouds"):
		if _reaches(cloud.global_position):
			cloud.dissipate()
	for item in get_tree().get_nodes_in_group("items"):
		if _reaches(item.global_position):
			item.knock(_aim * SPEED * 0.4)


## Shoves one body along the wind. Only sideways: whatever way the stroke points, the push is horizontal.
func _blow(body: Node2D, delta: float) -> void:
	if not SpellTargets.affects(body):
		return
	var along := Vector2(signf(_aim.x) * absf(_aim.x), 0.0) * SPEED
	if body.is_in_group("mobs"):
		var share := WALKER_SHARE
		if body.KINDS[body.kind]["role"] == "flyer":
			share = 1.0
			along = _aim * SPEED  # a flyer is carried any way the wind blows
		elif body.KINDS[body.kind]["effect"] == "smash":
			share = 0.0
		if share > 0.0:
			body.knock_back(along * share)
	else:
		body.push(Vector2(along.x * PLAYER_SHARE, 0.0))


## True when a point lies in the gust's path.
func _reaches(point: Vector2) -> bool:
	var local := to_local(point)
	return local.x >= -20.0 and local.x <= LENGTH and absf(local.y) <= WIDTH * 0.5 + 20.0
