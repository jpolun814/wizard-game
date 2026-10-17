class_name Backdrop
extends Node2D

## The scenery behind the arena, from ansimuz's GothicVania packs (see tools/prepare_gothic_art.py): a blood-moon
## sky over crags and a graveyard, a haunted swamp under a dark canopy, or the inside of a cathedral. Each layer
## slides past slower the farther away it is. Where a layer's picture ends, its edge colour carries on, so a high
## jump or a fall never shows a gap.

## Each place: a sky fixed to the screen (or none), the colour behind everything, and its layers farthest first.
## A layer is [file, how fast it scrolls against the camera, where its bottom edge sits in the world, how fast it
## drifts, whether its top colour carries on up past it, and how many times its own size it is drawn: far scenery
## can be drawn big, which also makes it read as farther off]. Layers only slide sideways: up and down they stay put,
## so they always meet the ground the same way. Every layer's bottom colour carries on down.
const PLACES := {
	"cemetery": {"sky": "res://art/backgrounds/cemetery/sky.png", "fill": Color("#2c0127"), "layers": [
		["res://art/backgrounds/cemetery/far.png", Vector2(0.12, 1.0), 214.0, 0.0, false, 1.0],
		["res://art/backgrounds/cemetery/near.png", Vector2(0.35, 1.0), 222.0, 0.0, false, 1.0],
	]},
	"swamp": {"sky": "", "fill": Color("#1b6642"), "layers": [
		["res://art/backgrounds/swamp/sky.png", Vector2(0.05, 1.0), 200.0, 0.0, true, 2.0],
		["res://art/backgrounds/swamp/woods.png", Vector2(0.22, 1.0), 290.0, 0.0, false, 2.0],
		["res://art/backgrounds/swamp/near.png", Vector2(0.45, 1.0), 260.0, 0.0, false, 2.0],
	]},
	"church": {"sky": "", "fill": Color("#272638"), "layers": [
		["res://art/backgrounds/church/hall.png", Vector2(0.3, 1.0), 212.0, 0.0, true, 2.0],
	]},
}

var place := "cemetery"


## Builds the sky and the layers for one place. Call after adding it to the tree.
func build(backdrop: String) -> void:
	place = backdrop
	var spec: Dictionary = PLACES[place]
	z_index = -50
	_build_sky(spec)
	for layer in spec["layers"]:
		var texture: Texture2D = load(layer[0])
		var zoom: float = layer[5]
		var size := texture.get_size() * zoom
		var parallax := Parallax2D.new()
		parallax.scroll_scale = layer[1]
		parallax.repeat_size = Vector2(size.x, 0)
		parallax.repeat_times = ceili(2400.0 / size.x)
		parallax.autoscroll = Vector2(layer[3], 0)
		add_child(parallax)
		var top: float = layer[2] - size.y
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(0.0, top)
		sprite.scale = Vector2(zoom, zoom)
		parallax.add_child(sprite)
		# Carry the picture's top and bottom colours on past its edges, where they are solid.
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var above := image.get_pixel(image.get_width() / 2, 0)
		var below := image.get_pixel(image.get_width() / 2, image.get_height() - 1)
		if layer[4] and above.a > 0.9:
			_band(parallax, Rect2(0.0, top - 600.0, size.x, 600.0), above)
		if below.a > 0.9:
			_band(parallax, Rect2(0.0, layer[2] - 1.0, size.x, 600.0), below)


func _band(parent: Node, rect: Rect2, colour: Color) -> void:
	var band := ColorRect.new()
	band.position = rect.position
	band.size = rect.size
	band.color = colour
	parent.add_child(band)


## The sky sits on its own layer, fixed to the screen, so it always fills the view whatever the camera does.
func _build_sky(spec: Dictionary) -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	add_child(sky_layer)
	var fill := ColorRect.new()
	fill.color = spec["fill"]
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(fill)
	if spec["sky"] == "":
		return
	var sky := TextureRect.new()
	sky.texture = load(spec["sky"])
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(sky)
