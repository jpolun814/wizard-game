class_name WizardBrain
extends RefCounted

## A rival wizard's mind. It plays the way a player would: it walks the world looking for pages, and when it comes near another wizard (you,
## or another of its own kind: spells have no teams) it keeps its distance, reacts to what is thrown at it, and picks spells that suit the
## moment. It casts only the spells whose pages it has found. Every spell it casts is drawn in front of it as a real gesture and read by the
## same recognizer as yours, so you can watch it form, learn the shapes from it, and break the spell by hitting the wizard before it finishes.
##
## Four layers, checked in order each frame:
##   Travel: with no wizard in reach it walks to the nearest page it has not read, and when there are none, to the nearest wizard.
##   Reactions: a shot coming at it, standing in something dangerous, or you right on top of it. After a short
##     reaction time (shorter the more skilled it is) it jumps, reflects the shot with a Gust, raises a
##     Barrier, steps away, or pushes you off.
##   Footwork: it holds a dueling range, strafes, jumps to get a clear line at you, and won't walk into fire.
##   Attacks: each spell is scored for the situation (are you moving, behind cover, rooted, close, far?) and one is
##     picked by weight. Projectiles are aimed where you are going, not where you are.

const WALK_SPEED := 300.0
const ENGAGE := 620.0         # a wizard this close, and in sight, is a fight; farther off, it is a journey
const PAGE_REACH := 4          # tiles: a page further than this from any place to stand is not one it can get
const GOAL_EVERY := 4.0       # seconds between looking for a nearer page
const SWIM_ARRIVE := 48.0     # pixels from the place it swims to at which it has got there
const SWIM_HOLD := 260.0      # the distance it keeps from a rival it fights in the water
const SWIM_RISE := 150.0      # about how fast it rises, a stroke at a time, in pixels a second: for how long the way up to air takes
const AIR_SPARE := 1.5        # seconds of breath it keeps in hand on the way up
const AIR_SCAN := 640.0       # how far to either side it looks for open water to rise through, when something is over its head
const PAGE_TOUCH := 20.0         # pixels: a page this near is within reach
const PAGE_STEPS := 320.0        # pixels: a page this near, and level, is walked to when the way ends short of it
const PAGE_STEPS_TIME := 3.0     # seconds it tries
const PORTAL_LEFT := 3.0        # seconds: a portal with less than this left open is not worth the walk
const PORTAL_CHANCE := 0.75     # how often it takes a portal that is nearer than the page it was after
const PORTAL_JUMP_FOR := 5.0    # seconds it stands under a portal hung in the air, jumping for it, before it takes it for out of reach
const PUSH_THROUGH_FOR := 5.0   # seconds it goes on through danger after backing out of it over and over
const PAGE_GLOW := 120.0  # a page shines: its glow shows at the edge of the screen when it lies this far past it
const EXPLORE_FLOOR := 12     # tiles between one floor of a tall building and the next, when it looks for pages above or below
const EXPLORE_STEP := 20    # tiles between the places it picks to look at, going along
const READ_MIN := 0.87       # seconds a new page is looked at before its spell is drawn (the middle half of the recordings)
const READ_MAX := 1.55
const LONG_FALL := 300.0  # a drop this deep below its feet is a long fall, worth a Featherfall
const HASTE_FROM := 160      # moves left on a journey before it says the chant of swift feet (it takes 30 words a minute to say: shorter than this it saves no time)
const MEND_BELOW := 0.5    # a wizard worn down below this share of the greatest maximum lights a bonfire and rests by it
const MEND_UNTIL := 0.92
const MEND_MAX := 40.0     # seconds it rests at most
const STUCK_RADIUS := 260.0  # pixels it must get from where it was in STUCK_FOR seconds, or it has got nowhere
const STUCK_FOR := 20.0
const VOLCANO_KEEP_OFF := 520.0  # pixels: a page this near a volcano that is awake is left alone
const VOLCANO_FLEE := 440.0     # pixels: it goes away from a volcano that is awake when it is this near
const ASSAIL_REACH := 150.0   # how near a creature must come before it is dealt with
const STAIR_PATIENCE := 10.0  # seconds it waits for a stair when it is only looking round, before it looks the other way
const DASH_AFTER := 2.0        # seconds it waits at lava on its way before it runs across, if the lava is narrow
const DASH_MAX := 150.0        # pixels of lava that it will run across (a hit or two) rather than wait
const DASH_MIN_MAX := 70.0     # the least maximum stamina it will run lava with
const DANGER_WAIT_MAX := 7.0  # seconds it waits before lava on its way before it gives up that way
const GIVE_UP := 45.0         # seconds a page it could not reach stays off its list
const LOOK_AGAIN := 8.0       # seconds a page it knows of but cannot yet see the way to stays off its list, while it looks about
const NEAR := 190.0           # closer than this it backs away
const FAR := 330.0            # farther than this it closes in
const HUNT_PAGE_NEAR := 14    # (a page this many steps away or nearer is taken first, even by one that is hunting)
const BOLD_ABOVE := 0.62      # it thinks itself strong enough to go looking for rivals
const TIMID_BELOW := 0.3      # it thinks itself too weak to stand and fight, and keeps away while it can
const TIMID_HESITATE := 3.0   # seconds a timid wizard stands its ground before it turns away
const TIMID_STAND := 260.0    # (a timid wizard that is this close, or closer, fights, since it cannot get away)
const TOO_CLOSE := 95.0       # this close it acts to get you off it
const INTERRUPT_DAMAGE := 6   # a hit this big while it draws breaks the spell
const QUICK_DRAW := 0.35      # defensive signs are drawn quickly
const ATTACK_DRAW := 0.8      # attacks take longer, which is your chance to interrupt them
const ATTACK_RANGE := 460.0   # it only casts at you from about a screen away, never across the map
const CLEARS := {  # the gates a wizard clears, and the spells that do it, best first: any fire burns growth and gas and melts ice, wind thins gas, stone breaks ice and walls
	"brambles": ["Ignite", "Fire Breath", "Firewall"],
	"gas": ["Ignite", "Fire Breath", "Firewall", "Gust", "Tornado"],
	"ice": ["Fire Breath", "Firewall", "Ignite", "Stonefall", "Earthquake"],
	"wall": ["Stonefall", "Earthquake"],
	"piranhas": ["Spark"],
	"creature": ["Ignite", "Frostbolt", "Fire Breath", "Spark", "Stonefall"],  # anything that stands in the way and can be killed
	"giant": ["Faint"],  # what has too much strength to kill is put to sleep
}
const WAYS := {  # the spells (and chants) that get a wizard past each crossing that no one clears, the one it likes best first
	"chasm": ["Shadow Step", "chant:double_jump", "leap:air", "Obsidian Armor"],  # (a Gust shoves a wizard too little to carry it over; the glass wades through the lava, and needs a way up the far side)
	"flood": ["Frost Bridge", "Lily Pads", "Shadow Step"],
	"piranhas": ["Frost Bridge", "Lily Pads", "Shadow Step"],
	"sentinel": ["Smoke Screen", "Eclipse", "Barrier", "Decoy"],
	"wall": ["Geyser", "Rocket Jump", "Push", "Updraft", "Liana", "Great Oak", "Tornado"],
	"gas": ["chant:deep_breath"],  # walked through with the breath held (a chant, not a spell)  # thrown up over the top of it
}
const LASTS := {"Frost Bridge": 25.0, "Lily Pads": 6.0, "Smoke Screen": 11.0, "Eclipse": 5.0, "Barrier": 5.0, "Decoy": 3.0}  # seconds that the way a spell makes lasts
const COVER_ALL := ["Barrier", "Smoke Screen", "Eclipse", "Decoy"]  # when there are several shooters
const COVERS := ["Smoke Screen", "Eclipse", "Barrier", "Decoy"]  # the spells that keep a sentinel from hitting it, best first
const REST_BELOW := 20.0      # stamina: below this a wizard that is only travelling stops to get its breath back,
const REST_UNTIL := 90.0      # and walks on again when it has this much (a jump and a spell both cost stamina, and it comes back only while standing)
const SETTLE := 1.0           # seconds from drawing a way over water to its being there to walk on
const PADS_REACH := 480.0     # pixels of pit that one row of Lily Pads covers, no further apart than a wizard can step
const DOUBLE_JUMP_REACH := 460.0  # pixels of pit that two jumps carry it over
const LEAP_STEPS := 2         # Shadow Steps at least that it makes in the air to get over a pit: a jump and two of them carry it 900 px
const SENTINEL_LOOKOUT := 40  # tiles of the way it looks ahead along for a sentinel
const COVER_RANGE := 780.0    # it draws its cover when it is this close to a sentinel, a little before the sentinel sees it (700)
const CLEAR_TRIES := 14       # casts at one gate before it gives up on it for a while
const STRIKE_REACH := {"Fire Breath": 5, "Ignite": 12, "Stonefall": 10, "Earthquake": 10, "Firewall": 8, "Gust": 7, "Tornado": 6, "Spark": 40, "Frostbolt": 12, "Faint": 8}  # tiles: how far off a spell strikes a gate
const BREATH_AHEAD := 60.0        # pixels short of a bank of gas that it stops to hold its breath
const EYE_SECONDS := 20.0         # how long what a brain sees through its Scrying Eye lasts
const GAS_WALK := 20.0            # seconds the way through gas is taken to be open after the chant (the breath is held for longer)
const STRIKE_STAND := 4       # tiles: and it steps up to this far from it
const JUMP_REACH := 130.0       # pixels a jump carries it up: the highest ledge it will jump for
const CHASE_ABOVE := 90.0       # pixels a rival's feet must be over its own before it looks for a way up to them
const LIFT_CLOSE := {"Liana": 40.0, "Great Oak": 40.0, "Updraft": 0.0}  # the lifts that are climbed, and so are cast from near the foot of the ledge, walking up to it
const LIFT_STAND := {"Updraft": 0.0}  # how close to a rival on a ledge it stands to raise itself to them, for the lifts that differ from the usual
const CHASE_REST := 10.0        # seconds between two tries at a way up to a rival
const OAK_CHASE_MAX := 190.0    # pixels up to a rival that an oak can still be climbed for (its low ledge, and a jump from it)
const LIFTS := ["Geyser", "Updraft", "Rocket Jump", "Push", "Liana", "Great Oak", "Tornado"]  # what raises it up a wall or to a rival, the one it likes best first
const TEND_REST := {"Flare": 40.0, "Glowcap": 60.0, "Moonbeam": 30.0, "Adrenaline": 25.0, "Wild Shape": 30.0, "Sneak": 25.0, "Crimson Veil": 8.0, "Obsidian Armor": 25.0,
		"Decoy": 8.0, "Stone Wall": 6.0, "Smoke Screen": 10.0, "Eclipse": 14.0, "Hunter's Mark": 25.0}  # seconds before it looks to the same need with the same spell again
