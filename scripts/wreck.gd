class_name Wreck
extends Node2D

## A wreck on the floor of the ocean (chapter 20): the broken columns of a drowned cathedral, with crates, barrels and ship's timbers fallen about them,
## all of the game's own church and town props, dyed dark with the sea. In the middle is an air pocket (AirPocket): a hollow the water has not filled,
## lit faintly, with bubbles rising from it, where a wizard can breathe. A page lies here. It is scenery and the pocket: nothing in it is solid.
## Its origin is the floor under the middle of it.

const COLUMN := preload("res://art/props/church_column.png")
const CRATE := preload("res://art/props/crate.png")
const BARREL := preload("res://art/props/barrel.png")
const TIMBER := preload("res://art/props/plank_legs.png")
const SUNK := Color(0.4, 0.5, 0.55)  # what the sea does to the colours of everything it has had for a long time

var seed_value := 0
var pocket: AirPocket


func _ready() -> void:
	z_index = -1  # behind the wizards, in front of the water
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var left := rng.randf() < 0.5
	for k in 2:  # two columns, one broken, standing at the two sides of the pocket
		var column := Sprite2D.new()
		column.texture = COLUMN
		column.centered = false
		column.offset = Vector2(-COLUMN.get_width() * 0.5, -COLUMN.get_height())
		column.position = Vector2((-1.0 if (k == 0) == left else 1.0) * 120.0, 6.0)
		column.modulate = SUNK
		column.region_enabled = k == 1  # the second is a stump
		if k == 1:
			column.region_rect = Rect2(0, COLUMN.get_height() * 0.45, COLUMN.get_width(), COLUMN.get_height() * 0.55)
			column.offset = Vector2(-COLUMN.get_width() * 0.5, -COLUMN.get_height() * 0.55)
		add_child(column)
	for k in rng.randi_range(2, 3):
		var crate := Sprite2D.new()
		crate.texture = CRATE if rng.randf() < 0.6 else BARREL
		crate.centered = false
		crate.offset = Vector2(-crate.texture.get_width() * 0.5, -crate.texture.get_height() + 2.0)
		crate.position = Vector2(rng.randf_range(-210.0, 210.0), 4.0)
		crate.rotation = rng.randf_range(-0.25, 0.25)
		crate.flip_h = rng.randf() < 0.5
		crate.modulate = SUNK
		add_child(crate)
	for k in 2:
		var timber := Sprite2D.new()
		timber.texture = TIMBER
		timber.centered = false
		timber.offset = Vector2(-TIMBER.get_width() * 0.5, -TIMBER.get_height())
		timber.position = Vector2(rng.randf_range(-190.0, 190.0), 2.0)
		timber.rotation = rng.randf_range(-0.9, 0.9)
		timber.scale = Vector2(2.0, 2.0)
		timber.modulate = SUNK
		add_child(timber)
	pocket = AirPocket.new()
	add_child(pocket)
	var light := PointLight2D.new()  # the hollow glows a little: air, lit by what little reaches it
	light.texture = Fx.tex("light_01")
	light.texture_scale = 300.0 / Fx.TEX_SIZE
	light.color = Color(0.7, 0.9, 1.0)
	light.energy = 0.55
	light.position = Vector2(0.0, -pocket.size.y * 0.5)
	add_child(light)
	var bubbles := Fx.trail(Color(0.85, 0.95, 1.0, 0.7), 8, 2.2, 36.0, Vector2(0, -40), "circle_05", 5.0)
	bubbles.position = Vector2(0.0, -8.0)
	bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 40.0
	bubbles.emitting = true
	add_child(bubbles)
