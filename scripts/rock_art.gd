class_name RockArt
extends RefCounted

## Pictures of loose rock cut from the world's own earth, so a boulder or a raised wall is made of the same stone as the ground it
## lands on or rises from. They are drawn in 2 by 2 pixel blocks like the rest of the pixel art, shaded from the top left, with a dark
## rim, and every one is lumpy: nothing here is a perfect circle or rectangle.

const BLOCK := 2
const RIM := Color("#0d0916")
const BRIGHTEN := 1.2  # loose rock is only a little brighter than the ground it lies on: the same stone, with the same dark seams


## The earth's colour at a point, whole blocks of it.
static func _earth(image: Image, x: int, y: int) -> Color:
	var c := image.get_pixel(posmod(x, image.get_width()), posmod(y, image.get_height()))
	return Color(minf(c.r * BRIGHTEN, 1.0), minf(c.g * BRIGHTEN, 1.0), minf(c.b * BRIGHTEN, 1.0), c.a)


static func _readable(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


## A round, lumpy boulder with the earth on its face, lit from the top left like a sphere.
static func boulder(earth: Texture2D, radius: float, seed_value: int) -> ImageTexture:
	var image := _readable(earth)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := int(ceil(radius * 2.0 / BLOCK)) + 2
	var out := Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	var phase_a := rng.randf() * TAU
	var phase_b := rng.randf() * TAU
	var middle := (cells - 1) * 0.5
	var reach := radius / BLOCK
	var offset := Vector2i(rng.randi_range(0, 60), rng.randi_range(0, 60))
	for y in cells:
		for x in cells:
			var d := Vector2(x - middle, y - middle)
			var edge := reach * (1.0 + 0.1 * sin(d.angle() * 3.0 + phase_a) + 0.07 * sin(d.angle() * 5.0 + phase_b))
			if d.length() > edge:
				continue
			var depth := sqrt(maxf(1.0 - pow(d.length() / edge, 2.0), 0.0))
			var normal := Vector3(d.x / edge, d.y / edge, depth)
			var light := normal.dot(Vector3(-0.55, -0.65, 0.5).normalized())
			var base := _earth(image, x * BLOCK + offset.x, y * BLOCK + offset.y)
			var shade := clampf(0.8 + light * 0.9, 0.5, 1.9)
			var colour := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
			if d.length() > edge - 1.0:
				colour = RIM.lerp(colour, 0.4)
			out.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(out)


## A slab of rock lying along x for a length, with a ragged end and a lumpy edge, lit from above. Part of it can be knocked out. The
## picture is as many whole blocks as fit, and is drawn at BLOCK times its size. Where the slab stands, where it began is the base.
static func slab(earth: Texture2D, length: float, thickness: float, knocked: float, seed_value: int, origin: Vector2) -> ImageTexture:
	var image := _readable(earth)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := int(ceil(length / BLOCK))
	var h := int(ceil((thickness + 10.0) / BLOCK))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var middle := (h - 1) * 0.5
	var half := thickness / BLOCK * 0.5
	var lumps := []
	for k in 3:
		lumps.append([rng.randf() * w, rng.randf_range(1.2, 2.4), rng.randf() * TAU])
	var tip := rng.randf_range(0.0, 1.0)
	for x in w:
		var along := float(x) / w
		var top := half + 1.0
		var bottom := half + 1.0
		for lump in lumps:
			top += sin(x * 0.55 / lump[1] + lump[2]) * 0.45
			bottom += sin(x * 0.4 / lump[1] + lump[2] + 1.3) * 0.45
		var taper := smoothstep(0.78, 1.0, along)  # the far end narrows and breaks into points
		top -= taper * half * (0.5 + 0.5 * absf(sin(x * 1.3 + tip * 6.0)))
		bottom -= taper * half * (0.4 + 0.6 * absf(sin(x * 0.9 + tip * 4.0)))
		if along < 0.04:
			top -= 1.0  # the foot is a little narrower than the body, sunk into where it grew from
		for y in h:
			var dy := y - middle
			if dy > bottom or dy < -top:
				continue
			var from_top := dy + top
			var from_bottom := bottom - dy
			var base := _earth(image, int(origin.x) + x * BLOCK, int(origin.y) + y * BLOCK)  # a block of the ground's own texels, which is the size of the ground's stones
			var shade := 1.0
			if from_top < 1.5:
				shade = 1.35  # the lit top
			elif from_bottom < 2.0:
				shade = 0.8  # the shaded underside
			var colour := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
			if from_top < 1.0 or from_bottom < 1.0 or x == 0 or (taper > 0.0 and x == w - 1):
				colour = RIM
			out.set_pixel(x, y, colour)
	for k in int(knocked * w * h / 6.0):  # stone knocked away
		var bx := rng.randi_range(0, w - 3)
		var by := rng.randi_range(0, h - 3)
		for dy in 2:
			for dx in 2:
				out.set_pixel(bx + dx, by + dy, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(out)


## A sheet of bare ice lying along the ground, `width` across: glossy, deep blue in the body with a pale lit top, scratched and cracked, with
## ends that thin out raggedly over the snow. It is drawn at BLOCK times its size, and its top lies at its top edge.
static func ice_sheet(width: float, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := int(ceil(width / BLOCK))
	var h := 6
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var scratches := []
	for k in maxi(3, w / 14):
		scratches.append([rng.randi_range(0, w - 1), rng.randi_range(1, 3), rng.randi_range(3, 9)])  # start, row, length
	for x in w:
		var edge := minf(float(x), float(w - 1 - x))
		var thin := 0.0  # the ends thin out: the sheet is lower and shorter there, and breaks into pieces
		if edge < 5.0:
			thin = (5.0 - edge) * (0.45 + 0.4 * absf(sin(x * 2.3 + float(seed_value))))
		var rows := int(round(h - thin))
		for y in h:
			if y < h - rows or (edge < 1.0 and y < 3):
				continue
			var from_top := y - (h - rows)
			var colour: Color
			match from_top:
				0:
					colour = Color(0.86, 0.96, 1.0, 0.98)  # the lit top
				1:
					colour = Color(0.56, 0.8, 0.95, 0.96)
				2, 3:
					colour = Color(0.28, 0.5, 0.78, 0.95)
				_:
					colour = Color(0.14, 0.28, 0.52, 0.95)  # the dark body, deep in the ice
			if from_top == rows - 1:
				colour = Color(0.08, 0.16, 0.34, 0.95)
			out.set_pixel(x, y, colour)
	for scratch: Array in scratches:  # pale scratches along the face
		for k in int(scratch[2]):
			var x: int = scratch[0] + k
			var y: int = scratch[1] + k / 4
			if x < w and y < h and out.get_pixel(x, y).a > 0.5:
				out.set_pixel(x, y, Color(0.8, 0.94, 1.0, 0.95))
	for k in maxi(1, w / 30):  # a few dark cracks
		var x := rng.randi_range(2, w - 3)
		for y in range(1, h - 1):
			if out.get_pixel(x, y).a > 0.5:
				out.set_pixel(x + (y % 2), y, Color(0.06, 0.12, 0.28, 0.95))
	return ImageTexture.create_from_image(out)


const SINK_BLOCKS := 3  # rows of a spike that lie inside the ground or ceiling it grows from


## A spike that grows from the ground (up) or hangs from a ceiling, as tall as it is told to be, cut from a source picture of stone or ice. Rock
## has a main spire with a spur or two beside it and a lit left side; ice is a bulb at the root that tapers to a point with a bright streak
## down it. The root rows are sunk into whatever it grows from. The picture is drawn at BLOCK times its size: for a spike that grows up its
## top left is at (-width / 2, -height) and for a hanging one at (-width / 2, -SINK_BLOCKS * BLOCK); see spike_rect.
static func spike(source: Texture2D, width: float, height: float, up: bool, ice: bool, seed_value: int) -> ImageTexture:
	var image := _readable(source)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := int(ceil(width / BLOCK)) + 4
	var rows := int(ceil(height / BLOCK))
	var h := rows + SINK_BLOCKS
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var middle := (w - 1) * 0.5
	var half := width / BLOCK * 0.5
	var spires: Array = [[0.0, 1.0, half]]  # offset, height share, half width
	if not ice:
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.7:
				spires.append([side * half * rng.randf_range(0.7, 1.1), rng.randf_range(0.3, 0.6), half * rng.randf_range(0.35, 0.55)])
	var wobble := rng.randf() * TAU
	for y in h:
		var from_base := float(h - 1 - y)  # rows above the lowest row
		var span := from_base - SINK_BLOCKS
		for x in w:
			var inside := false
			var lit := 0.0
			for spire in spires:
				var spire_rows: float = rows * spire[1]
				var u: float = clampf(span / maxf(spire_rows, 1.0), -1.0, 1.0)
				if span < 0.0:
					u = 0.0
				if u >= 1.0:
					continue
				var shape: float = 0.7 if ice else 0.9
				var reach: float = spire[2] * pow(1.0 - u, shape) * (1.0 + 0.1 * sin(span * 0.9 + wobble))
				if ice and u < 0.15:
					reach *= 1.0 + (0.15 - u)  # the bulb where the ice hangs from its root
				var dx: float = x - middle - spire[0]
				if absf(dx) <= maxf(reach, 0.0):
					inside = true
					lit = dx / maxf(reach, 0.8)
			if not inside:
				continue
			var base := _earth(image, x * BLOCK, y * BLOCK)
			var shade := 1.2 - lit * 0.5  # the left of a spire is lit, the right in shadow
			var colour: Color
			if ice:
				colour = Color(0.62 + base.r * 0.3, 0.8 + base.g * 0.15, 0.95, 0.92)
				if absf(lit + 0.45) < 0.14:
					colour = Color(0.95, 0.99, 1.0, 0.95)  # the bright streak
				elif lit > 0.3:
					colour = colour.darkened(0.25)
			else:
				colour = Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
				if rng.randf() < 0.04:
					colour = colour.darkened(0.4)  # a crack
			out.set_pixel(x, y, colour)
	# A dark rim round the spike, cut from the outside in.
	var rimmed := out.duplicate()
	for y in h:
		for x in w:
			if out.get_pixel(x, y).a > 0.0:
				continue
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + step
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and out.get_pixel(n.x, n.y).a > 0.0:
					rimmed.set_pixel(x, y, Color(0.04, 0.1, 0.2, 0.9) if ice else RIM)
					break
	if not up:
		rimmed.flip_y()  # built tip up, hung tip down
	return ImageTexture.create_from_image(rimmed)


## Where a spike picture is drawn so its root lies in the ground (up) or the ceiling (down), and its tip is height away.
static func spike_rect(picture: Texture2D, up: bool, height: float) -> Rect2:
	var size := picture.get_size() * BLOCK
	return Rect2(-size.x * 0.5, -size.y + SINK_BLOCKS * BLOCK if up else -SINK_BLOCKS * BLOCK, size.x, size.y)


## A block of ice a wizard stands frozen in: a chunky slab with cut corners and a jagged crown, clear in the middle so the one inside shows through,
## with a bright bevel on its lit left and top and a dark one on its right and foot, and pale streaks slanting across it. The picture is as many
## blocks as fit the size, drawn at BLOCK times its size.
static func ice_block(width: float, height: float, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var w := int(ceil(width / BLOCK))
	var h := int(ceil(height / BLOCK))
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var crown: Array = []  # how far down each column the jagged top starts
	for x in w:
		var rise := 0.0
		if x > 2 and x < w - 3:
			rise = float(int(absf(sin(x * 0.9 + seed_value)) * 3.0))
		crown.append(rise)
	var streaks := [rng.randf_range(0.2, 0.4), rng.randf_range(0.55, 0.75)]
	for y in h:
		for x in w:
			var top: float = crown[x] + 1.0
			var cut := 3.0  # the corners are cut off
			var corner_x := minf(float(x), float(w - 1 - x))
			var corner_y := float(h - 1 - y)
			if corner_x + corner_y < cut or y < top:
				continue
			var depth_x := minf(float(x), float(w - 1 - x))
			var depth_y := minf(float(y) - top + 1.0, float(h - 1 - y))
			var depth := minf(depth_x, depth_y)
			var colour := Color(0.72, 0.9, 1.0, 0.34)  # clear in the middle
			if depth < 1.0:
				colour = Color(0.12, 0.3, 0.45, 0.95)  # the outline
			elif depth < 3.0:
				if x < w * 0.5 and depth_x <= depth_y or y - top < 2.0:
					colour = Color(0.88, 0.97, 1.0, 0.9)  # the lit bevel, left and top
				elif x >= w * 0.5 and depth_x <= depth_y or h - 1 - y < 2.0:
					colour = Color(0.34, 0.6, 0.8, 0.9)  # the shaded bevel, right and foot
				else:
					colour = Color(0.62, 0.84, 0.96, 0.75)
			else:
				for streak: float in streaks:
					var line := float(x) / w + float(y) / h * 0.7 - streak
					if absf(line) < 0.035:
						colour = Color(0.95, 1.0, 1.0, 0.55)
			out.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(out)
