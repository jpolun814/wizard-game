class_name Mob
extends CharacterBody2D

## An enemy. Each one has a role (melee walker, ranged shooter, or flyer) and a school. The school sets its
## colour and what it is weak or resistant to. Some schools also give their enemies a particular trick.

const KINDS := {
	"basic": {"name": "Basic", "desc": "A plain enemy with no weakness and no resistance.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "", "weak": "", "resist": "", "damage": 8, "speed": 1.0, "effect": ""},
	"dark_wizard": {"name": "Dark Wizard", "desc": "Keeps its distance and casts spells like yours.", "role": "wizard", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Shadow", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": ""},
	"force_melee": {"name": "Melee Force", "desc": "A plain walker with no strengths or weaknesses.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Force", "weak": "", "resist": "", "damage": 8, "speed": 1.0, "effect": "big_knockback"},
	"force_ranged": {"name": "Ranged Force", "desc": "Fires plain orbs from a distance.", "role": "ranged", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Force", "weak": "", "resist": "", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.2, "damage": 6}},
	"force_flyer": {"name": "Flying Force", "desc": "A plain flier that swoops down at you.", "role": "flyer", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Force", "weak": "", "resist": "", "damage": 6, "speed": 1.0, "effect": ""},
	"fire_melee": {"name": "Melee Fire", "desc": "Leaves a trail of fire as it walks.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Fire", "weak": "Ice", "resist": "Fire", "damage": 8, "speed": 1.0, "effect": "fire_trail"},
	"fire_ranged": {"name": "Ranged Fire", "desc": "Drops fireballs straight down on you from above.", "role": "ranged", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Fire", "weak": "Ice", "resist": "Fire", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.0, "damage": 8, "above": true}},
	"fire_flyer": {"name": "Flying Fire", "desc": "Drops fireballs while it flies over the arena.", "role": "flyer", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Fire", "weak": "Ice", "resist": "Fire", "damage": 6, "speed": 1.0, "effect": "", "shot": {"interval": 1.4, "damage": 6, "drop": true}},
	"ice_melee": {"name": "Melee Ice", "desc": "Leaves frost patches that slow you.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Ice", "weak": "Fire", "resist": "Ice", "damage": 6, "speed": 0.9, "effect": "frost_trail"},
	"ice_ranged": {"name": "Ranged Ice", "desc": "Fires a bolt that slows you.", "role": "ranged", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Ice", "weak": "Fire", "resist": "Ice", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.0, "damage": 4, "slow": true}},
	"ice_flyer": {"name": "Flying Ice", "desc": "Drops snow and icicles from above.", "role": "flyer", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Ice", "weak": "Fire", "resist": "Ice", "damage": 4, "speed": 1.0, "effect": "", "shot": {"interval": 1.8, "damage": 3, "slow": true, "drop": true}},
	"earth_melee": {"name": "Melee Earth", "desc": "Heavy. Hits hard and knocks you back.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Earth", "weak": "Storm", "resist": "Earth", "damage": 14, "speed": 0.6, "effect": "knockback"},
	"earth_ranged": {"name": "Ranged Earth", "desc": "Hurls boulders in an arc.", "role": "ranged", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Earth", "weak": "Storm", "resist": "Earth", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.6, "damage": 10, "gravity": 420.0}},
	"earth_flyer": {"name": "Flying Earth", "desc": "Drops boulders from the air.", "role": "flyer", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Earth", "weak": "Storm", "resist": "Earth", "damage": 8, "speed": 1.0, "effect": "", "shot": {"interval": 2.2, "damage": 8, "gravity": 300.0, "drop": true}},
	"storm_melee": {"name": "Melee Storm", "desc": "Fast. Explodes when it reaches you.", "role": "melee", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Storm", "weak": "Earth", "resist": "Storm", "damage": 6, "speed": 2.6, "effect": "explode"},
	"storm_ranged": {"name": "Ranged Storm", "desc": "Fires a fan of zaps.", "role": "ranged", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Storm", "weak": "Earth", "resist": "Storm", "damage": 0, "speed": 1.0, "effect": "", "shot": {"interval": 2.4, "damage": 5, "spread": 3}},
	"storm_flyer": {"name": "Flying Storm", "desc": "Divebombs you, then flies away.", "role": "flyer", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Storm", "weak": "Earth", "resist": "Storm", "damage": 8, "speed": 1.0, "effect": ""},
}
const SPEED := 80.0
const TERMINAL_FALL := 900.0  # no enemy falls faster than this
const FALL_LIMIT := 400.0     # an enemy below this has fallen off the map and is removed
const MAX_HP := 30
const TARGET_HEIGHT := 64.0   # the on-screen height of every enemy, whatever the art's native size
const CONTACT_RANGE := 50.0   # bodies stop about 42px apart when pressed together, so this must be larger
const CONTACT_COOLDOWN := 1.0
const KNOCK_DECAY := 1500.0
const MOB_JUMP := -320.0      # enough to clear a block, or reach a player standing above
const BURST_DAMAGE := 4       # a Stormrunner's explosion hurts everything close by this much
const BURST_RADIUS := 60.0
const SPIT_RANGE := 480.0       # a ranged enemy fires from this far away
const SPIT_STAND_RANGE := 300.0 # and stops walking once it is this close
const FLY_SPEED := 120.0        # how fast a flyer drifts while it patrols
const DIVE_SPEED := 340.0       # how fast a flyer dives at you
const RETREAT_SPEED := 240.0    # how fast it flies away after a dive
const FIRE_TRAIL_INTERVAL := 0.45
const FROST_TRAIL_INTERVAL := 0.8
const PATROL := 0
const DIVE := 1
const RETREAT := 2

var kind := "basic"  # set before the mob enters the tree
var caster: Caster  # only the dark wizard has one: it casts from its own strokes
var _cast_timer := 2.0
var stamina := 100.0      # the dark wizard spends stamina on spells, and it regenerates like yours
var last_spell := ""
var _look: Node2D
var _staff: Sprite2D
var _hand_right: Sprite2D
var _hand_rest := Vector2.ZERO
var _cast_pose := 0.0
var _draw_time := 0.0
var _stroke := PackedVector2Array()
var _stroke_colour := Color.WHITE
var _on_drawn: Callable
const DRAW_TIME := 0.8
const WIZARD_SPEED := 300.0  # the same as the player's running speed
var player: Node2D
var hp := MAX_HP
var _cooldown := 0.0
var _slow_time := 0.0
var _knock_x := 0.0
var _dead := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _walk_t := 0.0
var _idle_t := 0.0
var _squash := Vector2.ONE
var _facing := 1.0
var _shot_timer := 1.5
var _root_time := 0.0
var _base_scale := 1.0
var _lunge := 0.0        # 1 the moment an enemy attacks, fading to 0: it lunges toward the player
var _trail_timer := 0.0
var _fly_state := PATROL
var _fly_timer := 2.0
var _fly_goal_x := 0.0
var _fly_target := Vector2.ZERO
var _fly_away := 1.0
@onready var _visual: AnimatedSprite2D = $Visual
static var _frame_cache := {}  # recoloured animation frames, built once per enemy kind


func _ready() -> void:
	add_to_group("mobs")
	var data: Dictionary = KINDS[kind]
	_visual.sprite_frames = _frames_for(kind)
	# Each enemy's hitbox matches its drawn body, with the feet still at the bottom of the box.
	var hitbox: CollisionShape2D = $CollisionShape2D
	hitbox.shape = hitbox.shape.duplicate()
	var hit_h: float = data["hit"]
	(hitbox.shape as RectangleShape2D).size = Vector2(40.0, hit_h)
	hitbox.position = Vector2(0.0, 25.0 - hit_h / 2.0)
	_visual.animation_finished.connect(_on_animation_finished)
	var first: Texture2D = _visual.sprite_frames.get_frame_texture("idle", 0)
	_base_scale = TARGET_HEIGHT / first.get_height()
	_visual.play("idle")
	if data["role"] == "flyer":
		collision_mask = 0  # flyers pass through the terrain; they reach you from above
		_fly_goal_x = global_position.x
		_fly_timer = 1.0 + randf() * 2.0
	_shot_timer = 0.5 + randf() * 1.0
	if data["role"] == "wizard":
		_build_wizard_look()
		caster = Caster.new()
		add_child(caster)
		caster.set_process(false)  # cast from its own strokes only, never from the mouse
		caster.ground_check = Callable(get_parent(), "_is_ground_at")
		caster.cast_resolved.connect(Callable(get_parent(), "_on_wizard_cast").bind(self))


## The animation frames for each enemy kind, recoloured to its school. Built once per kind and reused.
func _frames_for(kind_name: String) -> SpriteFrames:
	if not _frame_cache.has(kind_name):
		var data: Dictionary = KINDS[kind_name]
		_frame_cache[kind_name] = _build_frames(data["frames"], data["idle"], data["school"])
	return _frame_cache[kind_name]


## Builds the animations from the frame files in a folder: idle (looping), walk, hit and death.
func _build_frames(dir: String, idle_prefix: String, school: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var files := DirAccess.get_files_at(dir)
	files.sort()
	var animations := [["idle", idle_prefix, true], ["walk", "walk", true], ["hit", "hit", false], ["death", "death", false]]
	for entry in animations:
		var anim_name: String = entry[0]
		var prefix: String = entry[1]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, entry[2])
		frames.set_animation_speed(anim_name, 12.0)
		for f in files:
			if f.begins_with(prefix + "_") and f.ends_with(".png"):
				if school != "":
					frames.add_frame(anim_name, SpellData.recoloured_image(Image.load_from_file(dir + "/" + f), school))
				else:
					frames.add_frame(anim_name, load(dir + "/" + f))
	return frames


func _physics_process(delta: float) -> void:
	if global_position.y > FALL_LIMIT:
		queue_free()
		return
	_cooldown -= delta
	_root_time -= delta
	if _slow_time > 0.0:
		_slow_time -= delta
	_knock_x = move_toward(_knock_x, 0.0, KNOCK_DECAY * delta)
	if KINDS[kind]["role"] == "wizard":
		_pose_wizard(delta)
		_wizard(delta)
		return
	if KINDS[kind]["role"] == "flyer":
		_fly(delta)
	else:
		_walk(delta)


## Walkers and shooters stay on the ground: they walk, jump blocks, shoot, or attack on contact.
func _walk(delta: float) -> void:
	var data: Dictionary = KINDS[kind]
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, TERMINAL_FALL)
	var speed: float = SPEED * data["speed"]
	if _slow_time > 0.0:
		speed *= 0.5
	var distance := player.global_position.distance_to(global_position) if player else INF
	var shooter: bool = data["role"] == "ranged"
	var stands_to_shoot := shooter and distance < SPIT_STAND_RANGE
	if player and not stands_to_shoot and _root_time <= 0.0:
		velocity.x = signf(player.global_position.x - global_position.x) * speed + _knock_x
	else:
		velocity.x = _knock_x
	# Enemies jump when a wall blocks them, or when the player is above them and close by.
	if is_on_floor() and player and _root_time <= 0.0 and not stands_to_shoot:
		var above := player.global_position.y < global_position.y - 30.0 and distance < 160.0
		if is_on_wall() or above:
			velocity.y = MOB_JUMP
	move_and_slide()
	# Some melee enemies leave something behind as they walk.
	if is_on_floor() and absf(velocity.x) > 5.0:
		_trail_timer -= delta
		if _trail_timer <= 0.0 and data["effect"] in ["fire_trail", "frost_trail"]:
			var fire: bool = data["effect"] == "fire_trail"
			_trail_timer = FIRE_TRAIL_INTERVAL if fire else FROST_TRAIL_INTERVAL
			if fire:
				Hazard.place(get_parent(), global_position + Vector2(0, 25), "fire", 26.0, 3.0)
			else:
				_leave_snow()
	if shooter and player and distance < SPIT_RANGE:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = data["shot"]["interval"]
			_shoot(data["shot"])
	if data["role"] == "melee" and player and _cooldown <= 0.0 and distance < CONTACT_RANGE and _can_reach_player():
		_attack()
		_cooldown = CONTACT_COOLDOWN


## Flyers drift over the arena above the player. Every so often they dive at the player, hit, and fly away.
func _fly(delta: float) -> void:
	var data: Dictionary = KINDS[kind]
	if player == null:
		return
	var before := global_position
	var cruise_y := maxf(player.global_position.y - 130.0, 30.0)
	var speed_mult: float = data["speed"]
	_fly_timer -= delta
	match _fly_state:
		PATROL:
			global_position.x += signf(_fly_goal_x - global_position.x) * FLY_SPEED * delta
			global_position.y = move_toward(global_position.y, cruise_y, 160.0 * delta)
			if absf(_fly_goal_x - global_position.x) < 12.0:
				_fly_goal_x = player.global_position.x + randf_range(-280.0, 280.0)
			if _fly_timer <= 0.0:
				_fly_state = DIVE
				_fly_target = player.global_position + Vector2(0, -8)
				_fly_timer = 1.6
		DIVE:
			var to_target := _fly_target - global_position
			global_position += to_target.normalized() * DIVE_SPEED * speed_mult * delta
			if global_position.distance_to(player.global_position) < CONTACT_RANGE and _can_reach_player():
				_attack()
				_fly_away = signf(global_position.x - player.global_position.x)
				_fly_state = RETREAT
				_fly_timer = 1.4
			elif _fly_timer <= 0.0 or to_target.length() < 6.0:
				_fly_away = signf(global_position.x - player.global_position.x)
				_fly_state = RETREAT
				_fly_timer = 1.4
		RETREAT:
			global_position.x += _fly_away * RETREAT_SPEED * delta
			global_position.y = move_toward(global_position.y, cruise_y - 60.0, 200.0 * delta)
			if _fly_timer <= 0.0:
				_fly_state = PATROL
				_fly_goal_x = player.global_position.x + randf_range(-280.0, 280.0)
				_fly_timer = 2.5
	global_position.x = clampf(global_position.x + _knock_x * delta, ArenaGen.LEFT_WALL * 16.0, ArenaGen.RIGHT_WALL * 16.0)
	if _hits_terrain(before, global_position):
		global_position = before  # flyers cannot pass through platforms or walls
		if _fly_state == DIVE:
			_fly_state = RETREAT
			_fly_timer = 1.2
	if data.get("shot", {}).size() > 0:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = data["shot"]["interval"]
			_shoot(data["shot"])


## Fires one of this enemy's shots. Shots take the enemy's school colour.
func _shoot(shot: Dictionary) -> void:
	var school: String = KINDS[kind]["school"]
	var colour: Color = SpellData.SCHOOL_COLORS[school] if school != "" else Color("#d8d0e8")
	var origin := _visual.global_position  # shots leave the middle of the sprite
	var aim := player.global_position
	var count: int = shot.get("spread", 1)
	for i in count:
		var angle := 0.0 if count == 1 else (i - (count - 1) * 0.5) * 0.12
		var target := origin + (aim - origin).rotated(angle)
		EnemyBolt.fire(get_parent(), origin, target, colour, shot["damage"], shot.get("gravity", 0.0), shot.get("slow", false))


## True when nothing solid stands between the enemy and the player. Enemies cannot hit through a platform.
func _can_reach_player() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 1  # terrain only
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Damage from a spell of the given school. Weak to a school takes double; resisting it takes nothing.
func take_damage(amount: int, school := "") -> void:
	if _dead:
		return
	var data: Dictionary = KINDS[kind]
	var dealt := amount
	if school != "" and school == data["resist"]:
		dealt = 0
	elif school != "" and school == data["weak"]:
		dealt = amount * 2
	if dealt <= 0:
		_show_damage_text("Resisted", Color(0.7, 0.7, 0.75))
		return
	hp -= dealt
	_squash = Vector2(1.2, 0.8)  # flinch when hit
	_show_damage_text("-%d%s" % [dealt, "!" if dealt > amount else ""], Color.YELLOW if dealt <= amount else Color("#ff8a3a"))
	# Sparks take the spell's colour, not the enemy's, and nothing sparks on the killing blow.
	if hp > 0:
		var spark_school: String = school if school != "" else data["school"]
		var spark: Color = SpellData.SCHOOL_COLORS[spark_school] if SpellData.SCHOOL_COLORS.has(spark_school) else Color("#d8d0e8")
		Fx.burst(get_parent(), global_position, spark, 10, 120.0, 0.3)
	if hp <= 0:
		_die()
	elif _visual.sprite_frames.has_animation("hit") and _visual.sprite_frames.get_frame_count("hit") > 0:
		_visual.play("hit")


## A defeated enemy plays its death animation, then disappears.
func _die() -> void:
	_dead = true
	remove_from_group("mobs")
	set_physics_process(false)
	if _visual.sprite_frames.has_animation("death") and _visual.sprite_frames.get_frame_count("death") > 0:
		_visual.play("death")
	else:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)


func _on_animation_finished() -> void:
	if _dead and _visual.animation == "death":
		queue_free()
	elif not _dead and _visual.animation == "hit":
		_visual.play("idle")


func apply_root(seconds: float) -> void:
	_root_time = maxf(_root_time, seconds)


func apply_slow(seconds: float) -> void:
	if KINDS[kind]["school"] == "Ice":
		return  # ice enemies cannot be slowed by ice or snow
	_slow_time = maxf(_slow_time, seconds)


func knock_back(impulse: Vector2) -> void:
	_knock_x = impulse.x
	velocity.y = minf(velocity.y, impulse.y)  # a little lift for upward knocks


## An enemy hits the player. Its effect (knockback, or an explosion) comes after the damage.
func _attack() -> void:
	var data: Dictionary = KINDS[kind]
	_lunge = 1.0
	player.take_damage(data["damage"])
	match data["effect"]:
		"knockback":
			player.push(Vector2(signf(player.global_position.x - global_position.x) * 420.0, -160.0))
		"big_knockback":
			player.push(Vector2(signf(player.global_position.x - global_position.x) * 900.0, -220.0))
		"explode":
			_explode()


func _explode() -> void:
	var burst := Burst.new()
	burst.global_position = global_position
	get_parent().add_child(burst)
	# Damage the player and any other enemy close enough to the blast.
	if global_position.distance_to(player.global_position) <= BURST_RADIUS:
		player.take_damage(BURST_DAMAGE)
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and other.global_position.distance_to(global_position) <= BURST_RADIUS:
			other.take_damage(BURST_DAMAGE)
	queue_free()


## A short expanding ring that fades out, left behind where the enemy exploded.
class Burst extends Node2D:
	const DURATION := 0.4
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DURATION:
			queue_free()

	func _draw() -> void:
		var progress := _t / DURATION
		draw_circle(Vector2.ZERO, 10.0 + (BURST_RADIUS - 10.0) * progress, Color(0.55, 0.36, 0.18, 0.8 * (1.0 - progress)))


func _show_damage_text(text: String, color: Color) -> void:
	var number := Label.new()
	number.text = text
	number.position = Vector2(-10, -50)
	number.modulate = color
	add_child(number)
	var tween := create_tween()
	tween.tween_property(number, "position:y", -90.0, 0.6)
	tween.parallel().tween_property(number, "modulate:a", 0.0, 0.6)
	tween.tween_callback(number.queue_free)


func _process(delta: float) -> void:
	_animate(delta)


## A hop while walking, a gentle idle bob, a squash when hit, a lunge when attacking, and a turn to face
## where the enemy is going. Flyers hover instead of hopping.
func _animate(delta: float) -> void:
	var flying: bool = KINDS[kind]["role"] == "flyer"
	var moving := (flying or is_on_floor()) and absf(velocity.x) > 5.0 and not _dead
	if flying and player and not _dead:
		moving = absf(global_position.x - _fly_goal_x) > 4.0
	if moving:
		_walk_t += delta * 9.0
		_facing = signf(velocity.x) if not flying else signf(player.global_position.x - global_position.x) if player else _facing
	_idle_t += delta
	_squash = _squash.lerp(Vector2.ONE, minf(delta * 8.0, 1.0))
	var lunge := 0.0
	if _lunge > 0.0 and player:
		lunge = sin(_lunge * PI) * 12.0 * signf(player.global_position.x - global_position.x)
		_lunge = maxf(_lunge - delta * 3.0, 0.0)
	var walking := moving and not flying and _visual.sprite_frames.get_frame_count("walk") > 0
	var wanted := "walk" if walking else "idle"
	if not _dead and _visual.animation != "hit" and _visual.animation != wanted:
		_visual.play(wanted)
	var hop := absf(sin(_walk_t)) * 3.0 if walking else 0.0
	var idle := sin(_idle_t * 2.5) * 0.6 if not walking else 0.0
	_visual.position = Vector2(lunge, KINDS[kind]["feet"] - hop + idle)  # each kind's art sits so its feet meet the collision box
	_visual.scale = Vector2(_base_scale * _squash.x * _facing, _base_scale * _squash.y)


## An ice enemy leaves snow falling behind it, the same as the Snowfall spell.
func _leave_snow() -> void:
	var snow := SpellEffect.new()
	snow.polygon = PackedVector2Array([Vector2(0, -60), Vector2(40, -60), Vector2(40, 60), Vector2(0, 60)])
	get_parent().add_child(snow)
	snow.setup("Snowfall", global_position + Vector2(-20, 0), 0.0)


## True when solid terrain lies between two points. Flyers use it to stay out of platforms and walls.
func _hits_terrain(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## A dark wizard holds its distance on the ground and, every few seconds, casts a spell at the player.
func _wizard(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, TERMINAL_FALL)
	if player:
		var gap := player.global_position.x - global_position.x
		var toward := signf(gap)
		if absf(gap) < 240.0:
			velocity.x = -toward * WIZARD_SPEED
		elif absf(gap) > 320.0:
			velocity.x = toward * WIZARD_SPEED
		else:
			velocity.x = 0.0
		caster.anchor = global_position
	stamina = minf(100.0, stamina + 20.0 * delta)
	if is_on_floor() and (is_on_wall() or (player and player.global_position.y < global_position.y - 60.0)):
		velocity.y = -450.0
	move_and_slide()
	_cast_timer -= delta
	if _draw_time > 0.0:
		_draw_time -= delta
		queue_redraw()
		if _draw_time <= 0.0:
			_on_drawn.call(_stroke)
			_stroke = PackedVector2Array()
	if _cast_timer <= 0.0 and player and _draw_time <= 0.0:
		if get_parent().call("wizard_cast", self):
			_cast_timer = 2.5 + randf() * 1.5
		else:
			_cast_timer = 0.6


## The dark wizard is the player\'s own character, recoloured dark with red eyes.
func _build_wizard_look() -> void:
	var scene: Node = load("res://scenes/player.tscn").instantiate()
	_look = scene.get_node("Look")
	scene.remove_child(_look)
	scene.queue_free()
	_look.scale = Vector2.ONE * 0.07
	_look.position = Vector2(0, -2)  # the same placement as the player's artwork
	var body_box: CollisionShape2D = $CollisionShape2D
	(body_box.shape as RectangleShape2D).size = Vector2(40.0, 46.0)
	body_box.position = Vector2.ZERO
	_look.modulate = Color(0.5, 0.32, 0.6)
	var eyes := _look.get_node_or_null("Eyes")
	if eyes:
		eyes.modulate = Color(1.0, 0.25, 0.2)
	_staff = _look.get_node("Staff")
	_hand_right = _look.get_node("HandRight")
	_hand_rest = _hand_right.position
	add_child(_look)
	_visual.visible = false


## Shows the stroke being drawn in front of the dark wizard for a moment, then calls on_done with it.
func start_drawing(points: PackedVector2Array, colour: Color, on_done: Callable) -> void:
	_stroke = points
	_stroke_colour = colour
	_on_drawn = on_done
	_draw_time = DRAW_TIME


func _draw() -> void:
	if _draw_time <= 0.0 or _stroke.is_empty():
		return
	var progress := 1.0 - _draw_time / DRAW_TIME
	var count := int(_stroke.size() * progress)
	var local := PackedVector2Array()
	for i in count:
		local.append(_stroke[i] - global_position)
	if local.size() >= 2:
		draw_polyline(local, Color(_stroke_colour.r, _stroke_colour.g, _stroke_colour.b, 0.9), 3.0)
		draw_polyline(local, Color(1.0, 1.0, 1.0, 0.9), 1.0)


## The wizard lifts its staff and hand while drawing, and faces the player.
func _pose_wizard(delta: float) -> void:
	var drawing := 1.0 if _draw_time > 0.0 else 0.0
	_cast_pose = move_toward(_cast_pose, drawing, delta * 5.0)
	if player:
		_look.scale.x = 0.07 * signf(player.global_position.x - global_position.x)
	_look.position.y = -2.0 - (absf(sin(_walk_t)) * 3.0 if is_on_floor() and absf(velocity.x) > 5.0 else 0.0)
	_look.position.y = 20.0 - (absf(sin(_walk_t)) * 3.0 if is_on_floor() and absf(velocity.x) > 5.0 else 0.0)
	_staff.rotation = -0.5 * _cast_pose
	_hand_right.position = _hand_rest + Vector2(0, -140.0 * _cast_pose)
