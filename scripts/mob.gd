class_name Mob
extends CharacterBody2D

## An enemy. Each one has a role (melee walker, ranged shooter or flyer) and a school. The school sets its
## colour and what it is weak or resistant to. Some schools also give their enemies a particular trick.
## The creatures are LuizMelo's skeleton, goblin, mushroom and flying eye (art/mobs). Each keeps its own colours with an
## outline in its school's colour. (The wizards are not mobs: see Wizard.) "scale" draws a
## creature bigger, always at a whole number of pixels so the pixel art stays sharp.
## A walker's origin is at its feet, so it stands exactly on the ground; a flyer's is the middle of its body.
## Every attack is telegraphed: walkers wind up, shooters charge a glow, flyers hover before they dive.

## Every kind of enemy, by the name it is summoned by, each a MobKind resource read from res://mobs/ in the order they are meant to be listed.
static var KINDS: Dictionary = _load_kinds()


static func _load_kinds() -> Dictionary:
	var found: Array[MobKind] = []
	for file in ResourceLoader.list_directory("res://mobs"):
		file = file.trim_suffix(".remap")  # an exported game lists remapped resources under this name
		if file.ends_with(".tres") or file.ends_with(".res"):
			found.append(load("res://mobs/" + file))
	found.sort_custom(func(x: MobKind, y: MobKind) -> bool: return x.sort_order < y.sort_order)
	var out := {}
	for kind in found:
		out[kind.id] = kind
	return out
