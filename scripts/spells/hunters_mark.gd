class_name HuntersMark
extends Node

## Hunter's Mark: the scent of the nearest other wizard. An arrow at the edge of the screen points to them (see EdgeArrows, which looks for
## everything in the "hunts" group) while the scent lasts, and follows whoever is nearest as they move. Only the one who cast it sees it.

const SECONDS := 20.0

var caster: Wizard
var target: Wizard  # whoever is nearest now
var _age := 0.0


## The nearest living wizard to a point, other than the one given, or null when nobody else is left.
static func nearest_other(tree: SceneTree, point: Vector2, not_this: Wizard) -> Wizard:
	var in_sight := SpellTargets.wizards(tree).filter(func(wizard: Wizard) -> bool: return wizard != not_this and wizard.is_seen_from(point))
	return SpellTargets.nearest_to(in_sight, point) as Wizard


func _ready() -> void:
	add_to_group("hunts")
	_follow()


func _process(delta: float) -> void:
	_age += delta
	_follow()
	if _age >= SECONDS or not is_instance_valid(caster) or caster.dead:
		queue_free()


func _follow() -> void:
	target = nearest_other(get_tree(), caster.center(), caster) if is_instance_valid(caster) else null
