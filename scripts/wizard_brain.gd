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
const REMEMBER := 8.0         # seconds a rival gone out of sight is still thought to be where it was last seen
const ENGAGE := 620.0         # a wizard this close, and in sight, is a fight; farther off, it is a journey
const PAGE_REACH := 4          # tiles: a page further than this from any place to stand is not one it can get
const GOAL_EVERY := 4.0       # seconds between looking for a nearer page
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
const DRIFT_FILE := "res://ai/stroke_drift.json"
const DRAG_MARGIN := 0.7  # it keeps well inside what a shape stands
const LONG_FALL := 300.0  # a drop this deep below its feet is a long fall, worth a Featherfall
const HOLD_STILL := 0.4   # seconds it stands still when a stroke would be dragged out of shape
const STOPPING := 0.35  # seconds to come to a stop before the first letter of a chant (a person stops walking, then types)
const TYPING_PER_LETTER := 0.25  # seconds a letter takes to type: 48 words a minute (the owner found 30 too slow), about what a person types words of a language that is not theirs
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
const SHOT_SPEED := 650.0     # roughly how fast its bolts fly, for leading a moving target
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
const LEAP_AIR_MAX := 4.0     # seconds in the air after which a leap is given up
const LEAP_DRAW := 0.15       # seconds to draw one: it falls the while
const SENTINEL_LOOKOUT := 40  # tiles of the way it looks ahead along for a sentinel
const COVER_RANGE := 780.0    # it draws its cover when it is this close to a sentinel, a little before the sentinel sees it (700)
const CLEAR_TRIES := 14       # casts at one gate before it gives up on it for a while
const STRIKE_REACH := {"Fire Breath": 5, "Ignite": 12, "Stonefall": 10, "Earthquake": 10, "Firewall": 8, "Gust": 7, "Tornado": 6, "Spark": 40, "Frostbolt": 12, "Faint": 8}  # tiles: how far off a spell strikes a gate
const LIFT_WAIT := 1.6         # seconds it stands on a Geyser it has drawn, waiting to be thrown, before it takes it for a miss
const SHOVE_WAIT := 1.0         # seconds it waits to be off the ground after shoving itself up, before it takes it for a miss
const VINE_SCALE := 2.4          # how much bigger than its picture it draws a vine, to grow it taller than a wall
const VINE_OVER := 70.0          # pixels over the top of the wall that it climbs before it lets go, to clear the edge when it drops
const VINE_WAIT := 8.0          # seconds it climbs before it takes the vine for a miss
const WADE_WAIT := 40.0          # seconds it spends in a pit before it takes the crossing for a miss
const BREATH_AHEAD := 60.0        # pixels short of a bank of gas that it stops to hold its breath
const EYE_SECONDS := 20.0         # how long what a brain sees through its Scrying Eye lasts
const GAS_WALK := 20.0            # seconds the way through gas is taken to be open after the chant (the breath is held for longer)
const LIFT_CLEARANCE := 40.0    # pixels it must be thrown above the top of a wall to get over it
const STRIKE_STAND := 4       # tiles: and it steps up to this far from it
const ICICLE_REACH := 420.0      # pixels over a rival that a ceiling can hang an icicle from (the arena's own reach)
const JUMP_REACH := 130.0       # pixels a jump carries it up: the highest ledge it will jump for
const TORNADO_WAIT := 2.5       # seconds it walks into a whirlwind it has drawn, waiting to be flung, before it takes it for a miss
const OAK_GROW := 1.1           # seconds it waits for a great oak to stand before it climbs
const OAK_WAIT := 9.0           # seconds it climbs an oak before it takes it for a miss
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
var _cast_cooldown := 1.8
var _react := 0.0             # counting down to a planned reaction
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
var _typing := ""                # the chant it is typing, and will say when _settle has run out
var _hold_still := 0.0
var _pending := {}                # a stroke it stopped to draw: drawn as soon as it stands still enough (see _draw_when_still)
static var _drift := {}
var _typing_age := 0.0           # seconds since the chant box was opened
var _said := {}                   # chant id -> whether it took, for a chant just typed and said, until whoever asked for it looks (see _type_then_say)
var _said_failed := {}            # chant id -> seconds before it is tried again, after it was typed and came to nothing
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
var _pressure := 0.0          # how many shots you have thrown at it lately
var _seen_shots := {}
var _recent: Array[String] = []  # its last two attacks, which it avoids repeating
var _rng := RandomNumberGenerator.new()
var _foe: Wizard                 # the wizard it is dealing with: the nearest of the others it knows of
var _lure: Decoy                 # a shadow it takes for a rival, and deals with as if it were them (see _notice_decoys)
var _shadows := {}                # decoy instance id -> true when it knows it for a shadow, false when it is fooled
var _known := {}                  # rival instance id -> {"wizard", "at" (feet when last seen), "age" (seconds since)} (see _look_about)
var _route := WizardRoute.new()
var _goal := ""                  # what it is travelling to: "page", "foe", or "" for nothing
var _goal_page: PagePickup
var _goal_portal: FieldPortal
var _page_steps := 0.0         # seconds it has spent walking the last steps to a page that lies just off the end of its way
var _portal_jumping := 0.0     # seconds it has stood under a portal in the air, jumping for it
var _last_feet := Vector2.INF
var _goal_timer := 0.0
var _skip := {}                  # a page (its instance id) or a gate (its name) -> seconds it stays off the list, for one that could not be had
var _wise_to_mirages := false      # it has watched a mirage fade, and now sees the waver of the rest
var stuck_at: Array[String] = []  # where it has been held up, for a report
var _goal_gate := {}              # the gate it is going to clear: {"kind", "outside", "target", "entry"}
var _gate_tries := 0
var _gate_gone := 0              # how many pieces of the gate had gone when it last struck it
var _nav_version := -1           # which build of the ways its list of pages it cannot reach belongs to
var _bridged := {}               # crossing (by key) -> seconds more that the way over it, which this wizard made, will last
var _cross_run := 0.0            # the speed it goes at while it makes its way over a crossing
var _pad_walk := {}              # crossing (by key) -> {"dir", "end"}: the row of pads laid over it, and the x it walks along them to
var _hurt_age := 99.0            # seconds since it was last hurt
var _chant_breaks := 0          # chants broken off lately: the more, the longer before it tries again, and the farther from the trouble
var _settle := 0.0               # seconds it stands still while a way over water grows
var _resting := false            # it has stopped to get its breath back
var _pads := {}                  # crossing (by key) -> {"dir", "front"}: the row of Lily Pads it has made so far over a long pit
var _wade := {}                  # a walk through the lava of a pit in black glass: {"dir", "key", "span": the pit, "stage", "waited"}
var _lift := {}                  # a throw up over a wall: {"dir", "key", "span": the wall, "drawn", "thrown", "waited"}
var _leap := {}                  # a jump over a chasm: {"dir": -1 or 1, "key", "steps": Shadow Steps left to make, "span": the chasm, "jumped", "air": seconds since it left the ground}
var _cannot := {}                # crossing (by key) -> seconds more that it will not try it, having fallen in
var _replans := 0                # times in a row it has had to find its way again
var _eye_time := 0.0              # seconds a Scrying Eye lasts for it: a wizard faded from sight can be found
var _scent := 0.0                # seconds that a Hunter's Mark lasts for it: a wizard faded from sight can be found
var _tend_cooldown := 3.0        # counting down to the next time it looks to its own needs
var _rest := {}                  # a spell (or "chase") -> seconds before it uses it for itself again


func _init(body: Wizard) -> void:
	wizard = body
	_rng.randomize()
	skill = GameSettings.rival_skill()


## A Hunter's Mark was cast: for a while it can find a wizard who has faded from sight.
func catch_scent(seconds: float) -> void:
	_scent = maxf(_scent, seconds)


## Called when the wizard takes damage. A real hit while it draws breaks its spell, and being badly hurt makes it
## want to get away.
func on_hurt(amount: int) -> void:
	_hurt_age = 0.0
	if wizard.is_drawing() and amount >= INTERRUPT_DAMAGE:
		wizard.interrupt_cast()
		_cast_cooldown = maxf(_cast_cooldown, 0.9)
	if _knows("Shadow Step") and wizard.max_stamina < Wizard.MAX_STAMINA * 0.4 and _defend_cooldown <= 0.0 and _react <= 0.0 and _rng.randf() < 0.5:
		_plan("blink_away", 0.25)


## The chant it is typing, as far as it has got, over its head: a person's words are seen as they are typed, and so are these.
func _show_words() -> void:
	if _typing == "" or not RitualInput.RITUALS.has(_typing):
		wizard.shown_words = ""
		return
	var text: String = RitualInput.RITUALS[_typing]["text"]
	var total := _typing_time(_typing)
	var done := 1.0 - clampf(_settle / maxf(total, 0.01), 0.0, 1.0)
	wizard.shown_words = text.substr(0, int(ceil(text.length() * done)))


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
	return not wizard.is_on_floor() or _hurt_age < 0.5 or (absf(wizard.velocity.x) > 40.0 and _typing_age > STOPPING) or wizard.is_drawing() or wizard.is_frozen() or _in_danger(wizard.center())


## Whether this is a place to stand and type: it stands on the ground and is not being hurt, no creature or rival is near enough to come at it, and
## nothing that burns, shoves or bites lies within a few paces. It looks at what is there, not at a clock.
func _quiet_here() -> bool:
	if not wizard.is_on_floor() or absf(wizard.velocity.x) > 30.0 or _hurt_age < 1.5:
		return false
	if _assailant() != null:
		return false
	if _foe != null and is_instance_valid(_foe) and not _foe.dead and _foe_feet().distance_to(wizard.global_position) < 450.0:
		return false
	for dx in [-200.0, -120.0, -60.0, 0.0, 60.0, 120.0, 200.0]:
		if _in_danger(wizard.center() + Vector2(dx, 0.0)) or _in_danger(wizard.global_position + Vector2(dx, -6.0)):
			return false
	return true


