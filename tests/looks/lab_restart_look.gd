extends Node

## The waiting room's width before and after a restart (R): it must come out the same. (Needs a window; pass --audio-driver Dummy.)


func _ready() -> void:
	var tree := get_tree()
	var first: Node = load("res://scenes/lab.tscn").instantiate()
	tree.root.add_child(first)
	tree.current_scene = first
	for k in 30:
		await tree.process_frame
	_report("first")
	tree.reload_current_scene()
	for k in 40:
		await tree.process_frame
	_report("after R")
	tree.quit()


func _report(label: String) -> void:
	var ponds := get_tree().get_nodes_in_group("ponds")
	var lab := get_tree().current_scene
	print(label, ": right wall ", ArenaGen.right_wall, ", chunks ", ArenaGen.chunk_count, ", scene ", lab.name)
