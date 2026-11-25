class_name BrainMend
extends RefCounted

## How an AI wizard looks after itself: resting to get its strength back, camping at its spring, and the small things it tends to (a light in the dark, its health, the scent of whoever it has lost).

var camped := false             # it rests by its spring to mend
var camped_for := 0.0
var mend_wait := 0.0
var resting := false            # it has stopped to get its breath back
const STAR_DRAW := 1.1  # seconds to draw a star: too quick a stroke is read as a flick
const SPRAYS := ["Barbs", "Insect Plague", "Hailstorm", "Spore Puff", "Fire Breath", "Firewall", "Bramble"]  # what lands as many small blows (each one takes a blow off a veil)
var sight_wait := 0.0              # seconds before it thinks again of saying the chant that sees in the dark
var brace_wait := 0.0              # seconds before it thinks again of saying the chant that fills its strength
var tend_cooldown := 3.0        # counting down to the next time it looks to its own needs

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Wounds: a wizard worn down to a small maximum, with no one at its heels, says a chant, or goes to its spring, and rests until it has
## mended, as a person does. Returns the speed to walk at, or NAN when it is not mending.
func mend(delta: float, fighting: bool) -> float:
	mend_wait -= delta
	brace_wait -= delta
	sight_wait -= delta
	if (brain.chant.is_typing() or camped or brain.settle > 0.0) and (brain.assailant() != null or brain.danger.scorched() or brain.danger.bitten()):  # it does not sit and chant with a blade or a flame on it
		brain.chant.typing = ""
		brain.settle = 0.0
		camped = false
		mend_wait = 3.0
		return NAN
	if (wizard.mending.is_on("rest") or wizard.mending.is_on("mud_mask") or wizard.mending.is_on("breathe")) and not fighting and wizard.max_stamina < Wizard.MAX_STAMINA * WizardBrain.MEND_UNTIL:
		return 0.0  # it sits still while a heal goes on (a Rest is ended by moving, and nothing else is worth walking off for)
	var fire := camp_near(wizard.global_position, 900.0)
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
	var chant := heal_chant()
	if chant != "":
		if not brain.quiet_here():  # not here: it goes on a while, and tries again
			mend_wait = 5.0
			return NAN
		brain.chant.open(chant)
		return 0.0
	mend_wait = 30.0
	return NAN


## Looks to what it needs, and casts for it: a way up to a rival over its head, a light in the dark, its strength, and something between it and a rival who
## is hurting it. True when it has begun a cast.
## Whether the Chant of Darkvision is on it already (its light is a flare nobody sees).
func _sees_in_the_dark() -> bool:
	for flare: Flare in wizard.get_tree().get_nodes_in_group("flares"):
		if flare.unseen and flare.caster == wizard:
			return true
	return false


## Whether there is something on it that water would wash off: a flame, a curse, a wound, a snail on its heels.
func _needs_washing() -> bool:
	if wizard.burning_time > 0.0 or Hex.on(wizard.get_tree(), wizard) != null or Hemorrhage.on(wizard.get_tree(), wizard) != null:
		return true
	for snail: InvincibleSnail in wizard.get_tree().get_nodes_in_group("snails"):
		if snail.target == wizard:
			return true
	return false


func tend(to_player: Vector2, sees: bool, fighting: bool) -> bool:
	if fighting and brain.combat.chase(to_player, sees):
		return true
	if not fighting and brace_wait <= 0.0 and brain.knows("chant:boundless") and wizard.infinite_time <= 0.0 and brain.quiet_here() and not BrainProfile.off("brace") and brain.pressure > 0.3:
		brace_wait = 50.0  # a rival it has seen shoot at it is somewhere near, and not yet on it: it says the words that fill the strength, as a person would before a fight
		brain.chant.open("boundless")
		return true
	if not fighting and sight_wait <= 0.0 and brain.in_dark() and brain.knows("chant:darkvision") and brain.quiet_here() and not _sees_in_the_dark():
		sight_wait = 60.0  # the dark has come down on it: it says the words that let it see, as a person would
		brain.chant.open("darkvision")
		return true
	if not fighting and brain.knows("chant:second_chance") and not wizard.mending.is_armed() and brain.quiet_here() and brace_wait <= 0.0:
		brace_wait = 50.0  # a second chance is said ahead of need, once, as a person would
		brain.chant.open("second_chance")
		return true
	var gap := absf(to_player.x)
	var low := wizard.max_stamina < Wizard.MAX_STAMINA * 0.45
	var ambush: bool = not fighting and gap > 360.0 and gap < 900.0 and brain.skill >= 0.4 and wizard.fade_time <= 0.0 and not BrainProfile.off("ambush")  # a rival it knows of, off a way: it goes unseen to close the gap and strikes first
	var tired := resting or wizard.stamina < 35.0
	var weights := {}
	if brain.in_dark():
		weights["Flare"] = 1.5
		weights["Dancing Lights"] = 1.3
		weights["Glowcap"] = 0.6 if tired or fighting else 0.0
		weights["Moonbeam"] = 0.8 if fighting else 0.0
	if brain.in_dark() and not brain.knows("Flare") and not brain.knows("Glowcap"):
		weights["Ignite"] = 0.8  # a fireball thrown ahead lights the way when nothing gentler is held
	if _needs_washing():
		weights["Bathe"] = 2.0  # a flame, a snail or a wound on it: water takes them all
	if wizard.max_stamina < Wizard.MAX_STAMINA * WizardBrain.MEND_BELOW and not wizard.shifted() and wizard.is_on_floor() and wizard.mending.kind == "":
		weights["Mud Mask"] = 1.0  # worn down, with no one at its heels: it mends the way it can
		weights["Breathe"] = 1.0 if not fighting or not sees or gap > 500.0 else 0.0  # (a blow ends a breath, so it is not drawn in a fight)
		if (not fighting or not sees or gap > 600.0) and HealingSpring.of(wizard.get_tree(), wizard) == null:
			weights["Healing Spring"] = 1.2
		if not wizard.is_wet() and wizard.oiled_time <= 0.0 and wizard.max_stamina < Wizard.MAX_STAMINA * 0.4:
			weights["Cauterize"] = 1.5  # the sear is quick, and what it burns is far less than it mends
	if sees and gap < 160.0 and wizard.max_stamina > 60.0:
		weights["Headwind"] = 0.35  # a rival closing on it: the wind slows them
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
		# The veil is paid in blood and negates a few blows, whatever their size: worth it against heavy single blows, wasted on a spray of thorns or a swarm, which
		# strips it in one go (owner's duel, 2026-11-21: three veils cost an AI more than half its strength, each torn away by one volley of Barbs). Never when wounded.
		if brain.pressure > 0.8 and wizard.veil == 0 and (BrainProfile.off("veil") or (brain.caution() <= 0.0 and not brain.profile.shown_any(brain.opponent, SPRAYS))):
			weights["Crimson Veil"] = 1.3
		if brain.pressure > 1.6 and wizard.obsidian_time <= 0.0:
			weights["Obsidian Armor"] = 0.8
		if sees and gap > 200.0:
			weights["Eclipse"] = 0.6 + 0.3 * brain.pressure
	if not BrainProfile.off("facts"):
		if not BrainProfile.off("nb_heal"):
			_heals_by_numbers(weights)
		if not BrainProfile.off("nb_defense"):
			_defenses_by_numbers(weights)
	for spell_name in weights.keys():
		if not brain.ready_to_cast(spell_name):
			weights[spell_name] = 0.0
		elif brain.recharging and fighting and spell_name != "Adrenaline":
			weights[spell_name] = 0.0  # nothing is cast while it gets its stamina back (each cast puts the return off), but the one spell for being worn out
	var choice := brain.combat.pick(weights)
	if choice == "":
		return false
	if not brain.hand.begin_cast(choice, brain.hand.tend_stroke(choice, to_player), STAR_DRAW if choice == "Dancing Lights" else WizardBrain.QUICK_DRAW):
		return false
	brain.rest[choice] = WizardBrain.TEND_REST[choice]
	return true