func think(delta: float) -> void:
	_hurt_age += delta
	_dash -= delta
	_hold_still -= delta
	_draw_when_still()
	_catch_fall()
	if _typing != "" and _typing_disturbed():  # it breaks off the chant, and will not try it here again for a while
		_typing = ""
		_settle = 0.0
		_chant_breaks = mini(_chant_breaks + 1, 4)
		_mend_wait = maxf(_mend_wait, 10.0 * _chant_breaks)
		_haste_wait = maxf(_haste_wait, 10.0 * _chant_breaks)
	_cast_cooldown -= delta
	_defend_cooldown -= delta
	_jump_cooldown -= delta
	_escape_time -= delta
	_goal_timer -= delta
	_settle -= delta
	_tend_cooldown -= delta
	_scent -= delta
	_eye_time -= delta
	for id in _said_failed.keys():
		_said_failed[id] -= delta
		if _said_failed[id] <= 0.0:
			_said_failed.erase(id)
	_note_sights(delta)
	_hurdle()
	_show_words()
	_pressure *= exp(-delta / 3.0)
	for spell_name in _rest.keys():
		_rest[spell_name] -= delta
		if _rest[spell_name] <= 0.0:
			_rest.erase(spell_name)
	for id in _skip.keys():
		_skip[id] -= delta
		if _skip[id] <= 0.0:
			_skip.erase(id)
	for key in _cannot.keys():
		_cannot[key] -= delta
		if _cannot[key] <= 0.0:
			_cannot.erase(key)
	for key in _bridged.keys():
		_bridged[key] -= delta
		if _bridged[key] <= 0.0:
			_bridged.erase(key)
			_pad_walk.erase(key)
	if wizard.nav != null and wizard.nav.version != _nav_version:
		_nav_version = wizard.nav.version
		_skip.clear()  # a gate has been cleared: pages that could not be reached may be reachable now
	_track_shots()
	_look_about(delta)
	_notice_decoys()
	_foe = _lure.caster if _lure != null else _nearest_foe()
	_strength_in -= delta
	if _strength_in <= 0.0:
		_strength_in = 1.0
		_strength = _feel_strength(_foe)
	if _typing != "":  # the chant box is open: it can only type, or close the box to do something else (see _while_typing)
		_while_typing()
		return
	if _foe == null and _eye_time <= 0.0 and SpellTargets.wizards(wizard.get_tree()).size() > 1 and wizard.ledger.knows_chant("scrying_eye"):
		_type_then_say("scrying_eye")  # it has lost track of everyone: it sends out an eye (see _while_typing)
	if _foe == null:  # the last wizard standing, or it knows of no one else (none in sight): it goes about its journey
		if _react > 0.0:  # (a reaction it has planned still comes: nothing else counts it down here)
			_react -= delta
			if _react <= 0.0:
				_act(_reaction)
		# It still looks after itself: a light in the dark, its strength, the scent of whoever it has lost.
		if _react <= 0.0 and _tend_cooldown <= 0.0 and not wizard.is_drawing() and _lift.is_empty() and _leap.is_empty() and _wade.is_empty() and not _smothering():
			_tend_cooldown = 0.6 + _rng.randf() * 0.6
			if _tend(Vector2.ZERO, false, false):
				_tend_cooldown = 1.4 + _rng.randf() * 0.8
		var mending := _mend(delta, false) if _lift.is_empty() and _leap.is_empty() and _wade.is_empty() else NAN
		if not is_nan(mending):
			wizard.walk(mending)
			return
		wizard.walk(_travel(delta) if SpellTargets.wizards(wizard.get_tree()).size() > 1 or wizard.get_tree().get_first_node_in_group(&"gate_source") != null else 0.0)  # (alone in a match it has won; alone in a room it goes on)
		return
	var foe: Wizard = _foe
	var in_view := wizard.eyes.sees_point(_lure.center()) if _lure != null else eyes_see(foe)
	var to_player: Vector2 = _seen_center(foe) - wizard.center()
	var sees := in_view and _clear_line(wizard.center(), _seen_center(foe))
	var fighting := sees and to_player.length() < ENGAGE

	_push_through -= delta
	_escape_commit -= delta
	_escapes = maxf(_escapes - delta * 0.5, 0.0)
	# Reactions.
	if _react > 0.0:
		_react -= delta
		if _react <= 0.0:
			_act(_reaction)
	elif not wizard.is_drawing():
		var shot := _incoming_shot()
		if not shot.is_empty() and _defend_cooldown <= 0.0:
			_threat_dir = shot["dir"]
			_plan(_choose_defence(shot["eta"]), _reaction_time())
		elif (_dash <= 0.0 and _scorched()) or _bitten() or (_push_through <= 0.0 and (_in_danger(wizard.global_position + Vector2(0, -6)) or _in_danger(wizard.center()))):
			_plan("escape", _reaction_time() * 0.6)
			_settle = 0.0  # nobody stands in the fire to finish a chant
			_typing = ""
			_camped = false
			_escapes += 1.0
			if _escapes > 3.0 and not _scorched() and not _bitten():  # it keeps backing out of the same thing that lies on its way: it goes through it this once
				_push_through = PUSH_THROUGH_FOR
				_escapes = 0.0
		elif _defend_cooldown <= 0.0 and not _watchers().is_empty():
			_plan("cover", _reaction_time())
		elif fighting and to_player.length() < TOO_CLOSE and _defend_cooldown <= 0.0:
			_plan(_choose_repel(), _reaction_time())

	# Looking after itself: its lights, its strength, a wall between it and you, a way up to you.
	if _react <= 0.0 and _tend_cooldown <= 0.0 and not wizard.is_drawing() and _lift.is_empty() and _leap.is_empty() and _wade.is_empty() and not _smothering():
		_tend_cooldown = 0.6 + _rng.randf() * 0.6
		if _tend(to_player, sees, fighting):
			_tend_cooldown = 1.4 + _rng.randf() * 0.8

	if wizard.wild and fighting:
		_wolf(to_player, sees)  # a werewolf has no spells: it runs at the rival and claws
		return

	# Footwork, or the journey.
	var run: float
	var mend := _mend(delta, fighting) if _lift.is_empty() and _leap.is_empty() and _wade.is_empty() and _react <= 0.0 else NAN
	if not is_nan(mend):
		wizard.walk(mend)
		return
	if not _lift.is_empty():
		run = _lifting(delta)  # a throw, a climb or a lift up to you goes on, fight or no
	else:
		var daunted := fighting and _strength < TIMID_BELOW and to_player.length() > TIMID_STAND
		_daunted = _daunted + delta if daunted else 0.0
		var standing_to_fight := fighting and (not daunted or _daunted < TIMID_HESITATE)  # (one that feels weak, after a moment, goes on with its journey and keeps away)
		run = _footwork(delta, to_player, sees) if standing_to_fight else _travel(delta)  # (both may jump: the speed is written after they have)
	wizard.walk(run)
	# A wizard faces the way it runs; it turns to its rival only while standing still or drawing a spell, so it never backpedals.
	var running := run != 0.0 and not wizard.is_drawing()
	wizard.facing = signf(run) if running else (signf(to_player.x) if fighting or wizard.is_drawing() else wizard.facing)
	if not fighting or (_strength < TIMID_BELOW and to_player.length() > TIMID_STAND and _daunted >= TIMID_HESITATE):
		return

	# Attacks.
	if _cast_cooldown <= 0.0 and not wizard.is_drawing() and _react <= 0.0:
		if _smothering() or _hiding():
			_cast_cooldown = 0.3  # another spell would let the breath go; and a wizard out of sight is shown by casting
		elif foe.has_shield():
			_cast_cooldown = 0.3  # nothing gets through a Barrier; wait it out
		elif _attack(to_player, sees):
			_cast_cooldown = lerpf(2.8, 1.5, skill) + _rng.randf() * 0.8
		else:
			_cast_cooldown = 0.4


## A werewolf's turn: straight at the rival, and a swipe once they are in reach.
func _wolf(to_player: Vector2, sees: bool) -> void:
	var near := absf(to_player.x) < Wizard.CLAW_REACH * 0.8
	wizard.walk(0.0 if near else signf(to_player.x) * Wizard.SPEED * Wizard.WILD_SPEED)
	wizard.facing = signf(to_player.x) if to_player.x != 0.0 else wizard.facing
	if sees and absf(to_player.x) < Wizard.CLAW_REACH and absf(to_player.y) < 60.0:
		wizard.claw()


func _reaction_time() -> float:
	return lerpf(0.4, 0.15, skill) + _rng.randf() * 0.12


func _plan(reaction: String, delay: float) -> void:
	_reaction = reaction
	_react = delay


# --- Travel -----------------------------------------------------------------------------------------------------


## Whether it holds the page of a spell.
func _knows(spell_name: String) -> bool:
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


## What it knows of the others, as a person knows it: where each was when it last saw them. A rival on its screen and in plain sight is seen
## where they are; one that goes out of sight is thought to be where it was last seen, and is forgotten after a while. A scent (Hunter's Mark) or
## an eye sent out (the Chant of the Scrying Eye) shows them wherever they are, as it would show a person.
func _look_about(delta: float) -> void:
	for other: Wizard in SpellTargets.wizards(wizard.get_tree()):
		if other == wizard:
			continue
		var id := other.get_instance_id()
		if (eyes_see(other) or _scent > 0.0 or _eye_time > 0.0) and not (_lure != null and _lure.caster == other):
			_known[id] = {"wizard": other, "at": other.global_position, "age": 0.0}
		elif _known.has(id):
			_known[id]["age"] += delta
	for id in _known.keys():
		var entry: Dictionary = _known[id]
		if entry["age"] > REMEMBER or not is_instance_valid(entry["wizard"]) or entry["wizard"].dead:
			_known.erase(id)


## Where it thinks its rival stands: where they are when it sees them, where it last saw them, or where the shadow it takes for them stands.
func _foe_feet() -> Vector2:
	if _foe == null or not is_instance_valid(_foe):
		return wizard.global_position
	return _seen_feet(_foe)


## Where a rival looks to be standing, to it (see _foe_feet).
func _seen_feet(other: Wizard) -> Vector2:
	if other == null or not is_instance_valid(other):
		return wizard.global_position
	if other == _foe and _lure != null and is_instance_valid(_lure) and not _lure.is_dead():
		return _lure.global_position
	var entry: Dictionary = _known.get(other.get_instance_id(), {})
	return entry["at"] if entry.get("age", 0.0) > 0.0 else other.global_position


## The middle of a rival's body, where it thinks they stand.
func _seen_center(other: Wizard) -> Vector2:
	return _seen_feet(other) + other.center_offset()


## A Decoy looks like any wizard to everyone but its caster. It takes one for its caster unless it saw it come out of nothing, or it is its own;
## the nearest figure it sees, real or shadow, is the one it deals with. A shadow that wears through is known for what it was.
func _notice_decoys() -> void:
	if _lure != null and (not is_instance_valid(_lure) or _lure.is_dead()):
		_lure = null
	var nearest_gap := INF
	for id in _known:
		if _known[id]["age"] <= 0.0:
			nearest_gap = minf(nearest_gap, wizard.global_position.distance_to(_known[id]["at"]))
	var best: Decoy = null
	for node in wizard.get_tree().get_nodes_in_group("decoys"):
		var decoy := node as Decoy
		if decoy.is_dead() or decoy.caster == null or not is_instance_valid(decoy.caster) or decoy.caster == wizard:
			continue
		var id := decoy.get_instance_id()
		var seen := wizard.eyes.sees_point(decoy.center())
		if seen and not _shadows.has(id):
			_shadows[id] = decoy.age() < 0.4  # it watched it come: it knows it for a shadow
		if not seen or _shadows.get(id, true):
			continue
		var gap := wizard.global_position.distance_to(decoy.global_position)
		if gap < nearest_gap:
			nearest_gap = gap
			best = decoy
	_lure = best
	if _lure != null:
		_known[_lure.caster.get_instance_id()] = {"wizard": _lure.caster, "at": _lure.global_position, "age": 0.0}
	if _shadows.size() > 64:
		_shadows.clear()


## The nearest of the other wizards it knows of (sees, or saw a little while ago), or null when it knows of none.
func _nearest_foe() -> Wizard:
	var best: Wizard = null
	var best_gap := INF
	for id in _known:
		var entry: Dictionary = _known[id]
		var gap: float = wizard.global_position.distance_to(entry["at"])
		if gap < best_gap:
			best = entry["wizard"]
			best_gap = gap
	return best


## Whether a wizard cannot move freely: rooted, or slowed.
func _held(foe: Wizard) -> bool:
	return foe.is_rooted() or foe.is_slowed()


## What tells it of the gates about it: a match's world, or a room that has read itself (see RoomScan).
func _world() -> Node:
	var tree := wizard.get_tree()
	var found := tree.get_first_node_in_group(&"world")
	return found if found != null else tree.get_first_node_in_group(&"gate_source")


## The tile a body stands in, from its feet.
func _tile_of(feet: Vector2) -> Vector2i:
	return Vector2i(floori(feet.x / WizardRoute.TILE), floori((feet.y - 1.0) / WizardRoute.TILE))


## Wounds: a wizard worn down to a small maximum, with no one at its heels, lights a bonfire (or goes to one that burns) and rests by it until it has
## mended, as a person does. Returns the speed to walk at, or NAN when it is not mending.
func _mend(delta: float, fighting: bool) -> float:
	_mend_wait -= delta
	if (_typing != "" or _camped or _settle > 0.0) and (_assailant() != null or _scorched() or _bitten()):  # it does not sit and chant with a blade or a flame on it
		_typing = ""
		_settle = 0.0
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
	if _knows("chant:bonfire"):
		if not _quiet_here():  # not here: it goes on a while, and tries again
			_mend_wait = 5.0
			return NAN
		_open_chant("bonfire")
		return 0.0
	_mend_wait = 30.0
	return NAN


## How long a person takes to type a chant: it stands where it is while it does.
func _typing_time(id: String) -> float:
	return float(RitualInput.RITUALS[id]["text"].length()) * TYPING_PER_LETTER


## True while the chant box is open and it is typing.
func is_typing() -> bool:
	return _typing != ""


## The chant box open: the wizard stands and types. A person with the box open cannot walk, jump or draw (the keys type letters), so it does
## none of them; when something comes at it, it closes the box, as a person would, and the words are lost. When the last letter is typed the chant
## is said.
func _while_typing() -> void:
	wizard.walk(0.0)
	_typing_age += wizard.get_physics_process_delta_time()
	var shot := _incoming_shot()
	var threatened := not shot.is_empty() or (_foe != null and is_instance_valid(_foe) and eyes_see(_foe) and _foe.center().distance_to(wizard.center()) < TOO_CLOSE)
	if threatened:
		_break_typing()
		return
	if _settle > 0.0:
		return
	var said := _typing
	_typing = ""
	_chant_breaks = 0
	var done := wizard.chant(said)
	_said[said] = done
	if done and said == "bonfire":
		_camped = true
		_camped_for = 0.0
	if done and said == "scrying_eye":
		_eye_time = EYE_SECONDS  # (the eye shows the others at once, so whoever asked for it may not ask again)
		_said.erase(said)


## True when it can make out another wizard: on its screen, in plain sight, not faded from sight.
func eyes_see(other: Wizard) -> bool:
	return wizard.eyes.sees_wizard(other)


## It closes the chant box before the words are done.
func _break_typing() -> void:
	_typing = ""
	_settle = 0.0


## A chant asked for where it is needed (a gate, a lost rival): it types it first. True once it has been said; false while it is being typed, or
## when the last try at it came to nothing.
func _type_then_say(id: String) -> bool:
	if _said.has(id):
		var done: bool = _said[id]
		_said.erase(id)
		if not done:
			_said_failed[id] = 3.0
		return done
	if _said_failed.get(id, 0.0) > 0.0 or not RitualInput.RITUALS.has(id):
		return false
	if _typing == "" and wizard.is_on_floor() and not wizard.is_drawing():
		_open_chant(id)
	return false


