class_name HealingSpring
extends Node2D

## Healing Spring: clear water wells up out of the ground into a basin, and stays for the rest of the world. Anyone who stands in it mends a little at a time
## (through the same allowance as every other heal over time: `Mending.pour`), the caster's rivals as readily as the caster. A wizard has one spring at a
## time: a new one takes the place of the old. It is water, so the world's laws treat it as water (the group "waters": whoever stands in it is wet, and a flame
## in it goes out), and it asks for ground to well up from.

const GIVES := 2.0         # maximum stamina a second, to each wizard standing in it
const HALF_WIDTH := 34.0   # how far from its middle someone still stands in it
const REACH := 46.0        # how far over the ground the water is felt
const SPRAY := 64.0        # how high the water plays: whoever stands in the basin is wet to here
const ART := "res://art/props/healing_spring.png"

var caster: Wizard  # set by the arena before it enters the tree
var _picture: Texture2D
var _spray: CPUParticles2D
var _age := 0.0


## Where the spring lies, and the wizards who may stand in it: for the caster's wells and for the tests.
static func of(tree: SceneTree, wizard: Wizard) -> HealingSpring:
	for spring: HealingSpring in tree.get_nodes_in_group("springs"):
		if is_instance_valid(spring) and spring.caster == wizard and not spring.is_queued_for_deletion():
			return spring
	return null


func _ready() -> void:
	add_to_group("lasting")
	add_to_group("springs")
	add_to_group("waters")
	z_index = 1
	for old: HealingSpring in get_tree().get_nodes_in_group("springs"):
		if old != self and is_instance_valid(old) and old.caster == caster and not old.is_queued_for_deletion():
			old.queue_free()  # one spring to a wizard
	_picture = load(ART)
	_spray = CPUParticles2D.new()
	_spray.texture = Fx.pixel_drop()
	_spray.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spray.position = Vector2(0.0, -14.0)
	_spray.amount = 14
	_spray.lifetime = 0.9
	_spray.direction = Vector2.UP
	_spray.spread = 18.0
	_spray.initial_velocity_min = 60.0
	_spray.initial_velocity_max = 110.0
	_spray.gravity = Vector2(0.0, 260.0)
	_spray.color = Color(0.82, 0.95, 1.0, 0.9)
	add_child(_spray)
	Sfx.cue("Healing Spring", "mend", global_position, -4.0)


func _physics_process(delta: float) -> void:
	_age += delta
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if is_instance_valid(wizard) and not wizard.dead and standing_in(wizard.global_position):
			wizard.mending.pour(GIVES * delta)
	queue_redraw()


## True when a point at someone's feet is in the spring.
func standing_in(feet: Vector2) -> bool:
	return absf(feet.x - global_position.x) <= HALF_WIDTH and feet.y <= global_position.y + 6.0 and feet.y >= global_position.y - REACH


## The water is wet where the basin and its spray are (the law of waters: `Elements`): a wizard standing in it is wet to the head.
func wets(point: Vector2) -> bool:
	return absf(point.x - global_position.x) <= HALF_WIDTH and point.y >= global_position.y - SPRAY and point.y <= global_position.y + 4.0


func _draw() -> void:
	if _picture == null:
		return
	var size := _picture.get_size()
	var rise := minf(_age / 0.6, 1.0)  # the water wells up at first
	draw_texture_rect(_picture, Rect2(Vector2(-size.x * 0.5, -size.y) + Vector2(0.0, (1.0 - rise) * 6.0), size), false, Color(1, 1, 1, rise))


func danger_at(_point: Vector2) -> bool:
	return false
