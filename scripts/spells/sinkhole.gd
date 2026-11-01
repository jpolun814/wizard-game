class_name Sinkhole
extends Node2D

## Sinkhole: the ground opens where a U was drawn. A pit in the shape of the U is dug into the open ground (Terrain.dig), as wide as the U and
## about as deep as it is tall, and whoever stands over it drops in. It does not close again. Drawn at the underside of a roof it digs
## up instead, into the rock above, and a roof thin enough lets the sky in. A castle floor is a slab of rock, and a pit dug in it goes right
## through to the floor below.

const HALF_WIDTH := 80.0  # the width of a pit drawn with no U to go by
const LEAST := 50.0       # and the narrowest and widest a drawn U can make it
const MOST := 130.0
const DEPTH := 96.0  # and how deep a pit drawn with no U to go by is
const SHALLOWEST := 56.0
const DEEPEST := 120.0  # a wizard's jump clears a little more than this, so nobody can be left at the bottom of a pit with straight sides
const WARNING := 0.9   # seconds the ground trembles before it gives way

var ground: Terrain
var ridge: MountainRidges  # set when the pit opens in a ridge's top
var half_width := HALF_WIDTH  # how far the pit reaches to either side: the width of the U that was drawn
var depth := DEPTH            # how deep it goes: the height of the U
var profile := PackedFloat32Array()  # how deep the pit is across its width, from the left side to the right, as a share of the depth: the U itself
var _age := 0.0
var _opened := false
var _dust: CPUParticles2D


## The shape of a drawn U as a profile of the pit: for each of `count` places across its box, how far down the stroke goes there, 0 at the top
## of the box and 1 at the bottom.
static func profile_of(drawn: PackedVector2Array, count: int) -> PackedFloat32Array:
	var box := GestureTemplates.bounds(drawn)
	var out := _lows(drawn, count)
	for i in count:
		out[i] = clampf((out[i] - box.position.y) / maxf(box.size.y, 1.0), 0.0, 1.0)
	return out


## How the pit follows the line that was drawn: where it opens, how wide, how deep, and its profile. The line is laid onto the world as it was
## drawn, so the pit is as deep at each place as the line sinks below the ground there. A U drawn wholly in the open air has no ground to
## sink below, so it is let down until its top rests on the ground and its own height is the depth.
static func fit(world: World2D, drawn: PackedVector2Array, count := 17, ridges: MountainRidges = null) -> Dictionary:
	var box := GestureTemplates.bounds(drawn)
	var lows := _lows(drawn, count)
	var half := clampf(box.size.x * 0.5, LEAST, MOST)
	var on_ridge := ridges != null and ridges.holds(box)  # a U drawn on a ridge's top sinks the ridge, not the ground in front of it
	var middle := Vector2(box.get_center().x, ridges.top_at(box.get_center().x)) if on_ridge else SpellTargets.surface_over(world, Vector2(box.get_center().x, box.position.y))
	var sunk := PackedFloat32Array()
	var in_the_air := true
	for i in count:
		var x := box.position.x + box.size.x * float(i) / float(count - 1)
		var surface: float = ridges.top_at(x) if on_ridge else SpellTargets.surface_over(world, Vector2(x, box.position.y)).y
		if surface == INF:
			surface = middle.y
		sunk.append(maxf(lows[i] - surface, 0.0))
		in_the_air = in_the_air and lows[i] <= surface
	if in_the_air:  # nothing of the line reaches the ground
		for i in count:
			sunk[i] = lows[i] - box.position.y
	var deepest := 0.0
	for i in count:
		deepest = maxf(deepest, sunk[i])
	var depth := clampf(deepest, SHALLOWEST, DEEPEST)
	var profile := PackedFloat32Array()
	for i in count:
		profile.append(clampf(sunk[i] / maxf(deepest, 1.0), 0.0, 1.0))
	return {"spot": Vector2(box.get_center().x, middle.y), "half_width": half, "depth": depth, "profile": profile, "ridge": ridges if on_ridge else null}


## For each of `count` places across the box of a stroke, the lowest the stroke goes near there (its largest y).
static func _lows(drawn: PackedVector2Array, count: int) -> PackedFloat32Array:
	var box := GestureTemplates.bounds(drawn)
	var out := PackedFloat32Array()
	var reach := box.size.x / float(count - 1)
	for i in count:
		var x := box.position.x + box.size.x * float(i) / float(count - 1)
		var low := -INF
		for point in drawn:
			if absf(point.x - x) <= reach:
				low = maxf(low, point.y)
		out.append(low if low > -INF else NAN)
	for i in count:  # a place no point of the stroke came near takes its neighbours' depth
		if is_nan(out[i]):
			var before := i - 1
			while before >= 0 and is_nan(out[before]):
				before -= 1
			var after := i + 1
			while after < count and is_nan(out[after]):
				after += 1
			out[i] = out[before] if before >= 0 else (out[after] if after < count else box.end.y)
	return out


func _ready() -> void:
	add_to_group("lasting")
	z_index = 2
	_dust = CPUParticles2D.new()
	_dust.amount = 18
	_dust.lifetime = 0.7
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(half_width, 2.0)
	_dust.direction = Vector2.UP
	_dust.spread = 25.0
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 60.0
	_dust.gravity = Vector2(0.0, 90.0)
	_dust.texture = Fx.tex("dirt_01")
	_dust.scale_amount_min = 4.0 / Fx.TEX_SIZE
	_dust.scale_amount_max = 9.0 / Fx.TEX_SIZE
	_dust.color = Color(0.7, 0.58, 0.45, 0.8)
	add_child(_dust)
	Sfx.play("quake", global_position, -6.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _opened:
		if _age > WARNING + 1.2:
			queue_free()
		return
	if _age < WARNING:
		return
	_opened = true
	_dust.emitting = false
	var dug := ridge.dig(global_position, half_width, depth, profile) if ridge != null else ground != null and ground.dig(global_position, half_width, depth, profile)
	if dug:
		GameCamera.shake_scene(get_tree(), 0.35)
		Fx.debris(get_parent(), global_position, Color("#8a6a4a"), 14, 200.0)
		Sfx.play("stones", global_position, -2.0)
	else:
		Fx.smoke(get_parent(), global_position, Color(0.5, 0.47, 0.45, 0.6), 4, 24.0, 30.0)  # nothing here gave way


## True over the pit while it is about to open: the ground is not to be stood on.
func danger_at(point: Vector2) -> bool:
	return not _opened and absf(point.x - global_position.x) < half_width and absf(point.y - global_position.y) < 40.0
