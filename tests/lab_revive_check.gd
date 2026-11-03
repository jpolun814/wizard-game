extends Node

## Whoever falls in the waiting room is on their feet again at once, and no game-over screen comes up.
##
##     godot --headless --fixed-fps 60 --path . tests/lab_revive_check.tscn

func _ready() -> void:
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 10:
		await get_tree().process_frame
	lab.player.take_damage(1000, false)
	var died := lab.player.dead
	for k in 5:
		await get_tree().process_frame
	var checks := {
		"the blow felled them": died,
		"they are up again": not lab.player.dead and lab.player.max_stamina == Wizard.MAX_STAMINA and lab.player.movement_enabled,
		"no game-over screen": not lab.hud.is_game_over(),
	}
	var failed := false
	for what: String in checks:
		print("%s  %s" % ["PASS" if checks[what] else "FAIL", what])
		failed = failed or not checks[what]
	get_tree().quit(1 if failed else 0)