## What the brain does with every spell there is (a test holds it to this: a spell with no line here is one it would never cast, and each line is met by a check).
const USES := {
	"Ignite": "attack", "Frostbolt": "attack", "Spark": "attack", "Stonefall": "attack", "Fire Breath": "attack", "Firewall": "attack", "Spore Puff": "attack",
	"Stalagmite": "attack", "Bramble": "attack", "Flytrap": "attack", "Icicles": "attack under a ceiling", "Sinkhole": "attack", "Tornado": "attack, and a way up",
	"Ice Prison": "attack", "Blizzard": "attack", "Mudslide": "attack", "Black Hole": "attack", "Earthquake": "attack", "Hex": "attack", "Vacuum": "attack",
	"Faint": "attack", "Fight or Flight": "attack", "Silence": "attack", "Tide Surf": "attack", "Thunderclap": "attack",
	"Barbs": "attack", "Pebble": "attack", "Hailstorm": "attack", "Thorn Whip": "attack", "Insect Plague": "attack", "Leech": "attack", "Raise Dead": "attack", "Flaming Sphere": "attack", "Eldritch Blast": "attack", "Hemorrhage": "attack", "Supernova": "attack", "Scythe": "attack", "Mirage": "attack",
	"Barrier": "defence", "Gust": "defence", "Shadow Step": "defence, and a way over a chasm", "Push": "repel, and a way up", "Rocket Jump": "a way up", "Geyser": "repel, and a way up",
	"Stone Wall": "tend", "Smoke Screen": "tend", "Decoy": "tend", "Eclipse": "tend", "Crimson Veil": "tend", "Obsidian Armor": "tend, and a way through lava",
	"Adrenaline": "tend", "Wild Shape": "tend, and fights as a werewolf", "Sneak": "tend", "Hunter's Mark": "tend", "Flare": "tend", "Glowcap": "tend", "Moonbeam": "tend",
	"Featherfall": "tend, in a long fall", "Updraft": "a way up", "Great Oak": "a way up", "Liana": "a way up", "Frost Bridge": "a way over water", "Lily Pads": "a way over water",
}

