class_name SpellEffect
extends Area2D

## World effect for a resolved spell. Projectiles fly and hit the first foe or wall;
## area spells act on whatever is inside them. Who gets hurt depends on the spell's team (see SpellTargets).
## Each school looks different: a pixel-art fireball and ice spear, lightning from the sky, a column of fire, a
## circle of force that shoves everything inside it along the line drawn out of the circle (Push).

signal broke

const PROJECTILES := {
	"Ignite": {"speed": 700.0, "damage": 12, "life": 2.0, "color": Color("#ff7a2a")},
	"Frostbolt": {"speed": 600.0, "damage": 6, "life": 2.0, "color": Color("#b8f0ff")},
}
const FORCE_ZONE_LIFE := 0.5
const FIREWALL_TICK := 0.5
const FIREWALL_DAMAGE := 4
const FIREWALL_HEIGHT := 120.0
const SPARK_DAMAGE := 20
const SPARK_SKY := 420.0  # the strike starts this far above where it lands
const KNOCK_SPEED := 700.0
const SLOW_SECONDS := 2.0
const FIREBALL_KNOCK := 420.0  # how hard a fireball pushes what it hits
const ICICLE_LIFE := 99999.0  # an icicle stands until the wave ends, or fire melts it
const ICICLE_TICK := 0.5
const ICICLE_DAMAGE := 6
const MELT_TICK := 0.5  # fire takes a slice off an icicle this often
const MELT_STEP := 0.25  # and each slice is this share of its height
const PILE_GROW := 2.0  # snow lands on the ground at this many pixels a second, up to PILE_MAX
const REPOSE := 4.0  # how steep a heap of snow can be before it slides, in pixels of height per column
const MELT_RADIUS := 40.0  # fire melts snow this far from itself
const PILE_MELT := 35.0  # fire melts the pile at this many pixels a second
const SNOW_STEP := 6.0  # how often the ground under the snow is checked, in pixels
const SNOW_LIFE := 99999.0  # the snow falls until the wave ends
const STONE_WALL_LENGTH := 140.0  # a wall drawn without a length of its own
const STONE_WALL_MIN := 60.0
const STONE_WALL_MAX := 240.0
# Images drawn every frame are held here, so they stay loaded between frames.
const ROCK := preload("res://art/fx/rock.png")
const STONE := preload("res://art/tiles/stone.png")
const FIRE_SHEET := preload("res://art/fx/flame.png")
const ICE := preload("res://art/props/ice_fill.png")
const SNOW_CLOUDS := [preload("res://art/props/cloud_snow_big.png"), preload("res://art/props/cloud_snow_small_1.png"),
		preload("res://art/props/cloud_snow_small_2.png")]

var spell := ""
var team := "player"  # "player" or "enemy": who cast it, which decides who it hurts
var _aim := Vector2.RIGHT
var _age := 0.0
var _life := 1.0
var _tick := 0.0
var _burst_done := false
var _spent := false
var zone_radius := 40.0  # the Push circle's radius, set by the caster from the drawn circle
var wall_length := 0.0  # a Stone Wall's length: the distance the stroke was drawn over (0 for the default)
var _wall_length := STONE_WALL_LENGTH
var wall_texture: Texture2D  # the biome's earth, set by the arena for a Stone Wall
var _wall_stages: Array[Texture2D] = []  # the wall as it is whole, part crumbled and mostly crumbled
var _health := 0.0
var _max_health := 0.0
var _melt_time := 0.0
var _pile := PackedFloat32Array()
var _pile_body: StaticBody2D  # the landed snow is solid: it can be walked on
var _pile_shapes: Array = []
var _pile_timer := 0.0  # how deep the landed snow is in each stretch of the ground under the line
var _snow_floors := PackedFloat32Array()  # the ground under the line, every few pixels, so the snow lands on it
var _spark_depth := 400.0  # how far the strike reaches down from where it starts
var _trail: CPUParticles2D
var polygon := PackedVector2Array()  # local outline for icicles and the snow band, set by the arena before setup


