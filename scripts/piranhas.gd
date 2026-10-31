class_name Piranhas
extends Node2D

## A shoal of piranhas in a long, shallow pit of water. They swim to and fro, and go for anyone who is in the water, quick
## to bite. Whoever crosses above it, on ice or lily pads or a bridge, is out of their reach. Lightning kills them: a spark
## that strikes the water shocks every fish near it.

const FRAMES := [0, 1, 2, 3]
const BITE := 15
const BITE_GAP := 0.6
const SWIM := 55.0
const CHASE := 190.0
const SHOCK_REACH := 150.0  # how far along the water a lightning strike kills

var water := Rect2()  # the pit's water, in world pixels
var pond: Pond  # the pool the shoal lives in, when it is one: once its liquid flows, the fish keep to the liquid as it is now
var bed := PackedInt32Array()  # for a pond dug in sloping ground: the row of the ground under each of its columns, so the fish keep to the water
var bed_x := 0.0  # the left edge of the first of those columns, in world pixels
var count := 5
var _fish: Array[Dictionary] = []  # each {"sprite", "dir", "phase", "bite"}
var _t := 0.0
var _dry := 0.0     # seconds the pool has had no water deep enough to swim in
var _look := 0.0    # seconds until the stretch the fish can swim in is worked out again


const STRANDED := 3.0  # seconds without water deep enough, and the fish are left on dry ground
const DEEP_ENOUGH := 40.0  # how much water there must be over a column of the bed for a fish to be in it
var _swim_from := 0.0
var _swim_to := 0.0


func _ready() -> void:
	add_to_group("shoals")
	_swim_from = water.position.x
	_swim_to = water.end.x
	if not bed.is_empty():  # only the stretch that is deep enough: the basin's slopes are not water a fish can swim in
		_swim_from = INF
		_swim_to = -INF
		for k in bed.size():
			if bed[k] * float(ArenaGen.TILE) - water.position.y >= DEEP_ENOUGH:
				_swim_from = minf(_swim_from, bed_x + k * float(ArenaGen.TILE))
				_swim_to = maxf(_swim_to, bed_x + (k + 1) * float(ArenaGen.TILE))
		if _swim_from >= _swim_to:
			_swim_from = water.position.x
			_swim_to = water.end.x
	z_index = 0
	var frames := SpriteFrames.new()
	frames.add_animation("swim")
	frames.set_animation_speed("swim", 6.0)
	for i in FRAMES:
		frames.add_frame("swim", load("res://art/mobs/piranha_small/frame_%d.png" % i))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(water.position.x)
	for k in count:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE  # drawn as it is, so the pixels stay put
		sprite.modulate = Color(1, 1, 1, 0.9)
		sprite.position = _confine(Vector2(_swim_from + (_swim_to - _swim_from) * (k + 0.5) / count, water.position.y + water.size.y * rng.randf_range(0.5, 0.85)))
		sprite.play("swim")
		sprite.frame = k % FRAMES.size()
		add_child(sprite)
		_fish.append({"sprite": sprite, "pos": sprite.position, "dir": 1.0 if k % 2 == 0 else -1.0, "phase": rng.randf() * TAU, "bite": 0.0})


func _physics_process(delta: float) -> void:
	_t += delta
	if _follows_liquid():
		_look -= delta
		if _look <= 0.0:
			_look = 0.4
			_find_swimming_water()
		if _swim_from >= _swim_to:  # the water has drained away from under them
			_dry += delta
			if _dry > STRANDED:
				_strand()
				return
		else:
			_dry = 0.0
	var prey := _prey()
	for fish in _fish:
		var sprite: AnimatedSprite2D = fish["sprite"]
		fish["bite"] = maxf(fish["bite"] - delta, 0.0)
		var pos: Vector2 = fish["pos"]
		var goal := Vector2.ZERO
		var chasing := false
		var best := 1e9
		for body: Node2D in prey:
			var at := SpellTargets.center_of(body)
			var d := at.distance_to(pos)
			if d < best:
				best = d
				goal = at
				chasing = true
		if chasing:
			var to := goal - pos
			if to.length() > 14.0:
				pos += to.normalized() * CHASE * delta
			fish["dir"] = signf(to.x) if absf(to.x) > 4.0 else fish["dir"]
			if best < 40.0 and fish["bite"] <= 0.0:
				fish["bite"] = BITE_GAP
				for body: Node2D in prey:
					if SpellTargets.center_of(body).distance_to(pos) < 40.0:
						SpellTargets.hurt(body, BITE, "Water")
						Fx.burst(get_parent(), SpellTargets.center_of(body), Color("#a02020"), 5, 80.0, 0.3)
						break
		else:
			pos.x += fish["dir"] * SWIM * delta
			pos.y += sin(_t * 1.6 + fish["phase"]) * 10.0 * delta
			if pos.x < _swim_from + 16.0:
				fish["dir"] = 1.0
			elif pos.x > _swim_to - 16.0:
				fish["dir"] = -1.0
		pos = _confine(pos)
		fish["pos"] = pos
		sprite.position = pos.round()  # drawn on whole pixels, so it does not shimmer
		sprite.flip_h = fish["dir"] < 0.0