## It opens the chant box: it stops, and types the words.
func _open_chant(id: String) -> void:
	_typing = id
	_typing_age = 0.0
	_settle = _typing_time(id) + STOPPING


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
	if wizard.global_position.distance_to(_anchor) > STUCK_RADIUS or _resting or _goal == "":
		_anchor = wizard.global_position
		_anchored_for = 0.0
		return
	_anchored_for += delta
	if _anchored_for < STUCK_FOR:
		return
	_anchored_for = 0.0
	_unsticks += 1
	if _goal == "page" and is_instance_valid(_goal_page):
		_skip[_goal_page.get_instance_id()] = GIVE_UP
	elif _goal == "portal" and is_instance_valid(_goal_portal):
		_skip[_goal_portal.get_instance_id()] = GIVE_UP
	elif _goal == "gate":
		_skip[_gate_key(_goal_gate)] = GIVE_UP
	_goal = ""
	_goal_timer = 0.0
	_route.clear()
	if _unsticks >= 2:
		_unsticks = 0
		_wander_dir = -1.0 if _rng.randf() < 0.5 else 1.0
		_wander_time = _rng.randf_range(1.5, 3.0)
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
	_settle = 0.0  # no one stands typing with a blade at their back
	_typing = ""
	_camped = false
	_resting = false
	var away := signf(wizard.global_position.x - mob.global_position.x)
	if away == 0.0:
		away = -wizard.facing
	var spell_name := _clearing_spell("giant" if mob.max_hp >= 1000 else "creature")
	if spell_name != "" and not wizard.is_drawing() and _cast_cooldown <= 0.0 and _react <= 0.0:
		_goal_gate = {"kind": "giant" if mob.max_hp >= 1000 else "creature", "entry": {"mob": mob, "nodes": [mob]}, "target": mob.center()}
		_cast_cooldown = 1.4
		_begin_cast(spell_name, _gate_stroke(spell_name, mob.center()), ATTACK_DRAW)
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
	if not _leap.is_empty():
		return _leaping(delta)
	if not _wade.is_empty():
		return _wading(delta)
	if not _lift.is_empty():
		return _lifting(delta)
	var assailed := _assailed(delta)
	if not is_nan(assailed):
		return assailed
	if _settle > 0.0:
		return 0.0
	if wizard.is_drawing():
		return 0.0
	_watch_progress(delta)
	if _goal != "" and _route.remaining() > HASTE_FROM and wizard.haste_time <= 0.0 and _haste_wait <= 0.0 and _knows("chant:haste") and _quiet_here():
		_haste_wait = 25.0
		_open_chant("haste")  # (it stops to say it, as a person does)
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
	if _walking_pads():
		return _cross_run
	if _resting and wizard.stamina >= minf(REST_UNTIL, wizard.max_stamina * 0.9):  # (a wizard worn down to a small maximum rests up to that, not up to more than it can ever hold)
		_resting = false
	elif not _resting and wizard.stamina < minf(REST_BELOW, wizard.max_stamina * 0.3) and wizard.is_on_floor():
		_resting = true
	if _resting:
		return 0.0
	if wizard.nav == null:
		return 0.0
	_read_page_underfoot()
	if _last_feet.distance_to(wizard.global_position) > 250.0 and _last_feet != Vector2.INF:  # a portal has carried it off: the way it was going is no use
		_goal = ""
		_goal_timer = 0.0
	_last_feet = wizard.global_position
	if _goal == "portal" and _route.done():
		if is_instance_valid(_goal_portal) and _goal_portal.lift > 0.0 and _portal_jumping < PORTAL_JUMP_FOR and not _goal_lost():
			return _jump_for_portal(delta)  # it stands under a portal hung in the air and leaps for it
		_skip[_goal_portal.get_instance_id()] = GIVE_UP  # it has come to the portal and nothing came of it
		_goal = ""
		_goal_timer = 0.0
	if _goal == "page" and _route.done() and not _goal_lost() and is_instance_valid(_goal_page):
		var short: Vector2 = _goal_page.global_position - wizard.global_position
		if absf(short.x) > PAGE_TOUCH and absf(short.x) < PAGE_STEPS and absf(short.y) < PAGE_STEPS and _page_steps < PAGE_STEPS_TIME:
			_page_steps += delta  # the way ends a little short of it (the ground it lies on is not on the map): the last steps are walked
			return signf(short.x) * WALK_SPEED
	if _goal == "page" and _route.done() and not _goal_lost():  # it has come to the place, and the page is not to be had from there
		_skip[_goal_page.get_instance_id()] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
	if _goal == "gate":
		if _gate_open(_goal_gate["entry"]):
			_goal = ""
			_goal_timer = 0.0
		elif _route.done():
			_work_gate()
			return 0.0
	var creature := _creature_ahead()
	if not creature.is_empty():
		_goal_gate = creature
		_goal = "gate"
		_gate_tries = 0
		_clear_gate(creature["target"])
		return 0.0
	if (_goal == "" and _goal_timer <= 0.0) or _goal_lost() or ((_goal == "foe" or _goal == "exit" or _goal == "explore") and (_goal_timer <= 0.0 or _route.done())):
		_choose_goal()
	if _goal != "" and not _route.done() and wizard.is_on_floor():  # (a wizard in the air cannot stop for it; after the goal is chosen, so that a gate on the way is seen before the first step towards it)
		var crossing := _crossing_ahead()
		_cross_run = 0.0
		if not crossing.is_empty() and _cross(crossing):
			return _cross_run
	# Standing on a wooden platform or a ridge that the map does not know, high over the ground it does know: it steps down through it.
	_off_map_check -= delta
	if _off_map_check <= 0.0 and wizard.is_on_floor():
		_off_map_check = 0.4
		var here := _tile_of(wizard.global_position)
		var known: Vector2i = wizard.nav.nearest(here, true)
		_off_map = known != WorldNav.NONE and known.y - here.y >= 3 and absi(known.x - here.x) <= 6
	if _off_map and wizard.is_on_floor():
		wizard.drop_through()
	var volcano := _volcano_near(wizard.global_position, VOLCANO_FLEE) if _lift.is_empty() and _leap.is_empty() and _wade.is_empty() else Vector2.INF
	if volcano != Vector2.INF and not wizard.lava_proof() and wizard.is_on_floor():
		_goal = ""  # a volcano is awake close by: it goes away from it, and chooses what to do when it is far enough off
		_goal_timer = 0.5
		return signf(wizard.global_position.x - volcano.x) * WALK_SPEED
	var steer := _steer(delta)
	if steer["replan"]:
		stuck_at.append("%s %s" % [str(_tile_of(wizard.global_position)), _route.status()])
		_stuck_on_goal()
	if _route.waiting_for_stair and _goal == "explore":
		_stair_wait += delta
		if _stair_wait > STAIR_PATIENCE:  # a person does not stand at a stair for half a minute just to see what lies past it: they look elsewhere
			_stair_wait = 0.0
			var far := _route.last()
			if far != WorldNav.NONE:  # the place it was going to is given up (a floor above or below as well as one along)
				_explored[_square_of(Vector2(far.x * WizardRoute.TILE, far.y * WizardRoute.TILE))] = true
			for k in range(0, 3):
				_explored[_square_of(wizard.global_position + Vector2(signf(_explore_dir) * k * 600.0, 0.0))] = true
			_explore_dir = -_explore_dir
			_goal = ""
			_goal_timer = 0.0
			_route.clear()
	else:
		_stair_wait = 0.0
	var ahead := signf(steer["dir"])
	if ahead != 0.0 and wizard.is_on_floor() and _dash <= 0.0 and not _lethal_at(wizard.global_position + Vector2(0, -6)):
		var near := _lethal_at(_over_ground(ahead * 40.0)) or _lethal_at(_over_ground(ahead * 72.0))
		if near or _lethal_at(_over_ground(ahead * 110.0)):
			# lava or an eruption lies on the way: it keeps its distance, backing away if it is close, and waits for it to pass or cool; when that takes
			# too long it looks for another way
			_danger_wait += delta
			_route.wait()
			if _danger_wait > DASH_AFTER and wizard.max_stamina >= DASH_MIN_MAX and _lethal_stretch(ahead) <= DASH_MAX:  # a narrow stretch is not worth a wait: a person runs over it and takes the hit
				_dash = 1.6
				_danger_wait = 0.0
				return steer["dir"] * WALK_SPEED
			if _danger_wait > DANGER_WAIT_MAX:
				_danger_wait = 0.0
				if _goal == "page" and is_instance_valid(_goal_page):
					_skip[_goal_page.get_instance_id()] = GIVE_UP
				elif _goal == "explore":  # it will not look that way again: it turns round and tries the other side
					for k in range(0, 7):
						_explored[_square_of(wizard.global_position + Vector2(ahead * k * 600.0, 0.0))] = true
					_explore_dir = -ahead
				_goal = ""
				_goal_timer = 0.0
				_route.clear()
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


## The width in pixels of the lava (or other danger) that starts within reach ahead, or INF when it is wider than it is worth, or no ground lies past it.
func _lethal_stretch(ahead: float) -> float:
	var start := -1.0
	var d := 16.0
	while d <= 480.0:
		var bad := _lethal_at(_over_ground(ahead * d))
		if bad and start < 0.0:
			start = d
		elif not bad and start >= 0.0:
			var landing := _over_ground(ahead * (d + 32.0))
			return d - start if not _lethal_at(landing) and absf(landing.y - wizard.global_position.y) < 120.0 else INF
		d += 16.0
	return INF


## What the legs do along the route this frame: {"dir", "speed", "jump", "drop", "climb", "let_go", "replan"}. Here, what the route says; a wizard whose footwork is learned
## (LearnedBrain) decides for itself.
func _steer(delta: float) -> Dictionary:
	return _route.steer(wizard, delta)


## The crossing the way goes over soon, if the way over it is not made: {"kind", "key", "span", "post"}. A pit counts when it is the next few tiles
## off, a sentinel from much farther, for it sees a long way.
func _crossing_ahead() -> Dictionary:
	var world := _world()
	for moves in SENTINEL_LOOKOUT:
		var key := _toll_between(_route.ahead(moves - 1) if moves > 0 else wizard.nav.nearest(_tile_of(wizard.global_position), true), _route.ahead(moves))
		if key == "" or _bridged.has(key):
			continue
		for crossing: Dictionary in world.crossings():
			if crossing["key"] == key and (moves < 4 or crossing["kind"] == "sentinel"):
				return crossing
	return {}


## While it is on a row of pads it has laid over water, it walks along them to the end of the row rather than hopping from one to the next (a hop
## that lands a little short drops it in). True when it is walking them (or standing at the end of the row), with the speed in `_cross_run`.
func _walking_pads() -> bool:
	if _pad_walk.is_empty() or not wizard.is_on_floor():
		return false
	var world := _world()
	for crossing: Dictionary in world.crossings():
		if not _pad_walk.has(crossing["key"]):
			continue
		var span: Rect2 = crossing["span"]
		var dir: int = _pad_walk[crossing["key"]]["dir"]
		var end: float = _pad_walk[crossing["key"]]["end"]
		var x := wizard.global_position.x
		if x < span.position.x - WizardRoute.TILE or x > span.end.x + WizardRoute.TILE or (end - x) * dir < -WizardRoute.TILE:
			continue  # not on this row
		_cross_run = dir * WALK_SPEED if (end - x) * dir > 8.0 else 0.0
		return true
	return false


## The crossing whose toll lies on a move from one tile to the next, or "": a long jump over a pit passes over tiles that the path never names.
func _toll_between(from: Vector2i, to: Vector2i) -> String:
	if to == WorldNav.NONE:
		return ""
	for step in range(1, absi(to.x - from.x) + 1):
		var key: String = wizard.nav.toll_at(Vector2i(from.x + step * signi(to.x - from.x), to.y if step == absi(to.x - from.x) else from.y))
		if key != "":
			return key
	return wizard.nav.toll_at(to)


