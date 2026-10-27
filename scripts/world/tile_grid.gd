class_name TileGrid
extends RefCounted

## The tiles of a world, one byte each in a packed array (0 is open air, otherwise the material plus one). A world is hundreds
## of thousands of tiles, which a Dictionary of cells would hold far too slowly and in far too much memory.

var size := Vector2i.ZERO
var data := PackedByteArray()


func _init(world_size := Vector2i.ZERO, material := -1) -> void:
	size = world_size
	data.resize(size.x * size.y)
	if material >= 0:
		data.fill(material + 1)


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func has(cell: Vector2i) -> bool:
	return inside(cell) and data[cell.y * size.x + cell.x] != 0


## The material of a cell, or -1 for open air or outside the world.
func material(cell: Vector2i) -> int:
	if not inside(cell):
		return -1
	return int(data[cell.y * size.x + cell.x]) - 1


func put(cell: Vector2i, material_id: int) -> void:
	if inside(cell):
		data[cell.y * size.x + cell.x] = material_id + 1


func erase(cell: Vector2i) -> void:
	if inside(cell):
		data[cell.y * size.x + cell.x] = 0


func fill_rect(rect: Rect2i, material_id: int) -> void:
	for r in range(maxi(rect.position.y, 0), mini(rect.end.y, size.y)):
		for c in range(maxi(rect.position.x, 0), mini(rect.end.x, size.x)):
			data[r * size.x + c] = material_id + 1


func count() -> int:
	var total := 0
	for value in data:
		total += 1 if value != 0 else 0
	return total


func duplicate() -> TileGrid:
	var copy := TileGrid.new(size)
	copy.data = data.duplicate()
	return copy