func setup(spell_name: String, origin: Vector2, aim_angle: float) -> void:
	spell = spell_name
	global_position = origin
	_aim = Vector2.from_angle(aim_angle)
	material = _glow_material()
	collision_mask = 7  # terrain, enemies and the player
	var shape := CollisionShape2D.new()
	if PROJECTILES.has(spell):
		add_to_group("projectiles")
		rotation = aim_angle
		_life = PROJECTILES[spell]["life"]
		var rect := RectangleShape2D.new()
		rect.size = Vector2(22, 12)
		shape.shape = rect
		body_entered.connect(_on_projectile_hit)
		_trail = _make_trail()
		add_child(_trail)
		# The shot itself: a pixel-art fireball or ice spear, its head on the node and its tail streaming behind.
		var shot := PixelFx.sprite("fireball" if spell == "Ignite" else "icespear", 18.0)
		shot.offset = Vector2(-18, 0)
		add_child(shot)
		Sfx.play("cast_fire" if spell == "Ignite" else "cast_ice", origin)
	else:
		match spell:
			"Icicles":
				# Ice where it was drawn. It hurts what walks through it, then melts.
				_life = ICICLE_LIFE
				add_to_group("lasting")
				texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				z_index = -1  # behind the ground, as if it hangs from it
				var icicle := ConvexPolygonShape2D.new()
				icicle.points = polygon
				shape.shape = icicle
				add_to_group("danger")
				Sfx.play("ice_shatter", origin, 2.0)
				Fx.burst(get_parent(), origin, Color("#dff6ff"), 8, 80.0, 0.4, true, "star_04")
			"Blizzard":
				# A band of snow along the drawn line. It slows whatever is inside.
				_life = SNOW_LIFE
				add_to_group("lasting")
				_snow_floors = _snow_ground()
				var snow_band := ConvexPolygonShape2D.new()
				snow_band.points = polygon
				shape.shape = snow_band
				if team == "player":
					Sfx.play("snow", origin)
			"Firewall":
				# Burns whoever stands in it; anyone can walk through. It rises from the ground under the stroke.
				_life = 4.0
				global_position = SpellTargets.ground_below(get_world_2d(), origin + Vector2(0, -20)) - Vector2(0, FIREWALL_HEIGHT * 0.5)
				var rect := RectangleShape2D.new()
				rect.size = Vector2(24, FIREWALL_HEIGHT + 4.0)
				shape.shape = rect
				_add_flames()
				add_to_group("danger")
				Sfx.play("fire_wall", global_position)
			"Push":
				# A circle of force: everything inside it is shoved once, along the line drawn out of the circle.
				_life = FORCE_ZONE_LIFE
				rotation = aim_angle
				Sfx.play("push", origin)
				var ring := PixelFx.play(get_parent(), origin, "ring", 60.0, maxf(1.0, roundf(zone_radius / 22.0)), Color(0.8, 0.6, 1.0))
				ring.material = Fx.additive()
			"Stone Wall":
				# A solid slab that rises along the stroke from the ground and stays until a Push knocks it down.
				_life = 99999.0
				rotation = aim_angle
				_wall_length = clampf(wall_length, STONE_WALL_MIN, STONE_WALL_MAX) if wall_length > 0.0 else STONE_WALL_LENGTH
				global_position = origin + Vector2.from_angle(aim_angle) * _wall_length * 0.5
				_add_stone_slab(Vector2(_wall_length, 22))
				_build_wall()
				Sfx.play("stones", origin, -2.0)  # pebbles shifting under the slab
				Sfx.play("quake", origin)  # and the ground heaving under it
				Fx.debris(get_parent(), origin, Color("#a08060"), 10, 200.0)
				GameCamera.shake_scene(get_tree(), 0.2)
			"Force Wall":
				# A short-lived wall of force that only touches shots: it bats them back. Characters pass through it.
				_life = 1.3  # a flash of force that stays long enough to be seen
				var force_rect := RectangleShape2D.new()
				force_rect.size = Vector2(124, 26)  # long along the slash, so it deflects along its angle
				rotation = aim_angle
				shape.shape = force_rect
				collision_mask = 1  # shots live on layer 1; characters (layers 2 and 4) are never touched
				area_entered.connect(_on_force_area)
				# A simple flick of force: a bolt of arcane light streaks forward through the wall and fades.
				var flick := PixelFx.sprite("magic_bolt", 18.0, false)
				flick.scale = Vector2.ONE * 2.0
				flick.modulate = Color(1.0, 0.75, 1.0)  # a touch brighter, so the flick is more present
				flick.material = Fx.additive()
				flick.position = Vector2(-30.0, 0)
				add_child(flick)
				var streak := create_tween()
				streak.tween_property(flick, "position", Vector2(30.0, 0), 0.3)
				streak.parallel().tween_property(flick, "modulate:a", 0.0, 0.3)
				Sfx.play("force", origin)
			"Stonefall":
				# A boulder that falls onto the ground under the stroke and stays where it lands, as a loose rock.
				var boulder := Boulder.new()
				boulder.team = team
				boulder.global_position = origin + Vector2(0, -260)
				get_parent().add_child(boulder)
				queue_free()
			"Spark":
				# A strike from the sky: it comes straight down through the stroke and stops at the first thing it meets,
				# a platform or the ground. Nothing under a platform can be struck from above it.
				_life = 0.35
				var ground := SpellTargets.ground_below(get_world_2d(), Vector2(origin.x, ArenaGen.WALL_TOP * ArenaGen.TILE), 2000.0)
				global_position = Vector2(origin.x, ground.y - SPARK_SKY)
				_spark_depth = SPARK_SKY
				var rect := RectangleShape2D.new()
				rect.size = Vector2(16, _spark_depth)
				shape.position = Vector2(0, _spark_depth * 0.5)
				shape.shape = rect
				# The bolt is a pixel-art strike drawn twice its size, standing on the ground where it lands.
				var strike := PixelFx.play(get_parent(), ground + Vector2(0, 6), "lightning", 24.0, 2.0, Color(1.0, 1.0, 0.85), true)
				strike.z_index = 7
				PixelFx.play(get_parent(), ground, "blast_small", 20.0, 1.0, Color(1.0, 0.95, 0.6), true, false, true)
				Fx.impact(get_parent(), ground, Color("#ffe85a"), 50.0)
				Fx.burst(get_parent(), ground, Color("#ffe85a"), 20, 240.0, 0.4, true, "spark_04")
				Sfx.play("spark", ground)
				GameCamera.shake_scene(get_tree(), 0.25)
	add_child(shape)


