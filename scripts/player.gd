extends CharacterBody2D

signal damaged(amount: int)
signal debuff_applied(kind: String)

const SPEED := 300.0
const JUMP_VELOCITY := -450.0
const JUMP_COST := 5.0  # stamina a jump takes; with less than this, you can't jump
const RUN_COST := 0.5    # stamina per second of running on the ground
const MAX_HP := 100
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 20.0   # per second
const REGEN_DELAY := 1.0      # seconds without spending before regen starts
const SHIELD_RADIUS := 36.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var hp := MAX_HP
var stamina := MAX_STAMINA
var focus := "wand"          # the held focus item, see FocusItem.FOCI
var movement_enabled := true  # the arena turns this off while a typing box or the spellbook is open
var infinite_time := 0.0  # Chant of Boundless Vigour: stamina does not run out while this lasts
var _shove := Vector2.ZERO  # a Push on the caster: slides them for a moment, then fades
var mute_time := 0.0          # no rituals while above zero
var root_time := 0.0          # no walking or jumping while above zero
var blind_time := 0.0         # the caster's gesture trail is hidden while above zero
var _shield_time := 0.0
var _since_spend := 0.0
var _walk_t := 0.0       # walk cycle, advances only while moving
var _breath_t := 0.0     # idle breathing
var _squash := Vector2.ONE
var _was_on_floor := true
var _facing := 1.0
var _flash := 0.0        # red flash after being hit
var casting := false      # true while the caster has a stroke in progress (set by the arena)
var _cast_blend := 0.0    # 0 at rest, 1 fully in the casting pose
var _thrust := 0.0        # a short forward thrust when a spell goes off
var cast_color := Color.WHITE  # the school being drawn (set by the arena); the crystal takes it
var _gem: Sprite2D             # soft glow on the staff's crystal
@onready var _staff: Sprite2D = $Look/Staff
@onready var _hand_right: Sprite2D = $Look/HandRight
var _hand_rest := Vector2.ZERO
@onready var _sprite: Node2D = $Look
var _anim := 0.0  # running clock for the shield's animation
var _shield_emitter: CPUParticles2D


func _ready() -> void:
	add_to_group("player")
	_hand_rest = _hand_right.position
	# A soft glow on the crystal, at its position in the staff's own pixels (the art's top gem).
	_gem = Sprite2D.new()
	_gem.texture = Fx.dot_texture()
	_gem.material = Fx.additive()
	_gem.position = Vector2(241, -229)
	_gem.scale = Vector2.ONE * 4.4
	_staff.add_child(_gem)
	# Sparkles along the rim of the Barrier, only while it's up.
	_shield_emitter = CPUParticles2D.new()
	_shield_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_shield_emitter.emission_sphere_radius = SHIELD_RADIUS
	_shield_emitter.amount = 14
	_shield_emitter.lifetime = 0.5
	_shield_emitter.direction = Vector2.ZERO
	_shield_emitter.spread = 180.0
	_shield_emitter.initial_velocity_min = 2.0
	_shield_emitter.initial_velocity_max = 8.0
	_shield_emitter.gravity = Vector2.ZERO
	_shield_emitter.scale_amount_min = 0.8
	_shield_emitter.scale_amount_max = 1.8
	_shield_emitter.texture = Fx.dot_texture()
	_shield_emitter.color_ramp = Fx.fade_ramp(Color(0.7, 0.95, 1.0))
	_shield_emitter.material = Fx.additive()
	_shield_emitter.emitting = false
	add_child(_shield_emitter)


func raise_shield(seconds: float) -> void:
	_shield_time = maxf(_shield_time, seconds)


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
	if _shield_time > 0.0:
		return
	hp -= amount
	_flash = 0.3
	damaged.emit(amount)
	if hp <= 0:
		Levels.wave_index = 0  # a death ends the run; the next one starts from the first wave
		get_tree().reload_current_scene()


func apply_debuff(kind: String, seconds: float) -> void:
	# The Barrier stops debuffs as well as damage.
	if _shield_time > 0.0:
		return
	match kind:
		"mute":
			mute_time = maxf(mute_time, seconds)
		"root":
			root_time = maxf(root_time, seconds)
		"blind":
			blind_time = maxf(blind_time, seconds)
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
	return "   ".join(parts)


