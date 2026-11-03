class_name Hall

## The waiting room's place as a bare stage for a cut-scene: its backdrop and a level floor with nothing standing on it. The opening cut-scene
## and the one after a win both play here, so they look like the room the book was touched in.


static func build(parent: Node2D, rng: RandomNumberGenerator) -> void:
	var backdrop := Backdrop.new()
	parent.add_child(backdrop)
	backdrop.build(ArenaGen.BIOMES[ArenaGen.WAITING_ROOM_BIOME]["backdrop"])
	var flat := PackedFloat32Array()  # level ground the whole way: the arena's own heights are hills
	flat.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
	var cells := ArenaGen.build(rng, flat)
	for cell: Vector2i in cells.keys():  # only the floor: no props of the arena's chunks, which stand where the wizards do
		if cell.y < ArenaGen.GROUND_ROW and cell.x > ArenaGen.LEFT_WALL and cell.x < ArenaGen.right_wall:
			cells.erase(cell)
	var ground := Terrain.new()
	parent.add_child(ground)
	ground.build(cells, ArenaGen.WAITING_ROOM_BIOME, rng, false)  # bare: a hooded statue among them would pass for a fifth wizard
