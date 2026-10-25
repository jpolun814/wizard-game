class_name Mob
extends CharacterBody2D

## An enemy. Each one has a role (melee walker, ranged shooter, flyer, or wizard) and a school. The school sets its
## colour and what it is weak or resistant to. Some schools also give their enemies a particular trick.
## The creatures are LuizMelo's skeleton, goblin, mushroom and flying eye, and the dark wizard is his Evil Wizard
## (art/mobs, art/chars). Each keeps its own colours with an outline in its school's colour. "scale" draws a
## creature bigger, always at a whole number of pixels so the pixel art stays sharp.
## A walker's origin is at its feet, so it stands exactly on the ground; a flyer's is the middle of its body.
## Every attack is telegraphed: walkers wind up, shooters charge a glow, flyers hover before they dive.

const KINDS := {
	"basic": {"name": "Basic", "desc": "Has no weakness and no resistance.", "role": "melee", "art": "skeleton", "hp": 30, "school": "", "weak": "", "resist": "", "damage": 8, "speed": 1.0, "effect": ""},
	"dark_wizard": {"name": "Dark Wizard", "desc": "Casts your own spells. Hit it while it draws to break its cast.", "role": "wizard", "art": "dark_wizard", "scale": 1.0, "hp": 120, "school": "Shadow", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": ""},
	"pyre_wizard": {"name": "Pyre Wizard", "desc": "Casts your own spells. Hit it while it draws to break its cast.", "role": "wizard", "art": "pyre_wizard", "scale": 1.5, "hp": 120, "school": "Shadow", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": ""},
	"bone_wizard": {"name": "Bone Wizard", "desc": "Casts your own spells. Hit it while it draws to break its cast.", "role": "wizard", "art": "bone_wizard", "scale": 1.5, "hp": 120, "school": "Shadow", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": ""},
	"force_melee": {"name": "Melee Air", "desc": "Hits hard enough to send people flying.", "role": "melee", "art": "skeleton", "hp": 30, "school": "Air", "weak": "", "resist": "", "damage": 8, "speed": 1.0, "effect": "big_knockback"},
	"force_ranged": {"name": "Ranged Air", "desc": "Fires orbs from a distance.", "role": "ranged", "art": "goblin", "hp": 24, "school": "Air", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.2, "damage": 6}},
	"force_flyer": {"name": "Flying Air", "desc": "Swoops down.", "role": "flyer", "art": "eye", "hp": 22, "school": "Air", "weak": "", "resist": "", "damage": 6, "speed": 1.0, "effect": ""},
	"fire_melee": {"name": "Melee Fire", "desc": "Sets alight whatever it touches.", "role": "melee", "art": "skeleton", "hp": 30, "school": "Fire", "weak": "Water", "resist": "Fire", "damage": 8, "speed": 1.0, "effect": "burning"},
	"fire_ranged": {"name": "Ranged Fire", "desc": "Hurls fireballs.", "role": "ranged", "art": "goblin", "hp": 24, "school": "Fire", "weak": "Water", "resist": "Fire", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.4, "damage": 8, "art": "fireball"}},
	"fire_flyer": {"name": "Flying Fire", "desc": "Drops fireballs as it flies.", "role": "flyer", "art": "eye", "hp": 22, "school": "Fire", "weak": "Water", "resist": "Fire", "damage": 6, "speed": 1.0, "effect": "", "shot": {"interval": 1.4, "damage": 6, "drop": true}},
	"ice_melee": {"name": "Melee Water", "desc": "Leaves falling snow that slows.", "role": "melee", "art": "skeleton", "hp": 34, "school": "Water", "weak": "Fire", "resist": "Water", "damage": 6, "speed": 0.9, "effect": "frost_trail"},
	"ice_ranged": {"name": "Ranged Water", "desc": "Fires bolts that slow.", "role": "ranged", "art": "goblin", "hp": 24, "school": "Water", "weak": "Fire", "resist": "Water", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.0, "damage": 4, "slow": true}},
	"ice_flyer": {"name": "Flying Water", "desc": "Drops icicles that slow.", "role": "flyer", "art": "eye", "hp": 22, "school": "Water", "weak": "Fire", "resist": "Water", "damage": 4, "speed": 1.0, "effect": "", "shot": {"interval": 1.8, "damage": 3, "slow": true, "drop": true}},
	"earth_melee": {"name": "Melee Earth", "desc": "Hits hard and knocks back.", "role": "melee", "art": "skeleton", "hp": 48, "school": "Earth", "weak": "Water", "resist": "Earth", "damage": 14, "speed": 0.6, "effect": "knockback"},
	"earth_ranged": {"name": "Ranged Earth", "desc": "Hurls boulders in an arc.", "role": "ranged", "art": "goblin", "hp": 28, "school": "Earth", "weak": "Water", "resist": "Earth", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.6, "damage": 10, "gravity": 420.0}},
	"earth_flyer": {"name": "Flying Earth", "desc": "Drops boulders as it flies.", "role": "flyer", "art": "eye", "hp": 26, "school": "Earth", "weak": "Water", "resist": "Earth", "damage": 8, "speed": 1.0, "effect": "", "shot": {"interval": 2.2, "damage": 8, "gravity": 300.0, "drop": true}},
	"storm_melee": {"name": "Melee Wind", "desc": "Fast. Explodes on contact.", "role": "melee", "art": "skeleton", "hp": 20, "school": "Air", "weak": "Earth", "resist": "Air", "damage": 35, "speed": 2.6, "effect": "explode"},
	"storm_ranged": {"name": "Ranged Wind", "desc": "Fires a fan of zaps.", "role": "ranged", "art": "goblin", "hp": 24, "school": "Air", "weak": "Earth", "resist": "Air", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.4, "damage": 5, "spread": 3}},
	"storm_flyer": {"name": "Flying Wind", "desc": "Dives, then flies away.", "role": "flyer", "art": "eye", "hp": 22, "school": "Air", "weak": "Earth", "resist": "Air", "damage": 8, "speed": 1.4, "effect": ""},
	"dummy": {"name": "Dummy", "desc": "Never falls. Test your spells on it.", "role": "melee", "art": "skeleton", "hp": 300, "school": "", "weak": "", "resist": "", "damage": 0, "speed": 0.0, "effect": "dummy"},
	"turret": {"name": "Turret", "desc": "Never falls. Fires plain bolts.", "role": "ranged", "art": "goblin", "hp": 300, "school": "", "weak": "", "resist": "", "damage": 0, "speed": 0.0, "effect": "dummy", "shot": {"interval": 2.0, "damage": 6}},
	"ninja": {"name": "Ninja", "desc": "Fragile and quick. Throws stars in a pack.", "role": "ranged", "art": "ninja", "scale": 1.0, "hp": 14, "school": "", "weak": "", "resist": "", "damage": 0, "speed": 2.4, "effect": "acrobatic", "shot": {"interval": 1.6, "damage": 5, "art": "ninja_star", "burst": 5, "charge": 0.06}},
	"giant": {"name": "Giant", "desc": "Slow and tough. Smashes stone walls.", "role": "melee", "art": "giant", "scale": 6.0, "hp": 260, "school": "", "weak": "", "resist": "", "damage": 30, "speed": 0.75, "effect": "smash"},
}
const SPEED := 80.0
const TERMINAL_FALL := 900.0  # no enemy falls faster than this
const FALL_LIMIT := 800.0     # an enemy below this has fallen off the map and is removed
const CONTACT_RANGE := 40.0   # how close (middle to middle) a walker must be to hit
const CONTACT_COOLDOWN := 1.1
const WINDUP := 0.3           # a walker draws back this long before it hits
const SMASH_WINDUP := 0.9   # a giant draws its leg back this long before it stomps
const SMASH_REACH := 130.0  # how far in front of it a smash lands
const SMASH_HEIGHT := -50.0 # and how high up: about where a giant's stomp lands
const SMASH_WALL_DAMAGE := 200.0  # a smash breaks a stone wall or a boulder outright
const SMASH_MOB_DAMAGE := 20  # and hurts any other enemy close to it
const SMASH_STUCK := 3.0      # the first stomp sticks the player in the ground this long
const SMASH_SPOTS := 8        # the ground the stomp lands on is marked at this many points, from the giant out
const FLIP_TIME := 0.45      # a ninja's backflip, from the moment it leaves the ground to landing
const LEAP_SPEED := 380.0    # how hard a ninja springs away, or hops about, in a flip
const STUNT_MIN := 0.6       # a ninja hops and flips about on its own, this often
const STUNT_MAX := 1.5
const BURST_GAP := 0.09      # the gap between the stars of one burst
const LEAP_RANGE := 110.0    # a ninja this close to the player leaps away in a flip
const GIANT_JUMP := -640.0    # a giant leaps higher than a plain walker: onto ledges, and over walls
const SLASH_RANGE := 70.0    # a ninja this close to the player strikes with its sword
const SLASH_DAMAGE := 6
const SLASH_COOLDOWN := 0.8  # and waits this long between strikes
const CHARGE := 0.45          # a shooter's glow builds this long before it fires
const DIVE_WARNING := 0.4     # a flyer hangs and shakes this long before it dives
const KNOCK_DECAY := 1500.0
const MOB_JUMP := -420.0      # enough to clear two blocks
const MOB_JUMP_HIGH := -560.0 # enough to reach a platform when the player is up on one
const BURST_DAMAGE := 6       # a Stormrunner's explosion hurts everything close by this much
const BURST_RADIUS := 60.0
const DECOY_NOTICE := 520.0    # a decoy this close is noticed, and attacked instead of the player
const SPIT_RANGE := 480.0       # a ranged enemy fires from this far away
const SPIT_STAND_RANGE := 300.0 # and stops walking once it is this close
const FLY_SPEED := 120.0        # how fast a flyer drifts while it patrols
const DIVE_SPEED := 340.0       # how fast a flyer dives at you
const RETREAT_SPEED := 240.0    # how fast it flies away after a dive
const FROST_TRAIL_INTERVAL := 0.8
const SPAWN_TIME := 0.7         # enemies fade in over a summoning circle and cannot act until it is done
const PATROL := 0
const DIVE := 1
const RETREAT := 2
const HOVER := 3
const DRAW_TIME := 0.8          # how long the dark wizard takes to draw a spell
const CREATURE_ANIMATIONS := {
	"idle": {"fps": 8.0}, "walk": {"fps": 10.0}, "attack": {"fps": 14.0, "loop": false},
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
## The dark wizard holds its staff's shadow up while it draws, and throws a burst of shadow when the spell goes off.
const WIZARD_ANIMATIONS := {
	"idle": {"fps": 8.0}, "walk": {"from": "run", "fps": 12.0}, "jump": {"fps": 8.0, "loop": false},
	"fall": {"fps": 8.0}, "channel": {"from": "release", "fps": 8.0, "first": 0, "last": 3},
	"burst": {"from": "cast", "fps": 16.0, "loop": false, "first": 3, "last": 5},
	"hit": {"fps": 10.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
## The dark wizard's hooded body, at its drawn size: its staff and the shadow flame on it are not part of the target.
const WIZARD_BODY := Rect2(-16, -52, 30, 52)

var kind := "basic"  # set before the mob enters the tree
var player: Node2D
var hp := 30
var max_hp := 30
var caster: Caster  # only the dark wizard has one: it casts from its own strokes
var brain: WizardBrain
var stamina := 100.0      # the dark wizard spends stamina on spells, and it regenerates like yours
var last_spell := ""
var _bursting := 0.0  # time left of the dark wizard's burst of shadow as a spell goes off
var _draw_time := 0.0
var _draw_total := DRAW_TIME
var _stroke := PackedVector2Array()
var _stroke_colour := Color.WHITE
var _on_drawn: Callable
var _shield_time := 0.0
var _cooldown := 0.0
var _since_hit := 0.0  # seconds since this enemy was last hurt; a dummy heals once it has been left alone
var _slow_time := 0.0
var _knock_x := 0.0
var _drift := Vector2.ZERO  # a pull (Gravity Well) that fades
var _dead := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _idle_t := 0.0
var facing := 1.0
var _shot_timer := 1.5
var _root_time := 0.0
var _nojump_time := 0.0  # while above zero, the walker cannot jump (mudslide)
var _frozen_time := 0.0
var _flame: Node2D  # a burning walker's flame; it goes out while the walker is frozen
var _relight := 0.0  # seconds until the flame is lit again after a freeze
var _base_scale := 1.0
var _lunge := 0.0        # 1 the moment an enemy attacks, fading to 0: it lunges toward the player
var _windup := 0.0       # counting down to a melee hit
var _flip := 0.0         # counting down a ninja's backflip
var _stuck := 0.0        # how long a giant has been held up by a ledge
var _last_x := 0.0       # where a giant was last frame, to tell whether it is moving
var _slash_cd := 0.0     # counting down to a ninja's next katana strike
var _stunt := 0.5        # counting down to the ninja's next hop and flip
var _burst_left := 0     # stars still to throw in the burst being thrown
var _burst_gap := 0.0    # counting down to the next star of the burst
var _charge := 0.0       # counting down to a shot
var _flash := 0.0
var _liquid := Color.WHITE  # the colour of the water or lava it stands in
var _liquid_time := 0.0
var _spawn := SPAWN_TIME
var _trail_timer := 0.0
var _touch_timer := 0.0  # between the burns a fire walker gives to whoever touches it
const TOUCH_BURN := 6
const RELIGHT_SECONDS := 1.5  # a frozen walker's flame comes back this long after it is freed
var _fly_state := PATROL
var _fly_timer := 2.0
var _fly_goal_x := 0.0
var _fly_target := Vector2.ZERO
var _fly_away := 1.0
var _body_size := Vector2(30, 40)  # the hitbox, in world pixels
var _body_center := Vector2(0, -20)
var _overlay: Node2D               # draws health bar, ice, shield and charge glows on top of the sprite
var _material: ShaderMaterial
@onready var _visual: AnimatedSprite2D = $Visual
var _bubble: AnimatedSprite2D  # the Barrier round the dark wizard
const ICE := preload("res://art/props/ice_fill.png")


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("mobs")
	var data: Dictionary = KINDS[kind]
	if _burns():
		_set_alight()
	max_hp = data.get("hp", 30)
	hp = max_hp
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_overlay)
	if data["role"] == "wizard":
		_build_wizard()
	else:
		_build_creature(data)
	if data["role"] == "flyer":
		collision_mask = 0  # flyers pass through the terrain; they reach you from above
		_fly_goal_x = global_position.x
		_fly_timer = 1.0 + randf() * 2.0
	_shot_timer = 0.8 + randf() * 1.2
	# Every enemy arrives through a summoning circle.
	Fx.pop(get_parent(), global_position + Vector2(0, -2 if not _flies() else 18), "magic_02", _school_colour(), 70.0, SPAWN_TIME + 0.2, 1.2, 1.5)
	Sfx.play("summon", global_position)
	modulate.a = 0.0


## A creature drawn from art/mobs: its frames, its size, and a hitbox that matches the body in the drawing.
func _build_creature(data: Dictionary) -> void:
	var art: String = data["art"]
	var info: Dictionary = PixelArt.CHARACTERS[art]
	_visual.sprite_frames = CharFrames.build("res://art/mobs/" + art, CREATURE_ANIMATIONS)
	if data["effect"] == "smash":
		# The lean is slowed to fill the giant's wind-up, so one pass of it lasts as long as the wind-up does.
		_visual.sprite_frames.set_animation_speed("attack", 7.0)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # scaled-up pixel art stays crisp, not blurred
	_base_scale = data.get("scale", 1.0)
	var body: Rect2 = info["body"]
	var frame: Vector2 = info["size"]
	var hitbox: CollisionShape2D = $CollisionShape2D
	if info["flyer"]:
		# A flyer's frames are centred on the middle of its body; its body is a circle.
		_visual.offset = Vector2.ZERO
		var circle := CircleShape2D.new()
		circle.radius = minf(body.size.x, body.size.y) * 0.5 * _base_scale * 0.9
		hitbox.shape = circle
		_body_center = Vector2.ZERO
		_body_size = Vector2.ONE * circle.radius * 2.0
	else:
		# A walker's frames have its feet on the bottom edge. Its hitbox is its body, not a weapon held out.
		_visual.offset = Vector2(0, -frame.y * 0.5)
		var width := 0.85
		_set_walker_body(Vector2(body.size.x * width, body.size.y * 0.95) * _base_scale)
	hitbox.position = _body_center
	_start_animating()
	_visual.frame = randi() % maxi(1, _visual.sprite_frames.get_frame_count("idle"))


## A walker's hitbox: a box of this size standing on its feet.
func _set_walker_body(size: Vector2) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	var hitbox: CollisionShape2D = $CollisionShape2D
	hitbox.shape = rect
	_body_size = size
	_body_center = Vector2(0, -size.y * 0.5)
	hitbox.position = _body_center


func _start_animating() -> void:
	_apply_material()
	_visual.animation_finished.connect(_on_animation_finished)
	_visual.play("idle")


## The creature's own colours, with a little of its school's colour and an outline in it. Plain enemies get no
## outline at all.
func _apply_material() -> void:
	var school: String = KINDS[kind]["school"]
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/mob.gdshader")
	_material.set_shader_parameter("school_color", _school_colour())
	_material.set_shader_parameter("tint", 0.0 if school in ["", "Shadow"] else 0.22)
	_material.set_shader_parameter("outline", 0.0 if school == "" else 0.9)
	_visual.material = _material


func _school_colour() -> Color:
	var school: String = KINDS[kind]["school"]
	return SpellData.SCHOOL_COLORS.get(school, Color("#d8d0e8"))


func _flies() -> bool:
	return KINDS[kind]["role"] == "flyer"


## The middle of the enemy's body in the world. Spells and the player's aim go here.
func center() -> Vector2:
	return global_position + _body_center


func _physics_process(delta: float) -> void:
	if global_position.y > FALL_LIMIT:
		queue_free()
		return
	_update_flame(delta)
	if _spawn > 0.0:
		_spawn -= delta
		modulate.a = clampf(1.0 - _spawn / SPAWN_TIME, 0.0, 1.0)
		if not _flies():
			_fall(delta)
			velocity.x = 0.0
			move_and_slide()
		return
	modulate.a = 1.0
	_cooldown -= delta
	_since_hit += delta
	if KINDS[kind]["effect"] == "dummy" and _since_hit > 3.0:
		hp = max_hp  # a dummy heals as soon as you stop
	_root_time -= delta
	_nojump_time -= delta
	_shield_time -= delta
	_slow_time -= delta
	_knock_x = move_toward(_knock_x, 0.0, KNOCK_DECAY * delta)
	_drift = _drift.move_toward(Vector2.ZERO, 900.0 * delta)
	if _frozen_time > 0.0:
		_frozen_time -= delta
		_windup = 0.0
		_charge = 0.0
		if _frozen_time <= 0.0:
			Shatter.spawn(get_parent(), center(), Color("#cdeeff"))
		if not _flies():
			_fall(delta)
			velocity.x = _knock_x + _drift.x
			move_and_slide()
		return
	if KINDS[kind]["effect"] == "acrobatic":
		_acrobatics(delta)
	match KINDS[kind]["role"]:
		"wizard":
			_wizard(delta)
		"flyer":
			_fly(delta)
		_:
			_walk(delta)
	if KINDS[kind]["effect"] == "smash":
		_climb_ledges(delta)
## A giant's tall, wide hitbox can catch the lip of a ledge without touching a wall, and stop dead. When it is held up
## like that on the way to the player, it jumps.
func _climb_ledges(delta: float) -> void:
	# Only a giant that is trying to walk and not moving counts: one winding up a smash stands still on purpose.
	var held: bool = is_on_floor() and _windup <= 0.0 and player != null and absf(player.center().x - center().x) > 60.0 and absf(global_position.x - _last_x) < 0.5
	_stuck = _stuck + delta if held else 0.0
	if _stuck > 0.25:
		velocity.y = GIANT_JUMP
		_stuck = 0.0
	_last_x = global_position.x


func _fall(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, TERMINAL_FALL)


## Walkers and shooters stay on the ground: they walk, jump blocks, shoot, or wind up and hit.
func _walk(delta: float) -> void:
	var data: Dictionary = KINDS[kind]
	_fall(delta)
	velocity.y += _drift.y * delta * 4.0
	var speed: float = SPEED * data["speed"]
	if _slow_time > 0.0:
		speed *= 0.5
	var target: Node2D = _target()  # the player, or a decoy it has noticed
	var to_player: Vector2 = target.center() - center() if target else Vector2.ZERO
	var distance := to_player.length() if target else INF
	var shooter: bool = data["role"] == "ranged"
	var sees := target != null and _sees(target)
	var stands_to_shoot: bool = shooter and distance < SPIT_STAND_RANGE and sees and data.get("effect", "") != "acrobatic"
	var close := absf(to_player.x) < 18.0  # right on top of the player: stop instead of walking through
	var moving := target != null and speed > 0.0 and not stands_to_shoot and _root_time <= 0.0 and _windup <= 0.0 and _charge <= 0.0 and not close
	velocity.x = (signf(to_player.x) * speed if moving else 0.0) + _knock_x + _drift.x
	# Enemies jump when a wall blocks them, and leap up to a platform when the player is standing on it.
	if is_on_floor() and target and _root_time <= 0.0 and _nojump_time <= 0.0 and moving:
		var above := to_player.y < -50.0 and absf(to_player.x) < 140.0
		if above:
			velocity.y = MOB_JUMP_HIGH
		elif is_on_wall():
			velocity.y = GIANT_JUMP if KINDS[kind]["effect"] == "smash" else MOB_JUMP
	move_and_slide()
	# Touching a burning walker sets you alight, whether or not it is attacking.
	if _burns() and _flame_lit() and player and not player.dead:
		_touch_timer -= delta
		if _touch_timer <= 0.0 and player.center().distance_to(center()) < 34.0:
			_touch_timer = 0.6
			player.take_damage(TOUCH_BURN, false)  # a burn never blocks a sword blow, nor is blocked by one
	# Some melee enemies leave something behind as they walk.
	if is_on_floor() and absf(velocity.x) > 5.0:
		_trail_timer -= delta
		if _trail_timer <= 0.0 and data["effect"] == "frost_trail":
			_trail_timer = FROST_TRAIL_INTERVAL
			_leave_snow()
	if shooter and target:
		_update_shooter(delta, distance, sees, data["shot"])
	if data["role"] == "melee" and target and data["effect"] != "dummy":
		_update_melee(delta, distance)


## A walker that is close enough draws back, then lunges. If the player moved away during the wind-up, it misses.
func _update_melee(delta: float, distance: float) -> void:
	# A giant that walks into a stone wall or boulder swings at it, even with the player out of reach.
	if KINDS[kind]["effect"] == "smash" and _windup <= 0.0 and _cooldown <= 0.0 and _wall_ahead():
		_windup = SMASH_WINDUP
		_telegraph_smash()
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if KINDS[kind]["effect"] == "smash":
				_smash()
			elif distance < _reach() + 10.0 and _can_reach(_target()):
				_attack()
			_lunge = 1.0
			_cooldown = CONTACT_COOLDOWN
		return
	if _cooldown <= 0.0 and distance < _reach() and _can_reach(_target()):
		_windup = _windup_time()
		if KINDS[kind]["effect"] == "smash":
			_telegraph_smash()


## The giant's stomp: its foot comes down in front of it, breaking any stone wall or boulder there, hurting every other
## enemy close by, and knocking the player back if they are in reach.
## The ground the stomp lands on: points along the ground in front of the giant, out to its reach.
func _smash_spots() -> Array:
	var spots := []
	for i in range(1, SMASH_SPOTS + 1):
		var x := global_position.x + facing * SMASH_REACH * float(i) / SMASH_SPOTS
		spots.append(SpellTargets.solid_below(get_world_2d(), Vector2(x, global_position.y - 60.0)))
	return spots


## Shows where the stomp will land: dust rising off the ground at each spot, as the giant draws its leg back.
func _telegraph_smash() -> void:
	for spot in _smash_spots():
		Fx.smoke(get_parent(), spot, Color(0.82, 0.74, 0.6, 0.9), 6, 26.0, 40.0)


func _smash() -> void:
	var point := global_position + Vector2(SMASH_REACH * facing, SMASH_HEIGHT)
	Sfx.play("stones", point, -2.0)
	Fx.debris(get_parent(), point, Color("#a08060"), 10, 180.0)
	GameCamera.shake_scene(get_tree(), 0.3)
	for wall in get_tree().get_nodes_in_group("walls"):
		wall.take_blow_near(point, SMASH_WALL_DAMAGE)
	for rock in get_tree().get_nodes_in_group("rocks"):
		rock.take_blow_near(point, SMASH_WALL_DAMAGE)
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and not other.is_dead() and other.center().distance_to(point) <= 50.0:
			other.take_damage(SMASH_MOB_DAMAGE)
	# The impact shows on every spot the stomp landed on.
	for spot in _smash_spots():
		Fx.smoke(get_parent(), spot, Color(0.5, 0.43, 0.34, 0.85), 5, 26.0, 40.0)
		Fx.debris(get_parent(), spot, Color("#8a7058"), 6, 150.0)
	# The stomp covers the ground in front of the giant, from its feet up to the height of a standing player. The first
	# stomp that catches the player sticks them in the ground; a stomp that catches them while they are stuck throws them
	# far away and frees them.
	var rel: Vector2 = player.center() - global_position if player else Vector2.ZERO
	if player and not player.dead and signf(rel.x) == facing and absf(rel.x) < SMASH_REACH + 40.0 and absf(rel.y) < 120.0:
		player.take_damage(KINDS[kind]["damage"])
		if player.root_time > 0.0:
			player.push(Vector2(facing * 900.0, -220.0))
		else:
			player.stick_in_ground(SMASH_STUCK)
	Sfx.play("push", point, -6.0)


## True when a stone wall or boulder stands within a smash's reach in front of the giant.
func _wall_ahead() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, SMASH_HEIGHT), global_position + Vector2(SMASH_REACH * facing, SMASH_HEIGHT))
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var blocker: Object = hit["collider"]
	return blocker.has_meta("stone_wall") or blocker.is_in_group("rocks")


