extends Check
## Frost Bridge on the ground. Drawn along level ground it freezes the ground into a sheet of ice, and all ice is slippery: a foot on it is "under" ice (a wizard on it cannot stop
## or turn quickly). Fire melts it. Drawn in the air, or where the ground is not level for a stretch, it freezes nothing.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/frost_ground_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _arena: Node
var _player: Wizard


func _ready() -> void:
	_arena = load("res://scenes/lab.tscn").instantiate()
	add_child(_arena)
	for k in 6:
		await get_tree().physics_frame
	_player = _arena.player
	var world := _player.get_world_2d()
	var x := 0.0
	var ground := Vector2.ZERO
	for from in range(-3000, 3000, 20):  # a stretch of level ground, wide enough for the line
		var level := SpellTargets.solid_below(world, Vector2(from, -600.0), 1400.0).y
		var flat := true
		for k in range(0, 260, 16):
			flat = flat and absf(SpellTargets.solid_below(world, Vector2(from + k, -600.0), 1400.0).y - level) < 2.0
		if flat:
			x = float(from)
			ground = Vector2(from, level)
			break
	_verdict(x != 0.0 or ground != Vector2.ZERO, "there is level ground to try it on")
	_verdict(IceSheet.under(get_tree(), Vector2(x + 50.0, ground.y)) == false, "bare ground is not slippery")
	_draw(Vector2(x, ground.y - 6.0), 200.0)
	await get_tree().physics_frame
	var sheets := get_tree().get_nodes_in_group("slick").filter(func(n: Node) -> bool: return n is IceSheet and n.thaws)
	_verdict(sheets.size() == 1, "a wavy line along the ground freezes it into a sheet of ice")
	_verdict(IceSheet.under(get_tree(), Vector2(x + 100.0, ground.y)), "and a foot on it is on ice, which is slippery")
	_verdict(not IceSheet.under(get_tree(), Vector2(x + 400.0, ground.y)), "but not a foot beyond it")
	# A flame melts it.
	Hazard.place(_arena, Vector2(x + 100.0, ground.y), 60.0, 4.0)
	for k in 30:
		await get_tree().physics_frame
	_verdict(sheets.all(func(s) -> bool: return not is_instance_valid(s) or s.is_queued_for_deletion()), "fire melts it")
	# Drawn in the air, it freezes nothing.
	_draw(Vector2(x, ground.y - 500.0), 200.0)
	await get_tree().physics_frame
	_verdict(get_tree().get_nodes_in_group("slick").filter(func(n: Node) -> bool: return n is IceSheet and n.thaws and not n.is_queued_for_deletion()).is_empty(), "a line drawn in the air freezes nothing")
	print("the ground freezes" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## A wavy line of this width, starting at a point, cast as Frost Bridge.
func _draw(from: Vector2, width: float) -> void:
	var points := PackedVector2Array()
	for k in 21:
		points.append(from + Vector2(width * k / 20.0, sin(k * 1.2) * 8.0))
	var info := {"line": points}
	_arena.spawn_spell("Frost Bridge", "shape", from + Vector2(width * 0.5, 0.0), 0.0, info, _player)
