class_name Wizard
extends CharacterBody2D

## A wizard: the body every wizard in the game has, the player's and every other wizard's in a match. It is driven either by a person (the keyboard
## and the mouse) or by a WizardBrain, and from there it is the same body: the same walk, jump, stamina, wounds, shoves and status
## effects, so a spell does the same to any of them. Its origin is at its feet, so it stands exactly on whatever is under it.
## Each is made of parts (see PartsLook): the look is the whole choice, written as one String.

signal damaged(amount: int)
signal debuff_applied(kind: String)
signal died

const SPEED := 300.0
const JUMP_VELOCITY := -520.0
const JUMP_COST := 5.0  # stamina a jump takes; with less than this, you can't jump
const RUN_COST := 0.12   # stamina per second of walking or running on the ground
const MAX_STAMINA := 200.0  # what you start with, and the most you can ever have: a hit lowers the most you have, and healing raises it again, but not past this
const STAMINA_REGEN := 20.0   # per second
const REGEN_DELAY := 1.0      # seconds after a spell (or a faint, or a blow) before regen starts; walking and jumping do not make it wait
const ADRENALINE_TAKEN := 0.6   # how much of a blow gets through under Adrenaline
const ADRENALINE_DEALT := 1.5   # and how much harder the wizard's own blows land
const SHOVE_SHED := 1500.0      # how fast a shove dies away on the ground, in pixels a second each second
const AIR_DRAG := 100.0         # how slowly a blow's sideways speed dies away in the air, in pixels a second each second
const AIR_STEER := 0.5          # how much of a walking pace the keys can give or take away in the air once a wizard has been thrown or pulled
const AIR_ACCEL := 300.0       # how fast the keys can add to or turn a wizard's sideways speed then, in pixels a second each second
const AIR_OWN_ACCEL := 2400.0  # and how fast they can when the wizard jumped or walked off a ledge themselves: they steer as freely as on the ground
## The sound of a footstep on each biome's ground (NOX SOUND's Footsteps Essentials, tools/make_nox_sounds.py).
const STEP_SOUNDS := {"graveyard": "step_dirt", "mountains": "step_snow", "jungle": "step_leaves", "ashlands": "step_gravel", "castle": "step_tile",
	"underground": "step_rock", "portals": "step_grass", "ocean": "step_wood"}
