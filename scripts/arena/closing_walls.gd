class_name ClosingWalls
extends Node2D

## The last world of a match closes in. After a while the two ends of the world turn deadly and move toward each other, a little at a time, until the wizards who are left
## share a space too small to keep away from one another (owner, 2026-11-23: the worlds are to shrink so that the wizards have to fight). Anyone outside the safe stretch is
## hurt every half second, whoever they are. The stretch is worked out from this node's own age, so the same on every machine that began the world together.
## Each end is a wall of fire (the game's own fire pictures, stood in a column on the camera's view) with a pall of dark smoke behind it (owner, 2026-11-24: the first red veil was not thematic).

const GRACE := 60.0        # seconds in the world before the walls begin to move
const WARN := 12.0         # seconds of warning before that
const SPEED := 28.0        # pixels a second, from each end
const LEAST := 1100.0      # the narrowest the safe stretch gets, in pixels
const MARGIN := 70.0       # how far inside the line the wizards of the AI keep, so that they are never caught by it
const TICK := 0.5
const DAMAGE := 4

var _age := 0.0
var _tick := 0.0
var _warned := false
var _flames: Array[AnimatedSprite2D] = []  # the wall of fire at each end, as many pictures as the screen is tall; [left ones..., right ones...]
const FLAME_SCALE := 2.0  # whole numbers only: the pictures are pixel art


func _ready() -> void:
	add_to_group("danger")
	z_index = 40


## How far each end has closed in, in pixels.
func closed() -> float:
	var room := (ArenaGen.right_edge() - ArenaGen.left_edge() - LEAST) * 0.5
	return clampf((_age - GRACE * MatchState.hurry) * SPEED, 0.0, maxf(room, 0.0))


func safe_left() -> float:
	return ArenaGen.left_edge() + closed()


func safe_right() -> float:
	return ArenaGen.right_edge() - closed()


func _physics_process(delta: float) -> void:
	_age += delta
	if not _warned and _age >= (GRACE - WARN) * MatchState.hurry:
		_warned = true
		var world := get_parent() as World
		if world != null and world.hud != null:
			world.hud.banner("The walls are closing in")
	if closed() <= 0.0:
		return
	if int(_age) % 5 == 0 and absf(_age - roundf(_age)) < delta:
		MatchRecorder.event("WALLS %d %d" % [safe_left(), safe_right()])
	queue_redraw()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for wizard in SpellTargets.wizards(get_tree()):
		if is_instance_valid(wizard) and not wizard.dead and (wizard.global_position.x < safe_left() or wizard.global_position.x > safe_right()):
			wizard.take_damage(DAMAGE, false)


func danger_at(point: Vector2) -> bool:
	if _age < (GRACE - WARN) * MatchState.hurry + WARN * 0.5 * MatchState.hurry:
		return false
	return point.x < safe_left() + MARGIN or point.x > safe_right() - MARGIN


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or closed() <= 0.0:
		for flame in _flames:
			flame.visible = false
		return
	var high: float = PixelArt.FX["fire_wall"]["size"].y * FLAME_SCALE * 0.4  # (they overlap, so the wall has no gaps)
	var wide: float = PixelArt.FX["fire_wall"]["size"].x * FLAME_SCALE
	var view := get_viewport().get_visible_rect().size / camera.zoom
	var first := floorf((camera.get_screen_center_position().y - view.y * 0.5) / high) - 1.0
	var rows := int(ceilf(view.y / high)) + 3
	while _flames.size() < rows * 2:  # (more are made only when the screen grows taller)
		var flame := PixelFx.sprite("fire_wall", 12.0, true, 2)  # (from the third picture on: the first ones are the spark it starts from)
		flame.scale = Vector2(FLAME_SCALE, FLAME_SCALE)
		flame.material = Fx.additive()
		flame.frame = randi() % 5
		flame.z_index = 41
		add_child(flame)
		_flames.append(flame)
	for k in _flames.size():
		var flame := _flames[k]
		flame.visible = k < rows * 2
		if not flame.visible:
			continue
		var left := k < rows
		flame.position = Vector2(safe_left() - wide * 0.5 if left else safe_right() + wide * 0.5, (first + float(k % rows) + 0.5) * high)
		flame.flip_h = not left


func _draw() -> void:
	var top := -4000.0
	var tall := 12000.0
	var left_edge := ArenaGen.left_edge() - 400.0
	var right_edge := ArenaGen.right_edge() + 400.0
	var pall := Color(0.03, 0.01, 0.02, 0.55)  # smoke dark enough to read as the place no one should be
	draw_rect(Rect2(left_edge, top, safe_left() - left_edge, tall), pall)
	draw_rect(Rect2(safe_right(), top, right_edge - safe_right(), tall), pall)
