class_name ScryingEye
extends Control

## The Chant of the Scrying Eye: a small round window in the bottom-right corner of the screen that shows, live, another wizard picked by chance from those still
## standing. It stays on them until they fall, then picks another. It does not say where they are. A little eye floats over the watched wizard's head (see
## EyeMark), on every machine, so they can tell they are watched.
##
## The window is a second view of the same world (a SubViewport that shares the world's canvas) with a camera of its own. The ground is only made near the
## wizards, so the camera joins the "ground_watchers" group, and the world keeps the ground round it made too (see World._process).

const SIZE := 190.0
const MARGIN := 16.0
const ZOOM := 0.5         # a whole step down, so the pixel art is never scaled across a fraction
const PICK_EVERY := 0.5   # seconds between looking for someone to watch, when no one is
const FOLLOW := 8.0       # how quickly the camera catches up with them
const RING := Color("#c9a45a")
const MASK := preload("res://scripts/ui/circle_mask.gdshader")

var arena: Node
var watched: Wizard       # who is in the window now
var _view: SubViewport
var _camera: Camera2D
var _pick_time := 0.0
var _window := SubViewportContainer.new()
var _dressed := false      # the window has been given the color of the world it shows


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -SIZE - MARGIN
	offset_top = -SIZE - MARGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	_window.stretch = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.size = Vector2(SIZE, SIZE)
	var mask := ShaderMaterial.new()
	mask.shader = MASK
	_window.material = mask
	add_child(_window)
	_view = SubViewport.new()
	_view.size = Vector2i(int(SIZE), int(SIZE))
	_view.world_2d = get_viewport().world_2d  # the same world, seen by another camera
	_view.transparent_bg = false
	_view.handle_input_locally = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_window.add_child(_view)
	_camera = Camera2D.new()
	_camera.zoom = Vector2(ZOOM, ZOOM)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS  # as physics interpolation makes it anyway
	_view.add_child(_camera)
	visibility_changed.connect(_on_shown_or_hidden)
	_on_shown_or_hidden()


## The window is seen through the same color as the screen: the world's grade, and the graveyard's wash of gray. (Done when it is first shown, for the
## world has chosen its colors by then.)
func _dress() -> void:
	if _dressed:
		return
	_dressed = true
	_view.add_child(Grade.for_biome(arena.grade_biome))
	if arena.grayed:
		_view.add_child(Grade.gray_wash())


## When the window is hidden nothing is drawn in it, and no ground is kept for it.
func _on_shown_or_hidden() -> void:
	var shown := is_visible_in_tree()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if shown:
		_dress()
		_camera.add_to_group("ground_watchers")
	else:
		_camera.remove_from_group("ground_watchers")
		_watch(null)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not is_instance_valid(watched) or watched.dead:
		_watch(null)
		_pick_time -= delta
		if _pick_time <= 0.0:
			_pick_time = PICK_EVERY
			_watch(_someone())
	if watched != null:
		var at := watched.center()
		_camera.global_position = at if _camera.global_position.distance_to(at) > 1200.0 else _camera.global_position.lerp(at, minf(1.0, delta * FOLLOW))
	queue_redraw()


## One of the wizards still standing other than the one at this machine, at random, or null when there is no one.
func _someone() -> Wizard:
	var others: Array = []
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		if wizard != arena.player:
			others.append(wizard)
	return null if others.is_empty() else others[randi() % others.size()]


func _watch(wizard: Wizard) -> void:
	if wizard == watched:
		return
	if is_instance_valid(watched):
		arena.eye_on(watched, false)
	watched = wizard
	if wizard != null:
		_camera.global_position = wizard.center()
		arena.eye_on(wizard, true)


func _draw() -> void:
	var middle := Vector2(SIZE, SIZE) * 0.5
	if watched == null:
		draw_circle(middle, SIZE * 0.5, Color(0.04, 0.02, 0.06, 0.85))  # no one to watch: a dark glass
	draw_arc(middle, SIZE * 0.5 - 1.0, 0.0, TAU, 64, RING, 3.0, false)
	draw_arc(middle, SIZE * 0.5 - 4.0, 0.0, TAU, 64, Color(0.1, 0.06, 0.12, 0.8), 2.0, false)
