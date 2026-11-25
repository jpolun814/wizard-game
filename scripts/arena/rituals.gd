class_name Rituals
extends RefCounted

## The chants of the person at this machine, and of the brains: opening the box, what each chant does when it is said, the Rift, the Scrying Eye.
## Reached as `arena.rituals`. What other machines are shown (`kindle`, `show_chant`, `show_eye`) is sent from the arena's own rpc calls, which must stay on the node.

const RIFT_WEAR := 35.0  # what a Rift takes off the most stamina you can have
const RIFT_LEAST := 20.0  # the least stamina a Rift can be cast with, and the least it leaves as the most

var arena: Arena


func _init(owner_arena: Arena) -> void:
	arena = owner_arena


## The key that opens the chant box: not while frozen, silenced by a faint voice or holding the breath.
func start() -> void:
	var player := arena.player
	if player.is_frozen():
		return
	if player.is_muted():
		arena.feedback("Wait for your voice to return.", Color.ORANGE)
		return
	if player.lungs.holding():
		return  # the bubbles over the head say why
	arena.ritual.open()
	# Stop this key press from also reaching the text box it just opened.
	arena.get_viewport().set_input_as_handled()


## A chant has been typed: it works as well as it was said, or backfires if it was garbled.
func finished(id: String, acc: float, unfinished: bool) -> void:
	var player := arena.player
	var data: Dictionary = RitualInput.RITUALS[id]
	if not player.ledger.knows_chant(id):
		arena.casting.misfire_puff()
		return
	if player.lungs.holding():
		return
	if unfinished:
		# Stopping a chant partway lets the words fade harmlessly; only a garbled chant backfires.
		return
	player.break_sneak()
	player.ledger.mark_cast("chant:" + id)
	if data["kind"] == "toggle":
		toggle(data, acc)
		return

	if id == "rift" and (player.max_stamina - RIFT_WEAR < RIFT_LEAST or player.stamina < RIFT_LEAST):
		arena.feedback("Too frail." if player.stamina >= RIFT_LEAST else "Too tired.", Color("#ffb86b"))
		Sfx.cue("rituals", "misfire", player.center(), -6.0)
		return
	var power := RitualInput.power_for(acc)
	if power <= 0.0:
		player.take_damage(15)
		Sfx.cue("rituals", "explosion", player.center())
		Fx.impact(arena, player.center(), Color("#ff4a4a"), 50.0)
		return

	arena.show_chant(String(player.name))
	Net.send(arena, &"show_chant", [String(player.name)])
	grant(player, id, power)
	match id:
		"rift":
			_rift()
		"dowsing":
			_dowse()


## A brain's wizard says one of the chants that give a gift, (the others make marks and portals, which have only the player's own).
## It says it perfectly. False when it does not know the chant, cannot speak or is under water.
func said_by(speaker: Wizard, id: String) -> bool:
	if not is_instance_valid(speaker) or speaker.dead or not speaker.ledger.knows_chant(id) or speaker.is_muted() or speaker.is_frozen() or speaker.lungs.holding():
		return false
	speaker.break_sneak()
	arena.show_chant(String(speaker.name))
	Net.send(arena, &"show_chant", [String(speaker.name)])
	grant(speaker, id)
	return true


## The chants that give their speaker something, for a while or (see Ledger.LASTING) for the rest of the match. `power` is how well it was said (1 for a brain).
func grant(speaker: Wizard, id: String, power := 1.0) -> void:
	speaker.ledger.settle(id)
	speaker.mending.act()  # a chant is said: a Rest, which is stillness, is over
	if Mending.CHANTS.has(id):
		speaker.mending.say(id, power)
	match id:
		"boundless":
			speaker.grant_unlimited(20.0)
		"double_jump":
			speaker.grant_air_jump(20.0)
		"haste":
			speaker.grant_haste(20.0)
		"deep_breath":
			speaker.lungs.grant_deep(Lungs.DEEP_BREATH)
		"darkvision":
			give_sight(speaker)


