extends CharacterBody2D

## The player's wizard: LuizMelo's hooded wizard (art/chars/wizard). Its origin is at its feet, so it stands exactly
## on whatever is under it.

signal damaged(amount: int)
signal debuff_applied(kind: String)
signal died

const SPEED := 300.0
const JUMP_VELOCITY := -520.0
const JUMP_COST := 5.0  # stamina a jump takes; with less than this, you can't jump
const RUN_COST := 0.12   # stamina per second of walking or running on the ground
const MAX_HP := 100
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 20.0   # per second
const REGEN_DELAY := 1.0      # seconds without spending before regen starts
const SHIELD_RADIUS := 50.0
const BODY_HEIGHT := 78.0     # from the feet to the top of the hood
const COYOTE_TIME := 0.1      # a jump still works this long after walking off a ledge
const JUMP_BUFFER := 0.12     # a jump pressed this long before landing happens on landing
const HURT_GRACE := 0.5       # after a hit, further hits are ignored this long
const STEP_EVERY := 0.32      # seconds between footstep sounds while running
const CLIMB_SPEED := 170.0    # how fast the wizard climbs a vine
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
var sink_time := 0.0  # quicksand: slowed, and unable to jump while this lasts
var air_jump_time := 0.0  # the Chant of the Second Leap: a jump in the air is allowed while this lasts
var air_jump_ready := false  # the air jump is spent by one use, and comes back when the wizard lands
var _shove := Vector2.ZERO  # a Push on the caster: slides them for a moment, then fades
var mute_time := 0.0          # no rituals while above zero
var root_time := 0.0          # no walking or jumping while above zero
var _stuck_time := 0.0         # how long a giant's stomp has the player stuck in the ground
var _sink_material: ShaderMaterial  # cuts the body off at the waist while stuck, so it looks sunk into the ground
var blind_time := 0.0         # the caster's gesture trail is hidden while above zero
var dead := false
var _shield_time := 0.0
var _frozen_time := 0.0  # frozen in ice: rooted, and shattered out of it by Air or Earth
var _since_spend := 0.0
var facing := 1.0
var _flash := 0.0        # red flash after being hit
var _liquid := Color.WHITE  # the colour of the water or lava the wizard stands in
var _liquid_time := 0.0
var _grace := 0.0        # time left of the safety after a hit
var _coyote := 0.0
var _jump_buffer := 0.0
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
var _swirl: Sprite2D  # the wind turning round the Barrier
var _vine: Node2D  # the vine (Liana) the wizard is hanging on, if any
var _vine_cooldown := 0.0  # after letting go, a vine cannot be grabbed again for a moment


func _ready() -> void:
	floor_max_angle = deg_to_rad(50.0)  # a 45 degree slope, the steepest a tunnel climbs, still counts as floor
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
	# Air, not force: wind swirls round the wizard inside a faint pale bubble.
	_swirl = Sprite2D.new()
	_swirl.texture = Fx.tex("twirl_01")
	_swirl.scale = Vector2.ONE * (SHIELD_RADIUS * 2.2 / Fx.TEX_SIZE)
	_swirl.material = Fx.additive()
	_swirl.visible = false
	_shield.add_child(_swirl)
	# Sparkles along the rim of the Barrier, only while it's up.
	_shield_emitter = CPUParticles2D.new()
	_shield_emitter.position = center_offset()
	_shield_emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_shield_emitter.emission_sphere_radius = SHIELD_RADIUS
	_shield_emitter.amount = 14
	_shield_emitter.lifetime = 0.5
	_shield_emitter.direction = Vector2.ZERO
	_shield_emitter.spread = 180.0
	_shield_emitter.initial_velocity_min = 0.0
	_shield_emitter.initial_velocity_max = 4.0
	_shield_emitter.orbit_velocity_min = 0.6
	_shield_emitter.orbit_velocity_max = 1.0
	_shield_emitter.gravity = Vector2.ZERO
	_shield_emitter.scale_amount_min = 0.12
	_shield_emitter.scale_amount_max = 0.22
	_shield_emitter.texture = Fx.tex("trace_01")
	_shield_emitter.color_ramp = Fx.fade_ramp(Color(0.9, 0.96, 1.0))
	_shield_emitter.material = Fx.additive()
	_shield_emitter.emitting = false
	add_child(_shield_emitter)


## Where the wizard's mouth is, for Fire Breath.
func mouth() -> Vector2:
	return global_position + Vector2(26.0 * facing, -56.0)  # at the front of the wizard, around the face


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


