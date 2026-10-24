class_name Hex
extends Node2D

## Hex: a pentagram drawn over someone. They are cursed for a while, and take half again as much damage from everything.
## It marks whoever is under the star, friend or foe: no spell has a side.

const SECONDS := 8.0
const BONUS := 1.5
const REACH := 70.0  # how close to the star's middle someone must be to be marked

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


## A glowing pentagram, a violet star with a bright centre.
func _draw() -> void:
	var glow := Color(0.65, 0.4, 1.0)
	Fx.draw_glow(self, Vector2.ZERO, 24.0, Color(glow.r, glow.g, glow.b, 0.5))
	var star := PackedVector2Array()
	for step in 6:
		star.append(Vector2.from_angle(-PI / 2.0 + TAU * ((step * 2) % 5) / 5.0) * 12.0)
	draw_polyline(star, Color(0.9, 0.8, 1.0), 1.5)
	draw_circle(Vector2.ZERO, 2.0, Color(0.95, 0.85, 1.0))