var wizard: Wizard            # the body it plays
var skill := 0.6              # 0 to 1: how quick its reactions are and how true its aim is
var strength := 0.5          # 0 to 1: how strong it thinks it is (see _feel_strength); a strong wizard hunts, a weak one looks for pages and keeps away
var _strength_in := 0.0
var _daunted := 0.0           # seconds it has faced a rival it feels too weak for, at a distance: it hesitates (and may cast to hide or mend) before it turns away
var cast_cooldown := 1.8
var react := 0.0             # counting down to a planned reaction
var _reaction := ""
var jump_cooldown := 0.0
var _push_through := 0.0     # seconds left that it walks on through what it would back out of
var _escapes := 0.0           # how often it has backed out of danger lately
var clock := 0.0                 # seconds this brain has been thinking
var _read_until := {}             # page -> the time on clock until which it is still reading it (see _note_new_pages)
var _pages_noted := -1
var _ledger_noted: Ledger
var seen_pages := {}            # the pages it has set eyes on, and not read (id -> true): in a match it goes only for those
var pressure := 0.0          # how many shots you have thrown at it lately
var rng := RandomNumberGenerator.new()
var hand: BrainHand
var travel: BrainTravel
var combat: BrainCombat
var mend: BrainMend
var explore: BrainExplore
var gates: BrainGates  # the ways over crossings and the clearing of gates
var moves: BrainMoves  # the leap, the wade and the lift it may have in hand
var chant: BrainChant
var danger: BrainDanger
var sight: BrainSight
var opponent: Wizard                 # the wizard it is dealing with: the nearest of the others it knows of
var route := WizardRoute.new()
var goal := ""                  # what it is travelling to: "page", "foe", or "" for nothing
var goal_timer := 0.0
var skip := {}                  # a page (its instance id) or a gate (its name) -> seconds it stays off the list, for one that could not be had
var wise_to_mirages := false      # it has watched a mirage fade, and now sees the waver of the rest
var stuck_at: Array[String] = []  # where it has been held up, for a report
var _nav_version := -1           # which build of the ways its list of pages it cannot reach belongs to
var _hurt_age := 99.0            # seconds since it was last hurt
var settle := 0.0               # seconds it stands still while a way over water grows
var _eye_time := 0.0              # seconds since it sent out a Scrying Eye, counting down (its window shows someone, not where they are)
var scent := 0.0                # seconds that a Hunter's Mark lasts for it: a wizard faded from sight can be found
var rest := {}                  # a spell (or "chase") -> seconds before it uses it for itself again