## How far a melee enemy's hit reaches: a giant's stomp reaches much farther than a fist.
func _reach() -> float:
	return SMASH_REACH if KINDS[kind]["effect"] == "smash" else CONTACT_RANGE


func _windup_time() -> float:
	match KINDS[kind]["effect"]:
		"explode":
			return WINDUP * 0.6
		"smash":
			return SMASH_WINDUP
	return WINDUP


## A shooter in range charges its shot (a glow builds in front of it), then fires.
## A ninja's acrobatics: it hops and somersaults about on its own, and when the player gets close it springs away in a
## backflip.
func _acrobatics(delta: float) -> void:
	_flip = maxf(_flip - delta, 0.0)
	_stunt -= delta
	_slash_cd = maxf(_slash_cd - delta, 0.0)
	if _slash_cd <= 0.0 and player and not _dead and _frozen_time <= 0.0 and player.center().distance_to(center()) < SLASH_RANGE:
		_slash_cd = SLASH_COOLDOWN
		_slash()
	if _flip > 0.0 or not is_on_floor() or player == null or _dead or _frozen_time > 0.0 or _root_time > 0.0:
		return
	var close: bool = player.center().distance_to(center()) < LEAP_RANGE
	if not close and _stunt > 0.0:
		return
	_stunt = randf_range(STUNT_MIN, STUNT_MAX)
	_flip = FLIP_TIME
	velocity.y = -330.0
	var way := -signf(player.center().x - center().x) if close else signf(randf() - 0.5)
	knock_back(Vector2(way * LEAP_SPEED, 0.0))