## The trail behind a projectile. Ice leaves drifting snow; fire leaves rising embers and a little smoke.
## One frame of the pixel fire the flames are cut from, for the embers that fly off fire.
func _pixel_ember() -> Texture2D:
	var ember := AtlasTexture.new()
	ember.atlas = FIRE_SHEET
	ember.region = Rect2(20 * 64, 0, 64, 64)
	return ember


func _make_trail() -> CPUParticles2D:
	var trail: CPUParticles2D
	match spell:
		"Frostbolt":
			# Drawn normally rather than as light, and a little blue, so the snow shows up against a snowy level.
			trail = Fx.trail(Color("#a9dcff"), 36, 0.55, 30.0, Vector2(0, 60), "star_04", 12.0)
			trail.material = null
		_:
			trail = Fx.trail(Color("#ff9a40"), 60, 0.35, 25.0, Vector2(0, -60), "flame_05", 12.0)
			trail.texture = _pixel_ember()  # the same pixel fire as the flames, not a soft particle
			trail.angle_min = -180.0
			trail.angle_max = 180.0
	return trail


## Fire and lightning add light to what's behind them. Ice, force and stone are solid, with no glow.
func _glow_material() -> CanvasItemMaterial:
	if spell in ["Frostbolt", "Push", "Icicles", "Blizzard", "Force Wall", "Stonefall", "Stone Wall"]:
		return null
	return Fx.additive()


## The firewall is three pixel-art flames stacked on each other, each burning out of step with the others, with
## embers rising off it.
func _add_flames() -> void:
	# Four tall flames of the pixel fire, overlapping up the wall, so they read as one wall of fire.
	for i in 4:
		var flame := PixelFx.sprite("fire_wall", 14.0 + i * 2.0)
		flame.scale = Vector2.ONE * 2.0
		flame.offset = Vector2(0, -PixelArt.FX["fire_wall"]["size"].y * 0.5)
		flame.position = Vector2(0, FIREWALL_HEIGHT * 0.5 - i * FIREWALL_HEIGHT / 3.0)
		flame.flip_h = i % 2 == 1
		flame.frame = i * 2
		flame.z_index = 1 - i % 2
		add_child(flame)
	var p := Fx.trail(Color(1.0, 0.55, 0.2), 24, 0.8, 20.0, Vector2(0, -60), "spark_01", 6.0)
	p.texture = _pixel_ember()  # the same pixel fire as the flames, not a soft particle
	p.direction = Vector2.UP
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, FIREWALL_HEIGHT * 0.4)
	add_child(p)


