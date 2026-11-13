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
var _strength := 0.5          # 0 to 1: how strong it thinks it is (see _feel_strength); a strong wizard hunts, a weak one looks for pages and keeps away
var _strength_in := 0.0
var _daunted := 0.0           # seconds it has faced a rival it feels too weak for, at a distance: it hesitates (and may cast to hide or mend) before it turns away
var cast_cooldown := 1.8
var react := 0.0             # counting down to a planned reaction
var _reaction := ""
var _threat_dir := Vector2.ZERO
var _defend_cooldown := 0.0
var _strafe := 0.0
var _strafe_timer := 0.0
var _escape_time := 0.0
var _escape_dir := 0.0
var _jump_cooldown := 0.0
var _escape_commit := 0.0     # seconds it keeps the way it chose out of danger
var _push_through := 0.0     # seconds left that it walks on through what it would back out of
var _escapes := 0.0           # how often it has backed out of danger lately
var _anchor := Vector2.INF       # where it was when it last moved any distance
var _anchored_for := 0.0         # seconds it has stayed within STUCK_RADIUS of it
var _unsticks := 0               # times in a row it has had to drop what it was after
var _wander_dir := 1.0
var _wander_time := 0.0
var _off_map := false           # it stands on something the map does not hold, over ground that it does
var _off_map_check := 0.0
var _camped := false             # it rests by a bonfire to mend
var _camped_for := 0.0
var _mend_wait := 0.0
var _stroke_in := 0.0         # seconds to its next stroke in the water
var _for_air := false         # it is on its way up for air
var clock := 0.0                 # seconds this brain has been thinking
var _read_until := {}             # page -> the time on clock until which it is still reading it (see _note_new_pages)
var _pages_noted := -1
var _ledger_noted: Ledger
var _haste_wait := 0.0
var _seen_pages := {}            # the pages it has set eyes on, and not read (id -> true): in a match it goes only for those
var _explored := {}              # the squares of the world it has been to ((x / 16, y / 12) -> true)
var _explore_dir := 0.0
var _sight_timer := 0.0
var _assail_commit := 0.0       # seconds it keeps running from a creature after it is out of reach
var _assail_dir := 0.0
var _stair_wait := 0.0          # seconds it has stood at a swinging stair on its way to look at somewhere new
var _dash := 0.0               # seconds it runs on across lava, whatever it does to it
var _danger_wait := 0.0       # seconds it has stood waiting for danger on its way to pass
var _hop_timer := 1.5  # counting down to its next hop while it walks
var pressure := 0.0          # how many shots you have thrown at it lately
var _recent: Array[String] = []  # its last two attacks, which it avoids repeating
var rng := RandomNumberGenerator.new()
var hand: BrainHand
var gates: BrainGates  # the ways over crossings and the clearing of gates
var moves: BrainMoves  # the leap, the wade and the lift it may have in hand
var chant: BrainChant
var danger: BrainDanger
var sight: BrainSight
var _foe: Wizard                 # the wizard it is dealing with: the nearest of the others it knows of
var route := WizardRoute.new()
var goal := ""                  # what it is travelling to: "page", "foe", or "" for nothing
var _goal_page: PagePickup
var _goal_portal: FieldPortal
var _page_steps := 0.0         # seconds it has spent walking the last steps to a page that lies just off the end of its way
var _portal_jumping := 0.0     # seconds it has stood under a portal in the air, jumping for it
var _last_feet := Vector2.INF
var goal_timer := 0.0
var skip := {}                  # a page (its instance id) or a gate (its name) -> seconds it stays off the list, for one that could not be had
var _wise_to_mirages := false      # it has watched a mirage fade, and now sees the waver of the rest
var stuck_at: Array[String] = []  # where it has been held up, for a report
var _nav_version := -1           # which build of the ways its list of pages it cannot reach belongs to
var _hurt_age := 99.0            # seconds since it was last hurt
var settle := 0.0               # seconds it stands still while a way over water grows
var _resting := false            # it has stopped to get its breath back
var _replans := 0                # times in a row it has had to find its way again
var _eye_time := 0.0              # seconds since it sent out a Scrying Eye, counting down (its window shows someone, not where they are)
var scent := 0.0                # seconds that a Hunter's Mark lasts for it: a wizard faded from sight can be found
var _tend_cooldown := 3.0        # counting down to the next time it looks to its own needs
var _rest := {}                  # a spell (or "chase") -> seconds before it uses it for itself again


func _init(body: Wizard) -> void:
	wizard = body
	hand = BrainHand.new(self, body)
	moves = BrainMoves.new(self, body)
	gates = BrainGates.new(self, body)
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
	if knows("Shadow Step") and wizard.max_stamina < Wizard.MAX_STAMINA * 0.4 and _defend_cooldown <= 0.0 and react <= 0.0 and rng.randf() < 0.5:
		_plan("blink_away", 0.25)


## A Flaming Sphere rolling at it along the ground: a person jumps over it, as over a rolling log, instead of standing in its way or running from it.
func _hurdle() -> void:
	if not wizard.is_on_floor() or _jump_cooldown > 0.0 or wizard.wild:
		return
	for node in wizard.get_tree().get_nodes_in_group("fires"):
		if node is FlamingSphere:
			var gap: Vector2 = node.global_position - wizard.global_position
			if absf(gap.y) < 50.0 and absf(gap.x) < 120.0 and signf(-gap.x) == signf(node.direction):
				wizard.request_jump()
				_jump_cooldown = 0.8
				return


## A person cannot type a chant on the move, in the air or under blows, and stops when any of them happens. True while the way it stands lets it type.
## (A wizard that has just opened the box is still coming to a stop: its steps do not break the words for the first moment.)
func _typing_disturbed() -> bool:
	return not wizard.is_on_floor() or _hurt_age < 0.5 or (absf(wizard.velocity.x) > 40.0 and chant.age > BrainChant.STOPPING) or wizard.is_drawing() or wizard.is_frozen() or danger.in_danger(wizard.center())


## Whether this is a place to stand and type: it stands on the ground and is not being hurt, no creature or rival is near enough to come at it, and
## nothing that burns, shoves or bites lies within a few paces. It looks at what is there, not at a clock.
func _quiet_here() -> bool:
	if not wizard.is_on_floor() or absf(wizard.velocity.x) > 30.0 or _hurt_age < 1.5 or wizard.underwater():  # (no one chants under water: the sea is no place to stand and type)
		return false
	if _assailant() != null:
		return false
	if is_instance_valid(_foe) and not _foe.dead and sight.foe_feet().distance_to(wizard.global_position) < 450.0:
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
	if _foe == null and _eye_time <= 0.0 and not wizard.ledger.is_settled("scrying_eye") and SpellTargets.wizards(wizard.get_tree()).size() > 1 and wizard.ledger.knows_chant("scrying_eye"):
		chant.type_then_say("scrying_eye")  # it has lost track of everyone: it sends out an eye once, as a person would (see BrainChant.while_typing); the window stays
	if _foe == null:
		_alone(delta)
		return
	_with_a_rival(delta)


## What runs out as time goes: the cooldowns, the rests, the things it has set aside (pages it gave up, ways it cannot make, bridges laid), and the chant
## it has to break off when it is jostled.
func _run_clocks(delta: float) -> void:
	_hurt_age += delta
	_note_new_pages(delta)
	_dash -= delta
	hand.tick(delta)
	_catch_fall()
	if chant.is_typing() and _typing_disturbed():  # it breaks off the chant, and will not try it here again for a while
		chant.typing = ""
		settle = 0.0
		chant.breaks = mini(chant.breaks + 1, 4)
		_mend_wait = maxf(_mend_wait, 10.0 * chant.breaks)
		_haste_wait = maxf(_haste_wait, 10.0 * chant.breaks)
	cast_cooldown -= delta
	_defend_cooldown -= delta
	_jump_cooldown -= delta
	_escape_time -= delta
	goal_timer -= delta
	settle -= delta
	_tend_cooldown -= delta
	scent -= delta
	_eye_time -= delta
	chant.tick(delta)
	_note_sights(delta)
	_hurdle()
	wizard.shown_words = chant.words_shown()
	pressure *= exp(-delta / 3.0)
	for spell_name in _rest.keys():
		_rest[spell_name] -= delta
		if _rest[spell_name] <= 0.0:
			_rest.erase(spell_name)
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
	_foe = sight.lure.caster if sight.lure != null else sight.nearest_foe()
	_strength_in -= delta
	if _strength_in <= 0.0:
		_strength_in = 1.0
		_strength = _feel_strength(_foe)


## No rival in mind (the last wizard standing, or it knows of no one else): it looks after itself and goes about its journey.
func _alone(delta: float) -> void:
	if react > 0.0:  # (a reaction it has planned still comes: nothing else counts it down here)
		react -= delta
		if react <= 0.0:
			_act(_reaction)
	# It still looks after itself: a light in the dark, its strength, the scent of whoever it has lost.
	if react <= 0.0 and _tend_cooldown <= 0.0 and not wizard.is_drawing() and not moves.busy() and not _smothering():
		_tend_cooldown = 0.6 + rng.randf() * 0.6
		if _tend(Vector2.ZERO, false, false):
			_tend_cooldown = 1.4 + rng.randf() * 0.8
	var mending := _mend(delta, false) if not moves.busy() else NAN
	if not is_nan(mending):
		wizard.walk(mending)
		return
	wizard.walk(_travel(delta) if SpellTargets.wizards(wizard.get_tree()).size() > 1 or wizard.get_tree().get_first_node_in_group(&"gate_source") != null else 0.0)  # (alone in a match it has won; alone in a room it goes on)


