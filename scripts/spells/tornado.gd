class_name Tornado
extends Area2D

## A funnel of wind that touches down on the ground under where it was drawn. It bats shots back the way they
## came, and it swirls the foes inside it around until it dissipates. The funnel is a pixel-art tornado from the
## Creasta sheet: it is born, then turns on its tip for as long as it lasts.

const FUNNEL_BANDS := [Rect2(-66, -78, 116, 24), Rect2(-64, -54, 114, 24), Rect2(-56, -30, 86, 24), Rect2(-58, -6, 56, 24), Rect2(-58, 18, 42, 24), Rect2(-42, 42, 32, 24), Rect2(-64, 66, 102, 24)]  # the funnel's solid core, in bands, in its own coordinates (its tip on the ground at TIP)
const LIFE := 6.0
const SWIRL_INTERVAL := 0.3
const SWIRL_SPEED := 420.0
const TIP := 90.0  # the funnel's narrow end is this far below its middle
const DIE_TIME := 1.1  # the last moments: the birth played backwards, the funnel sinks back into the ground

var team := "player"
var _age := 0.0
var _swirl := 0.0
var _funnel: AnimatedSprite2D
var _dying := false
var _shots := {}  # a shot that entered the funnel -> where it came in, or null once it has been turned


func _ready() -> void:
	# The funnel's tip rests on the ground.
	var ground := SpellTargets.ground_below(get_world_2d(), global_position + Vector2(0, -40))
	global_position = ground - Vector2(0, TIP)
	for band in FUNNEL_BANDS:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = band.size
		shape.shape = box
		shape.position = band.get_center()
		add_child(shape)
	collision_mask = 7  # enemies, the player, and terrain
	area_entered.connect(_on_area)
	add_to_group("danger")
	Sfx.play("tornado", global_position)
	# Dust kicked up around the base.
	var dust := CPUParticles2D.new()
	dust.amount = 24
	dust.lifetime = 0.8
	dust.position = Vector2(0, TIP - 4.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(22, 2)
	dust.direction = Vector2.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0
	dust.tangential_accel_min = 200.0
	dust.tangential_accel_max = 300.0
	dust.gravity = Vector2(0, 40)
	dust.texture = Fx.tex("smoke_04")
	dust.scale_amount_min = 10.0 / Fx.TEX_SIZE
	dust.scale_amount_max = 20.0 / Fx.TEX_SIZE
	dust.color_ramp = Fx.fade_ramp(Color(0.8, 0.75, 0.6, 0.5))
	add_child(dust)
	dust.emitting = true
	# The funnel itself: the tornado is born (frames 0-15, once), then turns in a loop (frames 16-59) on its tip.
	_funnel = PixelFx.sprite("tornado", 14.0, false, 0, 15)
	_funnel.animation_finished.connect(func() -> void:
		if not _dying:
			_funnel.sprite_frames = PixelFx.frames("tornado", 14.0, true, 16)
			_funnel.play())
	_funnel.scale = Vector2.ONE * 2.0  # a whole-number scale keeps the pixels crisp
	_funnel.offset = Vector2(0, -PixelArt.FX["tornado"]["size"].y * 0.5)
	_funnel.position = Vector2(0, TIP)
	_funnel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_funnel)


func _physics_process(delta: float) -> void:
	_age += delta
	_swirl -= delta
	modulate.a = clampf(_age / 0.3, 0.0, 1.0)  # the funnel fades in as it touches down
	if not _dying and _age >= LIFE - DIE_TIME:
		_dying = true
		_funnel.sprite_frames = PixelFx.frames("tornado", 14.0, false, 0, 15)
		_funnel.play_backwards("default")
	if _swirl <= 0.0:
		_swirl = SWIRL_INTERVAL
		for body in get_overlapping_bodies():
			if not SpellTargets.affects(body, team):
				continue
			var around: Vector2 = body.global_position - global_position
			var tangent := around.rotated(PI * 0.5).normalized()
			if body.is_in_group("mobs"):
				body.knock_back(Vector2(tangent.x * SWIRL_SPEED, -180.0))
			else:
				body.push(Vector2(tangent.x * SWIRL_SPEED * 0.6, -160.0))
	_turn_far_side_shots()
	_blow_clouds(delta)
	if _age >= LIFE:
		queue_free()


## A shot that enters the funnel keeps going until it reaches the far side, and only then is turned back the way it
## came. Shots from the other side are reflected onto this side; your own shots are turned but stay yours.
func _on_area(area: Area2D) -> void:
	if _shots.has(area):
		return
	var shot_bolt := area is EnemyBolt and team == "player" and not (area as EnemyBolt).reflected
	var shot_spell := area is SpellEffect and SpellEffect.PROJECTILES.has(area.spell)
	if shot_bolt or shot_spell:
		_shots[area] = area.global_position


## Turns every shot that has reached the far side of the funnel back toward where it came in.
func _turn_far_side_shots() -> void:
	for shot in _shots.keys():
		if not is_instance_valid(shot):
			_shots.erase(shot)
			continue
		var entry: Vector2 = _shots[shot] if _shots[shot] != null else shot.global_position
		var entry_side := entry - global_position
		var from_centre: Vector2 = shot.global_position - global_position
		if _shots[shot] == null or _inside(shot.global_position) or from_centre.dot(entry_side) >= 0.0:
			continue
		var back: Vector2 = -from_centre.normalized()
		_shots[shot] = null
		if shot is EnemyBolt:
			(shot as EnemyBolt).push(back)
		elif shot.team != team:
			shot.reflect(back)
		else:
			shot.deflect(back)  # the wind turns your own shot, but it stays yours


func danger_at(point: Vector2) -> bool:
	return _inside(point)


## True while a point is within the funnel's solid core.
func _inside(point: Vector2) -> bool:
	for band in FUNNEL_BANDS:
		if band.has_point(point - global_position):
			return true
	return false


## The wind dissipates storm clouds and Blizzard snow that pass through it: they thin away and are gone.
func _blow_clouds(_delta: float) -> void:
	for node in get_parent().get_children():
		var is_cloud: bool = node is StormCloud or (node is SpellEffect and node.spell == "Blizzard")
		if not is_cloud or node.has_meta("dissipating"):
			continue
		if not _over_cloud(node):
			continue
		node.set_meta("dissipating", true)
		var fade := node.create_tween()
		fade.tween_property(node, "modulate:a", 0.0, 1.2)
		fade.tween_callback(node.queue_free)


## True when the funnel is in or under a cloud or snow, whichever part of it is wide.
func _over_cloud(node: Node2D) -> bool:
	var left: float
	var right: float
	if node is StormCloud:
		left = node.global_position.x - node.width * 0.5 - 40.0
		right = node.global_position.x + node.width * 0.5 + 40.0
	else:
		left = node.global_position.x - 40.0
		right = node.global_position.x + node.polygon[2].x + 40.0
	var top := node.global_position.y - 220.0
	var bottom := node.global_position.y + 140.0
	return global_position.x >= left and global_position.x <= right and global_position.y >= top and global_position.y <= bottom