func _draw() -> void:
	var fade := clampf(1.0 - _age / _life, 0.0, 1.0)
	match spell:
		"Ignite":
			Fx.draw_glow(self, Vector2.ZERO, 20.0 * (1.0 + 0.1 * sin(_age * 30.0)), Color(1.0, 0.45, 0.12, 0.45))
		"Push":
			_draw_push_zone()
		"Icicles":
			_draw_icicle(fade)
		"Blizzard":
			_draw_snow(fade)
		"Firewall":
			_draw_firewall(fade)
		"Force Wall":
			_draw_force_wall(fade)
		"Stone Wall":
			_draw_stone_wall()


## The light the firewall throws on what's behind it; the flames themselves are sprites.
func _draw_firewall(fade: float) -> void:
	Fx.draw_glow(self, Vector2(0, 10), FIREWALL_HEIGHT * 0.55, Color(1.0, 0.4, 0.1, 0.3 * fade))


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if PROJECTILES.has(spell):
		var speed: float = PROJECTILES[spell]["speed"]
		position += _aim * speed * delta
		rotation = _aim.angle()
	match spell:
		"Firewall":
			_tick -= delta
			if _tick <= 0.0:
				_tick = FIREWALL_TICK
				_damage_overlapping(FIREWALL_DAMAGE)
		"Spark":
			if not _burst_done and _age > 0.05:
				_burst_done = true
				_damage_overlapping(SPARK_DAMAGE)
		"Icicles":
			if _fire_touches():
				# Each fire tick takes a slice off the top; the point stays where it is until the icicle is gone.
				_melt_time -= delta
				if _melt_time <= 0.0:
					_melt_time = MELT_TICK
					scale.y = maxf(scale.y - MELT_STEP, 0.0)
					if scale.y <= 0.05:
						queue_free()
						return
			_tick -= delta
			if _tick <= 0.0:
				_tick = ICICLE_TICK
				_damage_overlapping(ICICLE_DAMAGE)
		"Blizzard":
			_grow_pile(delta)
			for body in get_overlapping_bodies():
				if not SpellTargets.affects(body, team):
					continue
				if body.is_in_group("mobs"):
					body.apply_slow(2.0)  # the slow lingers a second or two after leaving the snow
				else:
					body.apply_debuff("slow", 2.0)
		"Push":
			if not _burst_done and _age > 0.05:
				_burst_done = true
				_apply_force_zone()
	if _age >= _life:
		_finish()


func _on_projectile_hit(body: Node2D) -> void:
	if body.is_in_group("player"):
		# A shot never hurts the one who cast it.
		if team == "player" or _spent:
			return
		_spent = true
		body.take_damage(PROJECTILES[spell]["damage"], true, true)
		if spell == "Frostbolt":
			body.apply_debuff("slow", SLOW_SECONDS)
		_impact_effect()
		_finish()
		return
	if body.is_in_group("mobs"):
		if team == "enemy" or _spent or body.is_dead():
			return  # the dark wizard's shots fly through its allies
		_spent = true
		_impact_effect()
		var damage: int = PROJECTILES[spell]["damage"]
		body.take_damage(damage, _school())
		if spell == "Ignite":
			body.knock_back(_aim * FIREBALL_KNOCK)  # a fireball shoves the enemy a little along its path
		if spell == "Frostbolt":
			body.apply_slow(SLOW_SECONDS)
		_finish()
		return
	# Terrain, walls and stone slabs stop it.
	if _spent:
		return
	_spent = true
	_impact_effect()
	_finish()


## Ice shatters into shards; fire bursts into sparks and a puff of smoke.
func _impact_effect() -> void:
	if spell == "Frostbolt":
		Shatter.spawn(get_parent(), global_position, PROJECTILES[spell]["color"])
		Sfx.play("ice_shatter", global_position)
	else:
		PixelFx.play(get_parent(), global_position, "blast_small", 22.0, 1.0)
		Fx.smoke(get_parent(), global_position, Color(0.3, 0.25, 0.25, 0.4), 3, 18.0, 30.0)
		Sfx.play("fire_hit", global_position)