## A ninja strikes with its sword: it swings through its attack frames, and hurts the player if they are still in
## reach. Quick, so there is little to dodge once it is this close.
func _slash() -> void:
	_visual.play("attack")
	if not player.dead:
		player.take_damage(SLASH_DAMAGE)
	Sfx.play("push", center(), -8.0)


## A shooter in range charges its shot (a glow builds in front of it), then fires.
func _update_shooter(delta: float, distance: float, sees: bool, shot: Dictionary) -> void:
	# A burst is thrown one star after another, a short gap apart.
	if _burst_left > 0:
		_burst_gap -= delta
		if _burst_gap <= 0.0:
			_burst_left -= 1
			_burst_gap = BURST_GAP
			_shoot(shot)
		return
	if _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_burst_left = shot.get("burst", 1)
			_burst_gap = 0.0
		return
	if distance < SPIT_RANGE and (sees or shot.get("above", false)):
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = shot["interval"]
			_charge = shot.get("charge", CHARGE)


## Flyers drift over the arena above the player. Every so often they hang still, shaking, then dive at the
## player, hit, and fly away.
func _fly(delta: float) -> void:
	var data: Dictionary = KINDS[kind]
	if player == null:
		return
	var before := global_position
	var cruise_y := minf(player.center().y - 130.0, ArenaGen.GROUND_Y - 110.0)
	var speed_mult: float = data["speed"] * (0.5 if _slow_time > 0.0 else 1.0)
	_fly_timer -= delta
	match _fly_state:
		PATROL:
			global_position.x += signf(_fly_goal_x - global_position.x) * FLY_SPEED * speed_mult * delta
			global_position.y = move_toward(global_position.y, cruise_y, 160.0 * delta)
			if absf(_fly_goal_x - global_position.x) < 12.0:
				_fly_goal_x = player.global_position.x + randf_range(-280.0, 280.0)
			if _fly_timer <= 0.0 and _root_time <= 0.0:
				_fly_state = HOVER
				_fly_timer = DIVE_WARNING
				Sfx.play("mob_hurt", global_position, -6.0, 0.3)
		HOVER:
			# The warning before a dive: it stops and shakes.
			if _fly_timer <= 0.0:
				_fly_state = DIVE
				_fly_target = player.center()
				_fly_timer = 1.6
		DIVE:
			var to_target := _fly_target - center()
			global_position += to_target.normalized() * DIVE_SPEED * speed_mult * delta
			if center().distance_to(player.center()) < CONTACT_RANGE and _can_reach_player():
				_attack()
				_start_retreat()
			elif _fly_timer <= 0.0 or to_target.length() < 6.0:
				_start_retreat()
		RETREAT:
			global_position.x += _fly_away * RETREAT_SPEED * delta
			global_position.y = move_toward(global_position.y, cruise_y - 60.0, 200.0 * delta)
			if _fly_timer <= 0.0:
				_fly_state = PATROL
				_fly_goal_x = player.global_position.x + randf_range(-280.0, 280.0)
				_fly_timer = 2.5
	global_position += (Vector2(_knock_x, 0.0) + _drift) * delta
	global_position.x = clampf(global_position.x, ArenaGen.left_edge() + 16.0, ArenaGen.right_edge() - 16.0)
	# Flyers never sink into the ground, even mid-dive.
	global_position.y = minf(global_position.y, ArenaGen.GROUND_Y - _body_size.y * 0.5 - _body_center.y - 2.0)
	if _hits_terrain(before + _body_center, center()):
		global_position = before  # flyers cannot pass through stone or walls
		if _fly_state == DIVE:
			_start_retreat()
	if data.get("shot", {}).size() > 0:
		_shot_timer -= delta
		var shot: Dictionary = data["shot"]
		# A dropping flyer waits until it is over the player before it lets go.
		var lined_up: bool = not shot.get("drop", false) or absf(player.global_position.x - global_position.x) < 70.0
		if _shot_timer <= 0.0 and lined_up and _fly_state != DIVE:
			_shot_timer = shot["interval"]
			_shoot(shot)


