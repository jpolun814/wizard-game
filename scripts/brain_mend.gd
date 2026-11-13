class_name BrainMend
extends RefCounted

## How an AI wizard looks after itself: resting to get its strength back, camping at a bonfire, and the small things it tends to (a light in the dark, its health, the scent of whoever it has lost).

var camped := false             # it rests by a bonfire to mend
var camped_for := 0.0
var mend_wait := 0.0
var resting := false            # it has stopped to get its breath back
var tend_cooldown := 3.0        # counting down to the next time it looks to its own needs

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Wounds: a wizard worn down to a small maximum, with no one at its heels, lights a bonfire (or goes to one that burns) and rests by it until it has
## mended, as a person does. Returns the speed to walk at, or NAN when it is not mending.
func mend(delta: float, fighting: bool) -> float:
	mend_wait -= delta
	if (brain.chant.is_typing() or camped or brain.settle > 0.0) and (brain.assailant() != null or brain.danger.scorched() or brain.danger.bitten()):  # it does not sit and chant with a blade or a flame on it
		brain.chant.typing = ""
		brain.settle = 0.0
		camped = false
		mend_wait = 3.0
		return NAN
	var fire := bonfire_near(wizard.global_position, 900.0)
	if camped:
		camped_for += delta
		var healed := wizard.max_stamina >= Wizard.MAX_STAMINA * WizardBrain.MEND_UNTIL
		if fighting or healed or camped_for > WizardBrain.MEND_MAX or fire == null or wizard.wild:
			camped = false
			mend_wait = 12.0
			return NAN
		var off := fire.global_position.x - wizard.global_position.x
		if absf(off) > 50.0:
			return signf(off) * WizardBrain.WALK_SPEED * 0.8
		return 0.0
	if fighting or mend_wait > 0.0 or wizard.max_stamina >= Wizard.MAX_STAMINA * WizardBrain.MEND_BELOW or not wizard.is_on_floor() or wizard.is_drawing() or wizard.wild:
		return NAN
	if fire != null and absf(fire.global_position.y - wizard.global_position.y) < 120.0:
		camped = true
		camped_for = 0.0
		return 0.0
	if brain.knows("chant:bonfire"):
		if not brain.quiet_here():  # not here: it goes on a while, and tries again
			mend_wait = 5.0
			return NAN
		brain.chant.open("bonfire")
		return 0.0
	mend_wait = 30.0
	return NAN


## Looks to what it needs, and casts for it: a way up to a rival over its head, a light in the dark, its strength, and something between it and a rival who
## is hurting it. True when it has begun a cast.
func tend(to_player: Vector2, sees: bool, fighting: bool) -> bool:
	if fighting and brain.chase(to_player):
		return true
	var gap := absf(to_player.x)
	var low := wizard.max_stamina < Wizard.MAX_STAMINA * 0.45
	var tired := resting or wizard.stamina < 35.0
	var weights := {}
	if brain.in_dark():
		weights["Flare"] = 1.5
		weights["Glowcap"] = 0.6 if tired or fighting else 0.0
		weights["Moonbeam"] = 0.8 if fighting else 0.0
	if (tired or (fighting and gap > WizardBrain.FAR)) and wizard.adrenaline_time <= 0.0:
		weights["Adrenaline"] = 1.2
	if fighting and sees and gap < 260.0 and wizard.max_stamina > 90.0 and not wizard.wild:
		weights["Wild Shape"] = 1.1  # a rival close at hand: it comes at them with claws
	if brain.goal != "page" and brain.scent <= 0.0 and SpellTargets.wizards(wizard.get_tree()).size() > 1:
		weights["Hunter's Mark"] = 1.0
	if fighting:
		if low and gap > 140.0 and wizard.fade_time <= 0.0:
			weights["Sneak"] = 2.5
		if sees and brain.pressure > 0.8 and gap > 110.0 and gap < 380.0:
			weights["Stone Wall"] = 1.4
		if brain.pressure > 1.0 and gap > 150.0:
			weights["Smoke Screen"] = 1.0
		if brain.pressure > 1.2:
			weights["Decoy"] = 1.0
		if brain.pressure > 0.8 and wizard.veil == 0:
			weights["Crimson Veil"] = 1.3
		if brain.pressure > 1.6 and wizard.obsidian_time <= 0.0:
			weights["Obsidian Armor"] = 0.8
		if sees and gap > 200.0:
			weights["Eclipse"] = 0.6 + 0.3 * brain.pressure
	for spell_name in weights.keys():
		if not brain.ready_to_cast(spell_name):
			weights[spell_name] = 0.0
	var choice := brain.pick(weights)
	if choice == "":
		return false
	if not brain.hand.begin_cast(choice, brain.hand.tend_stroke(choice, to_player), WizardBrain.QUICK_DRAW):
		return false
	brain.rest[choice] = WizardBrain.TEND_REST[choice]
	return true


## The nearest bonfire that burns, within reach of a point, or null.
func bonfire_near(point: Vector2, reach: float) -> Bonfire:
	var best: Bonfire = null
	var best_gap := reach
	for node in wizard.get_tree().get_nodes_in_group("fires"):
		if node is Bonfire and not node.is_queued_for_deletion():
			var gap: float = node.global_position.distance_to(point)
			if gap < best_gap:
				best = node
				best_gap = gap
	return best
