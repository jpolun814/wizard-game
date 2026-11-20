extends Check

## Casts EVERY spell in the game, one after another, through the real caster in the waiting room, and checks for each:
##   - the drawn picture is read as that spell (and not a misfire);
##   - the world shows something for it: a new node, or a change in the caster (a state, a position);
##   - nothing prints a script error (the runner fails on any SCRIPT ERROR in the output);
##   - it ends: what it made is gone, or counted as lasting on purpose, a few seconds after.
## With `-- leak=1` each spell is also followed for forty seconds, to see that what it made is gone (slow: not in the quick set).
## A new spell is covered the day its data file is added. Spells that make nothing new on purpose are listed in SELF_ONLY.
##
##     godot --headless --fixed-fps 60 --path . tests/checks/spell_sweep_check.tscn [-- shard=0/4] [-- only=Ignite]

## Spells that change the caster and add no node of their own.
const SELF_ONLY := ["Adrenaline", "Barrier", "Crimson Veil", "Obsidian Armor", "Sneak", "Featherfall", "Shadow Step", "Tide Surf", "Rocket Jump", "Wild Shape"]
## Spells that stay in the world for good by design: they are not expected to be gone.
## Spells drawn over someone.
const TARGETED := ["Hemorrhage", "Insect Plague", "Vacuum", "Leech", "Faint", "Hex", "Invincible Snail", "Hunter's Mark", "Fight or Flight"]
const LASTING := ["Updraft", "Stone Wall", "Great Oak", "Liana", "Sinkhole", "Stalagmite", "Mudslide", "Oil Slick", "Bramble", "Lily Pads", "Frost Bridge", "Glowcap", "Flytrap", "Moonbeam", "Eclipse", "Raise Dead", "Invincible Snail", "Bonfire", "Mirage", "Icicles", "Ice Prison", "Blizzard", "Geyser"]  # (a Blizzard snows until it is put out; a Geyser leaves its water in the pond)

var _lab: Lab
var _resolved := ""
var _misfired := false
var _floor := 0.0
var groups_of := {}  # spell -> the law groups what it made joined (the laws matrix reads this)


