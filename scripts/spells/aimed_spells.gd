class_name AimedSpells
extends RefCounted

## The spells cast at someone: a tether, a wound, a faint, a curse, the air drawn out of their lungs. Each finds who is under the stroke, and where there is no one
## the cast says so and makes nothing. Each is a small recipe that is given the cast (see SpellCast) and lists itself in `recipes`.

var _arena: Arena


func _init(arena: Arena) -> void:
	_arena = arena


func recipes() -> Dictionary:
	return {"Leech": _leech, "Hemorrhage": _hemorrhage, "Faint": _faint, "Fight or Flight": _fight_or_flight, "Vacuum": _vacuum, "Hex": _hex}


## Whoever a blood spell is aimed at: the one nearest the stroke.
static func blood_target(tree: SceneTree, origin: Vector2) -> Node2D:
	return SpellTargets.nearest_to(SpellTargets.all(tree), origin, Hex.REACH)


func _say_no_one(c: SpellCast, color: Color) -> void:
	FloatText.spawn(_arena, c.origin + Vector2(0, -20), "Aim at someone", color, 0.9)


func _leech(c: SpellCast) -> void:
	var drained := Leech.pick(_arena.get_tree(), c.caster, c.aim)
	if drained != null:
		var tether := Leech.new()
		tether.caster = c.caster
		tether.target = drained
		c.add(tether)


func _hemorrhage(c: SpellCast) -> void:
	var cut := Hemorrhage.nearest_under(_arena.get_tree(), c.origin, c.info.get("extent", Vector2.ZERO))
	if cut == null:
		_say_no_one(c, Color("#e0707f"))
		return
	var wound := Hemorrhage.new()
	wound.target = cut
	wound.position = SpellTargets.center_of(cut)
	c.add(wound)


func _faint(c: SpellCast) -> void:
	var down := blood_target(_arena.get_tree(), c.origin)
	if down != null:
		down.faint()
		Fx.burst(_arena, SpellTargets.center_of(down), Color(0.55, 0.1, 0.2), 14, 100.0, 0.6, true)
		Sfx.play("faint", SpellTargets.center_of(down))


func _fight_or_flight(c: SpellCast) -> void:
	var stirred := FightOrFlight.nearest_under(_arena.get_tree(), c.origin)
	if stirred == null:
		_say_no_one(c, Color("#ff9a9a"))
		return
	var stir := FightOrFlight.new()
	stir.target = stirred
	stir.caster = c.caster
	c.add(stir)


func _vacuum(c: SpellCast) -> void:
	var smothered := Vacuum.nearest_under(_arena.get_tree(), c.origin)
	if smothered == null:
		_say_no_one(c, Color("#a8d8ff"))
		return
	var vacuum := Vacuum.new()
	vacuum.target = smothered
	vacuum.caster = c.caster
	c.add(vacuum)


func _hex(c: SpellCast) -> void:
	var cursed := Hex.nearest_under(_arena.get_tree(), c.origin)
	if cursed == null:
		_say_no_one(c, Color("#c8a8ff"))
		return
	var hex := Hex.new()
	hex.target = cursed
	c.add(hex)
