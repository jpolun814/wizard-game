class_name IcePrison
extends Node2D

## Ice Prison: draw a box and it fills with ice. Anyone whose body is inside it is frozen solid: enemies can't move
## or attack until it thaws, and an Air or Earth spell shatters them out of it for extra damage. Ice enemies shrug
## it off. Drawn around nobody, it freezes nothing: the cold breaks up in a puff of frost.

const FREEZE_SECONDS := 6.0
const MIN_SIZE := 24.0
const MAX_SIZE := 160.0

var rect := Rect2()   # the box as drawn, in world space; set before adding to the tree
var _age := 0.0
var _life := 0.6
var _encased := []     # each body in ice: {"body", "block": the picture of its block of ice}
const WIZARD_BLOCK := Vector2(68.0, 104.0)  # the block round a wizard: past the body on every side, and over the hood
const ROOM := Vector2(26.0, 22.0)  # how much bigger than a walker its block is


func _ready() -> void:
	var size := rect.size.clamp(Vector2.ONE * MIN_SIZE, Vector2.ONE * MAX_SIZE)
	rect = Rect2(rect.get_center() - size * 0.5, size)
	global_position = rect.get_center()
	z_index = 3
	var caught := []
	for body in SpellTargets.all(get_tree()):
		if rect.grow(6.0).has_point(SpellTargets.center_of(body)):
			caught.append(body)
	if caught.is_empty():
		Fx.burst(get_parent(), global_position, Color("#dff6ff"), 8, 60.0, 0.4, true, "star_04")
		queue_free()
		return
	Sfx.play("freeze", global_position)
	for body in caught:
		if body.is_in_group("mobs"):
			if not body.freeze(FREEZE_SECONDS):
				FloatText.spawn(get_parent(), body.center() + Vector2(0, -30), "Immune", Color("#bfe9ff"), 0.8)
				continue
		elif not body.freeze(FREEZE_SECONDS):
			continue
		var block_size: Vector2 = body.body_extent() + ROOM if body.is_in_group("mobs") else WIZARD_BLOCK
		_encased.append({"body": body, "block": RockArt.ice_block(block_size.x, block_size.y, int(global_position.x) + _encased.size())})
		_life = FREEZE_SECONDS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var burst := PixelFx.play(get_parent(), global_position, "ice_burst", 70.0, maxf(1.0, roundf(rect.size.x / 70.0)))
	burst.z_index = 5


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	for entry: Dictionary in _encased.duplicate():
		var body: Node2D = entry["body"]
		if not is_instance_valid(body) or (_age > 1.0 and not body.is_frozen()) or _age >= _life:  # thawed, or broken out of it (a wizard on another machine is told it a moment late)
			if is_instance_valid(body):
				Shatter.spawn(get_parent(), body.center(), Color("#cdeeff"))
				Sfx.play("ice_shatter", body.center())
			_encased.erase(entry)
	if _age >= _life or (_age > 1.0 and _encased.is_empty() and _life > 0.6):
		queue_free()


## The ice round each frozen body: a block of it that covers the whole body, growing from the ground up.
func _draw() -> void:
	var fade := clampf((_life - _age) / 0.4, 0.0, 1.0)
	var grow := clampf(_age / 0.18, 0.0, 1.0)
	for entry: Dictionary in _encased:
		var body: Node2D = entry["body"]
		var block: ImageTexture = entry["block"]
		var size := block.get_size() * RockArt.BLOCK
		var feet: Vector2 = body.global_position - global_position + Vector2(0.0, 6.0)  # the block stands on the ground under the body
		var shown := size.y * grow
		var rect := Rect2(feet + Vector2(-size.x * 0.5, -shown), Vector2(size.x, shown))
		draw_texture_rect_region(block, rect, Rect2(0.0, block.get_height() * (1.0 - grow), block.get_width(), block.get_height() * grow), Color(1, 1, 1, fade))