## A Force Wall or Tornado sent this shot back: it turns around and now belongs to the other side.
func reflect(direction: Vector2) -> void:
	if not PROJECTILES.has(spell):
		return
	_aim = direction.normalized()
	team = "enemy" if team == "player" else "player"
	_age = 0.2  # it may hit whoever is in front of it straight away
	_spent = false
	Fx.burst(get_parent(), global_position, Color("#d9b8ff"), 8, 120.0, 0.3, true)
	Sfx.play("force", global_position, -4.0)


## Wind turns a shot to a new heading. Unlike a reflection, it stays with whoever fired it.
func deflect(direction: Vector2) -> void:
	if not PROJECTILES.has(spell):
		return
	_aim = direction.normalized()
	rotation = _aim.angle()


func _damage_overlapping(amount: int) -> void:
	for body in get_overlapping_bodies():
		SpellTargets.hurt(body, amount, _school(), team)


## Ends the effect. A projectile's trail is let go to finish fading rather than vanishing with it.
func _finish() -> void:
	if _trail:
		var trail := _trail
		_trail = null
		trail.emitting = false
		trail.reparent(get_parent())
		get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	queue_free()


## The school this spell belongs to, which decides what enemies resist or are weak to.
func _school() -> String:
	if SpellData.SPELLS.has(spell):
		return SpellData.SPELLS[spell]["school"]
	return "Ice" if spell == "Blizzard" else "Fire"


## A shot touched the force wall: it turns around and now hurts the side that fired it.
func _on_force_area(area: Area2D) -> void:
	if area is EnemyBolt and team == "player":
		(area as EnemyBolt).reflect()
	elif area is SpellEffect and area.team != team and PROJECTILES.has(area.spell):
		var normal := Vector2(-sin(rotation), cos(rotation))
		var incoming: Vector2 = area._aim
		area.reflect(incoming - 2.0 * incoming.dot(normal) * normal)


## True when a point is in this spell's harm. The dark wizard uses it to step out of danger.
func danger_at(point: Vector2) -> bool:
	match spell:
		"Firewall":
			return absf(point.x - global_position.x) < 24.0 and absf(point.y - global_position.y) < FIREWALL_HEIGHT * 0.5 + 10.0
		"Icicles":
			return Geometry2D.is_point_in_polygon(point - global_position, polygon) or (point - global_position).length() < 24.0
	return false


## Force wall: the slashes are sprites; only a faint glow lies along the wall itself.
func _draw_force_wall(fade: float) -> void:
	Fx.draw_glow(self, Vector2.ZERO, 50.0, Color(0.7, 0.5, 1.0, 0.25 * fade))



