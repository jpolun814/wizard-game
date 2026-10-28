class_name Bramble
extends FloraSpell

## Bramble: a thicket of thorns that grows along the line you drew, on the ground under it. Whoever walks through it is
## nearly stopped and pricked with every step, and cannot jump while caught, but standing still is safe. Flyers pass over. Fire
## burns it away. The world has the same thorns growing over stretches of its floor.

const STEP := 0.3     # seconds between one footfall and the next while walking
const DAMAGE := 8     # what each footfall costs
const HEIGHT := 34.0  # how high the thorns stand, which is how high you have to jump
const SPACING := 26.0
const SPRITES := ["swamp_fern", "bush_small", "swamp_grass"]

var line := PackedVector2Array()  # the drawn line, in world points; set before the thicket enters the tree
var planted_ground := PackedVector2Array()  # for a thicket the world grows: the ground it stands on, a point every SPACING, so nothing is looked up
var _surface: Array[Vector2] = []  # the ground under the thicket, a point every SPACING
var _stride := {}  # body -> seconds since its last footfall in the thorns
var _box := Rect2()


func _ready() -> void:
	add_to_group("danger")
	var planted := not planted_ground.is_empty()
	if planted:
		_surface.append_array(planted_ground)
	else:
		var span := GestureTemplates.bounds(line)
		var x := span.position.x
		while x <= span.end.x:
			_surface.append(_ground_at(Vector2(x, span.get_center().y)))
			x += SPACING
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for foot in _surface:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://art/props/%s.png" % SPRITES[rng.randi() % SPRITES.size()])
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5 + 2.0)  # its feet stand on the ground
		sprite.flip_h = rng.randf() < 0.5
		sprite.modulate = Color(0.75, 0.95, 0.55)
		sprite.position = foot
		sprite.z_index = 1
		add_child(sprite)
		if not planted:
			sprite.scale = Vector2(1.0, 0.05)
			var grow := sprite.create_tween()
			grow.tween_property(sprite, "scale:y", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var top := _surface[0].y
	var bottom := top
	for p in _surface:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	var left := _surface[0].x
	var right := _surface[_surface.size() - 1].x
	_box = Rect2(left - 10.0, top - HEIGHT, right - left + 20.0, bottom - top + HEIGHT + 14.0)
	if not planted:
		Sfx.play("earth", _surface[0], -6.0)


func _physics_process(delta: float) -> void:
	var caught := []
	for body in SpellTargets.all(get_tree()):
		if not _caught(body):
			continue
		caught.append(body)
		if body.is_in_group("mobs"):
			body.apply_slow(0.3)
		else:
			body.apply_debuff("tangle", 0.3)
		# Only a walker is pricked, once with each footfall; whoever stands still in the thorns is left alone.
		if absf(body.velocity.x) > 10.0 and body.is_on_floor():
			_stride[body] = _stride.get(body, STEP * 0.5) + delta
			if _stride[body] >= STEP:
				_stride[body] = 0.0
				if body.is_in_group("player"):
					body.take_damage(DAMAGE, false)  # every footfall counts: the wizard's pause after a hit would let some through
				else:
					SpellTargets.hurt(body, DAMAGE, "Flora")
	for body in _stride.keys():
		if not caught.has(body):
			_stride.erase(body)
	_burn(delta, _box)


## True for a walker standing in the thorns: on the ground within the thicket (whatever the slope under it), not jumping over it.
func _caught(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind].role == "flyer":
		return false
	var feet := body.global_position
	if feet.x < _box.position.x or feet.x > _box.end.x:
		return false
	var ground := _surface_at(feet.x)
	return feet.y >= ground - HEIGHT * 0.7 and feet.y <= ground + 14.0


## The ground's height under the thicket at an x position.
func _surface_at(x: float) -> float:
	var best := _surface[0]
	for p in _surface:
		if absf(p.x - x) < absf(best.x - x):
			best = p
	return best.y


func danger_at(point: Vector2) -> bool:
	if point.x < _box.position.x or point.x > _box.end.x:
		return false
	var ground := _surface_at(point.x)
	return point.y >= ground - HEIGHT and point.y <= ground + 14.0