func _init(body: Wizard) -> void:
	wizard = body
	hand = BrainHand.new(self, body)
	moves = BrainMoves.new(self, body)
	gates = BrainGates.new(self, body)
	travel = BrainTravel.new(self, body)
	combat = BrainCombat.new(self, body)
	mend = BrainMend.new(self, body)
	explore = BrainExplore.new(self, body)
	chant = BrainChant.new(self, body)
	danger = BrainDanger.new(self, body)
	sight = BrainSight.new(self, body)
	rng.randomize()
	skill = GameSettings.rival_skill()


## A Hunter's Mark was cast: for a while it can find a wizard who has faded from sight.
func catch_scent(seconds: float) -> void:
	scent = maxf(scent, seconds)


## Called when the wizard takes damage. A real hit while it draws breaks its spell, and being badly hurt makes it
## want to get away.
func on_hurt(amount: int) -> void:
	_hurt_age = 0.0
	if wizard.is_drawing() and amount >= INTERRUPT_DAMAGE:
		wizard.interrupt_cast()
		cast_cooldown = maxf(cast_cooldown, 0.9)
	if knows("Shadow Step") and wizard.max_stamina < Wizard.MAX_STAMINA * 0.4 and combat.defend_cooldown <= 0.0 and react <= 0.0 and rng.randf() < 0.5:
		_plan("blink_away", 0.25)


## A Flaming Sphere rolling at it along the ground: a person jumps over it, as over a rolling log, instead of standing in its way or running from it.
func _hurdle() -> void:
	if not wizard.is_on_floor() or jump_cooldown > 0.0 or wizard.wild:
		return
	for node in wizard.get_tree().get_nodes_in_group("fires"):
		if node is FlamingSphere:
			var gap: Vector2 = node.global_position - wizard.global_position
			if absf(gap.y) < 50.0 and absf(gap.x) < 120.0 and signf(-gap.x) == signf(node.direction):
				wizard.request_jump()
				jump_cooldown = 0.8
				return


## A person cannot type a chant on the move, in the air or under blows, and stops when any of them happens. True while the way it stands lets it type.
## (A wizard that has just opened the box is still coming to a stop: its steps do not break the words for the first moment.)
func _typing_disturbed() -> bool:
	return not wizard.is_on_floor() or _hurt_age < 0.5 or (absf(wizard.velocity.x) > 40.0 and chant.age > BrainChant.STOPPING) or wizard.is_drawing() or wizard.is_frozen() or danger.in_danger(wizard.center())