## Encases the player in ice: rooted for the same time an enemy stays frozen. A Barrier stops it.
func freeze(seconds: float) -> bool:
	if has_shield():
		return false
	_frozen_time = maxf(_frozen_time, seconds)
	root_time = maxf(root_time, seconds)
	return true


func is_frozen() -> bool:
	return _frozen_time > 0.0


func thaw() -> void:
	_frozen_time = 0.0


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


## A hit takes health and then gives a short grace, in which no other hit lands. A burn (grace_hit false) takes
## health without starting that grace, so a burn and a blow can both land.
func take_damage(amount: int, grace_hit := true, projectile := false) -> void:
	if (projectile and _shield_time > 0.0) or dead or (grace_hit and _grace > 0.0) or amount <= 0:
		return
	amount = roundi(amount * Hex.multiplier(get_tree(), self))  # a hexed wizard takes half again as much
	hp -= amount
	_flash = 0.3
	_hurt_anim = 0.25
	if grace_hit:
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


## Standing in water or lava: the wizard is tinted its colour for a moment after each call, so leaving it fades back at once.
func soak(tint: Color) -> void:
	_liquid = tint
	_liquid_time = 0.15


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
		"sink":
			sink_time = maxf(sink_time, seconds)
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
	query.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit["position"].y - global_position.y if not hit.is_empty() else -1.0


