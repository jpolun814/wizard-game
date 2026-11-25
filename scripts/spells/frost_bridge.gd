class_name FrostBridge
extends Node

## Frost Bridge: a wavy line drawn across water freezes the surface under it into ice you can walk on, and drawn on the ground it freezes the ground into
## a sheet of ice. All ice is slippery (a wizard on it cannot stop or turn quickly), fire melts it, and it thaws by itself after a while (see Pond and IceSheet).

const STEP := 16.0          # how finely the ground under the line is read
const LEVEL := 6.0          # how much the ground may rise or fall along a sheet, in pixels
static var WATER := Motion.of("Frost Bridge", "floor")
static var GROUND := Spell.among(SpellData.SPELLS["Frost Bridge"].parts, "slick", "ground")
static var SHORTEST: float = GROUND["least"]  # the least ground worth freezing

var line := PackedVector2Array()  # the drawn line, in world points; set before the effect enters the tree


func _ready() -> void:
	var box := GestureTemplates.bounds(line)
	var frozen := 0
	for pond in get_tree().get_nodes_in_group("ponds"):
		# The line must be drawn near the pond's surface: on it, or a little above or below.
		var level: float = pond.surface_at(box.get_center().x)
		if box.end.y < level - float(WATER["reach"]) or box.position.y > level + pond.depth:
			continue
		if pond.freeze_span(box.position.x, box.end.x):
			frozen += 1
	if frozen == 0:
		frozen = 1 if _freeze_ground(box) else 0
	if frozen == 0:
		FloatText.spawn(get_parent(), box.get_center() + Vector2(0, -20), "Nothing to freeze", Color("#9fd8ff"), 0.9)
	queue_free()


## Freezes the level ground under the line into a sheet of ice, as far as the ground stays level. False where the line was not drawn near ground.
func _freeze_ground(box: Rect2) -> bool:
	var world := get_viewport().world_2d
	var middle := SpellTargets.solid_below(world, Vector2(box.get_center().x, box.position.y - 200.0), 1200.0)
	if box.end.y < middle.y - float(GROUND["reach"]) or box.position.y > middle.y + 60.0:
		return false  # it was drawn in the air, or far under the ground
	var start := box.position.x
	var level := SpellTargets.solid_below(world, Vector2(start, middle.y - 200.0), 400.0).y
	var reach := start
	var x := start
	while x <= box.end.x:
		var here := SpellTargets.solid_below(world, Vector2(x, middle.y - 200.0), 400.0).y
		if absf(here - level) > LEVEL:
			break
		reach = x
		x += STEP
	if reach - start < SHORTEST:
		return false
	var sheet := IceSheet.new()
	sheet.width = reach - start
	sheet.thaws = true
	sheet.position = Vector2(start, level)
	get_parent().add_child(sheet)
	Sfx.cue("pond", "ice", Vector2((start + reach) * 0.5, level))
	Shatter.spawn(get_parent(), Vector2((start + reach) * 0.5, level), Color("#cdeeff"))
	return true