func _ready() -> void:
	Library.use_file("user://spell_sweep_check.json")
	Library.clear()
	_lab = load("res://scenes/lab.tscn").instantiate()
	add_child(_lab)
	for k in 30:
		await get_tree().process_frame
	_lab.hold_partner = true
	_floor = _lab._partner.global_position.y
	_lab.caster.cast_resolved.connect(func(spell: String, _t: String, _o: Vector2, _a: float, _i: Dictionary) -> void: _resolved = spell)
	_lab.caster.misfired.connect(func() -> void: _misfired = true)
	var args := _args()
	var names := SpellData.SPELLS.keys()
	names.sort()
	if args.has("only"):
		names = [args["only"]]
	elif args.has("shard"):
		var parts: PackedStringArray = args["shard"].split("/")
		var picked := []
		for k in names.size():
			if k % int(parts[1]) == int(parts[0]):
				picked.append(names[k])
		names = picked
	for spell_name: String in names:
		await _cast(spell_name)
	Library.clear()
	_lab.queue_free()
	if args.has("groups"):
		for spell_name: String in groups_of:
			print("GROUPS %s: %s" % [spell_name, ", ".join(groups_of[spell_name].keys())])
	print("%d spells cast, %d failures" % [names.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			out[a.get_slice("=", 0)] = a.get_slice("=", 1)
	return out


func _nodes() -> int:
	return get_tree().root.get_child_count() + _count(get_tree().current_scene if get_tree().current_scene else _lab)


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n


func _all(node: Node) -> Dictionary:
	var out := {node: true}
	for child in node.get_children():
		out.merge(_all(child))
	return out


## Notes the laws groups that the nodes a spell made have joined.
func _note_groups(spell_name: String, existing: Dictionary) -> void:
	var found: Dictionary = groups_of.get(spell_name, {})
	for node: Node in _all(_lab):
		if existing.has(node):
			continue
		for group in ["waters", "fires", "flares", "winds", "shots", "clouds", "lightning", "oil_slicks", "danger"]:
			if node.is_in_group(group):
				found[group] = true
	groups_of[spell_name] = found


## What of a wizard a spell can change at once.
func _state(w: Wizard) -> Array:
	return [w.global_position, w.stamina, w.velocity, w.marks, w.max_stamina, w.wet_time, w.burning_time, w.oiled_time, w.hex_time if "hex_time" in w else 0.0]


func _clear_world() -> void:
	for group in ["lasting", "walls", "rocks", "fires", "flora", "clouds", "shots", "projectiles"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Pond:
				node.queue_free()


func _cast(spell_name: String) -> void:
	var data: Spell = SpellData.SPELLS[spell_name]
	if not is_instance_valid(_lab.player):
		_verdict(false, "%s: the wizard of the room is gone before it is cast (the one before it ended the room)" % spell_name)
		return
	var player: Wizard = _lab.player
	_clear_world()
	await get_tree().physics_frame
	if not is_instance_valid(_lab._partner) or _lab._partner.dead:  # (a spell killed the partner: the room puts up another)
		_lab._spawn_partner()
		await get_tree().physics_frame
	player.stamina = player.max_stamina
	player.global_position = Vector2(ArenaGen.column_x(-16), _floor)
	player.velocity = Vector2.ZERO
	for k in 20:
		await get_tree().physics_frame
	var shape := GestureTemplates.preview_points(data.gesture)
	var ground := GestureTemplates.preview_ground(data.gesture)
	var middle := player.center() + Vector2(150.0, -20.0)
	if spell_name in TARGETED:  # (drawn over someone)
		middle = _lab._partner.center()
	if not is_nan(ground):
		middle.x = player.global_position.x + 70.0
		middle.y = player.global_position.y + 4.0 - (ground - GestureTemplates.bounds(shape).get_center().y)
	var stroke := BrainStrokes.offset(shape, middle, 1.0)
	_lab.caster.ground_check = _lab.caster.ground_check  # (the room's own)
	_resolved = ""
	_misfired = false
	var before := _count(_lab)
	var existing := _all(_lab)
	var partner: Wizard = _lab._partner
	var state_before := [_state(player), _state(partner)]
	Sfx.recording = true
	Sfx.heard.clear()
	_lab.caster.cast_stroke(data.buttons, stroke)
	var made := 0  # the most nodes it had up at once in the half second after
	var changed := false
	for k in 30:
		await get_tree().physics_frame
		made = maxi(made, _count(_lab) - before)
		_note_groups(spell_name, existing)
		if is_instance_valid(partner):
			changed = changed or state_before != [_state(player), _state(partner)]
	var heard: Array = Sfx.heard.duplicate()
	Sfx.recording = false
	_verdict(_resolved == spell_name, "%s: its picture is read as itself (got '%s'%s)" % [spell_name, _resolved, ", a misfire" if _misfired else ""])
	if _resolved == spell_name:
		_verdict(not heard.is_empty(), "%s: it is heard (%d sounds: %s)" % [spell_name, heard.size(), ", ".join(heard.slice(0, 4))])
		var loudest := 0
		for sound in heard:
			loudest = maxi(loudest, heard.count(sound))
		_verdict(loudest <= 12, "%s: no one sound is stacked up (%d of one in half a second)" % [spell_name, loudest])
		_verdict(made > 0 or changed or spell_name in SELF_ONLY, "%s: something happens in the world (%d nodes made)" % [spell_name, made])
	if not _args().has("leak"):
		return
	for k in 2400:  # forty seconds on: what a spell made is gone, unless it is meant to stay
		await get_tree().physics_frame
	var left := _count(_lab) - before
	if spell_name not in LASTING and spell_name not in SELF_ONLY and _resolved == spell_name:
		_verdict(left <= maxi(2, made / 2), "%s: it clears away when it is done (%d of %d nodes remain)" % [spell_name, left, made])
