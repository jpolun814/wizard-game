class_name SpellSpawner
extends RefCounted

## Turns a spell that has been drawn and paid for into the thing it makes in the world. Every wizard's spells come through `spawn`, whoever plays them: the
## arena keeps the wizards, the ritual and the screen, and this keeps what each spell conjures and where it lands.

const ICICLE_REACH := 420.0  # a ceiling this far above a V can hang its icicle
const ICICLE_MAX := 240.0    # the longest an icicle grows
const STALAGMITE_MAX := 200.0  # and the tallest a stalagmite rises
const MUZZLE_OFFSET := 26.0  # spawn directional spells just outside the caster's body
const BARRIER_SECONDS := 6.0
const STEP_DAMAGE := 8
const RAISED_HEALTH := 50  # what a skeleton raised from the dead has, always

var _arena: Arena


func _init(arena: Arena) -> void:
	_arena = arena


func spawn(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, caster_node: Wizard) -> void:
	caster_node.casts_made += 1
	if caster_node.ledger != null:
		caster_node.ledger.mark_cast(spell)
	if caster_node == _arena.player and _arena.is_in_group(&"world"):
		Library.record_cast(spell, float(info.get("accuracy", 0.0)))  # only matches count, not the waiting room
		MatchStats.cast(spell, float(info.get("accuracy", 0.0)))
	var from: Vector2 = caster_node.center()
	if spell != "Sneak":
		caster_node.break_sneak()
	if spell != "Vacuum":
		Vacuum.release(_arena.get_tree(), caster_node)  # a caster who casts something else lets go of whoever they were smothering
	var school: String = SpellData.SPELLS[spell].school if SpellData.SPELLS.has(spell) else ""
	if SpellData.SPELLS.has(spell) and not SpellData.SPELLS[spell].pays_max():
		Leech.charge_target(_arena.get_tree(), caster_node, SpellData.SPELLS[spell].cost_for(info))  # the other end of a tether pays its half, on every machine
	if (school == "Water" or school == "Air") and spell != "Barrier":
		# Water and wind put a flare out, but only one the spell actually reaches.
		if targeting == "directional":
			Flare.snuff_along(_arena.get_tree(), origin, origin + Vector2.from_angle(aim) * maxf(info.get("length", 0.0), 60.0))  # only along the stroke itself
		else:
			Flare.snuff_near(_arena.get_tree(), origin, 30.0)  # only where the spell lands
	match spell:
		"Earthquake":
			var quake := Earthquake.new()
			quake.caster = caster_node
			_arena.add_child(quake)
			return
		"Featherfall":
			Featherfall.cast(caster_node)
			return
		"Rocket Jump":
			RocketJump.cast(caster_node)
			return
		"Flaming Sphere":
			var ball := FlamingSphere.new()
			ball.caster = caster_node
			ball.direction = 1.0 if cos(aim) >= 0.0 else -1.0
			ball.global_position = caster_node.center() + Vector2(ball.direction * 34.0, 8.0)
			_arena.add_child(ball)
			return
		"Mirage":
			Mirage.conjure(_arena, _arena.landing(origin))
			return
		"Raise Dead":
			_raise_dead(caster_node, _arena.landing(origin))
			return
		"Leech":
			var drained := Leech.pick(_arena.get_tree(), caster_node, aim)
			if drained != null:
				var tether := Leech.new()
				tether.caster = caster_node
				tether.target = drained
				_arena.add_child(tether)
			return
		"Barrier":
			# Barrier wraps the caster rather than appearing somewhere in the world.
			caster_node.raise_shield(BARRIER_SECONDS)
			return
		"Shadow Step":
			# A step zips the caster along the stroke, so it starts from the caster, not the stroke.
			_shadow_step(caster_node, aim, info.get("length", 0.0))
			return
		"Fire Breath":
			# The fire pours out of the caster, toward the cone's open end.
			var breath := FireBreath.new()
			breath.caster_node = caster_node
			breath.aim = aim
			breath.spread = info.get("spread", 0.8)
			breath.reach = info.get("reach", 160.0)
			_arena.add_child(breath)
			return
		"Black Hole":
			var hole := BlackHole.new()
			hole.position = origin
			_arena.add_child(hole)
			return
		"Flare":
			# The flare hovers by the caster and follows them wherever it was drawn.
			var flare := Flare.new()
			flare.caster_node = caster_node
			_arena.add_child(flare)
			return
		"Firewall":
			# A wall of flame along the second line of the stroke, a column every little way, each standing on the ground beneath it.
			var line: PackedVector2Array = info.get("line", PackedVector2Array())
			if line.size() < 3:
				return
			var x_from := line[1].x
			var x_to := line[2].x
			var columns := maxi(1, ceili(absf(x_to - x_from) / Firewall.SPACING))
			for i in columns:
				var column := Firewall.new()
				_arena.add_child(column)
				column.setup(spell, Vector2(lerpf(x_from, x_to, (i + 0.5) / columns), line[0].y), 0.0)
			return
		"Eldritch Blast":
			var blast := EldritchBlast.new()
			blast.caster_node = caster_node
			blast.aim = aim
			_arena.add_child(blast)
			return
		"Supernova":
			var sun := Supernova.new()
			sun.position = origin
			_arena.add_child(sun)
			return
		"Scythe":
			var swing := Scythe.new()
			swing.caster_node = caster_node
			_arena.add_child(swing)
			return
		"Hemorrhage":
			var cut := Hemorrhage.nearest_under(_arena.get_tree(), origin, info.get("extent", Vector2.ZERO))
			if cut == null:
				FloatText.spawn(_arena, origin + Vector2(0, -20), "Aim at someone", Color("#e0707f"), 0.9)
				return
			var wound := Hemorrhage.new()
			wound.target = cut
			wound.position = SpellTargets.center_of(cut)
			_arena.add_child(wound)
			return
		"Spore Puff":
			# The spores pour out of the caster, toward the cone's open end, like Fire Breath.
			var spores := SporePuff.new()
			spores.caster_node = caster_node
			spores.aim = aim
			spores.spread = info.get("spread", 0.8)
			spores.reach = info.get("reach", 160.0)
			_arena.add_child(spores)
			return
		"Flytrap":
			var trap := Flytrap.new()
			trap.position = origin
			_arena.add_child(trap)
			return
		"Eclipse":
			var eclipse := Eclipse.new()
			eclipse.position = origin
			_arena.add_child(eclipse)
			return
		"Decoy":
			var decoy := Decoy.new()
			decoy.position = _arena.ground_below(origin)
			decoy.mine = caster_node == _arena.player
			if caster_node is Wizard:
				decoy.caster = caster_node
				decoy.look = caster_node.look
				decoy.palette = caster_node.palette
			_arena.add_child(decoy)
			return
		"Glowcap":
			var cap := Glowcap.new()
			cap.caster_node = caster_node
			cap.position = _arena.ground_below(origin)
			_arena.add_child(cap)
			return
		"Moonbeam":
			var beam := Moonbeam.new()
			beam.position = _arena.ground_below(origin)
			_arena.add_child(beam)
			return
		"Tide Surf":
			var surf := TideSurf.new()
			surf.caster_node = caster_node
			surf.ground = _arena.terrain()
			surf.direction = 1.0 if cos(aim) >= 0.0 else -1.0
			_arena.add_child(surf)
			return
		"Sneak":
			caster_node.fade_from_sight(20.0)
			Fx.burst(_arena, caster_node.center(), SpellData.SCHOOL_COLORS["Shadow"], 14, 90.0, 0.5, true)
			return
		"Hunter's Mark":
			if caster_node != _arena.player:
				if caster_node.brain != null:
					caster_node.brain.catch_scent(HuntersMark.SECONDS)  # a brain has no arrow to follow: the scent shows it a wizard who has faded from sight
				return
			if HuntersMark.nearest_other(_arena.get_tree(), _arena.player.center(), _arena.player) == null:
				return
			for old in _arena.get_tree().get_nodes_in_group("hunts"):
				old.queue_free()
			var hunt := HuntersMark.new()
			hunt.caster = _arena.player
			_arena.add_child(hunt)
			Sfx.play("heartbeat", _arena.player.center(), -4.0)
			return
		"Obsidian Armor":
			caster_node.raise_obsidian(20.0)
			Fx.burst(_arena, caster_node.center(), Color(0.45, 0.4, 0.6), 16, 120.0, 0.5, true)
			Sfx.play("glass", caster_node.center())
			return
		"Wild Shape":
			caster_node.become_wild()
			return
		"Adrenaline":
			caster_node.grant_adrenaline(10.0)
			Fx.burst(_arena, caster_node.center(), SpellData.SCHOOL_COLORS["Blood"], 14, 150.0, 0.5, true)
			Sfx.play("heartbeat", caster_node.center())
			return
		"Crimson Veil":
			caster_node.veil = 2
			Fx.burst(_arena, caster_node.center(), SpellData.SCHOOL_COLORS["Blood"], 16, 120.0, 0.5, true)
			Sfx.play("blood_cast", caster_node.center(), -4.0)
			return
		"Faint":
			var down := blood_target(spell, origin)
			if down != null:
				down.faint()
				Fx.burst(_arena, SpellTargets.center_of(down), Color(0.55, 0.1, 0.2), 14, 100.0, 0.6, true)
				Sfx.play("faint", SpellTargets.center_of(down))
			return
		"Fight or Flight":
			var stirred := FightOrFlight.nearest_under(_arena.get_tree(), origin)
			if stirred == null:
				FloatText.spawn(_arena, origin + Vector2(0, -20), "Aim at someone", Color("#ff9a9a"), 0.9)
				return
			var stir := FightOrFlight.new()
			stir.target = stirred
			stir.caster = caster_node
			_arena.add_child(stir)
			return
		"Sinkhole":
			var hole := Sinkhole.new()
			var drawn: PackedVector2Array = info.get("line", PackedVector2Array())
			if drawn.size() > 1:  # the pit opens under the middle of the U, the shape of the line where it was drawn
				var ridges: MountainRidges = _arena.get_tree().get_first_node_in_group("ridges") as MountainRidges
				var fit := Sinkhole.fit(_arena.get_world_2d(), drawn, 17, ridges)
				hole.ridge = fit["ridge"]
				hole.half_width = fit["half_width"]
				hole.depth = fit["depth"]
				hole.profile = fit["profile"]
				hole.global_position = fit["spot"]
			else:
				hole.global_position = SpellTargets.surface_over(_arena.get_world_2d(), origin)
			hole.ground = _arena.terrain()
			_arena.add_child(hole)
			return
		"Silence":
			var silence := Silence.new()
			silence.global_position = origin
			_arena.add_child(silence)
			return
		"Updraft":
			var updraft := Updraft.new()
			updraft.global_position = origin
			_arena.add_child(updraft)
			return
		"Vacuum":
			var smothered := Vacuum.nearest_under(_arena.get_tree(), origin)
			if smothered == null:
				FloatText.spawn(_arena, origin + Vector2(0, -20), "Aim at someone", Color("#a8d8ff"), 0.9)
				return
			var vacuum := Vacuum.new()
			vacuum.target = smothered
			vacuum.caster = caster_node
			_arena.add_child(vacuum)
			return
		"Hex":
			var cursed := Hex.nearest_under(_arena.get_tree(), origin)
			if cursed == null:
				FloatText.spawn(_arena, origin + Vector2(0, -20), "Aim at someone", Color("#c8a8ff"), 0.9)
				return
			var hex := Hex.new()
			hex.target = cursed
			_arena.add_child(hex)
			return
	# Icicles, snowfall, tornados, volcanoes and the rest are placed where they were drawn, not at one point.
	if targeting == "shape":
		place_shapes(spell, info)
		return
	# Stone Wall rises from where the stroke began, on the ground. Other directional spells leave the caster
	# along the stroke; positional ones appear where drawn.
	if targeting == "directional" and spell != "Stone Wall":
		origin = from + Vector2.from_angle(aim) * MUZZLE_OFFSET
	if spell == "Stonefall":
		# A boulder falls onto the ground under the stroke and stays where it lands, as a loose rock.
		var boulder := Boulder.new()
		boulder.earth = _arena.earth_texture()
		boulder.global_position = _arena.drop_point(origin)
		_arena.add_child(boulder)
		return
	var effect := _new_effect(spell)
	effect.caster = caster_node
	if effect is PushZone:
		effect.zone_radius = info.get("radius", 0.0)
	elif effect is StoneWall:
		effect.wall_length = info.get("length", 0.0)
		effect.wall_texture = _arena.earth_texture()
	_arena.add_child(effect)
	effect.setup(spell, origin, aim)


