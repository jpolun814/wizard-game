class_name BrainMend
extends RefCounted

## How an AI wizard looks after itself: resting to get its strength back, camping at a bonfire, and the small things it tends to (a light in the dark, its health, the scent of whoever it has lost).

var camped := false             # it rests by a bonfire to mend
var camped_for := 0.0
var mend_wait := 0.0
var resting := false            # it has stopped to get its breath back
var brace_wait := 0.0              # seconds before it thinks again of saying the chant that fills its strength
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
	brace_wait -= delta
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
		if fighting or healed or camped_for > WizardBrain.MEND_MAX or fire == null or wizard.shifted():
			camped = false
			mend_wait = 12.0
			return NAN
		var off := fire.global_position.x - wizard.global_position.x
		if absf(off) > 50.0:
			return signf(off) * WizardBrain.WALK_SPEED * 0.8
		return 0.0
	if fighting or mend_wait > 0.0 or wizard.max_stamina >= Wizard.MAX_STAMINA * WizardBrain.MEND_BELOW or not wizard.is_on_floor() or wizard.pen.active() or wizard.shifted():
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
	if fighting and brain.combat.chase(to_player, sees):
		return true
	if not fighting and brace_wait <= 0.0 and brain.knows("chant:boundless") and wizard.infinite_time <= 0.0 and brain.quiet_here() and not BrainProfile.off("brace") and brain.pressure > 0.3:
		brace_wait = 50.0  # a rival it has seen shoot at it is somewhere near, and not yet on it: it says the words that fill the strength, as a person would before a fight
		brain.chant.open("boundless")
		return true
	var gap := absf(to_player.x)
	var low := wizard.max_stamina < Wizard.MAX_STAMINA * 0.45
	var ambush: bool = not fighting and gap > 360.0 and gap < 900.0 and brain.skill >= 0.4 and wizard.fade_time <= 0.0 and not BrainProfile.off("ambush")  # a rival it knows of, off a way: it goes unseen to close the gap and strikes first
	var tired := resting or wizard.stamina < 35.0
	var weights := {}
	if brain.in_dark():
		weights["Flare"] = 1.5
		weights["Glowcap"] = 0.6 if tired or fighting else 0.0
		weights["Moonbeam"] = 0.8 if fighting else 0.0
	if brain.in_dark() and not brain.knows("Flare") and not brain.knows("Glowcap"):
		weights["Ignite"] = 0.8  # a fireball thrown ahead lights the way when nothing gentler is held
	if ambush:
		weights["Sneak"] = 1.4
	if fighting and not BrainProfile.off("decoy") and brain.pressure > 0.3 and brain.profile.shown_any(brain.opponent, ["Stonefall", "Spark", "Supernova", "Scythe", "Eldritch Blast"]):
		weights["Decoy"] = 1.0  # a rival with heavy blows to throw is given something to throw them at
	if (tired or (fighting and gap > WizardBrain.FAR)) and wizard.adrenaline_time <= 0.0:
		weights["Adrenaline"] = 1.2
	if fighting and sees and gap < 260.0 and wizard.max_stamina > 90.0 and not wizard.shifted():
		weights["Wild Shape"] = 1.1  # a rival close at hand: it comes at them with claws
	if brain.goal != "page" and brain.scent <= 0.0 and brain.opponent == null:  # (it has lost track of everyone, so it marks one; it cannot know whether anyone is left)
		weights["Hunter's Mark"] = 1.0
	if fighting:
		if low and gap > 140.0 and wizard.fade_time <= 0.0:
			weights["Sneak"] = 2.5
		if sees and brain.pressure > 0.8 and gap > 110.0 and gap < 380.0:
			weights["Stone Wall"] = 1.4
		if brain.pressure > 1.0 and gap > 150.0:
			weights["Smoke Screen"] = 1.0
		if not BrainProfile.off("wall") and sees and gap > 110.0 and gap < 380.0 and brain.profile.after_me(brain.opponent) and brain.profile.shown_any(brain.opponent, BrainProfile.SHOOTERS):
			weights["Stone Wall"] = maxf(weights.get("Stone Wall", 0.0), 1.8)  # a rival who keeps shooting at it along the ground: it puts a wall up
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
	var choice := brain.combat.pick(weights)
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