## The spells that mend are weighed by what they give for what they cost (`SpellFacts.heal_worth`) in place of the hand weights, scaled to weigh together what those did against the rest.
func _heals_by_numbers(weights: Dictionary) -> void:
	var fresh := {}
	var old_sum := 0.0
	var new_sum := 0.0
	var deficit := Wizard.MAX_STAMINA - wizard.max_stamina
	for spell_name in ["Mud Mask", "Breathe", "Healing Spring", "Cauterize"]:
		if weights.get(spell_name, 0.0) > 0.0:
			var worth := SpellFacts.heal_worth(spell_name, deficit, wizard.is_wet())
			if worth > 0.0:
				fresh[spell_name] = worth
				old_sum += float(weights[spell_name])
				new_sum += worth
	if new_sum <= 0.0:
		return
	for spell_name: String in fresh.keys():
		weights[spell_name] = fresh[spell_name] * old_sum / new_sum


## The spells that shield are weighed by the harm they take away for what they cost (`SpellFacts.defense_worth`), scaled to weigh together what the hand weights did. The harm
## coming at it is what it has been taking: the shots thrown at it lately (`pressure`) at a blow each, and what it has lost in the last seconds.
func _defenses_by_numbers(weights: Dictionary) -> void:
	var fresh := {}
	var old_sum := 0.0
	var new_sum := 0.0
	var blow := SpellFacts.TYPICAL_BLOW
	var incoming := maxf(brain.pressure, 0.3) * blow / SpellFacts.BLOW_GAP + wizard.mending.recent_loss() / 10.0
	var scarcity := 0.35 + 0.65 * clampf(1.0 - wizard.stamina / 120.0, 0.0, 1.0)
	for spell_name in weights.keys():
		if weights[spell_name] > 0.0 and SpellFacts.defends(spell_name):
			var worth := SpellFacts.defense_worth(spell_name, incoming, blow, scarcity, BrainProfile.knob("minding", 1.0))
			if worth > 0.0:
				fresh[spell_name] = worth
				old_sum += float(weights[spell_name])
				new_sum += worth
	if new_sum <= 0.0:
		return
	for spell_name: String in fresh.keys():
		weights[spell_name] = fresh[spell_name] * old_sum / new_sum


## The chant it says to mend, or "": the greatest it holds first. A Recovery is said only after a wound it could bring back, a Long Rest only where no one is about to
## find it asleep, and a Stitch or a Gamble never (a person does not stake the little strength they have left on a throw).
func heal_chant() -> String:
	for id: String in ["restoration", "mending", "recovery", "long_rest", "rest"]:
		if not brain.knows("chant:" + id):
			continue
		if id == "recovery" and wizard.mending.recent_loss() < 12.0:
			continue
		if id == "long_rest" and (brain.pressure > 0.0 or wizard.max_stamina > Wizard.MAX_STAMINA * 0.35 or brain.assailant() != null):
			continue
		return id
	return ""


## The place it can mend by, within reach of a point (a spring it raised), or null.
func camp_near(point: Vector2, reach: float) -> Node2D:
	var best: Node2D = null
	var best_gap := reach
	var spring := HealingSpring.of(wizard.get_tree(), wizard)
	if spring != null and spring.global_position.distance_to(point) < best_gap:
		best = spring
	return best
