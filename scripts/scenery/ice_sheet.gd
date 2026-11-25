class_name IceSheet
extends Node2D

## A sheet of bare ice laid over a level stretch of the snowy peaks' ground. A wizard running on it cannot stop or turn quickly: they slide.
## Its origin is the top-left of the stretch it covers.

static var MELT_SECONDS: float = Spell.among(SpellData.SPELLS["Frost Bridge"].parts, "slick", "ground")["for"]  # a sheet laid by a spell thaws after this long (the peaks' own sheets never do)

var width := 160.0
var thaws := false  # laid by a spell: it thaws by itself, and fire melts it
var _area := Rect2()
var _age := 0.0


func _ready() -> void:
	add_to_group("slick")
	add_to_group("slippery")  # anything in this group has `covers(point)`: a wizard on it cannot stop or turn quickly
	_area = Rect2(global_position + Vector2(0.0, -6.0), Vector2(width, 14.0))
	var strip := Sprite2D.new()  # glossy, scratched ice with ragged ends (see RockArt.ice_sheet)
	strip.texture = RockArt.ice_sheet(width, int(global_position.x))
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.scale = Vector2.ONE * RockArt.BLOCK
	strip.centered = false
	strip.position = Vector2(0.0, -8.0)
	add_child(strip)


func _physics_process(delta: float) -> void:
	if not thaws:
		return
	_age += delta
	if _age >= MELT_SECONDS or SpellTargets.fire_touching(get_tree(), _area):
		Fx.smoke(get_parent(), _area.get_center(), Color(0.85, 0.95, 1.0, 0.5), 5, 24.0, 30.0)
		queue_free()


## True when a point is on the ice.
func covers(point: Vector2) -> bool:
	return _area.has_point(point)


## True when a point is on any ice in the world that a foot slides on: a sheet, or the frozen top of a pond.
static func under(tree: SceneTree, point: Vector2) -> bool:
	for sheet: Node in tree.get_nodes_in_group("slippery"):
		if sheet.covers(point):
			return true
	return false