## How fast a wizard must be falling (px/s) to be heard landing.
const LAND_SPEED := 380.0
const OIL_GRIP := 90.0        # and on oil, which is more slippery still
const ICE_GRIP := 150.0        # how fast a wizard on ice can change speed, in pixels a second each second
static var OBSIDIAN_SECONDS := Motion.number("Obsidian Armor", "state", "for")  # how long the black glass holds
const VEIL_BLOWS := 2           # how many blows a Crimson Veil turns away
const OBSIDIAN_SHOTS := 0.5     # and how much of a shot's damage gets through
static var SURF := Motion.of("Tide Surf", "drive")       # how fast a wave carries the wizard
const GET_UP := 10.0            # a wizard who has fainted stands up with this much stamina
const FAINT_TIME := 4.0         # seconds a Faint keeps someone down: it costs the caster maximum stamina, so it has to be worth it
const BODY_HEIGHT := 78.0     # from the feet to the top of the hood
const COYOTE_TIME := 0.1      # a jump still works this long after walking off a ledge
const JUMP_BUFFER := 0.12     # a jump pressed this long before landing happens on landing
const HURT_GRACE := 0.5       # after a hit, further hits are ignored this long
const STEP_EVERY := 0.32      # seconds between footstep sounds while running
## The animations of the three newer figures (and the werewolf), whose frames are cut to these names.
const ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"fps": 12.0}, "jump": {"fps": 10.0, "loop": false}, "fall": {"fps": 8.0},
	"cast": {"fps": 8.0},                      # the hand held up while a stroke is drawn
	"release": {"fps": 16.0, "loop": false},  # thrust forward as the spell goes off
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 9.0, "loop": false},
}
## The older wizard's (LuizMelo's) animations.
const OLD_ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"fps": 12.0}, "jump": {"fps": 10.0, "loop": false}, "fall": {"fps": 8.0},
	"cast": {"fps": 8.0, "first": 0, "last": 2},                      # the staff held up while a stroke is drawn
	"release": {"fps": 18.0, "loop": false, "first": 0, "last": 4},  # thrust forward as the spell goes off
	"hit": {"fps": 14.0, "loop": false}, "death": {"fps": 10.0, "loop": false},
}
## The other three older looks name some of their frames differently: the staff is held up in "release" and thrust out in "cast".
const OLD_LOOK_ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"fps": 12.0}, "jump": {"fps": 8.0, "loop": false}, "fall": {"fps": 8.0},
	"cast": {"from": "release", "fps": 8.0, "first": 0, "last": 3},
	"release": {"from": "cast", "fps": 16.0, "loop": false, "first": 3, "last": 5},
	"hit": {"fps": 10.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
const OLD_ART := ["wizard", "dark_wizard", "pyre_wizard", "bone_wizard"]  # the folders of the four older figures
const SPAWN_TIME := 0.7       # a wizard summoned into the world arrives out of a circle this long
const FALL_LIMIT := 800.0     # a wizard below this has fallen off the map (in a world, the bottom of it)

static var FEATHER_FALL := BodyStates.fall("featherlight")  # the fastest a wizard falls under a Featherfall, in pixels a second
# Swimming (the ocean, chapter 20): out of its depth in a sea a wizard sinks slowly, each tap of jump is a stroke that lifts it, and S dives.
const SWIM_STROKE := 300.0   # the speed a stroke lifts the wizard at, in pixels a second
const SWIM_GRAVITY := 450.0  # how quickly it slows from that, and sinks again
const SINK_SPEED := 170.0    # the fastest it sinks by itself
const DIVE_SPEED := 300.0    # and the fastest it dives
const FALL_SHAKE_REACH := 500.0  # a wizard falling this near shakes a screen a little
const STROKE_EVERY := 0.28   # seconds between a brain's strokes: a person taps the key, they do not hold it (see WizardBrain._swim)
# Flying (the sky, chapter 19): no ground and no jump. A, D, W and S steer, and with no key down the wizard drifts slowly down.
const FLY_SPEED := 300.0     # sideways and up and down
const FLY_DRIFT := 30.0      # how fast the wizard drifts down when nothing is pressed
const FLY_ACCEL := 900.0     # how quickly the up and down speed follows the keys
var swim_time := 0.0         # above zero while the wizard is out of its depth in a sea (see swim)
var flying := false          # set by a world with no ground (the sky): the wizard steers freely instead of walking
var fly_box := Rect2()       # where a flying wizard's feet may be: it stops at the edge of it. Empty: anywhere
var _feather_motes := 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var look := PartsLook.DEFAULT_LOOK:  # which wizard this is: what it is made of (see PartsLook). (The seven older figures, and a MobKind in res://data/mobs, are still dressed if one is asked for.)
	set(value):
		if value == look:
			return
		look = value
		if is_node_ready():
			dress()

var palette := 0:  # which set of colors it wears (see WizardLook)
	set(value):
		if value == palette:
			return
		palette = value
		if is_node_ready():
			_paint()
var brain: RefCounted  # what plays this wizard (a WizardBrain, or SkyBrain); none while a person does
var caster: Caster  # a brain's wizard draws its spells through this; a person's strokes are read by the arena's own
var nav: WorldNav  # the ways about the world, for a wizard that walks it by itself; none in the waiting room
var last_spell := ""
var pad := Pad.new(self)  # what a brain asks of the body (a person's keys say the same)
var vine := VineHold.new(self)  # the vine (Liana) the wizard is hanging on, if any
var _jump_strength := 1.0  # how much of a full jump a brain asked for
var pen := Pen.new(self)  # the stroke a brain's wizard is drawing
var eyes: Eyes                      # the screen a person in this wizard's place would have
var _overlay: Node2D  # draws the ice, and the stroke a brain's wizard is drawing, over the sprite
var stamina := MAX_STAMINA
var max_stamina := MAX_STAMINA  # what stamina can reach for now. Hits and the Rift wear it down; you die when it is gone
var ledger := Ledger.complete()  # the pages in the wizard's book: all of them in the waiting room, the ones found in a world
var movement_enabled := true  # the arena turns this off while a typing box or the spellbook is open
var infinite_time: float: # Blessing of the Wellspring: stamina does not run out while this lasts
	get: return _status.left(&"infinite")
	set(seconds): _status.set_left(&"infinite", seconds)
var slow_time: float: # frost slows the caster while this lasts
	get: return _status.left(&"slow")
	set(seconds): _status.set_left(&"slow", seconds)
var wet_time: float: # water on the body: lightning strikes harder, and no fire takes hold (see Coating)
	get: return _status.left(&"wet")
	set(seconds): _status.set_left(&"wet", seconds)
var burning_time: float: # alight: a burn bites each half second while this lasts
	get: return _status.left(&"burning")
	set(seconds): _status.set_left(&"burning", seconds)
var oiled_time: float: # oil on the body: a fire that takes hold burns twice as long
	get: return _status.left(&"oiled")
	set(seconds): _status.set_left(&"oiled", seconds)
var _feathers: CPUParticles2D  # the pale feathers that drift about a wizard under Featherfall
var bubbles := StatusBubbles.new(self)  # the ring of little pictures that shows what state it is in
var coat := Coating.new(self)  # what clings to the body: water, flame, oil
var sink_time: float: # quicksand: slowed, and unable to jump while this lasts
	get: return _status.left(&"sink")
	set(seconds): _status.set_left(&"sink", seconds)
var tangle_time: float: # caught in thorns: nearly stopped, and unable to jump while this lasts
	get: return _status.left(&"tangle")
	set(seconds): _status.set_left(&"tangle", seconds)
var deep_breath_time: float: # the Blessing of the Deep Breath: the breath is held while this lasts, under water or not
	get: return _status.left(&"deep_breath")
	set(seconds): _status.set_left(&"deep_breath", seconds)
var lungs := Lungs.new(self)  # the air it holds, and the water around it
var haste_time: float: # the Chant of Swift Feet: faster on foot while this lasts
	get: return _status.left(&"haste") if not ledger.is_settled("haste") else 1.0e9
	set(seconds): _status.set_left(&"haste", seconds)
var air_jump_time: float: # the Blessing of Skystep: a jump in the air is allowed while this lasts
	get: return _status.left(&"air_jump") if not ledger.is_settled("double_jump") else 1.0e9
	set(seconds): _status.set_left(&"air_jump", seconds)
var adrenaline_time: float: # Adrenaline: the wizard is hasted, takes less damage and deals more while this lasts
	get: return _status.left(&"adrenaline")
	set(seconds): _status.set_left(&"adrenaline", seconds)
var obsidian_time: float: # Obsidian Armor: shots do half, lava does nothing, and the wizard is slower while this lasts
	get: return _status.left(&"obsidian")
	set(seconds): _status.set_left(&"obsidian", seconds)
var surf_time: float: # Tide Surf: a wave carries the wizard along surf_dir while this lasts
	get: return _status.left(&"surf")
	set(seconds): _status.set_left(&"surf", seconds)
var fade_time: float: # Sneak: the wizard shows only faintly while this lasts
	get: return _status.left(&"fade")
	set(seconds): _status.set_left(&"fade", seconds)
var rocket_time: float: # Rocket Jump: the flame lifts the wizard, slowly at first and then faster, while this lasts
	get: return _status.left(&"rocket")
	set(seconds): _status.set_left(&"rocket", seconds)
var feather_time: float: # Featherfall: the wizard falls as slowly as a feather while this lasts
	get: return _status.left(&"feather")
	set(seconds): _status.set_left(&"feather", seconds)
var surf_dir := 1.0
var veil := 0  # hits a Crimson Veil will still turn away
var _veil_cool := 0.0  # a moment after one is turned away, in which a burn or a second blow is turned away with it
var fainted := false  # knocked out by a Faint: down on the ground for FAINT_TIME
var asleep := false   # fainted by their own choice (a Long Rest): down until they have mended, or a blow wakes them
var mending := Mending.new(self)  # the heals over time, the second chance and the rest of what mends the wizard
var _faint_left := 0.0
var air_jump_ready := false  # the air jump is spent by one use, and comes back when the wizard lands
var wind := 0.0  # the push of the air along the ground, set every frame by the world that has wind (the snowy peaks)
var _slide := 0.0  # the sideways speed carried over on ice
var _shove := Vector2.ZERO  # a Push on the caster: slides them for a moment, then fades
var drained_time := 0.0     # a wound is bleeding the strength out of them: they are slower and their hand shakes (Hemorrhage keeps this up while it bleeds)
var _launched := false      # thrown or pulled through the air by something else: the keys can only nudge that, where in a jump of their own choosing they steer freely
var _placed_at := Vector2.ZERO  # where the last step left the wizard: if it is anywhere else, something moved it
var _air_vx := 0.0          # the sideways speed carried through the air from a jump: the keys only nudge it
var mute_time: float: # no rituals while above zero
	get: return _status.left(&"mute")
	set(seconds): _status.set_left(&"mute", seconds)
var daze_time: float: # a Thunderclap: slow, and no spell or chant, while above zero
	get: return _status.left(&"daze")
	set(seconds): _status.set_left(&"daze", seconds)
var rage_time := 0.0    # Fight or Flight, fighting: the game casts for the wizard while above zero, and the wizard casts nothing of their own
var fear_time := 0.0    # Fight or Flight, fleeing: the wizard cannot move toward afraid_of while above zero
var afraid_of: Wizard
var root_time: float: # no walking or jumping while above zero
	get: return _status.left(&"root")
	set(seconds): _status.set_left(&"root", seconds)
var _stuck_time := 0.0         # how long a giant's stomp has the player stuck in the ground
var _body_material: ShaderMaterial  # cuts the body off at the waist while stuck
var blind_time: float: # the caster's gesture trail is hidden while above zero
	get: return _status.left(&"blind")
	set(seconds): _status.set_left(&"blind", seconds)
var dead := false
var _status := StatusEffects.new()  # the timed conditions above, each a Timer
var _shield_time: float:
	get: return _status.left(&"shield")
	set(seconds): _status.set_left(&"shield", seconds)
var _frozen_time: float: # frozen in ice: rooted, and shattered out of it by Air or Earth
	get: return _status.left(&"frozen")
	set(seconds): _status.set_left(&"frozen", seconds)
var _since_spend := 0.0
var _stepping := false  # the wizard is moving their body along the ground (the last frame): the stamina does not come back meanwhile
var facing := 1.0
var look_dir := 0.0  # which way a wizard made of parts is drawn facing, when that is not the way it goes (a pull, a shove: the animation has them come from the front); 0 is the way it faces
var _flash := 0.0        # red flash after being hit
var _grace := 0.0        # time left of the safety after a hit
var _source_grace := {}  # hit source (instance id) -> time left before that source can hit this wizard again (see take_damage)
var _coyote := 0.0
var _jump_buffer := 0.0
var _step := 0.0
var casting := false      # true while the caster has a stroke in progress (set by the arena)
var _dice: RandomNumberGenerator  # see dice()
var _dice_of := -1
const WEDGED_SPEED := 700.0  # falling this fast and going nowhere, this long, a body is caught in rock
const WEDGED_FOR := 0.6
const STRUGGLES := 100.0  # and one that goes nowhere at this speed, inside rock, is caught in it (one standing quietly is well where it is)
var _wedged := 0.0
var _was_last := Vector2.ZERO
var _rock_look := 0.0
var _rock_about := false
var _firm := Vector2.INF   # where it last stood firmly
var _firm_for := 0.0
var casts_made := 0       # the spells this wizard has cast, for the tests that watch a match
var drawn := false  # the portal of a collapsing world is carrying the wizard up: they cast and fight, but cannot walk or fall
var _art := "wizard"  # the folder of frames it wears now
var pose := WizardPose.new(self)  # which of a wizard made of parts' many animations to play
var _ride_lift := 0.0
var _magic: MagicLayer  # a wizard made of parts has its gem, its glow and its spell effects on a layer of their own, in the color of the spell (see magic_ramp.gdshader)
var _gem := Color.WHITE  # the color of the last spell it drew, which the gem shows; a wizard that has cast none shows a school of its own

var _layer_alive := 0
var punch := Punch.new(self)  # a blow with the weapon, for no stamina (P)
var wolf := WildShape.new(self) # the werewolf shape (Wild Shape), when the wizard has taken it
var golem := GolemForm.new(self)  # the body of stone (Golem), when the wizard has taken it
var _releasing := 0.0     # time left of the thrust that plays when a spell goes off
var _hurt_anim := 0.0     # time left of the flinch after a hit
var cast_color := Color.WHITE  # the school being drawn (set by the arena); the trail and the sparks take it
@onready var _sprite: AnimatedSprite2D = $Look
var _barrier: BarrierBubble  # the Barrier as it is seen round the wizard
var _drop_time := 0.0          # while above zero, wooden platforms and stairs let the wizard through

# --- What the other machines of a network game see of this wizard (see share and Net) -------------------------------------
## Only the machine that drives a wizard (its multiplayer authority) moves it and decides what happens to it. A MultiplayerSynchronizer
## copies these to the others, where the wizard is a likeness that follows them. Playing alone, every wizard is driven here.
const FROZEN := 1
const SHIELDED := 2
const OBSIDIAN := 4
const STUCK := 8
const GROUNDED := 16
const ROOTED := 32
const SLOWED := 64
const FADED := 128
const VEILED := 256
const WILD := 512
const GOLEM_EARTH := preload("res://art/tiles/earth_cemetery.png")  # the stone when the world has none to show (a test, a lab)
const GOLEM := 8192
const WET := 1024
const BURNING := 2048
const OILED := 4096
var _hidden := false  # not drawn: faded from sight, and not the wizard at this machine
const UNSEEN_BUMP := 50.0  # how near a wizard faded from sight must be to be felt rather than seen
const FADE_ALPHA := 0.35  # how much of a veiled wizard shows
var peer := 0  # the machine that drives this wizard, as a peer id; 0 for this machine. Set before the wizard enters the tree
var human := true  # a person plays this wizard, here or on another machine; false for one a brain plays (on the host)
var net_position := Vector2.ZERO  # where the driving machine has the wizard; a likeness glides there
var shown_anim := &"idle"  # the animation the driving machine plays
var shown_words := ""  # the chant being typed so far, shown over the head for others to read (as a stroke is for others to read); empty when none
var shown_stroke := PackedVector2Array()  # the stroke being drawn, in the world, for others to see and read
var marks := 0  # FROZEN, SHIELDED, OBSIDIAN, STUCK, GROUNDED, ROOTED and SLOWED, as the driving machine has them
var _passed := false  # its fall has been shown
const GLIDE := 0.45  # how much of the way to where it really is a likeness moves each physics frame
const SNAP := 160.0  # farther than this, and it is put there at once (a step, a portal, a rift)


func _ready() -> void:
	eyes = Eyes.new(self)
	add_child(_status)
	add_child(bubbles.layer())
	_feathers = Featherfall.drift()
	add_child(_feathers)
	_status.ended.connect(func(status: StringName) -> void:
		if status == &"frozen":
			Shatter.spawn(get_parent(), center(), Color("#cdeeff")))  # the ice gives way
	floor_max_angle = deg_to_rad(50.0)  # a 45 degree slope, the steepest a tunnel climbs, still counts as floor
	add_to_group("wizards")
	_make_magic()
	dress()
	net_position = global_position
	if is_person():
		add_to_group("player")  # the one wizard the camera, the book and the bar belong to
	else:
		$Camera2D.queue_free()
		_sprite.animation_finished.connect(_on_animation_finished)
		Fx.pop(get_parent(), global_position + Vector2(0, -2), "magic_02", Color("#d8d0e8"), 70.0, SPAWN_TIME + 0.2, 1.2, 1.5)  # it arrives through a summoning circle
		Sfx.cue("wizard", "summon", global_position)
		if _uses_parts():
			pose.arrive()
	if brain != null:
		_make_caster()
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_body_material = ShaderMaterial.new()
	_body_material.shader = load("res://scripts/fx/wizard_body.gdshader")
	_sprite.material = _body_material
	_paint()
	_barrier = BarrierBubble.new(center_offset())
	add_child(_barrier)


## Puts on the frames of the wizard's look. A network game gives each seat its own look, after the scene's wizard is ready.
## The animations a folder of frames is cut to: the older figures' differ from the newer.
static func animations_for(art: String) -> Dictionary:
	if art == "wizard":
		return OLD_ANIMATIONS
	return OLD_LOOK_ANIMATIONS if OLD_ART.has(art) else ANIMATIONS


func dress() -> void:
	var art := "wizard"
	_sprite.scale = Vector2.ONE
	_magic.detach()
	if wolf.on:
		art = "werewolf"
		_sprite.scale = Vector2.ONE * WildShape.SCALE
	elif golem.shown:
		art = "golem"  # the stone of the world, over the picture of a golem (see the shader's stone)
	elif PartsLook.is_parts(look):
		var config := PartsLook.decode(look)
		var made := look if not config.is_empty() else PartsLook.DEFAULT_LOOK  # (a look that is not one of parts is never worn: this is for safety)
		if config.is_empty():
			config = PartsLook.default_config()
		_art = "wizard"  # the frames are the first wizard's size, and stand where its did
		_sprite.sprite_frames = PartFrames.body(made)
		_sprite.offset = PartFrames.OFFSET
		_gem = _gem_of(made)
		_sprite.play("idle")
		_magic.attach(_sprite, config["weapon"])
		_paint()
		return
	elif look != "wizard":
		var data: MobKind = Mob.KINDS[look]
		art = data.art
		_sprite.scale = Vector2.ONE * WizardLook.scale_of(look, data.scale)  # the three figures are drawn to one height
	_art = art
	_sprite.sprite_frames = CharFrames.build(GolemForm.FRAMES if golem.shown else "res://art/chars/" + art, GolemForm.ANIMATIONS if golem.shown else animations_for(art))
	_sprite.offset = Vector2(0, -PixelArt.CHARACTERS[art]["size"].y * 0.5)  # the frames' bottom edge is the feet
	_sprite.play("idle")
	_paint()


## True for a wizard made of parts that is not a werewolf: it has all of the animations, and a magic layer.
func _uses_parts() -> bool:
	return PartsLook.is_parts(look) and not wolf.on and not golem.shown


## The layer over a wizard made of parts that holds its gem and spell effects, which a shader colors (see MagicLayer).
func _make_magic() -> void:
	_magic = MagicLayer.new()
	add_child(_magic)
	move_child(_magic, _sprite.get_index() + 1)


## The school a wizard's gem shows before it has drawn a spell: its own, chosen by its look (every wizard is a different color, and the player does not choose).
func _gem_of(of_look: String) -> Color:
	var schools := SpellData.SCHOOL_COLORS.keys()
	return SpellData.SCHOOL_COLORS[schools[absi(of_look.hash()) % schools.size()]]


## What the magic layer is colored for the animation: the school of the last spell drawn, but a dazed wizard's stars are yellow and a thaw's shards are ice.
func _magic_color(anim: StringName) -> Color:
	match anim:
		&"dazed":
			return Color("#ffe066")
		&"frozen", &"thaw":
			return Color("#bfe6ff")
	return _gem


## The part of the body from the top that shows (see the shader's keep): all of it, or cut off at the waist while the wizard is stuck in the ground.
func _set_keep(amount: float) -> void:
	_body_material.set_shader_parameter("keep", amount)
	_magic.set_keep(amount)


## The wizard has won the match.
func celebrate() -> void:
	if _uses_parts() and not dead:
		pose.play_once("victory")


## A spell goes off (see CastStyles): a wizard made of parts moves its body as that spell asks.
func show_cast(spell: String, toward := 0.0) -> void:
	if _uses_parts():
		pose.cast(spell, toward)


## The body thrusts for this long: a spell goes off, or a claw swipes.
func thrust(seconds: float) -> void:
	_releasing = seconds


## Puts its set of colors on the sprite (the material is made a little after the frames are put on).
func _paint() -> void:
	if _body_material != null:
		WizardLook.paint(_body_material, look, 0 if wolf.on or golem.shown else palette)  # a werewolf keeps its own colors
		_body_material.set_shader_parameter("stone", 1.0 if golem.shown else 0.0)
		if golem.shown:
			var arena := get_parent()
			var rock: Texture2D = arena.earth_texture() if arena != null and arena.has_method("earth_texture") else null
			_body_material.set_shader_parameter("ground", rock if rock != null else GOLEM_EARTH)  # the very ground the wizard stands on


## Where the wizard's mouth is, for Fire Breath.
func mouth() -> Vector2:
	return global_position + Vector2(26.0 * facing, -56.0)  # at the front of the wizard, around the face


## Where the end of the staff, wand or blade is right now, in the world: the place a stream of water or a beam leaves from. The rig that drew the weapon says where
## it is in every frame (`PartFrames.tip_of`). A wizard without parts, a wolf or a golem has none and gives the mouth.
func tip() -> Vector2:
	if _magic == null or not _magic.visible or _magic.sprite_frames == null or golem.shown or wolf.on:
		return mouth()
	return _tip_at(String(_magic.animation), _magic.frame, _magic.flip_h)


## Where the gem will be a moment from now, when the staff is thrust out as the spell goes off. A spell is made the instant the stroke ends, before the
## body has changed to that pose, so what leaves the staff leaves from here and not from wherever the staff was held while drawing.
func launch_tip() -> Vector2:
	if _magic == null or not _magic.visible or _magic.sprite_frames == null or golem.shown or wolf.on:
		return mouth()
	if not PartFrames.ensure(_magic.sprite_frames, "release"):
		return tip()
	return _tip_at("release", 1, facing < 0.0)


## The weapon's tip in one frame, in the world, as the body is placed now (turned the way `flipped` says).
func _tip_at(anim: String, frame: int, flipped: bool) -> Vector2:
	var spot: Variant = PartFrames.tip_of(String(_magic.sprite_frames.get_meta("weapon", "")), anim, frame)
	if spot == null:
		return mouth()
	var local: Vector2 = spot
	if flipped:
		local.x = -local.x
	return _magic.to_global(local + _magic.offset)


## The middle of the wizard's body, relative to its feet.
func center_offset() -> Vector2:
	return Vector2(0, -BODY_HEIGHT * 0.5)


## The middle of the wizard's body in the world. Spells and enemies aim here, not at the feet.
func center() -> Vector2:
	return global_position + center_offset()


func raise_shield(seconds: float) -> void:
	_shield_time = maxf(_shield_time, seconds)
	Sfx.cue("Barrier", "barrier", center())


func has_shield() -> bool:
	return marks & SHIELDED != 0 if is_likeness() else _shield_time > 0.0


## Encases the player in ice: rooted for the same time an enemy stays frozen.
func freeze(seconds: float) -> bool:
	_frozen_time = maxf(_frozen_time, seconds)
	root_time = maxf(root_time, seconds)
	return true


func is_wet() -> bool:
	return marks & WET != 0 if is_likeness() else wet_time > 0.0


func is_burning() -> bool:
	return marks & BURNING != 0 if is_likeness() else burning_time > 0.0


func is_oiled() -> bool:
	return marks & OILED != 0 if is_likeness() else oiled_time > 0.0


func is_frozen() -> bool:
	return marks & FROZEN != 0 if is_likeness() else _frozen_time > 0.0


## Seconds left in the ice.
func frozen_left() -> float:
	return _frozen_time


func thaw() -> void:
	_frozen_time = 0.0


## Spend stamina if there is enough. Returns false and spends nothing otherwise.
func spend(amount: float, makes_wait := true) -> bool:
	if infinite_time > 0.0:
		return true
	if stamina < amount:
		return false
	drain(amount, makes_wait)
	return true


## Take stamina even if it's short (misfire penalty); never goes below zero.
## `makes_wait` is false for what the body does (a step, a jump): it does not put off the stamina coming back.
func drain(amount: float, makes_wait := true) -> void:
	if infinite_time > 0.0 or is_likeness():
		return
	stamina = maxf(stamina - amount, 0.0)
	if makes_wait:
		_since_spend = 0.0


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, max_stamina)


