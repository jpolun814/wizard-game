class_name Hex
extends Node2D

## Hex: a pentagram drawn over someone. They are cursed for a while, and take half again as much damage from everything.
## It marks whoever is under the star, friend or foe: no spell has a side.

const SECONDS := 30.0
const BONUS := 1.5
const REACH := 70.0  # how close to the star's middle someone must be to be marked

const MARK := preload("res://art/fx/hex_mark.png")  # a pentagram in pixels, made for the game (tools/make_marks.py)

var target: Node2D  # set by the arena, which finds who is under the star
var _age := 0.0


## The extra damage a body takes from being hexed: 1 if it is not.
static func multiplier(tree: SceneTree, body: Node) -> float:
	for hex in tree.get_nodes_in_group("hexes"):
		if hex.target == body:
			return BONUS
	return 1.0


## Whoever is closest to a point, if they are near enough to be under the star.
static func nearest_under(tree: SceneTree, point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := REACH
	for body in SpellTargets.all(tree):
		var distance := SpellTargets.center_of(body).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


func _ready() -> void:
	add_to_group("hexes")
	add_to_group("lasting")
	z_index = 9
	var mark := Sprite2D.new()
	mark.texture = MARK
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.scale = Vector2(2.0, 2.0)
	add_child(mark)
	Sfx.play("gravity", global_position, -6.0)
	Fx.burst(get_parent(), global_position, Color("#a070e0"), 12, 100.0, 0.5, true)


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(target) or _age >= SECONDS or (target.has_method("is_dead") and target.is_dead()) or ("dead" in target and target.dead):
		queue_free()
		return
	# The mark floats above the head, bobbing, and blinks out over its last moments.
	global_position = SpellTargets.center_of(target) + Vector2(0, -52.0 + sin(_age * 3.0) * 3.0)
	modulate.a = clampf((SECONDS - _age) / 1.0, 0.0, 1.0)
	queue_redraw()


## The violet glow behind the star.
func _draw() -> void:
	var glow := Color(0.65, 0.4, 1.0)
	Fx.draw_glow(self, Vector2.ZERO, 24.0, Color(glow.r, glow.g, glow.b, 0.5))
