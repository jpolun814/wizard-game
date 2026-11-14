class_name Casting
extends RefCounted

## What happens when a wizard's stroke has been read, the person's or a brain's: the same rules for both. The place or the spell may refuse it, it is paid for, and
## then it goes off. A stroke that means nothing is a misfire. Reached as `arena.casting`. What tells a person that a cast came to nothing is said at the
## pointer; a rival's wizard has nobody to tell.

const PERFECT := 0.95  # accuracy a cast needs for the flourish
const MISFIRE_COST := 10.0

var arena: Arena


func _init(owner_arena: Arena) -> void:
	arena = owner_arena


## The person's stroke has been read.
func by_person(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary) -> void:
	by(spell, targeting, origin, aim, info, arena.player)
	if not arena.player.ledger.knows_spell(spell):
		misfire_puff()  # a spell whose page has not been found is a shape that matches nothing


## A wizard's stroke has been read. It pays for the spell first.
func by(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Wizard) -> void:
	if not is_instance_valid(wizard) or wizard.dead:
		return
	var person := wizard == arena.player
	if person:
		wizard.play_cast_release()
	if not wizard.ledger.knows_spell(spell) or wizard.fainted or wizard.is_frozen():
		return
	var label_at := arena.get_global_mouse_position() + Vector2(0, -22) if person else wizard.center() + Vector2(0, -60)
	var refusal: Dictionary = _refusal(spell, info, aim, origin, wizard)
	if not refusal.is_empty():
		if person:
			_say(refusal["text"], refusal["color"], label_at, wizard, refusal["sound"])
		return
	var spell_data: Spell = SpellData.SPELLS[spell]
	var cost := spell_data.cost_for(info)
	if not spell_data.pays_max():
		cost = Leech.cost_after(arena.get_tree(), wizard, cost)  # on a tether, half of it falls on the other end
	var color := spell_data.glow()
	var paid := wizard.pay_max(cost) if spell_data.pays_max() else wizard.spend(cost)
	if not paid:
		# Blood is never spent to the last drop. Said to whoever the wizard is, not only to a person.
		_say("Too weak" if spell_data.pays_max() else "Too tired", Color("#ff9a9a") if spell_data.pays_max() else Color("#ffb86b"), label_at, wizard, true)
		if person and arena.is_in_group(&"world"):
			MatchStats.miss()
		return
	wizard.last_spell = spell
	if person:
		FloatText.spawn(arena, label_at, spell, color.lightened(0.25), 0.9)
		if info.get("accuracy", 0.0) >= PERFECT:
			_flourish(color)
	_everywhere(spell, targeting, origin, aim, info, wizard)


## Why this cast does not go off, as {text, color, sound}: the place forbids it (no ground to work on in the sky, no fire under the sea), or it finds no one to
## aim at. Nothing is paid then. An empty dictionary means nothing is wrong.
func _refusal(spell: String, info: Dictionary, aim: float, origin: Vector2, wizard: Wizard) -> Dictionary:
	if spell == "Icicles" and arena.spawner.shapes.icicle_spots(info).is_empty():
		return {"text": "Aim under a ceiling", "color": Color("#dff6ff"), "sound": true}
	var limit := SpellLimits.refusal(wizard, spell)
	if limit != "":
		return {"text": limit, "color": Color("#ffb86b"), "sound": true}
	if spell == "Faint" and AimedSpells.blood_target(arena.get_tree(), origin) == null:
		return {"text": "Aim at someone", "color": Color("#ff9a9a"), "sound": false}  # nothing is paid for a cut that finds no one
	if spell == "Leech" and Leech.pick(arena.get_tree(), wizard, aim) == null:
		return {"text": "Aim at someone", "color": Color("#ff9a9a"), "sound": false}  # nothing is paid for a tether that finds no one
	return {}


func _say(text: String, color: Color, at: Vector2, wizard: Wizard, sound: bool) -> void:
	FloatText.spawn(arena, at, text, color, 0.9)
	if sound:
		Sfx.play("misfire", wizard.center(), -6.0)


## A cast goes off on every machine of a network game, sent by the one that drives the wizard: the same spell in the same place, with the same throw of the dice
## for whatever it scatters. Each machine then decides what it does to the wizards that machine drives.
func _everywhere(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard: Wizard) -> void:
	var luck := randi()
	Net.send(arena, &"spawn_seen", [spell, targeting, origin, aim, info, String(wizard.name), luck])
	seed(luck)
	arena.spawn_spell(spell, targeting, origin, aim, info, wizard)


## Another machine's cast arrives: only the machine that drives a wizard casts for it.
func seen(spell: String, targeting: String, origin: Vector2, aim: float, info: Dictionary, wizard_name: String, luck: int) -> void:
	var wizard := arena.get_node_or_null(NodePath(wizard_name)) as Wizard
	if wizard == null or wizard.get_multiplayer_authority() != arena.multiplayer.get_remote_sender_id():
		return
	seed(luck)
	arena.spawn_spell(spell, targeting, origin, aim, info, wizard)


## The person drew a stroke that means nothing.
func misfire() -> void:
	arena.player.drain(MISFIRE_COST)
	misfire_puff()


## A brain's wizard drew a stroke that means nothing: it pays what a person pays (no word is drawn: no person reads it).
func misfire_by(wizard: Wizard) -> void:
	if not is_instance_valid(wizard) or wizard.dead:
		return
	wizard.drain(MISFIRE_COST)
	Sfx.play("misfire", wizard.center(), -6.0)


## What a shape or a chant that means nothing does: a puff, a sound and one word, so a player with the sound off still knows.
func misfire_puff() -> void:
	if arena.is_in_group(&"world"):
		MatchStats.miss()  # a stroke that matched nothing is a try that did not go off
	var at := arena.get_global_mouse_position()
	Sfx.play("misfire", arena.player.center())
	Fx.burst(arena, at, Color(0.6, 0.6, 0.65), 8, 80.0, 0.3)
	FloatText.spawn(arena, at + Vector2(0, -22), "Misfire", Color(0.75, 0.75, 0.82), 0.9)  # for a player with the sound off


## A perfect cast: a ring of the school's light opens round the wizard, sparks fly off it and a gold "Perfect" rises.
func _flourish(color: Color) -> void:
	var at: Vector2 = arena.player.center()
	# A ring of light in the school's color, opening round the wizard. It is a white texture, so the tint is the school's.
	var ring := Sprite2D.new()
	ring.texture = Fx.tex("circle_03")
	ring.material = Fx.additive()
	ring.modulate = color.lightened(0.35)
	ring.position = at
	ring.z_index = 8
	ring.scale = Vector2.ONE * (30.0 / Fx.TEX_SIZE)
	arena.add_child(ring)
	var open := arena.create_tween().set_parallel(true)
	open.tween_property(ring, "scale", Vector2.ONE * (150.0 / Fx.TEX_SIZE), 0.45).set_ease(Tween.EASE_OUT)
	open.tween_property(ring, "modulate:a", 0.0, 0.45)
	open.chain().tween_callback(ring.queue_free)
	Fx.burst(arena, at, color.lightened(0.6), 14, 170.0, 0.5, true, "star_04")
	FloatText.spawn(arena, at + Vector2(0, -52), "Perfect", Color("#ffe27a"), 1.0)
	Sfx.play("pickup", at, -6.0)
