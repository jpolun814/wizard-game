class_name CasterSpells
extends RefCounted

## The spells that work on the caster or pour out of them: a shield, a fall made slow, a step along the stroke, a breath of fire, a blade, a change of shape.
## Each is a small recipe that is given the cast (see SpellCast) and lists itself in `recipes`.

const BARRIER_SECONDS := 6.0
const STEP_DAMAGE := 8

var _arena: Arena


func _init(arena: Arena) -> void:
	_arena = arena


func recipes() -> Dictionary:
	return {
		"Featherfall": _featherfall, "Rocket Jump": _rocket_jump, "Flaming Sphere": _flaming_sphere, "Barrier": _barrier, "Shadow Step": _shadow_step,
		"Fire Breath": _fire_breath, "Spore Puff": _spore_puff, "Flare": _flare, "Eldritch Blast": _eldritch_blast, "Scythe": _scythe, "Tide Surf": _tide_surf,
		"Sneak": _sneak, "Obsidian Armor": _obsidian_armor, "Wild Shape": _wild_shape, "Adrenaline": _adrenaline, "Crimson Veil": _crimson_veil,
		"Hunter's Mark": _hunters_mark,
	}


func _featherfall(c: SpellCast) -> void:
	Featherfall.cast(c.caster)


func _rocket_jump(c: SpellCast) -> void:
	RocketJump.cast(c.caster)


func _flaming_sphere(c: SpellCast) -> void:
	var ball := FlamingSphere.new()
	ball.caster = c.caster
	ball.direction = c.side()
	ball.global_position = c.caster.center() + Vector2(ball.direction * 34.0, 8.0)
	c.add(ball)


## Barrier wraps the caster rather than appearing somewhere in the world.
func _barrier(c: SpellCast) -> void:
	c.caster.raise_shield(BARRIER_SECONDS)


## The fire pours out of the caster, toward the cone's open end.
func _fire_breath(c: SpellCast) -> void:
	var breath := FireBreath.new()
	breath.caster = c.caster
	breath.aim = c.aim
	breath.spread = c.info.get("spread", 0.8)
	breath.reach = c.info.get("reach", 160.0)
	c.add(breath)


## The spores pour out of the caster, toward the cone's open end, like Fire Breath.
func _spore_puff(c: SpellCast) -> void:
	var spores := SporePuff.new()
	spores.caster = c.caster
	spores.aim = c.aim
	spores.spread = c.info.get("spread", 0.8)
	spores.reach = c.info.get("reach", 160.0)
	c.add(spores)


## The flare hovers by the caster and follows them wherever it was drawn.
func _flare(c: SpellCast) -> void:
	var flare := Flare.new()
	flare.caster = c.caster
	c.add(flare)


func _eldritch_blast(c: SpellCast) -> void:
	var blast := EldritchBlast.new()
	blast.caster = c.caster
	blast.aim = c.aim
	c.add(blast)


func _scythe(c: SpellCast) -> void:
	var swing := Scythe.new()
	swing.caster = c.caster
	c.add(swing)


func _tide_surf(c: SpellCast) -> void:
	var surf := TideSurf.new()
	surf.caster = c.caster
	surf.ground = _arena.terrain()
	surf.direction = c.side()
	c.add(surf)


func _sneak(c: SpellCast) -> void:
	c.caster.fade_from_sight(20.0)
	Fx.burst(_arena, c.caster.center(), SpellData.SCHOOL_COLORS["Shadow"], 14, 90.0, 0.5, true)


func _obsidian_armor(c: SpellCast) -> void:
	c.caster.raise_obsidian(20.0)
	Fx.burst(_arena, c.caster.center(), Color(0.45, 0.4, 0.6), 16, 120.0, 0.5, true)
	Sfx.play("glass", c.caster.center())


func _wild_shape(c: SpellCast) -> void:
	c.caster.wolf.begin()


