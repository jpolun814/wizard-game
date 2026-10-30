class_name JungleTree
extends Node2D

## A great tree of the jungle, there to be seen: walk through its roots. The large ones have a branch to stand on, which one can jump up
## through and drop from, and a vine hanging from it to climb. Its origin is the foot of the trunk, on the ground.

const PICTURE := preload("res://art/props/great_oak.png")  # 208 x 234; its trunk's base is a little left of the middle
const VINE := preload("res://art/props/jungle_vine.png")
const BRANCH := [156.0, 30.0, 90.0]  # the high branch, as the oak's own ledges are: [height above the base, left edge, right edge] at the picture's own size
const BIG := 2.0  # a large tree is this many times the size of its picture

var big := true
var vine_ground := 0.0  # how far below the foot of the trunk the ground is where the vine hangs (it is a little to the side)


func _ready() -> void:
	z_index = -1
	var scale_up := BIG if big else 1.0
	var sprite := Sprite2D.new()
	sprite.texture = PICTURE
	sprite.scale = Vector2.ONE * scale_up
	sprite.position = Vector2(12.0, -PICTURE.get_height() * 0.5) * scale_up
	add_child(sprite)
	if not big:
		return
	var branch := StaticBody2D.new()
	branch.collision_layer = 16  # a one-way platform: jump up through it, land on top
	branch.collision_mask = 0
	var plank := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BRANCH[2] - BRANCH[1], 10.0) * Vector2(scale_up, 1.0)
	plank.shape = rect
	plank.position = Vector2((BRANCH[1] + BRANCH[2]) * 0.5 * scale_up, -BRANCH[0] * scale_up + 5.0)
	plank.one_way_collision = true
	plank.one_way_collision_margin = 6.0
	branch.add_child(plank)
	add_child(branch)
	var vine := RopeLadder.new()  # the vine, climbed like a rope ladder: it hangs from the branch's outer end
	vine.texture = VINE
	vine.modulate = Color(0.75, 1.0, 0.65)
	vine.height = BRANCH[0] * scale_up + vine_ground
	vine.position = Vector2((BRANCH[2] + 6.0) * scale_up, vine_ground)
	add_child(vine)
