extends SceneTree

## The flowing liquid on its own, with no world: it falls, spreads level, fills a pit beside it, keeps what it started with, goes to sleep when still,
## and is quick enough to run in a game.
##
##     godot --headless -s tests/test_liquid.gd
## It prints each failure and exits with code 1 if anything failed.

var _failures := 0


func _initialize() -> void:
	_falls_and_levels()
	_vessels_join()
	_fills_a_pit()
	_speed()
	print("liquid checks done, %d failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


## A grid of open cells, walled in with ground all round.
func _box(cols: int, rows: int) -> LiquidGrid:
	var grid := LiquidGrid.new()
	grid.setup(Rect2(Vector2.ZERO, Vector2(cols, rows) * LiquidGrid.CELL))
	grid.read_ground(func(point: Vector2) -> bool:
		var cell := grid.cell_at(point)
		return cell.x == 0 or cell.y == 0 or cell.x == cols - 1 or cell.y == rows - 1)
	return grid


func _settle(grid: LiquidGrid, limit := 2000) -> int:
	var steps := 0
	while not grid.asleep and steps < limit:
		grid.step()
		steps += 1
	return steps


func _falls_and_levels() -> void:
	var grid := _box(22, 14)
	for r in range(1, 6):
		grid.mass[r * grid.cols + 10] = 1.0  # a column of water standing in the air
	grid.wake()
	var before := grid.total()
	var steps := _settle(grid)
	_verdict(grid.asleep, "water dropped in a box comes to rest (%d steps)" % steps)
	_verdict(absf(grid.total() - before) < before * 0.02, "and none of it is lost (%.2f of %.2f)" % [grid.total(), before])
	var low := INF
	var high := 0.0
	for c in range(1, grid.cols - 1):
		var level := grid.surface_at(grid.origin.x + (c + 0.5) * LiquidGrid.CELL)
		low = minf(low, level)
		high = maxf(high, level)
	_verdict(high - low < LiquidGrid.CELL * 0.6, "and lies level (%.1f px between the highest and the lowest)" % (high - low))


func _vessels_join() -> void:
	# Two tall arms joined at the bottom: water poured into one rises in the other.
	var grid := LiquidGrid.new()
	var cols := 9
	var rows := 14
	grid.setup(Rect2(Vector2.ZERO, Vector2(cols, rows) * LiquidGrid.CELL))
	grid.read_ground(func(point: Vector2) -> bool:
		var cell := grid.cell_at(point)
		if cell.x == 0 or cell.x == cols - 1 or cell.y == rows - 1:
			return true
		return cell.x == 4 and cell.y < rows - 2)  # a wall between the arms, open at the bottom
	for r in range(2, 12):
		grid.mass[r * cols + 2] = 1.0
	grid.wake()
	_settle(grid)
	var left := grid.surface_at((2 + 0.5) * LiquidGrid.CELL)
	var right := grid.surface_at((6 + 0.5) * LiquidGrid.CELL)
	_verdict(right < INF and absf(left - right) < LiquidGrid.CELL * 1.3, "water poured into one arm of a U rises in the other (%.0f and %.0f)" % [left, right])


func _fills_a_pit() -> void:
	# A shallow pool in a basin on a shelf. The ground beside it is dug away into a deeper pit: the water pours in and the basin drains.
	var cols := 30
	var rows := 16
	var grid := LiquidGrid.new()
	grid.setup(Rect2(Vector2.ZERO, Vector2(cols, rows) * LiquidGrid.CELL))
	var dug := [false]
	var ground := func(point: Vector2) -> bool:
		var cell := grid.cell_at(point)
		if cell.x == 0 or cell.x == cols - 1 or cell.y >= rows - 1:
			return true
		if cell.y < 6:
			return false
		if cell.x >= 3 and cell.x <= 10 and cell.y <= 7:
			return false  # the basin
		if dug[0] and cell.x >= 9 and cell.x <= 17 and cell.y <= 11:
			return false  # the pit
		return true
	grid.read_ground(ground)
	grid.fill(Rect2(Vector2(3, 6) * LiquidGrid.CELL, Vector2(8, 2) * LiquidGrid.CELL))
	_settle(grid)
	var before := grid.total()
	_verdict(grid.wet_at(Vector2(5.5, 7.5) * LiquidGrid.CELL) and not grid.wet_at(Vector2(14.5, 10.5) * LiquidGrid.CELL), "a pool sits in its basin, and the ground beside it is dry")
	dug[0] = true
	grid.read_ground(ground)
	var steps := _settle(grid)
	_verdict(grid.wet_at(Vector2(14.5, 11.5) * LiquidGrid.CELL), "when the ground beside it is dug away the water pours into the pit (%d steps)" % steps)
	_verdict(absf(grid.total() - before) < before * 0.01, "and nothing is lost on the way (%.2f of %.2f)" % [grid.total(), before])
	_verdict(not grid.wet_at(Vector2(4.5, 7.5) * LiquidGrid.CELL), "and the basin, now higher than the water, is left dry")
	var level := grid.surface_at(13.5 * LiquidGrid.CELL)
	_verdict(level > 9.5 * LiquidGrid.CELL and level < 11.5 * LiquidGrid.CELL, "the water lies level in the pit (surface at %.1f cells)" % (level / LiquidGrid.CELL))


func _speed() -> void:
	# A big pool woken all at once: how long a step takes, and how many it needs to settle.
	var cols := 70
	var rows := 30
	var grid := LiquidGrid.new()
	grid.setup(Rect2(Vector2.ZERO, Vector2(cols, rows) * LiquidGrid.CELL))
	grid.read_ground(func(point: Vector2) -> bool:
		var cell := grid.cell_at(point)
		return cell.x == 0 or cell.x == cols - 1 or cell.y >= rows - 1)
	grid.fill(Rect2(Vector2(1, 12) * LiquidGrid.CELL, Vector2(cols - 2, 10) * LiquidGrid.CELL))
	for c in range(20, 30):
		grid.solid[(rows - 5) * cols + c] = 0
		for r in range(rows - 5, rows - 1):
			grid.solid[r * cols + c] = 0  # a pit under the pool, which it drains into
	grid.wake()
	var began := Time.get_ticks_usec()
	var steps := 0
	var worst := 0
	while not grid.asleep and steps < 3000:
		var t := Time.get_ticks_usec()
		grid.step()
		worst = maxi(worst, Time.get_ticks_usec() - t)
		steps += 1
	var average := (Time.get_ticks_usec() - began) / maxi(steps, 1) / 1000.0
	print("INFO  a pool of %d cells settled in %d steps: %.2f ms a step on average, %.2f ms at worst" % [cols * 10, steps, average, worst / 1000.0])
	_verdict(worst < 12000, "no single step takes long enough to be felt (%.1f ms)" % (worst / 1000.0))
	_verdict(grid.asleep, "and the pool does come to rest")