## Makes the way over a crossing, a stroke at a time. True while it is at it and must stand; false when it may walk on (a sentinel too
## far off to see it yet, or nothing it can do).
func _cross(crossing: Dictionary) -> bool:
	if wizard.is_drawing() or _react > 0.0:
		return true
	var kind: String = crossing["kind"]
	if kind == "sentinel":
		if wizard.center().distance_to(crossing["post"].center()) > COVER_RANGE:
			return false
		var used := _cover(crossing["post"], int(crossing.get("posts", 1)) > 1)
		if used == "":
			return false
		_bridged[crossing["key"]] = LASTS[used]
		return true
	var spell_name := _way_over(crossing)
	if spell_name == "":
		return false
	var span: Rect2 = crossing["span"]
	var dir := 1 if span.get_center().x > wizard.global_position.x else -1
	if _pads.has(crossing["key"]):
		dir = _pads[crossing["key"]]["dir"]  # a row of pads is laid along the way it set out
	_cross_run = 0.0
	match spell_name:
		"Geyser", "Rocket Jump", "Push", "Liana", "Updraft", "Great Oak", "Tornado":  # it walks up to the face of the wall and stands there while the ground bubbles under it, while it shoves itself up, while it climbs a vine, a column of air or an oak, or while a whirlwind flings it
			var face := span.position.x - 36.0 if dir > 0 else span.end.x + 36.0
			if absf(face - wizard.global_position.x) > 12.0:
				_cross_run = clampf(face - wizard.global_position.x, -WALK_SPEED, WALK_SPEED)
			elif wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost and not _begin_lift(spell_name, crossing["key"], dir, span):
				return false
		"Obsidian Armor":  # it puts on black glass at the edge, wades through the lava, and gets up the far side by a lift
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor() and wizard.stamina >= SpellData.SPELLS[spell_name].cost + SpellData.SPELLS[_way_up()].cost:
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), QUICK_DRAW)
				_wade = {"dir": dir, "key": crossing["key"], "span": span, "stage": 0, "waited": 0.0}
		"chant:deep_breath":  # it walks to the edge of the gas, holds its breath, and walks through
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > BREATH_AHEAD:
				_cross_run = dir * WALK_SPEED
			elif wizard.deep_breath_time > 0.0 or _type_then_say(spell_name.substr(6)):
				_bridged[crossing["key"]] = minf(wizard.deep_breath_time, GAS_WALK) if wizard.deep_breath_time > 0.0 else GAS_WALK
				_settle = SETTLE
			elif _typing != "":
				pass  # it is typing the words, standing at the edge
			else:
				_cannot[crossing["key"]] = GIVE_UP
				return false
		"Shadow Step":  # it walks to the edge, waits there until it is on the ground with strength to spare, and leaps
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor() and wizard.stamina >= 2.0 * SpellData.SPELLS[spell_name].cost:
				var steps := clampi(ceili((span.size.x - 200.0) / 300.0), LEAP_STEPS, 5)
				_leap = {"dir": dir, "key": crossing["key"], "steps": steps, "span": span, "jumped": false, "air": 0.0}
		"chant:double_jump":  # it walks to the edge, says the chant, and jumps, and jumps again at the top
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor() and (wizard.air_jump_time > 0.0 or _type_then_say("double_jump")):
				_leap = {"dir": dir, "key": crossing["key"], "steps": 0, "span": span, "jumped": false, "air": 0.0, "double": true}
		"leap:air":  # it jumps from the edge, and in the air a rocket throws it up and a feather lets it drift down, across
			var edge := span.position.x if dir > 0 else span.end.x
			if (edge - wizard.global_position.x) * dir > 20.0:
				_cross_run = dir * WALK_SPEED
			elif wizard.is_on_floor():
				var air: Array[String] = []
				for helper: String in ["Rocket Jump", "Featherfall"]:
					if _knows(helper):
						air.append(helper)
				var cost := 0.0
				for helper in air:
					cost += SpellData.SPELLS[helper].cost
				if wizard.stamina >= cost:
					_leap = {"dir": dir, "key": crossing["key"], "steps": 0, "span": span, "jumped": false, "air": 0.0, "helpers": air}
		"Lily Pads":  # a row at a time, as far as it reaches, and the next when it has come to the end of that
			if wizard.stamina >= SpellData.SPELLS[spell_name].cost:
				var reach := span.grow_individual(WizardRoute.TILE, 0.0, WizardRoute.TILE, 0.0)  # pads run a tile onto the bank at each end
				var near := reach.position.x if dir > 0 else reach.end.x
				var front: float = _pads[crossing["key"]]["front"] if _pads.has(crossing["key"]) else near
				var from_x := maxf(front, wizard.global_position.x) if dir > 0 else minf(front, wizard.global_position.x)
				var to_x := clampf(from_x + dir * PADS_REACH, reach.position.x, reach.end.x)
				var row := Rect2(minf(from_x, to_x), span.position.y, absf(to_x - from_x), span.size.y)
				_begin_cast(spell_name, _bridge_stroke(spell_name, row), ATTACK_DRAW)
				_settle = SETTLE
				var over := (to_x - (reach.end.x if dir > 0 else reach.position.x)) * dir >= 0.0
				_pads[crossing["key"]] = {"dir": dir, "front": to_x}
				_pad_walk[crossing["key"]] = {"dir": dir, "end": to_x}
				_bridged[crossing["key"]] = LASTS[spell_name] if over else SETTLE + absf(to_x - from_x) / WALK_SPEED - 0.8  # the next row goes down when it is near the end of this one
				if over:
					_pads.erase(crossing["key"])
		_:  # a bridge across the whole of it
			if wizard.stamina >= SpellData.SPELLS[spell_name].cost:
				_begin_cast(spell_name, _bridge_stroke(spell_name, span), ATTACK_DRAW)
				_settle = SETTLE
				_bridged[crossing["key"]] = LASTS[spell_name]
	return true


## Starts a lift up a wall from where it stands (see _lifting). False, and the wall is given up for a while, when rock overhead would stop it short.
func _begin_lift(spell_name: String, key: String, dir: int, span: Rect2) -> bool:
	var needed := wizard.global_position.y - (span.position.y - LIFT_CLEARANCE)
	if wizard.test_move(wizard.global_transform, Vector2(0.0, -needed)):  # rock overhead stops the water short of the top
		_cannot[key] = GIVE_UP
		return false
	_lift = {"spell": spell_name, "dir": dir, "key": key, "span": span, "drawn": false, "thrown": false, "waited": 0.0}
	return true


## A walk through the lava of a pit in black glass: it waits for the glass, wades to the foot of the far side, and is lifted out of the pit
## as it would be over a wall. Returns the speed to go at.
func _wading(delta: float) -> float:
	var span: Rect2 = _wade["span"]
	var dir: int = _wade["dir"]
	_wade["waited"] += delta
	if wizard.is_drawing():
		return 0.0
	if _wade["waited"] > WADE_WAIT or (_wade["stage"] == 0 and _wade["waited"] > 3.0 and wizard.obsidian_time <= 0.0):
		_cannot[_wade["key"]] = GIVE_UP
		_wade = {}
		return 0.0
	if _wade["stage"] == 0:
		if wizard.obsidian_time > 0.0:
			_wade["stage"] = 1
		return 0.0
	var foot := (span.end.x if dir > 0 else span.position.x) - dir * 36.0
	if (foot - wizard.global_position.x) * dir > 12.0 or not wizard.is_on_floor():
		return clampf((foot - wizard.global_position.x) * 4.0, -WALK_SPEED, WALK_SPEED)
	var floor_y := span.position.y - WizardRoute.TILE * 2.0  # the pit's lava lies two rows under the floor it was dug into
	var side := Rect2(Vector2(span.end.x if dir > 0 else span.position.x - 96.0, floor_y), Vector2(96.0, span.end.y - floor_y))
	var key: String = _wade["key"]
	_wade = {}
	_begin_lift(_way_up(), key, dir, side)
	return 0.0


## A jump over a pit: it leaps from the edge, and in the air carries itself on with Shadow Steps until it is across. Returns the speed to go at.
func _leaping(delta: float) -> float:
	var span: Rect2 = _leap["span"]
	var dir: int = _leap["dir"]
	if wizard.is_on_floor():
		if _leap["jumped"]:  # down again: over, or in the pit
			var across: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5
			if not across:
				_cannot[_leap["key"]] = GIVE_UP
			_bridged[_leap["key"]] = 2.0
			_leap = {}
			_goal = ""
			_goal_timer = 0.0
			return 0.0
		_leap["jumped"] = true
		wizard.request_jump()
		return dir * WizardRoute.MAX_AIR_SPEED
	_leap["air"] += delta
	var helpers: Array = _leap.get("helpers", [])
	if not helpers.is_empty() and not wizard.is_drawing():
		if helpers[0] == "Rocket Jump" and wizard.velocity.y < -40.0 and _leap["air"] > 0.12:
			helpers.pop_front()
			_begin_cast("Rocket Jump", _offset(GestureTemplates.preview_points("rocket"), wizard.center(), 0.6), LEAP_DRAW)
		elif helpers[0] == "Featherfall" and wizard.velocity.y > -20.0:
			helpers.pop_front()
			_begin_cast("Featherfall", _tend_stroke("Featherfall", Vector2.ZERO), LEAP_DRAW)
		elif helpers[0] == "Rocket Jump" and wizard.velocity.y > -20.0 and _leap["air"] > 0.5:
			helpers.pop_front()  # (it missed the moment)
	if _leap.get("double", false) and wizard.air_jump_ready and wizard.velocity.y > -20.0:
		wizard.request_jump()  # the second jump, at the top of the first
		_leap["double"] = false
	if _leap["air"] > LEAP_AIR_MAX:  # held against a rock face: it lets go of the jump and falls
		_cannot[_leap["key"]] = GIVE_UP
		_leap = {}
		return 0.0
	var beyond: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5 - 40.0
	if _leap["steps"] > 0 and not wizard.is_drawing() and not beyond and (wizard.velocity.y > -40.0 or _leap["steps"] < LEAP_STEPS):
		_leap["steps"] -= 1
		var start: Vector2 = wizard.center()
		_begin_cast("Shadow Step", _line(start, start + Vector2(dir * SpellData.STEP_MAX, -10.0).normalized() * SpellData.STEP_MAX), LEAP_DRAW)
	return dir * WizardRoute.MAX_AIR_SPEED


## A throw over a wall: it draws a Geyser under its feet and stands while the ground bubbles, and once the water has thrown it up it goes
## on across, over the top. Returns the speed to go at.
func _lifting(delta: float) -> float:
	pass
	var span: Rect2 = _lift["span"]
	var dir: int = _lift["dir"]
	if not _lift["drawn"]:
		if wizard.is_drawing():
			return 0.0
		_lift["drawn"] = true
		var feet: Vector2 = wizard.center()
		if _lift["spell"] == "Push":
			_begin_cast("Push", _push_stroke(feet, Vector2(dir * 0.2, -1.0).normalized()), QUICK_DRAW)
		elif _lift["spell"] == "Liana":  # a vine from the ground at its feet, taller than the wall
			_begin_cast("Liana", _offset(GestureTemplates.preview_points("vine"), Vector2(feet.x + 50.0 * VINE_SCALE, wizard.global_position.y - 75.0 * VINE_SCALE), VINE_SCALE), QUICK_DRAW)
		elif _lift["spell"] == "Rocket Jump":  # an arrow up drawn at its feet: the flame throws it high
			_begin_cast("Rocket Jump", _offset(GestureTemplates.preview_points("rocket"), feet, 0.6), QUICK_DRAW)
		elif _lift["spell"] == "Updraft":  # a column of air where it stands
			_begin_cast("Updraft", _offset(GestureTemplates.preview_points("updraft"), feet, 0.6), QUICK_DRAW)
		elif _lift["spell"] == "Tornado":  # a whirlwind a step ahead of it, to walk into
			_begin_cast("Tornado", _offset(GestureTemplates.preview_points("tornado"), Vector2(feet.x + dir * 60.0, wizard.global_position.y - 90.0), 0.9), ATTACK_DRAW)
		elif _lift["spell"] == "Great Oak":  # a trunk drawn up from the ground a step ahead of it
			var shape := GestureTemplates.preview_points("tree")
			var foot := Vector2(feet.x + dir * 50.0, wizard.global_position.y - 4.0)
			var moved := PackedVector2Array()
			for p in shape:
				moved.append(foot + (p - shape[0]) * 0.7)
			_begin_cast("Great Oak", _densify(moved), ATTACK_DRAW)
		else:
			_begin_cast("Geyser", _offset(GestureTemplates.preview_points("geyser"), feet, 0.6), QUICK_DRAW)
		return 0.0
	if _lift["spell"] == "Great Oak" and not _lift["thrown"]:  # it climbs the oak's ledges one by one
		var step := _climb_oak(delta, span, dir)
		if _lift.is_empty():
			return 0.0
		if not _lift["thrown"]:
			return step
	if _lift["spell"] == "Liana" and not _lift["thrown"]:  # it takes hold of the vine and climbs until its feet are over the top
		_lift["waited"] += delta
		if wizard.global_position.y < span.position.y - VINE_OVER:
			_lift["thrown"] = true
			wizard.climb_up = false
		elif _lift["waited"] > VINE_WAIT:
			wizard.climb_up = false
			_cannot[_lift["key"]] = GIVE_UP
			_lift = {}
			return 0.0
		else:
			wizard.climb_up = true
			return 0.0
	if wizard.is_on_floor():
		var wait := LIFT_WAIT if _lift["spell"] == "Geyser" or _lift["spell"] == "Updraft" else (TORNADO_WAIT if _lift["spell"] == "Tornado" else SHOVE_WAIT)
		if not _lift["thrown"] and _lift["waited"] < wait:  # the ground bubbles for a moment before the burst
			_lift["waited"] += delta
			return dir * WALK_SPEED if _lift["spell"] == "Tornado" else 0.0  # (a whirlwind is walked into)
		var past: bool = (wizard.global_position.x - span.get_center().x) * dir > span.size.x * 0.5
		var on_top: bool = wizard.global_position.y < span.position.y + 4.0
		if _lift["spell"] == "Great Oak" and _lift["thrown"] and on_top and not past:  # on a ledge over the top: it jumps off toward the far side
			wizard.request_jump()
			return dir * WizardRoute.MAX_AIR_SPEED
		var across: bool = past or on_top  # (or on top of the wall)
		if not across:  # down again on the near side: the water did not throw it high enough
			_cannot[_lift["key"]] = GIVE_UP
		_bridged[_lift["key"]] = 2.0
		_lift = {}
		_goal = ""
		_goal_timer = 0.0
		return 0.0
	_lift["thrown"] = true
	pass
	var clear: bool = wizard.global_position.y < span.position.y - 10.0
	return dir * WizardRoute.MAX_AIR_SPEED if clear else 0.0