## Whether this is a place to stand and type: it stands on the ground and is not being hurt, no creature or rival is near enough to come at it, and
## nothing that burns, shoves or bites lies within a few paces. It looks at what is there, not at a clock.
func quiet_here() -> bool:
	if not wizard.is_on_floor() or absf(wizard.velocity.x) > 30.0 or _hurt_age < 1.5 or wizard.underwater():  # (no one chants under water: the sea is no place to stand and type)
		return false
	if assailant() != null:
		return false
	if is_instance_valid(opponent) and not opponent.dead and sight.foe_feet().distance_to(wizard.global_position) < 450.0:
		return false
	for dx in [-200.0, -120.0, -60.0, 0.0, 60.0, 120.0, 200.0]:
		if danger.in_danger(wizard.center() + Vector2(dx, 0.0)) or danger.in_danger(wizard.global_position + Vector2(dx, -6.0)):
			return false
	return true


func think(delta: float) -> void:
	_run_clocks(delta)
	_sense(delta)
	if chant.is_typing():  # the chant box is open: it can only type, or close the box to do something else (see BrainChant.while_typing)
		_chant_said(chant.while_typing())
		return
	if opponent == null and _eye_time <= 0.0 and not wizard.ledger.is_settled("scrying_eye") and SpellTargets.wizards(wizard.get_tree()).size() > 1 and wizard.ledger.knows_chant("scrying_eye"):
		chant.type_then_say("scrying_eye")  # it has lost track of everyone: it sends out an eye once, as a person would (see BrainChant.while_typing); the window stays
	if opponent == null:
		_alone(delta)
		return
	_with_a_rival(delta)


## What runs out as time goes: the cooldowns, the rests, the things it has set aside (pages it gave up, ways it cannot make, bridges laid), and the chant
## it has to break off when it is jostled.
func _run_clocks(delta: float) -> void:
	_hurt_age += delta
	_note_new_pages(delta)
	travel.dash -= delta
	hand.tick(delta)
	combat.catch_fall()
	if chant.is_typing() and _typing_disturbed():  # it breaks off the chant, and will not try it here again for a while
		chant.typing = ""
		settle = 0.0
		chant.breaks = mini(chant.breaks + 1, 4)
		mend.mend_wait = maxf(mend.mend_wait, 10.0 * chant.breaks)
		travel.haste_wait = maxf(travel.haste_wait, 10.0 * chant.breaks)
	cast_cooldown -= delta
	combat.defend_cooldown -= delta
	jump_cooldown -= delta
	combat.escape_time -= delta
	goal_timer -= delta
	settle -= delta
	mend.tend_cooldown -= delta
	scent -= delta
	_eye_time -= delta
	chant.tick(delta)
	explore.note_sights(delta)
	_hurdle()
	wizard.shown_words = chant.words_shown()
	pressure *= exp(-delta / 3.0)
	for spell_name in rest.keys():
		rest[spell_name] -= delta
		if rest[spell_name] <= 0.0:
			rest.erase(spell_name)
	for id in skip.keys():
		skip[id] -= delta
		if skip[id] <= 0.0:
			skip.erase(id)
	for key in gates.cannot.keys():
		gates.cannot[key] -= delta
		if gates.cannot[key] <= 0.0:
			gates.cannot.erase(key)
	for key in gates.bridged.keys():
		gates.bridged[key] -= delta
		if gates.bridged[key] <= 0.0:
			gates.bridged.erase(key)
			gates.pad_walk.erase(key)
	if wizard.nav != null and wizard.nav.version != _nav_version:
		_nav_version = wizard.nav.version
		skip.clear()  # a gate has been cleared: pages that could not be reached may be reachable now


## Looking about: the shots, the others it knows of, the shadows, the rival it deals with now, and how strong it feels against them.
func _sense(delta: float) -> void:
	sight.track_shots()
	sight.look_about(delta)
	sight.notice_decoys()
	opponent = sight.lure.caster if sight.lure != null else sight.nearest_foe()
	_strength_in -= delta
	if _strength_in <= 0.0:
		_strength_in = 1.0
		strength = _feel_strength(opponent)


## No rival in mind (the last wizard standing, or it knows of no one else): it looks after itself and goes about its journey.
func _alone(delta: float) -> void:
	if react > 0.0:  # (a reaction it has planned still comes: nothing else counts it down here)
		react -= delta
		if react <= 0.0:
			combat.act(_reaction)
	# It still looks after itself: a light in the dark, its strength, the scent of whoever it has lost.
	if react <= 0.0 and mend.tend_cooldown <= 0.0 and not wizard.is_drawing() and not moves.busy() and not smothering():
		mend.tend_cooldown = 0.6 + rng.randf() * 0.6
		if mend.tend(Vector2.ZERO, false, false):
			mend.tend_cooldown = 1.4 + rng.randf() * 0.8
	var mending := mend.mend(delta, false) if not moves.busy() else NAN
	if not is_nan(mending):
		wizard.walk(mending)
		return
	wizard.walk(travel.travel(delta) if SpellTargets.wizards(wizard.get_tree()).size() > 1 or wizard.get_tree().get_first_node_in_group(&"gate_source") != null else 0.0)  # (alone in a match it has won; alone in a room it goes on)


