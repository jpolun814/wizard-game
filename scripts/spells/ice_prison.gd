class_name IcePrison
extends Node2D

## Ice Prison: draw a box and it fills with ice. Anyone whose body is inside it is frozen solid: enemies can't move
## or attack until it thaws, and a Force or Earth spell shatters them out of it for extra damage. Ice enemies shrug
## it off. Drawn around nobody, it freezes nothing: the cold breaks up in a puff of frost.

const FREEZE_SECONDS := 4.0
const MIN_SIZE := 24.0
const MAX_SIZE := 160.0

var team := "player"
var rect := Rect2()   # the box as drawn, in world space; set before adding to the tree
var _age := 0.0
var _life := 0.6
var _held: Node2D      # the player, while frozen by the dark wizard's prison
const ICE := preload("res://art/props/ice_fill.png")


func _ready() -> void:
	var size := rect.size.clamp(Vector2.ONE * MIN_SIZE, Vector2.ONE * MAX_SIZE)
	rect = Rect2(rect.get_center() - size * 0.5, size)
	global_position = rect.get_center()
	z_index = 3
	var caught := []
	for body in SpellTargets.all(get_tree(), team):
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
		else:
			if body.freeze(FREEZE_SECONDS):
				_held = body
				_life = FREEZE_SECONDS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var burst := PixelFx.play(get_parent(), global_position, "ice_burst", 70.0, maxf(1.0, roundf(rect.size.x / 70.0)))
	burst.z_index = 5


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= _life:
		if _held:
			Shatter.spawn(get_parent(), global_position, Color("#cdeeff"))
			Sfx.play("ice_shatter", global_position)
		queue_free()


## The ice round the frozen player: pixel-art ice over the body. Enemies draw their own ice.
func _draw() -> void:
	if not _held or not is_instance_valid(_held):
		return
	var local := Rect2(_held.center() - global_position - Vector2(18, 40), Vector2(36, 80))
	var fade := clampf((_life - _age) / 0.4, 0.0, 1.0)
	var grow := clampf(_age / 0.12, 0.0, 1.0)
	local = Rect2((local.get_center() - local.size * 0.5 * grow).floor(), (local.size * grow).floor())
	draw_texture_rect(ICE, local, true, Color(1, 1, 1, 0.75 * fade))
