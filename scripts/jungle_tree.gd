class_name JungleTree
extends Node2D

## A great tree of the jungle: walk through its roots. The large ones have the oak's ledges to stand on, which one can jump up
## through and drop from, and a vine hanging from the high one on the right to climb. Its origin is the foot of the trunk, on the ground.

const PICTURE := preload("res://art/props/great_oak.png")  # 208 x 234; its trunk's base is a little left of the middle
const VINE := preload("res://art/props/jungle_vine.png")
const TILE := 32
## The ledges, as the Great Oak spell's [height above the base, left edge, right edge] at the picture's own size. (Its own list is not used,
## so the wizards' map of the ways can load this without the spell.) The third is the high one on the right, which a vine hangs from; it is
## cut to whole columns, so that a wizard walking off either end clears it.
const LEDGES := [[30.0, -36.0, -10.0], [112.0, -44.0, -12.0], [156.0, 40.0, 88.0], [212.0, -26.0, 44.0]]
const VINE_LEDGE := 2
const MAX_BRIDGE := 9  # the most columns a rope bridge spans
const TRUNK_SHIFT := 12.0  # the trunk's base is this far left of the middle of the picture, at the picture's own size

var size := 2  # how many times the size of its picture: 1 is only to be seen, 2 and 3 have the oak's ledges and a vine
var mirror := false  # the picture turned about, ledges, vine and all
var vine_ground := 0.0  # how far below the foot of the trunk the ground is where the vine hangs (it is a little to the side)


## Where the vine's ledge and the vine are, in columns from the one the trunk stands in: {"first", "last": the columns the ledge covers whole,
## "vine": the column the vine hangs in, "rows": how many rows above the ground the top of the ledge is, rounded up}.
static func layout(tree_size: int, mirrored: bool) -> Dictionary:
	var scale_up := float(tree_size)
	var ledge: Array = LEDGES[VINE_LEDGE]
	var first: int
	var last: int
	var vine: int
	if not mirrored:
		first = ceili((TILE * 0.5 + ledge[1] * scale_up) / TILE)
		last = floori((TILE * 0.5 + ledge[2] * scale_up) / TILE) - 1
		vine = last + 1
	else:
		first = ceili((TILE * 0.5 - ledge[2] * scale_up) / TILE)
		last = floori((TILE * 0.5 - ledge[1] * scale_up) / TILE) - 1
		vine = first - 1
	return {"first": first, "last": last, "vine": vine, "rows": ceili((ledge[0] * scale_up - 2.0) / TILE)}


## The rope bridges between neighbouring large trees of the same size on level ground: [{"first", "last": the columns the bridge covers,
## "row": the row its planks lie on (the same as the two ledges it joins)}]. A bridge runs from the end of one tree's high ledge to the start of the next's.
static func bridges(trees: Array, floors: PackedInt32Array) -> Array:
	var out := []
	for k in range(trees.size() - 1):
		var left: Dictionary = trees[k]
		var right: Dictionary = trees[k + 1]
		if left["size"] < 2 or left["size"] != right["size"] or floors[left["column"]] != floors[right["column"]]:
			continue
		var a := layout(left["size"], left["mirror"])
		var b := layout(right["size"], right["mirror"])
		var first: int = left["column"] + a["last"] + 1
		var last: int = right["column"] + b["first"] - 1
		if last - first + 1 >= 1 and last - first + 1 <= MAX_BRIDGE:
			out.append({"first": first, "last": last, "row": floors[left["column"]] - a["rows"], "tree": left["column"]})
	return out


## The middle of the vine's ledge, from the foot of the trunk: where a page lies.
static func perch(tree_size: int, mirrored: bool) -> Vector2:
	var spot := layout(tree_size, mirrored)
	return Vector2(((spot["first"] + spot["last"] + 1) * 0.5 - 0.5) * TILE, -LEDGES[VINE_LEDGE][0] * float(tree_size))


func _ready() -> void:
	z_index = -1
	var scale_up := float(size)
	var way := -1.0 if mirror else 1.0
	var sprite := Sprite2D.new()
	sprite.texture = PICTURE
	sprite.scale = Vector2.ONE * scale_up
	sprite.flip_h = mirror
	sprite.position = Vector2(TRUNK_SHIFT * way, -PICTURE.get_height() * 0.5) * scale_up
	add_child(sprite)
	if size < 2:
		return
	var ledges := StaticBody2D.new()  # the oak's ledges, as the spell's own tree has: one-way, jump up through, land on top
	ledges.collision_layer = 16
	ledges.collision_mask = 0
	var spot := layout(size, mirror)
	for k in LEDGES.size():
		var ledge: Array = LEDGES[k]
		var left: float = ledge[1] * scale_up
		var right: float = ledge[2] * scale_up
		if mirror:
			left = -ledge[2] * scale_up
			right = -ledge[1] * scale_up
		if k == VINE_LEDGE:  # the one with the vine runs from one column's edge to another's, for the wizards' map of the ways
			left = spot["first"] * TILE - TILE * 0.5
			right = (spot["last"] + 1) * TILE - TILE * 0.5
		var plank := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(right - left, 10.0)
		plank.shape = rect
		plank.position = Vector2((left + right) * 0.5, -ledge[0] * scale_up + 5.0)
		plank.one_way_collision = true
		plank.one_way_collision_margin = 6.0
		ledges.add_child(plank)
	add_child(ledges)
	var vine := RopeLadder.new()  # the vine, climbed like a rope ladder: it hangs from the outer end of the high ledge
	vine.texture = VINE
	vine.sway = true
	vine.modulate = Color(0.75, 1.0, 0.65)
	vine.height = LEDGES[VINE_LEDGE][0] * scale_up + vine_ground
	vine.position = Vector2(spot["vine"] * TILE, vine_ground)
	add_child(vine)
