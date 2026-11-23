extends Node

## How often an AI wizard avoids a shot thrown straight at it, by how far off the thrower stands and how fast the shot is. Not a pass/fail check: it prints the
## numbers, so a change to the AI's footwork can be set beside the last (and beside the owner's own, from `python -I tools/duel_study.py`).
##
##     godot --path . --audio-driver Dummy tests/looks/dodge_bench.tscn -- level=9 shots=24
##     (a name after `--` such as `AI_OFF=dodge` is read from the environment instead)

var _lab: Lab
var _hits := 0
var awake := true
var _chose := ""
var _by := {}  # reaction -> [struck, avoided]
var _struck := false  # (a burn goes on hurting after a hit: one shot is one hit)


func _ready() -> void:
	Library.use_file("user://dodge_bench.json")
	Library.clear()
	var level := 9
	var shots := 24
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("level="):
			level = int(arg.get_slice("=", 1))
		elif arg.begins_with("shots="):
			shots = int(arg.get_slice("=", 1))
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().process_frame
	_lab._levels.set_level(level, false)
	_lab.hold_partner = true
	var floor_y: float = _lab._partner.global_position.y
	var partner: Wizard = _lab._partner
	partner.damaged.connect(func(_amount: int) -> void: _struck = true)
	var total_hit := 0
	var total := 0
	for gap: float in [220.0, 300.0, 380.0]:
		for kind: String in ["Ignite", "Frostbolt"]:
			_hits = 0
			for k in shots:
				partner.brain.rng.seed = k * 7919 + 13
				partner.global_position = Vector2(ArenaGen.column_x(-24), floor_y)
				partner.velocity = Vector2.ZERO
				partner.stamina = partner.max_stamina
				partner.max_stamina = Wizard.MAX_STAMINA
				_lab.player.global_position = Vector2(partner.global_position.x + gap, floor_y)
				_lab.player.velocity = Vector2.ZERO
				partner.brain.opponent = _lab.player
				await _wait(0.8)
				_struck = false
				_chose = "none"
				var shot: Projectile = Fireball.new() if kind == "Ignite" else IceSpear.new()
				shot.caster = _lab.player
				_lab.add_child(shot)
				var from: Vector2 = _lab.player.center()
				shot.setup(kind, from, (partner.center() - from).angle())
				await _wait(1.6)
				_hits += 1 if _struck else 0
				var row: Array = _by.get_or_add(_chose, [0, 0])
				row[0 if _struck else 1] += 1
				for s in get_tree().get_nodes_in_group("shots"):
					s.queue_free()
			print("%s from %d px: %d of %d struck (%.0f%% avoided)" % [kind, gap, _hits, shots, 100.0 * (1.0 - float(_hits) / shots)])
			total_hit += _hits
			total += shots
	print("all: %d of %d struck (%.0f%% avoided)" % [total_hit, total, 100.0 * (1.0 - float(total_hit) / total)])
	print("by what it chose [struck, avoided]: ", _by)
	Library.clear()
	get_tree().quit()


func _wait(seconds: float) -> void:
	for k in int(seconds * 60.0):
		await get_tree().physics_frame
		_lab._partner.brain.dormant = awake == false
		if _chose == "none" and _lab._partner.brain.react > 0.0:
			_chose = _lab._partner.brain._reaction
		_lab._partner.brain.cast_cooldown = maxf(_lab._partner.brain.cast_cooldown, 1.0)  # (it only dodges here: nothing it throws is part of the count)
