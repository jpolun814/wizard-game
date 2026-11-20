class_name SpellSpawner
extends RefCounted

## Turns a spell that has been drawn and paid for into the thing it makes in the world. Every wizard's spells come through `spawn`, whoever plays them: the
## arena keeps the wizards, the ritual and the screen, and this keeps what each spell conjures and where it lands.
##
## A spell has a recipe if its making is more than "a new effect of the kind its resource names": the recipes are in four tables, by what the spell does
## (at the caster, at someone, in a place, from a shape). The rest are simple effects (see SpellEffect), made the same way for each.


var shapes: ShapeSpells  # the spells whose shape says where they go (also asked where a V or a peak can stand)
var _arena: Arena
var _tables: Array[RefCounted] = []  # the four tables of recipes, kept so that what they hand out stays alive
var _recipes := {}  # spell name -> what makes it: a Callable that is given the cast


func _init(arena: Arena) -> void:
	_arena = arena
	shapes = ShapeSpells.new(arena)
	_tables = [CasterSpells.new(arena), AimedSpells.new(arena), PlacedSpells.new(arena), shapes]
	for table in _tables:
		_recipes.merge(table.recipes())


func spawn(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, caster_node: Wizard) -> void:
	var cast := SpellCast.new(_arena, spell, targeting, origin, aim, info, caster_node)
	_record(cast)
	_trace_from_staff(cast)
	if _recipes.has(spell):
		_recipes[spell].call(cast)
	else:
		_simple_effect(cast)


## What is written down about a cast, and what a cast does to others before its own work: nothing it makes is needed for these.
func _record(c: SpellCast) -> void:
	var caster := c.caster
	caster.casts_made += 1
	if caster.ledger != null:
		caster.ledger.mark_cast(c.spell)
	if caster == _arena.player and _arena.is_in_group(&"world"):
		Library.record_cast(c.spell, float(c.info.get("accuracy", 0.0)))  # only matches count, not the waiting room
		MatchStats.cast(c.spell, float(c.info.get("accuracy", 0.0)))
	if c.spell != "Sneak":
		caster.break_sneak()
	if c.spell != "Vacuum":
		Vacuum.release(_arena.get_tree(), caster)  # a caster who casts something else lets go of whoever they were smothering
	if SpellData.SPELLS.has(c.spell) and not SpellData.SPELLS[c.spell].pays_max():
		Leech.charge_target(_arena.get_tree(), caster, SpellData.SPELLS[c.spell].cost_for(c.info))  # the other end of a tether pays its half, on every machine


## A spell that appears somewhere else (a stone that rises, a storm that gathers) is sent there from the gem of the staff, in a streak of its school's color.
func _trace_from_staff(c: SpellCast) -> void:
	if c.targeting != "positional" and c.targeting != "shape" and c.targeting != "raised":
		return
	var to := c.center() if c.targeting == "shape" and not c.line().is_empty() else c.origin
	var school: String = SpellData.SPELLS[c.spell].school if SpellData.SPELLS.has(c.spell) else ""
	StaffTracer.launch(_arena, c.caster.launch_tip(), to, SpellData.SCHOOL_COLORS.get(school, Color(0.8, 0.8, 1.0)), c.caster)


## A spell with no recipe is the effect its resource names. A directional spell leaves the caster along the stroke (Stone Wall rises from where the stroke
## began, on the ground); a positional one appears where drawn.
func _simple_effect(c: SpellCast) -> void:
	if c.targeting == "shape":
		return  # a shape spell with no recipe makes nothing
	var origin := c.origin
	if c.is_directional() and c.targeting != "raised":
		origin = _muzzle(c)
	var effect := _new_effect(c.spell)
	effect.caster = c.caster
	if effect is PushZone:
		effect.zone_radius = c.info.get("radius", 0.0)
	elif effect is StoneWall:
		effect.wall_length = c.info.get("length", 0.0)
		effect.wall_texture = _arena.earth_texture()
	if effect is Projectile and c.caster is Wizard:
		effect.emerge_from = c.caster.launch_tip()  # it comes out of the gem of the staff (see Projectile._emerge)
	c.add(effect)
	effect.setup(c.spell, origin, c.aim)


## Where a shot starts: the gem of the staff, as it is thrust out. But with someone, or a wall, between the gem and the middle of the body (a rival at arm's
## length) the shot would start beyond them and fly on past, so it starts at the body's edge instead.
func _muzzle(c: SpellCast) -> Vector2:
	var body := c.caster.center()
	var gem := c.caster.launch_tip() + Vector2.from_angle(c.aim) * 8.0
	var edge := body + Vector2.from_angle(c.aim) * 26.0
	var query := PhysicsRayQueryParameters2D.create(body, gem)
	query.collision_mask = 1
	if not c.caster.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		return edge
	for other in SpellTargets.all(_arena.get_tree()):
		if other != c.caster and Geometry2D.get_closest_point_to_segment(SpellTargets.center_of(other), body, gem).distance_to(SpellTargets.center_of(other)) < 28.0:
			return edge
	return gem


## A new effect of the kind a spell needs: the script its resource names.
func _new_effect(spell: String) -> SpellEffect:
	var path: String = SpellData.SPELLS[spell].effect_path
	if path == "":
		push_error("No spell effect for %s" % spell)
		return SpellEffect.new()
	return load(path).new()