## A rival in mind: it reacts to what comes at it, looks after itself, and keeps its footing, its journey or its fight.
func _with_a_rival(delta: float) -> void:
	var foe: Wizard = opponent
	var in_view := wizard.eyes.sees_point(sight.lure.center()) if sight.lure != null else eyes_see(foe)
	var to_player: Vector2 = sight.seen_center(foe) - wizard.center()
	var sees := in_view and danger.clear_line(wizard.center(), sight.seen_center(foe))
	var fighting := sees and to_player.length() < ENGAGE

	_push_through -= delta
	combat.escape_commit -= delta
	_escapes = maxf(_escapes - delta * 0.5, 0.0)
	# Reactions.
	if react > 0.0:
		react -= delta
		if react <= 0.0:
			combat.act(_reaction)
	elif not wizard.is_drawing():
		var shot := sight.incoming_shot()
		if not shot.is_empty() and combat.defend_cooldown <= 0.0:
			combat.threat_dir = shot["dir"]
			_plan(combat.choose_defence(shot["eta"]), _reaction_time())
		elif (travel.dash <= 0.0 and danger.scorched()) or danger.bitten() or (_push_through <= 0.0 and (danger.in_danger(wizard.global_position + Vector2(0, -6)) or danger.in_danger(wizard.center()))):
			_plan("escape", _reaction_time() * 0.6)
			settle = 0.0  # nobody stands in the fire to finish a chant
			chant.typing = ""
			mend.camped = false
			_escapes += 1.0
			if _escapes > 3.0 and not danger.scorched() and not danger.bitten():  # it keeps backing out of the same thing that lies on its way: it goes through it this once
				_push_through = PUSH_THROUGH_FOR
				_escapes = 0.0
		elif combat.defend_cooldown <= 0.0 and not watchers().is_empty():
			_plan("cover", _reaction_time())
		elif fighting and to_player.length() < TOO_CLOSE and combat.defend_cooldown <= 0.0:
			_plan(combat.choose_repel(), _reaction_time())

	# Looking after itself: its lights, its strength, a wall between it and you, a way up to you.
	if react <= 0.0 and mend.tend_cooldown <= 0.0 and not wizard.is_drawing() and not moves.busy() and not smothering():
		mend.tend_cooldown = 0.6 + rng.randf() * 0.6
		if mend.tend(to_player, sees, fighting):
			mend.tend_cooldown = 1.4 + rng.randf() * 0.8

	if wizard.wild and fighting:
		combat.wolf(to_player, sees)  # a werewolf has no spells: it runs at the rival and claws
		return

	# Footwork, or the journey.
	var run: float
	var mend := mend.mend(delta, fighting) if not moves.busy() and react <= 0.0 and wizard.swim_time <= 0.0 else NAN  # (no one rests in deep water)
	if not is_nan(mend):
		wizard.walk(mend)
		return
	if not moves.lift.is_empty():
		run = moves.lifting(delta)  # a throw, a climb or a lift up to you goes on, fight or no
	else:
		var daunted := fighting and strength < TIMID_BELOW and to_player.length() > TIMID_STAND
		_daunted = _daunted + delta if daunted else 0.0
		var standing_to_fight := fighting and (not daunted or _daunted < TIMID_HESITATE)  # (one that feels weak, after a moment, goes on with its journey and keeps away)
		if standing_to_fight and wizard.swim_time > 0.0:
			run = travel.swim(delta, true, to_player)  # (out of its depth, it fights as it swims)
		else:
			run = combat.footwork(delta, to_player, sees) if standing_to_fight else travel.travel(delta)  # (both may jump: the speed is written after they have)
	wizard.walk(run)
	# A wizard faces the way it runs; it turns to its rival only while standing still or drawing a spell, so it never backpedals.
	var running := run != 0.0 and not wizard.is_drawing()
	wizard.facing = signf(run) if running else (signf(to_player.x) if fighting or wizard.is_drawing() else wizard.facing)
	if not fighting or (strength < TIMID_BELOW and to_player.length() > TIMID_STAND and _daunted >= TIMID_HESITATE):
		return

	# Attacks.
	if cast_cooldown <= 0.0 and not wizard.is_drawing() and react <= 0.0:
		if smothering() or hiding():
			cast_cooldown = 0.3  # another spell would let the breath go; and a wizard out of sight is shown by casting
		elif foe.has_shield():
			cast_cooldown = 0.3  # nothing gets through a Barrier; wait it out
		elif combat.attack(to_player, sees):
			cast_cooldown = lerpf(2.8, 1.5, skill) + rng.randf() * 0.8
		else:
			cast_cooldown = 0.4


