class_name SpellEffect
extends Area2D

## World effect for a resolved spell. Projectiles fly and hit the first mob or wall;
## area spells act on whatever is inside them. Mobs are found through the "mobs" group.
## Each school looks different: fire flickers and rises, ice is a sharp shard that shatters,
## a circle of force shoves everything inside it along the line drawn out of the circle (Push).

signal broke

const PROJECTILES := {
	"Ignite": {"speed": 700.0, "damage": 12, "life": 2.0, "color": Color("#ff7a2a")},
	"Frostbolt": {"speed": 600.0, "damage": 6, "life": 2.0, "color": Color("#b8f0ff")},
}
const STONEFALL_DAMAGE := 30
const STONEFALL_RADIUS := 60.0
const STONEFALL_DELAY := 0.6
const FORCE_WALL_KNOCK := 300.0
const FORCE_ZONE_LIFE := 0.5
const FIREWALL_TICK := 0.5
const FIREWALL_DAMAGE := 4
const CINDERBURST_DAMAGE := 25
const SPARK_DAMAGE := 20
const KNOCK_SPEED := 700.0
const SLOW_SECONDS := 2.0
const ICICLE_LIFE := 4.0  # an icicle stands this long, then melts
const ICICLE_TICK := 0.5
const ICICLE_DAMAGE := 6
const SNOW_LIFE := 6.0
const BOLT_REFRESH := 0.04  # how often the lightning re-forms, which makes it flicker

var spell := ""
var _aim := Vector2.RIGHT
var _age := 0.0
var _life := 1.0
var _tick := 0.0
var _burst_done := false
var _spent := false
var zone_radius := 40.0  # the Push circle's radius, set by the caster from the drawn circle
var _bolt := PackedVector2Array()  # jagged lightning path, re-formed while Spark is on screen
var _bolt_timer := 0.0
var _trail: CPUParticles2D
var polygon := PackedVector2Array()  # local outline for icicles and the snow band, set by the arena before setup


func setup(spell_name: String, origin: Vector2, aim_angle: float) -> void:
	spell = spell_name
	global_position = origin
	_aim = Vector2.from_angle(aim_angle)
	material = _glow_material()
	collision_mask = 7  # terrain, mobs and the player, so every spell can hit any of them
	var shape := CollisionShape2D.new()
	if PROJECTILES.has(spell):
		rotation = aim_angle
		_life = PROJECTILES[spell]["life"]
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 10)
		shape.shape = rect
		body_entered.connect(_on_projectile_hit)
		_trail = _make_trail()
		if _trail:
			add_child(_trail)
	else:
		match spell:
			"Icicles":
				# Ice where it was drawn. It hurts what walks through it, then melts.
				_life = ICICLE_LIFE
				var icicle := ConvexPolygonShape2D.new()
				icicle.points = polygon
				shape.shape = icicle
			"Snowfall":
				# A band of snow along the drawn line. It slows whatever is inside.
				_life = SNOW_LIFE
				var snow_band := ConvexPolygonShape2D.new()
				snow_band.points = polygon
				shape.shape = snow_band
			"Firewall":
				# Burns mobs pressing on it, and blocks them physically like a wall.
				_life = 4.0
				var rect := RectangleShape2D.new()
				rect.size = Vector2(26, 124)  # a bit wider than the wall, so mobs pressing on it are caught
				shape.shape = rect
				_add_solid_block(Vector2(20, 120))
				_add_flame_column(Vector2(10, 60), 40, Vector2(0, -80))
			"Cinderburst":
				_life = 0.5
				var circle := CircleShape2D.new()
				circle.radius = 70.0
				shape.shape = circle
				Fx.burst(get_parent(), origin, PROJECTILES.get("Ignite")["color"], 60, 260.0, 0.6)
			"Push":
				# A circle of force: everything inside it is shoved once, along the line drawn out of the circle.
				_life = FORCE_ZONE_LIFE
				rotation = aim_angle
			"Stone Wall":
				# A solid slab that rises along the stroke from the ground and stays until a Push knocks it down.
				_life = 99999.0
				rotation = aim_angle
				global_position = origin + Vector2.from_angle(aim_angle) * 70.0
				_add_stone_slab(Vector2(140, 18))
			"Force Wall":
				# A short-lived wall of force: it shoves foes off it and bats enemy bolts back.
				_life = 0.8  # a quick flash of force: the timing is the challenge
				var force_rect := RectangleShape2D.new()
				force_rect.size = Vector2(124, 26)  # long along the slash, so it deflects along its angle
				rotation = aim_angle
				shape.shape = force_rect
				area_entered.connect(_on_force_area)
			"Stonefall":
				# A boulder that falls onto the middle of the triangle after a short delay.
				_life = STONEFALL_DELAY + 0.6
				global_position = Vector2(origin.x, 164.0)  # the boulder lands on the floor under the stroke
			"Spark":
				# A strike from above: it lands straight down through the x position of the stroke.
				_life = 0.35
				global_position = Vector2(origin.x, 0.0)
				var rect := RectangleShape2D.new()
				rect.size = Vector2(14, 600)
				shape.shape = rect
				_bolt = _make_bolt()
				Fx.burst(get_parent(), Vector2(origin.x, 176.0), Color("#ffe85a"), 30, 240.0, 0.4)
	add_child(shape)