const SPEED := 80.0
const TERMINAL_FALL := 900.0  # no enemy falls faster than this
const FALL_LIMIT := 800.0     # an enemy below this has fallen off the map and is removed (in a world, the bottom of the world)
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
const BURST_GAP := 0.09      # the gap between the stars of one burst
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
const ROAM_NOTICE := 560.0     # a roaming enemy notices the player this close, and loses them again past a little farther
const DECOY_NOTICE := 520.0    # a decoy this close is noticed, and attacked instead of the player
const SPIT_RANGE := 480.0       # a ranged enemy fires from this far away
const SPIT_STAND_RANGE := 300.0 # and stops walking once it is this close
const FLY_SPEED := 120.0        # how fast a flyer drifts while it patrols
const DIVE_SPEED := 340.0       # how fast a flyer dives at you
const RETREAT_SPEED := 240.0    # how fast it flies away after a dive
const FROST_TRAIL_INTERVAL := 0.8
const GET_UP := 10.0           # a fainted enemy stands up when its stamina is this high again
const STAMINA_CAP := 100.0     # the most stamina an enemy has
const SPAWN_TIME := 0.7         # enemies fade in over a summoning circle and cannot act until it is done
const PATROL := 0
const DIVE := 1
const RETREAT := 2
const HOVER := 3
const CREATURE_ANIMATIONS := {
	"idle": {"fps": 8.0}, "walk": {"fps": 10.0}, "attack": {"fps": 14.0, "loop": false},
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
var kind := "basic"  # set before the mob enters the tree
var player: Node2D
var roams := false  # one the world left wandering (the graveyard's dead): it ambles about until a wizard comes near, then gives chase
var puppet := false  # in a network game, a roamer on a machine that is not the host: it shows what the host's one does and decides nothing
var net_position := Vector2.ZERO  # where the host says it is, while it is a puppet
var net_facing := 1.0
var net_swing := false  # the host's is drawing back to strike
var _prey_time := 0.0
var _wander := 0.0
var _wander_time := 0.0
var hp := 30
var max_hp := 30
var stamina := 100.0      # a Faint takes all of it; it comes back as a wizard's does, and the enemy stands up when there is enough
var _cooldown := 0.0
var _since_hit := 0.0  # seconds since this enemy was last hurt; a dummy heals once it has been left alone
var _slow_time: float:
	get: return _status.left(&"slow")
	set(seconds): _status.set_left(&"slow", seconds)
var _knock_x := 0.0
var _drift := Vector2.ZERO  # a pull (Gravity Well) that fades
var _dead := false
var _fainted := false  # knocked out by a Faint: down until its stamina has come back to GET_UP
var _since_stamina := 0.0  # seconds since a fainted enemy lost its stamina; it does not come back at once
var _status := StatusEffects.new()  # the timed conditions above, each a Timer
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _idle_t := 0.0
var facing := 1.0
var _shot_timer := 1.5
var _root_time: float:
	get: return _status.left(&"root")
	set(seconds): _status.set_left(&"root", seconds)
var _nojump_time: float: # while above zero, the walker cannot jump (mudslide)
	get: return _status.left(&"nojump")
	set(seconds): _status.set_left(&"nojump", seconds)
var _frozen_time: float:
	get: return _status.left(&"frozen")
	set(seconds): _status.set_left(&"frozen", seconds)
var _flame: Node2D  # a burning walker's flame; it goes out while the walker is frozen
var _relight := 0.0  # seconds until the flame is lit again after a freeze
var _base_scale := 1.0
var _lunge := 0.0        # 1 the moment an enemy attacks, fading to 0: it lunges toward the player
var _windup := 0.0       # counting down to a melee hit
var _stuck := 0.0        # how long a giant has been held up by a ledge
var _last_x := 0.0       # where a giant was last frame, to tell whether it is moving
var _slash_cd := 0.0     # counting down to a ninja's next katana strike
var _burst_left := 0     # stars still to throw in the burst being thrown
var _burst_gap := 0.0    # counting down to the next star of the burst
var _charge := 0.0       # counting down to a shot
var _flash := 0.0
var _liquid := Color.WHITE  # the colour of the water or lava it stands in
var _liquid_time := 0.0
var _liquid_y := INF  # the height of the surface of that liquid
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
const ICE := preload("res://art/props/ice_fill.png")


func _ready() -> void:
	add_child(_status)
	_status.ended.connect(func(status: StringName) -> void:
		if status == &"frozen":
			Shatter.spawn(get_parent(), center(), Color("#cdeeff")))  # the ice gives way
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("mobs")
	var data: MobKind = KINDS[kind]
	if _burns():
		_set_alight()
	max_hp = data.hp
	hp = max_hp
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_overlay)
	_build_creature(data)
	if data.role == "flyer":
		collision_mask = 0  # flyers pass through the terrain; they reach you from above
		_fly_goal_x = global_position.x
		_fly_timer = 1.0 + randf() * 2.0
	_shot_timer = 0.8 + randf() * 1.2
	# Every enemy arrives through a summoning circle.
	Fx.pop(get_parent(), global_position + Vector2(0, -2 if not _flies() else 18), "magic_02", _school_colour(), 70.0, SPAWN_TIME + 0.2, 1.2, 1.5)
	Sfx.play("summon", global_position)
	modulate.a = 0.0


## A creature drawn from art/mobs: its frames, its size, and a hitbox that matches the body in the drawing.
func _build_creature(data: MobKind) -> void:
	var art: String = data.art
	var info: Dictionary = PixelArt.CHARACTERS[art]
	_visual.sprite_frames = CharFrames.build("res://art/mobs/" + art, CREATURE_ANIMATIONS)
	if data.effect == "smash":
		# The lean is slowed to fill the giant's wind-up, so one pass of it lasts as long as the wind-up does.
		_visual.sprite_frames.set_animation_speed("attack", 7.0)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # scaled-up pixel art stays crisp, not blurred
	_base_scale = data.scale
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
	var school: String = KINDS[kind].school
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/mob.gdshader")
	_material.set_shader_parameter("school_color", _school_colour())
	_material.set_shader_parameter("tint", 0.0 if school in ["", "Shadow"] else 0.22)
	_material.set_shader_parameter("outline", 0.0 if school == "" else 0.9)
	_visual.material = _material


func _school_colour() -> Color:
	var school: String = KINDS[kind].school
	return SpellData.SCHOOL_COLORS.get(school, Color("#d8d0e8"))


func _flies() -> bool:
	return KINDS[kind].role == "flyer"


## The middle of the enemy's body in the world. Spells and the player's aim go here.
func center() -> Vector2:
	return global_position + _body_center