## Mends the wizard: the most stamina they can have rises by this much, and so does the stamina they have (never past the greatest a wizard can have).
func heal(amount: float) -> void:
	if is_likeness() or dead:
		return
	if wolf.on:
		wolf.mend(roundi(amount))  # a wolf is not mended: the wizard under it is
		return
	var before := max_stamina
	max_stamina = minf(max_stamina + amount, MAX_STAMINA)
	stamina = minf(stamina + amount, max_stamina)
	if max_stamina > before and amount >= 1.0:
		MatchRecorder.event("HEAL %d %.1f" % [get_instance_id(), max_stamina - before])


## Takes this much off the most stamina the wizard can have, whatever stands between (no veil, no grace, no armor): a wager lost, a breath run out. It can kill.
func lose_max(amount: float) -> void:
	max_stamina -= amount
	stamina = minf(stamina, maxf(max_stamina, 0.0))
	mending.lost(amount)
	_check_death()


## A grace in which no blow lands.
func give_grace(seconds: float) -> void:
	_grace = maxf(_grace, seconds)


## Puts the wizard to sleep: down on the ground as in a Faint, but with their stamina as it was, until something wakes them (a Long Rest: see Mending).
func fall_asleep() -> void:
	if dead or fainted or is_likeness():
		return
	wolf.end()
	golem.end()
	fainted = true
	asleep = true
	_faint_left = 1.0e9
	pen.drop()