## Whoever a blood spell is aimed at: the one nearest the stroke.
func blood_target(spell: String, origin: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := Hex.REACH
	for body in SpellTargets.all(_arena.get_tree()):
		var distance := SpellTargets.center_of(body).distance_to(origin)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


## A skeleton rises from the ground for a wizard. It is named after the wizard and the cast, which are the same on every machine, so the
## machines can tell each other about it; the machine that drives the wizard drives it, and the others only show it.
func _raise_dead(master: Wizard, feet: Vector2) -> void:
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


## A new effect of the kind a spell needs: the script its resource names.
func _new_effect(spell: String) -> SpellEffect:
	var path: String = SpellData.SPELLS[spell].effect_path
	if path == "":
		push_error("No spell effect for %s" % spell)
		return SpellEffect.new()
	return load(path).new()


## The last spot on the way from start to end where a body fits: feet, middle and head all clear of the ground. A step
## never ends inside rock, so it never leaves anyone stuck.
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


## Shadow Step: the caster slips along the stroke, stopping short of walls. Whoever is in the way takes damage, the
## caster aside.
func _shadow_step(caster_node: Wizard, aim: float, length: float) -> void:
	var dir := Vector2.from_angle(aim)
	var start: Vector2 = caster_node.global_position
	var end := start + dir * minf(length, SpellData.STEP_MAX)
	var query := PhysicsRayQueryParameters2D.create(start + Vector2(0, -20), end + Vector2(0, -20))
	query.collision_mask = 1
	var hit := _arena.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"] + Vector2(0, 20) - dir * 16.0
	end.x = clampf(end.x, ArenaGen.left_edge() + 14.0, ArenaGen.right_edge() - 14.0)
	end = _out_of_rock(start, end)
	for body in SpellTargets.all(_arena.get_tree()):
		if body == caster_node:
			continue
		var middle := SpellTargets.center_of(body)
		var closest := Geometry2D.get_closest_point_to_segment(middle, start + Vector2(0, -20), end + Vector2(0, -20))
		if closest.distance_to(middle) <= 24.0:
			SpellTargets.hurt(body, STEP_DAMAGE, "Shadow")
	var colour: Color = SpellData.SCHOOL_COLORS["Shadow"]
	Fx.pop(_arena, start + Vector2(0, -24), "twirl_02", colour, 60.0, 0.3, 0.3, 8.0)
	Fx.burst(_arena, start + Vector2(0, -24), colour, 12, 120.0, 0.25, true)
	caster_node.free_from_ground()  # a blink moves you out of the ground too
	caster_node.global_position = end
	caster_node.reset_physics_interpolation()
	caster_node.velocity = Vector2.ZERO
	Fx.pop(_arena, end + Vector2(0, -24), "twirl_02", colour, 24.0, 0.3, 2.4, -8.0)
	Fx.burst(_arena, end + Vector2(0, -24), colour, 12, 120.0, 0.25, true)
	Sfx.play("gravity", end, -2.0)  # a low whoosh like the other Shadow spells


## Where each drawn V can hang an icicle: from the ceiling straight above it. A V with no ceiling over it grows nothing.
## The icicle reaches down toward the V's tip, no longer than ICICLE_MAX.
func icicle_spots(info: Dictionary) -> Array:
	var spots := []
	for tri in info.get("shapes", []):
		# The ceiling is looked for upward from the V's tip, which hangs in the open: its top may already be in the rock when the V is drawn right up under a roof.
		var hit := {}
		for dip in [0.0, 24.0, 48.0, 72.0]:  # a tip drawn a little way into the rock hangs from the roof just above it
			var from := Vector2(tri[1].x, tri[1].y + dip)
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, -ICICLE_REACH - dip))
			query.collision_mask = 1
			hit = _arena.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit["normal"].y > 0.3:  # the underside of a roof, not a floor seen from inside the rock
				break
			hit = {}
		if hit.is_empty():
			continue
		var length := clampf(tri[1].y - hit["position"].y, 40.0, ICICLE_MAX)
		var width := clampf(absf(tri[2].x - tri[0].x), 14.0, length * 0.6)
		spots.append({"base": hit["position"] + Vector2(0.0, 6.0), "width": width, "length": length})
	return spots