func _physics_process(delta: float) -> void:
	if puppet:
		_glide(delta)
		return
	if roams:
		_pick_prey(delta)
	if global_position.y > (ArenaGen.world_size.y * float(ArenaGen.TILE) if ArenaGen.world_size.y > 0 else FALL_LIMIT):
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
	if KINDS[kind].effect == "dummy" and _since_hit > 3.0:
		hp = max_hp  # a dummy heals as soon as you stop
	_knock_x = move_toward(_knock_x, 0.0, KNOCK_DECAY * delta)
	_drift = _drift.move_toward(Vector2.ZERO, 900.0 * delta)
	if _frozen_time > 0.0:
		_windup = 0.0
		_charge = 0.0
		if not _flies():
			_fall(delta)
			velocity.x = _knock_x + _drift.x
			move_and_slide()
		return
	if _fainted:
		_windup = 0.0
		_charge = 0.0
		_since_stamina += delta
		if _since_stamina >= 1.0:
			stamina = minf(STAMINA_CAP, stamina + Wizard.STAMINA_REGEN * delta)
		if stamina >= GET_UP:
			_fainted = false
			if _visual.sprite_frames.has_animation("idle"):
				_visual.play("idle")
		else:
			if not _flies():
				_fall(delta)
				velocity.x = _knock_x + _drift.x
				move_and_slide()
			return
	if KINDS[kind].effect == "ninja":
		_ninja_strike(delta)
	match KINDS[kind].role:
		"flyer":
			_fly(delta)
		_:
			_walk(delta)
	if KINDS[kind].effect == "smash":
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
	var data: MobKind = KINDS[kind]
	_fall(delta)
	velocity.y += _drift.y * delta * 4.0
	var speed: float = SPEED * data.speed
	if _slow_time > 0.0:
		speed *= 0.5
	var target: Node2D = _target()  # the player, or a decoy it has noticed
	var to_player: Vector2 = target.center() - center() if target else Vector2.ZERO
	var distance := to_player.length() if target else INF
	var shooter: bool = data.role == "ranged"
	var sees := target != null and _sees(target)
	var stands_to_shoot: bool = shooter and distance < SPIT_STAND_RANGE and sees and data.effect != "ninja"
	if roams and distance > ROAM_NOTICE:
		_amble(delta, speed)
		return
	var close := absf(to_player.x) < 18.0  # right on top of the player: stop instead of walking through
	var moving := target != null and speed > 0.0 and not stands_to_shoot and _root_time <= 0.0 and _windup <= 0.0 and _charge <= 0.0 and not close
	velocity.x = (signf(to_player.x) * speed if moving else 0.0) + _knock_x + _drift.x
	# Enemies jump when a wall blocks them, and leap up to a platform when the player is standing on it.
	if is_on_floor() and target and _root_time <= 0.0 and _nojump_time <= 0.0 and moving:
		var above := to_player.y < -50.0 and absf(to_player.x) < 140.0
		if above:
			velocity.y = MOB_JUMP_HIGH
		elif is_on_wall():
			velocity.y = GIANT_JUMP if KINDS[kind].effect == "smash" else MOB_JUMP
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
		if _trail_timer <= 0.0 and data.effect == "frost_trail":
			_trail_timer = FROST_TRAIL_INTERVAL
			_leave_snow()
	if shooter and target:
		_update_shooter(delta, distance, sees, data.shot)
	if data.role == "melee" and target and data.effect != "dummy":
		_update_melee(delta, distance)


## A puppet follows the host's mob: it glides to where it is, walking when it moves, and draws back when the host's does.
func _glide(delta: float) -> void:
	if _dead:
		return
	var step := net_position - global_position
	global_position = net_position if step.length() > 160.0 else global_position + step * minf(1.0, delta * 14.0)
	velocity.x = step.x * 14.0
	facing = net_facing
	_windup = 0.2 if net_swing else 0.0


## A roamer goes after the nearest wizard who is still standing, whoever's they are (looked for a few times a second).
func _pick_prey(delta: float) -> void:
	_prey_time -= delta
	if _prey_time > 0.0:
		return
	_prey_time = 0.4
	player = null
	var nearest := INF
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		var gap := wizard.global_position.distance_squared_to(global_position)
		if not wizard.dead and gap < nearest:
			nearest = gap
			player = wizard


