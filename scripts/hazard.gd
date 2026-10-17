class_name Hazard
extends Area2D

## A patch left on the ground for a few seconds. Fire burns whoever stands in it. Frost slows them.
## Like a spell, it has a team: patches from your spells burn everyone, patches from enemies burn only you.

const FIRE_TICK := 0.5
const FIRE_DAMAGE := 5
const ICE := preload("res://art/props/ice_fill.png")

var kind := "fire"   # "fire" or "frost"
var width := 24.0
var team := "enemy"
var _age := 0.0
var _life := 3.0
var _tick := 0.0
var _flames: Array[AnimatedSprite2D] = []


## Places a patch centred on the point it is given, standing on the ground there.
static func place(parent: Node, at: Vector2, patch_kind: String, patch_width: float, life: float) -> Hazard:
	var hazard := Hazard.new()
	hazard.kind = patch_kind
	hazard.width = patch_width
	hazard._life = life
	hazard.global_position = at
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(patch_width, 14.0)
	shape.shape = rect
	shape.position = Vector2(0, -7)
	hazard.add_child(shape)
	hazard.collision_mask = 6  # the player and enemies
	hazard.monitoring = true
	parent.add_child(hazard)
	return hazard


func _ready() -> void:
	add_to_group("danger")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if kind != "fire":
		return
	# Small pixel-art flames along the patch, each a little out of step with the next.
	var count := maxi(1, int(width / 28.0))
	for i in count:
		var flame := PixelFx.sprite("flame", 26.0 + randf() * 8.0)
		flame.offset = Vector2(0, -PixelArt.FX["flame"]["size"].y * 0.5)
		flame.position = Vector2((i + 0.5) * width / count - width * 0.5, 4.0)
		flame.flip_h = i % 2 == 1
		flame.frame = randi() % 60
		add_child(flame)
		_flames.append(flame)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	_tick -= delta
	var hurt_tick := _tick <= 0.0
	if hurt_tick:
		_tick = FIRE_TICK
	for body in get_overlapping_bodies():
		if not SpellTargets.affects(body, team):
			continue
		if kind == "frost":
			if body.is_in_group("mobs"):
				body.apply_slow(0.3)
			else:
				body.apply_debuff("slow", 0.3)
		elif hurt_tick:
			SpellTargets.hurt(body, FIRE_DAMAGE, "Fire", team)
	for flame in _flames:
		flame.modulate.a = clampf((_life - _age) / 0.5, 0.0, 1.0)
	if _age >= _life:
		queue_free()


func danger_at(point: Vector2) -> bool:
	return kind == "fire" and absf(point.x - global_position.x) < width * 0.5 + 8.0 and absf(point.y - global_position.y) < 30.0


func _draw() -> void:
	var fade := clampf((_life - _age) / 0.8, 0.0, 1.0)
	if kind == "frost":
		draw_texture_rect(ICE, Rect2(-width * 0.5, -8, width, 8), true, Color(1, 1, 1, 0.8 * fade))
		return
	# Scorched ground with a glow of embers under the flames.
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, width * 0.55, Color(0.1, 0.05, 0.03, 0.55 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Fx.draw_glow(self, Vector2(0, -3), width * 0.45, Color(1.0, 0.4, 0.1, 0.45 * fade))
