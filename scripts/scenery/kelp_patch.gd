class_name KelpPatch
extends Node2D

## A stand of kelp on the sea floor (chapter 20): single strands, drawn in front of whoever is among them, with gaps between so that a person can still see
## their own wizard. The drawing is all there is to the hiding for a person; for a brain's eyes the patch is a sight blocker (see `blocks`), which
## does the same for them: a wizard in the kelp is not made out from far off. It slows whoever wades through it, as the Mudslide does.
## The strands are the jungle's hanging vine turned the right way up and dyed; the world's own colors do the rest.

const VINE := preload("res://art/props/jungle_vine.png")
const SIZE := 2                # whole-number scales only: a strand is this many times the picture
const SEEN_FROM := 260.0       # a wizard among the kelp is made out from this far, and not from further
const SLOW_FOR := 0.35         # seconds of slowness each check gives
const TINT := Color(0.16, 0.42, 0.36, 0.92)

var bases: Array[Vector2] = []  # where each strand stands: the world position of its foot (set before it enters the tree)
var seed_value := 0
var _area := Rect2()
var _strands: Array[Sprite2D] = []
var _phases := PackedFloat32Array()  # where each strand is in its sway, so that no two sway together
var _t := 0.0
var _check := 0.0


func _ready() -> void:
	z_index = 2  # in front of the wizards, behind the pages
	add_to_group("sight_blockers")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tall := float(VINE.get_height() * SIZE)
	_area = Rect2(bases[0].x, bases[0].y - tall, 0.0, tall)
	for base in bases:
		var strand := Sprite2D.new()
		strand.texture = VINE
		strand.flip_v = true  # the vine hangs; kelp stands
		strand.centered = false
		strand.offset = Vector2(-VINE.get_width() * 0.5, -VINE.get_height())
		strand.scale = Vector2(SIZE, SIZE)
		strand.position = base - global_position
		strand.modulate = TINT.lerp(Color(0.08, 0.3, 0.3, 0.92), rng.randf())
		_phases.append(rng.randf() * TAU)
		add_child(strand)
		_strands.append(strand)
		_area = _area.expand(Vector2(base.x - 24.0, base.y - tall)).expand(Vector2(base.x + 24.0, base.y))


func _process(delta: float) -> void:
	_t += delta
	for i in _strands.size():
		_strands[i].rotation = sin(_t * 1.1 + _phases[i]) * 0.07  # (it sways from its foot)


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.2
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if not wizard.dead and _area.has_point(wizard.center()):
			wizard.apply_debuff("slow", SLOW_FOR)


## The room the patch takes up, in the world.
func area() -> Rect2:
	return _area


## True when a sight line from one point to another is cut by the patch: one of its ends is among the strands and they are far apart.
func blocks(from: Vector2, to: Vector2) -> bool:
	if from.distance_to(to) <= SEEN_FROM:
		return false
	return _area.has_point(from) or _area.has_point(to)