func _start_retreat() -> void:
	_fly_away = signf(global_position.x - player.global_position.x)
	if _fly_away == 0.0:
		_fly_away = 1.0
	_fly_state = RETREAT
	_fly_timer = 1.4


## Fires one of this enemy's shots, in its school colour. Plain shots fly at the player; some arc, some fan out,
## some fall straight down from the flyer, and fire casters call one down from above the player.
func _shoot(shot: Dictionary) -> void:
	if KINDS[kind]["effect"] == "acrobatic" and _flip <= 0.0:
		_flip = FLIP_TIME  # a ninja flips as it lets a star go
	var colour := _school_colour()
	var origin := center() + Vector2(facing * _body_size.x * 0.5, -4.0)
	if shot.get("above", false):
		var drop_x: float = player.global_position.x + player.velocity.x * 0.35
		FallingShot.call_down(get_parent(), Vector2(drop_x, player.global_position.y), colour, shot["damage"])
		Sfx.play("mob_shoot", origin)
		return
	if shot.get("drop", false):
		EnemyBolt.fire(get_parent(), center() + Vector2(0, 10), center() + Vector2(0, 100), colour, shot["damage"], shot.get("gravity", 300.0), shot.get("slow", false), "magic_bolt", self)
		Sfx.play("mob_shoot", center())
		return
	var aim: Vector2 = _target().center()
	var count: int = shot.get("spread", 1)
	for i in count:
		var angle := 0.0 if count == 1 else (i - (count - 1) * 0.5) * 0.14
		var target := origin + (aim - origin).rotated(angle)
		var gravity: float = shot.get("gravity", 0.0)
		if gravity > 0.0:
			# Lob it so it comes down on the player: aim above them by how far the arc will drop.
			var flight := origin.distance_to(aim) / EnemyBolt.SPEED
			target = aim + Vector2(0, -0.5 * gravity * flight * flight)
		EnemyBolt.fire(get_parent(), origin, _quake_target(origin, target), colour, shot["damage"], gravity, shot.get("slow", false), shot.get("art", "magic_bolt"), self)
	Sfx.play("mob_shoot", origin)