## Hits a wizard for a mob. A wizard another machine drives is told to take the blow, since only its own machine can.
func _strike(target: Node2D, amount: int, impulse := Vector2.ZERO) -> void:
	if target is Wizard and target.is_likeness():
		target.rpc_id(target.get_multiplayer_authority(), &"_struck_by_a_mob", amount, impulse)
		return
	target.take_damage(amount)
	if impulse != Vector2.ZERO:
		target.push(impulse)


## A roaming enemy that has not noticed anyone: it stands about, or shuffles a little way one direction or the other.
func _amble(delta: float, speed: float) -> void:
	_wander_time -= delta
	if _wander_time <= 0.0:
		_wander_time = randf_range(1.5, 4.0)
		_wander = [-1.0, 0.0, 1.0][randi() % 3]
	if is_on_wall():
		_wander = -_wander
	velocity.x = _wander * speed * 0.35 + _knock_x + _drift.x
	move_and_slide()


## A walker that is close enough draws back, then lunges. If the player moved away during the wind-up, it misses.
func _update_melee(delta: float, distance: float) -> void:
	# A giant that walks into a stone wall or boulder swings at it, even with the player out of reach.
	if KINDS[kind].effect == "smash" and _windup <= 0.0 and _cooldown <= 0.0 and _wall_ahead():
		_windup = SMASH_WINDUP
		_telegraph_smash()
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if KINDS[kind].effect == "smash":
				_smash()
			elif distance < _reach() + 10.0 and _can_reach(_target()):
				_attack()
			_lunge = 1.0
			_cooldown = CONTACT_COOLDOWN
		return
	if _cooldown <= 0.0 and distance < _reach() and _can_reach(_target()):
		_windup = _windup_time()
		if KINDS[kind].effect == "smash":
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
		player.take_damage(KINDS[kind].damage)
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
	return SMASH_REACH if KINDS[kind].effect == "smash" else CONTACT_RANGE


func _windup_time() -> float:
	match KINDS[kind].effect:
		"explode":
			return WINDUP * 0.6
		"smash":
			return SMASH_WINDUP
	return WINDUP


## A shooter in range charges its shot (a glow builds in front of it), then fires.
## A ninja cuts at the player when they get close.
func _ninja_strike(delta: float) -> void:
	_slash_cd = maxf(_slash_cd - delta, 0.0)
	if _slash_cd <= 0.0 and player and not _dead and _frozen_time <= 0.0 and player.center().distance_to(center()) < SLASH_RANGE:
		_slash_cd = SLASH_COOLDOWN
		_slash()


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
	var data: MobKind = KINDS[kind]
	if player == null:
		return
	var before := global_position
	var cruise_y := minf(player.center().y - 130.0, ArenaGen.GROUND_Y - 110.0)
	var speed_mult: float = data.speed * (0.5 if _slow_time > 0.0 else 1.0)
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
	if data.shot.size() > 0:
		_shot_timer -= delta
		var shot: Dictionary = data.shot
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
## A Barrier negates only a projectile (shot true); anything else gets through it.
func take_damage(amount: int, school := "", shot := false) -> void:
	if _dead or _spawn > 0.0 or puppet:
		return
	var data: MobKind = KINDS[kind]
	var dealt := amount
	if school != "" and school == data.resist:
		dealt = 0
	elif school != "" and school == data.weak:
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
	if data.effect == "dummy" and hp <= 0:
		hp = max_hp  # a dummy is never beaten: it stands up again
	_flash = 1.0
	var weak := dealt > amount
	FloatText.spawn(get_parent(), text_at, "%d%s" % [dealt, "!" if weak else ""], Color("#ff9a3a") if weak else Color("#fff0a0"), 1.25 if weak else 1.0)
	# Sparks take the spell's colour, not the enemy's.
	var spark: Color = SpellData.SCHOOL_COLORS.get(school, _school_colour())
	Fx.burst(get_parent(), center(), spark, 8, 120.0, 0.3, true)
	if hp <= 0:
		_die()
	else:
		Sfx.play("mob_hurt", center())
		if _visual.sprite_frames.has_animation("hit") and _windup <= 0.0 and _charge <= 0.0:
			_visual.play("hit")


