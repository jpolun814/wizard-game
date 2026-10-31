class_name Vacuum
extends Node2D

## Vacuum: the air is drawn out of someone's lungs, drawn over them. They hold their breath, so they cannot chant, and the few seconds of air they
## have run down; when it is gone they suffocate. It lets go when the caster casts anything else or is hurt. A glassy bubble closes round the head, and the breath meter shows over it.
## Like every spell it has no side: whoever is under the sign is smothered, the caster too if they drew it over themselves.

const REACH := 90.0   # how close to the middle of the sign someone must be to be caught
const LONGEST := 14.0 # seconds it can last at most, in case word of the caster being hurt never comes

var target: Wizard  # set by the arena, which finds who is under the sign
var caster: Wizard
var _age := 0.0
var _bubble: Sprite2D


## Whoever is closest to a point, if they are near enough to be under the sign. Only wizards breathe.
static func nearest_under(tree: SceneTree, point: Vector2) -> Wizard:
	var best: Wizard = null
	var best_distance := REACH
	for wizard: Wizard in SpellTargets.wizards(tree):
		var distance := wizard.center().distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = wizard
	return best


## Lets go of everyone this wizard has smothered: they have cast something else.
static func release(tree: SceneTree, by: Wizard) -> void:
	for vacuum: Vacuum in tree.get_nodes_in_group("vacuums"):
		if vacuum.caster == by:
			vacuum.queue_free()


func _ready() -> void:
	add_to_group("vacuums")
	z_index = 9
	target.smother(true)
	if caster != null:
		caster.damaged.connect(_on_caster_hurt)
	_bubble = Sprite2D.new()
	_bubble.texture = Fx.tex("circle_01")
	_bubble.scale = Vector2.ONE * (56.0 / Fx.TEX_SIZE)
	_bubble.modulate = Color(0.75, 0.92, 1.0, 0.9)
	add_child(_bubble)
	Sfx.play("gravity", global_position, -8.0)


func _on_caster_hurt(_amount: int) -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(target) or target.dead or _age >= LONGEST:
		queue_free()
		return
	global_position = target.center() + Vector2(0.0, -20.0)
	_bubble.scale = Vector2.ONE * ((54.0 + sin(_age * 7.0) * 3.0) / Fx.TEX_SIZE)  # the bubble draws in and out with the failing breath


func _exit_tree() -> void:
	if is_instance_valid(target):
		target.smother(false)