## The light of the Chant of Darkvision, a flare with no flame, on a wizard: it lasts until they fall, and a later world of the match gives it again (the chant, once
## said, holds: see `Ledger.LASTING`). A new one replaces the old.
func give_sight(speaker: Wizard) -> void:
	var sight := Flare.new()
	sight.unseen = true
	sight.caster = speaker
	arena.add_child(sight)


## True when a wizard has the light of Darkvision on them.
func has_sight(speaker: Wizard) -> bool:
	for flare: Flare in arena.get_tree().get_nodes_in_group("flares"):
		if flare.unseen and flare.caster == speaker and not flare.is_queued_for_deletion():
			return true
	return false


## A chant takes hold: a ring of light under the speaker.
func show_chant(speaker_name: String) -> void:
	var speaker := arena.get_node_or_null(NodePath(speaker_name)) as Wizard
	if speaker == null:
		return
	Sfx.cue("rituals", "chant", speaker.center())
	Fx.pop(arena, speaker.global_position + Vector2(0, -2), "magic_02", Color(1.0, 0.9, 0.6), 80.0, 0.8, 1.3, 2.0)


## A little eye floats over a wizard while another watches them through the Chant of the Scrying Eye.
func show_eye(wizard_name: String, on: bool) -> void:
	var wizard := arena.get_node_or_null(NodePath(wizard_name)) as Wizard
	if wizard == null:
		return
	var mark := wizard.get_node_or_null("EyeMark")
	if on and mark == null:
		mark = EyeMark.new()
		mark.name = "EyeMark"
		wizard.add_child(mark)
	elif not on and mark != null:
		mark.queue_free()


## The Chant of Dowsing: an arrow points to the nearest page the player has not read, until they read it. Chanting again looks for another.
func _dowse() -> void:
	var player := arena.player
	for old in arena.get_tree().get_nodes_in_group("dowsings"):
		old.queue_free()
	var page := Dowsing.nearest_unread(arena.get_tree(), player.center(), player.ledger)
	if page == null:
		arena.feedback("Nothing left to find.", Color("#ffe9a0"))
		return
	var dowsing := Dowsing.new()
	dowsing.target = page
	dowsing.ledger = player.ledger
	arena.add_child(dowsing)


## The Rift: the wizard is torn away and set down somewhere else, with no stamina left and 20 less to ever have.
func _rift() -> void:
	var player := arena.player
	var color: Color = SpellData.SCHOOL_COLORS["Shadow"]
	var start: Vector2 = player.global_position
	player.max_stamina -= RIFT_WEAR
	player.drain(player.stamina)
	player.stamina = minf(player.stamina, player.max_stamina)
	player.global_position = arena.rift_spot(start)
	player.reset_physics_interpolation()
	player.velocity = Vector2.ZERO
	Fx.pop(arena, start + Vector2(0, -24), "twirl_02", color, 60.0, 0.3, 0.3, 8.0)
	Fx.burst(arena, start + Vector2(0, -24), color, 16, 140.0, 0.3, true)
	Fx.pop(arena, player.global_position + Vector2(0, -24), "twirl_02", color, 24.0, 0.3, 2.4, -8.0)
	Fx.burst(arena, player.global_position + Vector2(0, -24), color, 16, 140.0, 0.3, true)
	Sfx.cue("rituals", "dark_whoosh", player.global_position, -2.0)


## A toggle chant shows or hides a HUD module. Incantations cost no stamina.
func toggle(data: Dictionary, acc: float) -> void:
	if acc < RitualInput.BACKFIRE_BELOW:
		arena.feedback("Check the words and try again.", Color.GRAY)
		return
	var module: String = data["module"]
	arena.revealed[module] = true  # said once, it holds for the rest of the match
	arena.player.ledger.settle(module)
	Sfx.cue("rituals", "chant", arena.player.center(), -6.0)
