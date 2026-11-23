class_name PageFlight
extends Node2D

## The pages of a reading fly to the one who reads them, one at a time, from where they lay. As each reaches the wizard its name rises beside them, in its school's color
## (a chant's in gold). The pages are already in the book when this begins: it is what a reader sees, nothing more. A fallen wizard's book is read the same way.

const STAGGER := 0.2   # seconds from one page setting off to the next (owner, 2026-11-22: no more than 0.2; the names stay up longer instead)
const NAME_LIFE := 2.6  # seconds a page's name stays on the screen
const NAME_ROWS := 8    # the names stack in this many rows, so pages that arrive close together do not write over each other
const FLIGHT := 0.55   # seconds a page takes to reach the wizard
const CHANT_COLOR := Color("#ffe9a0")

var wizard: Wizard
var from := Vector2.ZERO
var pages: Array[String] = []
var _done := 0


## How long the whole reading takes, from the first page setting off to the last one arriving.
static func seconds_for(count: int) -> float:
	return maxf(count - 1, 0) * STAGGER + FLIGHT


## Sends these pages from a point to a wizard.
static func send(parent: Node, at: Vector2, to: Wizard, names: Array[String]) -> void:
	if parent == null or names.is_empty() or not is_instance_valid(to):
		return
	var flight := PageFlight.new()
	flight.from = at
	flight.wizard = to
	flight.pages = names
	parent.add_child(flight)


func _ready() -> void:
	for k in pages.size():
		get_tree().create_timer(k * STAGGER).timeout.connect(_launch.bind(pages[k], k))


## The color a page is shown in: its school's, or gold for a chant.
static func color_of(page: String) -> Color:
	if SpellData.SPELLS.has(page):
		return SpellData.SCHOOL_COLORS[SpellData.SPELLS[page].school]
	return CHANT_COLOR


func _launch(page: String, index: int) -> void:
	if not is_instance_valid(wizard):
		_finish()
		return
	var color := color_of(page)
	var sprite := Sprite2D.new()
	sprite.texture = PagePickup.PAGE
	var outline := ShaderMaterial.new()
	outline.shader = PagePickup.OUTLINE
	outline.set_shader_parameter("outline_color", color.lightened(0.2))
	sprite.material = outline
	sprite.z_index = 20
	sprite.global_position = from
	get_parent().add_child(sprite)
	Fx.burst(get_parent(), from, color, 6, 70.0, 0.3, true)
	var way := create_tween()
	way.tween_method(_fly.bind(sprite, from, index), 0.0, 1.0, FLIGHT).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	way.tween_callback(_arrive.bind(sprite, page, color, index))


## One step of a page's flight: toward where the wizard is now, in a little arc, and turning as it goes.
func _fly(progress: float, sprite: Sprite2D, start: Vector2, index: int) -> void:
	if not is_instance_valid(sprite):
		return
	var target := SpellTargets.center_of(wizard) if is_instance_valid(wizard) else start
	sprite.global_position = start.lerp(target, progress) + Vector2(0.0, -sin(progress * PI) * 50.0)
	sprite.rotation = progress * TAU * (1.0 if index % 2 == 0 else -1.0)
	sprite.scale = Vector2.ONE * (1.0 - 0.45 * progress)


func _arrive(sprite: Sprite2D, page: String, color: Color, index: int) -> void:
	if is_instance_valid(sprite):
		sprite.queue_free()
	if is_instance_valid(wizard):
		var at := SpellTargets.center_of(wizard)
		Fx.burst(get_parent(), at, color, 12, 110.0, 0.4, true)
		Fx.pop(get_parent(), at, "circle_05", Color(color.r, color.g, color.b, 0.7), 40.0, 0.3, 1.6)
		FloatText.spawn(get_parent(), at + Vector2(64.0, -10.0 - 15.0 * (index % NAME_ROWS)), Pages.title_of(page), color.lightened(0.25), 1.15, NAME_LIFE)  # beside them, in their school's color
		Sfx.cue("page_pickup", "rustle", at, -8.0)
	_finish()


func _finish() -> void:
	_done += 1
	if _done >= pages.size():
		queue_free()
