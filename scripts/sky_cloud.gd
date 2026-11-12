class_name SkyCloud
extends Node2D

## A cloud of the sky world (chapter 19). The wizards fall, so the clouds go up past them: where one is at a world age is worked out from its home, its rate of rise
## and that age alone (`seconds`, told every frame by the world), so every machine of a match has the same clouds in the same places, and a cloud that has gone
## off the top comes round again at the bottom.
##
## A plain cloud hides whoever is in it. It is drawn in front of the wizards, a little see-through, so a person can still see their own; for a brain's eyes it is a
## sight blocker (see `blocks`): a wizard in a cloud is not made out from far off, the same rule the ocean's kelp has.
## A thundercloud (`storm`) is the same in grey. Every few seconds it flashes, and a moment later a bolt comes down: whoever is inside the cloud is shocked, and so
## is whoever is under the bolt, which falls out of the cloud at a place the seed and the world's age have picked, as far as a little way outside it.
## The flash and a crackle of sparks where the bolt will land show it a moment before, so a person can steer round it.

const NORMAL := [preload("res://art/props/cloud_snow_big.png"), preload("res://art/props/cloud_snow_small_1.png"), preload("res://art/props/cloud_snow_small_2.png")]
const STORMY := [preload("res://art/props/cloud_storm_big.png"), preload("res://art/props/cloud_storm_small_1.png"), preload("res://art/props/cloud_storm_small_2.png")]
const SEEN_FROM := 300.0   # a wizard in a cloud is made out from this far, and not from further
const WARNING := 0.9       # seconds between the flash and the bolt
const SHOCK := 10          # what everyone inside a thundercloud takes from each bolt
const BOLT := 22           # and what the bolt itself does to whoever it comes down on
const STRIKE_WIDTH := 80.0 # how wide the bolt is where it falls
const STRIKE_HEIGHT := 400.0  # and how tall: the picture of the strike, twice its size
const OUTSIDE := 260.0     # the farthest a bolt may fall from the side of its cloud
const NEAR := 2200.0       # a cloud farther than this from every wizard throws nothing: no one is there to be struck

var storm := false
var kind := 0              # which picture: 0 is the big one
var seed_value := 0
var home := Vector2.ZERO   # where it is at world age zero
var rise := 40.0           # pixels a second it goes up
var side := 0.0            # pixels a second it drifts sideways
var span := Rect2()        # the room it moves in: it comes round again at the bottom
var period := 5.0          # seconds between bolts (a thundercloud)
var phase := 0.0           # where in that it begins
var seconds := 0.0         # the world's age, told every frame
var _sprite: Sprite2D
var _flash := 0.0
var _fired := -1
var _warned := -1
var _strip := Rect2()      # where the coming bolt will fall, while it is warned of
var _echo := 0.0


func _ready() -> void:
	z_index = 5  # in front of the wizards
	add_to_group("sight_blockers")
	if storm:
		add_to_group("thunderclouds")
		add_to_group("danger")
	_sprite = Sprite2D.new()
	var pictures: Array = STORMY if storm else NORMAL
	_sprite.texture = pictures[kind]
	_sprite.scale = Vector2.ONE * (6.0 if kind == 0 else 5.0)  # whole-number scales only
	_sprite.modulate = Color(0.78, 0.8, 0.86, 0.82) if storm else Color(0.86, 0.9, 1.0, 0.78)  # a little see-through, so a person still sees their wizard in it
	add_child(_sprite)
	_fired = _count()
	_place()


func _count() -> int:
	return floori((seconds + phase) / period)


## Where the cloud is at the world's age.
func _place() -> void:
	var x := span.position.x + fposmod(home.x - span.position.x + side * seconds, span.size.x)
	var y := span.position.y + fposmod(home.y - span.position.y - rise * seconds, span.size.y)
	global_position = Vector2(x, y)


## The room the cloud takes up now: a little less than its picture, which has soft edges.
func region() -> Rect2:
	var size := _sprite.texture.get_size() * _sprite.scale.x * 0.78
	return Rect2(global_position - size * 0.5, size)


