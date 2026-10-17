class_name Hazard
extends Area2D

## A patch left on the ground for a few seconds. Fire burns the player who stands in it. Frost slows them.
## Drawn crisp, with no glow.

const FIRE_TICK := 0.5
const FIRE_DAMAGE := 5

var kind := "fire"   # "fire" or "frost"
var width := 24.0
var _age := 0.0
var _life := 3.0
var _tick := 0.0


## Places a patch centred on the point it is given, standing on the ground there.
static func place(parent: Node, at: Vector2, patch_kind: String, patch_width: float, life: float) -> Hazard:
	var hazard := Hazard.new()
	hazard.kind = patch_kind
	hazard.width = patch_width
	hazard._life = life
	hazard.global_position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(patch_width, 10.0)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	hazard.add_child(shape)
	hazard.collision_mask = 6  # the player and enemies
	if patch_kind == "fire":
		hazard.material = Fx.additive()  # fire glows, like the bonfire
	hazard.monitoring = true
	parent.add_child(hazard)
	return hazard


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	_tick -= delta
	var hurt_tick := _tick <= 0.0
	if hurt_tick:
		_tick = FIRE_TICK
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			if kind == "frost":
				body.apply_debuff("slow", 0.3)
			elif hurt_tick:
				body.take_damage(FIRE_DAMAGE)
		elif body.is_in_group("mobs"):
			if kind == "frost":
				body.apply_slow(0.3)
			elif hurt_tick:
				body.take_damage(FIRE_DAMAGE, "Fire")
	if _age >= _life:
		queue_free()


func _draw() -> void:
	var fade := clampf((_life - _age) / 0.8, 0.0, 1.0)
	if kind == "frost":
		draw_rect(Rect2(-width * 0.5, -10, width, 10), Color(0.6, 0.88, 1.0, 0.55 * fade))
		draw_line(Vector2(-width * 0.5, -10), Vector2(width * 0.5, -10), Color(0.9, 0.98, 1.0, 0.9 * fade), 1.5)
		return
	# Fire: the bonfire's layered flame tongues, scaled down for a patch on the ground.
	var tongues := int(width / 6.0)
	for i in tongues:
		var x := -width * 0.5 + width * (float(i) + 0.5) / float(tongues)
		var phase := float(i) * 1.7
		var height := (12.0 + 4.0 * sin(_age * 9.0 + phase)) * (0.8 + 0.2 * sin(float(i) * 2.3))
		var sway := sin(_age * 7.0 + phase) * 1.5
		_flame(x, height * 1.1, 4.0, Color(1.0, 0.3, 0.06, 0.45 * fade), sway)
		_flame(x, height * 0.85, 3.0, Color(1.0, 0.6, 0.15, 0.6 * fade), sway)
		_flame(x, height * 0.45, 1.5, Color(1.0, 0.93, 0.55, 0.9 * fade), sway)


## One flame tongue, the same shape as the bonfire's.
func _flame(x: float, height: float, half_width: float, colour: Color, sway: float) -> void:
	var points := PackedVector2Array([Vector2(x - half_width, 0), Vector2(x - half_width * 0.6, -height * 0.5), Vector2(x + sway, -height), Vector2(x + half_width * 0.6 + sway * 0.5, -height * 0.5), Vector2(x + half_width, 0)])
	draw_colored_polygon(points, colour)
