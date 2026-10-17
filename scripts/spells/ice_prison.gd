class_name IcePrison
extends Node2D

## Ice Prison: draw a box and it fills with ice. Anyone whose body is inside it is frozen solid: enemies can't move
## or attack until it thaws, and a Force or Earth spell shatters them out of it for extra damage. Ice enemies shrug
## it off. Drawn around nothing, the box becomes a solid block of ice that stands for a while: a step to climb or
## a wall that stops shots.

const FREEZE_SECONDS := 3.0
const PLAYER_FREEZE := 1.4   # you break out of ice faster than enemies do
const BLOCK_LIFE := 6.0
const MIN_SIZE := 24.0
const MAX_SIZE := 160.0

var team := "player"
var rect := Rect2()   # the box as drawn, in world space; set before adding to the tree
var _age := 0.0
var _life := 0.6
var _block: StaticBody2D
var _held: Node2D      # the player, while frozen by the dark wizard's prison
var _frozen_any := false
const ICE := preload("res://art/props/ice_fill.png")


func _ready() -> void:
	var size := rect.size.clamp(Vector2.ONE * MIN_SIZE, Vector2.ONE * MAX_SIZE)
	rect = Rect2(rect.get_center() - size * 0.5, size)
	global_position = rect.get_center()
	z_index = 3
	Sfx.play("freeze", global_position)
	for body in SpellTargets.all(get_tree(), team):
		if not rect.grow(6.0).has_point(SpellTargets.center_of(body)):
			continue
		_frozen_any = true
		if body.is_in_group("mobs"):
			if not body.freeze(FREEZE_SECONDS):
				FloatText.spawn(get_parent(), body.center() + Vector2(0, -30), "Immune", Color("#bfe9ff"), 0.8)
		else:
			body.apply_debuff("root", PLAYER_FREEZE)
			if not body.has_shield():
				_held = body
				_life = PLAYER_FREEZE
	if not _frozen_any:
		_make_block()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var burst := PixelFx.play(get_parent(), global_position, "ice_burst", 70.0, maxf(1.0, roundf(rect.size.x / 70.0)))
	burst.z_index = 5


## Nothing was caught, so the box becomes a solid block of ice.
func _make_block() -> void:
	_life = BLOCK_LIFE
	_block = StaticBody2D.new()
	_block.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	_block.add_child(shape)
	add_child(_block)


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _life:
		if _block or _held:
			Shatter.spawn(get_parent(), global_position, Color("#cdeeff"))
			Sfx.play("ice_shatter", global_position)
		queue_free()


## The block of ice: pixel-art ice filling the box, with a light top edge. Enemies draw their own ice.
func _draw() -> void:
	var local := Rect2(-rect.size * 0.5, rect.size)
	if _held and is_instance_valid(_held):
		local = Rect2(_held.center() - global_position - Vector2(18, 40), Vector2(36, 80))
	elif not _block:
		return
	var fade := clampf((_life - _age) / 0.4, 0.0, 1.0)
	var grow := clampf(_age / 0.12, 0.0, 1.0)
	local = Rect2((local.get_center() - local.size * 0.5 * grow).floor(), (local.size * grow).floor())
	draw_texture_rect(ICE, local, true, Color(1, 1, 1, (0.75 if _held else 0.95) * fade))