## A defeated enemy bursts into smoke and its school's sparks, plays its death tumble, then disappears.
func _die() -> void:
	_dead = true
	if roams and not puppet:
		Net.send(self, &"_fell")  # the others' puppets of it fall too
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


@rpc("authority", "call_remote", "reliable")
func _fell() -> void:
	if not _dead:
		_die()


func _on_animation_finished() -> void:
	if _dead and _visual.animation == "death":
		var tween := create_tween()
		tween.tween_interval(0.4)
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	elif not _dead and _visual.animation in ["hit", "attack"]:
		_visual.play("idle")


func is_dead() -> bool:
	return _dead


## True while it draws back to strike.
func is_drawing_back() -> bool:
	return _windup > 0.0


## A Faint: all the stamina goes and the enemy drops to the ground, until its stamina is back to GET_UP.
func faint() -> void:
	if _dead or _fainted:
		return
	_fainted = true
	stamina = 0.0
	_since_stamina = 0.0
	_windup = 0.0
	_charge = 0.0
	FloatText.spawn(get_parent(), center() + Vector2(0, -_body_size.y * 0.5 - 6.0), "Fainted", Color("#c4162f"), 1.0)
	Sfx.play("mob_hurt", center())


func is_fainted() -> bool:
	return _fainted


func apply_no_jump(seconds: float) -> void:
	_nojump_time = maxf(_nojump_time, seconds)


## Holds the enemy where it stands, as a Flytrap does: it cannot walk, jump or be carried away by its own speed.
func is_rooted() -> bool:
	return _root_time > 0.0


func apply_root(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)
	_knock_x = 0.0


func is_slowed() -> bool:
	return _slow_time > 0.0


## Standing in water or lava: the part of it below the surface takes the liquid's colour for a moment after each call.
func soak(tint: Color, surface_y := INF, _lava := false) -> void:
	_liquid = tint
	_liquid_y = surface_y
	_liquid_time = 0.15


func apply_slow(seconds: float) -> void:
	if KINDS[kind].school == "Water":
		return  # water enemies cannot be slowed by ice or snow
	_slow_time = maxf(_slow_time, seconds)


## Encases the enemy in ice: it cannot move or attack until it thaws or something shatters it.
## Returns false for ice enemies, which shrug it off.
func freeze(seconds: float) -> bool:
	if KINDS[kind].school == "Water" or _dead:
		return false
	_frozen_time = maxf(_frozen_time, seconds)
	return true


func is_frozen() -> bool:
	return _frozen_time > 0.0


func knock_back(impulse: Vector2) -> void:
	if _frozen_time > 0.0:
		impulse *= 0.4  # a block of ice is heavy
	if KINDS[kind].effect == "smash":
		impulse *= 0.25  # a giant's bulk barely moves for a fireball
	_knock_x = impulse.x
	velocity.y = minf(velocity.y, impulse.y)  # a little lift for upward knocks


## A steady pull, such as a Gravity Well's. Call it every frame the pull lasts.
func pull(force: Vector2, delta: float) -> void:
	_drift += force * delta


## An enemy hits the player. Its effect (knockback, or an explosion) comes after the damage.
func _attack() -> void:
	var data: MobKind = KINDS[kind]
	_lunge = 1.0
	if data.effect == "explode":
		_explode()
		return
	var target := _target()
	if target != player:
		target.take_damage(data.damage)  # a decoy takes the blow
		Sfx.play("push", target.center(), -6.0)
		return
	var impulse := Vector2.ZERO
	match data.effect:
		"knockback":
			impulse = Vector2(signf(player.global_position.x - global_position.x) * 420.0, -160.0)
		"big_knockback":
			impulse = Vector2(signf(player.global_position.x - global_position.x) * 900.0, -220.0)
	_strike(player, data.damage, impulse)
	Sfx.play("stones" if data.school == "Earth" else "fire_hit" if data.school == "Fire" else "push", player.center(), -6.0)


