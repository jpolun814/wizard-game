class_name Bleed
extends Node2D

## Bleed: a wound that costs whoever has it stamina, a little at a time. It takes only the stamina they have now, never the most
## they can have. Someone with no stamina to lose (a plain enemy) loses health instead. Fire seals the wound, and cold slows it,
## and a Clot closes it. A body has one wound at a time: a new one only lengthens the old.

const SECONDS := 8.0
const RATE := 8.0        # stamina lost each second
const HEALTH_RATE := 2.0 # health a plain enemy loses each second
const DROP_EVERY := 0.35

var target: Node2D  # set by the arena before it enters the tree
var _age := 0.0
var _owed := 0.0     # a fraction of a point of health, until it adds up to one
var _drop := 0.0


## Opens a wound on a body, or lengthens the one it has.
static func open(parent: Node, body: Node2D) -> void:
	var old := of(parent.get_tree(), body)
	if old != null:
		old._age = 0.0
		return
	var wound := Bleed.new()
	wound.target = body
	parent.add_child(wound)


## The wound a body has, or null.
static func of(tree: SceneTree, body: Node) -> Bleed:
	for wound: Bleed in tree.get_nodes_in_group("bleeds"):
		if wound.target == body:
			return wound
	return null


## Closes the wounds of everyone within a radius of a point. Returns how many were closed.
static func close_near(tree: SceneTree, point: Vector2, radius: float) -> int:
	var closed := 0
	for wound: Bleed in tree.get_nodes_in_group("bleeds"):
		if is_instance_valid(wound.target) and SpellTargets.center_of(wound.target).distance_to(point) <= radius:
			wound.seal()
			closed += 1
	return closed


func _ready() -> void:
	add_to_group("bleeds")
	add_to_group("lasting")
	z_index = 9


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead()) or ("dead" in target and target.dead):
		queue_free()
		return
	_age += delta
	var centre := SpellTargets.center_of(target)
	var box := Rect2(centre - Vector2(14, 30), Vector2(28, 60))
	if SpellTargets.fire_touching(get_tree(), box):
		seal(true)  # fire cauterizes
		return
	var slowed: bool = (target.has_method("is_frozen") and target.is_frozen()) or (target.has_method("is_slowed") and target.is_slowed()) or ("slow_time" in target and target.slow_time > 0.0)
	var pace := 0.5 if slowed else 1.0  # cold keeps the blood in
	if "stamina" in target and (target.is_in_group("player") or target.KINDS[target.kind].role == "wizard"):
		if target.is_in_group("player"):
			target.drain(RATE * pace * delta)
		else:
			target.stamina = maxf(0.0, target.stamina - RATE * pace * delta)
	else:
		_owed += HEALTH_RATE * pace * delta
		if _owed >= 1.0:
			var whole := int(_owed)
			_owed -= whole
			target.take_damage(whole, "Blood", false)
	_drop -= delta
	if _drop <= 0.0:
		_drop = DROP_EVERY
		var drops := Fx.burst(get_parent(), centre + Vector2(randf_range(-8, 8), 6), Color("#c4162f"), 2, 40.0, 0.5, false, "circle_05")
		drops.gravity = Vector2(0, 600)
		drops.scale_amount_min = 3.0 / Fx.TEX_SIZE
		drops.scale_amount_max = 6.0 / Fx.TEX_SIZE
	if _age >= SECONDS:
		queue_free()


## Ends the wound. Fire leaves a puff of smoke.
func seal(burnt := false) -> void:
	if is_instance_valid(target):
		var at := SpellTargets.center_of(target)
		if burnt:
			Fx.smoke(get_parent(), at, Color(0.5, 0.45, 0.45, 0.5), 3, 16.0, 30.0)
			Sfx.play("fire_hit", at, -10.0)
		else:
			Fx.burst(get_parent(), at, Color("#f2c7c7"), 8, 70.0, 0.4, true)
	queue_free()