## The trail behind a projectile. Ice leaves drifting snow; fire leaves rising embers.
func _make_trail() -> CPUParticles2D:
	var trail: CPUParticles2D
	match spell:
		"Frostbolt":
			# Plain white snowflakes that fall away. No glow.
			trail = Fx.trail(Color("#ffffff"), 30, 0.6, 30.0, Vector2(0, 60))
			trail.scale_amount_min = 0.5
			trail.scale_amount_max = 1.0
		_:
			trail = Fx.trail(Color("#ffb040"), 90, 0.3, 25.0, Vector2(0, -50))
			trail.scale_amount_max = 2.5
	if _glow_material() == null:
		trail.material = null
	return trail


## Fire and the glowing spells add light to what's behind them. Ice and force are solid, with no glow.
func _glow_material() -> CanvasItemMaterial:
	if spell in ["Frostbolt", "Push", "Icicles", "Snowfall", "Force Wall", "Stonefall", "Stone Wall"]:
		return null
	return Fx.additive()


## A solid body that mobs and projectiles collide with. It doesn't detect anything.
func _add_solid_block(size: Vector2) -> void:
	var block := CollisionShape2D.new()
	var solid := RectangleShape2D.new()
	solid.size = size
	block.shape = solid
	var wall := StaticBody2D.new()
	wall.collision_layer = 8  # its own layer: mobs are blocked by it, the player walks through
	wall.add_child(block)
	add_child(wall)


## Embers rising off a fire area. The emitter is a child so it moves with the spell.
func _add_flame_column(extents: Vector2, amount: int, gravity: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 12.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = gravity
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.texture = Fx.dot_texture()
	p.color_ramp = Fx.fade_ramp(Color(1.0, 0.6, 0.15))
	p.material = Fx.additive()
	add_child(p)
	p.emitting = true


## Zigzag from the top of the sky down to the ground, jittered sideways at each step.
func _make_bolt() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y := -300.0
	while y < 190.0:
		pts.append(Vector2(randf_range(-12.0, 12.0), y))
		y += 40.0
	pts.append(Vector2(0.0, 190.0))
	return pts


func _draw() -> void:
	var fade := clampf(1.0 - _age / _life, 0.0, 1.0)
	match spell:
		"Ignite":
			_draw_fireball()
		"Frostbolt":
			_draw_shard()
		"Push":
			_draw_push_zone()
		"Icicles":
			_draw_icicle(fade)
		"Snowfall":
			_draw_snow(fade)
		"Firewall":
			_draw_firewall(fade)
		"Cinderburst":
			_draw_shockwave(fade)
		"Spark":
			_draw_lightning(fade)
		"Force Wall":
			_draw_force_wall(fade)
		"Stone Wall":
			_draw_stone_wall()
		"Stonefall":
			_draw_boulder()
## Fire: a hot flickering core with flame tongues trailing behind it.
func _draw_fireball() -> void:
	var flick := sin(_age * 25.0) * 1.5
	for i in 3:
		var length := 14.0 + i * 6.0 + flick
		var half_width := 4.0 - i
		var tail := PackedVector2Array([Vector2(-length, 0), Vector2(-6, -half_width), Vector2(-6, half_width)])
		draw_colored_polygon(tail, Color(1.0, 0.55 - i * 0.15, 0.1, 0.5 - i * 0.12))
	# A tight glow: a bright core inside a soft edge.
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.5, 0.15, 0.15))
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.6, 0.2, 0.7))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.97, 0.7, 0.95))