## The sleeper wakes and stands.
func wake() -> void:
	if not asleep:
		return
	asleep = false
	fainted = false
	_faint_left = 0.0

## Back on their feet with all their stamina, as if they had not fallen: a place where nothing can end the visit calls this.
func revive() -> void:
	if not dead or is_likeness():
		return
	dead = false
	_passed = false
	if _layer_alive != 0:
		collision_layer = _layer_alive
	max_stamina = MAX_STAMINA
	stamina = MAX_STAMINA
	movement_enabled = true
	modulate.a = 1.0


## True while a hit from this source (or, with none, from anything without one) would be turned away.
func _safe_from(source: Object) -> bool:
	if source == null:
		return _grace > 0.0
	return _source_grace.get(source.get_instance_id(), 0.0) > 0.0


## The safety that follows a hit: this source's own, or the general one when the hit names none.
func _begin_grace(source: Object) -> void:
	if source == null:
		_grace = HURT_GRACE
	else:
		_source_grace[source.get_instance_id()] = HURT_GRACE


## A hit lowers your most stamina and then gives a short grace, in which no other hit lands. A burn (grace_hit false) takes
## it without starting that grace, so a burn and a blow can both land.
## A hit that names its `source` (whatever struck: one spell's cast, see SpellTargets.hit_source_of) has a safety of its own: that source cannot hit this wizard again for
## HURT_GRACE, but a different source can land at once, and the safety that follows a hit with no source does not stop it. A hit with no source works as it always did.
func take_damage(amount: int, grace_hit := true, projectile := false, source: Object = null) -> void:
	if is_likeness():
		MatchStats.hit(self, minf(float(amount), maxf(max_stamina, 0.0)), "", float(amount) >= max_stamina)  # a blow this machine's person struck is theirs, though it lands on the other machine
		return  # the machine that drives this wizard decides what a hit does, and shows it here (see _show_hurt)
	if (projectile and _shield_time > 0.0) or dead or (grace_hit and _safe_from(source)) or amount <= 0:
		return
	if veil > 0 or _veil_cool > 0.0:
		if _veil_cool <= 0.0:
			veil -= 1
			_veil_cool = 0.5
			Fx.burst(get_parent(), center(), SpellData.SCHOOL_COLORS["Blood"], 14, 140.0, 0.4, true)
			Sfx.cue("Crimson Veil", "glass", center(), -4.0)
			FloatText.spawn(get_parent(), center() + Vector2(0, -44), "Negated", Color("#ff6b7a"), 1.0)
		if grace_hit:
			_begin_grace(source)
		return
	if projectile and obsidian_time > 0.0:
		amount = maxi(1, roundi(amount * OBSIDIAN_SHOTS))  # black glass takes half of what a shot would
	if adrenaline_time > 0.0:
		amount = maxi(1, roundi(amount * ADRENALINE_TAKEN))  # a racing heart feels less
	if golem.on:
		amount = maxi(1, roundi(amount * GolemForm.TAKEN))  # stone takes half of every blow
	amount = roundi(amount * Hex.multiplier(get_tree(), self))  # a hexed wizard takes half again as much
	var had := maxf(max_stamina, 0.0)
	max_stamina -= amount
	stamina = minf(stamina, maxf(max_stamina, 0.0))
	mending.lost(amount)
	mending.struck()
	_flash = 0.3
	_hurt_anim = 0.25
	if grace_hit:
		_begin_grace(source)
	Sfx.speak(self, WizardLook.hurt_sound(look), center())
	_shake_own_screen(0.35 + amount * 0.02)
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d" % amount, Color("#ff5a5a"), 1.1)
	Net.send(self, &"_show_hurt", [amount])
	damaged.emit(amount)
	if brain != null:
		brain.on_hurt(amount)
	_check_death()
	MatchStats.hit(self, minf(float(amount), had))  # (only what there was to lose)


func _check_death() -> void:
	if wolf.on and max_stamina <= 0.0 and not dead:
		wolf.end()  # the wolf is beaten, and not the wizard
		return
	if max_stamina <= 0.0 and not dead:
		var world := get_tree().get_first_node_in_group(&"world") as World
		if world != null and world.leaving:  # who goes on to the next world is settled: no one is beaten while this one fades
			max_stamina = 1.0
			return
		if mending.rescue():  # a second chance, armed: every way of dying comes to this question
			return
		max_stamina = 0.0
		dead = true
		movement_enabled = false
		pen.drop()
		died.emit()
		if brain != null:
			_pass_away()


## A wizard no person plays here (a brain's, or a likeness of another machine's) falls where it stands: spells pass through it, and it
## fades after its death tumble. (A person's own wizard stays, for the game-over screen and the camera.)
func _pass_away() -> void:
	if _passed:
		return
	_passed = true
	_layer_alive = collision_layer
	set_deferred("collision_layer", 0)
	Sfx.cue("wizard", "die", center())
	Fx.burst(get_parent(), center(), Color("#d8d0e8"), 18, 180.0, 0.6, true)
	Fx.smoke(get_parent(), center(), Color(0.25, 0.2, 0.3, 0.6), 5, 30.0)
	GameCamera.shake_near(get_tree(), global_position, 0.18, FALL_SHAKE_REACH)  # (a fall far off shakes nobody's screen)


## A fallen wizard fades after its death tumble, and one a brain plays is gone. A likeness only fades: it stays until its scene does,
## as the machine that drives it may still be telling it things.
func _on_animation_finished() -> void:
	if dead and _sprite.animation == &"death" and not (human and is_likeness()):  # a person's own machine hides their wizard
		var fade := create_tween()
		fade.tween_interval(0.4)
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		if not is_likeness():
			fade.tween_callback(queue_free)


## Standing in water or lava.
func soak(surface_y: float, lava: bool) -> void:
	lungs.soak(surface_y, lava)
	if not lava:
		coat.soak()  # a body that has been in water is wet


## The breath has run out under water: the most stamina goes, until the wizard breathes again.
func drown(amount: float) -> void:
	lose_max(amount)