func _process(delta: float) -> void:
	_place()
	if not storm:
		return
	var now := _count()
	var into := fposmod(seconds + phase, period)
	if into >= period - WARNING and _warned < now + 1 and _near_a_wizard():
		_warned = now + 1
		_warn(now + 1)
	if now > _fired:
		_fired = now
		if _near_a_wizard():
			_strike(now)
	_flash = maxf(_flash - delta * 2.0, 0.0)
	var warning := clampf((into - (period - WARNING)) / WARNING, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(seconds * 30.0) if warning > 0.0 else 0.0  # it flickers, faster and brighter as the bolt nears
	_sprite.modulate = Color(0.78, 0.8, 0.86, 0.82).lerp(Color(1.4, 1.4, 1.2, 0.95), maxf(warning * pulse * 0.8, _flash))
	if warning <= 0.0:
		_strip = Rect2()
	elif _warned == now + 1:
		_strip = _strip_for(_warned, global_position)  # (the cloud goes on rising: the place under the bolt goes with it)
		_echo -= delta
		if _echo <= 0.0:
			_echo = 0.25
			Fx.burst(get_parent(), _strip.end - Vector2(_strip.size.x * 0.5, 0.0), Color("#fff2a0"), 6, 70.0, 0.4, true, "spark_04")


func _near_a_wizard() -> bool:
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if not wizard.dead and wizard.global_position.distance_to(global_position) < NEAR:
			return true
	return false


## Where bolt number n falls, from the seed and n alone: [x, the y its foot stands on]. Most fall within the cloud's width, some a little outside it.
func bolt_at(n: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + n * 7919
	var reach := region().size.x * 0.5 + (OUTSIDE if rng.randf() < 0.35 else 0.0)
	var drop := rng.randf_range(60.0, 240.0)
	return Vector2(rng.randf_range(-reach, reach), drop)


## The strip of sky a bolt comes down in, for a bolt that lands at a point of the cloud's own space.
func _strip_for(n: int, centre: Vector2) -> Rect2:
	var at := bolt_at(n)
	var foot := Vector2(centre.x + at.x, centre.y + at.y)
	return Rect2(foot.x - STRIKE_WIDTH * 0.5, foot.y - STRIKE_HEIGHT, STRIKE_WIDTH, STRIKE_HEIGHT)


## The flash that tells of the bolt to come: the cloud flickers (see _process) and sparks crackle where it will fall.
func _warn(n: int) -> void:
	_strip = _strip_for(n, global_position)
	_echo = 0.0
	Fx.burst(get_parent(), global_position, Color("#fff2a0"), 8, 120.0, 0.5, true, "spark_04")
	Sfx.play("spark", global_position, -16.0)


## The bolt: everyone in the cloud is shocked, and everyone under the bolt is struck.
func _strike(n: int) -> void:
	var strip := _strip_for(n, global_position)
	_flash = 1.0
	var foot := strip.end - Vector2(strip.size.x * 0.5, 0.0)
	var picture := PixelFx.play(get_parent(), foot + Vector2(0.0, 6.0), "lightning", 24.0, 2.0, Color(1.0, 1.0, 0.85), true)
	picture.z_index = 7
	Fx.impact(get_parent(), foot, Color("#ffe85a"), 50.0)
	Sfx.play("thunder", foot, -8.0)
	GameCamera.shake_scene(get_tree(), 0.12)
	var inside := region()
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		if wizard.is_likeness():
			continue  # the machine that drives it says what a bolt does to it
		var body := wizard.center()
		if strip.has_point(body):
			SpellTargets.hurt(wizard, BOLT, "Fire", false, false, null)
			Fx.burst(get_parent(), body, Color("#ffe85a"), 10, 180.0, 0.3, true, "spark_04")
		elif inside.has_point(body):
			SpellTargets.hurt(wizard, SHOCK, "Fire", false, false, null)
			Fx.burst(get_parent(), body, Color("#ffe85a"), 6, 140.0, 0.3, true, "spark_04")
	_strip = Rect2()


## A thundercloud, and the place a bolt it has warned of will fall, are dangerous (the wizards keep out of them).
func danger_at(point: Vector2) -> bool:
	return storm and (region().has_point(point) or (_strip.size != Vector2.ZERO and _strip.has_point(point)))


## True when a sight line from one point to another is cut by the cloud: one of its ends is inside it and they are far apart.
func blocks(from: Vector2, to: Vector2) -> bool:
	if from.distance_to(to) <= SEEN_FROM:
		return false
	var room := region()
	return room.has_point(from) or room.has_point(to)


## Where the cloud is, for what looks at it (see Senses).
func sense_point() -> Vector2:
	return region().get_center()