## Who this enemy is after: a decoy it has noticed, otherwise the player.
func _target() -> Node2D:
	var decoy := Decoy.nearest(get_tree(), center(), DECOY_NOTICE)
	if decoy != null and _can_reach(decoy):
		return decoy
	return player


## True when nothing solid stands between the enemy and the player. Enemies cannot hit through stone.
func _can_reach_player() -> bool:
	return _can_reach(player)


## True when nothing solid stands between the enemy and its target.
func _can_reach(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(center(), target.center())
	query.collision_mask = 1  # terrain only; platforms do not block
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## True when the enemy can see its target: no stone in the way, and no smoke or darkness either.
func _sees(target: Node2D) -> bool:
	return _can_reach(target) and not SpellTargets.sight_blocked(get_tree(), center(), target.center())


## Damage from a spell of the given school. Weak to a school takes double; resisting it takes nothing.
## A frozen enemy hit by force or earth shatters out of the ice and takes extra.
func take_damage(amount: int, school := "") -> void:
	if _dead or _spawn > 0.0:
		return
	if _shield_time > 0.0:
		FloatText.spawn(get_parent(), center() + Vector2(0, -_body_size.y * 0.5), "Blocked", Color(0.8, 0.7, 1.0), 0.8)
		return
	var data: Dictionary = KINDS[kind]
	var dealt := amount
	if school != "" and school == data["resist"]:
		dealt = 0
	elif school != "" and school == data["weak"]:
		dealt = amount * 2
	dealt = roundi(dealt * Hex.multiplier(get_tree(), self))  # a hexed enemy takes half again as much
	if _frozen_time > 0.0 and school in ["Air", "Earth"]:
		dealt = roundi(dealt * 1.5)
		_frozen_time = 0.0
		Shatter.spawn(get_parent(), center(), Color("#cdeeff"))
		Sfx.play("ice_shatter", center())
	var text_at := center() + Vector2(0, -_body_size.y * 0.5 - 6.0)
	if dealt <= 0:
		FloatText.spawn(get_parent(), text_at, "Resisted", Color(0.75, 0.75, 0.82), 0.8)
		return
	hp -= dealt
	_since_hit = 0.0
	if data["effect"] == "dummy" and hp <= 0:
		hp = max_hp  # a dummy is never beaten: it stands up again
	_flash = 1.0
	var weak := dealt > amount
	FloatText.spawn(get_parent(), text_at, "%d%s" % [dealt, "!" if weak else ""], Color("#ff9a3a") if weak else Color("#fff0a0"), 1.25 if weak else 1.0)
	if data["role"] == "wizard" and brain:
		brain.on_hurt(dealt)
	# Sparks take the spell's colour, not the enemy's.
	var spark: Color = SpellData.SCHOOL_COLORS.get(school, _school_colour())
	Fx.burst(get_parent(), center(), spark, 8, 120.0, 0.3, true)
	if hp <= 0:
		_die()
	else:
		Sfx.play("mob_hurt", center())
		if _visual.sprite_frames.has_animation("hit") and _windup <= 0.0 and _charge <= 0.0 and not is_drawing():
			_visual.play("hit")


## A defeated enemy bursts into smoke and its school's sparks, plays its death tumble, then disappears.
func _die() -> void:
	_dead = true
	remove_from_group("mobs")
	set_physics_process(false)
	# Shots and spells pass through a body that is already falling over.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_windup = 0.0
	_charge = 0.0
	_frozen_time = 0.0
	Sfx.play("mob_die", center())
	Fx.burst(get_parent(), center(), _school_colour(), 18, 180.0, 0.6, true)
	Fx.smoke(get_parent(), center(), Color(0.25, 0.2, 0.3, 0.6), 5, 30.0)
	GameCamera.shake_scene(get_tree(), 0.18)
	if _visual.sprite_frames.has_animation("death"):
		_visual.play("death")
	else:
		var tween := create_tween()
		tween.tween_property(self, "position:y", position.y + 30.0, 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		tween.parallel().tween_property(self, "rotation", 1.2 * facing, 0.35)
		tween.tween_callback(queue_free)


func _on_animation_finished() -> void:
	if _dead and _visual.animation == "death":
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	elif not _dead and _visual.animation in ["hit", "attack", "burst"]:
		_visual.play("idle")


func is_dead() -> bool:
	return _dead


func apply_no_jump(seconds: float) -> void:
	_nojump_time = maxf(_nojump_time, seconds)


## Holds the enemy where it stands, as a Flytrap does: it cannot walk, jump or be carried away by its own speed.
func apply_root(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)
	_knock_x = 0.0


func is_slowed() -> bool:
	return _slow_time > 0.0


## Standing in water or lava: tinted its colour for a moment after each call.
func soak(tint: Color) -> void:
	_liquid = tint
	_liquid_time = 0.15


func apply_slow(seconds: float) -> void:
	if KINDS[kind]["school"] == "Water":
		return  # water enemies cannot be slowed by ice or snow
	_slow_time = maxf(_slow_time, seconds)


## Encases the enemy in ice: it cannot move or attack until it thaws or something shatters it.
## Returns false for ice enemies, which shrug it off.
func freeze(seconds: float) -> bool:
	if KINDS[kind]["school"] == "Water" or _dead:
		return false
	_frozen_time = maxf(_frozen_time, seconds)
	return true


func is_frozen() -> bool:
	return _frozen_time > 0.0


func knock_back(impulse: Vector2) -> void:
	if _frozen_time > 0.0:
		impulse *= 0.4  # a block of ice is heavy
	if KINDS[kind]["effect"] == "smash":
		impulse *= 0.25  # a giant's bulk barely moves for a fireball
	_knock_x = impulse.x
	velocity.y = minf(velocity.y, impulse.y)  # a little lift for upward knocks


## A steady pull, such as a Gravity Well's. Call it every frame the pull lasts.
func pull(force: Vector2, delta: float) -> void:
	_drift += force * delta


func raise_shield(seconds: float) -> void:
	if _bubble == null:
		# The same pixel bubble as the player's Barrier, sized to the body.
		_bubble = PixelFx.sprite("shield", 10.0)
		_bubble.scale = Vector2.ONE * maxf(2.0, ceilf(maxf(_body_size.x, _body_size.y) / 40.0))
		_bubble.position = _body_center
		_bubble.material = Fx.additive()
		_bubble.z_index = 9
		add_child(_bubble)
	_shield_time = maxf(_shield_time, seconds)
	Sfx.play("barrier", center())


func has_shield() -> bool:
	return _shield_time > 0.0


## An enemy hits the player. Its effect (knockback, or an explosion) comes after the damage.
func _attack() -> void:
	var data: Dictionary = KINDS[kind]
	_lunge = 1.0
	if data["effect"] == "explode":
		_explode()
		return
	var target := _target()
	if target != player:
		target.take_damage(data["damage"])  # a decoy takes the blow
		Sfx.play("push", target.center(), -6.0)
		return
	player.take_damage(data["damage"])
	Sfx.play("stones" if data["school"] == "Earth" else "fire_hit" if data["school"] == "Fire" else "push", player.center(), -6.0)
	match data["effect"]:
		"knockback":
			player.push(Vector2(signf(player.global_position.x - global_position.x) * 420.0, -160.0))
		"big_knockback":
			player.push(Vector2(signf(player.global_position.x - global_position.x) * 900.0, -220.0))


func _explode() -> void:
	Fx.impact(get_parent(), center(), _school_colour(), 70.0)
	Fx.pop(get_parent(), center(), "spark_02", _school_colour(), 90.0, 0.3, 1.4, 3.0)
	Sfx.play("explosion", center())
	GameCamera.shake_scene(get_tree(), 0.4)
	# Damage the player and any other enemy close enough to the blast.
	if center().distance_to(player.center()) <= BURST_RADIUS:
		player.take_damage(KINDS[kind]["damage"])
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and other.center().distance_to(center()) <= BURST_RADIUS:
			other.take_damage(BURST_DAMAGE)
	_die()


func _process(delta: float) -> void:
	_idle_t += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_liquid_time = maxf(_liquid_time - delta, 0.0)
	var wet := _liquid if _liquid_time > 0.0 else Color.WHITE
	modulate = Color(wet.r, wet.g, wet.b, modulate.a)
	_animate(delta)
	queue_redraw()
	_overlay.queue_redraw()


## Picks the animation for what the enemy is doing: attacking (the wind-up of a hit, the charge of a shot, a
## flyer's dive), flinching, walking or idling, and faces where it is going. Flyers bob as they hover.
func _animate(delta: float) -> void:
	var flying := _flies()
	var wizard: bool = KINDS[kind]["role"] == "wizard"
	if player and not _dead and _frozen_time <= 0.0:
		if flying or wizard or _windup > 0.0 or _charge > 0.0 or absf(velocity.x) < 5.0:
			facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else facing
		else:
			facing = signf(velocity.x)
	var lunge := 0.0
	if _lunge > 0.0:
		lunge = roundf(sin(_lunge * PI) * 8.0) * facing
		_lunge = maxf(_lunge - delta * 3.0, 0.0)
	_bursting = maxf(_bursting - delta, 0.0)
	var shake := Vector2.ZERO
	if flying and _fly_state == HOVER:
		shake = Vector2(randi_range(-1, 1), randi_range(-1, 1))
	var moving := not _dead and _frozen_time <= 0.0 and absf(velocity.x) > 5.0 and (is_on_floor() or flying)
	var wanted := "idle"
	if wizard:
		if _bursting > 0.0:
			wanted = "burst"
		elif is_drawing():
			wanted = "channel"
		elif not is_on_floor():
			wanted = "jump" if velocity.y < 0.0 else "fall"
		elif moving:
			wanted = "walk"
	elif _windup > 0.0 or _charge > 0.0 or (flying and _fly_state == DIVE):
		wanted = "attack"
	elif moving and _visual.sprite_frames.has_animation("walk"):
		wanted = "walk"
	var busy: bool = _visual.animation == "hit" or (_visual.animation == "attack" and _visual.is_playing())
	if not _dead and _visual.animation != wanted and not (busy and wanted != "attack" and wanted != "burst"):
		_visual.play(wanted)
	_visual.speed_scale = 0.0 if _frozen_time > 0.0 else 1.0
	var bob := roundf(sin(_idle_t * 3.0) * 2.0) if flying else 0.0
	_visual.position = Vector2(lunge, bob) + shake
	_visual.scale = Vector2(_base_scale, _base_scale)
	_visual.flip_h = facing < 0.0
	# A ninja's backflip turns about the middle of its body, away from the way it is moving, not about its feet.
	var spin := signf(velocity.x) if absf(velocity.x) > 1.0 else facing
	var turn := -TAU * (1.0 - _flip / FLIP_TIME) * spin if _flip > 0.0 else 0.0
	var pivot := _visual.offset * _base_scale
	_visual.rotation = turn
	_visual.position += pivot - pivot.rotated(turn)
	if _material:
		var charging := 0.0
		if _windup > 0.0:
			charging = 0.35 * (1.0 - _windup / WINDUP)
		_material.set_shader_parameter("flash", maxf(_flash, charging))
		_material.set_shader_parameter("flash_color", Color.WHITE if _flash > charging else _school_colour().lightened(0.5))
		_material.set_shader_parameter("frozen", 1.0 if _frozen_time > 0.0 else 0.0)


## A soft shadow under the enemy on the ground below it.
func _draw() -> void:
	if _dead:
		return
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 260))
	query.collision_mask = 1 | 16
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var below: float = hit["position"].y - global_position.y
	var fade := clampf(1.0 - below / 220.0, 0.15, 1.0)
	var width := _body_size.x * 0.6 * (0.6 + 0.4 * fade)
	var points := PackedVector2Array()
	for i in 18:
		points.append(Vector2(cos(TAU * i / 18.0) * width, below + sin(TAU * i / 18.0) * width * 0.25))
	draw_colored_polygon(points, Color(0, 0, 0, 0.3 * fade))