func apply_debuff(kind: String, seconds: float) -> void:
	if dead or is_likeness():
		return
	match kind:
		"mute":
			mute_time = maxf(mute_time, seconds)
		"root":
			root_time = maxf(root_time, seconds)
		"blind":
			blind_time = maxf(blind_time, seconds)
		"slow":
			slow_time = maxf(slow_time, seconds)
		"daze":
			daze_time = maxf(daze_time, seconds)
			slow_time = maxf(slow_time, seconds)
			FloatText.spawn(get_parent(), center() + Vector2(0, -44), "Dazed", Color(0.85, 0.9, 1.0), 1.0)
		"sink":
			sink_time = maxf(sink_time, seconds)
		"tangle":
			tangle_time = maxf(tangle_time, seconds)
	debuff_applied.emit(kind)


func is_muted() -> bool:
	return mute_time > 0.0 or fainted or silenced()


## True while the wizard has taken another body, the werewolf's or the golem's: no spells, and a fight with the body alone.
func shifted() -> bool:
	return wolf.on or golem.on


## True while the wizard stands in a ring of Silence, or is dazed by thunder: they can cast nothing.
func silenced() -> bool:
	return daze_time > 0.0 or wolf.on or golem.on or Silence.covers(get_tree(), center())


## Pays for a spell in maximum stamina, which only healing brings back. Never takes the last of it: false, and nothing paid, if the
## wizard could not live through it.
func pay_max(amount: float) -> bool:
	if dead or max_stamina <= amount or is_likeness():
		return false
	max_stamina -= amount
	stamina = minf(stamina, max_stamina)
	_flash = 0.3
	_since_spend = 0.0
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d max" % roundi(amount), Color("#ff6b7a"), 1.0)
	return true


## A Faint: all the stamina goes, and the wizard drops for FAINT_TIME seconds. They stand up with GET_UP stamina.
func faint() -> void:
	if dead or fainted or is_likeness():
		return
	wolf.end()  # the wolf is knocked out of the wizard
	golem.end()
	fainted = true
	_faint_left = FAINT_TIME
	stamina = 0.0
	_since_spend = 0.0
	pen.drop()
	Sfx.speak(self, WizardLook.hurt_sound(look), center())


func grant_adrenaline(seconds: float) -> void:
	adrenaline_time = maxf(adrenaline_time, seconds)
	haste_time = maxf(haste_time, seconds)


func fade_from_sight(seconds: float) -> void:
	fade_time = maxf(fade_time, seconds)
	Sfx.cue("wizard", "fade", center(), -6.0)


## True while the wizard is faded from sight.
func is_faded() -> bool:
	return marks & FADED != 0 if is_likeness() else fade_time > 0.0


## True when this wizard cannot be seen by anyone else: faded from sight, and not the body at this machine (whose own wizard sees themselves faintly).
## Rivals' brains, mobs, Insight and the Hunter's Mark all pass over a wizard like this, and nothing of it is drawn.
func is_unseen() -> bool:
	return is_faded() and not is_in_group("player")


## True when a wizard that is looking for others can make this one out: not faded, so close that it is bumped into, or hexed (the dark star
## floats over their head for anyone to see). The person at this machine is hidden from every brain and creature like anyone else: only their
## own screen shows them faintly (see is_unseen).
func is_seen_from(point: Vector2) -> bool:
	return not is_faded() or center().distance_to(point) < UNSEEN_BUMP or (is_inside_tree() and Hex.multiplier(get_tree(), self) > 1.0)


## A spell or a chant ends Sneak: a wizard out of sight can do one thing, and doing it shows them.
func break_sneak() -> void:
	if fade_time > 0.0:
		fade_time = 0.0


func raise_obsidian(seconds: float) -> void:
	obsidian_time = maxf(obsidian_time, seconds)
	Sfx.cue("Obsidian Armor", "barrier", center())


## A wave takes hold of the wizard and carries them, whichever way it runs.
func start_surf(direction: float, seconds: float) -> void:
	surf_dir = signf(direction) if direction != 0.0 else facing
	surf_time = seconds


## True while black glass keeps lava from hurting.
func lava_proof() -> bool:
	return marks & OBSIDIAN != 0 if is_likeness() else obsidian_time > 0.0


func is_blind() -> bool:
	return blind_time > 0.0


func status_text() -> String:
	var parts: Array[String] = []
	if mute_time > 0.0:
		parts.append("Muted")
	return "   ".join(parts)


## A soft shadow on the ground under the wizard. It shrinks and fades the higher the wizard is above the ground.
func _draw() -> void:
	var below := _ground_distance()
	if below < 0.0:
		return
	var fade := clampf(1.0 - below / 160.0, 0.0, 1.0)
	var width := 15.0 * (0.6 + 0.4 * fade)
	_draw_ellipse(Vector2(0, below), width, width * 0.28, Color(0, 0, 0, 0.32 * fade))


## How far below the feet the ground is, or -1 if there is none within reach.
func _ground_distance() -> float:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 200))
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y - global_position.y if not hit.is_empty() else -1.0


