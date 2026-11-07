class_name Hemorrhage
extends Node2D

## Hemorrhage: a crescent drawn like a cut, over someone. The wound will not close: it bleeds for a while, a little at a time. It cuts whoever is nearest to the
## stroke, whether friend or foe: no spell has a side.

const SECONDS := 8.0
const TICK := 1.0
const HARM := 3
const REACH := 80.0

var target: Node2D  # set by the arena, which finds who was cut
var _age := 0.0
var _clock := 0.0
var _drip: CPUParticles2D


## Whoever is closest to a point, if they are near enough to be under the cut.
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
	add_to_group("lasting")
	z_index = 9
	_drip = Fx.trail(Color("#c4162f"), 22, 0.8, 24.0, Vector2(0, 360), "circle_05", 11.0)
	_drip.material = null
	add_child(_drip)
	Sfx.play("blood_cast", global_position, -4.0)
	Fx.pop(get_parent(), global_position, "slash_01", Color("#c4162f"), 90.0, 0.35, 1.3, 0.0, false)  # the cut
	Fx.burst(get_parent(), global_position, Color("#c4162f"), 16, 130.0, 0.5, false)


func _physics_process(delta: float) -> void:
	_age += delta
	if not SpellTargets.affects(target) or _age >= SECONDS:
		queue_free()
		return
	global_position = SpellTargets.center_of(target) + Vector2(0, 8)
	_clock -= delta
	if _clock <= 0.0:
		_clock = TICK
		SpellTargets.hurt(target, HARM, "Blood", false, false, self)
		Fx.burst(get_parent(), global_position, Color("#c4162f"), 9, 90.0, 0.5, false)
