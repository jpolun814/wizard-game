extends CharacterBody2D

## The player's wizard: LuizMelo's hooded wizard (art/chars/wizard). Its origin is at its feet, so it stands exactly
## on whatever is under it.

signal damaged(amount: int)
signal debuff_applied(kind: String)
signal died

const SPEED := 300.0
const JUMP_VELOCITY := -520.0
const JUMP_COST := 5.0  # stamina a jump takes; with less than this, you can't jump
const RUN_COST := 0.5    # stamina per second of running on the ground
const MAX_HP := 100
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 20.0   # per second
const REGEN_DELAY := 1.0      # seconds without spending before regen starts
const SHIELD_RADIUS := 50.0
const BODY_HEIGHT := 78.0     # from the feet to the top of the hood
const COYOTE_TIME := 0.1      # a jump still works this long after walking off a ledge
const JUMP_BUFFER := 0.12     # a jump pressed this long before landing happens on landing
const HURT_GRACE := 0.5       # after a hit, further hits are ignored this long
const DROP_TIME := 0.25       # how long platforms let you fall through after S + jump
const PLATFORM_LAYER := 16
const STEP_EVERY := 0.32      # seconds between footstep sounds while running
const ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"fps": 12.0}, "jump": {"fps": 10.0, "loop": false}, "fall": {"fps": 8.0},
	"cast": {"fps": 8.0, "first": 0, "last": 2},                      # the staff held up while a stroke is drawn
	"release": {"fps": 18.0, "loop": false, "first": 0, "last": 4},  # thrust forward as the spell goes off
	"hit": {"fps": 14.0, "loop": false}, "death": {"fps": 10.0, "loop": false},
}
const STAFF_HEAD := Vector2(-55, -115)  # where the staff's crystal is in the casting pose, facing right
const WAND_HEAD := Vector2(-24, -95)     # and the wand's

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var hp := MAX_HP
var stamina := MAX_STAMINA
var focus := "wand"          # the held focus item, see FocusItem.FOCI
var movement_enabled := true  # the arena turns this off while a typing box or the spellbook is open
var infinite_time := 0.0  # Chant of Boundless Vigour: stamina does not run out while this lasts
var slow_time := 0.0  # frost slows the caster while this lasts
var _shove := Vector2.ZERO  # a Push on the caster: slides them for a moment, then fades
var mute_time := 0.0          # no rituals while above zero
var root_time := 0.0          # no walking or jumping while above zero
var blind_time := 0.0         # the caster's gesture trail is hidden while above zero
var dead := false
var _shield_time := 0.0
var _since_spend := 0.0
var _facing := 1.0
var _flash := 0.0        # red flash after being hit
var _grace := 0.0        # time left of the safety after a hit
var _coyote := 0.0
var _jump_buffer := 0.0
var _drop := 0.0
var _step := 0.0
var casting := false      # true while the caster has a stroke in progress (set by the arena)
var _releasing := 0.0     # time left of the thrust that plays when a spell goes off
var _hurt_anim := 0.0     # time left of the flinch after a hit
var cast_color := Color.WHITE  # the school being drawn (set by the arena); the staff's glow takes it
var _glow: Sprite2D            # a glow at the staff's head while a stroke is drawn
var _dressed_as := ""          # the focus the wizard's frames show
@onready var _sprite: AnimatedSprite2D = $Look
var _shield_emitter: CPUParticles2D
var _shield: Node2D
var _bubble: AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	_dress_for_focus()
	_sprite.offset = Vector2(0, -PixelArt.CHARACTERS["wizard"]["size"].y * 0.5)  # the frames' bottom edge is the feet
	_sprite.play("idle")
	# The staff's head glows in the school's colour while a stroke is being drawn.
	_glow = Sprite2D.new()
	_glow.texture = Fx.tex("circle_05")
	_glow.material = Fx.additive()
	_glow.scale = Vector2.ONE * 0.35
	_glow.visible = false
	add_child(_glow)
	# The Barrier is drawn on its own node in front of the wizard.
	_shield = Node2D.new()
	_shield.position = center_offset()
	_shield.z_index = 2
	_shield.draw.connect(_draw_shield)
	add_child(_shield)
	# The bubble itself, drawn twice its size round the wizard's middle.
	_bubble = PixelFx.sprite("shield", 10.0)
	_bubble.scale = Vector2.ONE * 2.0
	_bubble.material = Fx.additive()
	_bubble.visible = false
	_shield.add_child(_bubble)
	# Sparkles along the rim of the Barrier, only while it's up.
	_shield_emitter = CPUParticles2D.new()
	_shield_emitter.position = center_offset()
	_shield_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_shield_emitter.emission_sphere_radius = SHIELD_RADIUS
	_shield_emitter.amount = 14
	_shield_emitter.lifetime = 0.5
	_shield_emitter.direction = Vector2.ZERO
	_shield_emitter.spread = 180.0
	_shield_emitter.initial_velocity_min = 2.0
	_shield_emitter.initial_velocity_max = 8.0
	_shield_emitter.gravity = Vector2.ZERO
	_shield_emitter.scale_amount_min = 0.04
	_shield_emitter.scale_amount_max = 0.1
	_shield_emitter.texture = Fx.tex("star_04")
	_shield_emitter.color_ramp = Fx.fade_ramp(Color(0.85, 0.75, 1.0))
	_shield_emitter.material = Fx.additive()
	_shield_emitter.emitting = false
	add_child(_shield_emitter)


