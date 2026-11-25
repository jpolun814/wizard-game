extends Lab
## A bare room for the movement drills (tests/checks/movement_drills.gd): ground of any shape, and slabs over it. Nothing in it is named for the AI: its map holds what
## can be walked and jumped, and no crossing, gate or lift. Set `plan` and `slabs` before it is made.

const COLUMNS := 48

static var plan := PackedFloat32Array()  # the height of the ground in each column, in rows below the flat line (less than 0 is higher)
static var slabs: Array[Rect2i] = []     # blocks of stone, in tiles


func _init() -> void:
	heals_wounds = false
	_set_width()


func _enter_tree() -> void:
	super()
	_set_width()


func _set_width() -> void:
	ArenaGen.chunk_count = COLUMNS / ArenaGen.CHUNK_WIDTH
	ArenaGen.right_wall = ArenaGen.FIRST_COL + COLUMNS


func _build_map() -> Variant:
	var cells := ArenaGen.build(_rng, plan.duplicate())
	for slab in slabs:
		for col in range(slab.position.x, slab.end.x):
			for row in range(slab.position.y, slab.end.y):
				cells[Vector2i(col, row)] = ArenaGen.STONE
	return cells


func _begin_encounter(camera: Camera2D) -> void:
	player.infinite_time = 0.0
	camera.reset_smoothing()


## The map of the ways as the ground alone makes it.
func plain_map() -> WorldNav:
	var cells: Dictionary = map_cells()
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var grid := TileGrid.new(high - low + Vector2i.ONE)
	for cell: Vector2i in cells:
		grid.put(cell - low, cells[cell])
	var map := WorldNav.new()
	map.origin = low
	map.build(grid, grid.size.y)
	return map


func _on_player_died() -> void:
	pass
