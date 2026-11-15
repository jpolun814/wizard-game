extends Node

## The wall of nine crystals in the waiting room: it starts lit to the player's rating, a shot at a crystal lights it and every one before it, the match is played at
## that level, and the sparring partner (at the same level) fights only while the player is in its section.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/level_wall_check.tscn

func _ready() -> void:
	Library.use_file("user://level_wall_check.json")
	Library.clear()
	BrainLevel.match_level = 0
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var no_dummies: bool = lab.get_tree().get_nodes_in_group("mobs").is_empty()  # (before the partner can summon anything)
	var wall: LevelWall = lab._levels
	var start_level := wall.level
	var crystals: Array = wall.get_children().filter(func(n: Node) -> bool: return n is LevelCrystal)
	var shot := Projectile.new()
	shot.caster = lab.player
	shot._on_hit(crystals[4])
	var after := wall.level
	var lit := crystals.filter(func(c: LevelCrystal) -> bool: return c.get_node("Sprite").modulate == LevelWall.LIT).size()
	var match_level := BrainLevel.current()
	var partner: Wizard = lab._partner
	var partner_level: int = partner.brain.level
	var asleep: bool = partner.brain.dormant
	var floor_y := partner.global_position.y
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.SPAR_COL + 6), floor_y)
	for k in 20:
		await get_tree().process_frame
	var not_yet: bool = partner.brain.dormant  # (it takes no notice of someone only just come in)
	for k in 70:
		await get_tree().process_frame
	var awake: bool = not partner.brain.dormant
	lab.player.global_position = Vector2(ArenaGen.column_x(-9), floor_y)
	for k in 10:
		await get_tree().process_frame
	var asleep_again: bool = partner.brain.dormant
	# Standing in its section, the player is fought: it casts at them.
	wall.set_level(9)
	lab.player.global_position = Vector2(ArenaGen.column_x(Lab.SPAR_COL + 6), floor_y)
	var shots_seen := 0
	var lowest := Wizard.MAX_STAMINA
	for k in 1500:
		await get_tree().process_frame
		shots_seen = maxi(shots_seen, get_tree().get_nodes_in_group("shots").size())
		if is_instance_valid(lab._partner):
			lowest = minf(lowest, lab._partner.stamina)
	lab._spawn_partner()  # (a second call never leaves two)
	for k in 5:
		await get_tree().process_frame
	var rivals := get_tree().get_nodes_in_group("wizards").filter(func(w: Wizard) -> bool: return w != lab.player and not w.is_queued_for_deletion())
	var checks := {
		"only one partner in the room": rivals.size() == 1,
		"the book is at the right end of the room": lab._lectern.global_position.x > ArenaGen.column_x(40),
		"nine crystals": crystals.size() == 9,
		"it starts at the player's rating (a new one is level 1)": start_level == 1,
		"a shot at the fifth crystal sets level 5": after == 5 and lit == 5,
		"the match is played at it": match_level == 5,
		"the partner plays at it": partner_level == 5,
		"the partner sleeps while the player is away": asleep,
		"it takes no notice of someone only just come in": not_yet,
		"it wakes when the player has been in its section a moment": awake,
		"it sleeps again when they leave": asleep_again,
		"no dummies in the room": no_dummies,
		"the partner fights back when the player stands in its section": shots_seen > 0 or lowest < Wizard.MAX_STAMINA - 5.0,
		"the partner's own shots do not change the level": wall.level == 9,
		"it takes the new level at once": lab._partner.brain.level == 9 and BrainLevel.current() == 9,
	}
	var failed := false
	for what: String in checks:
		print("%s  %s" % ["PASS" if checks[what] else "FAIL", what])
		failed = failed or not checks[what]
	BrainLevel.match_level = 0
	Library.clear()
	get_tree().quit(1 if failed else 0)
