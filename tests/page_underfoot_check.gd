extends Node

## Where pages lie within reach of each other, Tab reads the one that gives the wizard something: a new page before one the book already holds, and a page that is
## really there before a mirage. (A page read already used to stand between the wizard and a new one lying beside it, for good.)
##
##     godot --headless --path . --fixed-fps 60 tests/page_underfoot_check.tscn
## It prints PASS or FAIL for each check and exits with code 1 if any failed.

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Wizard = world.player
	for page in get_tree().get_nodes_in_group("pages"):
		page.queue_free()
	await get_tree().process_frame
	var feet := player.global_position
	player.ledger.learn("Ignite")
	var known := _lay(world, "Ignite", feet)  # laid first: the first in the group
	var fresh := _lay(world, "Frostbolt", feet + Vector2(10.0, 0.0))
	await get_tree().physics_frame
	_verdict(PagePickup.underfoot(get_tree()) == fresh, "a new page is read before one the book already holds")
	fresh.queue_free()
	await get_tree().process_frame
	_verdict(PagePickup.underfoot(get_tree()) == known, "with only the known one left, the book opens at it")
	var mirage := Mirage.conjure(world, feet)
	var real := _lay(world, "Barrier", feet + Vector2(12.0, 0.0))
	await get_tree().create_timer(2.5).timeout  # (it shimmers in first)
	_verdict(PagePickup.underfoot(get_tree()) == real, "a page that is there is read before a mirage (%s)" % mirage.name)
	print("tab reads what gives something" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _lay(world: Node, page: String, at: Vector2) -> PagePickup:
	var pickup := PagePickup.new()
	pickup.page = page
	pickup.position = at
	world.add_child(pickup)
	return pickup


func _verdict(ok: bool, message: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1