## A stalagmite rises from the ground under the tip of each peak that was drawn, as tall as the peak was drawn, up to STALAGMITE_MAX.
func stalagmite_spots(info: Dictionary) -> Array:
	var spots := []
	for tri in info.get("shapes", []):
		var hit := {}
		for lift in [0.0, 24.0, 48.0, 72.0]:  # a tip drawn a little way into the ground rises from the surface above it
			var from := Vector2(tri[1].x, tri[1].y - lift)
			var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, ICICLE_REACH + lift))
			query.collision_mask = 1
			hit = _arena.get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit["normal"].y < -0.3:  # the top of the ground, not a ceiling
				break
			hit = {}
		if hit.is_empty():  # no ground within reach, but a ridge may stand there
			var on_ridge := _arena.on_ridge(tri[1], Vector2(tri[1].x, INF))
			if on_ridge.y < INF and on_ridge.y - tri[1].y < ICICLE_REACH:
				hit = {"position": on_ridge}
		if hit.is_empty():
			continue
		hit["position"] = _arena.on_ridge(tri[1], hit["position"])  # a peak drawn on a ridge rises from the ridge
		var height := clampf(hit["position"].y - tri[1].y, 40.0, STALAGMITE_MAX)
		var width := clampf(absf(tri[2].x - tri[0].x), 14.0, height * 0.6)
		spots.append({"base": hit["position"] + Vector2(0.0, 6.0), "width": width, "height": height})
	return spots