## Where the wizard's mouth is, for Fire Breath.
func mouth() -> Vector2:
	return global_position + Vector2(8.0 * _facing, -62.0)


## The middle of the wizard's body, relative to its feet.
func center_offset() -> Vector2:
	return Vector2(0, -BODY_HEIGHT * 0.5)


## The middle of the wizard's body in the world. Spells and enemies aim here, not at the feet.
func center() -> Vector2:
	return global_position + center_offset()


func raise_shield(seconds: float) -> void:
	_shield_time = maxf(_shield_time, seconds)
	Sfx.play("barrier", center())


func has_shield() -> bool:
	return _shield_time > 0.0


## Spend stamina if there is enough. Returns false and spends nothing otherwise.
func spend(amount: float) -> bool:
	if infinite_time > 0.0:
		return true
	if stamina < amount:
		return false
	drain(amount)
	return true


## Take stamina even if it's short (misfire penalty); never goes below zero.
func drain(amount: float) -> void:
	if infinite_time > 0.0:
		return
	stamina = maxf(stamina - amount, 0.0)
	_since_spend = 0.0


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, MAX_STAMINA)


func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)


func take_damage(amount: int) -> void:
	if _shield_time > 0.0 or dead or _grace > 0.0 or amount <= 0:
		return
	hp -= amount
	_flash = 0.3
	_hurt_anim = 0.25
	_grace = HURT_GRACE
	Sfx.play("player_hurt", center())
	GameCamera.shake_scene(get_tree(), 0.35 + amount * 0.02)
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d" % amount, Color("#ff5a5a"), 1.1)
	damaged.emit(amount)
	if hp <= 0:
		hp = 0
		dead = true
		movement_enabled = false
		died.emit()


func apply_debuff(kind: String, seconds: float) -> void:
	# The Barrier stops debuffs as well as damage.
	if _shield_time > 0.0 or dead:
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
	debuff_applied.emit(kind)


func is_muted() -> bool:
	return mute_time > 0.0


func is_blind() -> bool:
	return blind_time > 0.0


func status_text() -> String:
	var parts: Array[String] = []
	if mute_time > 0.0:
		parts.append("MUTED %.0fs" % mute_time)
	if root_time > 0.0:
		parts.append("ROOTED %.0fs" % root_time)
	if blind_time > 0.0:
		parts.append("BLIND %.0fs" % blind_time)
	if slow_time > 0.0:
		parts.append("SLOWED")
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
	query.collision_mask = 1 | PLATFORM_LAYER
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y - global_position.y if not hit.is_empty() else -1.0