## A rival in mind: it reacts to what comes at it, looks after itself, and keeps its footing, its journey or its fight.
func _with_a_rival(delta: float) -> void:
	var foe: Wizard = _foe
	var in_view := wizard.eyes.sees_point(sight.lure.center()) if sight.lure != null else eyes_see(foe)
	var to_player: Vector2 = sight.seen_center(foe) - wizard.center()
	var sees := in_view and danger.clear_line(wizard.center(), sight.seen_center(foe))
	var fighting := sees and to_player.length() < ENGAGE

	_push_through -= delta
	_escape_commit -= delta
	_escapes = maxf(_escapes - delta * 0.5, 0.0)
	# Reactions.
	if react > 0.0:
		react -= delta
		if react <= 0.0:
			_act(_reaction)
	elif not wizard.is_drawing():
		var shot := sight.incoming_shot()
		if not shot.is_empty() and _defend_cooldown <= 0.0:
			_threat_dir = shot["dir"]
			_plan(_choose_defence(shot["eta"]), _reaction_time())
		elif (_dash <= 0.0 and danger.scorched()) or danger.bitten() or (_push_through <= 0.0 and (danger.in_danger(wizard.global_position + Vector2(0, -6)) or danger.in_danger(wizard.center()))):
			_plan("escape", _reaction_time() * 0.6)
			settle = 0.0  # nobody stands in the fire to finish a chant
			chant.typing = ""
			_camped = false
			_escapes += 1.0
			if _escapes > 3.0 and not danger.scorched() and not danger.bitten():  # it keeps backing out of the same thing that lies on its way: it goes through it this once
				_push_through = PUSH_THROUGH_FOR
				_escapes = 0.0
		elif _defend_cooldown <= 0.0 and not _watchers().is_empty():
			_plan("cover", _reaction_time())
		elif fighting and to_player.length() < TOO_CLOSE and _defend_cooldown <= 0.0:
			_plan(_choose_repel(), _reaction_time())

	# Looking after itself: its lights, its strength, a wall between it and you, a way up to you.
	if react <= 0.0 and _tend_cooldown <= 0.0 and not wizard.is_drawing() and not moves.busy() and not _smothering():
		_tend_cooldown = 0.6 + rng.randf() * 0.6
		if _tend(to_player, sees, fighting):
			_tend_cooldown = 1.4 + rng.randf() * 0.8

	if wizard.wild and fighting:
		_wolf(to_player, sees)  # a werewolf has no spells: it runs at the rival and claws
		return

	# Footwork, or the journey.
	var run: float
	var mend := _mend(delta, fighting) if not moves.busy() and react <= 0.0 and wizard.swim_time <= 0.0 else NAN  # (no one rests in deep water)
	if not is_nan(mend):
		wizard.walk(mend)
		return
	if not moves.lift.is_empty():
		run = moves.lifting(delta)  # a throw, a climb or a lift up to you goes on, fight or no
	else:
		var daunted := fighting and _strength < TIMID_BELOW and to_player.length() > TIMID_STAND
		_daunted = _daunted + delta if daunted else 0.0
		var standing_to_fight := fighting and (not daunted or _daunted < TIMID_HESITATE)  # (one that feels weak, after a moment, goes on with its journey and keeps away)
		if standing_to_fight and wizard.swim_time > 0.0:
			run = _swim(delta, true, to_player)  # (out of its depth, it fights as it swims)
		else:
			run = _footwork(delta, to_player, sees) if standing_to_fight else _travel(delta)  # (both may jump: the speed is written after they have)
	wizard.walk(run)
	# A wizard faces the way it runs; it turns to its rival only while standing still or drawing a spell, so it never backpedals.
	var running := run != 0.0 and not wizard.is_drawing()
	wizard.facing = signf(run) if running else (signf(to_player.x) if fighting or wizard.is_drawing() else wizard.facing)
	if not fighting or (_strength < TIMID_BELOW and to_player.length() > TIMID_STAND and _daunted >= TIMID_HESITATE):
		return

	# Attacks.
	if cast_cooldown <= 0.0 and not wizard.is_drawing() and react <= 0.0:
		if _smothering() or _hiding():
			cast_cooldown = 0.3  # another spell would let the breath go; and a wizard out of sight is shown by casting
		elif foe.has_shield():
			cast_cooldown = 0.3  # nothing gets through a Barrier; wait it out
		elif _attack(to_player, sees):
			cast_cooldown = lerpf(2.8, 1.5, skill) + rng.randf() * 0.8
		else:
			cast_cooldown = 0.4


## A werewolf's turn: straight at the rival, and a swipe once they are in reach.
func _wolf(to_player: Vector2, sees: bool) -> void:
	var near := absf(to_player.x) < Wizard.CLAW_REACH * 0.8
	wizard.walk(0.0 if near else signf(to_player.x) * Wizard.SPEED * Wizard.WILD_SPEED)
	wizard.facing = signf(to_player.x) if to_player.x != 0.0 else wizard.facing
	if sees and absf(to_player.x) < Wizard.CLAW_REACH and absf(to_player.y) < 60.0:
		wizard.claw()


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
func _held(foe: Wizard) -> bool:
	return foe.is_rooted() or foe.is_slowed()


## What tells it of the gates about it: a match's world, or a room that has read itself (see RoomScan).
func the_world() -> Node:
	var tree := wizard.get_tree()
	var found := tree.get_first_node_in_group(&"world")
	return found if found != null else tree.get_first_node_in_group(&"gate_source")


## The tile a body stands in, from its feet.
func tile_of(feet: Vector2) -> Vector2i:
	return Vector2i(floori(feet.x / WizardRoute.TILE), floori((feet.y - 1.0) / WizardRoute.TILE))


## Wounds: a wizard worn down to a small maximum, with no one at its heels, lights a bonfire (or goes to one that burns) and rests by it until it has
## mended, as a person does. Returns the speed to walk at, or NAN when it is not mending.
func _mend(delta: float, fighting: bool) -> float:
	_mend_wait -= delta
	if (chant.is_typing() or _camped or settle > 0.0) and (_assailant() != null or danger.scorched() or danger.bitten()):  # it does not sit and chant with a blade or a flame on it
		chant.typing = ""
		settle = 0.0
		_camped = false
		_mend_wait = 3.0
		return NAN
	var fire := _bonfire_near(wizard.global_position, 900.0)
	if _camped:
		_camped_for += delta
		var healed := wizard.max_stamina >= Wizard.MAX_STAMINA * MEND_UNTIL
		if fighting or healed or _camped_for > MEND_MAX or fire == null or wizard.wild:
			_camped = false
			_mend_wait = 12.0
			return NAN
		var off := fire.global_position.x - wizard.global_position.x
		if absf(off) > 50.0:
			return signf(off) * WALK_SPEED * 0.8
		return 0.0
	if fighting or _mend_wait > 0.0 or wizard.max_stamina >= Wizard.MAX_STAMINA * MEND_BELOW or not wizard.is_on_floor() or wizard.is_drawing() or wizard.wild:
		return NAN
	if fire != null and absf(fire.global_position.y - wizard.global_position.y) < 120.0:
		_camped = true
		_camped_for = 0.0
		return 0.0
	if knows("chant:bonfire"):
		if not _quiet_here():  # not here: it goes on a while, and tries again
			_mend_wait = 5.0
			return NAN
		chant.open("bonfire")
		return 0.0
	_mend_wait = 30.0
	return NAN


## What a chant just said sets going: a bonfire it camps by, an eye it looks through.
func _chant_said(id: String) -> void:
	if id == "" or not chant.said[id]:
		return
	if id == "bonfire":
		_camped = true
		_camped_for = 0.0
	if id == "scrying_eye":
		_eye_time = EYE_SECONDS
		chant.said.erase(id)


## True when it can make out another wizard: on its screen, in plain sight, not faded from sight.
func eyes_see(other: Wizard) -> bool:
	return wizard.eyes.sees_wizard(other)


## The nearest bonfire that burns, within reach of a point, or null.
func _bonfire_near(point: Vector2, reach: float) -> Bonfire:
	var best: Bonfire = null
	var best_gap := reach
	for node in wizard.get_tree().get_nodes_in_group("fires"):
		if node is Bonfire and not node.is_queued_for_deletion():
			var gap: float = node.global_position.distance_to(point)
			if gap < best_gap:
				best = node
				best_gap = gap
	return best


## When it has got nowhere for a long time (a way its map has wrong, a ledge it cannot reach, a wind it cannot walk against), it drops what it was
## after and goes after something else, and if that does not help either it wanders a few steps, as a person does who has no idea what is wrong.
func _watch_progress(delta: float) -> void:
	if wizard.global_position.distance_to(_anchor) > STUCK_RADIUS or _resting or goal == "":
		_anchor = wizard.global_position
		_anchored_for = 0.0
		return
	_anchored_for += delta
	if _anchored_for < STUCK_FOR:
		return
	_anchored_for = 0.0
	_unsticks += 1
	if goal == "page" and is_instance_valid(_goal_page):
		skip[_goal_page.get_instance_id()] = GIVE_UP
	elif goal == "portal" and is_instance_valid(_goal_portal):
		skip[_goal_portal.get_instance_id()] = GIVE_UP
	elif goal == "gate":
		skip[gates.gate_key(gates.goal_gate)] = GIVE_UP
	goal = ""
	goal_timer = 0.0
	route.clear()
	if _unsticks >= 2:
		_unsticks = 0
		_wander_dir = -1.0 if rng.randf() < 0.5 else 1.0
		_wander_time = rng.randf_range(1.5, 3.0)
		wizard.request_jump()


