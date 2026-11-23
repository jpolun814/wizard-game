class_name ScreenFlash
extends CanvasLayer
## A flash of bright light over the whole screen, twice in a quick flicker, the way lightning lights up a night (owner, 2026-11-22: Spark and Jolt do it, which is what
## makes them lights). It is felt on the screen of the person at this machine, less the farther they are from where the bolt struck; nobody is hurt by it.

const REACH := 1100.0       # past this far from the bolt the person sees no flash
const FLICKER := [0.0, 0.07, 0.13, 0.5]  # seconds: up, down, up again, then away
const WHITE := Color(0.9, 0.93, 1.0)

var glare := 0.0 : set = _set_glare  # how bright the screen is from this flash, 0 to its peak
var _sheet: ColorRect


## How much of the dark an eclipse (or anything else that veils the screen) is lifted by a flash right now, 0 to 1: during the flash the whole world is seen in its own light.
static func lifting(tree: SceneTree) -> float:
	var most := 0.0
	for flash: ScreenFlash in tree.get_nodes_in_group("screen_flashes"):
		most = maxf(most, flash.glare)
	return clampf(most / 0.4, 0.0, 1.0)


func _set_glare(value: float) -> void:
	glare = value
	if _sheet != null:
		_sheet.color.a = value


## Flashes the screen for a bolt that struck at this point.
static func strike(tree: SceneTree, at: Vector2, strength := 0.55) -> void:
	var player := tree.get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	var near := 1.0 - clampf(player.global_position.distance_to(at) / REACH, 0.0, 1.0)
	if near <= 0.0 or tree.current_scene == null:
		return
	var flash := ScreenFlash.new()
	flash.layer = 40  # over the world, under the interface
	var sheet := ColorRect.new()
	sheet.color = Color(WHITE, 0.0)
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.add_child(sheet)
	flash._sheet = sheet
	flash.add_to_group("screen_flashes")
	tree.current_scene.add_child(flash)
	var peak := strength * near
	var tween := flash.create_tween()
	tween.tween_property(flash, "glare", peak, 0.02)
	tween.tween_property(flash, "glare", peak * 0.15, FLICKER[1] - 0.02)
	tween.tween_property(flash, "glare", peak * 0.8, 0.02)
	tween.tween_property(flash, "glare", 0.0, FLICKER[3] - FLICKER[2])
	tween.tween_callback(flash.queue_free)
