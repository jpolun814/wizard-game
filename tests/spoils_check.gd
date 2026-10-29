extends Node

## A wizard that dies leaves its whole book where it fell, and whoever reads it holds every page of it.
##
##     godot --headless --path . --fixed-fps 60 tests/spoils_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree := get_tree()
	var person: Wizard = world.player
	var victim: Wizard = null
	for found: Wizard in tree.get_nodes_in_group("wizards"):
		if found != person and victim == null:
			victim = found
	var book: Array = victim.ledger.pages.keys()
	var before := tree.get_nodes_in_group("pages").size()
	victim.take_damage(10000)
	await tree.physics_frame
	await tree.physics_frame
	_verdict(victim.dead, "the wizard dies")
	var spoils: PagePickup = null
	for pickup: PagePickup in tree.get_nodes_in_group("pages"):
		if not pickup.spoils.is_empty():
			spoils = pickup
	_verdict(spoils != null and tree.get_nodes_in_group("pages").size() == before + 1, "its book lies where it fell")
	if spoils == null:
		tree.quit(1)
		return
	var same := spoils.spoils.size() == book.size() and book.all(func(each: String) -> bool: return spoils.spoils.has(each))
	_verdict(same, "it holds every page the wizard held (%d)" % book.size())
	var known := person.ledger.count()
	var gain := spoils.new_pages(person.ledger).size()
	_verdict(gain > 0, "there is something in it for the player to read (%d new pages)" % gain)
	person.global_position = spoils.global_position
	_verdict(spoils.is_under(person), "the player can stand under it")
	spoils.take(person.ledger)
	await tree.process_frame
	_verdict(person.ledger.count() == known + gain and book.all(func(each: String) -> bool: return person.ledger.knows(each)), "reading it gives every page")
	_verdict(not is_instance_valid(spoils) or spoils.is_queued_for_deletion(), "the book is gone from the ground")
	print("done" if _failures == 0 else "%d FAILED" % _failures)
	tree.quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