## Things drawn over the sprite: the shot charging, the ice block, the shield, the health bar and the stroke the
## dark wizard is drawing.
func _draw_overlay() -> void:
	if _dead:
		return
	var o := _overlay
	if _charge > 0.0:
		# A pixel orb of the enemy's magic gathering in front of it.
		var k := 1.0 - _charge / CHARGE
		var at := _body_center + Vector2(facing * _body_size.x * 0.5, -4.0)
		var c := _school_colour()
		Fx.draw_glow(o, at, 6.0 + 12.0 * k, Color(c.r, c.g, c.b, 0.5 + 0.5 * k))
		var orbs := PixelFx.frames("dark_orb", 12.0, true)
		var orb := orbs.get_frame_texture("default", int(_idle_t * 12.0) % orbs.get_frame_count("default"))
		var size := 1.0 + floorf(k * 2.0)
		o.draw_texture_rect(orb, Rect2(at - Vector2.ONE * 8.0 * size, Vector2.ONE * 16.0 * size), false, c.lightened(0.4))
	if _frozen_time > 0.0:
		# Encased in a block of pixel-art ice, seen through.
		var box := Rect2((_body_center - _body_size * 0.5 - Vector2(6, 6)).floor(), (_body_size + Vector2(12, 10)).floor())
		o.draw_texture_rect(ICE, box, true, Color(1, 1, 1, 0.6))
	if _bubble:
		_bubble.visible = _shield_time > 0.0
		_bubble.modulate = Color(0.85, 0.93, 1.0, 0.3 * clampf(_shield_time / 0.4, 0.0, 1.0))
	var wizard: bool = KINDS[kind]["role"] == "wizard"
	if hp < max_hp or wizard:
		var width := 40.0 if wizard else 28.0
		var top := _body_center.y - _body_size.y * 0.5 - (26.0 if wizard else 9.0)
		var bar := Rect2(Vector2(-width * 0.5, top), Vector2(width, 4.0))
		o.draw_rect(bar.grow(1.0), Color(0.05, 0.03, 0.08, 0.85))
		o.draw_rect(Rect2(bar.position, Vector2(width * clampf(float(hp) / max_hp, 0.0, 1.0), 4.0)), Color("#e84a5f") if not wizard else Color("#b65cff"))
	if _draw_time > 0.0 and _stroke.size() >= 2:
		var progress := 1.0 - _draw_time / _draw_total
		var count := clampi(int(_stroke.size() * progress), 2, _stroke.size())
		var local := PackedVector2Array()
		for i in count:
			local.append(_stroke[i] - global_position)
		var c := _stroke_colour
		o.draw_polyline(local, Color(c.r, c.g, c.b, 0.25), 7.0)
		o.draw_polyline(local, Color(c.r, c.g, c.b, 0.9), 3.0)
		o.draw_polyline(local, Color(1.0, 1.0, 1.0, 0.9), 1.0)
		Fx.draw_glow(o, local[local.size() - 1], 8.0, Color(c.r, c.g, c.b, 0.9))


