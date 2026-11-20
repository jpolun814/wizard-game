extends Check

## A stroke a caster is GIVEN (Fight or Flight makes someone draw a spell, a brain draws its own) must not stay on the screen: it fades and is gone. A caster that is not running
## never redraws, so a stroke it was handed once hung there in perfect template lines.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/forced_stroke_check.tscn

func _ready() -> void:
	Library.use_file("user://forced_stroke_check.json")
	Library.clear()
	Lab.plain_room = false
	var lab: Lab = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	for k in 30:
		await get_tree().physics_frame
	var player: Wizard = lab.player
	_verdict(player.caster == null, "the person's own wizard has no caster of its own until one is needed")
	var hand := player.ensure_caster()
	var data: Spell = SpellData.SPELLS["Ignite"]
	hand.cast_stroke(data.buttons, BrainStrokes.offset(GestureTemplates.preview_points(data.gesture), player.center() + Vector2(120.0, -30.0), 1.0))
	await get_tree().physics_frame
	_verdict(hand.get("_stroke").size() > 1, "the stroke it was given is shown at first")
	for k in 90:
		await get_tree().physics_frame
	_verdict(hand.get("_stroke").is_empty(), "and is gone after it has faded")
	Library.clear()
	print("%d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
