extends Node

## The book's order and its mark of what is new: in a match the pages are grouped by school and, within a school, in the order they were found; in the
## tutorial they stay in the order they were found. A page is marked NEW until the spell has been cast (or the chant said).
##
##     godot --headless --fixed-fps 60 --path . tests/checks/spellbook_order_check.tscn

var _failed := false


func _verdict(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	_failed = _failed or not ok


func _ready() -> void:
	var found := ["Frostbolt", "Stonefall", "Ignite", "Icicles", "Flare"]  # Water, Earth, Fire, Water, Fire: the order they were read
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 10:
		await get_tree().process_frame
	lab.player.ledger = Ledger.of(found)
	lab.spellbook.refresh()
	var at: Dictionary = lab.spellbook._page_of
	_verdict(at["Ignite"] < at["Flare"] and at["Flare"] < at["Frostbolt"] and at["Frostbolt"] < at["Icicles"] and at["Icicles"] < at["Stonefall"], "in a match the pages are grouped by school (Fire, Water, Earth)")
	_verdict(at["Ignite"] < at["Flare"], "and within a school in the order they were found (Ignite before Flare)")
	_verdict(lab.spellbook._is_new("Ignite"), "a spell not yet cast is marked new")
	lab.player.ledger.mark_cast("Ignite")
	_verdict(not lab.spellbook._is_new("Ignite") and lab.spellbook._is_new("Flare"), "and not once it has been cast")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("out=") and DisplayServer.get_name() != "headless":
			lab.spellbook.show_page("Flare")
			for k in 90:
				await get_tree().process_frame
			DirAccess.make_dir_recursive_absolute(argument.trim_prefix("out="))
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("out=") + "/new_badge.png")
	lab.queue_free()
	var room: Tutorial = load("res://scenes/tutorial.tscn").instantiate()
	add_child(room)
	for k in 10:
		await get_tree().process_frame
	room.player.ledger = Ledger.of(found)
	room.spellbook.refresh()
	var order: Dictionary = room.spellbook._page_of
	_verdict(order["Frostbolt"] < order["Stonefall"] and order["Stonefall"] < order["Ignite"] and order["Ignite"] < order["Icicles"], "in the tutorial the pages stay in the order they were found")
	get_tree().quit(1 if _failed else 0)
