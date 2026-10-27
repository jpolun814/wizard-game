class_name Volcano
extends Node2D

## A volcano that erupts for a few seconds. A mound of rock heaves up out of the ground with fire roaring from its
## top, and it throws balls of lava in arcs (LavaBall). All of it is pixel art: the rock from the cemetery, the flames
## and fireballs from the effect strips.

const ERUPT_SECONDS := 3.0  # how long it erupts each time
const DORMANT_MIN := 15.0  # how long it sleeps between eruptions, at least and at most
const DORMANT_MAX := 45.0
const ERUPT_INTERVAL := 0.45
const GROUND_SAMPLES := 9  # the ground is measured at this many points across the foot of the mountain
const CRATER_Y := -70.0  # the top of the mountain's crater, in its own picture: where the fire comes out

var _age := 0.0
var _erupting := true  # it erupts for a while, then sleeps for a while, for good
var _phase := ERUPT_SECONDS  # time left in the current eruption or sleep
var _vent: AnimatedSprite2D
var _erupt := 0.0
var _lean := 0.0  # the slope the volcano stands on; its vent, crater and fire lean the same way
var _glow: Node2D
var _mound: Sprite2D  # the mountain, heaving up out of the ground


func _ready() -> void:
	add_to_group("danger")
	Sfx.play("volcano", global_position)
	Fx.debris(get_parent(), global_position, Color("#5a4238"), 12, 200.0)
	GameCamera.shake_scene(get_tree(), 0.3)
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
	# The mountain heaves up out of the ground, standing on its bottom edge.
	_mound = Sprite2D.new()
	_mound.texture = load("res://art/props/volcano_mound.png")
	_mound.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mound.offset = Vector2(0, -_mound.texture.get_height() * 0.5 + 3.0)
	_mound.scale = Vector2(1.0, 0.0)
	_lean = _slope()  # the mountain leans with the ground it stands on
	_mound.rotation = _lean
	# Sunk far enough that the lowest corner of the tilted mountain still sits below the ground line.
	_mound.position = Vector2(0, _seat_y() - global_position.y - 1.0)
	_mound.z_index = -1  # a layer behind the ground, so the mountain sits in the earth rather than on it
	add_child(_mound)
	create_tween().tween_property(_mound, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fire roars out of its top for as long as it erupts.
	var vent := PixelFx.sprite("fire_puff", 14.0, true, 1)
	vent.scale = Vector2.ONE * 2.0
	vent.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
	vent.position = _crater(8.0)
	vent.rotation = _lean
	vent.z_index = 1
	add_child(vent)
	_vent = vent
	add_to_group("lasting")


func _physics_process(delta: float) -> void:
	_age += delta
	_erupt -= delta
	_phase -= delta
	if _phase <= 0.0:
		_erupting = not _erupting
		_phase = ERUPT_SECONDS if _erupting else randf_range(DORMANT_MIN, DORMANT_MAX)
		_vent.visible = _erupting
	if _erupting and _erupt <= 0.0:
		_erupt = ERUPT_INTERVAL
		LavaBall.throw(get_parent(), global_position + _crater(0.0), Vector2(randf_range(-180.0, 180.0), -480.0).rotated(_lean))
		Fx.smoke(get_parent(), global_position + _crater(-20.0), Color(0.2, 0.17, 0.17, 0.6), 2, 26.0, 60.0)
	_glow.queue_redraw()


## The mountain and the ground round it are dangerous while it erupts.
func danger_at(point: Vector2) -> bool:
	return _erupting and absf(point.x - global_position.x) < 110.0 and point.y > global_position.y - 120.0


## The light the eruption throws over the crater.
func _draw_glow() -> void:
	if _erupting:
		_glow.draw_circle(_crater(0.0), 30.0 + 4.0 * sin(_age * 6.0), Color(1.0, 0.45, 0.15, 0.12))


## The angle of the ground under the volcano, from the surface under either bottom corner of its picture.
func _slope() -> float:
	var left := SpellTargets.solid_below(get_world_2d(), global_position + Vector2(-_half_width(), -40))
	var right := SpellTargets.solid_below(get_world_2d(), global_position + Vector2(_half_width(), -40))
	return atan2(right.y - left.y, 2.0 * _half_width())


## The height (world y) its bottom edge must sit at so that the whole of it is on or under the ground: the ground is
## measured all along its foot, so a dip or a bump under the middle is covered as well as the corners.
func _seat_y() -> float:
	var half := _half_width()
	var seat := -INF
	for i in GROUND_SAMPLES:
		var along := lerpf(-half, half, float(i) / (GROUND_SAMPLES - 1))
		var edge := Vector2(along, 0).rotated(_lean)  # this point of the leaning bottom edge, from the middle of it
		var ground := SpellTargets.solid_below(get_world_2d(), global_position + Vector2(edge.x, -40))
		seat = maxf(seat, ground.y - edge.y)
	return seat + 2.0


func _half_width() -> float:
	return _mound.texture.get_width() * 0.5


## A point above the crater (lift is how far above the top of the mountain). The crater moves with the mountain: it is
## sunk and leans with it.
func _crater(lift: float) -> Vector2:
	return _mound.position + Vector2(0, CRATER_Y + lift).rotated(_lean)