func _draw_ellipse(at: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		points.append(at + Vector2(cos(TAU * i / 20.0) * rx, sin(TAU * i / 20.0) * ry))
	draw_colored_polygon(points, color)


func _physics_process(delta: float) -> void:
	if is_likeness():
		_follow()
		coat.tick(delta)
		bubbles.tick()
		return
	eyes.follow(delta)
	if brain != null and global_position.y > (ArenaGen.world_size.y * float(ArenaGen.TILE) if ArenaGen.world_size.y > 0 else FALL_LIMIT) and not dead:
		wolf.lose()
		golem.lose()
		max_stamina = 0.0  # off the bottom of the map
		_check_death()
	if brain != null and not dead:
		_think(delta)
	_tick_timers(delta)
	_fall(delta)
	var can_move := movement_enabled and root_time <= 0.0 and not dead and not fainted
	vine.tick(delta)
	if can_move and is_on_floor() and pad.drops():
		_drop_time = 0.3
	_drop_time -= delta
	set_collision_mask_value(5, _drop_time <= 0.0)
	if can_move and vine.climb():
		_air_vx = 0.0  # hanging on a vine there is no sideways speed to carry
		_placed_at = global_position  # (the vine moved the wizard itself)
		return
	_steer(delta, can_move)
	_shoved(delta, can_move)
	_move_on(delta)


## The timers and the stamina of a frame: what runs out, what comes back, the breath.
func _tick_timers(delta: float) -> void:
	_grace -= delta
	for id: int in _source_grace.keys():
		_source_grace[id] -= delta
		if _source_grace[id] <= 0.0:
			_source_grace.erase(id)
	drained_time = maxf(drained_time - delta, 0.0)
	_veil_cool -= delta
	if fainted:
		_faint_left -= delta
		_since_spend = 0.0  # nothing comes back while they are down
		if _faint_left <= 0.0:
			fainted = false
			stamina = maxf(stamina, GET_UP)  # up again
	lungs.tick(delta)
	coat.tick(delta)
	mending.tick(delta)
	bubbles.tick()
	_feathers.emitting = feather_time > 0.0
	rage_time = maxf(rage_time - delta, 0.0)
	fear_time = maxf(fear_time - delta, 0.0)
	swim_time = maxf(swim_time - delta, 0.0)
	if is_on_floor():
		air_jump_ready = true
	if infinite_time > 0.0:
		stamina = max_stamina
	_since_spend += delta
	if golem.on:
		golem.tick(delta)
	punch.tick(delta)
	if wolf.on:
		wolf.tick(delta)
	elif _since_spend >= REGEN_DELAY and not _stepping:  # it comes back the moment the wizard stops moving their body
		restore_stamina(STAMINA_REGEN * delta)
	queue_redraw()
	_barrier.show_for(_shield_time)


## Gravity, as the wizard is placed: flying, swimming or falling (a feather, a rocket), and the grace for a jump just after leaving the ground.
func _fall(delta: float) -> void:
	if flying:
		_fly(delta)  # no gravity: the air is steered through (see _fly)
	elif swim_time > 0.0:
		velocity.y = move_toward(velocity.y, DIVE_SPEED if pad.dives() else SINK_SPEED, SWIM_GRAVITY * delta)  # in deep water it sinks slowly, or dives
	elif not is_on_floor():
		var light := feather_time > 0.0
		velocity.y = Motion.fallen(velocity.y, gravity, delta, FEATHER_FALL if light else INF)
		if light and velocity.y >= FEATHER_FALL:  # as light as a feather
			_feather_motes -= delta
			if _feather_motes <= 0.0:
				_feather_motes = 0.35
				Fx.burst(get_parent(), center() + Vector2(0, -20), Color(0.92, 0.95, 1.0), 2, 25.0, 0.8, false, "star_04")
	if rocket_time > 0.0:
		velocity.y = -Motion.drive_speed(RocketJump.DRIVE, RocketJump.BURN - rocket_time)  # a rocket: barely off the ground at first, then quicker and quicker
		if is_on_ceiling():
			rocket_time = 0.0
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_jump_buffer -= delta


## What the wizard does with its legs: jumps, and runs or walks (or stands, when it cannot move).
func _steer(delta: float, can_move: bool) -> void:
	if global_position.distance_squared_to(_placed_at) > 4.0:
		_air_vx = 0.0  # put somewhere else by a step, a teleport or a portal: the speed it had does not come along
	if can_move:
		if pad.jump_pressed():
			request_jump()
		if flying:
			_jump_buffer = 0.0  # there is nothing to jump from: the wizard steers
		if swim_time > 0.0 and _jump_buffer > 0.0:
			velocity.y = -SWIM_STROKE  # a stroke of the arms: it costs nothing
			_jump_buffer = 0.0
		elif _jump_buffer > 0.0 and _coyote > 0.0 and sink_time <= 0.0 and tangle_time <= 0.0 and (wolf.on or golem.on or spend(JUMP_COST, false)):
			velocity.y = JUMP_VELOCITY * _jump_strength * (GolemForm.JUMP if golem.on else 1.0)  # a golem jumps low and comes down hard
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.speak(self, WizardLook.jump_sound(look), global_position)
		elif _jump_buffer > 0.0 and air_jump_time > 0.0 and air_jump_ready and sink_time <= 0.0 and tangle_time <= 0.0 and not golem.on and not is_on_floor():
			# The second leap: a jump in the air, free of stamina, once per landing.
			velocity.y = JUMP_VELOCITY * float(BodyStates.TABLE["skystep"]["air_jump"])
			_jump_buffer = 0.0
			air_jump_ready = false
			Sfx.speak(self, WizardLook.jump_sound(look), global_position)
		# Letting go of jump early cuts the jump short, so small hops are easy.
		if pad.jump_released() and velocity.y < JUMP_VELOCITY * 0.4 and swim_time <= 0.0 and not flying:
			velocity.y = JUMP_VELOCITY * 0.4
		# Walking is free; running drains stamina. With none left you still walk, at half speed.
		var speed := _walking_speed()
		var wanted := pad.walking(speed)
		if is_on_floor() and absf(_shove.x) < 20.0 and _shove.y > -20.0:
			_launched = false  # back on the ground and the throw spent: the next jump is their own
		if _in_free_air():
			# Nothing to push against: the keys only add to the speed the wizard already has, up to half a walking pace, and can turn it slowly.
			# They never brake a speed already beyond it (a blow's), and letting go of them changes nothing.
			_air_vx = Motion.steered(_air_vx, wanted, _launched and not golem.on, delta)  # (a jump they chose: they steer, brake and turn as freely as on the ground)
			velocity.x = _air_vx
		else:
			velocity.x = wanted
			_air_vx = wanted
		_stepping = absf(velocity.x) > 10.0 and not flying  # (flying is not a body's work: the stamina comes back all the while)
		if is_on_floor() and absf(velocity.x) > 10.0 and stamina > 0.0 and not wolf.on:
			drain(RUN_COST * delta, false)
	else:
		velocity.x = 0.0
		_air_vx = 0.0
		_stepping = false


## Gives the wizard a sideways speed to carry through the air: a push off a vine, say.
func carry(speed: float) -> void:
	_air_vx = speed


## In the air with nothing under the wizard to push off, and nothing carrying them (not flying, not swimming, not riding a wave):
## the sideways speed is then the wizard's own momentum.
func _in_free_air() -> bool:
	return not is_on_floor() and not flying and swim_time <= 0.0 and surf_time <= 0.0


## How fast the wizard walks now: half of it when out of stamina, and each thing that slows, mires, tangles, hastens, armors or changes the wizard
## on top of that.
func _walking_speed() -> float:
	return (SPEED if stamina > 0.0 or wolf.on else SPEED * 0.5) * (BodyStates.pace("slowed") if slow_time > 0.0 else 1.0) * (BodyStates.pace("mired") if sink_time > 0.0 else 1.0) * (BodyStates.pace("tangled") if tangle_time > 0.0 else 1.0) * (BodyStates.pace("hasted") if haste_time > 0.0 else 1.0) * (BodyStates.pace("heavy") if obsidian_time > 0.0 else 1.0) * (WildShape.SPEED if wolf.on else 1.0) * (GolemForm.SPEED if golem.on else 1.0) * (BodyStates.pace("drained") if drained_time > 0.0 else 1.0)


## What moves the wizard that it did not choose: a wave, ice, fear, a shove and the wind.
func _shoved(delta: float, can_move: bool) -> void:
	if surf_time > 0.0 and not dead and not fainted:
		velocity.x = surf_dir * Motion.drive_speed(SURF, 0.0)  # a wave does not wait for the wizard
	var grip := OIL_GRIP if OilSlick.under(get_tree(), global_position) else (ICE_GRIP if IceSheet.under(get_tree(), global_position) else 0.0)
	if is_on_floor() and can_move and grip > 0.0:
		_slide = move_toward(_slide, velocity.x, grip * delta)  # on ice a wizard cannot stop or turn quickly
		velocity.x = _slide
	else:
		_slide = velocity.x
	if fear_time > 0.0 and is_instance_valid(afraid_of) and signf(velocity.x) == signf(afraid_of.global_position.x - global_position.x):
		velocity.x = 0.0  # they will not go toward the one they flee
		_slide = 0.0
		_air_vx = 0.0
	velocity.x += _shove.x + wind
	if _shove.y < 0.0:
		velocity.y = minf(velocity.y, _shove.y)
	# On the ground a shove dies away at once; in the air there is nothing to stop it, so a blow carries the wizard on and the keys cannot cancel it.
	_shove = Motion.shed(_shove, _in_free_air(), delta)


## The step itself: the AI's hop up a ledge, the move, the map's edges and the sound of the steps.
func _move_on(delta: float) -> void:
	# Walking into a ledge one tile high: a small hop lifts the AI wizards up it. A person jumps for themselves.
	if brain != null and is_on_floor() and is_on_wall() and absf(velocity.x) > 10.0 and not dead and sink_time <= 0.0 and tangle_time <= 0.0:
		velocity.y = minf(velocity.y, -330.0)
	if drawn:
		velocity = Vector2.ZERO
	var fell_at := velocity.y if not is_on_floor() else 0.0  # how fast they were falling as they reached the ground, if they did
	var was_at := global_position
	move_and_slide()
	_get_out_of_rock(delta, was_at)
	if is_on_floor() and fell_at > LAND_SPEED and not flying and swim_time <= 0.0 and surf_time <= 0.0:
		Sfx.cue("wizard", "land_mud" if sink_time > 0.0 else _ground_sound("land"), global_position, minf((fell_at - LAND_SPEED) / 400.0, 1.0) * 4.0)
	if is_on_wall():
		_air_vx = 0.0  # a wall stops the sideways speed it was carrying
		_shove.x = 0.0
	# A character pushed out of the map's sides is put back inside.
	global_position.x = clampf(global_position.x, ArenaGen.left_edge() + 12.0, ArenaGen.right_edge() - 12.0)
	if flying and fly_box.size != Vector2.ZERO:  # the sky has no walls, but a wizard that reaches the end of it simply stops
		var held := global_position.clamp(fly_box.position, fly_box.end)
		if not is_equal_approx(held.y, global_position.y):
			velocity.y = 0.0
		global_position = held
	_placed_at = global_position
	# A step is a foot set down by a wizard walking or running on the ground under their own power: not a ride on a wave, a slide on a shove,
	# a swim, a fall or a flight (the keys must be held, and the wizard must actually be moving).
	if is_on_floor() and _stepping and absf(velocity.x) > 10.0 and surf_time <= 0.0 and swim_time <= 0.0 and absf(_shove.x) < 20.0:
		_step -= delta
		if _step <= 0.0:
			_step = STEP_EVERY
			Sfx.cue("wizard", "step_mud" if sink_time > 0.0 else _ground_sound("step"), global_position)  # in mud, a squelch


## Squeezed into rock (by a stair swinging shut, say), a body falls or stands there and goes nowhere: it is put back where it last stood firmly, in the open.
func _get_out_of_rock(delta: float, was_at: Vector2) -> void:
	if flying or drawn or is_likeness():
		return
	if was_at.distance_squared_to(_was_last) > 250000.0:  # put somewhere far off (a portal, a Rift): what went before is not where it belongs (a step through the shadows goes less far)
		_firm = Vector2.INF
		_wedged = 0.0
	_was_last = global_position
	var still := global_position.distance_squared_to(was_at) < 4.0
	if is_on_floor() and velocity.length_squared() < 1.0:
		_firm_for += delta
		if _firm_for > 0.3 and not _in_rock():
			_firm = global_position
			_firm_for = 0.0
			_wedged = 0.0
	else:
		_firm_for = 0.0
	_rock_look -= delta
	if _rock_look <= 0.0:
		_rock_look = 0.2
		_rock_about = _in_rock()
	_wedged = _wedged + delta if still and (velocity.y > WEDGED_SPEED or (_rock_about and velocity.length() > STRUGGLES)) else 0.0
	if _wedged > WEDGED_FOR and _firm != Vector2.INF:
		_wedged = 0.0
		_rock_about = false
		global_position = _firm
		velocity = Vector2.ZERO
		reset_physics_interpolation()


## The middle of its body is inside rock, as the world has it (its rock is outlines: physics cannot say what is inside one).
func _in_rock() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as World
	return world != null and world.in_rock(global_position + Vector2(0.0, -24.0)) and world.in_rock(global_position + Vector2(0.0, -40.0))


## The name of the sound a wizard makes on the ground under them: kind is "step" or "land".
func _ground_sound(kind: String) -> String:
	return kind + STEP_SOUNDS.get(ArenaGen.biome_name_at(global_position.x), "step_dirt").trim_prefix("step")


## Out of its depth in a sea (see Pond.deep): the water holds the wizard up for a moment, and the call comes again each frame while it is there.
func swim() -> void:
	swim_time = 0.2


## Flying, in a world with no ground: steered up and down by the keys (or by a brain, through the pad), and drifting down at its own pace when nothing is asked.
func _fly(delta: float) -> void:
	var free := movement_enabled and root_time <= 0.0 and not dead and not fainted and not drawn
	var ask := 0.0
	if free:
		ask = pad.flying_ask()
	var pace := FLY_SPEED * (BodyStates.pace("slowed") if slow_time > 0.0 else 1.0) * (BodyStates.pace("tangled") if tangle_time > 0.0 else 1.0) * (BodyStates.pace("hasted") if haste_time > 0.0 else 1.0)
	velocity.y = move_toward(velocity.y, ask * pace if ask != 0.0 else FLY_DRIFT, FLY_ACCEL * delta)


## Blessing of Skystep: one extra jump in the air, for a while.
func grant_haste(seconds: float) -> void:
	haste_time = maxf(haste_time, seconds)


func grant_air_jump(seconds: float) -> void:
	air_jump_time = maxf(air_jump_time, seconds)
	air_jump_ready = true


func grant_unlimited(seconds: float) -> void:
	infinite_time = maxf(infinite_time, seconds)
	stamina = max_stamina


## A Push on the caster: they are shoved along the line for a moment.
func pull(force: Vector2, delta: float) -> void:
	if is_likeness():
		return
	free_from_ground()
	if _in_free_air():
		# Every pull was tuned against a shove shedding SHOVE_SHED each second. In the air it sheds only AIR_DRAG, so the rest is taken off the pull itself
		# and a pull is no stronger in the air than it ever was; what is new is that the keys cannot walk out of it.
		force.x = move_toward(force.x, 0.0, SHOVE_SHED - AIR_DRAG)
	_launched = true
	_shove += force * delta
	if _uses_parts():
		pose.pulled(force)


## What chance does to this wizard (see Dice).
func dice() -> RandomNumberGenerator:
	if _dice == null or _dice_of != Dice.begun:
		_dice = Dice.of(["wizard", String(name)])
		_dice_of = Dice.begun
	return _dice


func push(impulse: Vector2) -> void:
	if is_likeness():
		return
	free_from_ground()
	_launched = true
	_shove = impulse
	if _uses_parts():
		pose.shoved(impulse)


## Anything that moves the body out of the ground (a push, a pull, a blink, a knock) frees it. It can be stuck again only
## by the next stomp.
func free_from_ground() -> void:
	if _stuck_time > 0.0:
		root_time = 0.0
		unstick()


## A giant's stomp sticks the player in the ground: their body sinks down out of sight, and they cannot move or jump
## until it lets go.
func stick_in_ground(seconds: float) -> void:
	if is_likeness():
		return
	apply_debuff("root", seconds)
	_stuck_time = maxf(_stuck_time, seconds)
	_set_keep(0.7)
	# The cut is 57 px above the frame's bottom, so this drops the cut onto the ground: the body is in the ground from there down.
	_sprite.position = Vector2(0, 57)


## Lets the player out of the ground, as a throw does.
func unstick() -> void:
	_stuck_time = 0.0
	_set_keep(2.0)
	_sprite.position = Vector2.ZERO


## The body is drawn this far above where it stands: a wizard riding a wave stands on top of the water (Tide Surf). Only how they look moves, not where they are.
func ride_lift(height: float) -> void:
	_ride_lift = height
	_sprite.position.y = -height if _stuck_time <= 0.0 else 57.0
	if _magic != null:
		_magic.position.y = -height


func _process(delta: float) -> void:
	if not is_likeness():
		_tell_others()
	elif (marks & STUCK != 0) != (_sprite.position.y != 0.0):
		_set_keep(0.7 if marks & STUCK != 0 else 2.0)  # sunk in the ground, as on the machine that drives it
		_sprite.position = Vector2(0, 57) if marks & STUCK != 0 else Vector2.ZERO
	if _stuck_time > 0.0:
		_stuck_time -= delta
		if _stuck_time <= 0.0:
			unstick()
	_animate(delta)
	if is_person() and _uses_parts() and Engine.get_process_frames() % 4 == 0 and not casting:
		PartFrames.warm_next(_sprite.sprite_frames)  # (all of the wizard's animations are made in the first seconds, a few at a time)
		PartFrames.warm_next(_magic.sprite_frames)
	_overlay.queue_redraw()


## Picks the animation for what the wizard is doing, faces the way it is moving, and flashes when hit.
func _animate(delta: float) -> void:
	var parts := _uses_parts()
	if absf(velocity.x) > 10.0 and not dead and not is_likeness():
		facing = signf(velocity.x)  # a person's wizard and a brain's face the way they move, whatever turned them: nobody runs backwards (a brain turns to its rival only standing)
	if _in_free_air() and not dead and not is_likeness() and not casting and absf(pad.sideways()) > 0.3:
		facing = signf(pad.sideways())  # trying to go the other way in the air: the wizard turns to face it, though the carried speed has not turned yet
	_releasing = maxf(_releasing - delta, 0.0)
	_hurt_anim = maxf(_hurt_anim - delta, 0.0)
	var wanted := "idle"
	if is_likeness():
		wanted = shown_anim
	elif parts:
		pose.tick(delta)
		wanted = pose.pick(delta)
	elif dead or fainted:
		wanted = "death"
	elif golem.shown and golem.anim() != "":
		wanted = golem.anim()  # standing up, a smash, a landing
	elif _hurt_anim > 0.0:
		wanted = "hit"
	elif _releasing > 0.0:
		wanted = "release"
	elif casting:
		wanted = "cast"
	elif flying:
		wanted = "jump" if velocity.y < -40.0 else "fall"  # (there is no ground to run on: it rises or it falls, whichever way it steers, owner 2026-11-12)
	elif not is_on_floor():
		wanted = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x - wind) > 10.0:  # the wind can push a wizard along without a step
		wanted = "run"
	var set_in_ice := is_frozen() and not dead  # held on the very frame it was caught on
	if parts and not set_in_ice and not PartFrames.ensure(_sprite.sprite_frames, wanted):
		wanted = "idle"  # (an animation there is no such thing as: another machine's)
	if set_in_ice:
		wanted = String(_sprite.animation)  # held in the pose it was caught in
	elif _sprite.animation != wanted:
		_sprite.play(wanted)
	elif parts and pose.restart:
		_sprite.play(wanted)
		_sprite.set_frame_and_progress(0, 0.0)  # the same animation again from its first frame
	pose.restart = false
	_sprite.speed_scale = 0.0 if set_in_ice else 1.0  # nothing moves inside the ice
	shown_anim = wanted
	_sprite.flip_h = (look_dir if look_dir != 0.0 and parts else facing) < 0.0
	if parts and wanted == "turn" and _sprite.frame < 1:
		_sprite.flip_h = not _sprite.flip_h  # a turn begins facing the old way and swings round at its second frame
	_flash = maxf(_flash - delta, 0.0)
	# After a hit the wizard blinks while it can't be hurt again.
	var blink := _grace > 0.0 and int(_grace * 20.0) % 2 == 0
	lungs.dry(delta)
	if is_unseen() != _hidden:  # a wizard faded from sight is not drawn at all for anyone but themselves (the wizard is left as it was when it comes back)
		_hidden = is_unseen()
		visible = not _hidden
	_sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color(1.0, 1.0, 1.0, 0.55 if blink else (FADE_ALPHA if is_faded() else 1.0))
	var glassy := marks & OBSIDIAN != 0 if is_likeness() else obsidian_time > 0.0
	var veiled := marks & VEILED != 0 if is_likeness() else veil > 0
	_body_material.set_shader_parameter("obsidian", 1.0 if glassy and _flash <= 0.0 else 0.0)  # black glass with a sheen running over it
	_body_material.set_shader_parameter("aura", 1.0 if veiled and _flash <= 0.0 else 0.0)  # a wizard under a Crimson Veil is tinted red while it holds
	if _magic.visible:
		if cast_color != Color.WHITE and casting:
			_gem = cast_color  # the gem takes the school of the spell being drawn, and keeps it
		_magic.paint(_magic_color(_sprite.animation))
		_magic.mirror(_sprite)  # (it fades and blinks with the body, but does not flash red)