## How long it takes to answer something it has seen: the middle half of the reactions recorded from people runs from a quarter of a second to
## over three quarters (tools/measure_human.py); a skilled wizard is at the quick end of that, never quicker than the quickest people.
func _reaction_time() -> float:
	return lerpf(0.45, 0.25, skill) + rng.randf() * 0.2


func _plan(reaction: String, delay: float) -> void:
	_reaction = reaction
	react = delay


# --- Travel -----------------------------------------------------------------------------------------------------


## Whether it holds the page of a spell.
func knows(spell_name: String) -> bool:
	if spell_name.begins_with("chant:"):
		return wizard.ledger.knows_chant(spell_name.substr(6))
	return wizard.ledger.knows_spell(spell_name)


## How strong it thinks it is, 0 to 1, as a person feels it: from the attacking pages in its book and how much strength it has left. Good attack spells and plenty of strength make a wizard bold; a bare book makes it timid.
func _feel_strength(_rival: Wizard) -> float:
	var arms := 0.0
	for page: String in wizard.ledger.pages:
		var spell: Spell = SpellData.SPELLS.get(page)
		if spell == null or spell.damage.is_empty():
			continue
		var figure := spell.damage.get_slice(" ", 0).to_float()
		arms += clampf(figure, 4.0, 40.0) / 40.0  # a weak spell counts for little, a strong one for a good deal
	var armed := 1.0 if wizard.ledger.everything else clampf(arms / 2.5, 0.0, 1.0)  # (in the waiting room every page is held)
	var health := clampf(wizard.max_stamina / Wizard.MAX_STAMINA, 0.0, 1.0) * 0.7 + clampf(wizard.stamina / maxf(wizard.max_stamina, 1.0), 0.0, 1.0) * 0.3
	# A rival's strength and book are not seen (no bar hangs over them): it judges itself against what a rival is like, not against this one.
	var edge := clampf(0.5 + (wizard.max_stamina - Wizard.MAX_STAMINA * 0.75) / 200.0, 0.0, 1.0)
	return armed * 0.5 + health * 0.3 + edge * 0.2


## Whether a wizard cannot move freely: rooted, or slowed.
func held(foe: Wizard) -> bool:
	return foe.is_rooted() or foe.is_slowed()


## What tells it of the gates about it: a match's world, or a room that has read itself (see RoomScan).
func the_world() -> Node:
	var tree := wizard.get_tree()
	var found := tree.get_first_node_in_group(&"world")
	return found if found != null else tree.get_first_node_in_group(&"gate_source")


## The tile a body stands in, from its feet.
func tile_of(feet: Vector2) -> Vector2i:
	return Vector2i(floori(feet.x / WizardRoute.TILE), floori((feet.y - 1.0) / WizardRoute.TILE))


## What a chant just said sets going: a bonfire it camps by, an eye it looks through.
func _chant_said(id: String) -> void:
	if id == "" or not chant.said[id]:
		return
	if id == "bonfire":
		mend.camped = true
		mend.camped_for = 0.0
	if id == "scrying_eye":
		_eye_time = EYE_SECONDS
		chant.said.erase(id)


## True when it can make out another wizard: on its screen, in plain sight, not faded from sight.
func eyes_see(other: Wizard) -> bool:
	return wizard.eyes.sees_wizard(other)


## A creature close by that would strike it: the nearest one that is awake and not its own, or null.
func assailant() -> Mob:
	var best: Mob = null
	var gap := ASSAIL_REACH
	for mob: Mob in wizard.get_tree().get_nodes_in_group("mobs"):
		if mob.is_dead() or mob.is_fainted() or mob.master == wizard or mob.kind == "turret" or not (Mob.KINDS[mob.kind].role in ["melee", "ranged"]):
			continue
		var apart := absf(mob.global_position.x - wizard.global_position.x)
		if apart < gap and absf(mob.global_position.y - wizard.global_position.y) < 100.0:
			best = mob
			gap = apart
	return best


## What it does to forget a page or place it was bound for, to choose again.
func forget_goal() -> void:
	goal = ""
	goal_timer = 0.0