## A creature close by that would strike it: the nearest one that is awake and not its own, or null.
func _assailant() -> Mob:
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


## A creature is on it: it does what a person does, and strikes it down with a spell that kills, or, with none to hand, runs. Returns the
## speed to walk at, or NAN when nothing is upon it.
func _assailed(delta: float) -> float:
	_assail_commit -= delta
	var mob := _assailant()
	if mob == null:
		if _assail_commit > 0.0 and _assail_dir != 0.0:
			return _assail_dir * WALK_SPEED * 1.2  # (it runs on a moment, and does not turn straight back to it)
		return NAN
	settle = 0.0  # no one stands typing with a blade at their back
	chant.typing = ""
	_camped = false
	_resting = false
	var away := signf(wizard.global_position.x - mob.global_position.x)
	if away == 0.0:
		away = -wizard.facing
	var spell_name := gates.clearing_spell("giant" if mob.max_hp >= 1000 else "creature")
	if spell_name != "" and not wizard.is_drawing() and cast_cooldown <= 0.0 and react <= 0.0:
		gates.goal_gate = {"kind": "giant" if mob.max_hp >= 1000 else "creature", "entry": {"mob": mob, "nodes": [mob]}, "target": mob.center()}
		cast_cooldown = 1.4
		hand.begin_cast(spell_name, hand.gate_stroke(spell_name, mob.center()), ATTACK_DRAW)
		return 0.0
	if wizard.is_drawing():
		return 0.0
	if spell_name != "" and mob.max_hp < 1000.0:
		return away * WALK_SPEED * 0.6 if absf(mob.global_position.x - wizard.global_position.x) < 70.0 else 0.0  # it gives ground while its spell is ready again
	_assail_dir = away
	_assail_commit = 1.2
	if wizard.is_on_wall() and wizard.is_on_floor() and _jump_cooldown <= 0.0:
		wizard.request_jump()
		_jump_cooldown = 0.5
	return away * WALK_SPEED * 1.2


## Walks the way to what it is after, and reads a page when it stands under one. Returns the speed to walk at.
func _travel(delta: float) -> float:
	var held := _held_up(delta)
	if not is_nan(held):
		return held
	var at_the_goal := _at_the_goal(delta)
	if not is_nan(at_the_goal):
		return at_the_goal
	var short_of_page := goal == "page" and route.done() and is_instance_valid(_goal_page) and tile_of(_goal_page.global_position).distance_to(tile_of(wizard.global_position)) > PAGE_REACH + 2  # (its way stopped at the edge of what it knew: it looks again from there)
	if (goal == "" and goal_timer <= 0.0) or _goal_lost() or short_of_page or ((goal == "foe" or goal == "exit" or goal == "explore") and (goal_timer <= 0.0 or route.done())):
		_choose_goal()
	if wizard.swim_time > 0.0:
		return _swim(delta, false, Vector2.ZERO)
	if goal != "" and not route.done() and wizard.is_on_floor():  # (a wizard in the air cannot stop for it; after the goal is chosen, so that a gate on the way is seen before the first step towards it)
		var crossing := gates.crossing_ahead()
		gates.cross_run = 0.0
		if not crossing.is_empty() and gates.cross(crossing):
			return gates.cross_run
	# Standing on a wooden platform or a ridge that the map does not know, high over the ground it does know: it steps down through it.
	_off_map_check -= delta
	if _off_map_check <= 0.0 and wizard.is_on_floor():
		_off_map_check = 0.4
		var here := tile_of(wizard.global_position)
		var known: Vector2i = wizard.nav.nearest(here, true)
		_off_map = known != WorldNav.NONE and known.y - here.y >= 3 and absi(known.x - here.x) <= 6
	if _off_map and wizard.is_on_floor():
		wizard.drop_through()
	var volcano := danger.volcano_near(wizard.global_position, VOLCANO_FLEE) if not moves.busy() else Vector2.INF
	if volcano != Vector2.INF and not wizard.lava_proof() and wizard.is_on_floor():
		goal = ""  # a volcano is awake close by: it goes away from it, and chooses what to do when it is far enough off
		goal_timer = 0.5
		return signf(wizard.global_position.x - volcano.x) * WALK_SPEED
	return _follow_route(delta)


## What keeps it from going on with its journey this frame: a manoeuvre in hand (a leap, a wade, a lift), a creature at its heels, a chant to say, a stroke
## to draw, a place to wander or escape to, a row of pads to walk, or a rest. The speed to walk at when there is one, and NAN when there is none.
func _held_up(delta: float) -> float:
	if moves.busy():
		return moves.tick(delta)
	var assailed := _assailed(delta)
	if not is_nan(assailed):
		return assailed
	if settle > 0.0:
		return 0.0
	if wizard.is_drawing():
		return 0.0
	_watch_progress(delta)
	if goal != "" and route.remaining() > HASTE_FROM and wizard.haste_time <= 0.0 and _haste_wait <= 0.0 and knows("chant:haste") and _quiet_here():
		_haste_wait = 25.0
		chant.open("haste")  # (it stops to say it, as a person does)
		return 0.0
	_haste_wait -= delta
	if _wander_time > 0.0:
		_wander_time -= delta
		if wizard.is_on_floor() and _jump_cooldown <= 0.0 and wizard.is_on_wall():
			wizard.request_jump()
			_jump_cooldown = 0.6
		return _wander_dir * WALK_SPEED
	if _escape_time > 0.0:
		if wizard.is_on_wall() and wizard.is_on_floor() and _jump_cooldown <= 0.0:  # a bank too steep to walk up: it hops
			wizard.request_jump()
			_jump_cooldown = 0.5
		return _escape_dir * WALK_SPEED * 1.3
	if gates.walking_pads():
		return gates.cross_run
	if _resting and wizard.stamina >= minf(REST_UNTIL, wizard.max_stamina * 0.9):  # (a wizard worn down to a small maximum rests up to that, not up to more than it can ever hold)
		_resting = false
	elif not _resting and wizard.stamina < minf(REST_BELOW, wizard.max_stamina * 0.3) and wizard.is_on_floor():
		_resting = true
	if _resting:
		return 0.0
	if wizard.nav == null:
		return 0.0
	return NAN


## What it does on coming to its goal (a portal to leap for, a page to walk the last steps to, a gate to work, a creature to clear from the way). The speed to
## walk at when it does one of them, and NAN when it has not come to anything.
func _at_the_goal(delta: float) -> float:
	_read_page_underfoot()
	if _last_feet.distance_to(wizard.global_position) > 250.0 and _last_feet != Vector2.INF:  # a portal has carried it off: the way it was going is no use
		goal = ""
		goal_timer = 0.0
	_last_feet = wizard.global_position
	if goal == "portal" and route.done():
		if is_instance_valid(_goal_portal) and _goal_portal.lift > 0.0 and _portal_jumping < PORTAL_JUMP_FOR and not _goal_lost():
			return _jump_for_portal(delta)  # it stands under a portal hung in the air and leaps for it
		skip[_goal_portal.get_instance_id()] = GIVE_UP  # it has come to the portal and nothing came of it
		goal = ""
		goal_timer = 0.0
	if goal == "page" and route.done() and not _goal_lost() and is_instance_valid(_goal_page):
		var short: Vector2 = _goal_page.global_position - wizard.global_position
		if absf(short.x) > PAGE_TOUCH and absf(short.x) < PAGE_STEPS and absf(short.y) < PAGE_STEPS and _page_steps < PAGE_STEPS_TIME:
			_page_steps += delta  # the way ends a little short of it (the ground it lies on is not on the map): the last steps are walked
			return signf(short.x) * WALK_SPEED
	if goal == "page" and route.done() and not _goal_lost():  # it has come to the place, and the page is not to be had from there
		skip[_goal_page.get_instance_id()] = GIVE_UP
		goal = ""
		goal_timer = 0.0
	if goal == "gate":
		if gates.gate_open(gates.goal_gate["entry"]):
			goal = ""
			goal_timer = 0.0
		elif route.done():
			gates.work_gate()
			return 0.0
	var creature := gates.creature_ahead()
	if not creature.is_empty():
		gates.goal_gate = creature
		goal = "gate"
		gates.gate_tries = 0
		gates.clear_gate(creature["target"])
		return 0.0
	return NAN


