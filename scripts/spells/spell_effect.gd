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
const STONEFALL_DAMAGE := 30
const STONEFALL_RADIUS := 60.0
const STONEFALL_DELAY := 0.6
const FORCE_ZONE_LIFE := 0.5
const FIREWALL_TICK := 0.5
const FIREWALL_DAMAGE := 4
const FIREWALL_HEIGHT := 120.0
const SPARK_DAMAGE := 20
const SPARK_SKY := 420.0  # the strike starts this far above where it lands
const KNOCK_SPEED := 700.0
const SLOW_SECONDS := 2.0
const FIREBALL_KNOCK := 420.0  # how hard a fireball pushes what it hits
const ICICLE_LIFE := 4.0  # an icicle stands this long, then melts
const ICICLE_TICK := 0.5
const ICICLE_DAMAGE := 6
const SNOW_LIFE := 6.0
const STONE_WALL_LENGTH := 140.0
# Images drawn every frame are held here, so they stay loaded between frames.
const ROCK := preload("res://art/fx/rock.png")
const STONE := preload("res://art/tiles/stone.png")
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
				texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var icicle := ConvexPolygonShape2D.new()
				icicle.points = polygon
				shape.shape = icicle
				add_to_group("danger")
				Sfx.play("ice_shatter", origin, 2.0)
				Fx.burst(get_parent(), origin, Color("#dff6ff"), 8, 80.0, 0.4, true, "star_04")
			"Snowfall":
				# A band of snow along the drawn line. It slows whatever is inside.
				_life = SNOW_LIFE
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
				PixelFx.play(get_parent(), global_position + Vector2(0, FIREWALL_HEIGHT * 0.5), "blast_fire", 20.0, 1.0, Color.WHITE, true)
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
				global_position = origin + Vector2.from_angle(aim_angle) * STONE_WALL_LENGTH * 0.5
				_add_stone_slab(Vector2(STONE_WALL_LENGTH, 22))
				Sfx.play("earth", origin)
				Fx.debris(get_parent(), origin, Color("#a08060"), 10, 200.0)
				GameCamera.shake_scene(get_tree(), 0.2)
			"Force Wall":
				# A short-lived wall of force that only touches shots: it bats them back. Characters pass through it.
				_life = 0.8  # a quick flash of force: the timing is the challenge
				var force_rect := RectangleShape2D.new()
				force_rect.size = Vector2(124, 26)  # long along the slash, so it deflects along its angle
				rotation = aim_angle
				shape.shape = force_rect
				collision_mask = 1  # shots live on layer 1; characters (layers 2 and 4) are never touched
				area_entered.connect(_on_force_area)
				for side in [-1.0, 1.0]:
					var slash := PixelFx.sprite("slash", 76.0, false)
					slash.scale = Vector2(1.0 * side, 1.0)
					slash.rotation = PI * 0.5
					slash.position = Vector2(side * 30.0, 0)
					slash.material = Fx.additive()
					add_child(slash)
				Sfx.play("force", origin)
			"Stonefall":
				# A boulder that drops onto the ground under the stroke after a short delay.
				_life = STONEFALL_DELAY + 0.6
				global_position = SpellTargets.ground_below(get_world_2d(), origin + Vector2(0, -40))
				add_to_group("danger")
				Sfx.play("stones", global_position, -4.0)
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
func _make_trail() -> CPUParticles2D:
	var trail: CPUParticles2D
	match spell:
		"Frostbolt":
			# Drawn normally rather than as light, and a little blue, so the snow shows up against a snowy level.
			trail = Fx.trail(Color("#a9dcff"), 36, 0.55, 30.0, Vector2(0, 60), "star_04", 12.0)
			trail.material = null
		_:
			trail = Fx.trail(Color("#ff9a40"), 60, 0.35, 25.0, Vector2(0, -60), "flame_05", 12.0)
			trail.angle_min = -180.0
			trail.angle_max = 180.0
	return trail


## Fire and lightning add light to what's behind them. Ice, force and stone are solid, with no glow.
func _glow_material() -> CanvasItemMaterial:
	if spell in ["Frostbolt", "Push", "Icicles", "Snowfall", "Force Wall", "Stonefall", "Stone Wall"]:
		return null
	return Fx.additive()


## The firewall is three pixel-art flames stacked on each other, each burning out of step with the others, with
## embers rising off it.
func _add_flames() -> void:
	for i in 3:
		var flame := PixelFx.sprite("flame", 26.0 + i * 4.0)
		flame.offset = Vector2(0, -PixelArt.FX["flame"]["size"].y * 0.5)
		flame.position = Vector2(0, FIREWALL_HEIGHT * 0.5 + 4.0 - i * 42.0)
		flame.flip_h = i == 1
		flame.frame = i * 17
		flame.z_index = 1 - i
		add_child(flame)
	var p := Fx.trail(Color(1.0, 0.55, 0.2), 24, 0.8, 20.0, Vector2(0, -60), "spark_01", 6.0)
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
		"Snowfall":
			_draw_snow(fade)
		"Firewall":
			_draw_firewall(fade)
		"Force Wall":
			_draw_force_wall(fade)
		"Stone Wall":
			_draw_stone_wall()
		"Stonefall":
			_draw_boulder()


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
			_tick -= delta
			if _tick <= 0.0:
				_tick = ICICLE_TICK
				_damage_overlapping(ICICLE_DAMAGE)
		"Snowfall":
			for body in get_overlapping_bodies():
				if not SpellTargets.affects(body, team):
					continue
				if body.is_in_group("mobs"):
					body.apply_slow(0.3)
				else:
					body.apply_debuff("slow", 0.3)
		"Push":
			if not _burst_done and _age > 0.05:
				_burst_done = true
				_apply_force_zone()
		"Stonefall":
			if not _burst_done and _age >= STONEFALL_DELAY:
				_burst_done = true
				SpellTargets.hurt_within(get_tree(), global_position + Vector2(0, -20), STONEFALL_RADIUS, STONEFALL_DAMAGE, "Earth", team)
				Fx.debris(get_parent(), global_position, Color("#9c7a52"), 12, 200.0)
				Fx.smoke(get_parent(), global_position, Color(0.45, 0.38, 0.3, 0.5), 5, 30.0, 30.0)
				Sfx.play("quake", global_position)
				GameCamera.shake_scene(get_tree(), 0.5)
	if _age >= _life:
		_finish()