## True once the pool's liquid is flowing, so the water is wherever the liquid is rather than the rectangle the pool began as.
func _follows_liquid() -> bool:
	return pond != null and is_instance_valid(pond) and pond.grid != null


## The stretch of water the fish can swim in now: the unbroken run of columns where the liquid is deep enough, that the fish are in (or, failing
## that, the widest).
func _find_swimming_water() -> void:
	var mean := 0.0
	for fish in _fish:
		mean += fish["pos"].x
	mean /= maxf(_fish.size(), 1.0)
	var best := Vector2.ZERO
	var run_from := -1.0
	var x := pond.region().position.x
	var end := pond.region().end.x
	while x <= end + 8.0:
		var span := pond.wet_span(x) if x < end else Vector2.ZERO
		if span.y - span.x >= DEEP_ENOUGH:
			if run_from < 0.0:
				run_from = x
		elif run_from >= 0.0:
			var run := Vector2(run_from, x)
			if mean >= run.x - 16.0 and mean <= run.y + 16.0:
				best = run
				break
			if run.y - run.x > best.y - best.x:
				best = run
			run_from = -1.0
		x += 8.0
	_swim_from = best.x
	_swim_to = best.y


## The water is gone: the fish die where they lie.
func _strand() -> void:
	for fish in _fish:
		var sprite: AnimatedSprite2D = fish["sprite"]
		Fx.burst(get_parent(), sprite.global_position, Color("#a8c8d8"), 4, 60.0, 0.3)
	queue_free()


## A place in the water, nearest to a point: inside the stretch the fish can swim, and above the ground under it.
func _confine(pos: Vector2) -> Vector2:
	if _follows_liquid():
		if _swim_from >= _swim_to:
			return pos
		pos.x = clampf(pos.x, _swim_from + 12.0, maxf(_swim_to - 12.0, _swim_from + 12.0))
		var span := pond.wet_span(pos.x)
		if span.y > span.x:
			pos.y = clampf(pos.y, span.x + 16.0, maxf(span.y - 10.0, span.x + 16.0))
		return pos
	pos.x = clampf(pos.x, _swim_from + 12.0, _swim_to - 12.0)
	var floor_y := water.end.y - 10.0
	if not bed.is_empty():
		var k := clampi(int((pos.x - bed_x) / float(ArenaGen.TILE)), 0, bed.size() - 1)
		floor_y = minf(floor_y, bed[k] * float(ArenaGen.TILE) - 10.0)
	pos.y = clampf(pos.y, water.position.y + 16.0, maxf(floor_y, water.position.y + 16.0))
	return pos


## Whoever is in the water, and so within the fishes' reach: the body's middle is under the surface.
func _prey() -> Array:
	var out := []
	for body in SpellTargets.all(get_tree()):
		if not SpellTargets.affects(body):
			continue
		var at: Vector2 = SpellTargets.center_of(body)
		if _follows_liquid():
			if pond.wet_at(at + Vector2(0.0, 8.0)):
				out.append(body)
		elif at.x > water.position.x and at.x < water.end.x and at.y > water.position.y + 8.0 and at.y < water.end.y + 40.0:
			out.append(body)
	return out


## True while any fish is alive.
func alive() -> bool:
	return not _fish.is_empty()


## The x position of the live fish nearest to one, or the middle of the water when there are none.
func fish_x_near(x: float) -> float:
	var best := water.get_center().x
	var gap := INF
	for fish in _fish:
		var at: float = fish["sprite"].position.x
		if absf(at - x) < gap:
			gap = absf(at - x)
			best = at
	return best


## A bolt of lightning strikes the water at this point: every fish within reach along the water dies.
func shock(point: Vector2) -> void:
	if _follows_liquid():
		if not pond.wet_at(point) and not pond.wet_at(point + Vector2(0.0, 12.0)):
			return
	elif not water.grow(8.0).has_point(point):
		return
	for fish in _fish.duplicate():
		var sprite: AnimatedSprite2D = fish["sprite"]
		if absf(sprite.position.x - point.x) <= SHOCK_REACH:
			Fx.burst(get_parent(), sprite.global_position, Color("#ffe85a"), 8, 120.0, 0.3, true, "spark_04")
			sprite.queue_free()
			_fish.erase(fish)
	if _fish.is_empty():
		queue_free()  # no fish left: the pit is only water