## One step along its route: the way the route points, and the lava that may lie on it, which it waits out, runs over or turns from.
func _follow_route(delta: float) -> float:
	var steer := route.steer(wizard, delta)
	if steer["replan"]:
		stuck_at.append("%s %s" % [str(tile_of(wizard.global_position)), route.status()])
		_stuck_on_goal()
	if route.waiting_for_stair and goal == "explore":
		_stair_wait += delta
		if _stair_wait > STAIR_PATIENCE:  # a person does not stand at a stair for half a minute just to see what lies past it: they look elsewhere
			_stair_wait = 0.0
			var far := route.last()
			if far != WorldNav.NONE:  # the place it was going to is given up (a floor above or below as well as one along)
				_explored[_square_of(Vector2(far.x * WizardRoute.TILE, far.y * WizardRoute.TILE))] = true
			for k in range(0, 3):
				_explored[_square_of(wizard.global_position + Vector2(signf(_explore_dir) * k * 600.0, 0.0))] = true
			_explore_dir = -_explore_dir
			goal = ""
			goal_timer = 0.0
			route.clear()
	else:
		_stair_wait = 0.0
	var ahead := signf(steer["dir"])
	if ahead != 0.0 and wizard.is_on_floor() and _dash <= 0.0 and not danger.lethal_at(wizard.global_position + Vector2(0, -6)):
		var near := danger.lethal_at(_over_ground(ahead * 40.0)) or danger.lethal_at(_over_ground(ahead * 72.0))
		if near or danger.lethal_at(_over_ground(ahead * 110.0)):
			# lava or an eruption lies on the way: it keeps its distance, backing away if it is close, and waits for it to pass or cool; when that takes
			# too long it looks for another way
			_danger_wait += delta
			route.wait()
			if _danger_wait > DASH_AFTER and wizard.max_stamina >= DASH_MIN_MAX and _lethal_stretch(ahead) <= DASH_MAX:  # a narrow stretch is not worth a wait: a person runs over it and takes the hit
				_dash = 1.6
				_danger_wait = 0.0
				return steer["dir"] * WALK_SPEED
			if _danger_wait > DANGER_WAIT_MAX:
				_danger_wait = 0.0
				if goal == "page" and is_instance_valid(_goal_page):
					skip[_goal_page.get_instance_id()] = GIVE_UP
				elif goal == "explore":  # it will not look that way again: it turns round and tries the other side
					for k in range(0, 7):
						_explored[_square_of(wizard.global_position + Vector2(ahead * k * 600.0, 0.0))] = true
					_explore_dir = -ahead
				goal = ""
				goal_timer = 0.0
				route.clear()
			return -ahead * WALK_SPEED * 0.8 if near else 0.0
		_danger_wait = maxf(_danger_wait - delta * 0.15, 0.0)  # (backing off and coming back does not start the waiting over)
	else:
		_danger_wait = 0.0
	if steer["drop"]:
		wizard.drop_through()
	if steer["jump"] and wizard.is_on_floor():
		wizard.request_jump()
	wizard.climb_up = steer["climb"]  # at the foot of a rope ladder, the way up it
	wizard.let_go = steer["let_go"]  # and the hop off it at the top
	return steer["dir"] * steer["speed"]


## Out of its depth there is no walking: it swims, as a person does, the jump key a stroke at a time and S to dive (Wizard.swim). The map of ways
## (WizardRoute) is made for legs, and in the sea a jump is a stroke and a fall a slow sink: following it, wizards bobbed at the top of the sea over
## the floor they meant to reach, and three drowned against the edge of the world. So it swims straight for where it is going (the end of its route,
## the page it wants, a place a little short of the rival it fights), over whatever is in the way, and goes for air when its breath would only just
## last the way there: straight up when nothing is over it, else to an air pocket or to open water to one side. Returns its speed sideways.
func _swim(delta: float, fighting: bool, to_player: Vector2) -> float:
	_stroke_in -= delta
	wizard.swim_down = false
	var here := wizard.center()
	var air := _nearest_air(here)
	if wizard.deep_breath_time > 0.0:
		_for_air = false
	elif wizard.underwater() and wizard.breath < (absf(air.x - here.x) + absf(air.y - here.y)) / SWIM_RISE + AIR_SPARE:  # (the way across and then up, which it may have to take)
		_for_air = true
	elif _for_air and wizard.breath >= Wizard.BREATH * 0.95:
		_for_air = false
	var target := air
	if not _for_air:
		if fighting and to_player.length() > 1.0:
			target = here + to_player - to_player.normalized() * SWIM_HOLD
		else:
			target = _swim_goal()
	if target == Vector2.INF:
		return 0.0
	var line := target - here
	if not _for_air and not fighting and line.length() < SWIM_ARRIVE:
		route.clear()  # it is there: what comes next is chosen afresh
		return 0.0
	var blocked := wizard.is_on_wall() and absf(line.x) > SWIM_ARRIVE  # (a stroke takes it up over what is in the way)
	var keep_up := _for_air and not wizard.underwater() and wizard.velocity.y > 0.0  # (its head over the water while it breathes)
	var overhead := line.y < -24.0 and absf(line.x) > 12.0 and not danger.clear_line(here, target)  # something solid over the straight way (a wreck's hull): across under it first, then up
	if ((line.y < -24.0 and not overhead) or blocked or keep_up) and _stroke_in <= 0.0:
		_stroke_in = Wizard.STROKE_EVERY
		wizard.request_jump()
	elif line.y > 40.0 and not blocked:
		wizard.swim_down = true
		if wizard.is_on_floor():
			wizard.drop_through()  # (on a deck or driftwood over where it is going: it goes down through it, as a person does with S)
	return signf(line.x) * WALK_SPEED if absf(line.x) > 12.0 else 0.0


## Where its journey goes, swimming: the page it wants, or the end of its route (a place to look at, the rival it hunts). INF when it has none.
func _swim_goal() -> Vector2:
	if goal == "page" and is_instance_valid(_goal_page):
		return _goal_page.global_position + Vector2(0.0, -20.0)
	if not route.done():
		var end := route.last()
		if end != WorldNav.NONE:
			var at := Vector2((end.x + 0.5) * WizardRoute.TILE, (end.y + 1) * WizardRoute.TILE) + wizard.center() - wizard.global_position
			if _inside_solid(at):  # the map of the ways does not know a wreck's hull: a place inside one is given up as seen, and another is chosen
				_explored[_square_of(at)] = true
				route.clear()
				goal = ""
				return Vector2.INF
			return at
	return Vector2.INF