## A climb up the ledges of an oak: it goes to the highest one it can jump onto, and jumps, until the top is within a jump. Returns the speed to go at.
func _climb_oak(delta: float, span: Rect2, dir: int) -> float:
	_lift["waited"] += delta
	if _lift["waited"] < OAK_GROW:
		return 0.0
	var feet: Vector2 = wizard.global_position
	if feet.y - span.position.y <= JUMP_REACH - 20.0:  # the top is a jump away
		_lift["thrown"] = true
		wizard.request_jump()
		return dir * WizardRoute.MAX_AIR_SPEED
	var best := Rect2()
	var best_rise := 0.0
	for oak: GreatOak in wizard.get_tree().get_nodes_in_group("oaks"):
		for ledge in oak.ledge_tops():
			var rise := feet.y - ledge.position.y
			if rise > 6.0 and rise <= JUMP_REACH and rise > best_rise and absf(feet.x - ledge.get_center().x) < 220.0:
				best = ledge
				best_rise = rise
	if best_rise == 0.0 or _lift["waited"] > OAK_WAIT:  # no ledge it can reach: the oak is given up
		_cannot[_lift["key"]] = GIVE_UP
		_lift = {}
		return 0.0
	var under := clampf(feet.x, best.position.x + 12.0, best.end.x - 12.0)
	if wizard.is_on_floor() and absf(feet.x - under) < 8.0:
		wizard.request_jump()
	return clampf((under - feet.x) * 4.0, -WALK_SPEED, WALK_SPEED)


## The stroke that makes a way over a pit of water, along the width of it at its surface: a wave for Frost Bridge, a row of loops for Lily Pads.
func _bridge_stroke(spell_name: String, span: Rect2) -> PackedVector2Array:
	var level := span.position.y
	var out := PackedVector2Array()
	if spell_name == "Frost Bridge":
		var steps := 80
		for i in steps + 1:
			var x := span.size.x * i / steps
			out.append(Vector2(span.position.x + x, level + 14.0 * sin(x / 22.0)))
	else:
		var loops := maxi(roundi(span.size.x / 31.0), 2)  # small loops, two to a pad, so that the pad's height is the line's own
		var steps := loops * 16
		for i in steps + 1:
			var angle := TAU * loops * i / steps
			out.append(Vector2(span.position.x + span.size.x * i / steps - 10.0 * sin(angle), level - 8.0 - 10.0 * cos(angle)))
	return _densify(out)


## Draws what keeps a sentinel from hitting it: smoke over the statue, or a Barrier, or a Decoy. The name of the spell, or "" when it can do none.
func _cover(post: Node2D, many := false) -> String:
	for spell_name: String in (COVER_ALL if many else COVERS):  # (a screen over one shooter does nothing against the rest: a shield goes with the wizard)
		if not _knows(spell_name) or wizard.stamina < SpellData.SPELLS[spell_name].cost:
			continue
		var around: Vector2 = wizard.center()
		match spell_name:
			"Smoke Screen":
				var base: Vector2 = post.center()
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("smoke"), base + Vector2(0, -30.0), 0.9), QUICK_DRAW)
			"Eclipse":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("eclipse"), post.center() + Vector2(0, -20.0), 1.0), QUICK_DRAW)
			"Barrier":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("circle"), around, 0.8), QUICK_DRAW)
			"Decoy":
				_begin_cast(spell_name, _offset(GestureTemplates.preview_points("eight"), around + Vector2(-40.0 * signf(post.center().x - around.x), 0.0), 0.7), QUICK_DRAW)
		return spell_name
	return ""


## Reads the page it stands under, if it does not have it.
func _read_page_underfoot() -> void:
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if pickup.gives(wizard.ledger) and pickup.is_under(wizard):
			wizard.get_parent().read_page(pickup, wizard)
			_replans = 0
			_goal = ""
			_goal_timer = 0.0
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
	if _goal == "page" and _wise_to_mirages and is_instance_valid(_goal_page) and _goal_page is Mirage:
		return true
	if _goal == "portal":
		return not is_instance_valid(_goal_portal) or _goal_portal.is_closing() or _goal_portal.remaining() < PORTAL_LEFT * 0.5
	return _goal == "page" and (not is_instance_valid(_goal_page) or not _goal_page.gives(wizard.ledger))


## Picks what to go for: the page nearest by the way it must walk, and when there is none to be had, the nearest wizard.
func _choose_goal() -> void:
	_goal_timer = GOAL_EVERY
	_sight_timer = 0.0
	_note_sights(0.0)  # (what lies in view now is known now)
	_goal = ""
	var start: Vector2i = wizard.nav.nearest(_tile_of(wizard.global_position), true)
	if start == WorldNav.NONE:
		return
	var best_page: PagePickup = null
	var best_path: Array[Vector2i] = []
	var best_worth := INF
	for pickup: PagePickup in wizard.get_tree().get_nodes_in_group("pages"):
		if not pickup.gives(wizard.ledger) or _skip.has(pickup.get_instance_id()) or (pickup is Mirage and _wise_to_mirages):
			continue
		if _sight_is_limited() and not _seen_pages.has(pickup.get_instance_id()):
			continue  # it has not set eyes on that one
		if _volcano_near(pickup.global_position, VOLCANO_KEEP_OFF) != Vector2.INF and not wizard.lava_proof():
			continue  # a page by a volcano that is erupting is left until it is over
		var tile := _tile_of(pickup.global_position)
		var stand: Vector2i = wizard.nav.nearest(tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - tile.x) + absi(stand.y - tile.y) <= PAGE_REACH:
			path = _path(start, stand)
			if path.is_empty() and stand == start:
				path = [start]  # it stands where the way to the page ends: nothing to walk, though the page may lie a few steps off
		if path.is_empty():
			_skip[pickup.get_instance_id()] = GIVE_UP  # no way there that a wizard can walk
			continue
		var worth := path.size() / sqrt(maxf(1.0, float(pickup.new_pages(wizard.ledger).size())))  # a dropped book is worth the walk: the more pages it would give, the nearer it counts
		if best_page == null or worth < best_worth:
			best_page = pickup
			best_path = path
			best_worth = worth
	var portal := _nearest_portal(start)
	if portal.has("portal") and (best_page == null or (portal["path"].size() < best_path.size() and _rng.randf() < PORTAL_CHANCE)):
		_goal = "portal"
		_goal_portal = portal["portal"]
		_portal_jumping = 0.0
		_route.set_path(portal["path"])
		return
	if _foe != null and _strength >= BOLD_ABOVE and (best_page == null or best_path.size() > HUNT_PAGE_NEAR):  # feeling strong, it goes after a rival rather than a page that lies far off
		var hunt: Array[Vector2i] = _path(start, wizard.nav.nearest(_tile_of(_foe_feet())))
		if not hunt.is_empty():
			_goal = "foe"
			_route.set_path(hunt)
			return
	if best_page != null:
		_goal = "page"
		_goal_page = best_page
		_page_steps = 0.0
		_route.set_path(best_path)
		return
	if _choose_explore(start):
		return
	if _choose_gate(start):
		return
	var exit := wizard.get_tree().get_first_node_in_group(&"exit_points")  # a room's way out, when nothing is left to take
	if exit != null:
		var way: Array[Vector2i] = _path(start, wizard.nav.nearest(_tile_of(exit.global_position)))
		if not way.is_empty():
			_goal = "exit"
			_route.set_path(way)
			return
	if _foe != null:
		var path: Array[Vector2i] = _path(start, wizard.nav.nearest(_tile_of(_foe_feet())))
		if not path.is_empty():
			_goal = "foe"
			_route.set_path(path)


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
	if _seen_pages.size() > 400:
		_seen_pages.clear()


func _square_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / (16.0 * WizardRoute.TILE)), floori(point.y / (12.0 * WizardRoute.TILE)))


## Goes to look at a part of the world it has not been to: along the way it was going, or the other way when that is shut off.
func _choose_explore(start: Vector2i) -> bool:
	if not _sight_is_limited():
		return false
	if _explore_dir == 0.0:
		_explore_dir = -1.0 if _rng.randf() < 0.5 else 1.0
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
					var path: Array[Vector2i] = _path(start, tile)
					if path.is_empty():
						continue
					var cost := float(path.size()) + _rng.randf() * 12.0 - (14.0 if dir == _explore_dir else 0.0)
					if cost < best_cost:
						best_cost = cost
						best_path = path
						best_dir = dir
					break  # (the nearest unexplored square this way on this floor is the one to weigh)
		if not best_path.is_empty():
			_explore_dir = best_dir
			_goal = "explore"
			_route.set_path(best_path)
			return true
		_explored.clear()  # it has been everywhere it can get to: it looks again
	return false


## The open portal nearest by the way it must walk, as {"portal", "path"}, or nothing when fewer than two are open (one leads nowhere).
func _nearest_portal(start: Vector2i) -> Dictionary:
	var open: Array = wizard.get_tree().get_nodes_in_group("field_portals").filter(func(p: FieldPortal) -> bool: return not p.is_closing())
	var best := {}
	if open.size() < 2:
		return best
	for portal: FieldPortal in open:
		if portal.remaining() < PORTAL_LEFT or portal.lift > PortalField.JUMPABLE or _skip.has(portal.get_instance_id()):  # one hung higher than a jump reaches is not for it
			continue
		var path: Array[Vector2i] = _path(start, wizard.nav.nearest(_tile_of(portal.global_position + Vector2(0.0, Portal.RY + portal.lift))))
		if not path.is_empty() and (best.is_empty() or path.size() < best["path"].size()):
			best = {"portal": portal, "path": path}
	return best


## When no page is to be had, the nearest gate that it holds a spell for: it goes to the place short of it. True when it has set out.
func _choose_gate(start: Vector2i) -> bool:
	var world := _world()
	if world == null:
		return false
	var best := {}
	var best_path: Array[Vector2i] = []
	for gate: Dictionary in world.closed_gates():
		if _skip.has(_gate_key(gate)) or _clearing_spell(gate["kind"]) == "":
			continue
		var floor_tile: Vector2i = gate["outside"] + Vector2i(0, -1)
		var stand: Vector2i = wizard.nav.nearest(floor_tile)
		var path: Array[Vector2i] = []
		if absi(stand.x - floor_tile.x) + absi(stand.y - floor_tile.y) <= 3:
			path = _path(start, stand)
		if path.is_empty():
			_skip[_gate_key(gate)] = GIVE_UP
			continue
		if best.is_empty() or path.size() < best_path.size():
			best = gate
			best_path = path
	if best.is_empty():
		return false
	_goal = "gate"
	_goal_gate = best
	_gate_tries = 0
	_gate_gone = 0
	_route.set_path(best_path)
	return true


## The way from one tile to another that it can walk: not over a crossing it holds no spell for.
func _path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var shut := []
	var world := _world()
	if world != null:
		for crossing: Dictionary in world.crossings():
			if _way_over(crossing) == "" or _cannot.has(crossing["key"]):
				shut.append(crossing["key"])
	return wizard.nav.path(from, to, shut)


## Whether it holds a page for crossing this kind of gate.
func _can_cross(kind: String) -> bool:
	return WAYS.get(kind, []).any(_usable)


## The way it will go over this crossing, the one it likes best of those it knows and that will carry it so far, or "".
func _way_over(crossing: Dictionary) -> String:
	for spell_name: String in WAYS.get(crossing["kind"], []):
		if _usable(spell_name) and (spell_name != "chant:double_jump" or (crossing["span"] as Rect2).size.x <= DOUBLE_JUMP_REACH):
			return spell_name
	return ""


## The spell it will make its way over a crossing with, the one it likes best of those it knows, or "".
func _way(kind: String) -> String:
	for spell_name: String in WAYS.get(kind, []):
		if _usable(spell_name):
			return spell_name
	return ""


## The spell that lifts it out of a pit of lava, or "": a vine would burn in the lava.
func _way_up() -> String:
	for spell_name in ["Geyser", "Push"]:
		if _knows(spell_name):
			return spell_name
	return ""


## Whether it can cross with a spell: it holds the page, and for black glass, a way up the far side of the pit as well.
func _usable(spell_name: String) -> bool:
	if spell_name == "leap:air":
		return _knows("Rocket Jump") or _knows("Featherfall")
	return _knows(spell_name) and (spell_name != "Obsidian Armor" or _way_up() != "")


## What a gate is called on the list of what it has given up.
func _gate_key(gate: Dictionary) -> String:
	return "gate %s" % str(gate["outside"])


## At the gate: strikes it when it is near enough, and otherwise steps up to it, for the part of it that is left may lie farther in.
func _work_gate() -> void:
	var world := _world()
	var target: Vector2 = world.gate_target(_goal_gate["entry"])
	var across: float = target.x - wizard.global_position.x
	var reach: int = STRIKE_REACH.get(_clearing_spell(_goal_gate["kind"]), 5)
	if absf(across) <= reach * WizardRoute.TILE and absf(target.y - wizard.center().y) <= minf(reach, 6) * WizardRoute.TILE:
		_clear_gate(target)
		return
	var side := -1 if across > 0.0 else 1  # it stands on the side it came by
	var tile := _tile_of(target)
	var stand: Vector2i = wizard.nav.nearest(Vector2i(tile.x + side * STRIKE_STAND, tile.y))
	var path: Array[Vector2i] = _path(wizard.nav.nearest(_tile_of(wizard.global_position), true), stand)
	if path.is_empty() or absi(stand.x - tile.x) > reach + 2 or absi(stand.y - tile.y) > 6:
		_skip[_gate_key(_goal_gate)] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
	else:
		_route.set_path(path)


## Whether a gate has been cleared: a piece of the world marks itself open; a creature in the way is cleared when it is dead or asleep.
func _gate_open(entry: Dictionary) -> bool:
	if entry.get("open", false):
		return true
	if entry.has("mob"):
		var mob = entry["mob"]
		return not is_instance_valid(mob) or mob.is_dead() or mob.is_fainted()
	return false


