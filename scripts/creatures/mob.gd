class_name Mob
extends CharacterBody2D

## A creature: the skeletons (the graveyard's dead, a crypt's guard, a raised skeleton, the tutorial's), the giant, the castle's knights, and the
## practice dummy and turret. Each is a walker or a shooter, and some have a school, which sets an outline in its color and what it is weak or
## resistant to. (The wizards are not mobs: see Wizard.) "scale" draws a creature bigger, always at a whole number of pixels so the pixel art
## stays sharp. Its origin is at its feet, so it stands exactly on the ground. Every attack is telegraphed: walkers wind up, shooters charge a glow.

## Every kind of enemy, by the name it is summoned by, each a MobKind resource read from res://data/mobs/ in the order they are meant to be listed.
static var KINDS: Dictionary = _load_kinds()


static func _load_kinds() -> Dictionary:
	var found: Array[MobKind] = []
	for file in ResourceLoader.list_directory("res://data/mobs"):
		file = file.trim_suffix(".remap")  # an exported game lists remapped resources under this name
		if file.ends_with(".tres") or file.ends_with(".res"):
			found.append(load("res://data/mobs/" + file))
	found.sort_custom(func(x: MobKind, y: MobKind) -> bool: return x.sort_order < y.sort_order)
	var out := {}
	for kind in found:
		out[kind.id] = kind
	return out