## Called when a spell goes off: the wizard thrusts its staff forward once.
func play_cast_release() -> void:
	_releasing = 0.3
	_sprite.play("release")


# --- A wizard that a brain plays -------------------------------------------------------------------------------


## A brain's wizard casts from strokes of its own, never from the mouse: the arena reads them as it does yours.
func _make_caster() -> void:
	caster = Caster.new()
	add_child(caster)
	caster.set_process(false)
	caster.ground_check = Callable(get_parent(), "_is_ground_at")
	caster.cast_resolved.connect(get_parent().casting.by.bind(self))
	caster.misfired.connect(get_parent().casting.misfire_by.bind(self))  # a stroke that means nothing costs what it costs a person


## The caster that reads a stroke into a spell: a brain's wizard has one always, and a person's is made when something other than their own hand
## has to cast for them (Fight or Flight).
func ensure_caster() -> Caster:
	if caster == null:
		_make_caster()
	return caster


## A brain's wizard speaks a chant (see Arena.chant_by).
func chant(id: String) -> bool:
	return get_parent().chant_by(self, id)


## The brain's turn: a spell it is drawing goes off when the stroke is done, and then it decides what to do next.
func _think(delta: float) -> void:
	if fainted or is_frozen():  # down, or in a block of ice: nothing is drawn
		pen.drop()
		pad.walk = 0.0
		return
	pen.tick(delta)
	caster.anchor = center()
	brain.think(delta)
	if brain.holds_still():
		pad.walk = 0.0  # it stops to draw


