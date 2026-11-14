class_name Check
extends Node
## The base of every check that runs as a scene: it keeps the count of what failed, and `_verdict` says whether one thing held. The script that runs
## the checks (tools/run_checks.py) reads "FAIL" and "FAILED" out of what a check prints.

var _failures := 0


## Prints one line for one thing that was meant to hold, and counts it if it did not.
func _verdict(ok: bool, what: String) -> void:
	if what == "":
		return
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