## A creature in the way ahead that it holds a spell for: it deals with it where it stands before it walks on.
func _creature_ahead() -> Dictionary:
	var world := _world()
	if world == null or not wizard.is_on_floor():
		return {}
	var toward := signf(float(_route.ahead(1).x - _tile_of(wizard.global_position).x)) if not _route.done() and _route.ahead(1) != WorldNav.NONE else wizard.facing
	for gate: Dictionary in world.closed_gates():
		if gate["kind"] != "creature" and gate["kind"] != "giant":
			continue
		var spell_name := _clearing_spell(gate["kind"])
		if spell_name == "" or _gate_open(gate["entry"]):
			continue
		var apart: Vector2 = gate["target"] - wizard.center()
		if signf(apart.x) == toward and absf(apart.x) < float(STRIKE_REACH.get(spell_name, 8)) * WizardRoute.TILE * 0.7 and absf(apart.y) < 120.0:
			return gate
	return {}


## The spell it will clear this kind of gate with: one it knows and can pay for, or "".
func _clearing_spell(kind: String) -> String:
	for spell_name: String in CLEARS.get(kind, []):
		if _knows(spell_name) and wizard.stamina >= SpellData.SPELLS[spell_name].cost:
			return spell_name
	return ""


## At the gate: strikes it, and again, until it is open or it has tried enough.
func _clear_gate(target: Vector2) -> void:
	if wizard.is_drawing() or _cast_cooldown > 0.0 or _react > 0.0:
		return
	var spell_name := _clearing_spell(_goal_gate["kind"])
	if spell_name == "" or _gate_tries >= CLEAR_TRIES:
		_skip[_gate_key(_goal_gate)] = GIVE_UP
		_goal = ""
		_goal_timer = 0.0
		return
	var gone: int = _goal_gate["entry"].get("gone", []).count(true)
	if gone > _gate_gone:  # a piece has gone since it last struck: it has the whole of its tries for the next
		_gate_tries = 0
	_gate_gone = gone
	_gate_tries += 1
	_cast_cooldown = 2.2
	_begin_cast(spell_name, _gate_stroke(spell_name, target), ATTACK_DRAW)


## The stroke of a spell that strikes a point.
func _gate_stroke(spell_name: String, point: Vector2) -> PackedVector2Array:
	match spell_name:
		"Ignite", "Frostbolt":
			var start: Vector2 = wizard.center() + Vector2(signf(point.x - wizard.center().x) * 12.0, -6.0)
			return _line(start, start + (point - start).normalized() * 90.0)
		"Faint":
			return _offset(GestureTemplates.preview_points("spiral"), point, 0.5)
		"Fire Breath":
			return _breath_stroke(point)
		"Stonefall":
			return _offset(GestureTemplates.preview_points("stonefall"), Vector2(point.x, point.y - 130.0), 0.8)
		"Earthquake":
			return _offset(GestureTemplates.preview_points("earthquake"), Vector2(point.x, point.y - 120.0), 1.0)
		"Firewall":  # a line up and then a line out over the place: a short wall
			var ground := _ground_under(point)
			return _offset(GestureTemplates.preview_points("flame_wall"), Vector2(point.x - 40.0, ground - 50.0), 0.8)
		"Tornado":
			return _offset(GestureTemplates.preview_points("tornado"), Vector2(point.x, _ground_under(point) - 90.0), 0.9)
		"Spark":
			return _offset(GestureTemplates.preview_points("zigzag"), Vector2(point.x, point.y - 90.0), 1.0)
		"Gust":
			var from: Vector2 = wizard.center()
			var cloud := point  # the wind takes a cloud by its middle, which may lie off the point struck, down a slope
			var near := INF
			for node in _goal_gate["entry"].get("nodes", []):  # (untyped: it may be a freed object)
				if is_instance_valid(node) and not node.is_queued_for_deletion() and node.global_position.distance_to(from) < near:
					near = node.global_position.distance_to(from)
					cloud = node.global_position
			return _line(from, from + (cloud - from).normalized() * 90.0)
	return PackedVector2Array()


