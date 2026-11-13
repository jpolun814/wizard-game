extends Node

## Sneak hides a wizard from everyone else: not drawn on anyone's screen but their own, passed over by the other wizards' brains, mobs, Insight and
## the Hunter's Mark, until someone is almost on top of them.
##
##     godot --headless --fixed-fps 60 --path . tests/sneak_check.tscn

var _failures := 0


func _ready() -> void:
	World.random_start = false
	World.arrive_by_portal = false
	World.next_seed = 8
	MatchState.hurry = 100.0
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var me: Wizard = world.player
	var rivals: Array[Wizard] = []
	for found: Wizard in get_tree().get_nodes_in_group("wizards"):
		if found != me:
			rivals.append(found)
	var rival := rivals[0]
	var other := rivals[1]
	var brain: WizardBrain = rival.brain
	other.global_position = Vector2(-9000.0, -9000.0)
	rivals[2].global_position = Vector2(-9000.0, -9100.0)
	me.global_position = rival.global_position + Vector2(300.0, 0.0)
	me.fade_from_sight(20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(me.is_faded() and not me.is_unseen(), "the one who is sneaking still sees themselves")
	_verdict(me.visible, "and is drawn on their own screen")
	rival.fade_from_sight(20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(rival.is_unseen() and not rival.visible, "a rival who is sneaking is not drawn")
	rival.global_position = me.global_position + Vector2(300.0, 0.0)
	_verdict(not rival.is_seen_from(me.global_position), "and cannot be made out from a way off")
	_verdict(rival.is_seen_from(rival.global_position + Vector2(20.0, 0.0)), "but is felt when someone is almost on top of them")
	_verdict(HuntersMark.nearest_other(get_tree(), me.center(), me) != rival, "the Hunter's Mark does not lead to them")
	var hunter: Wizard = other
	hunter.global_position = rival.global_position + Vector2(400.0, 0.0)
	var foe: Wizard = hunter.brain.sight.nearest_foe()
	_verdict(foe != rival, "another wizard's brain does not pick them out (%s)" % foe)
	rival.break_sneak()
	await get_tree().process_frame
	await get_tree().process_frame
	_verdict(rival.visible and not rival.is_unseen(), "and they are drawn again once they cast")
	print("sneaking hides a wizard" if _failures == 0 else "%d FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _verdict(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