func _draw_ellipse(at: Vector2, rx: float, ry: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		points.append(at + Vector2(cos(TAU * i / 20.0) * rx, sin(TAU * i / 20.0) * ry))
	draw_colored_polygon(points, colour)


## The Barrier: a faint pale bubble of air round the wizard with wind turning round it. It fades out over its last moments.
func _draw_shield() -> void:
	var fade := clampf(_shield_time / 0.4, 0.0, 1.0)
	_bubble.visible = _shield_time > 0.0
	_bubble.modulate = Color(0.85, 0.93, 1.0, 0.22 * fade)
	_swirl.visible = _shield_time > 0.0
	_swirl.rotation = -Time.get_ticks_msec() * 0.004
	_swirl.modulate = Color(0.9, 0.96, 1.0, 0.8 * fade)


func _physics_process(delta: float) -> void:
	_shield_time -= delta
	_frozen_time -= delta
	_grace -= delta
	_shield_emitter.emitting = _shield_time > 0.0
	mute_time -= delta
	root_time -= delta
	blind_time -= delta
	slow_time -= delta
	sink_time -= delta
	air_jump_time -= delta
	if is_on_floor():
		air_jump_ready = true
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

	var can_move := movement_enabled and root_time <= 0.0 and not dead
	_vine_cooldown -= delta
	if can_move and _climb():
		return
	if can_move:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER
		if _jump_buffer > 0.0 and _coyote > 0.0 and sink_time <= 0.0 and spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.play("jump", global_position)
		elif _jump_buffer > 0.0 and air_jump_time > 0.0 and air_jump_ready and sink_time <= 0.0 and not is_on_floor():
			# The second leap: a jump in the air, free of stamina, once per landing.
			velocity.y = JUMP_VELOCITY * 0.9
			_jump_buffer = 0.0
			air_jump_ready = false
			Sfx.play("jump", global_position)
		# Letting go of jump early cuts the jump short, so small hops are easy.
		if Input.is_action_just_released("jump") and velocity.y < JUMP_VELOCITY * 0.4:
			velocity.y = JUMP_VELOCITY * 0.4
		# Walking is free; running drains stamina. With none left you still walk, at half speed.
		var speed := (SPEED if stamina > 0.0 else SPEED * 0.5) * (0.5 if slow_time > 0.0 else 1.0) * (0.4 if sink_time > 0.0 else 1.0)
		velocity.x = Input.get_axis("move_left", "move_right") * speed
		if is_on_floor() and absf(velocity.x) > 10.0 and stamina > 0.0:
			drain(RUN_COST * delta)
	else:
		velocity.x = 0.0
	velocity.x += _shove.x
	if _shove.y < 0.0:
		velocity.y = minf(velocity.y, _shove.y)
	_shove = _shove.move_toward(Vector2.ZERO, 1500.0 * delta)

	# Walking into a ledge one tile high: a small hop lifts the wizard up it, so slopes and steps are walkable.
	if is_on_floor() and is_on_wall() and absf(velocity.x) > 10.0 and not dead and sink_time <= 0.0:
		velocity.y = minf(velocity.y, -330.0)
	move_and_slide()
	# A character pushed out of the map's sides is put back inside.
	global_position.x = clampf(global_position.x, ArenaGen.left_edge() + 12.0, ArenaGen.right_edge() - 12.0)
	if is_on_floor() and absf(velocity.x) > 10.0:
		_step -= delta
		if _step <= 0.0:
			_step = STEP_EVERY
			Sfx.play("step", global_position)


## Hanging on a vine (Liana): W takes hold when the wizard is at one, W and S climb, and Space or a sideways key lets go.
## Returns true while the wizard is on a vine, which takes over the whole frame's movement.
func _climb() -> bool:
	var hands := global_position + Vector2(0, -20)
	if _vine != null and (not is_instance_valid(_vine) or not _vine.can_grab(hands)):
		_vine = null
	if _vine == null:
		if _vine_cooldown > 0.0 or not Input.is_key_pressed(KEY_W):
			return false
		for vine in get_tree().get_nodes_in_group("climbables"):
			if vine.can_grab(hands):
				_vine = vine
				break
		if _vine == null:
			return false
	var sideways := Input.get_axis("move_left", "move_right")
	var up := Input.is_key_pressed(KEY_W)
	var down := Input.is_action_pressed("move_down")
	if Input.is_key_pressed(KEY_SPACE) or absf(sideways) > 0.5:
		# Let go: a hop off the vine in the way the wizard was leaning.
		velocity = Vector2(sideways * SPEED, JUMP_VELOCITY * 0.6 if Input.is_key_pressed(KEY_SPACE) else 0.0)
		_vine = null
		_vine_cooldown = 0.3
		return false
	if down and is_on_floor():
		_vine = null
		_vine_cooldown = 0.3
		return false
	global_position.x = lerpf(global_position.x, _vine.vine_x(), 0.4)
	velocity = Vector2(0.0, (1.0 if down else 0.0) * CLIMB_SPEED - (1.0 if up else 0.0) * CLIMB_SPEED)
	move_and_slide()
	return true


## Chant of the Second Leap: one extra jump in the air, for a while.
func grant_air_jump(seconds: float) -> void:
	air_jump_time = maxf(air_jump_time, seconds)
	air_jump_ready = true


func grant_unlimited(seconds: float) -> void:
	infinite_time = maxf(infinite_time, seconds)
	stamina = MAX_STAMINA


## A Push on the caster: they are shoved along the line for a moment.
func pull(force: Vector2, delta: float) -> void:
	free_from_ground()
	_shove += force * delta


func push(impulse: Vector2) -> void:
	free_from_ground()
	_shove = impulse


## Anything that moves the body out of the ground (a push, a pull, a blink, a knock) frees it. It can be stuck again only
## by the next stomp.
func free_from_ground() -> void:
	if _stuck_time > 0.0:
		root_time = 0.0
		unstick()


## A giant's stomp sticks the player in the ground: their body sinks down out of sight, and they cannot move or jump
## until it lets go.
func stick_in_ground(seconds: float) -> void:
	apply_debuff("root", seconds)
	_stuck_time = maxf(_stuck_time, seconds)
	if _sink_material == null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nuniform float keep = 0.7;\nvoid fragment() {\n\tif (UV.y > keep) {\n\t\tdiscard;\n\t}\n\tCOLOR = texture(TEXTURE, UV) * COLOR;\n}\n"
		_sink_material = ShaderMaterial.new()
		_sink_material.shader = shader
	_sprite.material = _sink_material
	# The cut is 57 px above the frame's bottom, so this drops the cut onto the ground: the body is in the ground from there down.
	_sprite.position = Vector2(0, 57)


## Lets the player out of the ground, as a throw does.
func unstick() -> void:
	_stuck_time = 0.0
	_sprite.material = null
	_sprite.position = Vector2.ZERO


func _process(delta: float) -> void:
	if _stuck_time > 0.0:
		_stuck_time -= delta
		if _stuck_time <= 0.0:
			unstick()
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
		facing = signf(velocity.x)
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
	_sprite.flip_h = facing < 0.0
	_glow.visible = casting and not dead
	if _glow.visible:
		var head := WAND_HEAD if focus == "wand" else STAFF_HEAD
		_glow.position = Vector2(head.x * facing, head.y)
		_glow.modulate = Color(cast_color, 0.9)
	_flash = maxf(_flash - delta, 0.0)
	# After a hit the wizard blinks while it can't be hurt again.
	var blink := _grace > 0.0 and int(_grace * 20.0) % 2 == 0
	_liquid_time = maxf(_liquid_time - delta, 0.0)
	var wet := _liquid if _liquid_time > 0.0 else Color.WHITE
	_sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color(wet.r, wet.g, wet.b, 0.55 if blink else 1.0)


## Called when a spell goes off: the wizard thrusts its staff forward once.
func play_cast_release() -> void:
	_releasing = 0.3
	_sprite.play("release")