## The spells whose shape says where they go: icicles stand as the triangles they were drawn as, snow falls over
## the drawn line, a tornado or volcano forms under the middle of the drawing, a storm cloud hangs along its line,
## quicksand opens under the U, and an ice
## prison fills the drawn box.
func place_shapes(spell: String, info: Dictionary) -> void:
	var line: PackedVector2Array = info.get("line", PackedVector2Array())
	var centre := Vector2.ZERO
	for p in line:
		centre += p / line.size()
	match spell:
		"Icicles":
			for spot in icicle_spots(info):
				var half: float = spot["width"] * 0.5
				var icicle := Icicle.new()
				icicle.polygon = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(0.0, spot["length"])])
				_arena.add_child(icicle)
				icicle.setup(spell, spot["base"], 0.0)  # the base sits just inside the ceiling, hidden by it
		"Stalagmite":
			for spot in stalagmite_spots(info):
				var spike := Stalagmite.new()
				var half: float = spot["width"] * 0.5
				spike.polygon = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(0.0, -spot["height"])])
				spike.rock = _arena.earth_texture()
				_arena.add_child(spike)
				spike.setup(spell, spot["base"], 0.0)
		"Tornado":
			var tornado := Tornado.new()
			tornado.position = centre
			_arena.add_child(tornado)
		"Blizzard":
			var left := line[0].x
			var right := line[0].x
			for p in line:
				left = minf(left, p.x)
				right = maxf(right, p.x)
			var snow := Blizzard.new()
			snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(right - left, -60), Vector2(right - left, 60), Vector2(0, 60)])
			_arena.add_child(snow)
			snow.setup(spell, Vector2(left, centre.y), 0.0)
		"Smoke Screen":
			var smoke := SmokeScreen.new()
			smoke.line = line
			_arena.add_child(smoke)
		"Frost Bridge":
			var bridge := FrostBridge.new()
			bridge.line = line
			_arena.add_child(bridge)
		"Geyser":
			var geyser := Geyser.new()
			geyser.position = _arena.landing(centre)  # under the middle of the peak, on the surface
			geyser.ground = _arena.terrain()
			_arena.add_child(geyser)
		"Bramble":
			var thorns := Bramble.new()
			thorns.line = line
			_arena.add_child(thorns)
		"Liana":
			var vine := Liana.new()
			vine.line = line
			_arena.add_child(vine)
		"Great Oak":
			var oak := GreatOak.new()
			oak.position = _arena.landing(line[0])  # the trunk's foot
			_arena.add_child(oak)
		"Lily Pads":
			var pads := LilyPads.new()
			pads.line = line
			_arena.add_child(pads)
		"Mudslide":
			var sand := Mudslide.new()
			sand.width = SpellData.width_of(line)
			sand.position = centre
			_arena.add_child(sand)
		"Hailstorm":
			var hail := Hailstorm.new()
			hail.line = line
			_arena.add_child(hail)
			hail.setup(spell, centre, 0.0)
		"Ice Prison":
			var prison := IcePrison.new()
			prison.rect = info["rect"]
			_arena.add_child(prison)
