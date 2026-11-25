extends Node

## Holds the AI wizards to what a person could know. A brain may read another wizard only through what a person sees: its eyes, what was cast in view, what it
## says over its head. It may not read a rival's strength, book or health, count who is left in the match, ask whether a rival is a person, or look at the
## match's clock. This reads the brain's scripts and fails on any line that does. (A line that must break the rule, for a reason that is written beside it,
## ends with `# knows:` and the reason.)
##
## Run from the project folder:  godot --headless --fixed-fps 60 --path . tests/checks/knowledge_check.tscn

## Each needle is something a person at the screen could not know, and why. (The first group is made up of every rival's name for itself and every private fact.)
const WHO := ["foe", "opponent", "other", "rival", "target"]
const PRIVATE := ["stamina", "max_stamina", "ledger", "is_person", "brain"]
const FORBIDDEN := {
	"get_nodes_in_group(\"wizards\")": "the whole list of wizards: a person sees only those on the screen (use Eyes and BrainSight.known)",
	"SpellTargets.wizards(": "the whole list of wizards (counting who is left tells it what no one shows a person)",
	"stage_time": "the match's clock",
	"MatchState.plan": "the match's plan",
	"MatchState.hurry": "the match's clock",
}
## Old lines that break a rule and are known: each is listed so that no new one is added; fixing one means taking it off this list.
const KNOWN := [
	"brain_profile.gd:SpellTargets.wizards",
	"brain_sight.gd:SpellTargets.wizards",
]


func _ready() -> void:
	var failures := 0
	var scanned := 0
	var dir := DirAccess.open("res://scripts/brain")
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		scanned += 1
		var lines := FileAccess.get_file_as_string("res://scripts/brain/" + file).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			var code := line.get_slice("#", 0) if not line.contains("# knows:") else ""
			if file == "zz_tmp.gd":
				print("LINE[", code, "]")
			var needles := FORBIDDEN.duplicate()
			for who: String in WHO:
				for fact: String in PRIVATE:
					needles[who + "." + fact] = "a rival's strength, book or kind is not seen"
			for needle: String in needles:
				var at := code.find(needle)
				if at < 0:
					continue
				if at > 0 and (code[at - 1] == "_" or code[at - 1] == "." or code[at - 1].to_lower() != code[at - 1].to_upper()):
					continue  # (the end of a longer name, or something's own)
				var listed := false
				for known: String in KNOWN:
					if known.begins_with(file + ":") and code.contains(known.get_slice(":", 1)):
						listed = true
				if not listed:
					failures += 1
					print("FAIL %s:%d  %s -- %s" % [file, i + 1, needles[needle], line.strip_edges()])
	print("%d brain lines break what a person could know" % failures if failures > 0 else "ok knowledge_check (%d scripts read)" % scanned)
	get_tree().quit(1 if failures > 0 else 0)