## A solid stone slab. Enemies and shots collide with it; it is knocked down by a Push.
func _add_stone_slab(size: Vector2) -> void:
	var block := CollisionShape2D.new()
	var solid := RectangleShape2D.new()
	solid.size = size
	block.shape = solid
	var slab := StaticBody2D.new()
	slab.set_meta("stone_wall", true)
	slab.add_child(block)
	add_child(slab)
	# It rises out of the ground rather than appearing.
	scale = Vector2(0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Stone Wall: a slab of the biome's earth. It has health, and its face crumbles as it is struck.
func _draw_stone_wall() -> void:
	var ratio := _health / maxf(_max_health, 1.0)
	var stage := 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	var half := _wall_length * 0.5
	var corners := PackedVector2Array([Vector2(-half, -11), Vector2(half, -11), Vector2(half, 11), Vector2(-half, 11)])
	var uvs := PackedVector2Array()
	for corner in corners:
		uvs.append(corner / float(ArenaGen.TILE))  # the same scale as the ground, so the earth looks the same
	draw_polygon(corners, PackedColorArray([Color("#2a1f1a")]))  # the dark earth behind the face
	draw_polygon(corners, PackedColorArray([Color.WHITE]), uvs, _wall_stages[stage])


## The wall's health and its three faces, cut from the earth texture: whole, then with some of it knocked out.
func _build_wall() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_max_health = _wall_length * 0.45
	_health = _max_health
	var source := wall_texture.get_image()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_wall_stages.clear()
	for share in [0.0, 0.2, 0.5]:
		var face := source.duplicate()
		for i in int(share * face.get_width() * face.get_height() / 16.0):
			var x := rng.randi_range(0, face.get_width() - 4)
			var y := rng.randi_range(0, face.get_height() - 4)
			face.fill_rect(Rect2i(x, y, 4, 4), Color(0, 0, 0, 0))
		_wall_stages.append(ImageTexture.create_from_image(face))
	var strike_zone := Area2D.new()
	var zone := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(_wall_length, 22)
	zone.shape = box
	strike_zone.add_child(zone)
	strike_zone.collision_mask = 1  # enemy shots live on layer 1
	strike_zone.area_entered.connect(_on_wall_struck)
	add_child(strike_zone)


## An enemy shot that reaches the wall takes some of its health; the wall crumbles away when it has none left.
func _on_wall_struck(area: Area2D) -> void:
	var damage := 0
	if area is EnemyBolt:
		damage = (area as EnemyBolt)._damage
	elif area is SpellEffect and PROJECTILES.has(area.spell):
		damage = PROJECTILES[area.spell]["damage"]
	else:
		return
	_health -= damage
	if _health <= 0.0:
		Fx.debris(get_parent(), global_position, Color("#6b5a48"), 16, 220.0)
		Sfx.play("stones", global_position)
		GameCamera.shake_scene(get_tree(), 0.15)
		queue_free()
		return
	Fx.debris(get_parent(), area.global_position, Color("#6b5a48"), 5, 120.0)
	Sfx.play("stones", global_position, -6.0)
	queue_redraw()


## True when a point lies inside the Push circle.
func _in_force_zone(point: Vector2) -> bool:
	return point.distance_to(global_position) <= zone_radius


## Push moves everything inside the circle along the line drawn out of it: foes, the caster, dropped foci, shots,
## and stone walls (which fall).
func _apply_force_zone() -> void:
	for body in SpellTargets.all(get_tree(), team):
		var middle := SpellTargets.center_of(body)
		if not (_in_force_zone(middle) or _in_force_zone(body.global_position)):
			continue
		if body.is_in_group("mobs"):
			body.knock_back(_aim * KNOCK_SPEED * 1.6)  # the same lift as the player gets
		else:
			body.push(_aim * KNOCK_SPEED * 1.6)  # a push lifts the caster well above a jump (a jump is about 140 px; this is several times that)
	for item in get_tree().get_nodes_in_group("items"):
		if _in_force_zone(item.global_position):
			item.knock(_aim * KNOCK_SPEED * 0.6)
	for rock in get_tree().get_nodes_in_group("rocks"):
		if _in_force_zone(rock.global_position):
			rock.push(_aim * KNOCK_SPEED * 1.6)
	for node in get_parent().get_children():
		if node is EnemyBolt and _in_force_zone(node.global_position) and team == "player":
			node.push(_aim)
		elif node is SpellEffect and node != self and node.team != team and PROJECTILES.has(node.spell) and _in_force_zone(node.global_position):
			node.reflect(_aim)


## Push: gusts of wind flying out across the circle along the line (the ring is a sprite).
func _draw_push_zone() -> void:
	var fade := clampf(1.0 - _age / FORCE_ZONE_LIFE, 0.0, 1.0)
	var gust := PixelFx.frames("wind_bolt", 14.0, true)
	var frame := gust.get_frame_texture("default", int(_age * 14.0) % gust.get_frame_count("default"))
	for i in 3:
		var x := fmod(_age * 300.0 + i * zone_radius * 2.0 / 3.0, zone_radius * 2.0) - zone_radius
		draw_set_transform(Vector2(x, (i - 1) * zone_radius * 0.45), 0.0, Vector2.ONE * 2.0)
		draw_texture(frame, -frame.get_size() * 0.5, Color(0.85, 0.7, 1.0, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Icicles: the drawn triangle filled with pixel-art ice. It fades as it melts.
func _draw_icicle(fade: float) -> void:
	var uvs := PackedVector2Array()
	for p in polygon:
		uvs.append(p / ICE.get_size())
	draw_colored_polygon(polygon, Color(1, 1, 1, 0.95 * fade), uvs, ICE)


## Snowfall: pixel-art snow clouds along the top of the band, and pixel flakes drifting down through it, each a
## white square with a blue edge so it still shows against snow.
func _draw_snow(fade: float) -> void:
	var width := polygon[2].x
	var grow := clampf(_age / 0.4, 0.0, 1.0)
	var x := -10.0
	var i := 0
	while x < width + 10.0:
		var cloud: Texture2D = SNOW_CLOUDS[i % SNOW_CLOUDS.size()]
		var bob := roundf(sin(_age * 0.8 + i) * 2.0)
		draw_texture(cloud, Vector2(x, -60.0 - cloud.get_height() * 0.6 + bob), Color(1, 1, 1, fade * grow))
		x += cloud.get_width() * 0.7
		i += 1
	# A white wash from the top of the falling snow down to the ground under it, so the whole fall looks snowier.
	var wash := PackedVector2Array()
	for seg in _snow_floors.size():
		wash.append(Vector2(seg * SNOW_STEP, _snow_floors[seg]))
	for seg in range(_snow_floors.size() - 1, -1, -1):
		wash.append(Vector2(seg * SNOW_STEP, -50.0))
	draw_colored_polygon(wash, Color(1.0, 1.0, 1.0, 0.14 * fade * grow))
	var count := clampi(int(width * _snow_height() / 26.0), 30, 1400)  # a heavy fall: flakes by the area the snow covers
	for k in count:
		var fx := floorf(fmod(k * 37.0 + _age * 10.0, _wash_width()) + sin(_age * 2.0 + k) * 2.0)
		var column := clampi(int(fx / SNOW_STEP), 0, _snow_floors.size() - 1)
		var landing := _snow_floors[column] - _pile[column] if _pile.size() == _snow_floors.size() else _snow_floors[column]
		var fy := floorf(fmod(_age * 55.0 + k * 23.0, landing + 50.0) - 50.0)  # falls until it lands on the top of the pile
		var s := 2.0 + float(k % 2)
		var a := fade * grow * clampf((fy + 50.0) / 12.0, 0.0, 1.0)
		draw_rect(Rect2(fx - 1.0, fy - 1.0, s + 2.0, s + 2.0), Color(0.2, 0.36, 0.6, 0.8 * a))
		draw_rect(Rect2(fx, fy, s, s), Color(1, 1, 1, a))
	# The snow that has landed: a pile on the ground under the line, which fire melts.
	for seg in _pile.size():
		if _pile[seg] > 0.5:
			draw_rect(Rect2(seg * SNOW_STEP, _snow_floors[seg] - _pile[seg], SNOW_STEP + 1.0, _pile[seg]), Color(0.92, 0.96, 1.0, fade * grow))


## True when fire is touching this effect: a fire hazard, or a fire spell in flight.
func _fire_touches() -> bool:
	for node in get_parent().get_children():
		if node == self or not node is Node2D:
			continue
		var near := global_position.distance_to(node.global_position)
		if node is Hazard and node.kind == "fire" and near < 40.0 + node.width * 0.5:
			return true
		if node is SpellEffect and node.spell in ["Ignite", "Firewall"] and near < 40.0:
			return true
		if node is FireBreath:
			for puff in node._puffs:
				if puff["pos"].distance_to(global_position) < 30.0:
					return true
	return false


## The ground height (local) under the snow line, sampled every SNOW_STEP pixels across it.
func _snow_ground() -> PackedFloat32Array:
	var floors := PackedFloat32Array()
	var x := 0.0
	while x <= _cloud_right():
		floors.append(SpellTargets.solid_below(get_world_2d(), global_position + Vector2(x, -40)).y - global_position.y)
		x += SNOW_STEP
	return floors


## How far the snow falls on average, from the line to the ground.
func _snow_height() -> float:
	var total := 0.0
	for f in _snow_floors:
		total += f + 50.0
	return total / maxf(float(_snow_floors.size()), 1.0)


## Snow that lands builds up on the ground under the line; fire near the snow melts it.
func _grow_pile(delta: float) -> void:
	if _pile.size() != _snow_floors.size():
		_pile.resize(_snow_floors.size())
		_pile.fill(0.0)
	var cloud_bottom := -60.0 + 0.4 * _cloud_height()
	# Snow falls onto every stretch under the clouds, and what lands slides downhill until its slope is no steeper than REPOSE.
	for seg in _pile.size():
		_pile[seg] = minf(_pile[seg] + PILE_GROW * delta, maxf(_snow_floors[seg] - cloud_bottom, 0.0))
	for seg in range(_pile.size() - 1):
		var drop := _pile[seg] - _pile[seg + 1]
		if absf(drop) > REPOSE:
			var flow := (absf(drop) - REPOSE) * 0.25
			if drop > 0.0:
				_pile[seg] -= flow
				_pile[seg + 1] += flow
			else:
				_pile[seg + 1] -= flow
				_pile[seg] += flow
	# Each flame melts the snow within a radius of itself, most where it is hottest, and no stretch melts faster than
	# the hottest flame over it.
	var melt := PackedFloat32Array()
	melt.resize(_pile.size())
	melt.fill(0.0)
	for source in _fire_over_snow():
		var at_x: float = source[0]
		var strength: float = source[1]
		for seg in _pile.size():
			var distance := absf(seg * SNOW_STEP - at_x)
			if distance < MELT_RADIUS:
				melt[seg] = maxf(melt[seg], strength * (1.0 - distance / MELT_RADIUS))
	for seg in _pile.size():
		_pile[seg] = maxf(_pile[seg] - melt[seg] * delta, 0.0)
	if _pile_body == null:
		_build_pile_body()
	_pile_timer -= delta
	if _pile_timer <= 0.0:
		_pile_timer = 0.1
		_sync_pile_body()


## The width the white wash covers, which is where the snow falls.
func _wash_width() -> float:
	return maxf((_snow_floors.size() - 1) * SNOW_STEP, 1.0)


## How tall the clouds are: the tallest of the snow clouds drawn above the line.
func _cloud_height() -> float:
	var tallest := 0.0
	for cloud in SNOW_CLOUDS:
		tallest = maxf(tallest, cloud.get_height())
	return tallest



## A StaticBody for the landed snow: one solid stretch per segment, which follows the height of the pile.
func _build_pile_body() -> void:
	_pile_body = StaticBody2D.new()
	_pile_body.collision_layer = 1  # solid, like the ground: walkers and the player stand on it
	_pile_body.collision_mask = 0
	add_child(_pile_body)
	for seg in _snow_floors.size():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(SNOW_STEP, 1.0)
		shape.shape = box
		shape.disabled = true
		_pile_body.add_child(shape)
		_pile_shapes.append(shape)


func _sync_pile_body() -> void:
	for seg in _pile_shapes.size():
		var shape: CollisionShape2D = _pile_shapes[seg]
		var height: float = _pile[seg]
		shape.disabled = height < 1.0
		if not shape.disabled:
			(shape.shape as RectangleShape2D).size = Vector2(SNOW_STEP, height)
			shape.position = Vector2(seg * SNOW_STEP + SNOW_STEP * 0.5, _snow_floors[seg] - height * 0.5)


## The fire over the snow band, as [x along the line, how fast it melts]: a fireball melts hard, fire that stays melts slower.
func _fire_over_snow() -> Array:
	var sources := []
	# Fire counts from up to 40 px beyond the snow on any side, so fire touching the side of a pile melts it too.
	var left := global_position.x - 50.0
	var right := global_position.x + polygon[2].x + 50.0
	var top := global_position.y - 100.0
	var bottom := global_position.y + 130.0
	for node in get_parent().get_children():
		if node == self or not node is Node2D:
			continue
		var at: Vector2 = node.global_position
		if at.x < left or at.x > right or at.y < top or at.y > bottom:
			continue
		if node is Hazard and node.kind == "fire":
			sources.append([at.x - global_position.x, PILE_MELT])
		elif node is SpellEffect and node.spell == "Ignite":
			sources.append([at.x - global_position.x, PILE_MELT * 3.0])
		elif node is SpellEffect and node.spell == "Firewall":
			sources.append([at.x - global_position.x, PILE_MELT])
		elif node is FireBreath:
			for puff in node._puffs:
				var pos: Vector2 = puff["pos"]
				if pos.x >= left and pos.x <= right and pos.y >= top and pos.y <= bottom:
					sources.append([pos.x - global_position.x, PILE_MELT])
	return sources


## The right edge of the snow clouds as they are drawn: the snow falls no further than this.
func _cloud_right() -> float:
	var x := -10.0
	var i := 0
	var edge := 0.0
	while x < polygon[2].x + 10.0:
		var cloud: Texture2D = SNOW_CLOUDS[i % SNOW_CLOUDS.size()]
		edge = x + cloud.get_width()
		x += cloud.get_width() * 0.7
		i += 1
	return maxf(edge, polygon[2].x)