## Ice: a sharp, faceted shard that points along its flight. It's cold and still, not flickering.
func _draw_shard() -> void:
	var ice: Color = PROJECTILES["Frostbolt"]["color"]
	var body := PackedVector2Array([
		Vector2(16, 0), Vector2(-2, -5), Vector2(-11, -2), Vector2(-13, 0), Vector2(-11, 2), Vector2(-2, 5),
	])
	draw_colored_polygon(body, Color(ice.r, ice.g, ice.b, 0.85))
	# Facet lines down the middle and along each side make it look cut from crystal.
	draw_line(Vector2(16, 0), Vector2(-9, 0), Color(1, 1, 1, 0.9), 1.0)
	draw_line(Vector2(-2, -5), Vector2(-9, 0), Color(0.9, 1.0, 1.0, 0.7), 1.0)
	draw_line(Vector2(-2, 5), Vector2(-9, 0), Color(0.9, 1.0, 1.0, 0.7), 1.0)


func _draw_firewall(fade: float) -> void:
	# A glowing core with flame tongues flicking out from both sides.
	draw_rect(Rect2(-10, -60, 20, 120), Color(1.0, 0.45, 0.1, 0.35 * fade))
	draw_rect(Rect2(-4, -60, 8, 120), Color(1.0, 0.9, 0.4, 0.45 * fade))
	for i in 12:
		var y := -58.0 + i * 10.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var length := 9.0 + 7.0 * sin(_age * 10.0 + i * 2.1)
		var base := Vector2(side * 10.0, y)
		var tip := base + Vector2(side * length, -5.0 - 3.0 * sin(_age * 7.0 + i))
		draw_line(base, tip, Color(1.0, 0.55, 0.15, 0.85 * fade), 3.0)
		draw_circle(tip, 2.0, Color(1.0, 0.9, 0.5, 0.9 * fade))


func _draw_shockwave(fade: float) -> void:
	var radius := 70.0 * minf(1.0, _age / 0.25)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.15, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, fade), 4.0)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, fade * 0.7), 2.0)
	if _age < 0.2:
		draw_circle(Vector2.ZERO, 26.0 * (1.0 - _age / 0.2), Color(1.0, 0.95, 0.8, 0.9))


func _draw_lightning(fade: float) -> void:
	# Three layers: a wide soft glow, a brighter sheath, and a white-hot core.
	draw_polyline(_bolt, Color(1.0, 0.95, 0.4, 0.18 * fade), 14.0)
	draw_polyline(_bolt, Color(1.0, 1.0, 0.6, 0.5 * fade), 6.0)
	draw_polyline(_bolt, Color(1.0, 1.0, 1.0, fade), 2.0)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if PROJECTILES.has(spell):
		var speed: float = PROJECTILES[spell]["speed"]
		position += _aim * speed * delta
	if spell == "Spark":
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt = _make_bolt()
			_bolt_timer = BOLT_REFRESH
	match spell:
		"Firewall":
			_tick -= delta
			if _tick <= 0.0:
				_tick = FIREWALL_TICK
				_damage_overlapping(_area_tick_damage())
				for body in get_overlapping_bodies():
					if body.is_in_group("player"):
						body.take_damage(FIREWALL_DAMAGE)
		"Cinderburst":
			# Wait one physics frame so overlaps are registered before the burst.
			if not _burst_done and _age > 0.05:
				_burst_done = true
				_damage_overlapping(CINDERBURST_DAMAGE)
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
				if body.is_in_group("mobs"):
					body.apply_slow(0.3)
		"Force Wall":
			# Shove any mob standing against the wall away from it, a few times a second.
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.3
				_push_overlapping_mobs()
		"Push":
			if not _burst_done and _age > 0.05:
				_burst_done = true
				_apply_force_zone()
		"Stonefall":
			if not _burst_done and _age >= STONEFALL_DELAY:
				_burst_done = true
				_damage_within(global_position, STONEFALL_RADIUS, STONEFALL_DAMAGE)
				Shatter.spawn(get_parent(), global_position, Color("#b8864a"))
	if _age >= _life:
		_finish()