## True when a point lies inside something solid that is not the ground: a wreck's hull, a wall of stone. (The ground's outlines have no inside
## for a query to find, so it is asked of the map instead.)
func _inside_solid(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return not wizard.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


## The nearest air from under the water: the surface straight over it when nothing solid is in the way, else over open water a little to one side,
## or an air pocket (AirPocket) if one is nearer.
func _nearest_air(here: Vector2) -> Vector2:
	var top := wizard.water_surface()
	if top == INF:
		return here  # (in no water: it is breathing)
	var best := Vector2.INF
	for dx: float in [0.0, -96.0, 96.0, -224.0, 224.0, -384.0, 384.0, -AIR_SCAN, AIR_SCAN]:
		var below := Vector2(here.x + dx, here.y)
		var over := Vector2(below.x, top - 30.0)  # (its head out of the water)
		if (dx == 0.0 or danger.clear_line(here, below)) and danger.clear_line(below, over):
			best = over
			break
	for pocket: AirPocket in wizard.get_tree().get_nodes_in_group("air_pockets"):
		var inside := pocket.global_position + Vector2(0.0, -pocket.size.y * 0.5)
		if not danger.clear_line(here, inside):
			continue  # (a pocket behind a wreck's hull is no use: it is reached round the hull, not through it)
		if best == Vector2.INF or here.distance_to(inside) < here.distance_to(best):
			best = inside
	return best if best != Vector2.INF else Vector2(here.x, top - 30.0)


## The width in pixels of the lava (or other danger) that starts within reach ahead, or INF when it is wider than it is worth, or no ground lies past it.
func _lethal_stretch(ahead: float) -> float:
	var start := -1.0
	var d := 16.0
	while d <= 480.0:
		var bad := danger.lethal_at(_over_ground(ahead * d))
		if bad and start < 0.0:
			start = d
		elif not bad and start >= 0.0:
			var landing := _over_ground(ahead * (d + 32.0))
			return d - start if not danger.lethal_at(landing) and absf(landing.y - wizard.global_position.y) < 120.0 else INF
		d += 16.0
	return INF


## Reads the page it stands under, if it does not have it.
func _read_page_underfoot() -> void:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if pickup.gives(wizard.ledger) and pickup.is_under(wizard):
			wizard.get_parent().read_page(pickup, wizard)
			_replans = 0
			goal = ""
			goal_timer = 0.0
			return


## Stands under the portal it is after and jumps until it is carried off. Returns the speed to go at.
func _jump_for_portal(delta: float) -> float:
	_portal_jumping += delta
	if wizard.is_on_floor() and _jump_cooldown <= 0.0:
		wizard.request_jump()
		_jump_cooldown = 0.7
	var off := _goal_portal.global_position.x - wizard.global_position.x
	return signf(off) * WALK_SPEED * 0.5 if absf(off) > 14.0 else 0.0


## The page it was going to has gone: someone else read it, or it has it already.
func _goal_lost() -> bool:
	if goal == "page" and _wise_to_mirages and is_instance_valid(_goal_page) and _goal_page is Mirage:
		return true
	if goal == "portal":
		return not is_instance_valid(_goal_portal) or _goal_portal.is_closing() or _goal_portal.remaining() < PORTAL_LEFT * 0.5
	return goal == "page" and (not is_instance_valid(_goal_page) or not _goal_page.gives(wizard.ledger))


## Picks what to go for: the page nearest by the way it must walk, and when there is none to be had, the nearest wizard.
func _choose_goal() -> void:
	goal_timer = GOAL_EVERY
	_sight_timer = 0.0
	_note_sights(0.0)  # (what lies in view now is known now)
	goal = ""
	var start: Vector2i = wizard.nav.nearest(tile_of(wizard.global_position), true)
	if start == WorldNav.NONE:
		return
	var found := _pick_page(start)
	var best_page: PagePickup = found["page"]
	var best_path: Array[Vector2i] = []
	best_path.assign(found["path"])
	var portal := _nearest_portal(start)
	if portal.has("portal") and (best_page == null or (portal["path"].size() < best_path.size() and rng.randf() < PORTAL_CHANCE)):
		goal = "portal"
		_goal_portal = portal["portal"]
		_portal_jumping = 0.0
		route.set_path(portal["path"])
		return
	if _foe != null and _strength >= BOLD_ABOVE and (best_page == null or best_path.size() > HUNT_PAGE_NEAR):  # feeling strong, it goes after a rival rather than a page that lies far off
		var hunt: Array[Vector2i] = find_path(start, wizard.nav.nearest(tile_of(sight.foe_feet())))
		if not hunt.is_empty():
			goal = "foe"
			route.set_path(hunt)
			return
	if best_page != null:
		goal = "page"
		_goal_page = best_page
		_page_steps = 0.0
		route.set_path(best_path)
		return
	if _choose_explore(start):
		return
	if _choose_gate(start):
		return
	var exit := wizard.get_tree().get_first_node_in_group(&"exit_points")  # a room's way out, when nothing is left to take
	if exit != null:
		var way: Array[Vector2i] = find_path(start, wizard.nav.nearest(tile_of(exit.global_position)))
		if not way.is_empty():
			goal = "exit"
			route.set_path(way)
			return
	if _foe != null:
		var path: Array[Vector2i] = find_path(start, wizard.nav.nearest(tile_of(sight.foe_feet())))
		if not path.is_empty():
			goal = "foe"
			route.set_path(path)


## The page it will go for from where it stands: the one that seems nearest of those it knows of and can reach, and the way to it ({"page", "path"}). The
## page is null when it knows of none worth the walk. Pages it cannot reach are given up for a while on the way.
func _pick_page(start: Vector2i) -> Dictionary:
	var best_page: PagePickup = null
	var best_path: Array[Vector2i] = []
	var best_worth := INF
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup.gives(wizard.ledger) or skip.has(pickup.get_instance_id()) or (pickup is Mirage and _wise_to_mirages):
			continue
		if _sight_is_limited() and not _seen_pages.has(pickup.get_instance_id()):
			continue  # it has not set eyes on that one
		if danger.volcano_near(pickup.global_position, VOLCANO_KEEP_OFF) != Vector2.INF and not wizard.lava_proof():
			continue  # a page by a volcano that is erupting is left until it is over
		var tile := tile_of(pickup.global_position)
		var stand: Vector2i = wizard.nav.nearest(tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - tile.x) + absi(stand.y - tile.y) <= PAGE_REACH:
			path = _raw_path(start, stand)
			if path.is_empty() and stand == start:
				path = [start]  # it stands where the way to the page ends: nothing to walk, though the page may lie a few steps off
		if path.is_empty():
			skip[pickup.get_instance_id()] = GIVE_UP  # no way there that a wizard can walk
			continue
		# How far it seems: the way, when it knows the ground the way goes over; else as the crow flies, all a person can guess of ground unseen.
		var known := not _sight_is_limited() or _through_known(path, start, stand)
		var length := float(path.size()) if known else Vector2(stand - start).length()
		var worth := length / sqrt(maxf(1.0, float(pickup.new_pages(wizard.ledger).size())))  # a dropped book is worth the walk: the more pages it would give, the nearer it counts
		if best_page == null or worth < best_worth:
			best_page = pickup
			best_path = path if known else _no_path()
			best_worth = worth
	if best_page != null and best_path.is_empty():  # it knows of the page but not the way: as far toward it as the ground it has seen takes it
		best_path = _toward_known(start, wizard.nav.nearest(tile_of(best_page.global_position)))
		if best_path.is_empty():
			skip[best_page.get_instance_id()] = LOOK_AGAIN  # nothing it knows leads nearer: it looks about, and comes back to it
			best_page = null
	return {"page": best_page, "path": best_path}


## In a match a wizard knows of a page only when it has seen it, as a person does, and goes looking when it knows of none.
func _sight_is_limited() -> bool:
	return wizard.get_tree().get_first_node_in_group(&"world") != null


func _note_sights(delta: float) -> void:
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = 0.4
	var at := wizard.center()
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if wizard.eyes.rect().grow(PAGE_GLOW).has_point(pickup.global_position) and not SpellTargets.sight_blocked(wizard.get_tree(), at, pickup.global_position):
			_seen_pages[pickup.get_instance_id()] = true
	_explored[_square_of(wizard.global_position)] = true
	# Everything on its screen has been seen: the squares whose middles lie on it are explored too.
	var view := wizard.eyes.rect()
	var square := Vector2(16.0 * WizardRoute.TILE, 12.0 * WizardRoute.TILE)
	var first := _square_of(view.position)
	var last := _square_of(view.end)
	for sx in range(first.x, last.x + 1):
		for sy in range(first.y, last.y + 1):
			if view.has_point((Vector2(sx, sy) + Vector2(0.5, 0.5)) * square):
				_explored[Vector2i(sx, sy)] = true
	if _seen_pages.size() > 400:
		_seen_pages.clear()


func _square_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / (16.0 * WizardRoute.TILE)), floori(point.y / (12.0 * WizardRoute.TILE)))


## Goes to look at a part of the world it has not been to: along the way it was going, or the other way when that is shut off.
func _choose_explore(start: Vector2i) -> bool:
	if not _sight_is_limited():
		return false
	if _explore_dir == 0.0:
		_explore_dir = -1.0 if rng.randf() < 0.5 else 1.0
	for round in 2:
		# It looks at what lies near first (to either side, and up or down a floor), and likes to go on the way it was going.
		var best_path: Array[Vector2i] = []
		var best_cost := INF
		var best_dir := _explore_dir
		for dy in [0, -EXPLORE_FLOOR, EXPLORE_FLOOR, -2 * EXPLORE_FLOOR, 2 * EXPLORE_FLOOR]:
			for dir: float in [_explore_dir, -_explore_dir]:
				for k in range(0 if dy != 0 else 1, 10):
					var aim := Vector2i(start.x + int(dir) * k * EXPLORE_STEP, start.y + dy)
					var tile: Vector2i = wizard.nav.nearest(aim, true)
					if tile == WorldNav.NONE or (absi(tile.x - start.x) < EXPLORE_STEP / 2 and absi(tile.y - start.y) < EXPLORE_FLOOR / 2):
						continue
					if _explored.has(_square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))):
						continue
					if Wreck.covers(wizard.get_tree(), Vector2((tile.x + 0.5) * WizardRoute.TILE, (tile.y + 1) * WizardRoute.TILE)):
						continue  # (a wreck is taken in at a glance: its page and its air are sought for themselves, its hold is not searched square by square)
					var path: Array[Vector2i] = _raw_path(start, tile)
					if path.is_empty() or not _through_known(path, start, tile):
						continue
					var cost := float(path.size()) + rng.randf() * 12.0 - (14.0 if dir == _explore_dir else 0.0)
					if cost < best_cost:
						best_cost = cost
						best_path = path
						best_dir = dir
					break  # (the nearest unexplored square this way on this floor is the one to weigh)
		if not best_path.is_empty():
			_explore_dir = best_dir
			goal = "explore"
			route.set_path(best_path)
			return true
		_explored.clear()  # it has been everywhere it can get to: it looks again
	return false


## Whether a way to an unexplored square goes only over ground it has seen, and the square itself or ground next to where it stands: a person
## exploring knows the ground they have seen, not the ground beyond, so they go to the edge of what they know and look. (The map of the ways is
## the whole world's; this keeps the brain to the part a person would know.)
func _through_known(path: Array[Vector2i], start: Vector2i, target: Vector2i) -> bool:
	var here := _square_of(Vector2(start.x * WizardRoute.TILE, start.y * WizardRoute.TILE))
	var there := _square_of(Vector2(target.x * WizardRoute.TILE, target.y * WizardRoute.TILE))
	for tile in path:
		var sq := _square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))
		if _explored.has(sq) or (absi(sq.x - there.x) <= 1 and absi(sq.y - there.y) <= 1) or (absi(sq.x - here.x) <= 1 and absi(sq.y - here.y) <= 1):
			continue
		return false
	return true


## The open portal nearest by the way it must walk, as {"portal", "path"}, or nothing when fewer than two are open (one leads nowhere).
func _nearest_portal(start: Vector2i) -> Dictionary:
	var open: Array = wizard.get_tree().get_nodes_in_group("field_portals").filter(func(p: FieldPortal) -> bool: return not p.is_closing())
	var best := {}
	if open.size() < 2:
		return best
	for portal: FieldPortal in open:
		if portal.remaining() < PORTAL_LEFT or portal.lift > PortalField.JUMPABLE or skip.has(portal.get_instance_id()):  # one hung higher than a jump reaches is not for it
			continue
		var path: Array[Vector2i] = find_path(start, wizard.nav.nearest(tile_of(portal.global_position + Vector2(0.0, Portal.RY + portal.lift))))
		if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
			best = {"portal": portal, "path": path}
	return best


## When no page is to be had, the nearest gate that it holds a spell for: it goes to the place short of it. True when it has set out.
func _choose_gate(start: Vector2i) -> bool:
	var world := the_world()
	if world == null:
		return false
	var best := {}
	var best_path: Array[Vector2i] = []
	for gate: Dictionary in world.closed_gates():
		if skip.has(gates.gate_key(gate)) or gates.clearing_spell(gate["kind"]) == "":
			continue
		var floor_tile: Vector2i = gate["outside"] + Vector2i(0, -1)
		var stand: Vector2i = wizard.nav.nearest(floor_tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - floor_tile.x) + absi(stand.y - floor_tile.y) <= 3:
			path = find_path(start, stand)
		if path.is_empty():
			skip[gates.gate_key(gate)] = GIVE_UP
			continue
		if best.is_empty() or path.size() < best_path.size():
			best = gate
			best_path = path
	if best.is_empty():
		return false
	goal = "gate"
	gates.goal_gate = best
	gates.gate_tries = 0
	gates.gate_gone = 0
	route.set_path(best_path)
	return true