const SPEED := 80.0
const SHAKE_REACH := 700.0  # a creature's fall or blast shakes only the screens of those this near (not every screen in the world)
const TERMINAL_FALL := 900.0  # no enemy falls faster than this
const FALL_LIMIT := 800.0     # an enemy below this has fallen off the map and is removed (in a world, the bottom of the world)
const CONTACT_RANGE := 40.0   # how close (middle to middle) a walker must be to hit
const CONTACT_COOLDOWN := 1.1
const WINDUP := 0.3           # a walker draws back this long before it hits
const GIANT_JUMP := -640.0    # a giant leaps higher than a plain walker: onto ledges, and over walls
const CHARGE := 0.45          # a shooter's glow builds this long before it fires
const KNOCK_DECAY := 1500.0
const MOB_JUMP := -420.0      # enough to clear two blocks
const MOB_JUMP_HIGH := -560.0 # enough to reach a platform when the player is up on one
const GUARD_NOTICE := 330.0    # a guard (a knight) notices a wizard this close, and goes back to its post once they are farther than that
const ROAM_NOTICE := 560.0     # a roaming enemy notices the player this close, and loses them again past a little farther
const FOLLOW_GAP := 110.0      # a raised skeleton with no one to fight keeps about this close to its master
const FOLLOW_REACH := 1100.0   # and goes no farther than this to find them
const DECOY_NOTICE := 520.0    # a decoy this close is noticed, and attacked instead of the player
const SPIT_RANGE := 480.0       # a ranged enemy fires from this far away
const SPIT_STAND_RANGE := 300.0 # and stops walking once it is this close
const GET_UP := 10.0           # a fainted enemy stands up when its stamina is this high again
const STAMINA_CAP := 100.0     # the most stamina an enemy has
const SPAWN_TIME := 0.7         # enemies fade in over a summoning circle and cannot act until it is done
const CREATURE_ANIMATIONS := {
	"idle": {"fps": 8.0}, "walk": {"fps": 10.0}, "attack": {"fps": 14.0, "loop": false},
	"hit": {"fps": 12.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
var kind := "basic"  # set before the mob enters the tree
var stomp := Stomp.new(self)  # a giant's stomp
var player: Node2D
var guards := false  # a knight at its post: it stands still until a wizard comes near, then fights them, and walks back to its post afterwards
var post_x := 0.0  # where a guard stands
var roams := false  # one the world left wandering (the graveyard's dead): it ambles about until a wizard comes near, then gives chase
var _swing_seen := false  # a puppet: the host's was drawing back at the last news
var shared := false  # the world keeps its place in step across the network (a roamer or a crypt guard): its fall is told to the other machines
var puppet := false  # in a network game, a roamer on a machine that is not the host: it shows what the host's one does and decides nothing
var net_position := Vector2.ZERO  # where the host says it is, while it is a puppet
var net_facing := 1.0
var net_swing := false  # the host's is drawing back to strike
var master: Wizard  # the wizard who raised this one from the dead (Raise Dead), or null for any other: it never attacks its master, and fights the dead another wizard raised
var _foe: Mob       # a dead another wizard raised, which it has picked to fight
var _master_sync := 0.0
var _prey_time := 0.0
var _wander := 0.0
var _wander_time := 0.0
var hp := 30
var max_hp := 30
var stamina := 100.0      # a Faint takes all of it; it comes back as a wizard's does, and the enemy stands up when there is enough
var _cooldown := 0.0
var faint_stays := false  # a Faint on it is not slept off (the tutorial's skeleton)
var felled_stays := false  # a practice dummy that can be beaten: it falls and stays down (the tutorial's)
var _since_hit := 0.0  # seconds since this enemy was last hurt; a dummy heals once it has been left alone
var _slow_time: float:
	get: return _status.left(&"slow")
	set(seconds): _status.set_left(&"slow", seconds)
var _knock_x := 0.0
var _drift := Vector2.ZERO  # a pull (a Black Hole's) that fades
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
var _base_scale := 1.0
var _lunge := 0.0        # 1 the moment an enemy attacks, fading to 0: it lunges toward the player
var _windup := 0.0       # counting down to a melee hit
var _lie_side := 1.0     # which way a fainted enemy with no fall of its own topples
var _stuck := 0.0       # how long a giant has been held up by a ledge
var _last_x := 0.0       # where a giant was last frame, to tell whether it is moving
var _charge := 0.0       # counting down to a shot
var _flash := 0.0
var _liquid := Color.WHITE  # the color of the water or lava it stands in
var _liquid_time := 0.0
var _liquid_y := INF  # the height of the surface of that liquid
var _spawn := SPAWN_TIME
var _body_size := Vector2(30, 40)  # the hitbox, in world pixels
var _body_center := Vector2(0, -20)
var _overlay: Node2D               # draws health bar, ice, shield and charge glows on top of the sprite
var _material: ShaderMaterial
@onready var _visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	add_child(_status)
	_status.ended.connect(func(status: StringName) -> void:
		if status == &"frozen":
			Shatter.spawn(get_parent(), center(), Color("#cdeeff")))  # the ice gives way
	floor_max_angle = deg_to_rad(50.0)
	add_to_group("mobs")
	var data: MobKind = KINDS[kind]
	max_hp = data.hp
	hp = max_hp
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_overlay)
	_build_creature(data)
	_shot_timer = 0.8 + randf() * 1.2
	# Every enemy arrives through a summoning circle.
	Fx.pop(get_parent(), global_position + Vector2(0, -2), "magic_02", _school_color(), 70.0, SPAWN_TIME + 0.2, 1.2, 1.5)
	Sfx.play("summon", global_position)
	modulate.a = 0.0


## A creature drawn from art/mobs: its frames, its size, and a hitbox that matches the body in the drawing.
func _build_creature(data: MobKind) -> void:
	var art: String = data.art
	var info: Dictionary = PixelArt.CHARACTERS[art]
	_visual.sprite_frames = CharFrames.build("res://art/mobs/" + art, CREATURE_ANIMATIONS)
	if data.effect == "smash":
		# The lean is slowed to fill the giant's wind-up: the three frames of drawing back last as long as the wind-up does, so the swing down
		# (the fourth frame) is on screen at the moment the blow lands, not before it.
		_visual.sprite_frames.set_animation_speed("attack", 3.0 / Stomp.WINDUP)
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # scaled-up pixel art stays crisp, not blurred
	_base_scale = data.scale
	var body: Rect2 = info["body"]
	var frame: Vector2 = info["size"]
	var hitbox: CollisionShape2D = $CollisionShape2D
	# The frames have its feet on the bottom edge. Its hitbox is its body, not a weapon held out.
	_visual.offset = Vector2(0, -frame.y * 0.5)
	_set_walker_body(Vector2(body.size.x * 0.85, body.size.y * 0.95) * _base_scale)
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


## The creature's own colors, with a little of its school's color and an outline in it. Plain enemies get no
## outline at all.
func _apply_material() -> void:
	var school: String = KINDS[kind].school
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/creatures/mob.gdshader")
	_material.set_shader_parameter("school_color", _school_color())
	_material.set_shader_parameter("tint", 0.0 if school in ["", "Shadow"] else 0.22)
	_material.set_shader_parameter("outline", 0.0 if school == "" else 0.9)
	_visual.material = _material


func _school_color() -> Color:
	var school: String = KINDS[kind].school
	return SpellData.SCHOOL_COLORS.get(school, Color("#d8d0e8"))


## The middle of the enemy's body in the world. Spells and the player's aim go here.
func center() -> Vector2:
	return global_position + _body_center


func _physics_process(delta: float) -> void:
	if puppet:
		_glide(delta)
		return
	if roams or guards:
		_pick_prey(delta)
	if master != null and (not is_instance_valid(master) or master.dead) and not _dead:
		_die()  # it was held up by its master's will: when the master is beaten it falls
		return
	_share_raised(delta)
	if global_position.y > (ArenaGen.world_size.y * float(ArenaGen.TILE) if ArenaGen.world_size.y > 0 else FALL_LIMIT):
		queue_free()
		return
	if _spawn > 0.0:
		_spawn -= delta
		modulate.a = clampf(1.0 - _spawn / SPAWN_TIME, 0.0, 1.0)
		_fall(delta)
		velocity.x = 0.0
		move_and_slide()
		return
	modulate.a = 1.0
	_cooldown -= delta
	_since_hit += delta
	if KINDS[kind].effect == "dummy" and _since_hit > 3.0 and not felled_stays:
		hp = max_hp  # a dummy heals as soon as you stop
	_knock_x = move_toward(_knock_x, 0.0, KNOCK_DECAY * delta)
	_drift = _drift.move_toward(Vector2.ZERO, 900.0 * delta)
	if _frozen_time > 0.0:
		_windup = 0.0
		_charge = 0.0
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
		if stamina >= GET_UP and not faint_stays:
			_fainted = false
			if _visual.sprite_frames.has_animation("idle"):
				_visual.play("idle")
		else:
			_fall(delta)
			velocity.x = _knock_x + _drift.x
			move_and_slide()
			return
	_walk(delta)
	if KINDS[kind].effect == "smash":
		_climb_ledges(delta)


## A giant's tall, wide hitbox can catch the lip of a ledge without touching a wall, and stop dead. When it is held up
## like that on the way to the player, it jumps.
func _climb_ledges(delta: float) -> void:
	# Only a giant that is trying to walk and not moving counts: one winding up a smash stands still on purpose.
	var held: bool = is_on_floor() and _windup <= 0.0 and _root_time <= 0.0 and player != null and absf(player.center().x - center().x) > 60.0 and absf(global_position.x - _last_x) < 0.5
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
	var stands_to_shoot: bool = shooter and distance < SPIT_STAND_RANGE and sees
	if guards and distance > GUARD_NOTICE:
		_hold_post(speed)
		return
	if roams and distance > ROAM_NOTICE:
		if master != null:
			_follow_master(speed)
		else:
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
	if net_swing and not _swing_seen:
		_windup = _windup_time()  # a swing is drawn all the way through, even if the packets after the first are lost
		_lunge = 0.0
	elif _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_lunge = 1.0
	_swing_seen = net_swing


## A roamer goes after the nearest wizard who is still standing, whoever's they are (looked for a few times a second).
func _pick_prey(delta: float) -> void:
	_prey_time -= delta
	if _prey_time > 0.0:
		return
	_prey_time = 0.4
	player = null
	_foe = null
	var nearest := INF
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		var gap := wizard.global_position.distance_squared_to(global_position)
		if wizard != master and not wizard.dead and wizard.is_seen_from(global_position) and gap < nearest:
			nearest = gap
			player = wizard
	if master == null:
		return
	# The dead another wizard raised are fought too, whichever is nearer.
	var foe_gap := minf(nearest, ROAM_NOTICE * ROAM_NOTICE)
	for other: Mob in get_tree().get_nodes_in_group("mobs"):
		if other.master == null or other.master == master or other.is_dead() or other._spawn > 0.0:
			continue
		var gap := other.global_position.distance_squared_to(global_position)
		if gap < foe_gap and _can_reach(other):
			foe_gap = gap
			_foe = other


## Hits a wizard for a mob. A wizard another machine drives is told to take the blow, since only its own machine can.
func _strike(target: Node2D, amount: int, impulse := Vector2.ZERO) -> void:
	if target is Wizard and target.is_likeness():
		target.rpc_id(target.get_multiplayer_authority(), &"_struck_by_a_mob", amount, impulse)
		return
	target.take_damage(amount)
	if impulse != Vector2.ZERO:
		target.push(impulse)


## A raised skeleton with no one to fight stays near its master: it walks toward them until it is close, and hops what blocks the way.
func _follow_master(speed: float) -> void:
	var to := master.center() - center()
	var coming := absf(to.x) > FOLLOW_GAP and to.length() < FOLLOW_REACH and _root_time <= 0.0 and _windup <= 0.0
	velocity.x = (signf(to.x) * speed if coming else 0.0) + _knock_x + _drift.x
	if is_on_floor() and coming and _nojump_time <= 0.0 and (is_on_wall() or (to.y < -50.0 and absf(to.x) < 140.0)):
		velocity.y = MOB_JUMP_HIGH if to.y < -50.0 else MOB_JUMP
	move_and_slide()


## In a network game the machine that drives a raised skeleton's master tells the others where it is and what it is doing; theirs only show it.
func _share_raised(delta: float) -> void:
	if master == null or puppet or not Net.online():
		return
	_master_sync -= delta
	if _master_sync > 0.0:
		return
	_master_sync = 0.05
	Net.send(self, &"_raised_at", [global_position, facing, is_drawing_back()])


@rpc("authority", "call_remote", "unreliable")
func _raised_at(at: Vector2, face: float, swing: bool) -> void:
	net_position = at
	net_facing = face
	net_swing = swing


## A blow from another wizard's dead, struck on a machine where this one is only a puppet.
@rpc("any_peer", "call_remote", "reliable")
func _struck_by_the_dead(amount: int) -> void:
	take_damage(amount)


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


## A guard with nobody near stands at its post, facing the way it was put, and walks back to it if it was drawn away.
func _hold_post(speed: float) -> void:
	var off := post_x - global_position.x
	velocity.x = (signf(off) * speed if absf(off) > 6.0 else 0.0) + _knock_x + _drift.x
	move_and_slide()


## A walker that is close enough draws back, then lunges. If the player moved away during the wind-up, it misses.
func _update_melee(delta: float, distance: float) -> void:
	# A giant that walks into a stone wall or boulder swings at it, even with the player out of reach.
	if KINDS[kind].effect == "smash" and _windup <= 0.0 and _cooldown <= 0.0 and stomp.wall_ahead():
		_windup = Stomp.WINDUP
		stomp.telegraph()
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			if KINDS[kind].effect == "smash":
				stomp.land()
			elif distance < _reach() + 10.0 and _can_reach(_target()):
				_attack()
			_lunge = 1.0
			_cooldown = CONTACT_COOLDOWN
		return
	if _cooldown <= 0.0 and distance < _reach() and _can_reach(_target()):
		_windup = _windup_time()
		if KINDS[kind].effect == "smash":
			stomp.telegraph()


## How far a melee enemy's hit reaches: a giant's stomp reaches much farther than a fist.
func _reach() -> float:
	return Stomp.REACH if KINDS[kind].effect == "smash" else CONTACT_RANGE


func _windup_time() -> float:
	return Stomp.WINDUP if KINDS[kind].effect == "smash" else WINDUP


## A shooter in range charges its shot (a glow builds in front of it), then fires.
func _update_shooter(delta: float, distance: float, sees: bool, shot: Dictionary) -> void:
	if _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_shoot(shot)
		return
	if distance < SPIT_RANGE and sees:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = shot["interval"]
			_charge = shot.get("charge", CHARGE)


## Fires one of this enemy's shots at its target, in its school color.
func _shoot(shot: Dictionary) -> void:
	var origin := center() + Vector2(facing * _body_size.x * 0.5, -4.0)
	EnemyBolt.fire(get_parent(), origin, _quake_target(origin, _target().center()), _school_color(), shot["damage"], self)
	Sfx.play("mob_shoot", origin)


## Who this enemy is after: a decoy it has noticed, otherwise the player.
func _target() -> Node2D:
	if is_instance_valid(_foe) and not _foe.is_dead():
		return _foe
	var decoy := Decoy.nearest(get_tree(), center(), DECOY_NOTICE)
	if decoy != null and _can_reach(decoy):
		return decoy
	return player


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
		MatchStats.strike(null)
		return
	hp -= dealt
	var counted := float(dealt) + minf(float(hp), 0.0)  # (a blow past the last of its strength counts only for what was left)
	_since_hit = 0.0
	if data.effect == "dummy" and hp <= 0 and not felled_stays:
		hp = max_hp  # a dummy is never beaten: it stands up again
	_flash = 1.0
	var weak := dealt > amount
	FloatText.spawn(get_parent(), text_at, "%d%s" % [dealt, "!" if weak else ""], Color("#ff9a3a") if weak else Color("#fff0a0"), 1.25 if weak else 1.0)
	# Sparks take the spell's color, not the enemy's.
	var spark: Color = SpellData.SCHOOL_COLORS.get(school, _school_color())
	Fx.burst(get_parent(), center(), spark, 8, 120.0, 0.3, true)
	if hp <= 0:
		_die()
	else:
		Sfx.play("mob_hurt", center())
		if _visual.sprite_frames.has_animation("hit") and _windup <= 0.0 and _charge <= 0.0:
			_visual.play("hit")
	MatchStats.hit(self, counted, school)


## A defeated enemy bursts into smoke and its school's sparks, plays its death tumble, then disappears.
func _die() -> void:
	_dead = true
	if (roams or shared or guards) and not puppet:
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
	Fx.burst(get_parent(), center(), _school_color(), 18, 180.0, 0.6, true)
	Fx.smoke(get_parent(), center(), Color(0.25, 0.2, 0.3, 0.6), 5, 30.0)
	GameCamera.shake_near(get_tree(), global_position, 0.18, SHAKE_REACH)
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
	_lie_side = facing
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


## Standing in water or lava: the part of it below the surface takes the liquid's color for a moment after each call.
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


## True for an enemy that ice cannot hold: one already beaten.
func shrugs_off_cold() -> bool:
	return _dead


## How big the body is, for the block of ice that is built round it.
func body_extent() -> Vector2:
	return _body_size


func knock_back(impulse: Vector2) -> void:
	if _frozen_time > 0.0:
		impulse *= 0.4  # a block of ice is heavy
	if KINDS[kind].effect == "smash":
		impulse *= 0.25  # a giant's bulk barely moves for a fireball
	_knock_x = impulse.x
	velocity.y = minf(velocity.y, impulse.y)  # a little lift for upward knocks


## A steady pull, such as a Black Hole's. Call it every frame the pull lasts.
func pull(force: Vector2, delta: float) -> void:
	_drift += force * delta


## An enemy hits the player. Its effect (a knockback) comes after the damage.
func _attack() -> void:
	var data: MobKind = KINDS[kind]
	_lunge = 1.0
	var target := _target()
	if target != player:
		if target is Mob and target.puppet:
			Net.send(target, &"_struck_by_the_dead", [data.damage])  # the machine that drives it decides what the blow does
		else:
			target.take_damage(data.damage)  # a decoy takes the blow
		Sfx.play("push", target.center(), -6.0)
		return
	var impulse := Vector2(signf(player.global_position.x - global_position.x) * 420.0, -160.0) if data.effect == "knockback" else Vector2.ZERO
	_strike(player, data.damage, impulse)
	Sfx.play("stones" if data.school == "Earth" else "push", player.center(), -6.0)


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


## Picks the animation for what the enemy is doing: attacking (the wind-up of a hit, the charge of a shot), flinching, walking or idling, and faces
## where it is going.
func _animate(delta: float) -> void:
	if player and not _dead and _frozen_time <= 0.0:
		if _windup > 0.0 or _charge > 0.0 or absf(velocity.x) < 5.0:
			facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else facing
		else:
			facing = signf(velocity.x)
	var lunge := 0.0
	if _lunge > 0.0:
		lunge = roundf(sin(_lunge * PI) * 8.0) * facing
		_lunge = maxf(_lunge - delta * 3.0, 0.0)
	var moving := not _dead and not _fainted and _frozen_time <= 0.0 and absf(velocity.x) > 5.0 and is_on_floor()
	var wanted := "idle"
	if _fainted and _visual.sprite_frames.has_animation("death"):
		wanted = "death"
	elif _windup > 0.0 or _charge > 0.0:
		wanted = "attack"
	elif moving and _visual.sprite_frames.has_animation("walk"):
		wanted = "walk"
	var busy: bool = _visual.animation == "hit" or (_visual.animation == "attack" and _visual.is_playing())
	if not _dead and _visual.animation != wanted and not (busy and wanted != "attack"):
		_visual.play(wanted)
	var lies := _fainted and not _visual.sprite_frames.has_animation("death")  # one with no fall of its own is toppled over instead
	_visual.rotation = lerp_angle(_visual.rotation, PI * 0.5 * _lie_side if lies else 0.0, minf(delta * 5.0, 1.0))
	_visual.speed_scale = 0.0 if _frozen_time > 0.0 or lies else 1.0
	_visual.position = Vector2(lunge, 0.0)
	_visual.scale = Vector2(_base_scale, _base_scale)
	_visual.flip_h = facing < 0.0
	if _material:
		var charging := 0.0
		if _windup > 0.0:
			charging = 0.35 * (1.0 - _windup / WINDUP)
		_material.set_shader_parameter("flash", maxf(_flash, charging))
		_material.set_shader_parameter("flash_color", Color.WHITE if _flash > charging else _school_color().lightened(0.5))
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
		var c := _school_color()
		Fx.draw_glow(o, at, 6.0 + 12.0 * k, Color(c.r, c.g, c.b, 0.5 + 0.5 * k))
		var orbs := PixelFx.frames("dark_orb", 12.0, true)
		var orb := orbs.get_frame_texture("default", int(_idle_t * 12.0) % orbs.get_frame_count("default"))
		var size := 1.0 + floorf(k * 2.0)
		o.draw_texture_rect(orb, Rect2(at - Vector2.ONE * 8.0 * size, Vector2.ONE * 16.0 * size), false, c.lightened(0.4))
	if hp < max_hp:
		var width := 28.0
		var top := _body_center.y - _body_size.y * 0.5 - 9.0
		var bar := Rect2(Vector2(-width * 0.5, top), Vector2(width, 4.0))
		o.draw_rect(bar.grow(1.0), Color(0.05, 0.03, 0.08, 0.85))
		o.draw_rect(Rect2(bar.position, Vector2(width * clampf(float(hp) / max_hp, 0.0, 1.0), 4.0)), Color("#e84a5f"))


## While the ground shakes, a shooter's aim is turned a few degrees off its mark.
func _quake_target(origin: Vector2, target: Vector2) -> Vector2:
	if not Earthquake.is_shaking(get_tree()):
		return target
	return origin + (target - origin).rotated(deg_to_rad(randf_range(-Earthquake.AIM_DEGREES, Earthquake.AIM_DEGREES)))