## The height of the ground under a point (a little above it, looking down).
func ground_under(point: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(point + Vector2(0, -40), point + Vector2(0, 400))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else point.y


## What it is doing, for a report.
func status() -> String:
	return "%s (%s)" % [goal if goal != "" else "nothing", route.status()]


# --- Reactions --------------------------------------------------------------------------------------------------


## The sentinels that have it in sight, when it holds a spell to meet them with.
func watchers() -> Array:
	var out := []
	if not COVERS.any(knows):
		return out
	for post: Sentinel in wizard.get_tree().get_nodes_in_group("sentinels"):
		if post.sees(wizard.center()):
			out.append(post)
	return out


# --- Footwork ---------------------------------------------------------------------------------------------------


# --- Attacks ----------------------------------------------------------------------------------------------------


## The wizard it is dealing with: the nearest of the others it knows of.
func foe() -> Wizard:
	return opponent


## The pull of gravity on a stroke it draws now: the screen follows a wizard that falls, and drags the stroke with it.
func drag_gravity() -> float:
	return 0.0 if wizard.is_on_floor() else wizard.gravity


## Where you will be by the time a spell lands, judged with the wizard's skill: a skilled wizard leads you well.
func predict(seconds: float) -> Vector2:
	var foe: Wizard = opponent
	var lead: Vector2 = foe.velocity * seconds * skill
	lead.y = 0.0 if foe.stands() else lead.y * 0.5
	return sight.seen_center(foe) + lead


## A brain that has watched a mirage fade learns to see the waver of the next, and does not go for it.
func saw_a_mirage_fade() -> void:
	wise_to_mirages = true


## True when a real page, one a wizard could take, lies within this distance of the wizard: the thing a mirage would pass for.
func real_page_near(distance: float) -> bool:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not pickup.is_queued_for_deletion() and pickup.global_position.distance_to(wizard.global_position) < distance 				and (not explore.sight_is_limited() or seen_pages.has(pickup.get_instance_id())):
			return true
	return false


## How many mirages are out there at the moment (a brain does not scatter them all over the world).
func mirages_set() -> int:
	var count := 0
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if pickup is Mirage:
			count += 1
	return count


## How many skeletons this wizard has raised that are still standing.
func own_raised() -> int:
	var count := 0
	for mob: Mob in wizard.get_tree().get_nodes_in_group("mobs"):
		if mob.master == wizard and not mob.is_dead():
			count += 1
	return count


## A page newly in its book is looked at before its spell can be drawn: a person reads the picture first, about a second (the book stays open
## at a new page for 0.87 to 1.55 s in the middle half of the recordings). The pages it starts with are known already.
func _note_new_pages(delta: float) -> void:
	clock += delta
	if wizard.ledger == null:
		return
	var pages: Dictionary = wizard.ledger.pages
	var fresh := wizard.ledger != _ledger_noted  # a book handed over whole (a new match, the waiting room's): its pages are known already
	if pages.size() == _pages_noted and not fresh:
		return
	_ledger_noted = wizard.ledger
	_pages_noted = pages.size()
	for page in pages:
		if not _read_until.has(page):
			_read_until[page] = 0.0 if fresh else clock + rng.randf_range(READ_MIN, READ_MAX)


## True while it stands still to draw.
func holds_still() -> bool:
	return hand.hold_still > 0.0


# --- Looking after itself ---------------------------------------------------------------------------------------


## Whether it is hiding: faded from sight, and too hurt to fight.
func hiding() -> bool:
	return wizard.fade_time > 0.0 and wizard.max_stamina < Wizard.MAX_STAMINA * 0.45


## Whether a Vacuum of its own still holds someone: any other spell it cast would let them go.
func smothering() -> bool:
	for vacuum: Vacuum in wizard.get_tree().get_nodes_in_group("vacuums"):
		if vacuum.caster == wizard:
			return true
	return false


## Whether the world is dark: a flare, a glowcap or a moonbeam would show it the way.
func in_dark() -> bool:
	for node in wizard.get_tree().get_nodes_in_group("darkness"):
		if node is CanvasModulate and node.visible and node.color.get_luminance() < 0.5:
			return true
	return false


## Whether it may cast a spell now: it holds the page, is not silenced, has not just cast it for itself, and has the strength (blood is paid
## in maximum stamina, and never to the last drop).
func ready_to_cast(spell_name: String) -> bool:
	if not knows(spell_name) or rest.has(spell_name) or wizard.silenced() or wizard.rage_time > 0.0 or SpellLimits.refusal(wizard, spell_name) != "":
		return false
	if _read_until.get(spell_name, 0.0) > clock:
		return false  # a page just read: it is still looking at the picture
	var spell: Spell = SpellData.SPELLS[spell_name]
	if spell.pays_max():
		return wizard.max_stamina > spell.cost + 40.0
	return wizard.stamina >= spell.cost


