class_name SpellCast
extends RefCounted

## One cast, as it reaches the world: which spell, where it was drawn, which way it points, what the stroke measured and who cast it. Every spell's recipe
## (see SpellSpawner) is given one of these.

var arena: Arena
var spell: String
var targeting: String
var origin: Vector2
var aim: float
var info: Dictionary
var caster: Wizard


func _init(in_arena: Arena, spell_name: String, how_aimed: String, where: Vector2, angle: float, measured: Dictionary, by: Wizard) -> void:
	arena = in_arena
	spell = spell_name
	targeting = how_aimed
	origin = where
	aim = angle
	info = measured
	caster = by


## Whether it leaves the caster along the stroke (see Spell.DIRECTIONAL).
func is_directional() -> bool:
	return Spell.DIRECTIONAL.has(targeting)


## The line that was drawn, for the spells that follow it.
func line() -> PackedVector2Array:
	return info.get("line", PackedVector2Array())


## The middle of the line that was drawn.
func center() -> Vector2:
	var points := line()
	var out := Vector2.ZERO
	for p in points:
		out += p / points.size()
	return out


## Which way along the ground the stroke points: 1 for right, -1 for left.
func side() -> float:
	return 1.0 if cos(aim) >= 0.0 else -1.0


## Puts what the spell made into the world.
func add(node: Node) -> void:
	arena.add_child(node)