## The way to a place, as a person would know it (owner, 2026-11-12: the brain planned its ways with the whole world's map, ground it had never
## seen included). In a match, when the way goes over ground it has not seen, it goes only as far toward the place as the ground it has seen
## takes it (_toward_known); there it sees more, and finds the way on from there. In a room (the tutorial, the waiting room) the ground is all in view.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var full := _raw_path(from, to)
	if full.is_empty() or not _sight_is_limited() or _through_known(full, from, to):
		return full
	return _toward_known(from, to)


## As far toward a place as the ground it has seen takes it: of the places it knows that lie between here and there (along the line to it, and
## along its own floor), the one nearest the place that it can walk to over ground it has seen. Empty when none is nearer than where it stands.
func _toward_known(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var best := _no_path()
	var best_gap := Vector2(to - from).length() - 3.0  # it must come nearer, or there is no point
	var aims: Array[Vector2i] = []
	for k in range(8, 0, -1):
		aims.append(from + Vector2i((Vector2(to - from) * k / 8.0).round()))  # along the line, the far end first
	var side := signi(to.x - from.x)
	for k in range(1, 6):
		aims.append(Vector2i(from.x + side * k * EXPLORE_STEP / 2, from.y))  # and along its own floor, the way the place lies
	for aim in aims:
		var tile: Vector2i = wizard.nav.nearest(aim, true)
		if tile == WorldNav.NONE or tile == from or not _explored.has(_square_of(Vector2(tile.x * WizardRoute.TILE, tile.y * WizardRoute.TILE))):
			continue
		var gap := Vector2(to - tile).length()
		if gap >= best_gap:
			continue
		var path := _raw_path(from, tile)
		if path.is_empty() or not _through_known(path, from, tile):
			continue
		best = path
		best_gap = gap
	return best


func _no_path() -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	return none


## The way from one tile to another that it can walk, over the whole world's map: not over a crossing it holds no spell for.
func _raw_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := []
	var world := the_world()
	if world != null:
		for crossing: Dictionary in world.crossings():
			if gates.way_over(crossing) == "" or gates.cannot.has(crossing["key"]):
				shut.append(crossing["key"])
	return wizard.nav.path(from, to, shut)


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


## It is getting nowhere on its way: find the way again, and after a few tries give the page up for a while.
func _stuck_on_goal() -> void:
	_replans += 1
	if goal == "portal" and _replans >= 3 and is_instance_valid(_goal_portal):
		skip[_goal_portal.get_instance_id()] = GIVE_UP
		_replans = 0
		_choose_goal()
		return
	if goal == "page" and _replans >= 3 and is_instance_valid(_goal_page):
		skip[_goal_page.get_instance_id()] = GIVE_UP
		_replans = 0
		_choose_goal()
		return
	var start: Vector2i = wizard.nav.nearest(tile_of(wizard.global_position), true)
	var path: Array[Vector2i] = find_path(start, route.goal())
	if path.is_empty():
		goal = ""
	else:
		route.set_path(path)


## What it is doing, for a report.
func status() -> String:
	return "%s (%s)" % [goal if goal != "" else "nothing", route.status()]


# --- Reactions --------------------------------------------------------------------------------------------------


## The sentinels that have it in sight, when it holds a spell to meet them with.
func _watchers() -> Array:
	var out := []
	if not COVERS.any(knows):
		return out
	for post: Sentinel in wizard.get_tree().get_nodes_in_group("sentinels"):
		if post.sees(wizard.center()):
			out.append(post)
	return out


func _choose_defence(eta: float) -> String:
	var options := {"jump": 1.0}
	if knows("Gust") and wizard.stamina >= 15.0 and eta > QUICK_DRAW + 0.05:
		options["reflect"] = 0.6 + 1.6 * skill  # a skilled wizard sends your spells back at you
	if knows("Barrier") and wizard.stamina >= 35.0 and eta > QUICK_DRAW + 0.05:
		options["shield"] = 0.5
	if knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_side"] = 0.7
	if not wizard.is_on_floor():
		options.erase("jump")
	return _pick(options) if not options.is_empty() else ""


func _choose_repel() -> String:
	var options := {}
	if _ready_to_cast("Geyser") and _foe.stands():
		options["geyser"] = 1.0
	if _ready_to_cast("Tide Surf"):
		options["surf"] = 0.9
	if _ready_to_cast("Spore Puff") and danger.clear_line(wizard.center(), sight.seen_center(_foe)):
		options["spores"] = 1.1
	if knows("Push") and wizard.stamina >= 10.0:
		options["push"] = 1.5
	if knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_away"] = 1.0
	if knows("Fire Breath") and wizard.stamina >= 16.0 and danger.clear_line(wizard.center(), sight.seen_center(_foe)):
		options["breath"] = 1.3
	return _pick(options) if not options.is_empty() else "escape"


func _act(reaction: String) -> void:
	var foe: Wizard = _foe
	if (not is_instance_valid(foe)) and reaction in ["push", "breath", "spores", "geyser", "surf", "blink_side", "blink_away"]:
		return  # (a reaction planned against a rival who is gone from its mind by the time it comes)
	match reaction:
		"jump":
			if wizard.is_on_floor():
				wizard.request_jump(0.8)
			_defend_cooldown = 0.6
		"reflect":
			# A Gust blown toward where the shot came from: it turns the shot round and sends it back.
			var start: Vector2 = wizard.center() - _threat_dir * 20.0
			hand.begin_cast("Gust", BrainStrokes.line(start, start - _threat_dir * 90.0), QUICK_DRAW)
			_defend_cooldown = 1.4
		"cover":
			var watchers := _watchers()
			if not watchers.is_empty():
				gates.cover(watchers[0])
			_defend_cooldown = 4.0
		"shield":
			hand.begin_cast("Barrier", BrainStrokes.offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), QUICK_DRAW)
			_defend_cooldown = 2.5
		"blink_side", "blink_away":
			_blink_away(foe)
			_defend_cooldown = 1.6
		"escape":
			if _escape_commit <= 0.0 or _escape_dir == 0.0:
				_escape_dir = _safe_side()  # (once it has chosen a way out, it keeps to it for a while rather than turning back at every lick of flame)
				_escape_commit = 1.8
			_escape_time = 0.6
			if knows("Shadow Step") and wizard.stamina >= 12.0 and rng.randf() < skill * 0.6:
				var from: Vector2 = wizard.center()
				hand.begin_cast("Shadow Step", BrainStrokes.line(from, from + Vector2(_escape_dir * 240.0, -12.0)), QUICK_DRAW)  # (to the safe side, not away from the rival)
			_defend_cooldown = 0.6
		"push":
			var away: Vector2 = (sight.seen_center(foe) - wizard.center()).normalized()
			hand.begin_cast("Push", hand.push_stroke(sight.seen_center(foe), away), QUICK_DRAW)
			_defend_cooldown = 1.5
		"breath":
			hand.begin_cast("Fire Breath", hand.breath_stroke(sight.seen_center(foe)), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8
		"spores":
			hand.begin_cast("Spore Puff", hand.breath_stroke(sight.seen_center(foe)), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8
		"geyser":  # the ground bubbles under its feet and throws it off
			hand.begin_cast("Geyser", BrainStrokes.offset(GestureTemplates.preview_points("geyser"), sight.seen_feet(foe) + Vector2(0.0, -24.0), 0.6), QUICK_DRAW)
			_defend_cooldown = 1.8
		"surf":
			hand.begin_cast("Tide Surf", hand.surf_stroke(signf(sight.seen_feet(foe).x - wizard.global_position.x)), QUICK_DRAW)
			_defend_cooldown = 1.8


## Steps away from the player along the ground, or past them if its back is to a wall.
func _blink_away(foe: Wizard) -> void:
	var away := -signf(sight.seen_feet(foe).x - wizard.global_position.x)
	if away == 0.0:
		away = 1.0
	var room := (ArenaGen.right_edge() - wizard.global_position.x) if away > 0.0 else (wizard.global_position.x - ArenaGen.left_edge())
	if room < 120.0:
		away = -away  # cornered: go past the player instead
	var start: Vector2 = wizard.center()
	hand.begin_cast("Shadow Step", BrainStrokes.line(start, start + Vector2(away * 240.0, -12.0)), QUICK_DRAW)


# --- Footwork ---------------------------------------------------------------------------------------------------


func _footwork(delta: float, to_player: Vector2, sees: bool) -> float:
	if wizard.is_drawing():
		return 0.0
	var speed := WALK_SPEED
	if _escape_time > 0.0:
		return _escape_dir * speed * 1.3
	var gap := absf(to_player.x)
	var toward := signf(to_player.x)
	var dir := 0.0
	if _hiding():
		dir = -toward  # slipping away unseen
	elif not sees:
		dir = toward  # get a clear line
	elif gap < NEAR or (to_player.y < -CHASE_ABOVE and LIFT_CLOSE.has(_ready_lift()) and gap > LIFT_CLOSE[_ready_lift()] + 30.0):
		# A rival high on a ledge is not backed away from: it stands where its way up is cast from (under them for a rising column of air, right at the foot
		# of the ledge for a vine or an oak, which it must climb and cross within a few steps), and raises itself.
		var lift := _ready_lift()
		var high: bool = to_player.y < -CHASE_ABOVE and lift != ""
		if high and LIFT_CLOSE.has(lift):
			dir = toward if gap > LIFT_CLOSE[lift] + 30.0 else 0.0
		else:
			dir = 0.0 if high and gap > LIFT_STAND.get(lift, 120.0) else -toward  # a rival high on a ledge is not backed away from: it stands under them, and raises itself up
	elif gap > FAR:
		dir = toward
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = rng.randf_range(1.3, 3.2)  # (a person holds a direction, or stands, for a while: they do not change their mind every second)
			_strafe = [-1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0][rng.randi() % 7]  # (a recorded person stood still 47% of a fight and went each way about a quarter)
		dir = _strafe
	# Never back into the edge of the map; it would rather stand its ground there.
	var x: float = wizard.global_position.x
	if (dir < 0.0 and x < ArenaGen.left_edge() + 60.0) or (dir > 0.0 and x > ArenaGen.right_edge() - 60.0):
		dir = 0.0
	# Never walk into something burning.
	if dir != 0.0 and danger.in_danger(wizard.global_position + Vector2(dir * 34.0, -10.0)):
		dir = 0.0
	if wizard.is_on_floor() and _jump_cooldown <= 0.0:
		var blocked: bool = dir != 0.0 and wizard.is_on_wall()
		# Up onto a ledge you are standing on, whether or not it can see you, or when it is blocked.
		var above: bool = to_player.y < -50.0 and absf(to_player.x) < 260.0 and _ready_lift() == ""  # (with a way up to cast, it does not hop at the ledge)
		# Now and then, while it moves, it hops: a person does, but not every second.
		_hop_timer -= delta
		var hop: bool = dir != 0.0 and _hop_timer <= 0.0
		if hop:
			_hop_timer = rng.randf_range(2.0, 5.0)  # (a recorded person hops about every three seconds in a fight)
		if blocked or above or hop:
			wizard.request_jump()
			_jump_cooldown = 0.9
	return dir * speed


## The point just over the ground at a distance sideways: on a slope, the ground there is higher or lower than where it stands.
func _over_ground(dx: float) -> Vector2:
	var from := Vector2(wizard.global_position.x + dx, wizard.global_position.y - 140.0)
	var ground := SpellTargets.ground_below(wizard.get_world_2d(), from, 420.0)
	return Vector2(from.x, ground.y - 10.0)


## Which way is away from danger: the way to the nearest ground that is not burning or dangerous. It looks as far as a few hundred pixels,
## because a flow of lava down a slope is wider than a step.
func _safe_side() -> float:
	var volcano := danger.volcano_near(wizard.global_position, 900.0)  # lava from a volcano pours down its flanks: running up toward it is running into more of it
	if volcano != Vector2.INF and absf(wizard.global_position.x - volcano.x) > 40.0:
		return signf(wizard.global_position.x - volcano.x)
	var reach := [INF, INF]
	for k in 2:
		var dir := -1.0 if k == 0 else 1.0
		for step in range(30, 811, 30):
			var spot := _over_ground(dir * step)
			if not danger.in_danger(spot) and not danger.in_danger(spot + Vector2(0.0, 12.0)) and not danger.in_shoal(spot):
				reach[k] = float(step)
				break
	if reach[0] == reach[1]:
		if _escape_dir != 0.0:
			return _escape_dir
		return -signf(sight.seen_feet(_foe).x - wizard.global_position.x) if _foe != null else 1.0
	var best := -1.0 if reach[0] < reach[1] else 1.0
	if _escape_dir != 0.0 and reach[0 if _escape_dir < 0.0 else 1] <= reach[0 if best < 0.0 else 1] * 1.6 + 60.0:
		return _escape_dir  # the way it was already running is nearly as good: it does not turn back and forth in the flow
	return best


# --- Attacks ----------------------------------------------------------------------------------------------------


## Picks an attack for the situation and starts drawing it. Returns false if nothing is worth casting now.
func _attack(to_player: Vector2, sees: bool) -> bool:
	var foe: Wizard = _foe
	if absf(to_player.x) > ATTACK_RANGE:
		return false  # too far off to aim at you: it waits for you to come within reach
	var gap := absf(to_player.x)
	var still: bool = foe.velocity.length() < 30.0
	var stuck: bool = _held(foe)
	var grounded: bool = foe.stands()
	var closing: bool = signf(foe.velocity.x) == signf(-to_player.x) and absf(foe.velocity.x) > 60.0
	var aim_ok := absf(to_player.normalized().x) > 0.4  # a near-vertical stroke is a poor flick
	var scores := {
		"Ignite": (2.0 if gap > 140.0 else 0.8) if sees and aim_ok else 0.0,
		"Frostbolt": (0.4 if foe.is_slowed() else 1.6) if sees else 0.0,
		"Spark": 2.2 if still or stuck else 1.0,
		"Stonefall": 3.0 if stuck else (1.8 if still else 0.5),
		"Icicles": 2.0 if _ceiling_over(sight.seen_center(foe)) else 0.0,  # they hang from a ceiling, wherever there is one over you
		"Spore Puff": 1.6 if gap < 240.0 else 0.0,
		"Stalagmite": (2.0 if still or stuck else 1.0) if grounded and gap < 360.0 else 0.0,
		"Bramble": (1.4 if closing else 0.7) if grounded and gap > 100.0 else 0.0,
		"Flytrap": 1.3 if grounded and (still or stuck) else 0.0,  # a trap snaps shut on whoever stands in it
		"Sinkhole": 1.5 if grounded and (still or stuck) and gap < 340.0 else 0.0,
		"Hex": 1.4 if Hex.multiplier(wizard.get_tree(), foe) <= 1.0 else 0.0,
		"Vacuum": 1.5 if not foe.smothered and gap < 400.0 else 0.0,
		"Faint": 1.6 if not foe.fainted and gap < 400.0 else 0.0,
		"Fight or Flight": 0.6 if foe.rage_time <= 0.0 and foe.fear_time <= 0.0 else 0.0,
		"Silence": (1.8 if foe.is_drawing() else 0.6) if gap > Silence.RADIUS + 45.0 else 0.0,  # the ring is drawn round you, so well clear of it
		"Tide Surf": 1.0 if grounded and gap > 110.0 and gap < 320.0 else 0.0,
		"Thunderclap": 1.7 if gap < Thunderclap.RADIUS - 40.0 and foe.daze_time <= 0.0 else 0.0,
		"Tornado": (0.6 + pressure * 0.5) if gap < 260.0 else 0.2,
		"Ice Prison": 1.3 if gap < 360.0 and not stuck else 0.0,
		"Mudslide": 1.1 if grounded and not stuck else 0.0,
		"Black Hole": (0.4 + pressure * 0.4) if gap < 300.0 else 0.0,
		"Firewall": (1.6 if closing else 0.5) if gap < 280.0 and gap > 90.0 else 0.0,
		"Blizzard": 0.4 if grounded else 0.0,
		"Fire Breath": 1.8 if gap < 240.0 else 0.0,
		"Earthquake": 1.5 if grounded and gap < 300.0 and _own_walkers_near(300.0) < 2 else 0.0,
		"Barbs": 1.7 if sees and aim_ok and gap < 300.0 else 0.0,
		"Pebble": (1.3 if gap < 460.0 else 0.0) if aim_ok else 0.0,  # lobbed, so it needs no clear line
		"Hailstorm": 1.5 if gap < 420.0 and not _sheltered() else 0.0,
		"Thorn Whip": 1.3 if sees and aim_ok and gap > 110.0 and gap < 340.0 else 0.0,  # it drags you in
		"Insect Plague": 1.2 if gap < 480.0 else 0.0,
		"Flaming Sphere": 1.3 if grounded and aim_ok and gap > 120.0 and gap < 620.0 else 0.0,  # it rolls along the ground toward you
		"Mirage": 0.9 if gap > 250.0 and grounded and _real_page_near(500.0) and _mirages_set() < 2 else 0.0,  # a bait set among real pages, with the rival still some way off; nonsense at arm's length, or where no page lies
		"Raise Dead": 1.2 if gap < 560.0 and grounded and wizard.max_stamina > 120.0 and _own_raised() < 2 else 0.0,
		"Leech": 1.0 if sees and aim_ok and gap < Leech.REACH - 40.0 and Leech.held_by(wizard.get_tree(), wizard) == null else 0.0,
		"Eldritch Blast": 1.4 if sees and gap > 120.0 and gap < 560.0 else 0.0,  # slow, and it bends toward you
		"Hemorrhage": 1.2 if sees and gap < 420.0 else 0.0,
		"Supernova": 1.4 if gap < 560.0 and wizard.max_stamina > 140.0 and not _sheltered() else 0.0,  # a sun that hangs about: it likes a rival who stays near
		"Scythe": 2.0 if sees and gap < 110.0 else 0.0,  # only at arm's length
	}
	if _sheltered():
		# Under a platform: lightning from above cannot reach you.
		scores["Spark"] = 0.0
	if not sees:
		# Behind cover: only spells that come from above or along the ground reach you.
		for spell_name in ["Ignite", "Frostbolt", "Ice Prison", "Black Hole", "Firewall", "Fire Breath", "Barbs", "Thorn Whip", "Leech", "Eldritch Blast", "Hemorrhage", "Scythe"]:
			scores[spell_name] = 0.0
	for spell_name in scores.keys():
		if not _ready_to_cast(spell_name):
			scores[spell_name] = 0.0
		elif spell_name in _recent:
			scores[spell_name] *= 0.25  # it does not keep repeating itself
	var choice := _pick(scores)
	if choice == "":
		return false
	_recent.push_front(choice)
	if _recent.size() > 2:
		_recent.pop_back()
	hand.begin_cast(choice, hand.attack_stroke(choice), ATTACK_DRAW, true)
	return true


## True when something solid (a platform or the ground) is above you, so nothing from the sky can reach you.
func _sheltered() -> bool:
	var top: Vector2 = sight.seen_center(_foe) + Vector2(0, -50)
	# Cast from the sky down, the way lightning comes: a one-way platform only stops things from above.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -600), top)
	query.collision_mask = 1 | 16
	return not wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## The wizard it is dealing with: the nearest of the others it knows of.
func foe() -> Wizard:
	return _foe


## The pull of gravity on a stroke it draws now: the screen follows a wizard that falls, and drags the stroke with it.
func drag_gravity() -> float:
	return 0.0 if wizard.is_on_floor() else wizard.gravity


## Where you will be by the time a spell lands, judged with the wizard's skill: a skilled wizard leads you well.
func predict(seconds: float) -> Vector2:
	var foe: Wizard = _foe
	var lead: Vector2 = foe.velocity * seconds * skill
	lead.y = 0.0 if foe.stands() else lead.y * 0.5
	return sight.seen_center(foe) + lead


## A brain that has watched a mirage fade learns to see the waver of the next, and does not go for it.
func saw_a_mirage_fade() -> void:
	_wise_to_mirages = true


## True when a real page, one a wizard could take, lies within this distance of the wizard: the thing a mirage would pass for.
func _real_page_near(distance: float) -> bool:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup is Mirage and not pickup.is_queued_for_deletion() and pickup.global_position.distance_to(wizard.global_position) < distance 				and (not _sight_is_limited() or _seen_pages.has(pickup.get_instance_id())):
			return true
	return false


## How many mirages are out there at the moment (a brain does not scatter them all over the world).
func _mirages_set() -> int:
	var count := 0
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if pickup is Mirage:
			count += 1
	return count


## How many skeletons this wizard has raised that are still standing.
func _own_raised() -> int:
	var count := 0
	for mob: Mob in wizard.get_tree().get_nodes_in_group("mobs"):
		if mob.master == wizard and not mob.is_dead():
			count += 1
	return count


## How far it would fall from here before it met ground or a platform (a long way, when there is nothing under it).
func _drop_below() -> float:
	var from := wizard.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 2000.0), 1 | 16)
	query.exclude = [wizard.get_rid()]
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return 2000.0 if hit.is_empty() else from.distance_to(hit["position"])


