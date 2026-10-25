class_name GreatOak
extends FloraSpell

## Great Oak: a tree grows where the trunk was drawn. Its branches are ledges you can jump onto, and its trunk is a
## wall to walkers and shots, until it is broken. Fire, Earthquake and Stonefall bring it down. It creaks and
## leans first, then falls, and everything under it when it lands is crushed: you, and anyone else.

const TREE := preload("res://art/props/great_oak.png")  # 208 x 234; its trunk's base is a little left of the middle
const HEALTH := 220.0
const BURN_DAMAGE := 75.0  # per second, while it burns
const TRUNK := Rect2(-12, -200, 24, 200)  # the trunk's solid part, from its base
## The ledges, as [height above the base, left edge, right edge], each one under a branch of the drawing.
const LEDGES := [[30.0, -36.0, -10.0], [112.0, -44.0, -12.0], [156.0, 30.0, 90.0], [212.0, -26.0, 44.0]]
const GROW_SECONDS := 0.8
const CREAK_SECONDS := 1.3
const FALL_SECONDS := 0.9
const CRUSH_DAMAGE := 35
const HEIGHT := 234.0
const WIDTH := 44.0  # how wide the falling trunk crushes

var _health := HEALTH
var _state := "growing"  # growing, standing, creaking, falling, fallen
var _t := 0.0
var _lean := 1.0  # which way it falls: 1 to the right, -1 to the left
var _statics: Array[StaticBody2D] = []
var _crushed := {}  # bodies the falling trunk has already hit
var _picture: Node2D


func _ready() -> void:
	burn_seconds = 3.0
	add_to_group("breakables")
	add_to_group("danger")
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	_picture = Node2D.new()
	_picture.z_index = -1
	add_child(_picture)
	var trunk := Sprite2D.new()
	trunk.texture = TREE
	trunk.position = Vector2(12.0, -HEIGHT * 0.5)
	_picture.add_child(trunk)
	scale = Vector2(1.0, 0.05)
	var grow := create_tween()
	grow.tween_property(self, "scale:y", 1.0, GROW_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	grow.tween_callback(_stand)
	Sfx.play("earth", global_position)
	Sfx.play("quake", global_position, -4.0)
	Fx.debris(get_parent(), global_position, Color("#7a6a3a"), 12, 220.0)
	GameCamera.shake_scene(get_tree(), 0.3)


## The tree has grown: now its trunk and ledges are solid.
func _stand() -> void:
	_state = "standing"
	var trunk := StaticBody2D.new()
	trunk.collision_layer = 1
	trunk.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = TRUNK.size
	shape.shape = box
	shape.position = TRUNK.get_center()
	trunk.add_child(shape)
	add_child(trunk)
	_statics.append(trunk)
	var ledges := StaticBody2D.new()
	ledges.collision_layer = 16  # a one-way platform: jump up through it, land on top
	ledges.collision_mask = 0
	for ledge in LEDGES:
		var plank := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(ledge[2] - ledge[1], 10.0)
		plank.shape = rect
		plank.position = Vector2((ledge[1] + ledge[2]) * 0.5, -ledge[0] + 5.0)
		plank.one_way_collision = true
		plank.one_way_collision_margin = 6.0
		ledges.add_child(plank)
	add_child(ledges)
	_statics.append(ledges)


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		"standing":
			if is_burning():
				_health -= BURN_DAMAGE * delta
				if _health <= 0.0:
					_topple(1.0 if randf() < 0.5 else -1.0)
			_burn(delta, Rect2(global_position + Vector2(-60, -HEIGHT), Vector2(150, HEIGHT)))
		"creaking":
			var sway := sin(_t * 18.0) * 0.015 + _lean * 0.07 * (_t / CREAK_SECONDS)
			rotation = sway
			if fmod(_t, 0.35) < delta:
				Sfx.play("stones", global_position, -8.0)
				Fx.debris(get_parent(), global_position + Vector2(0, -4), Color("#7a6a3a"), 3, 90.0)
			if _t >= CREAK_SECONDS:
				_state = "falling"
				_t = 0.0
		"falling":
			var progress := clampf(_t / FALL_SECONDS, 0.0, 1.0)
			rotation = _lean * lerpf(0.07, PI * 0.5, progress * progress)
			_crush()
			if progress >= 1.0:
				_land()
		"fallen":
			modulate.a = clampf((4.0 - _t) / 1.0, 0.0, 1.0)
			if _t >= 4.0:
				queue_free()


## A blow near the tree (a quake, a falling boulder) wears it down. True when the blow reached it.
func take_blow_near(point: Vector2, damage: float) -> bool:
	if _state != "standing" or absf(point.x - global_position.x) > 48.0 or point.y < global_position.y - HEIGHT or point.y > global_position.y + 24.0:
		return false
	_health -= damage
	Fx.debris(get_parent(), point, Color("#7a6a3a"), 6, 140.0)
	Sfx.play("stones", global_position, -4.0)
	if _health <= 0.0:
		_topple(signf(global_position.x - point.x) if point.x != global_position.x else 1.0)
	return true


## The tree is done for. It leans and creaks first, which is the warning, and then it falls away from the blow.
func _topple(lean: float) -> void:
	if _state == "creaking" or _state == "falling" or _state == "fallen":
		return
	_lean = lean
	_state = "creaking"
	_t = 0.0
	for body in _statics:
		body.queue_free()
	_statics.clear()


## The falling trunk crushes whoever it passes through, each once.
func _crush() -> void:
	for body in SpellTargets.all(get_tree()):
		if _crushed.has(body):
			continue
		var local := to_local(SpellTargets.center_of(body))
		if local.y <= 20.0 and local.y >= -HEIGHT and absf(local.x) <= WIDTH:
			_crushed[body] = true
			SpellTargets.hurt(body, CRUSH_DAMAGE, "Flora")
			if body.is_in_group("player"):
				body.push(Vector2(_lean * 360.0, 0.0))
			else:
				body.knock_back(Vector2(_lean * 360.0, -120.0))  # an enemy the fall just killed has left its group


func _land() -> void:
	_state = "fallen"
	_t = 0.0
	rotation = _lean * PI * 0.5
	remove_from_group("danger")
	GameCamera.shake_scene(get_tree(), 0.6)
	Sfx.play("quake", global_position)
	Fx.debris(get_parent(), global_position + Vector2(_lean * HEIGHT * 0.9, -6), Color("#7a6a3a"), 18, 260.0)
	Fx.smoke(get_parent(), global_position + Vector2(_lean * HEIGHT * 0.9, -6), Color(0.45, 0.4, 0.3, 0.5), 6, 34.0, 40.0)


## Burning down means falling, not vanishing: a tree that has burned through topples.
func _burned_down() -> void:
	_topple(1.0 if randf() < 0.5 else -1.0)


## The fall's path is dangerous from the moment it starts to creak.
func danger_at(point: Vector2) -> bool:
	if _state == "creaking" or _state == "falling":
		var reach := _lean * (point.x - global_position.x)
		return reach > -WIDTH and reach < HEIGHT and point.y > global_position.y - HEIGHT and point.y < global_position.y + 10.0
	return false
