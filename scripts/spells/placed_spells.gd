class_name PlacedSpells
extends RefCounted

## The spells that appear where the stroke was drawn, or on the ground under it: a star, a hole, a wall of flame, a boulder, a skeleton. Each is a small recipe that
## is given the cast (see SpellCast) and lists itself in `recipes`.

const RAISED_HEALTH := 50  # what a skeleton raised from the dead has, always

var _arena: Arena


func _init(arena: Arena) -> void:
	_arena = arena


func recipes() -> Dictionary:
	return {
		"Earthquake": _earthquake, "Mirage": _mirage, "Raise Dead": _raise_dead, "Black Hole": _black_hole, "Firewall": _firewall, "Supernova": _supernova,
		"Flytrap": _flytrap, "Eclipse": _eclipse, "Decoy": _decoy, "Glowcap": _glowcap, "Moonbeam": _moonbeam, "Sinkhole": _sinkhole, "Silence": _silence,
		"Updraft": _updraft, "Stonefall": _stonefall,
	}


func _earthquake(c: SpellCast) -> void:
	var quake := Earthquake.new()
	quake.caster = c.caster
	c.add(quake)


func _mirage(c: SpellCast) -> void:
	Mirage.conjure(_arena, _arena.landing(c.origin))


func _black_hole(c: SpellCast) -> void:
	var hole := BlackHole.new()
	hole.position = c.origin
	c.add(hole)


## A wall of flame along the second line of the stroke, a column every little way, each standing on the ground beneath it.
func _firewall(c: SpellCast) -> void:
	var line := c.line()
	if line.size() < 3:
		return
	var x_from := line[1].x
	var x_to := line[2].x
	var columns := maxi(1, ceili(absf(x_to - x_from) / Firewall.SPACING))
	for i in columns:
		var column := Firewall.new()
		c.add(column)
		column.setup(c.spell, Vector2(lerpf(x_from, x_to, (i + 0.5) / columns), line[0].y), 0.0)


func _supernova(c: SpellCast) -> void:
	var sun := Supernova.new()
	sun.position = c.origin
	c.add(sun)


func _flytrap(c: SpellCast) -> void:
	var trap := Flytrap.new()
	trap.position = c.origin
	c.add(trap)


func _eclipse(c: SpellCast) -> void:
	var eclipse := Eclipse.new()
	eclipse.position = c.origin
	c.add(eclipse)


func _decoy(c: SpellCast) -> void:
	var decoy := Decoy.new()
	decoy.position = _arena.ground_below(c.origin)
	decoy.mine = c.caster == _arena.player
	if c.caster is Wizard:
		decoy.caster = c.caster
		decoy.look = c.caster.look
		decoy.palette = c.caster.palette
	c.add(decoy)


func _glowcap(c: SpellCast) -> void:
	var cap := Glowcap.new()
	cap.caster = c.caster
	cap.position = _arena.ground_below(c.origin)
	c.add(cap)


func _moonbeam(c: SpellCast) -> void:
	var beam := Moonbeam.new()
	beam.position = _arena.ground_below(c.origin)
	c.add(beam)


func _silence(c: SpellCast) -> void:
	var silence := Silence.new()
	silence.global_position = c.origin
	c.add(silence)


func _updraft(c: SpellCast) -> void:
	var updraft := Updraft.new()
	updraft.global_position = c.origin
	c.add(updraft)


## The pit opens under the middle of the U, the shape of the line where it was drawn.
func _sinkhole(c: SpellCast) -> void:
	var hole := Sinkhole.new()
	var drawn := c.line()
	if drawn.size() > 1:
		var ridges: MountainRidges = _arena.get_tree().get_first_node_in_group("ridges") as MountainRidges
		var fit := Sinkhole.fit(_arena.get_world_2d(), drawn, 17, ridges)
		hole.ridge = fit["ridge"]
		hole.half_width = fit["half_width"]
		hole.depth = fit["depth"]
		hole.profile = fit["profile"]
		hole.global_position = fit["spot"]
	else:
		hole.global_position = SpellTargets.surface_over(_arena.get_world_2d(), c.origin)
	hole.ground = _arena.terrain()
	c.add(hole)


## A boulder falls from where the circle was drawn, onto the ground under it, and stays where it lands, as a loose rock. How hard it hits is how fast it falls.
func _stonefall(c: SpellCast) -> void:
	var boulder := Boulder.new()
	boulder.earth = _arena.earth_texture()
	boulder.global_position = _arena.lifted_out_of_rock(c.origin)
	c.add(boulder)


## A skeleton rises from the ground for a wizard. It is named after the wizard and the cast, which are the same on every machine, so the machines can tell each
## other about it; the machine that drives the wizard drives it, and the others only show it.
func _raise_dead(c: SpellCast) -> void:
	var master := c.caster
	var feet := _arena.landing(c.origin)
	var risen: Mob = Arena.MOB_SCENE.instantiate()
	risen.kind = "basic"
	risen.master = master
	risen.roams = true
	risen.puppet = master.is_likeness()
	risen.name = "Raised_%s_%d" % [master.name, master.casts_made]
	risen.position = feet
	risen.set_multiplayer_authority(master.get_multiplayer_authority())
	_arena.add_child(risen)
	risen.max_hp = RAISED_HEALTH
	risen.hp = RAISED_HEALTH
	Fx.burst(_arena, feet, SpellData.SCHOOL_COLORS["Blood"], 12, 110.0, 0.5, true)
	Sfx.play("summon", feet, -4.0)
