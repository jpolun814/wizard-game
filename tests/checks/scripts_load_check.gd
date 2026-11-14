extends Check
## Every script of the game, and of the checks, loads: the start-up only loads what it reaches, so a name that no longer exists in a script that is seldom
## used (a screen, a look) would not show until someone opened it.


func _ready() -> void:
	var paths := _scripts_under("res://scripts") + _scripts_under("res://tests")
	var broken := 0
	for path in paths:
		if load(path) == null:
			broken += 1
			print("FAIL  does not load: ", path)
	_verdict(broken == 0, "all %d scripts load" % paths.size())
	print("%d FAILED" % _failures if _failures > 0 else "ok")
	get_tree().quit(1 if _failures > 0 else 0)


func _scripts_under(folder: String) -> Array[String]:
	var found: Array[String] = []
	for entry in DirAccess.get_directories_at(folder):
		found.append_array(_scripts_under(folder + "/" + entry))
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder + "/" + file)
	return found
