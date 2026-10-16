class_name Mob
extends CharacterBody2D

## Walker that moves toward the player and attacks on contact. Each kind hits the player
## differently, so each one calls for a different response. Animated with the pack's frames.

const KINDS := {
	"grunt": {"name": "Grunt", "desc": "Charges you and hits on contact.", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Fire", "weak": "Ice", "resist": "Fire", "damage": 8, "debuff": "", "seconds": 0.0},
	"muter": {"name": "Muter", "desc": "Its touch silences your casting for a while.", "frames": "res://art/enemies/muter", "idle": "idle", "feet": -0.5, "hit": 24.0, "school": "Force", "weak": "Lightning", "resist": "Force", "damage": 4, "debuff": "mute", "seconds": 12.0},
	"rooter": {"name": "Rooter", "desc": "Roots you on touch, then bursts. Runs fast.", "frames": "res://art/enemies/rooter", "speed": 3.0, "idle": "idle", "feet": 1.5, "hit": 24.0, "school": "Ice", "weak": "Fire", "resist": "Ice", "damage": 0, "debuff": "root", "seconds": 2.0},
	"blinder": {"name": "Blinder", "desc": "Flies in and blinds you on touch.", "frames": "res://art/enemies/blinder", "idle": "fly", "feet": 0.7, "hit": 44.0, "school": "Lightning", "weak": "Fire", "resist": "Lightning", "damage": 4, "debuff": "blind", "seconds": 5.0},
	"spitter": {"name": "Spitter", "desc": "Keeps its distance and spits Ice bolts at you.", "frames": "res://art/enemies/grunt", "idle": "idle", "feet": -0.2, "hit": 30.0, "school": "Ice", "weak": "Fire", "resist": "Ice", "damage": 0, "debuff": "", "seconds": 0.0},
}
const SPEED := 80.0
const TERMINAL_FALL := 900.0  # no enemy falls faster than this
const FALL_LIMIT := 400.0     # an enemy below this has fallen off the map and is removed
const MAX_HP := 30
const TARGET_HEIGHT := 64.0  # the on-screen height of every enemy, whatever the art's native size
const CONTACT_RANGE := 50.0  # bodies stop about 42px apart when pressed together, so this must be larger
const CONTACT_COOLDOWN := 1.0
const MOB_JUMP := -320.0  # enough to clear a block, or reach a player standing above
const KNOCK_DECAY := 1500.0
const BURST_DAMAGE := 4      # a rooter bursts for this much to everything close by
const BURST_RADIUS := 60.0
const SPIT_RANGE := 480.0       # a spitter fires from this far away
const SPIT_STAND_RANGE := 300.0 # and stops walking once it is this close
const SPIT_INTERVAL := 2.2      # seconds between shots
const SPIT_DAMAGE := 6

var kind := "grunt"  # set before the mob enters the tree
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
var _lunge := 0.0        # 1 the moment an enemy attacks, fading to 0: it lunges toward the player
var _facing := 1.0
var _shot_timer := 1.5    # spitters fire this often
var _root_time := 0.0     # rooted by Dark Bind: stays put while above zero
var _base_scale := 1.0
@onready var _visual: AnimatedSprite2D = $Visual


func _ready() -> void:
	add_to_group("mobs")
	collision_mask = 1 | 8  # terrain and fire walls only, so enemies walk past each other; the player walks through fire walls
	_visual.sprite_frames = _build_frames(KINDS[kind]["frames"], KINDS[kind]["idle"])
	# Each enemy's hitbox matches its drawn body, with the feet still at the bottom of the box.
	var hitbox: CollisionShape2D = $CollisionShape2D
	hitbox.shape = hitbox.shape.duplicate()
	var hit_h: float = KINDS[kind]["hit"]
	(hitbox.shape as RectangleShape2D).size = Vector2(40.0, hit_h)
	hitbox.position = Vector2(0.0, 25.0 - hit_h / 2.0)
	_visual.animation_finished.connect(_on_animation_finished)
	var first: Texture2D = _visual.sprite_frames.get_frame_texture("idle", 0)
	_base_scale = TARGET_HEIGHT / first.get_height()
	# Tint toward the school's colour, but keep most of the art's own colours.
	_visual.self_modulate = Color.WHITE.lerp(SpellData.SCHOOL_COLORS[KINDS[kind]["school"]], 0.4)
	_visual.play("idle")


## Builds the animations from the frame files in a folder: idle (looping), hit and death.
func _build_frames(dir: String, idle_prefix: String) -> SpriteFrames:
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
				frames.add_frame(anim_name, load(dir + "/" + f))
	return frames


## Damage from a spell of the given school. Weak to a school takes double; resisting it takes nothing.
func take_damage(amount: int, school := "") -> void:
	if _dead:
		return
	var data: Dictionary = KINDS[kind]
	var dealt := amount
	if school == data["resist"]:
		dealt = 0
	elif school == data["weak"]:
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
		Fx.burst(get_parent(), global_position, SpellData.SCHOOL_COLORS[spark_school], 10, 120.0, 0.3)
	if hp <= 0:
		_die()
	elif _visual.sprite_frames.has_animation("hit") and _visual.sprite_frames.get_frame_count("hit") > 0:
		_visual.play("hit")


## A defeated enemy plays its death animation, then disappears. Its own burst (the rooter's) is a design
## feature, not a death effect.
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
	_slow_time = maxf(_slow_time, seconds)


func knock_back(impulse: Vector2) -> void:
	_knock_x = impulse.x
	velocity.y = minf(velocity.y, impulse.y)  # a little lift for upward knocks


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


func _physics_process(delta: float) -> void:
	if global_position.y > FALL_LIMIT:
		queue_free()
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + _gravity * delta, TERMINAL_FALL)

	var speed: float = SPEED * KINDS[kind].get("speed", 1.0)
	if _slow_time > 0.0:
		speed *= 0.5
		_slow_time -= delta
	_knock_x = move_toward(_knock_x, 0.0, KNOCK_DECAY * delta)

	_root_time -= delta
	var distance := player.global_position.distance_to(global_position) if player else INF
	var stands_to_shoot := kind == "spitter" and distance < SPIT_STAND_RANGE
	if player and not stands_to_shoot:
		velocity.x = signf(player.global_position.x - global_position.x) * speed + _knock_x
	else:
		velocity.x = _knock_x
	if _root_time > 0.0 or stands_to_shoot:
		velocity.x = _knock_x  # rooted or shooting: no walking, but knocks still move it
	# Enemies jump when a wall blocks them, or when the player is above them and close by.
	if is_on_floor() and player and _root_time <= 0.0 and not stands_to_shoot:
		var above := player.global_position.y < global_position.y - 30.0 and distance < 160.0
		if is_on_wall() or above:
			velocity.y = MOB_JUMP
	move_and_slide()

	if kind == "spitter" and player and distance < SPIT_RANGE:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = SPIT_INTERVAL
			_squash = Vector2(0.8, 1.2)  # a spitter stretches up as it spits
			EnemyBolt.fire(get_parent(), global_position, player.global_position, SpellData.SCHOOL_COLORS["Ice"], SPIT_DAMAGE)

	_cooldown -= delta
	if player and _cooldown <= 0.0 and global_position.distance_to(player.global_position) < CONTACT_RANGE:
		_attack()
		_cooldown = CONTACT_COOLDOWN