func _draw_ellipse(at: Vector2, rx: float, ry: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		points.append(at + Vector2(cos(TAU * i / 20.0) * rx, sin(TAU * i / 20.0) * ry))
	draw_colored_polygon(points, colour)


## The Barrier: a pixel-art bubble of force round the wizard, lit violet. It fades out over its last moments.
func _draw_shield() -> void:
	_bubble.visible = _shield_time > 0.0
	_bubble.modulate = Color(0.8, 0.6, 1.0, 0.75 * clampf(_shield_time / 0.4, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_shield_time -= delta
	_grace -= delta
	_shield_emitter.emitting = _shield_time > 0.0
	mute_time -= delta
	root_time -= delta
	blind_time -= delta
	slow_time -= delta
	infinite_time -= delta
	if infinite_time > 0.0:
		stamina = MAX_STAMINA
	_since_spend += delta
	if _since_spend >= REGEN_DELAY:
		restore_stamina(STAMINA_REGEN * delta)
	queue_redraw()
	_shield.queue_redraw()

	if not is_on_floor():
		velocity.y += gravity * delta
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_jump_buffer -= delta
	_drop -= delta
	# Platforms let you fall through while dropping; they become solid again once you are below them.
	set_collision_mask_value(5, _drop <= 0.0)

	var can_move := movement_enabled and root_time <= 0.0 and not dead
	if can_move:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER
		if Input.is_action_pressed("move_down") and _on_platform():
			# S while standing on a wooden platform drops through it.
			_drop = DROP_TIME
		elif _jump_buffer > 0.0 and _coyote > 0.0 and spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.play("jump", global_position)
		# Letting go of jump early cuts the jump short, so small hops are easy.
		if Input.is_action_just_released("jump") and velocity.y < JUMP_VELOCITY * 0.4:
			velocity.y = JUMP_VELOCITY * 0.4
		# Walking is free; running drains stamina. With none left you still walk, at half speed.
		var speed := (SPEED if stamina > 0.0 else SPEED * 0.5) * (0.5 if slow_time > 0.0 else 1.0)
		velocity.x = Input.get_axis("move_left", "move_right") * speed
		if is_on_floor() and absf(velocity.x) > 10.0 and stamina > 0.0:
			drain(RUN_COST * delta)
	else:
		velocity.x = 0.0
	velocity.x += _shove.x
	if _shove.y < 0.0:
		velocity.y = minf(velocity.y, _shove.y)
	_shove = _shove.move_toward(Vector2.ZERO, 1500.0 * delta)

	move_and_slide()
	# A character pushed out of the map's sides is put back inside.
	global_position.x = clampf(global_position.x, ArenaGen.left_edge() + 12.0, ArenaGen.right_edge() - 12.0)
	if is_on_floor() and absf(velocity.x) > 10.0:
		_step -= delta
		if _step <= 0.0:
			_step = STEP_EVERY
			Sfx.play("step", global_position)


## True when the wizard stands on a one-way platform rather than solid ground.
func _on_platform() -> bool:
	if not is_on_floor():
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 8))
	query.collision_mask = 1 | PLATFORM_LAYER
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] is StaticBody2D and hit["collider"].collision_layer == PLATFORM_LAYER


func grant_unlimited(seconds: float) -> void:
	infinite_time = maxf(infinite_time, seconds)
	stamina = MAX_STAMINA


## A Push on the caster: they are shoved along the line for a moment.
func push(impulse: Vector2) -> void:
	_shove = impulse


func _process(delta: float) -> void:
	_animate(delta)


## The wizard's frames show the focus it holds: its staff, or the same staff cut down to a wand.
func _dress_for_focus() -> void:
	_dressed_as = focus
	var animation := _sprite.animation
	_sprite.sprite_frames = CharFrames.build("res://art/chars/wizard_wand" if focus == "wand" else "res://art/chars/wizard", ANIMATIONS)
	_sprite.play(animation if _sprite.sprite_frames.has_animation(animation) else "idle")


## Picks the animation for what the wizard is doing, faces the way it is moving, and flashes when hit.
func _animate(delta: float) -> void:
	if focus != _dressed_as:
		_dress_for_focus()
	if absf(velocity.x) > 10.0 and not dead:
		_facing = signf(velocity.x)
	_releasing = maxf(_releasing - delta, 0.0)
	_hurt_anim = maxf(_hurt_anim - delta, 0.0)
	var wanted := "idle"
	if dead:
		wanted = "death"
	elif _hurt_anim > 0.0:
		wanted = "hit"
	elif _releasing > 0.0:
		wanted = "release"
	elif casting:
		wanted = "cast"
	elif not is_on_floor():
		wanted = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 10.0:
		wanted = "run"
	if _sprite.animation != wanted:
		_sprite.play(wanted)
	_sprite.flip_h = _facing < 0.0
	_glow.visible = casting and not dead
	if _glow.visible:
		var head := WAND_HEAD if focus == "wand" else STAFF_HEAD
		_glow.position = Vector2(head.x * _facing, head.y)
		_glow.modulate = Color(cast_color, 0.9)
	_flash = maxf(_flash - delta, 0.0)
	# After a hit the wizard blinks while it can't be hurt again.
	var blink := _grace > 0.0 and int(_grace * 20.0) % 2 == 0
	_sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color(1, 1, 1, 0.55 if blink else 1.0)


## Called when a spell goes off: the wizard thrusts its staff forward once.
func play_cast_release() -> void:
	_releasing = 0.3
	_sprite.play("release")