## A brain asks to walk at a speed, left (negative) or right: the body keeps to what it can do.
func walk(speed: float) -> void:
	pad.walk = speed


## A jump, asked for as a person asks with the key: it happens if the wizard is on the ground (or just left it) and has the stamina.
## A brain steps down through the wooden platform it stands on (a person holds S).
func drop_through() -> void:
	if is_on_floor():
		_drop_time = 0.3


## A brain asks for a part of a full jump for a hop.
func request_jump(strength := 1.0) -> void:
	_jump_buffer = JUMP_BUFFER
	_jump_strength = strength


## Drops the spell being drawn, with a puff of sparks so a rival can see it was broken.
func interrupt_cast() -> void:
	if not pen.interrupt():
		return
	_show_interrupt()
	Net.send(self, &"_show_interrupt")


@rpc("authority", "call_remote", "reliable")
func _show_interrupt() -> void:
	Fx.burst(get_parent(), center() + Vector2(facing * 14.0, -16.0), cast_color, 14, 140.0, 0.4, true)
	FloatText.spawn(get_parent(), center() + Vector2(0, -44), "Interrupted!", Color("#d9b8ff"), 0.9)
	Sfx.cue("wizard", "misfire", center())


## Things drawn over the sprite: the stroke any other wizard is drawing (a brain's, or a
## person's on another machine), which grows as the spell does so that it can be read and broken. Your own is the caster's trail.
func _draw_overlay() -> void:
	if dead:
		return
	if shown_words != "" and not is_person():  # the words of a chant, as they are typed: a stroke is seen being drawn, and so are these
		var font := ThemeDB.fallback_font
		var size := 13
		var width := font.get_string_size(shown_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(clampf(-width * 0.5, -150.0, 0.0), -BODY_HEIGHT - 26.0)
		_overlay.draw_string_outline(font, at, shown_words, HORIZONTAL_ALIGNMENT_LEFT, 300.0, size, 4, Color(0.05, 0.03, 0.02, 0.9))
		_overlay.draw_string(font, at, shown_words, HORIZONTAL_ALIGNMENT_LEFT, 300.0, size, Color(0.93, 0.85, 0.62))
	if shown_stroke.size() >= 2 and not is_person():
		var local := PackedVector2Array()
		for point in shown_stroke:
			local.append(point - global_position)
		var c := cast_color
		_overlay.draw_polyline(local, Color(c.r, c.g, c.b, 0.25), 7.0)
		_overlay.draw_polyline(local, Color(c.r, c.g, c.b, 0.9), 3.0)
		_overlay.draw_polyline(local, Color(1.0, 1.0, 1.0, 0.9), 1.0)
		Fx.draw_glow(_overlay, local[local.size() - 1], 8.0, Color(c.r, c.g, c.b, 0.9))


func is_rooted() -> bool:
	return marks & ROOTED != 0 if is_likeness() else root_time > 0.0


func is_slowed() -> bool:
	return marks & SLOWED != 0 if is_likeness() else slow_time > 0.0


## True while the wizard stands on something. A likeness is not moved by physics here, so it says what its own machine says.
func stands() -> bool:
	return marks & GROUNDED != 0 if is_likeness() else is_on_floor()


# --- In a network game (see Net) ---------------------------------------------------------------------------------------


## The name a person's wizard has in a network game, the same on every machine.
static func name_for(peer_id: int) -> String:
	return "Wizard%d" % peer_id


func _enter_tree() -> void:
	set_multiplayer_authority(peer if peer != 0 else multiplayer.get_unique_id())


## True for the wizard this machine's person plays: the keys and the mouse drive it, and the camera, book and bar are its.
func is_person() -> bool:
	return brain == null and is_multiplayer_authority()


## A blow shakes the screen of whoever plays this wizard, and nobody else's (owner, 2026-11-12: a screen shook whenever any wizard anywhere was hurt):
## the camera when it is this machine's person, the AI's own screen (Eyes) when a brain plays it.
func _shake_own_screen(amount: float) -> void:
	if is_person():
		GameCamera.shake_scene_camera(get_tree(), amount)
	if eyes != null:
		eyes.shake(amount)


## True for a likeness of a wizard another machine drives: it shows what that machine says and decides nothing itself.
func is_likeness() -> bool:
	return not is_multiplayer_authority()


## Shows this wizard to the other machines in the same scene: a MultiplayerSynchronizer sends what they need to draw it from the
## machine that drives it, many times a second. Things that change now and then are sent only when they change.
func share() -> void:
	var config := SceneReplicationConfig.new()
	for property in ["net_position", "velocity", "facing", "stamina", "max_stamina", "cast_color", "casting"]:
		config.add_property(NodePath(".:" + property))
		config.property_set_replication_mode(NodePath(".:" + property), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for property in ["dead", "fainted", "shown_anim", "shown_stroke", "marks", "visible", "modulate", "look", "palette", "shown_words", "look_dir"]:
		config.add_property(NodePath(".:" + property))
		config.property_set_replication_mode(NodePath(".:" + property), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.root_path = NodePath("..")
	sync.replication_config = config
	sync.add_visibility_filter(Net.is_here)  # nothing is sent to a machine that has not got this scene yet
	sync.set_multiplayer_authority(get_multiplayer_authority())  # a node added later does not take its parent's driver by itself
	add_child(sync)


## On the machine that drives the wizard: what the others are sent (see share).
func _tell_others() -> void:
	net_position = global_position
	marks = (FROZEN if is_frozen() else 0) | (SHIELDED if has_shield() else 0) | (OBSIDIAN if obsidian_time > 0.0 else 0) | (STUCK if _stuck_time > 0.0 else 0) 			| (GROUNDED if is_on_floor() else 0) | (ROOTED if is_rooted() else 0) | (SLOWED if is_slowed() else 0) | (FADED if fade_time > 0.0 else 0) | (VEILED if veil > 0 else 0) | (WILD if wolf.on else 0) | (GOLEM if golem.shown else 0) | (WET if wet_time > 0.0 else 0) | (BURNING if burning_time > 0.0 else 0) | (OILED if oiled_time > 0.0 else 0)
	if brain != null:
		shown_stroke = pen.so_far()


## A likeness glides to where its wizard is, or jumps there when it went far at once, and falls when its wizard does.
func _follow() -> void:
	wolf.follow(marks & WILD != 0)
	golem.follow(marks & GOLEM != 0)
	if global_position.distance_to(net_position) > SNAP:
		global_position = net_position
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(net_position, GLIDE)
	if dead:
		_pass_away()
	queue_redraw()
	_barrier.show_for(1.0 if has_shield() else 0.0)


## A likeness of a person beaten in an earlier world of the match: it is out, unseen, as on their own machine.
func stay_fallen() -> void:
	dead = true
	_passed = true
	collision_layer = 0
	hide()


## The person who played this wizard has left the game: it falls where it stands and fades, and nothing more is heard from it.
func abandon() -> void:
	var sync := get_node_or_null("Sync")
	if sync != null:
		sync.queue_free()
	dead = true
	shown_anim = &"death"
	_pass_away()
	create_tween().tween_property(self, "modulate:a", 0.0, 0.8).set_delay(1.2)


## The machine that drives this wizard says it was hurt: the flash, the cry and the number, as there.
## A mob on the host's machine struck this wizard, which only the machine that drives it can feel.
@rpc("any_peer", "call_remote", "reliable")
func _struck_by_a_mob(amount: int, impulse: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	take_damage(amount)
	if impulse != Vector2.ZERO:
		push(impulse)


@rpc("authority", "call_remote", "unreliable_ordered")
func _show_hurt(amount: int) -> void:
	damaged.emit(amount)  # (a Vacuum let go of when its caster is hurt listens to this, on every machine)
	_flash = 0.3
	Sfx.speak(self, WizardLook.hurt_sound(look), center())
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d" % amount, Color("#ff5a5a"), 1.1)