func _attack() -> void:
	var data: Dictionary = KINDS[kind]
	_lunge = 1.0
	player.take_damage(data["damage"])
	if data["debuff"] != "":
		player.apply_debuff(data["debuff"], data["seconds"])
	# A rooter bursts once it has rooted you, so it can't keep rooting you while it's still touching.
	if kind == "rooter":
		_explode()


func _explode() -> void:
	var burst := Burst.new()
	burst.global_position = global_position
	get_parent().add_child(burst)
	# Damage the player and any other mob close enough to the blast.
	if global_position.distance_to(player.global_position) <= BURST_RADIUS:
		player.take_damage(BURST_DAMAGE)
	for other in get_tree().get_nodes_in_group("mobs"):
		if other != self and other.global_position.distance_to(global_position) <= BURST_RADIUS:
			other.take_damage(BURST_DAMAGE)
	queue_free()


## A short expanding ring that fades out, left behind where the mob exploded.
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


func _process(delta: float) -> void:
	_animate(delta)


## A hop while walking, a gentle idle bob, a squash when hit, and a turn to face where it's going.
func _animate(delta: float) -> void:
	var moving := is_on_floor() and absf(velocity.x) > 5.0 and not _dead
	if moving:
		_walk_t += delta * 9.0
		_facing = signf(velocity.x)
	_idle_t += delta
	_squash = _squash.lerp(Vector2.ONE, minf(delta * 8.0, 1.0))
	var lunge := 0.0
	if _lunge > 0.0 and player:
		lunge = sin(_lunge * PI) * 12.0 * signf(player.global_position.x - global_position.x)
		_lunge = maxf(_lunge - delta * 3.0, 0.0)
	var wanted := "walk" if moving and _visual.sprite_frames.get_frame_count("walk") > 0 else "idle"
	if not _dead and _visual.animation != "hit" and _visual.animation != wanted:
		_visual.play(wanted)
	var hop := absf(sin(_walk_t)) * 3.0 if moving else 0.0
	var idle := sin(_idle_t * 2.5) * 0.6 if not moving else 0.0
	_visual.position = Vector2(lunge, KINDS[kind]["feet"] - hop + idle)  # each kind's art sits so its feet meet the collision box
	_visual.scale = Vector2(_base_scale * _squash.x * _facing, _base_scale * _squash.y)