## The Barrier: a glowing bubble with a slowly turning rune ring, orbiting motes and sparkles
## along the rim. It fades out over its last moments.
func _draw() -> void:
	if _shield_time <= 0.0:
		return
	var fade := clampf(_shield_time / 0.4, 0.0, 1.0)
	var r := SHIELD_RADIUS
	var ice := Color(0.6, 0.9, 1.0)
	draw_circle(Vector2.ZERO, r, Color(ice.r, ice.g, ice.b, 0.12 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(ice.r, ice.g, ice.b, 0.35 * fade), 8.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.9, 0.98, 1.0, 0.9 * fade), 2.0)
	# Rune ring: arc segments turning one way, glyph ticks turning the other.
	var inner := r * 0.7
	for i in 8:
		var start := _anim * 1.5 + i * TAU / 8.0
		draw_arc(Vector2.ZERO, inner, start, start + 0.5, 6, Color(0.8, 0.95, 1.0, 0.85 * fade), 1.5)
	for i in 6:
		var a := -_anim * 2.5 + i * TAU / 6.0
		var dir := Vector2.from_angle(a)
		draw_line(dir * inner * 0.8, dir * inner * 1.1, Color(0.9, 1.0, 1.0, 0.8 * fade), 1.5)
	# Motes orbiting just outside the bubble.
	for i in 3:
		var a := _anim * 3.0 + i * TAU / 3.0
		draw_circle(Vector2.from_angle(a) * (r + 6.0), 2.5, Color(1, 1, 1, 0.9 * fade))


func _physics_process(delta: float) -> void:
	_shield_time -= delta
	_anim += delta
	_shield_emitter.emitting = _shield_time > 0.0
	mute_time -= delta
	root_time -= delta
	blind_time -= delta
	infinite_time -= delta
	if infinite_time > 0.0:
		stamina = MAX_STAMINA
	_since_spend += delta
	if _since_spend >= REGEN_DELAY:
		restore_stamina(STAMINA_REGEN * delta)
	queue_redraw()

	if not is_on_floor():
		velocity.y += gravity * delta

	var can_move := movement_enabled and root_time <= 0.0
	if can_move:
		if Input.is_action_just_pressed("jump") and is_on_floor() and spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY
		# Walking is free; running drains stamina. With none left you still walk, at half speed.
		var speed := SPEED if stamina > 0.0 else SPEED * 0.5
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


## A Push on the caster: they are shoved along the line for a moment.
func grant_unlimited(seconds: float) -> void:
	infinite_time = maxf(infinite_time, seconds)
	stamina = MAX_STAMINA


func push(impulse: Vector2) -> void:
	_shove = impulse


func _process(delta: float) -> void:
	_animate(delta)


## Walk bob and sway, idle breathing, squash on landing and stretch on jumping, a flash when hit,
## and a turn to face the way the player is moving.
func _animate(delta: float) -> void:
	const BASE_SCALE := 0.07  # the wizard parts are drawn on one 598x679 canvas
	var moving := is_on_floor() and absf(velocity.x) > 10.0
	if moving:
		_walk_t += delta * 11.0
		_facing = signf(velocity.x)
	_breath_t += delta
	if is_on_floor() and not _was_on_floor:
		_squash = Vector2(1.18, 0.84)   # landed
	elif _was_on_floor and not is_on_floor():
		_squash = Vector2(0.86, 1.14)   # jumped
	_was_on_floor = is_on_floor()
	_squash = _squash.lerp(Vector2.ONE, minf(delta * 9.0, 1.0))

	var bob := absf(sin(_walk_t)) * 2.5 if moving else 0.0
	var breathe := sin(_breath_t * 2.2) * 0.015
	_sprite.position = Vector2(0, -2.0 - bob)
	_sprite.rotation = (sin(_walk_t) * 0.05 if moving else 0.0) - 0.05 * _cast_blend
	_sprite.scale = Vector2(BASE_SCALE * _squash.x * _facing, BASE_SCALE * _squash.y * (1.0 + breathe))
	# Casting: the staff tilts up and the hand lifts while drawing; a short thrust plays when the spell goes off.
	_cast_blend = lerpf(_cast_blend, 1.0 if casting else 0.0, minf(delta * 8.0, 1.0))
	_thrust = maxf(_thrust - delta * 3.0, 0.0)
	_staff.rotation = -0.5 * _cast_blend + 0.45 * _thrust
	_staff.scale = Vector2.ONE * (1.0 + 0.05 * sin(_breath_t * 14.0) * _cast_blend)
	# The crystal glows faintly at rest, and brighter in the school's colour while a stroke is drawn.
	var gem_color := Color(0.85, 0.97, 1.0).lerp(cast_color, _cast_blend)
	_gem.modulate = Color(gem_color.r, gem_color.g, gem_color.b, 0.45 + 0.55 * _cast_blend)
	_gem.scale = Vector2.ONE * 4.4 * (1.0 + 0.08 * sin(_breath_t * 6.0) + 0.25 * _cast_blend)
	_hand_right.position = _hand_rest + Vector2(0, -140.0 * _cast_blend)

	_flash = maxf(_flash - delta, 0.0)
	_sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color.WHITE


## Called when a spell goes off: the staff thrusts forward once.
func play_cast_release() -> void:
	_thrust = 1.0