## An ice enemy leaves snow falling behind it for a few seconds: a passing blizzard, with no pile.
func _leave_snow() -> void:
	var snow := Blizzard.new()
	snow.lasting = false
	snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(40, -60), Vector2(40, 60), Vector2(0, 60)])
	get_parent().add_child(snow)
	snow.setup("Blizzard", center() + Vector2(-20, 0), 0.0)


## True when solid terrain lies between two points. Flyers use it to stay out of stone and walls.
func _hits_terrain(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- The dark wizard ------------------------------------------------------------------------------------------


## The dark wizard: a hooded figure with a staff wreathed in shadow, the same size as the player. Its hitbox is the
## hooded body, not the staff.
func _build_wizard() -> void:
	_visual.sprite_frames = CharFrames.build("res://art/chars/" + str(KINDS[kind]["art"]), WIZARD_ANIMATIONS)
	_base_scale = KINDS[kind].get("scale", 1.0)
	_visual.offset = Vector2(0, -PixelArt.CHARACTERS[KINDS[kind]["art"]]["size"].y * 0.5)
	var body: Rect2 = WIZARD_BODY if kind == "dark_wizard" else PixelArt.CHARACTERS[KINDS[kind]["art"]]["body"]
	_set_walker_body(body.size * _base_scale * Vector2(0.9, 0.95))
	_start_animating()
	# Dark wisps rising off the robes.
	var wisps := Fx.trail(Color(0.45, 0.2, 0.6, 0.55), 18, 0.9, 30.0, Vector2(0, -40), "smoke_04", 14.0)
	wisps.material = null
	wisps.position = Vector2(0, -10)
	wisps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	wisps.emission_rect_extents = Vector2(14, 6)
	add_child(wisps)
	move_child(wisps, 0)
	caster = Caster.new()
	add_child(caster)
	caster.set_process(false)  # it casts from its own strokes only, never from the mouse
	caster.ground_check = Callable(get_parent(), "_is_ground_at")
	caster.cast_resolved.connect(Callable(get_parent(), "_on_wizard_cast").bind(self))
	brain = WizardBrain.new(self)


## Where the dark wizard's mouth would be under its hood, for Fire Breath.
func mouth() -> Vector2:
	return global_position + Vector2(6.0 * facing * _base_scale, -_body_size.y * 0.85)


## The dark wizard's turn: its brain moves it and decides when to cast.
func _wizard(delta: float) -> void:
	_fall(delta)
	stamina = minf(100.0, stamina + WizardBrain.STAMINA_REGEN * delta)
	if _draw_time > 0.0:
		_draw_time -= delta
		if _draw_time <= 0.0:
			var stroke := _stroke
			_stroke = PackedVector2Array()
			_bursting = 0.35
			_visual.play("burst")
			_on_drawn.call(stroke)
	if player:
		caster.anchor = center()
		brain.think(delta)
	velocity.x += _knock_x + _drift.x
	if _root_time > 0.0:
		velocity.x = _knock_x
	move_and_slide()
	global_position.x = clampf(global_position.x, ArenaGen.left_edge() + 12.0, ArenaGen.right_edge() - 12.0)


## Starts drawing a stroke in front of the dark wizard. After DRAW_TIME it calls on_done with the stroke.
## Being hit hard while drawing breaks the spell (see WizardBrain.on_hurt).
func start_drawing(points: PackedVector2Array, colour: Color, on_done: Callable, draw_time := DRAW_TIME) -> void:
	_stroke = points
	_stroke_colour = colour
	_on_drawn = on_done
	_draw_time = draw_time
	_draw_total = draw_time
	Sfx.play("wizard_cast", center())


func is_drawing() -> bool:
	return _draw_time > 0.0


## Drops the spell being drawn, with a puff of sparks so the player can see they broke it.
func interrupt_cast() -> void:
	if _draw_time <= 0.0:
		return
	_draw_time = 0.0
	_stroke = PackedVector2Array()
	Fx.burst(get_parent(), center() + Vector2(facing * 14.0, -16.0), _stroke_colour, 14, 140.0, 0.4, true)
	FloatText.spawn(get_parent(), center() + Vector2(0, -44), "Interrupted!", Color("#d9b8ff"), 0.9)
	Sfx.play("misfire", center())


func _burns() -> bool:
	return KINDS[kind]["effect"] == "burning"


## A burning walker: one flame, tall enough to cover its whole body, stands on it and moves with it.
func _set_alight() -> void:
	var flame := PixelFx.sprite("fire_wall", 14.0)
	flame.scale = Vector2.ONE * 3.0  # three times the size, so the fire rises round the whole body
	# The flame's bottom sits on the walker's feet (its origin), and it is drawn behind the walker.
	flame.position = Vector2(0, -PixelArt.FX["fire_wall"]["size"].y * 0.5 * flame.scale.y + 55.0)  # 55: the feet sit this far below the origin
	flame.z_index = -1
	add_child(flame)
	_flame = flame


## A frozen walker's flame goes out, and comes back a moment after the ice is gone.
func _update_flame(delta: float) -> void:
	if _flame == null:
		return
	_relight = RELIGHT_SECONDS if _frozen_time > 0.0 else maxf(_relight - delta, 0.0)
	_flame.visible = _flame_lit()


func _flame_lit() -> bool:
	return _relight <= 0.0 and _frozen_time <= 0.0


## While the ground shakes, a shooter's aim is turned a few degrees off its mark.
func _quake_target(origin: Vector2, target: Vector2) -> Vector2:
	if not Earthquake.is_shaking(get_tree()):
		return target
	return origin + (target - origin).rotated(deg_to_rad(randf_range(-Earthquake.AIM_DEGREES, Earthquake.AIM_DEGREES)))
