class_name Flames
extends RefCounted

## Fire that spreads over something: a burning plant, a patch of burning ground, a lake of lava. The flames are the same pixel flame as
## everywhere else, but they are scattered the way a real fire is: no two the same size, none the same height, none leaning the same way,
## taller toward the middle and ragged at the edges, in front of and behind one another, with a glow under them and embers rising.

const FLAME := "fire_puff"


## Lays a fire over an area (a box in world space) as a child of `host`, and returns it, so that it can be faded or freed with the host.
## `reach` is how tall the tallest flames stand above the area's bottom edge (they may stand taller than the area); `crowd` is how thickly
## they grow: 1 is the usual. The same seed is the same fire.
static func lay(host: Node2D, area: Rect2, seed_value: int, reach := 0.0, crowd := 1.0) -> Node2D:
	var fire := Node2D.new()
	host.add_child(fire)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tall := maxf(reach, area.size.y * 0.8)
	var count := clampi(roundi((area.size.x / 11.0) * (0.9 + area.size.y / 90.0) * crowd), 3, 60)
	var stand := PixelArt.FX[FLAME]["size"].y
	# Flames are laid from the back to the front: those toward the top are behind.
	var spots: Array[Vector2] = []
	for k in count:
		var u := rng.randf()
		var rise := pow(rng.randf(), 1.5)  # most stand low, a few high
		spots.append(Vector2(area.position.x + area.size.x * u, area.end.y - rise * area.size.y * 0.85))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for spot in spots:
		var middle := 1.0 - absf((spot.x - area.get_center().x) / maxf(area.size.x * 0.5, 1.0))  # 1 in the middle, 0 at the ends
		var height := clampf((0.55 + 0.6 * middle) * rng.randf_range(0.7, 1.2) * (tall / stand * 0.6 + 0.45), 0.55, 2.0)
		var flame := PixelFx.sprite(FLAME, rng.randf_range(10.0, 19.0), true, 1)
		flame.offset = Vector2(0, -stand * 0.5)
		flame.scale = Vector2(height * rng.randf_range(0.75, 1.2), height)
		flame.rotation = rng.randf_range(-0.22, 0.22)  # a flame leans
		flame.flip_h = rng.randf() < 0.5
		flame.frame = rng.randi() % 6
		flame.modulate = Color(1.0, rng.randf_range(0.82, 1.0), rng.randf_range(0.7, 1.0), rng.randf_range(0.9, 1.0))
		flame.position = fire.to_local(spot)
		flame.z_index = 3 + int(spot.y > area.get_center().y)
		fire.add_child(flame)
	var glow := Sprite2D.new()
	glow.texture = Fx.tex("circle_05")
	glow.material = Fx.additive()
	glow.modulate = Color(1.0, 0.45, 0.12, 0.4)
	glow.scale = Vector2(area.size.x * 1.5, maxf(area.size.y, 24.0) * 1.6) / Fx.TEX_SIZE
	glow.position = fire.to_local(area.get_center())
	glow.z_index = 2
	fire.add_child(glow)
	var embers := Fx.trail(Color(1.0, 0.55, 0.2), clampi(count * 2, 6, 40), 1.0, 22.0, Vector2(0, -50), "spark_01", 5.0)
	embers.texture = PixelFx.ember()
	embers.direction = Vector2.UP
	embers.spread = 35.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(area.size.x * 0.5, maxf(area.size.y * 0.3, 3.0))
	embers.position = fire.to_local(area.get_center())
	embers.z_index = 5
	fire.add_child(embers)
	return fire
