class_name ShapeSpells
extends RefCounted

## The spells whose shape says where they go: icicles stand as the triangles they were drawn as, snow falls over the drawn line, a tornado forms under the middle
## of the drawing, a storm cloud hangs along its line, and an ice prison fills the drawn box. Each is a small recipe that is given the cast (see SpellCast) and
## lists itself in `recipes`.

const ICICLE_REACH := 420.0  # a ceiling this far above a V can hang its icicle
const ICICLE_MAX := 240.0  # the longest an icicle grows
const STALAGMITE_MAX := 200.0  # and the tallest a stalagmite rises

var _arena: Arena


func _init(arena: Arena) -> void:
	_arena = arena


func recipes() -> Dictionary:
	return {
		"Icicles": _icicles, "Stalagmite": _stalagmites, "Tornado": _tornado, "Blizzard": _blizzard, "Smoke Screen": _smoke_screen, "Frost Bridge": _frost_bridge,
		"Geyser": _geyser, "Bramble": _bramble, "Liana": _liana, "Great Oak": _great_oak, "Lily Pads": _lily_pads, "Mudslide": _mudslide, "Hailstorm": _hailstorm,
		"Ice Prison": _ice_prison,
	}


## Places a shape spell by name, as the arena does when it is cast (and as a check does, to put one where it wants).
func place(spell: String, info: Dictionary) -> void:
	if recipes().has(spell):
		recipes()[spell].call(SpellCast.new(_arena, spell, "shape", Vector2.ZERO, 0.0, info, null))


func _icicles(c: SpellCast) -> void:
	for spot in icicle_spots(c.info):
		var half: float = spot["width"] * 0.5
		var icicle := Icicle.new()
		icicle.polygon = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(0.0, spot["length"])])
		c.add(icicle)
		icicle.setup(c.spell, spot["base"], 0.0)  # the base sits just inside the ceiling, hidden by it


func _stalagmites(c: SpellCast) -> void:
	for spot in stalagmite_spots(c.info):
		var spike := Stalagmite.new()
		var half: float = spot["width"] * 0.5
		spike.polygon = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(0.0, -spot["height"])])
		spike.rock = _arena.earth_texture()
		c.add(spike)
		spike.setup(c.spell, spot["base"], 0.0)


func _tornado(c: SpellCast) -> void:
	var tornado := Tornado.new()
	tornado.position = c.centre()
	c.add(tornado)


func _blizzard(c: SpellCast) -> void:
	var line := c.line()
	var left := line[0].x
	var right := line[0].x
	for p in line:
		left = minf(left, p.x)
		right = maxf(right, p.x)
	var snow := Blizzard.new()
	snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(right - left, -60), Vector2(right - left, 60), Vector2(0, 60)])
	c.add(snow)
	snow.setup(c.spell, Vector2(left, c.centre().y), 0.0)


func _smoke_screen(c: SpellCast) -> void:
	var smoke := SmokeScreen.new()
	smoke.line = c.line()
	c.add(smoke)


func _frost_bridge(c: SpellCast) -> void:
	var bridge := FrostBridge.new()
	bridge.line = c.line()
	c.add(bridge)


func _geyser(c: SpellCast) -> void:
	var geyser := Geyser.new()
	geyser.position = _arena.landing(c.centre())  # under the middle of the peak, on the surface
	geyser.ground = _arena.terrain()
	c.add(geyser)


func _bramble(c: SpellCast) -> void:
	var thorns := Bramble.new()
	thorns.line = c.line()
	c.add(thorns)


func _liana(c: SpellCast) -> void:
	var vine := Liana.new()
	vine.line = c.line()
	c.add(vine)


func _great_oak(c: SpellCast) -> void:
	var oak := GreatOak.new()
	oak.position = _arena.landing(c.line()[0])  # the trunk's foot
	c.add(oak)


func _lily_pads(c: SpellCast) -> void:
	var pads := LilyPads.new()
	pads.line = c.line()
	c.add(pads)


func _mudslide(c: SpellCast) -> void:
	var sand := Mudslide.new()
	sand.width = SpellData.width_of(c.line())
	sand.position = c.centre()
	c.add(sand)


func _hailstorm(c: SpellCast) -> void:
	var hail := Hailstorm.new()
	hail.line = c.line()
	c.add(hail)
	hail.setup(c.spell, c.centre(), 0.0)


func _ice_prison(c: SpellCast) -> void:
	var prison := IcePrison.new()
	prison.rect = c.info["rect"]
	c.add(prison)


## Where each drawn V can hang an icicle: from the ceiling straight above it. A V with no ceiling over it grows nothing. The icicle reaches down toward the V's
## tip, no longer than ICICLE_MAX.
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