## The height of the ground under a point (a little above it, looking down).
func _ground_under(point: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(point + Vector2(0, -40), point + Vector2(0, 400))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else point.y


## It is getting nowhere on its way: find the way again, and after a few tries give the page up for a while.
func _stuck_on_goal() -> void:
	_replans += 1
	if _goal == "portal" and _replans >= 3 and is_instance_valid(_goal_portal):
		_skip[_goal_portal.get_instance_id()] = GIVE_UP
		_replans = 0
		_choose_goal()
		return
	if _goal == "page" and _replans >= 3 and is_instance_valid(_goal_page):
		_skip[_goal_page.get_instance_id()] = GIVE_UP
		_replans = 0
		_choose_goal()
		return
	var start: Vector2i = wizard.nav.nearest(_tile_of(wizard.global_position), true)
	var path: Array[Vector2i] = _path(start, _route.goal())
	if path.is_empty():
		_goal = ""
	else:
		_route.set_path(path)


## What it is doing, for a report.
func status() -> String:
	return "%s (%s)" % [_goal if _goal != "" else "nothing", _route.status()]


# --- Reactions --------------------------------------------------------------------------------------------------


## The nearest of your shots that will hit it soon: {"eta": seconds, "dir": its direction}, or nothing.
func _incoming_shot() -> Dictionary:
	var best := {}
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster == wizard or not wizard.eyes.sees_node(node):
			continue  # (a shot off its screen, or in smoke or the dark, is not seen coming)
		var velocity: Vector2 = node.velocity()
		var rel: Vector2 = wizard.center() - node.global_position
		var closing := rel.dot(velocity.normalized())
		if closing <= 0.0:
			continue
		var eta := closing / velocity.length()
		var miss := (rel - velocity.normalized() * closing).length()
		if eta < 0.9 and miss < 28.0 and (best.is_empty() or eta < best["eta"]):
			best = {"eta": eta, "dir": velocity.normalized()}
	return best


## The sentinels that have it in sight, when it holds a spell to meet them with.
func _watchers() -> Array:
	var out := []
	if not COVERS.any(_knows):
		return out
	for post: Sentinel in wizard.get_tree().get_nodes_in_group("sentinels"):
		if post.sees(wizard.center()):
			out.append(post)
	return out


## Counts how many shots you have thrown lately, so it knows when to put up walls.
func _track_shots() -> void:
	for node in wizard.get_tree().get_nodes_in_group("projectiles"):
		if node.caster != wizard and not _seen_shots.has(node.get_instance_id()) and wizard.eyes.sees_node(node):
			_seen_shots[node.get_instance_id()] = true
			_pressure += 1.0
	if _seen_shots.size() > 64:
		_seen_shots.clear()


func _choose_defence(eta: float) -> String:
	var options := {"jump": 1.0}
	if _knows("Gust") and wizard.stamina >= 15.0 and eta > QUICK_DRAW + 0.05:
		options["reflect"] = 0.6 + 1.6 * skill  # a skilled wizard sends your spells back at you
	if _knows("Barrier") and wizard.stamina >= 35.0 and eta > QUICK_DRAW + 0.05:
		options["shield"] = 0.5
	if _knows("Shadow Step") and wizard.stamina >= 10.0:
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
	if _ready_to_cast("Spore Puff") and _clear_line(wizard.center(), _seen_center(_foe)):
		options["spores"] = 1.1
	if _knows("Push") and wizard.stamina >= 10.0:
		options["push"] = 1.5
	if _knows("Shadow Step") and wizard.stamina >= 10.0:
		options["blink_away"] = 1.0
	if _knows("Fire Breath") and wizard.stamina >= 16.0 and _clear_line(wizard.center(), _seen_center(_foe)):
		options["breath"] = 1.3
	return _pick(options) if not options.is_empty() else "escape"


func _act(reaction: String) -> void:
	var foe: Wizard = _foe
	match reaction:
		"jump":
			if wizard.is_on_floor():
				wizard.request_jump(0.8)
			_defend_cooldown = 0.6
		"reflect":
			# A Gust blown toward where the shot came from: it turns the shot round and sends it back.
			var start: Vector2 = wizard.center() - _threat_dir * 20.0
			_begin_cast("Gust", _line(start, start - _threat_dir * 90.0), QUICK_DRAW)
			_defend_cooldown = 1.4
		"cover":
			var watchers := _watchers()
			if not watchers.is_empty():
				_cover(watchers[0])
			_defend_cooldown = 4.0
		"shield":
			_begin_cast("Barrier", _offset(GestureTemplates.preview_points("circle"), wizard.center(), 0.8), QUICK_DRAW)
			_defend_cooldown = 2.5
		"blink_side", "blink_away":
			_blink_away(foe)
			_defend_cooldown = 1.6
		"escape":
			if _escape_commit <= 0.0 or _escape_dir == 0.0:
				_escape_dir = _safe_side()  # (once it has chosen a way out, it keeps to it for a while rather than turning back at every lick of flame)
				_escape_commit = 1.8
			_escape_time = 0.6
			if _knows("Shadow Step") and wizard.stamina >= 12.0 and _rng.randf() < skill * 0.6:
				var from: Vector2 = wizard.center()
				_begin_cast("Shadow Step", _line(from, from + Vector2(_escape_dir * 240.0, -12.0)), QUICK_DRAW)  # (to the safe side, not away from the rival)
			_defend_cooldown = 0.6
		"push":
			var away: Vector2 = (_seen_center(foe) - wizard.center()).normalized()
			_begin_cast("Push", _push_stroke(_seen_center(foe), away), QUICK_DRAW)
			_defend_cooldown = 1.5
		"breath":
			_begin_cast("Fire Breath", _breath_stroke(_seen_center(foe)), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8
		"spores":
			_begin_cast("Spore Puff", _breath_stroke(_seen_center(foe)), QUICK_DRAW + 0.1)
			_defend_cooldown = 1.8
		"geyser":  # the ground bubbles under its feet and throws it off
			_begin_cast("Geyser", _offset(GestureTemplates.preview_points("geyser"), _seen_feet(foe) + Vector2(0.0, -24.0), 0.6), QUICK_DRAW)
			_defend_cooldown = 1.8
		"surf":
			_begin_cast("Tide Surf", _surf_stroke(signf(_seen_feet(foe).x - wizard.global_position.x)), QUICK_DRAW)
			_defend_cooldown = 1.8


## Steps away from the player along the ground, or past them if its back is to a wall.
func _blink_away(foe: Wizard) -> void:
	var away := -signf(_seen_feet(foe).x - wizard.global_position.x)
	if away == 0.0:
		away = 1.0
	var room := (ArenaGen.right_edge() - wizard.global_position.x) if away > 0.0 else (wizard.global_position.x - ArenaGen.left_edge())
	if room < 120.0:
		away = -away  # cornered: go past the player instead
	var start: Vector2 = wizard.center()
	_begin_cast("Shadow Step", _line(start, start + Vector2(away * 240.0, -12.0)), QUICK_DRAW)


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
			_strafe_timer = _rng.randf_range(1.3, 3.2)  # (a person holds a direction, or stands, for a while: they do not change their mind every second)
			_strafe = [-1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 1.0][_rng.randi() % 7]  # (a recorded person stood still 47% of a fight and went each way about a quarter)
		dir = _strafe
	# Never back into the edge of the map; it would rather stand its ground there.
	var x: float = wizard.global_position.x
	if (dir < 0.0 and x < ArenaGen.left_edge() + 60.0) or (dir > 0.0 and x > ArenaGen.right_edge() - 60.0):
		dir = 0.0
	# Never walk into something burning.
	if dir != 0.0 and _in_danger(wizard.global_position + Vector2(dir * 34.0, -10.0)):
		dir = 0.0
	if wizard.is_on_floor() and _jump_cooldown <= 0.0:
		var blocked: bool = dir != 0.0 and wizard.is_on_wall()
		# Up onto a ledge you are standing on, whether or not it can see you, or when it is blocked.
		var above: bool = to_player.y < -50.0 and absf(to_player.x) < 260.0 and _ready_lift() == ""  # (with a way up to cast, it does not hop at the ledge)
		# Now and then, while it moves, it hops: a person does, but not every second.
		_hop_timer -= delta
		var hop: bool = dir != 0.0 and _hop_timer <= 0.0
		if hop:
			_hop_timer = _rng.randf_range(2.0, 5.0)  # (a recorded person hops about every three seconds in a fight)
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
	var volcano := _volcano_near(wizard.global_position, 900.0)  # lava from a volcano pours down its flanks: running up toward it is running into more of it
	if volcano != Vector2.INF and absf(wizard.global_position.x - volcano.x) > 40.0:
		return signf(wizard.global_position.x - volcano.x)
	var reach := [INF, INF]
	for k in 2:
		var dir := -1.0 if k == 0 else 1.0
		for step in range(30, 811, 30):
			var spot := _over_ground(dir * step)
			if not _in_danger(spot) and not _in_danger(spot + Vector2(0.0, 12.0)) and not _in_shoal(spot):
				reach[k] = float(step)
				break
	if reach[0] == reach[1]:
		if _escape_dir != 0.0:
			return _escape_dir
		return -signf(_seen_feet(_foe).x - wizard.global_position.x) if _foe != null else 1.0
	var best := -1.0 if reach[0] < reach[1] else 1.0
	if _escape_dir != 0.0 and reach[0 if _escape_dir < 0.0 else 1] <= reach[0 if best < 0.0 else 1] * 1.6 + 60.0:
		return _escape_dir  # the way it was already running is nearly as good: it does not turn back and forth in the flow
	return best


## True when anything that hurts (any spell, its own included) would reach it at this point.
## Where a volcano that is awake (or lava from one that is still running and cooling) lies within reach of a point, or Vector2.INF.
func _volcano_near(point: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	var best_gap := reach
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		var source := node as Node2D
		if source == null or not ((node is Eruption and node.is_awake()) or (node is Pond and node.cools and node.molten())):
			continue
		var gap := absf(source.global_position.x - point.x)
		if gap < best_gap and absf(source.global_position.y - point.y) < 900.0:
			best = source.global_position
			best_gap = gap
	return best


## True while lava is burning it: that is never walked on through.
func _scorched() -> bool:
	if wizard.lava_proof():
		return false
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if node is Pond and node.molten() and node.holds(wizard):
			return true
	return false


## True over a volcano that is awake, or lava from one that still runs: it passes, and nothing walks on into it meanwhile.
func _lethal_at(point: Vector2) -> bool:
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if ((node is Eruption and node.is_awake()) or (node is Pond and node.cools and node.molten()) or (node is Bramble and _clearing_spell("brambles") == "")) and node.danger_at(point):  # (thorns are not walked into by someone with no fire to burn them)
			return true
	return _in_shoal(point)


## True in water with piranhas in it.
func _in_shoal(point: Vector2) -> bool:
	for shoal: Piranhas in wizard.get_tree().get_nodes_in_group("shoals"):  # water with fish in it is not waded
		if shoal.alive() and shoal.is_biting_at(point):
			return true
	return false


## True while it stands in water with piranhas in it: it gets out by the nearest bank, hopping the edge when it must.
func _bitten() -> bool:
	return _in_shoal(wizard.global_position + Vector2(0.0, -6.0)) or _in_shoal(wizard.center())


func _in_danger(point: Vector2) -> bool:
	for node in wizard.get_tree().get_nodes_in_group("danger"):
		if node.danger_at(point):
			return true
	return false


func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


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
	var same_ground: bool = grounded and wizard.is_on_floor() and absf(_seen_feet(foe).y - wizard.global_position.y) < 8.0
	var closing: bool = signf(foe.velocity.x) == signf(-to_player.x) and absf(foe.velocity.x) > 60.0
	var aim_ok := absf(to_player.normalized().x) > 0.4  # a near-vertical stroke is a poor flick
	var scores := {
		"Ignite": (2.0 if gap > 140.0 else 0.8) if sees and aim_ok else 0.0,
		"Frostbolt": (0.4 if foe.is_slowed() else 1.6) if sees else 0.0,
		"Spark": 2.2 if still or stuck else 1.0,
		"Stonefall": 3.0 if stuck else (1.8 if still else 0.5),
		"Icicles": 2.0 if _ceiling_over(_seen_center(foe)) else 0.0,  # they hang from a ceiling, wherever there is one over you
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
		"Tornado": (0.6 + _pressure * 0.5) if gap < 260.0 else 0.2,
		"Ice Prison": 1.3 if gap < 360.0 and not stuck else 0.0,
		"Mudslide": 1.1 if grounded and not stuck else 0.0,
		"Black Hole": (0.4 + _pressure * 0.4) if gap < 300.0 else 0.0,
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
	_begin_cast(choice, _attack_stroke(choice), ATTACK_DRAW, true)
	return true


## True when something solid (a platform or the ground) is above you, so nothing from the sky can reach you.
func _sheltered() -> bool:
	var top: Vector2 = _seen_center(_foe) + Vector2(0, -50)
	# Cast from the sky down, the way lightning comes: a one-way platform only stops things from above.
	var query := PhysicsRayQueryParameters2D.create(top + Vector2(0, -600), top)
	query.collision_mask = 1 | 16
	return not wizard.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Where you will be by the time a spell lands, judged with the wizard's skill: a skilled wizard leads you well.
func _predict(seconds: float) -> Vector2:
	var foe: Wizard = _foe
	var lead: Vector2 = foe.velocity * seconds * skill
	lead.y = 0.0 if foe.stands() else lead.y * 0.5
	return _seen_center(foe) + lead


## The gesture for an attack, drawn where the spell should land.
func _attack_stroke(spell_name: String) -> PackedVector2Array:
	var foe: Wizard = _foe
	var feet: Vector2 = _seen_feet(foe)
	var facing := signf(_seen_feet(foe).x - wizard.global_position.x)
	if facing == 0.0:
		facing = 1.0
	match spell_name:
		"Pebble":  # lobbed: aimed above the rival by as far as the stone will have fallen on the way
			var start: Vector2 = wizard.center() + Vector2(facing * 12.0, -6.0)
			var flight: float = start.distance_to(_seen_center(foe)) / Pebble.SPEED
			var target := _predict(flight)
			target.y -= 0.5 * Pebble.FALL * flight * flight
			var aim := (target - start).angle() + _rng.randfn(0.0, 0.1 * (1.0 - skill))
			return _line(start, start + Vector2.from_angle(aim) * 90.0)
		"Hailstorm":  # a cloud over the rival's head, and the hail falls from it
			return _offset(GestureTemplates.preview_points("hailstorm"), Vector2(_seen_center(foe).x + 20.0, _seen_center(foe).y - 120.0), 1.0)
		"Ignite", "Frostbolt", "Barbs":
			var start: Vector2 = wizard.center() + Vector2(facing * 12.0, -6.0)
			var target := _predict(start.distance_to(_seen_center(foe)) / SHOT_SPEED)
			var aim := (target - start).angle() + _rng.randfn(0.0, 0.16 * (1.0 - skill))
			return _line(start, start + Vector2.from_angle(aim) * 90.0)
		"Spark":
			var x := _predict(ATTACK_DRAW * 0.8).x
			return _offset(GestureTemplates.preview_points("zigzag"), Vector2(x, _seen_center(foe).y - 90.0), 1.0)
		"Stonefall":
			var x := _predict(ATTACK_DRAW + 0.6).x
			return _offset(GestureTemplates.preview_points("stonefall"), Vector2(x, _seen_center(foe).y - 130.0), 0.8)
		"Tornado":
			var x: float = lerpf(wizard.global_position.x, _seen_feet(foe).x, 0.45)
			return _offset(GestureTemplates.preview_points("tornado"), Vector2(x, feet.y - 90.0), 0.9)
		"Ice Prison":
			return _offset(GestureTemplates.preview_points("circle"), _predict(ATTACK_DRAW * 0.6), 0.8)
		"Earthquake":
			# Drawn in the air above the middle of the fight, where the peaks read clearly.
			return _offset(GestureTemplates.preview_points("earthquake"), Vector2(_predict(ATTACK_DRAW * 0.6).x, _seen_center(foe).y - 120.0), 1.0)
		"Mudslide":
			var x := _predict(ATTACK_DRAW * 0.6).x
			return _offset(GestureTemplates.preview_points("wave"), Vector2(x, feet.y - 60.0), 1.0)
		"Black Hole":
			# Beyond you if you are close (it drags you away from it), between you if you keep shooting at it.
			var spot: Vector2 = _seen_center(foe) + Vector2(facing * 80.0, 0.0)
			if _pressure > 1.5:
				spot = wizard.center().lerp(_seen_center(foe), 0.4)
			var spiral := GestureTemplates.preview_points("spiral")
			# The black hole forms where the spiral ends, so place the spiral's end on the spot.
			return _offset(spiral, spot - (spiral[spiral.size() - 1] - _centre_of(spiral)), 1.0)
		"Firewall":
			var x: float = lerpf(wizard.global_position.x, _seen_feet(foe).x, 0.5)
			var toward := signf(_seen_feet(foe).x - wizard.global_position.x)  # a wall between them: up from the ground, then out across the way
			return _offset(_facing_flipped(GestureTemplates.preview_points("flame_wall"), toward), Vector2(x - toward * 50.0, feet.y - 50.0), 0.8)
		"Blizzard":
			return _offset(GestureTemplates.preview_points("snowfall"), Vector2(feet.x - 30.0, _seen_center(foe).y - 70.0), 0.8)
		"Fire Breath", "Spore Puff":
			return _breath_stroke(_seen_center(foe))
		"Stalagmite":
			return _offset(GestureTemplates.preview_points("stalagmite"), Vector2(_predict(ATTACK_DRAW * 0.6).x, feet.y - 40.0), 0.9)
		"Bramble":
			return _offset(GestureTemplates.preview_points("bramble"), Vector2(lerpf(wizard.global_position.x, _seen_feet(foe).x, 0.8), feet.y - 16.0), 1.0)
		"Flytrap":
			return _offset(GestureTemplates.preview_points("jaws"), Vector2(_predict(ATTACK_DRAW * 0.6).x, feet.y - 30.0), 0.8)
		"Icicles":  # Vs hung over its head, their tips just above it
			return _offset(GestureTemplates.preview_points("icicles"), Vector2(_seen_center(foe).x, _seen_center(foe).y - 35.0), 0.9)
		"Sinkhole":  # a U drawn into the ground under its feet
			return _offset(GestureTemplates.preview_points("pit"), Vector2(_predict(ATTACK_DRAW * 0.6).x, feet.y + 20.0), 0.8)
		"Hex":
			return _offset(GestureTemplates.preview_points("pentagram"), _predict(0.3), 0.5)
		"Vacuum":
			return _offset(GestureTemplates.preview_points("lungs"), _seen_center(foe), 0.5)
		"Faint":
			return _offset(GestureTemplates.preview_points("spiral"), _seen_center(foe), 0.5)
		"Fight or Flight":
			return _offset(GestureTemplates.preview_points("question"), _seen_center(foe), 0.6)
		"Silence":
			return _offset(GestureTemplates.preview_points("silence"), _seen_center(foe), 0.6)
		"Tide Surf", "Thorn Whip", "Leech":
			return _surf_stroke(facing)
		"Flaming Sphere":  # a ring and a level line toward it, along the ground beside the wizard
			return _offset(_facing_flipped(GestureTemplates.preview_points("sphere"), facing), wizard.center() + Vector2(facing * 50.0, 0.0), 0.8)
		"Mirage":  # a tall box drawn on the ground a little ahead of it
			return _offset(GestureTemplates.preview_points("portrait"), Vector2(wizard.center().x + facing * 90.0, wizard.global_position.y - 60.0), 0.8)
		"Raise Dead":  # a cross drawn upright in the ground beside it: the skeleton rises there, on its way toward you
			return _offset(GestureTemplates.preview_points("latin_cross"), Vector2(wizard.center().x + facing * 70.0, wizard.global_position.y - 40.0), 0.8)
		"Insect Plague":  # an infinity sign, the wings of a bee, beside it: the swarm sets off from there
			return _offset(GestureTemplates.preview_points("lungs"), wizard.center() + Vector2(facing * 50.0, -10.0), 0.7)
		"Eldritch Blast":  # an arrow pointing at the rival
			var pointing: float = (_predict(0.4) - wizard.center()).angle() + _rng.randfn(0.0, 0.1 * (1.0 - skill))
			return _offset(_turned(GestureTemplates.preview_points("arrow"), pointing), wizard.center(), 0.8)
		"Hemorrhage":  # a drop of blood drawn over the rival
			return _offset(GestureTemplates.preview_points("flare"), _seen_center(foe), 0.6)
		"Supernova":  # a planet and its ring, drawn where the sun should hang: over the rival
			return _offset(GestureTemplates.preview_points("saturn"), _predict(ATTACK_DRAW), 0.8)
		"Scythe":  # a crescent drawn in front of the wizard
			return _offset(GestureTemplates.preview_points("crescent"), wizard.center() + Vector2(facing * 40.0, 0.0), 0.8)
		"Thunderclap":  # a cloud and a bolt, drawn on itself
			return _offset(GestureTemplates.preview_points("thunderclap"), wizard.center() + Vector2(0.0, -30.0), 0.8)
	return PackedVector2Array()


## A stroke turned by an angle, about its own origin.
func _turned(points: PackedVector2Array, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p.rotated(angle))
	return out


## A Tide Surf drawn toward one side: the wave runs the way the stroke runs.
func _surf_stroke(side: float) -> PackedVector2Array:
	var wave := GestureTemplates.preview_points("tsunami")
	var out := PackedVector2Array()
	for p in wave:
		out.append(Vector2(p.x * (side if side != 0.0 else 1.0), p.y))
	return _offset(out, wizard.center() + Vector2(side * 70.0, -10.0), 1.0)


## A stroke drawn the other way round, for a foe on the left.
func _facing_flipped(points: PackedVector2Array, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(p.x * (side if side != 0.0 else 1.0), p.y))
	return out


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


## A Fire Breath cone with its point at the wizard and its mouth toward you, a little off when it is unskilled.
## It draws the cone longer when you are farther off, so the fire reaches you.
func _breath_stroke(target: Vector2) -> PackedVector2Array:
	var gap: float = wizard.center().distance_to(target)
	var size := clampf(gap / 150.0, 1.0, 1.4)
	var aim: float = (target - wizard.center()).angle() + _rng.randfn(0.0, 0.2 * (1.0 - skill))
	var tip: Vector2 = wizard.center() + Vector2.from_angle(aim) * 20.0
	var out := PackedVector2Array()
	for p in GestureTemplates.preview_points("cone"):
		out.append(tip + p.rotated(aim) * size)
	return _densify(out)


## A Push: a circle round you, starting on its far side, then a line out of it pointing away from the wizard.
func _push_stroke(around: Vector2, away: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var start_angle := away.angle()
	for i in 33:
		pts.append(around + Vector2.from_angle(start_angle + TAU * i / 32.0) * 30.0)
	var exit := pts[pts.size() - 1]
	pts.append(exit + away * 90.0)
	return _densify(pts)


## Starts the wizard drawing a spell's gesture. The spell happens when the drawing is done, if nothing breaks it.
func _begin_cast(spell_name: String, stroke: PackedVector2Array, draw_time: float, sloppy := false) -> bool:
	if stroke.size() < 2 or wizard.silenced() or wizard.rage_time > 0.0:
		return false
	if _typing != "":  # the chant box is open: a person closes it to draw, and the chant is lost
		_break_typing()
		return false
	if not _drag_ok(spell_name, draw_time):  # the screen would drag the stroke out of shape: it stands still first, as a person learns to,
		_hold_still = HOLD_STILL                # and draws it once it has stopped (see _draw_when_still)
		_pending = {"spell": spell_name, "stroke": stroke, "time": draw_time, "sloppy": sloppy, "from": wizard.global_position}
		return false
	var data: Spell = SpellData.SPELLS[spell_name]
	var mask: int = data.buttons
	var caster: Caster = wizard.caster
	return wizard.start_drawing(stroke, SpellData.SCHOOL_COLORS[data.school], func(points: PackedVector2Array) -> void:
		caster.cast_stroke(mask, _shaken(_handed(points) if sloppy else points)), draw_time)


## Whether a stroke drawn now, over this long, keeps its shape: the view follows the wizard, so whatever way the wizard is going the stroke is dragged,
## and each spell's shape stands only so much of it (measured with the recognizer: tests/measure_drift.gd, ai/stroke_drift.json). A person learns
## which spells they can draw on the run; this is that knowledge.
func _drag_ok(spell_name: String, draw_time: float) -> bool:
	var row: Dictionary = _drift_table().get(spell_name, {})
	if not row.has("right"):
		return true  # a stroke that is read only in the world (a ceiling, water): not measured
	var slide := wizard.eyes.slide_over(draw_time, wizard.velocity, 0.0 if wizard.is_on_floor() else wizard.gravity)
	var allow_x: float = row["right"] if slide.x >= 0.0 else row["left"]
	var allow_y: float = row["down"] if slide.y >= 0.0 else row["up"]
	return absf(slide.x) <= allow_x * DRAG_MARGIN and absf(slide.y) <= allow_y * DRAG_MARGIN


static func _drift_table() -> Dictionary:
	if _drift.is_empty():
		var file := FileAccess.open(DRIFT_FILE, FileAccess.READ)
		_drift = JSON.parse_string(file.get_as_text()) if file != null else {"": {}}
		if _drift == null or _drift.is_empty():
			_drift = {"": {}}
	return _drift


## How far it would fall from here before it met ground or a platform (a long way, when there is nothing under it).
func _drop_below() -> float:
	var from := wizard.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 2000.0), 1 | 16)
	query.exclude = [wizard.get_rid()]
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return 2000.0 if hit.is_empty() else from.distance_to(hit["position"])


## A stroke it has stopped to draw is drawn once it is still enough, where it meant it to be (moved with it, if it slid on while stopping);
## if it has not come to a stop in time, the moment has passed.
func _draw_when_still() -> void:
	if _pending.is_empty():
		return
	if _hold_still <= 0.0 or wizard.is_drawing():
		_pending = {}
		return
	if not _drag_ok(_pending["spell"], _pending["time"]):
		return
	var shift: Vector2 = wizard.global_position - _pending["from"]
	var stroke := PackedVector2Array()
	for point: Vector2 in _pending["stroke"]:
		stroke.append(point + shift)
	var spell_name: String = _pending["spell"]
	var draw_time: float = _pending["time"]
	var sloppy: bool = _pending["sloppy"]
	_pending = {}
	_begin_cast(spell_name, stroke, draw_time, sloppy)


## A long fall ahead: a Featherfall is drawn the moment it begins, while the view still keeps up with the stroke. Once the wizard is falling
## fast the screen drags the stroke out of shape, as it would a person's, and it is too late.
func _catch_fall() -> void:
	if wizard.is_on_floor() or wizard.velocity.y <= 0.0 or wizard.feather_time > 0.0 or wizard.is_drawing() or _typing != "" or not _ready_to_cast("Featherfall"):
		return
	if not _drag_ok("Featherfall", QUICK_DRAW) or _drop_below() <= LONG_FALL:
		return
	_begin_cast("Featherfall", _tend_stroke("Featherfall", Vector2.ZERO), QUICK_DRAW)


## True while it stands still to draw.
func holds_still() -> bool:
	return _hold_still > 0.0


## A hand is not a template: the stroke wanders a little, as a stroke drawn with a mouse does. The hastier the wizard (the less skilled), the
## more it wanders. It never botches a stroke on purpose (owner, 2026-11-09: no made-up mistakes); a stroke goes wrong only as a person's does,
## from the view moving under it or the ground shaking. Only in a fight: the strokes it
## draws to cross a gate or to get on are drawn with care.
func _handed(points: PackedVector2Array) -> PackedVector2Array:
	var wander := lerpf(5.0, 2.0, skill)
	var phase_a := _rng.randf() * TAU
	var phase_b := _rng.randf() * TAU
	var squash := Vector2.ONE
	var turn := 0.0
	var middle := Vector2.ZERO
	for p in points:
		middle += p
	middle /= maxf(float(points.size()), 1.0)
	var out := PackedVector2Array()
	for i in points.size():
		var k := float(i) / maxf(float(points.size() - 1), 1.0)
		var off := Vector2(sin(k * 7.0 + phase_a), cos(k * 5.0 + phase_b)) * wander + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.8
		var rel := (points[i] - middle) * squash
		out.append(middle + rel.rotated(turn) + off)
	return out


## While the ground shakes, each point of the wizard's stroke is nudged by the screen's shake, the same amount the
## player's stroke is nudged by the shaking view.
func _shaken(points: PackedVector2Array) -> PackedVector2Array:
	var tree := wizard.get_tree()
	if not Earthquake.is_shaking(tree):
		return points
	var px := GameCamera.shake_px(tree)
	var shaken := PackedVector2Array()
	for p in points:
		shaken.append(p + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px)
	return shaken


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
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0.0, -ICICLE_REACH))
	query.collision_mask = 1
	var hit := wizard.get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["normal"].y > 0.3


## Whether it may cast a spell now: it holds the page, is not silenced, has not just cast it for itself, and has the strength (blood is paid
## in maximum stamina, and never to the last drop).
func _ready_to_cast(spell_name: String) -> bool:
	if not _knows(spell_name) or _rest.has(spell_name) or wizard.silenced() or wizard.rage_time > 0.0:
		return false
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
	if _goal != "page" and _scent <= 0.0 and SpellTargets.wizards(wizard.get_tree()).size() > 1:
		weights["Hunter's Mark"] = 1.0
	if fighting:
		if low and gap > 140.0 and wizard.fade_time <= 0.0:
			weights["Sneak"] = 2.5
		if sees and _pressure > 0.8 and gap > 110.0 and gap < 380.0:
			weights["Stone Wall"] = 1.4
		if _pressure > 1.0 and gap > 150.0:
			weights["Smoke Screen"] = 1.0
		if _pressure > 1.2:
			weights["Decoy"] = 1.0
		if _pressure > 0.8 and wizard.veil == 0:
			weights["Crimson Veil"] = 1.3
		if _pressure > 1.6 and wizard.obsidian_time <= 0.0:
			weights["Obsidian Armor"] = 0.8
		if sees and gap > 200.0:
			weights["Eclipse"] = 0.6 + 0.3 * _pressure
	for spell_name in weights.keys():
		if not _ready_to_cast(spell_name):
			weights[spell_name] = 0.0
	var choice := _pick(weights)
	if choice == "":
		return false
	if not _begin_cast(choice, _tend_stroke(choice, to_player), QUICK_DRAW):
		return false
	_rest[choice] = TEND_REST[choice]
	return true


## The stroke of a spell it casts for itself.
func _tend_stroke(spell_name: String, to_player: Vector2) -> PackedVector2Array:
	var dir := signf(to_player.x) if to_player.x != 0.0 else 1.0
	var here: Vector2 = wizard.center()
	var feet: Vector2 = wizard.global_position
	match spell_name:
		"Flare":
			return _offset(GestureTemplates.preview_points("flare"), here + Vector2(0.0, -40.0), 0.6)
		"Glowcap":
			return _offset(GestureTemplates.preview_points("circle"), here + Vector2(dir * 60.0, 0.0), 0.6)
		"Moonbeam":
			var at: Vector2 = _seen_feet(_foe) if _foe != null else feet
			return _line(Vector2(at.x, at.y - 70.0), Vector2(at.x, at.y + 10.0))
		"Adrenaline":
			return _offset(GestureTemplates.preview_points("zigzag"), here, 0.6)
		"Wild Shape":
			return _offset(GestureTemplates.preview_points("eclipse"), here, 0.9)
		"Hunter's Mark":
			return _offset(GestureTemplates.preview_points("arrow"), here, 0.6)
		"Sneak":  # a wave deep enough not to be read as a flick, which is a Shadow Step on the same buttons
			var wave := PackedVector2Array()
			for i in 61:
				wave.append(here + Vector2(180.0 * i / 60.0 - 90.0, 28.0 * sin(TAU * 3.0 * i / 60.0)))
			return _densify(wave)
		"Stone Wall":  # begun in the ground a step toward you, and drawn up and a little toward you
			var x := feet.x + dir * 70.0
			return _line(Vector2(x, _ground_under(Vector2(x, feet.y)) + 4.0), Vector2(x + dir * 20.0, _ground_under(Vector2(x, feet.y)) - 90.0))
		"Smoke Screen":
			var middle := lerpf(feet.x, feet.x + to_player.x, 0.5)
			return _offset(GestureTemplates.preview_points("smoke"), Vector2(middle, feet.y - 50.0), 0.9)
		"Decoy":
			return _offset(GestureTemplates.preview_points("eight"), here + Vector2(-dir * 50.0, 0.0), 0.7)
		"Eclipse":
			return _offset(GestureTemplates.preview_points("eclipse"), _seen_center(_foe), 1.0)
		"Crimson Veil":
			return _line(Vector2(here.x, here.y - 50.0), Vector2(here.x, here.y + 20.0))
		"Obsidian Armor":
			return _offset(GestureTemplates.preview_points("circle"), here, 0.8)
		"Featherfall":
			return _offset(GestureTemplates.preview_points("feather"), here, 0.9)
	return PackedVector2Array()


## The first of the spells that raise it up that it is ready to cast, or "".
func _ready_lift() -> String:
	for spell_name: String in LIFTS:
		if _ready_to_cast(spell_name):
			return spell_name
	return ""


## A rival standing over its head, on a ledge: it raises itself up to them with the first spell it holds that does it. True when it has begun.
func _chase(to_player: Vector2) -> bool:
	if not wizard.is_on_floor() or _rest.has("chase") or not _lift.is_empty():
		return false
	var rise := wizard.global_position.y - _seen_feet(_foe).y
	if rise < CHASE_ABOVE or absf(to_player.x) > 320.0:
		return false
	var dir := 1 if to_player.x >= 0.0 else -1
	var span := Rect2(_seen_feet(_foe).x - 24.0, _seen_feet(_foe).y - 6.0, 48.0, 12.0)
	for spell_name: String in LIFTS:
		if not _ready_to_cast(spell_name) or (spell_name == "Great Oak" and rise > OAK_CHASE_MAX):
			continue
		if LIFT_CLOSE.has(spell_name) and absf(to_player.x) > LIFT_CLOSE[spell_name] + 60.0:
			continue  # a vine, an oak or a column of air is raised only once it has walked up to the foot of the ledge
		_rest["chase"] = CHASE_REST
		if _begin_lift(spell_name, "chase", dir, span):
			return true
	return false


# --- Shapes -----------------------------------------------------------------------------------------------------


func _line(a: Vector2, b: Vector2) -> PackedVector2Array:
	return _densify(PackedVector2Array([a, b]))


## A preview shape, scaled, with the middle of its bounding box moved to a point.
func _offset(shape: PackedVector2Array, middle: Vector2, scale: float) -> PackedVector2Array:
	var centre := _box_centre(shape)
	var out := PackedVector2Array()
	for p in shape:
		out.append(middle + (p - centre) * scale)
	return _densify(out)


func _box_centre(points: PackedVector2Array) -> Vector2:
	return GestureTemplates.bounds(points).get_center()


func _centre_of(points: PackedVector2Array) -> Vector2:
	return _box_centre(points)


## The stroke with points every two pixels, as dense as one drawn with the mouse.
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points.size() - 1:
		var steps := maxi(1, int(points[i].distance_to(points[i + 1]) / 2.0))
		for k in steps:
			out.append(points[i].lerp(points[i + 1], float(k) / steps))
	out.append(points[points.size() - 1])
	return out


## Picks a key at random, weighted by its value. Returns "" when every weight is zero.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(weights[key], 0.0)
	if total <= 0.0:
		return ""
	var roll := _rng.randf() * total
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
		if other.is_dead() or other.KINDS[other.kind].role == "flyer":
			continue
		if other.center().distance_to(target.center()) < reach:
			count += 1
	return count