func _adrenaline(c: SpellCast) -> void:
	c.caster.grant_adrenaline(10.0)
	Fx.burst(_arena, c.caster.center(), SpellData.SCHOOL_COLORS["Blood"], 14, 150.0, 0.5, true)
	Sfx.play("heartbeat", c.caster.center())


func _crimson_veil(c: SpellCast) -> void:
	c.caster.veil = 2
	Fx.burst(_arena, c.caster.center(), SpellData.SCHOOL_COLORS["Blood"], 16, 120.0, 0.5, true)
	Sfx.play("blood_cast", c.caster.center(), -4.0)


func _hunters_mark(c: SpellCast) -> void:
	if c.caster != _arena.player:
		if c.caster.brain != null:
			c.caster.brain.catch_scent(HuntersMark.SECONDS)  # a brain has no arrow to follow: the scent shows it a wizard who has faded from sight
		return
	if HuntersMark.nearest_other(_arena.get_tree(), _arena.player.center(), _arena.player) == null:
		return
	for old in _arena.get_tree().get_nodes_in_group("hunts"):
		old.queue_free()
	var hunt := HuntersMark.new()
	hunt.caster = _arena.player
	c.add(hunt)
	Sfx.play("heartbeat", _arena.player.center(), -4.0)


## Shadow Step: the caster slips along the stroke, stopping short of walls, so it starts from the caster, not the stroke. Whoever is in the way takes damage,
## the caster aside.
func _shadow_step(c: SpellCast) -> void:
	var caster := c.caster
	var dir := Vector2.from_angle(c.aim)
	var start: Vector2 = caster.global_position
	var end := start + dir * minf(float(c.info.get("length", 0.0)), SpellData.STEP_MAX)
	var query := PhysicsRayQueryParameters2D.create(start + Vector2(0, -20), end + Vector2(0, -20))
	query.collision_mask = 1
	var hit := _arena.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"] + Vector2(0, 20) - dir * 16.0
	end.x = clampf(end.x, ArenaGen.left_edge() + 14.0, ArenaGen.right_edge() - 14.0)
	end = _out_of_rock(start, end)
	for body in SpellTargets.all(_arena.get_tree()):
		if body == caster:
			continue
		var middle := SpellTargets.center_of(body)
		var closest := Geometry2D.get_closest_point_to_segment(middle, start + Vector2(0, -20), end + Vector2(0, -20))
		if closest.distance_to(middle) <= 24.0:
			SpellTargets.hurt(body, STEP_DAMAGE, "Shadow")
	var color: Color = SpellData.SCHOOL_COLORS["Shadow"]
	Fx.pop(_arena, start + Vector2(0, -24), "twirl_02", color, 60.0, 0.3, 0.3, 8.0)
	Fx.burst(_arena, start + Vector2(0, -24), color, 12, 120.0, 0.25, true)
	caster.free_from_ground()  # a blink moves you out of the ground too
	caster.global_position = end
	caster.reset_physics_interpolation()
	caster.velocity = Vector2.ZERO
	Fx.pop(_arena, end + Vector2(0, -24), "twirl_02", color, 24.0, 0.3, 2.4, -8.0)
	Fx.burst(_arena, end + Vector2(0, -24), color, 12, 120.0, 0.25, true)
	Sfx.play("gravity", end, -2.0)  # a low whoosh like the other Shadow spells


## The last spot on the way from start to end where a body fits: feet, middle and head all clear of the ground. A step never ends inside rock, so it never
## leaves anyone stuck.
func _out_of_rock(start: Vector2, end: Vector2) -> Vector2:
	var steps := maxi(1, int(start.distance_to(end) / 8.0))
	for i in range(steps, -1, -1):
		var at := start.lerp(end, float(i) / steps)
		var free := true
		for lift in [-4.0, -36.0, -70.0]:
			var probe := PhysicsPointQueryParameters2D.new()
			probe.position = at + Vector2(0.0, lift)
			probe.collision_mask = 1
			if not _arena.get_world_2d().direct_space_state.intersect_point(probe, 1).is_empty():
				free = false
				break
		if free:
			return at
	return start