func _on_projectile_hit(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	# A stone wall stops anything.
	if body.has_meta("stone_wall"):
		_finish()
		return
	if _spent:
		return
	_spent = true
	# Ice shatters into shards; fire bursts into sparks.
	if spell == "Frostbolt":
		Shatter.spawn(get_parent(), global_position, PROJECTILES[spell]["color"])
	else:
		Fx.burst(get_parent(), global_position, PROJECTILES[spell]["color"], 14, 140.0, 0.35)
	if body.is_in_group("mobs"):
		var damage: int = PROJECTILES[spell]["damage"]
		if damage > 0:
			body.take_damage(damage, _school())
		if spell == "Frostbolt":
			body.apply_slow(SLOW_SECONDS)
	_finish()

func _area_tick_damage() -> int:
	return FIREWALL_DAMAGE


func _damage_overlapping(amount: int) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("mobs"):
			body.take_damage(amount, _school())


## Ends the effect. A projectile's trail is let go to finish fading rather than vanishing with it.
func _finish() -> void:
	if _trail:
		var trail := _trail
		_trail = null
		trail.emitting = false
		trail.reparent(get_parent())
		get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
	queue_free()


## The school this spell belongs to, which decides what mobs resist or are weak to.
func _school() -> String:
	if SpellData.SPELLS.has(spell):
		return SpellData.SPELLS[spell]["school"]
	return "Fire"  # the fire the old chant used to make is gone; nothing else falls through to here


## An enemy bolt touched the force wall: it turns around and now hurts enemies.
func _on_force_area(area: Area2D) -> void:
	if area is EnemyBolt:
		(area as EnemyBolt).reflect()


## Shoves every mob standing against the force wall, away from its centre line.
func _push_overlapping_mobs() -> void:
	var normal := Vector2(-sin(rotation), cos(rotation))  # perpendicular to the slash
	for body in get_overlapping_bodies():
		if body.is_in_group("mobs"):
			var side := 1.0 if (body.global_position - global_position).dot(normal) >= 0.0 else -1.0
			body.knock_back(normal * side * FORCE_WALL_KNOCK)


## Damages every mob within a radius of a point.
func _damage_within(point: Vector2, radius: float, amount: int) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob.global_position.distance_to(point) <= radius:
			mob.take_damage(amount, _school())


## Force wall: a violet band lying along the slash, crisp edges and a shimmer running along it. It fades as it runs out.
func _draw_force_wall(fade: float) -> void:
	var violet := Color("#b07cff")
	draw_rect(Rect2(-62, -10, 124, 20), Color(violet.r, violet.g, violet.b, 0.22 * fade))
	draw_line(Vector2(-62, -10), Vector2(62, -10), Color(violet.r, violet.g, violet.b, fade), 2.0)
	draw_line(Vector2(-62, 10), Vector2(62, 10), Color(violet.r, violet.g, violet.b, fade), 2.0)
	var shimmer_x := -62.0 + fmod(_age * 160.0, 124.0)
	draw_line(Vector2(shimmer_x, -10), Vector2(shimmer_x, 10), Color(1.0, 1.0, 1.0, 0.5 * fade), 2.0)


## Stonefall: the boulder drops onto the spot, then a dust ring spreads out where it lands.
func _draw_boulder() -> void:
	var stone := Color("#8a6a40")
	if _age < STONEFALL_DELAY:
		var t := _age / STONEFALL_DELAY
		var y := lerpf(-220.0, 0.0, t * t)
		draw_circle(Vector2(0, y), 16.0, stone)
		draw_arc(Vector2(0, y), 16.0, 0.0, TAU, 24, Color("#4a3418"), 2.0)
		draw_line(Vector2(-6, y - 4), Vector2(2, y + 3), Color("#4a3418"), 1.5)
		draw_line(Vector2(3, y - 8), Vector2(7, y - 2), Color("#4a3418"), 1.5)
	else:
		var t := clampf((_age - STONEFALL_DELAY) / 0.6, 0.0, 1.0)
		draw_arc(Vector2.ZERO, STONEFALL_RADIUS * t, 0.0, TAU, 36, Color(0.72, 0.55, 0.32, 1.0 - t), 3.0)


## A solid stone slab. Mobs and projectiles collide with it; it is knocked down by a Push.
func _add_stone_slab(size: Vector2) -> void:
	var block := CollisionShape2D.new()
	var solid := RectangleShape2D.new()
	solid.size = size
	block.shape = solid
	var slab := StaticBody2D.new()
	slab.set_meta("stone_wall", true)
	slab.add_child(block)
	add_child(slab)


## Knocked down by a Push: the slab stops blocking, tips over, and fades away.
func topple() -> void:
	for child in get_children():
		if child is StaticBody2D:
			child.get_child(0).set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + PI / 2.0, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


## Stone Wall: an earth-brown slab of stone blocks with dark mortar lines. Crisp, no glow.
func _draw_stone_wall() -> void:
	draw_rect(Rect2(-70, -9, 140, 18), Color("#a0744a"))
	draw_rect(Rect2(-70, -9, 140, 3), Color("#c89a64"))
	draw_rect(Rect2(-70, 6, 140, 3), Color("#6b4a2b"))
	for x in [-42.0, -14.0, 14.0, 42.0]:
		draw_line(Vector2(x, -9), Vector2(x, 9), Color("#5a4026"), 1.5)
	draw_rect(Rect2(-70, -9, 140, 18), Color("#3a2818"), false, 1.5)


## True when a point lies inside the Push circle.
func _in_force_zone(point: Vector2) -> bool:
	return point.distance_to(global_position) <= zone_radius


## Push moves everything inside the circle along the line drawn out of it: foes, the caster, dropped foci, enemy bolts, and stone walls (which fall).
func _apply_force_zone() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if _in_force_zone(mob.global_position):
			mob.knock_back(_aim * KNOCK_SPEED)
	var player = get_tree().get_first_node_in_group("player")
	if player and (_in_force_zone(player.global_position) or _in_force_zone(player.global_position + Vector2(0, -30))):
		player.push(_aim * KNOCK_SPEED)
	for item in get_tree().get_nodes_in_group("items"):
		if _in_force_zone(item.global_position):
			item.knock(_aim * KNOCK_SPEED * 0.6)
	for node in get_parent().get_children():
		if node is SpellEffect and node.spell == "Stone Wall" and _in_force_zone(node.global_position):
			node.topple()
		elif node is EnemyBolt and _in_force_zone(node.global_position):
			node.push(_aim)


## Push: the circle's outline, with chevrons sliding out along the line. Crisp, no glow.
func _draw_push_zone() -> void:
	var purple := Color("#b07cff")
	var fade := clampf(1.0 - _age / FORCE_ZONE_LIFE, 0.0, 1.0)
	draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 48, Color(purple.r, purple.g, purple.b, 0.8 * fade), 2.0)
	for i in 3:
		var x := fmod(_age * 240.0 + i * zone_radius * 2.0 / 3.0, zone_radius * 2.0) - zone_radius
		var chevron := PackedVector2Array([Vector2(x - 8, -12), Vector2(x + 8, 0), Vector2(x - 8, 12)])
		draw_polyline(chevron, Color(purple.r, purple.g, purple.b, fade), 2.0)


## Icicles: a pale spike with a bright edge. It fades as it melts.
func _draw_icicle(fade: float) -> void:
	draw_colored_polygon(polygon, Color(0.78, 0.95, 1.0, 0.85 * fade))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color(0.3, 0.62, 0.82, fade), 1.5)


## Snowfall: small flakes drift down through the band. Crisp dots, no glow.
func _draw_snow(fade: float) -> void:
	var width := polygon[2].x
	for i in 40:
		var x := fmod(i * 37.0 + _age * 10.0, width)
		var y := fmod(_age * 50.0 + i * 23.0, 120.0) - 60.0
		draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, 0.8 * fade))
