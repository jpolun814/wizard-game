class_name IceSheet
extends Node2D

## A sheet of bare ice laid over a level stretch of the snowy peaks' ground. A wizard running on it cannot stop or turn quickly: they slide.
## Its origin is the top-left of the stretch it covers.

var width := 160.0
var _area := Rect2()


func _ready() -> void:
	add_to_group("slick")
	_area = Rect2(global_position + Vector2(0.0, -6.0), Vector2(width, 14.0))
	var strip := Sprite2D.new()  # glossy, scratched ice with ragged ends (see RockArt.ice_sheet)
	strip.texture = RockArt.ice_sheet(width, int(global_position.x))
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.scale = Vector2.ONE * RockArt.BLOCK
	strip.centered = false
	strip.position = Vector2(0.0, -8.0)
	add_child(strip)


## True when a point is on the ice.
func covers(point: Vector2) -> bool:
	return _area.has_point(point)


## True when a point is on any sheet of ice in the world.
static func under(tree: SceneTree, point: Vector2) -> bool:
	for sheet: IceSheet in tree.get_nodes_in_group("slick"):
		if sheet.covers(point):
			return true
	return false