func _on_projectile_hit(body: Node2D) -> void:
	if body.is_in_group("player"):
		# A shot does not hit its own caster right after it leaves.
		if team == "enemy" or _age > 0.15:
			if not _spent:
				_spent = true
				body.take_damage(PROJECTILES[spell]["damage"])
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
	return "Ice" if spell == "Snowfall" else "Fire"


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
		"Stonefall":
			return not _burst_done and point.distance_to(global_position) < STONEFALL_RADIUS + 10.0
	return false


## Force wall: the slashes are sprites; only a faint glow lies along the wall itself.
func _draw_force_wall(fade: float) -> void:
	Fx.draw_glow(self, Vector2.ZERO, 50.0, Color(0.7, 0.5, 1.0, 0.25 * fade))


## Stonefall: a shadow grows on the ground as the boulder drops onto it, then the dust ring spreads out.
func _draw_boulder() -> void:
	var rock: Texture2D = ROCK
	if _age < STONEFALL_DELAY:
		var t := _age / STONEFALL_DELAY
		var shadow := 10.0 + 22.0 * t
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, shadow, Color(0, 0, 0, 0.35 * t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var y := lerpf(-320.0, -18.0, t * t)
		draw_set_transform(Vector2(0, y), floorf(t * 8.0) * PI * 0.5, Vector2.ONE * 3.0)
		draw_texture(rock, -rock.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var t := clampf((_age - STONEFALL_DELAY) / 0.6, 0.0, 1.0)
		draw_set_transform(Vector2(0, -24.0), 0.0, Vector2.ONE * 3.0)
		draw_texture(rock, -rock.get_size() * 0.5, Color(1, 1, 1, 1.0 - t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## Knocked down by a Push: the slab stops blocking, tips over, and fades away.
func topple() -> void:
	for child in get_children():
		if child is StaticBody2D:
			child.get_child(0).set_deferred("disabled", true)
	Sfx.play("stones", global_position)
	Fx.debris(get_parent(), global_position, Color("#a08060"), 8, 160.0)
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + PI / 2.0, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## Stone Wall: a slab cut from the same stone as the arena's pillars, with a dark outline. Crisp, no glow.
func _draw_stone_wall() -> void:
	var stone: Texture2D = STONE
	var source := Rect2(Terrain.ATLAS_CELL + Terrain.ATLAS_PAD, Terrain.ATLAS_CELL + Terrain.ATLAS_PAD, Terrain.ATLAS_TILE, Terrain.ATLAS_TILE)
	var half := STONE_WALL_LENGTH * 0.5
	var blocks := 6
	var w := STONE_WALL_LENGTH / blocks
	for i in blocks:
		draw_texture_rect_region(stone, Rect2(-half + i * w, -11, w, 22), source, Color(0.92, 0.9, 0.95))
		draw_line(Vector2(-half + i * w, -11), Vector2(-half + i * w, 11), Color("#3a3640"), 1.0)
	draw_rect(Rect2(-half, -11, STONE_WALL_LENGTH, 4), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(-half, -11, STONE_WALL_LENGTH, 22), Color("#2b2730"), false, 2.0)


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
			body.knock_back(_aim * KNOCK_SPEED)
		else:
			body.push(_aim * KNOCK_SPEED)
	for item in get_tree().get_nodes_in_group("items"):
		if _in_force_zone(item.global_position):
			item.knock(_aim * KNOCK_SPEED * 0.6)
	for node in get_parent().get_children():
		if node is SpellEffect and node.spell == "Stone Wall" and _in_force_zone(node.global_position):
			node.topple()
		elif node is EnemyBolt and _in_force_zone(node.global_position) and team == "player":
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
	var count := clampi(int(width / 4.0), 24, 90)
	for k in count:
		var fx := floorf(fmod(k * 37.0 + _age * 10.0, width) + sin(_age * 2.0 + k) * 5.0)
		var fy := floorf(fmod(_age * 55.0 + k * 23.0, 110.0) - 50.0)
		var s := 2.0 + float(k % 2)
		var a := fade * grow * clampf((fy + 50.0) / 12.0, 0.0, 1.0)
		draw_rect(Rect2(fx - 1.0, fy - 1.0, s + 2.0, s + 2.0), Color(0.2, 0.36, 0.6, 0.8 * a))
		draw_rect(Rect2(fx, fy, s, s), Color(1, 1, 1, a))