## A long fall ahead: a Featherfall is drawn the moment it begins, while the view still keeps up with the stroke. Once the wizard is falling
## fast the screen drags the stroke out of shape, as it would a person's, and it is too late. Walking on as it drops would drag the stroke
## sideways too: it lets go of the keys, as a person does to draw on the way down, and draws as soon as the view keeps up.
func _catch_fall() -> void:
	if wizard.is_on_floor() or wizard.velocity.y <= 0.0 or wizard.feather_time > 0.0 or wizard.is_drawing() or chant.is_typing() or not _ready_to_cast("Featherfall"):
		return
	if _drop_below() <= LONG_FALL:
		return
	if not hand.drag_ok("Featherfall", QUICK_DRAW):
		hand.stand_still()
		return
	hand.begin_cast("Featherfall", hand.tend_stroke("Featherfall", Vector2.ZERO), QUICK_DRAW)


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
func _hiding() -> bool:
	return wizard.fade_time > 0.0 and wizard.max_stamina < Wizard.MAX_STAMINA * 0.45


## Whether a Vacuum of its own still holds someone: any other spell it cast would let them go.
func _smothering() -> bool:
	for vacuum: Vacuum in wizard.get_tree().get_nodes_in_group("vacuums"):
		if vacuum.caster == wizard:
			return true
	return false


