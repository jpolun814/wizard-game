class_name Piranhas
extends Node2D

## A shoal of piranhas in a long, shallow pit of water. They swim to and fro, and go for anyone who is in the water, quick
## to bite. Whoever crosses above it, on ice or lily pads or a bridge, is out of their reach. Lightning kills them: a spark
## that strikes the water shocks every fish near it.

const FRAMES := [0, 2]  # the two frames of the strip that keep the body still while the tail and fins move
const BITE := 15
const BITE_GAP := 0.6
const SWIM := 55.0
const CHASE := 190.0
const SHOCK_REACH := 150.0  # how far along the water a lightning strike kills

var water := Rect2()  # the pit's water, in world pixels
var count := 5
var _fish: Array[Dictionary] = []  # each {"sprite", "dir", "phase", "bite"}
var _t := 0.0


func _ready() -> void:
	add_to_group("shoals")
	z_index = 0
	var frames := SpriteFrames.new()
	frames.add_animation("swim")
	frames.set_animation_speed("swim", 4.0)
	for i in FRAMES:
		frames.add_frame("swim", load("res://art/mobs/piranha/frame_%d.png" % i))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(water.position.x)
	for k in count:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * 2.0  # a whole-number scale, so the pixels stay put
		sprite.modulate = Color(1, 1, 1, 0.9)
		sprite.position = Vector2(water.position.x + water.size.x * (k + 0.5) / count, water.position.y + water.size.y * rng.randf_range(0.5, 0.85))
		sprite.play("swim")
		sprite.frame = k % FRAMES.size()
		add_child(sprite)
		_fish.append({"sprite": sprite, "pos": sprite.position, "dir": 1.0 if k % 2 == 0 else -1.0, "phase": rng.randf() * TAU, "bite": 0.0})


func _physics_process(delta: float) -> void:
	_t += delta
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
			if pos.x < water.position.x + 24.0:
				fish["dir"] = 1.0
			elif pos.x > water.end.x - 24.0:
				fish["dir"] = -1.0
		pos.x = clampf(pos.x, water.position.x + 16.0, water.end.x - 16.0)
		pos.y = clampf(pos.y, water.position.y + 28.0, water.end.y - 14.0)
		fish["pos"] = pos
		sprite.position = pos.round()  # drawn on whole pixels, so it does not shimmer
		sprite.flip_h = fish["dir"] < 0.0


## Whoever is in the water, and so within the fishes' reach: the body's middle is under the surface.
func _prey() -> Array:
	var out := []
	for body in SpellTargets.all(get_tree()):
		if not SpellTargets.affects(body):
			continue
		var at: Vector2 = SpellTargets.center_of(body)
		if at.x > water.position.x and at.x < water.end.x and at.y > water.position.y + 8.0 and at.y < water.end.y + 40.0:
			out.append(body)
	return out


## True while any fish is alive.
func alive() -> bool:
	return not _fish.is_empty()


## A bolt of lightning strikes the water at this point: every fish within reach along the water dies.
func shock(point: Vector2) -> void:
	if not water.grow(8.0).has_point(point):
		return
	for fish in _fish.duplicate():
		var sprite: AnimatedSprite2D = fish["sprite"]
		if absf(sprite.position.x - point.x) <= SHOCK_REACH:
			Fx.burst(get_parent(), sprite.global_position, Color("#ffe85a"), 8, 120.0, 0.3, true, "spark_04")
			sprite.queue_free()
			_fish.erase(fish)