func _explode() -> void:
	Fx.impact(get_parent(), center(), _school_colour(), 70.0)
	Fx.pop(get_parent(), center(), "spark_02", _school_colour(), 90.0, 0.3, 1.4, 3.0)
	Sfx.play("explosion", center())
	GameCamera.shake_scene(get_tree(), 0.4)
	# Damage the player and any other enemy close enough to the blast.
	if center().distance_to(player.center()) <= BURST_RADIUS:
		player.take_damage(KINDS[kind].damage)
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and other.center().distance_to(center()) <= BURST_RADIUS:
			other.take_damage(BURST_DAMAGE)
	_die()


func _process(delta: float) -> void:
	_idle_t += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_liquid_time = maxf(_liquid_time - delta, 0.0)
	var wet := _liquid_time > 0.0
	_material.set_shader_parameter("water_y", _liquid_y if wet else 1000000.0)
	_material.set_shader_parameter("water_tint", _liquid)
	_animate(delta)
	queue_redraw()
	_overlay.queue_redraw()


## Picks the animation for what the enemy is doing: attacking (the wind-up of a hit, the charge of a shot, a
## flyer's dive), flinching, walking or idling, and faces where it is going. Flyers bob as they hover.
func _animate(delta: float) -> void:
	var flying := _flies()
	if player and not _dead and _frozen_time <= 0.0:
		if flying or _windup > 0.0 or _charge > 0.0 or absf(velocity.x) < 5.0:
			facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else facing
		else:
			facing = signf(velocity.x)
	var lunge := 0.0
	if _lunge > 0.0:
		lunge = roundf(sin(_lunge * PI) * 8.0) * facing
		_lunge = maxf(_lunge - delta * 3.0, 0.0)
	var shake := Vector2.ZERO
	if flying and _fly_state == HOVER:
		shake = Vector2(randi_range(-1, 1), randi_range(-1, 1))
	var moving := not _dead and not _fainted and _frozen_time <= 0.0 and absf(velocity.x) > 5.0 and (is_on_floor() or flying)
	var wanted := "idle"
	if _fainted and _visual.sprite_frames.has_animation("death"):
		wanted = "death"
	elif _windup > 0.0 or _charge > 0.0 or (flying and _fly_state == DIVE):
		wanted = "attack"
	elif moving and _visual.sprite_frames.has_animation("walk"):
		wanted = "walk"
	var busy: bool = _visual.animation == "hit" or (_visual.animation == "attack" and _visual.is_playing())
	if not _dead and _visual.animation != wanted and not (busy and wanted != "attack"):
		_visual.play(wanted)
	_visual.speed_scale = 0.0 if _frozen_time > 0.0 else 1.0
	var bob := roundf(sin(_idle_t * 3.0) * 2.0) if flying else 0.0
	_visual.position = Vector2(lunge, bob) + shake
	_visual.scale = Vector2(_base_scale, _base_scale)
	_visual.flip_h = facing < 0.0
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


## Things drawn over the sprite: the shot charging, the ice block and the health bar.
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
	if hp < max_hp:
		var width := 28.0
		var top := _body_center.y - _body_size.y * 0.5 - 9.0
		var bar := Rect2(Vector2(-width * 0.5, top), Vector2(width, 4.0))
		o.draw_rect(bar.grow(1.0), Color(0.05, 0.03, 0.08, 0.85))
		o.draw_rect(Rect2(bar.position, Vector2(width * clampf(float(hp) / max_hp, 0.0, 1.0), 4.0)), Color("#e84a5f"))


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


func _burns() -> bool:
	return KINDS[kind].effect == "burning"


## A burning walker: one flame, tall enough to cover its whole body, stands on it and moves with it.
func _set_alight() -> void:
	var flame := PixelFx.sprite("fire_puff", 14.0, true, 1)
	flame.scale = Vector2.ONE * 3.7  # so the fire rises round the whole body
	# The flame's bottom sits on the walker's feet (its origin), and it is drawn behind the walker.
	flame.position = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5 * flame.scale.y + 55.0)  # 55: the feet sit this far below the origin
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
