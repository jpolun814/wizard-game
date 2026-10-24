class_name Bramble
extends FloraSpell

## Bramble: a thicket of thorns that grows along the line you drew, on the ground under it. Whoever walks through it is
## slowed and pricked. You can jump it, and flyers pass over. Fire burns it away.

const TICK := 0.5
const DAMAGE := 3
const HEIGHT := 34.0  # how high the thorns stand, which is how high you have to jump
const SPACING := 26.0
const SPRITES := ["swamp_fern", "bush_small", "swamp_grass"]

var line := PackedVector2Array()  # the drawn line, in world points; set before the thicket enters the tree
var _surface: Array[Vector2] = []  # the ground under the thicket, a point every SPACING
var _tick := 0.0
var _box := Rect2()


func _ready() -> void:
	add_to_group("danger")
	var span := GestureTemplates.bounds(line)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var x := span.position.x
	while x <= span.end.x:
		var ground := _ground_at(Vector2(x, span.get_center().y))
		_surface.append(ground)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://art/props/%s.png" % SPRITES[rng.randi() % SPRITES.size()])
		sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5 + 2.0)  # its feet stand on the ground
		sprite.flip_h = rng.randf() < 0.5
		sprite.modulate = Color(0.75, 0.95, 0.55)
		sprite.position = ground
		sprite.scale = Vector2(1.0, 0.05)
		sprite.z_index = 1
		add_child(sprite)
		var grow := sprite.create_tween()
		grow.tween_property(sprite, "scale:y", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		x += SPACING
	var top := _surface[0].y
	var bottom := top
	for p in _surface:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	_box = Rect2(span.position.x - 10.0, top - HEIGHT, span.size.x + 20.0, bottom - top + HEIGHT + 14.0)
	Sfx.play("earth", _surface[0], -6.0)


func _physics_process(delta: float) -> void:
	_tick -= delta
	var prick := _tick <= 0.0
	if prick:
		_tick = TICK
	for body in SpellTargets.all(get_tree()):
		if not _caught(body):
			continue
		if prick:
			SpellTargets.hurt(body, DAMAGE, "Flora")
		if body.is_in_group("mobs"):
			body.apply_slow(0.3)
		else:
			body.apply_debuff("slow", 0.3)
	_burn(delta, _box)


## True for a walker standing in the thorns: on the ground within the thicket (whatever the slope under it), not jumping over it.
func _caught(body: Node2D) -> bool:
	if body.is_in_group("mobs") and body.KINDS[body.kind]["role"] == "flyer":
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
