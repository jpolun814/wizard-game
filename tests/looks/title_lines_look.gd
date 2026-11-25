extends Node

## Lists every spell and chant whose name takes two lines on its spellbook page (a look, not a check).

func _lines_of(node: Node, text: String) -> int:
	if node is Label and (node as Label).text == text:
		return (node as Label).get_line_count()
	for child in node.get_children():
		var n := _lines_of(child, text)
		if n > 0:
			return n
	return 0

func _ready() -> void:
	Library.use_file("user://title_lines_look.json")
	Library.clear()
	Lab.plain_room = false
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().process_frame
	var names: Array = SpellData.SPELLS.keys()
	for id in RitualInput.RITUALS:
		names.append(RitualInput.RITUALS[id]["name"])
	for n: String in names:
		lab.spellbook.show_page(n)
		for k in 3:
			await get_tree().process_frame
		var lines := _lines_of(lab.spellbook, n)
		if lines != 1:
			print("TWO_LINES ", lines, " ", n)
	print("DONE ", names.size())
	Library.clear()
	get_tree().quit()