## Whether the world is dark: a flare, a glowcap or a moonbeam would show it the way.
func _in_dark() -> bool:
	for node in wizard.get_tree().get_nodes_in_group("darkness"):
		if node is CanvasModulate and node.visible and node.color.get_luminance() < 0.5:
			return true
	return false


## Whether there is a ceiling over a point that an icicle could hang from.
func _ceiling_over(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0.0, -SpellSpawner.ICICLE_REACH))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["normal"].y > 0.3


## Whether it may cast a spell now: it holds the page, is not silenced, has not just cast it for itself, and has the strength (blood is paid
## in maximum stamina, and never to the last drop).
func _ready_to_cast(spell_name: String) -> bool:
	if not knows(spell_name) or _rest.has(spell_name) or wizard.silenced() or wizard.rage_time > 0.0 or SpellLimits.refusal(wizard, spell_name) != "":
		return false
	if _read_until.get(spell_name, 0.0) > clock:
		return false  # a page just read: it is still looking at the picture
	var spell: Spell = SpellData.SPELLS[spell_name]
	if spell.pays_max():
		return wizard.max_stamina > spell.cost + 40.0
	return wizard.stamina >= spell.cost


## Looks to what it needs, and casts for it: a way up to a rival over its head, a light in the dark, its strength, and something between it and a rival who
## is hurting it. True when it has begun a cast.
func _tend(to_player: Vector2, sees: bool, fighting: bool) -> bool:
	if fighting and _chase(to_player):
		return true
	var gap := absf(to_player.x)
	var low := wizard.max_stamina < Wizard.MAX_STAMINA * 0.45
	var tired := _resting or wizard.stamina < 35.0
	var weights := {}
	if _in_dark():
		weights["Flare"] = 1.5
		weights["Glowcap"] = 0.6 if tired or fighting else 0.0
		weights["Moonbeam"] = 0.8 if fighting else 0.0
	if (tired or (fighting and gap > FAR)) and wizard.adrenaline_time <= 0.0:
		weights["Adrenaline"] = 1.2
	if fighting and sees and gap < 260.0 and wizard.max_stamina > 90.0 and not wizard.wild:
		weights["Wild Shape"] = 1.1  # a rival close at hand: it comes at them with claws
	if goal != "page" and scent <= 0.0 and SpellTargets.wizards(wizard.get_tree()).size() > 1:
		weights["Hunter's Mark"] = 1.0
	if fighting:
		if low and gap > 140.0 and wizard.fade_time <= 0.0:
			weights["Sneak"] = 2.5
		if sees and pressure > 0.8 and gap > 110.0 and gap < 380.0:
			weights["Stone Wall"] = 1.4
		if pressure > 1.0 and gap > 150.0:
			weights["Smoke Screen"] = 1.0
		if pressure > 1.2:
			weights["Decoy"] = 1.0
		if pressure > 0.8 and wizard.veil == 0:
			weights["Crimson Veil"] = 1.3
		if pressure > 1.6 and wizard.obsidian_time <= 0.0:
			weights["Obsidian Armor"] = 0.8
		if sees and gap > 200.0:
			weights["Eclipse"] = 0.6 + 0.3 * pressure
	for spell_name in weights.keys():
		if not _ready_to_cast(spell_name):
			weights[spell_name] = 0.0
	var choice := _pick(weights)
	if choice == "":
		return false
	if not hand.begin_cast(choice, hand.tend_stroke(choice, to_player), QUICK_DRAW):
		return false
	_rest[choice] = TEND_REST[choice]
	return true


## The first of the spells that raise it up that it is ready to cast, or "".
func _ready_lift() -> String:
	for spell_name: String in LIFTS:
		if _ready_to_cast(spell_name):
			return spell_name
	return ""


## A rival standing over its head, on a ledge: it raises itself up to them with the first spell it holds that does it. True when it has begun.
func _chase(to_player: Vector2) -> bool:
	if not wizard.is_on_floor() or _rest.has("chase") or not moves.lift.is_empty():
		return false
	var rise := wizard.global_position.y - sight.seen_feet(_foe).y
	if rise < CHASE_ABOVE or absf(to_player.x) > 320.0:
		return false
	var dir := 1 if to_player.x >= 0.0 else -1
	var span := Rect2(sight.seen_feet(_foe).x - 24.0, sight.seen_feet(_foe).y - 6.0, 48.0, 12.0)
	for spell_name: String in LIFTS:
		if not _ready_to_cast(spell_name) or (spell_name == "Great Oak" and rise > OAK_CHASE_MAX):
			continue
		if LIFT_CLOSE.has(spell_name) and absf(to_player.x) > LIFT_CLOSE[spell_name] + 60.0:
			continue  # a vine, an oak or a column of air is raised only once it has walked up to the foot of the ledge
		_rest["chase"] = CHASE_REST
		if moves.begin_lift(spell_name, "chase", dir, span):
			return true
	return false


## Picks a key at random, weighted by its value. Returns "" when every weight is zero.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for key in weights:
		roll -= maxf(weights[key], 0.0)
		if roll <= 0.0 and weights[key] > 0.0:
			return key
	return ""


## How many of the wizard's own walkers stand within reach of the player: an earthquake would shake them too.
func _own_walkers_near(reach: float) -> int:
	var count := 0
	var target: Wizard = _foe
	for other in wizard.get_tree().get_nodes_in_group("mobs"):
		if other.is_dead():
			continue
		if other.center().distance_to(target.center()) < reach:
			count += 1
	return count
