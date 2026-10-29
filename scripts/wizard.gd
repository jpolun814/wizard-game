class_name Wizard
extends CharacterBody2D

## A wizard: the body every wizard in the game has, the player's and the three others'. It is driven either by a person (the keyboard
## and the mouse) or by a WizardBrain, and from there it is the same body: the same walk, jump, stamina, wounds, shoves and status
## effects, so a spell does the same to any of them. Its origin is at its feet, so it stands exactly on whatever is under it.
## The player's is LuizMelo's hooded wizard (art/chars/wizard); the others wear one of the looks in res://mobs.

signal damaged(amount: int)
signal debuff_applied(kind: String)
signal died

const SPEED := 300.0
const BREATH := 8.0  # seconds under water before the wizard starts to drown
const DEEP_BREATH := 45.0  # seconds the Chant of the Deep Breath holds the wizard's breath: it counts down from the chant
const DROWN_RATE := 3.0  # most stamina lost per second while out of breath, and it does not come back by itself
const HASTE := 1.6  # how much faster the Chant of Swift Feet makes the wizard
const JUMP_VELOCITY := -520.0
const JUMP_COST := 5.0  # stamina a jump takes; with less than this, you can't jump
const RUN_COST := 0.12   # stamina per second of walking or running on the ground
const MAX_STAMINA := 200.0  # what you start with, and the most you can ever have: a hit lowers the most you have, and healing raises it again, but not past this
const STAMINA_REGEN := 20.0   # per second
const REGEN_DELAY := 1.0      # seconds without spending before regen starts
const SHIELD_RADIUS := 50.0
const ADRENALINE_REGEN := 3.0   # how many times faster stamina comes back under Adrenaline
const OBSIDIAN_SPEED := 0.75    # how fast the wizard walks in black glass
const OBSIDIAN_SHOTS := 0.5     # and how much of a shot's damage gets through
const SURF_SPEED := 470.0       # how fast a wave carries the wizard
const GET_UP := 10.0            # a wizard who has fainted stands up again once this much stamina has come back
const BODY_HEIGHT := 78.0     # from the feet to the top of the hood
const BODY_WIDTH := 24.0      # and across the hood, as wide as the collision capsule
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
## The other three looks name some of their frames differently: the staff is held up in "release" and thrust out in "cast".
const LOOK_ANIMATIONS := {
	"idle": {"fps": 8.0}, "run": {"fps": 12.0}, "jump": {"fps": 8.0, "loop": false}, "fall": {"fps": 8.0},
	"cast": {"from": "release", "fps": 8.0, "first": 0, "last": 3},
	"release": {"from": "cast", "fps": 16.0, "loop": false, "first": 3, "last": 5},
	"hit": {"fps": 10.0, "loop": false}, "death": {"fps": 8.0, "loop": false},
}
const STAFF_HEAD := Vector2(-55, -115)  # where the staff's crystal is in the casting pose, facing right
const DRAW_TIME := 0.8        # how long a brain's wizard takes to draw a spell
const SPAWN_TIME := 0.7       # a wizard summoned into the world arrives out of a circle this long
const FALL_LIMIT := 800.0     # a wizard below this has fallen off the map (in a world, the bottom of it)
const ICE := preload("res://art/props/ice_fill.png")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var look := "wizard"  # which wizard this is: the player's own, or the id of one of the others' looks (a MobKind in res://mobs)
var brain: WizardBrain  # what plays this wizard; none while a person does
var caster: Caster  # a brain's wizard draws its spells through this; a person's strokes are read by the arena's own
var nav: WorldNav  # the ways about the world, for a wizard that walks it by itself; none in the waiting room
var last_spell := ""
var _walk := 0.0  # the speed a brain asks to walk at, left or right, in pixels a second
var _jump_strength := 1.0  # how much of a full jump a brain asked for
var climb_up := false  # what a brain asks of a vine; a person's keys say the same
var climb_down := false
var let_go := false
var _stroke := PackedVector2Array()  # the spell a brain's wizard is drawing, and how far on it is
var _stroke_colour := Color.WHITE
var _draw_time := 0.0
var _draw_total := DRAW_TIME
var _on_drawn: Callable
var _overlay: Node2D  # draws the ice, and the stroke a brain's wizard is drawing, over the sprite
var stamina := MAX_STAMINA
var max_stamina := MAX_STAMINA  # what stamina can reach for now. Hits and the Rift wear it down; you die when it is gone
var ledger := Ledger.complete()  # the pages in the wizard's book: all of them in the waiting room, the ones found in a world
var movement_enabled := true  # the arena turns this off while a typing box or the spellbook is open
var infinite_time: float: # Chant of Boundless Vigour: stamina does not run out while this lasts
	get: return _status.left(&"infinite")
	set(seconds): _status.set_left(&"infinite", seconds)
var slow_time: float: # frost slows the caster while this lasts
	get: return _status.left(&"slow")
	set(seconds): _status.set_left(&"slow", seconds)
var sink_time: float: # quicksand: slowed, and unable to jump while this lasts
	get: return _status.left(&"sink")
	set(seconds): _status.set_left(&"sink", seconds)
var tangle_time: float: # caught in thorns: nearly stopped, and unable to jump while this lasts
	get: return _status.left(&"tangle")
	set(seconds): _status.set_left(&"tangle", seconds)
var deep_breath_time: float: # the Chant of the Deep Breath: the breath is held while this lasts, under water or not
	get: return _status.left(&"deep_breath")
	set(seconds): _status.set_left(&"deep_breath", seconds)
var breath := BREATH  # seconds of air left under water
var haste_time: float: # the Chant of Swift Feet: faster on foot while this lasts
	get: return _status.left(&"haste")
	set(seconds): _status.set_left(&"haste", seconds)
var air_jump_time: float: # the Chant of the Second Leap: a jump in the air is allowed while this lasts
	get: return _status.left(&"air_jump")
	set(seconds): _status.set_left(&"air_jump", seconds)
var adrenaline_time: float: # Adrenaline: stamina comes back quicker and the wizard is hasted while this lasts
	get: return _status.left(&"adrenaline")
	set(seconds): _status.set_left(&"adrenaline", seconds)
var obsidian_time: float: # Obsidian Armor: shots do half, lava does nothing, and the wizard is slower while this lasts
	get: return _status.left(&"obsidian")
	set(seconds): _status.set_left(&"obsidian", seconds)
var surf_time: float: # Tide Surf: a wave carries the wizard along surf_dir while this lasts
	get: return _status.left(&"surf")
	set(seconds): _status.set_left(&"surf", seconds)
var surf_dir := 1.0
var temp_stamina := 0.0  # stamina from an Offering: spent once the usual stamina is gone, never comes back by itself, and may pass the most
var veil := 0  # hits a Crimson Veil will still turn away
var _veil_cool := 0.0  # a moment after one is turned away, in which a burn or a second blow is turned away with it
var fainted := false  # knocked out by a Faint: down on the ground until the stamina comes back
var air_jump_ready := false  # the air jump is spent by one use, and comes back when the wizard lands
var _shove := Vector2.ZERO  # a Push on the caster: slides them for a moment, then fades
var mute_time: float: # no rituals while above zero
	get: return _status.left(&"mute")
	set(seconds): _status.set_left(&"mute", seconds)
var root_time: float: # no walking or jumping while above zero
	get: return _status.left(&"root")
	set(seconds): _status.set_left(&"root", seconds)
var _stuck_time := 0.0         # how long a giant's stomp has the player stuck in the ground
var _wet_material: ShaderMaterial  # cuts the body off at the waist while stuck, and colours the part under water or lava
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
var facing := 1.0
var _flash := 0.0        # red flash after being hit
var _liquid := Color.WHITE  # the colour of the water or lava the wizard stands in
var _liquid_time := 0.0
var _liquid_y := INF  # the height of the surface of that liquid
var _in_lava := false
var _grace := 0.0        # time left of the safety after a hit
var _coyote := 0.0
var _jump_buffer := 0.0
var _step := 0.0
var casting := false      # true while the caster has a stroke in progress (set by the arena)
var _releasing := 0.0     # time left of the thrust that plays when a spell goes off
var _hurt_anim := 0.0     # time left of the flinch after a hit
var cast_color := Color.WHITE  # the school being drawn (set by the arena); the staff's glow takes it
var _glow: Sprite2D            # a glow at the staff's head while a stroke is drawn
@onready var _sprite: AnimatedSprite2D = $Look
var _shield_emitter: CPUParticles2D
var _shield: Node2D
var _bubble: AnimatedSprite2D
var _swirl: Sprite2D  # the wind turning round the Barrier
var _vine: Node2D  # the vine (Liana) the wizard is hanging on, if any
var _vine_cooldown := 0.0  # after letting go, a vine cannot be grabbed again for a moment


func _ready() -> void:
	add_child(_status)
	_status.ended.connect(func(status: StringName) -> void:
		if status == &"frozen":
			Shatter.spawn(get_parent(), center(), Color("#cdeeff")))  # the ice gives way
	floor_max_angle = deg_to_rad(50.0)  # a 45 degree slope, the steepest a tunnel climbs, still counts as floor
	add_to_group("wizards")
	var art := "wizard"
	if brain == null:
		add_to_group("player")  # the one wizard the camera, the book and the bar belong to
	else:
		var data: MobKind = Mob.KINDS[look]
		art = data.art
		_sprite.scale = Vector2.ONE * data.scale
		$Camera2D.queue_free()
		_make_caster()
		_sprite.animation_finished.connect(_on_animation_finished)
		Fx.pop(get_parent(), global_position + Vector2(0, -2), "magic_02", Color("#d8d0e8"), 70.0, SPAWN_TIME + 0.2, 1.2, 1.5)  # it arrives through a summoning circle
		Sfx.play("summon", global_position)
	_sprite.sprite_frames = CharFrames.build("res://art/chars/" + art, ANIMATIONS if brain == null else LOOK_ANIMATIONS)
	_sprite.offset = Vector2(0, -PixelArt.CHARACTERS[art]["size"].y * 0.5)  # the frames' bottom edge is the feet
	_sprite.play("idle")
	_overlay = Node2D.new()
	_overlay.z_index = 10
	_overlay.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_wet_material = ShaderMaterial.new()
	_wet_material.shader = load("res://scripts/wet.gdshader")
	_sprite.material = _wet_material
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


## Encases the player in ice: rooted for the same time an enemy stays frozen.
func freeze(seconds: float) -> bool:
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
	if stamina + temp_stamina < amount:
		return false
	drain(amount)
	return true


## Take stamina even if it's short (misfire penalty); never goes below zero.
func drain(amount: float) -> void:
	if infinite_time > 0.0:
		return
	var short := maxf(amount - stamina, 0.0)  # what the usual stamina could not cover is taken from the offering
	stamina = maxf(stamina - amount, 0.0)
	temp_stamina = maxf(temp_stamina - short, 0.0)
	_since_spend = 0.0


## An Offering: stamina on top of the bar that is used last and not given back.
func gain_temp_stamina(amount: float) -> void:
	temp_stamina += amount
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "+%d" % roundi(amount), Color("#ff9aa8"), 1.0)


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, max_stamina)


func heal(amount: int) -> void:
	max_stamina = minf(max_stamina + amount, MAX_STAMINA)
	stamina = minf(stamina + amount, max_stamina)


## A hit lowers your most stamina and then gives a short grace, in which no other hit lands. A burn (grace_hit false) takes
## it without starting that grace, so a burn and a blow can both land.
func take_damage(amount: int, grace_hit := true, projectile := false) -> void:
	if (projectile and _shield_time > 0.0) or dead or (grace_hit and _grace > 0.0) or amount <= 0:
		return
	if veil > 0 or _veil_cool > 0.0:
		if _veil_cool <= 0.0:
			veil -= 1
			_veil_cool = 0.5
			Fx.burst(get_parent(), center(), SpellData.SCHOOL_COLORS["Blood"], 14, 140.0, 0.4, true)
			Sfx.play("glass", center(), -4.0)
		if grace_hit:
			_grace = HURT_GRACE
		return
	if projectile and obsidian_time > 0.0:
		amount = maxi(1, roundi(amount * OBSIDIAN_SHOTS))  # black glass takes half of what a shot would
	amount = roundi(amount * Hex.multiplier(get_tree(), self))  # a hexed wizard takes half again as much
	max_stamina -= amount
	stamina = minf(stamina, maxf(max_stamina, 0.0))
	_flash = 0.3
	_hurt_anim = 0.25
	if grace_hit:
		_grace = HURT_GRACE
	Sfx.play("player_hurt", center())
	GameCamera.shake_scene(get_tree(), 0.35 + amount * 0.02)
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d" % amount, Color("#ff5a5a"), 1.1)
	damaged.emit(amount)
	if brain != null:
		brain.on_hurt(amount)
	_check_death()


func _check_death() -> void:
	if max_stamina <= 0.0 and not dead:
		max_stamina = 0.0
		dead = true
		movement_enabled = false
		_draw_time = 0.0
		_stroke = PackedVector2Array()
		casting = false
		died.emit()
		if brain != null:
			_pass_away()


## A wizard no person plays falls where it stands: spells pass through it, and it fades after its death tumble. (A person's wizard
## stays, for the game-over screen and the camera.)
func _pass_away() -> void:
	set_deferred("collision_layer", 0)
	Sfx.play("mob_die", center())
	Fx.burst(get_parent(), center(), Color("#d8d0e8"), 18, 180.0, 0.6, true)
	Fx.smoke(get_parent(), center(), Color(0.25, 0.2, 0.3, 0.6), 5, 30.0)
	GameCamera.shake_scene(get_tree(), 0.18)


func _on_animation_finished() -> void:
	if dead and _sprite.animation == &"death":
		var fade := create_tween()
		fade.tween_interval(0.4)
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		fade.tween_callback(queue_free)


## Standing in water or lava: the part of the wizard below the surface takes its colour for a moment after each call, so
## leaving it fades back at once.
func soak(tint: Color, surface_y := INF, lava := false) -> void:
	_liquid = tint
	_liquid_y = surface_y
	_in_lava = lava
	_liquid_time = 0.15


## True when the wizard's head is under the surface of water.
func underwater() -> bool:
	return _liquid_time > 0.0 and not _in_lava and global_position.y - BODY_HEIGHT + 10.0 > _liquid_y


## True while the wizard holds their breath: no air is used up under water, and gas does no harm.
func holding_breath() -> bool:
	return deep_breath_time > 0.0


## The chant cannot be said under water, so the lungs are full when it takes hold, and breathing starts again, full, when it ends.
func grant_deep_breath(seconds: float) -> void:
	deep_breath_time = seconds
	breath = BREATH


func apply_debuff(kind: String, seconds: float) -> void:
	if dead:
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
		"tangle":
			tangle_time = maxf(tangle_time, seconds)
	debuff_applied.emit(kind)


func is_muted() -> bool:
	return mute_time > 0.0 or fainted


## Pays for a spell in maximum stamina, which only healing brings back. Never takes the last of it: false, and nothing paid, if the
## wizard could not live through it.
func pay_max(amount: float) -> bool:
	if dead or max_stamina <= amount:
		return false
	max_stamina -= amount
	stamina = minf(stamina, max_stamina)
	_flash = 0.3
	_since_spend = 0.0
	FloatText.spawn(get_parent(), center() + Vector2(0, -24), "-%d max" % roundi(amount), Color("#ff6b7a"), 1.0)
	return true


## A Faint: all the stamina goes, and the wizard drops. They stand up when the stamina has come back to GET_UP.
func faint() -> void:
	if dead or fainted:
		return
	fainted = true
	stamina = 0.0
	temp_stamina = 0.0
	_since_spend = 0.0
	casting = false
	_draw_time = 0.0
	_stroke = PackedVector2Array()
	Sfx.play("player_hurt", center())


func grant_adrenaline(seconds: float) -> void:
	adrenaline_time = maxf(adrenaline_time, seconds)
	haste_time = maxf(haste_time, seconds)


func raise_obsidian(seconds: float) -> void:
	obsidian_time = maxf(obsidian_time, seconds)
	Sfx.play("barrier", center())


## A wave takes hold of the wizard and carries them, whichever way it runs.
func start_surf(direction: float, seconds: float) -> void:
	surf_dir = signf(direction) if direction != 0.0 else facing
	surf_time = seconds


## True while black glass keeps lava from hurting.
func lava_proof() -> bool:
	return obsidian_time > 0.0


func is_blind() -> bool:
	return blind_time > 0.0


func status_text() -> String:
	var parts: Array[String] = []
	if mute_time > 0.0:
		parts.append("Muted")
	return "   ".join(parts)


## A soft shadow on the ground under the wizard. It shrinks and fades the higher the wizard is above the ground.
func _draw() -> void:
	_draw_breath()
	var below := _ground_distance()
	if below < 0.0:
		return
	var fade := clampf(1.0 - below / 160.0, 0.0, 1.0)
	var width := 15.0 * (0.6 + 0.4 * fade)
	_draw_ellipse(Vector2(0, below), width, width * 0.28, Color(0, 0, 0, 0.32 * fade))


## Air under water: a row of bubbles over the head, one for each second left.
func _draw_breath() -> void:
	if dead:
		return
	var bubble := Fx.tex("circle_05")
	if not holding_breath() and not underwater() and breath >= BREATH:
		return  # the bar shows while the breath is held, under water, and while the lungs fill again
	var left := deep_breath_time if holding_breath() else breath  # the held breath, when there is one, in place of the air
	var count := ceili(maxf(left, 0.0))
	var width := minf(14.0, 160.0 / maxf(count, 1.0))
	var size := minf(10.0, width - 1.0)
	for i in count:
		var at := Vector2((i - (count - 1) * 0.5) * width, -BODY_HEIGHT - 20.0)
		draw_texture_rect(bubble, Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), false, Color(0.75, 0.92, 1.0, 0.9))
	if left <= 0.0:
		draw_texture_rect(bubble, Rect2(Vector2(-6, -BODY_HEIGHT - 26.0), Vector2(12, 12)), false, Color(1.0, 0.4, 0.4, 0.9))


## Under water the air runs down, and once it is gone the most stamina does too, until the wizard surfaces. That loss is
## only made good the usual ways.
func _breathe(delta: float) -> void:
	if dead:
		return
	if holding_breath():
		breath = BREATH
	elif underwater():
		if breath > 0.0:
			breath = maxf(breath - delta, 0.0)
		else:
			max_stamina -= DROWN_RATE * delta
			stamina = minf(stamina, maxf(max_stamina, 0.0))
			_check_death()
	else:
		breath = minf(breath + delta * BREATH * 2.0, BREATH)


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
	if brain != null and global_position.y > (ArenaGen.world_size.y * float(ArenaGen.TILE) if ArenaGen.world_size.y > 0 else FALL_LIMIT) and not dead:
		max_stamina = 0.0  # off the bottom of the map
		_check_death()
	if brain != null and not dead:
		_think(delta)
	_grace -= delta
	_veil_cool -= delta
	_shield_emitter.emitting = _shield_time > 0.0
	if fainted and stamina >= GET_UP:
		fainted = false  # the stamina is back: up again
	_breathe(delta)
	if is_on_floor():
		air_jump_ready = true
	if infinite_time > 0.0:
		stamina = max_stamina
	_since_spend += delta
	if _since_spend >= REGEN_DELAY:
		restore_stamina(STAMINA_REGEN * (ADRENALINE_REGEN if adrenaline_time > 0.0 else 1.0) * delta)
	queue_redraw()
	_shield.queue_redraw()

	if not is_on_floor():
		velocity.y += gravity * delta
	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_jump_buffer -= delta

	var can_move := movement_enabled and root_time <= 0.0 and not dead and not fainted
	_vine_cooldown -= delta
	if can_move and _climb():
		return
	if can_move:
		if brain == null and Input.is_action_just_pressed("jump"):
			request_jump()
		if _jump_buffer > 0.0 and _coyote > 0.0 and sink_time <= 0.0 and tangle_time <= 0.0 and spend(JUMP_COST):
			velocity.y = JUMP_VELOCITY * _jump_strength
			_jump_buffer = 0.0
			_coyote = 0.0
			Sfx.play("jump", global_position)
		elif _jump_buffer > 0.0 and air_jump_time > 0.0 and air_jump_ready and sink_time <= 0.0 and tangle_time <= 0.0 and not is_on_floor():
			# The second leap: a jump in the air, free of stamina, once per landing.
			velocity.y = JUMP_VELOCITY * 0.9
			_jump_buffer = 0.0
			air_jump_ready = false
			Sfx.play("jump", global_position)
		# Letting go of jump early cuts the jump short, so small hops are easy.
		if brain == null and Input.is_action_just_released("jump") and velocity.y < JUMP_VELOCITY * 0.4:
			velocity.y = JUMP_VELOCITY * 0.4
		# Walking is free; running drains stamina. With none left you still walk, at half speed.
		var speed := (SPEED if stamina > 0.0 else SPEED * 0.5) * (0.5 if slow_time > 0.0 else 1.0) * (0.4 if sink_time > 0.0 else 1.0) * (0.3 if tangle_time > 0.0 else 1.0) * (HASTE if haste_time > 0.0 else 1.0) * (OBSIDIAN_SPEED if obsidian_time > 0.0 else 1.0)
		velocity.x = Input.get_axis("move_left", "move_right") * speed if brain == null else clampf(_walk, -speed, speed)
		if is_on_floor() and absf(velocity.x) > 10.0 and stamina > 0.0:
			drain(RUN_COST * delta)
	else:
		velocity.x = 0.0
	if surf_time > 0.0 and not dead and not fainted:
		velocity.x = surf_dir * SURF_SPEED  # a wave does not wait for the wizard
	velocity.x += _shove.x
	if _shove.y < 0.0:
		velocity.y = minf(velocity.y, _shove.y)
	_shove = _shove.move_toward(Vector2.ZERO, 1500.0 * delta)

	# Walking into a ledge one tile high: a small hop lifts the wizard up it, so slopes and steps are walkable.
	if is_on_floor() and is_on_wall() and absf(velocity.x) > 10.0 and not dead and sink_time <= 0.0 and tangle_time <= 0.0:
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
	var up := Input.is_action_pressed("move_up") if brain == null else climb_up
	var down := Input.is_action_pressed("move_down") if brain == null else climb_down
	var letting_go := Input.is_action_pressed("let_go") if brain == null else let_go
	var sideways := Input.get_axis("move_left", "move_right") if brain == null else clampf(_walk / SPEED, -1.0, 1.0)
	if _vine == null:
		if _vine_cooldown > 0.0 or not up:
			return false
		for vine in get_tree().get_nodes_in_group("climbables"):
			if vine.can_grab(hands):
				_vine = vine
				break
		if _vine == null:
			return false
	if letting_go or absf(sideways) > 0.5:
		# Let go: a hop off the vine in the way the wizard was leaning.
		velocity = Vector2(sideways * SPEED, JUMP_VELOCITY * 0.6 if letting_go else 0.0)
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
	_wet_material.set_shader_parameter("keep", 0.7)
	# The cut is 57 px above the frame's bottom, so this drops the cut onto the ground: the body is in the ground from there down.
	_sprite.position = Vector2(0, 57)


## Lets the player out of the ground, as a throw does.
func unstick() -> void:
	_stuck_time = 0.0
	_wet_material.set_shader_parameter("keep", 2.0)
	_sprite.position = Vector2.ZERO


func _process(delta: float) -> void:
	if _stuck_time > 0.0:
		_stuck_time -= delta
		if _stuck_time <= 0.0:
			unstick()
	_animate(delta)
	_overlay.queue_redraw()


## Picks the animation for what the wizard is doing, faces the way it is moving, and flashes when hit.
func _animate(delta: float) -> void:
	if absf(velocity.x) > 10.0 and not dead and brain == null:
		facing = signf(velocity.x)  # (a brain turns its wizard itself)
	_releasing = maxf(_releasing - delta, 0.0)
	_hurt_anim = maxf(_hurt_anim - delta, 0.0)
	var wanted := "idle"
	if dead or fainted:
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
		_glow.position = Vector2(STAFF_HEAD.x * facing, STAFF_HEAD.y)
		_glow.modulate = Color(cast_color, 0.9)
	_flash = maxf(_flash - delta, 0.0)
	# After a hit the wizard blinks while it can't be hurt again.
	var blink := _grace > 0.0 and int(_grace * 20.0) % 2 == 0
	_liquid_time = maxf(_liquid_time - delta, 0.0)
	var wet := _liquid_time > 0.0
	_wet_material.set_shader_parameter("water_y", _liquid_y if wet else 1000000.0)
	_wet_material.set_shader_parameter("water_tint", _liquid)
	_sprite.modulate = Color(1.0, 0.45, 0.45) if _flash > 0.0 else Color(1.0, 1.0, 1.0, 0.55 if blink else 1.0)
	if obsidian_time > 0.0 and _flash <= 0.0:
		var glint := 0.5 + 0.08 * sin(Time.get_ticks_msec() * 0.006)
		_sprite.modulate = Color(glint, glint * 0.92, glint * 1.2, _sprite.modulate.a)  # black glass, with a violet shine


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
	caster.cast_resolved.connect(Callable(get_parent(), "cast_by").bind(self))


## A brain's wizard speaks a chant (see Arena.chant_by).
func chant(id: String) -> bool:
	return get_parent().chant_by(self, id)


## The brain's turn: a spell it is drawing goes off when the stroke is done, and then it decides what to do next.
func _think(delta: float) -> void:
	if fainted:
		_draw_time = 0.0
		_walk = 0.0
		return
	if _draw_time > 0.0:
		_draw_time -= delta
		if _draw_time <= 0.0:
			var stroke := _stroke
			_stroke = PackedVector2Array()
			casting = false
			play_cast_release()
			_on_drawn.call(stroke)
	caster.anchor = center()
	brain.think(delta)


## A brain asks to walk at a speed, left (negative) or right: the body keeps to what it can do.
func walk(speed: float) -> void:
	_walk = speed


## A jump, asked for as a person asks with the key: it happens if the wizard is on the ground (or just left it) and has the stamina.
## A brain asks for a part of a full jump for a hop.
func request_jump(strength := 1.0) -> void:
	_jump_buffer = JUMP_BUFFER
	_jump_strength = strength


## Starts drawing a stroke in front of the wizard. After draw_time it calls on_done with the stroke.
## Being hit hard while drawing breaks the spell (see WizardBrain.on_hurt).
func start_drawing(points: PackedVector2Array, colour: Color, on_done: Callable, draw_time := DRAW_TIME) -> void:
	_stroke = points
	_stroke_colour = colour
	cast_color = colour
	_on_drawn = on_done
	_draw_time = draw_time
	_draw_total = draw_time
	casting = true
	Sfx.play("wizard_cast", center())


func is_drawing() -> bool:
	return _draw_time > 0.0


## Drops the spell being drawn, with a puff of sparks so a rival can see it was broken.
func interrupt_cast() -> void:
	if _draw_time <= 0.0:
		return
	_draw_time = 0.0
	_stroke = PackedVector2Array()
	casting = false
	Fx.burst(get_parent(), center() + Vector2(facing * 14.0, -16.0), _stroke_colour, 14, 140.0, 0.4, true)
	FloatText.spawn(get_parent(), center() + Vector2(0, -44), "Interrupted!", Color("#d9b8ff"), 0.9)
	Sfx.play("misfire", center())


## Things drawn over the sprite: the block of ice a frozen wizard is in, and the stroke a brain's wizard is drawing, which
## grows as the spell does so that it can be read and broken.
func _draw_overlay() -> void:
	if dead:
		return
	if is_frozen():
		var body := Vector2(BODY_WIDTH, BODY_HEIGHT)
		var box := Rect2((center_offset() - body * 0.5 - Vector2(6, 6)).floor(), (body + Vector2(12, 10)).floor())
		_overlay.draw_texture_rect(ICE, box, true, Color(1, 1, 1, 0.6))
	if _draw_time > 0.0 and _stroke.size() >= 2:
		var progress := 1.0 - _draw_time / _draw_total
		var count := clampi(int(_stroke.size() * progress), 2, _stroke.size())
		var local := PackedVector2Array()
		for i in count:
			local.append(_stroke[i] - global_position)
		var c := _stroke_colour
		_overlay.draw_polyline(local, Color(c.r, c.g, c.b, 0.25), 7.0)
		_overlay.draw_polyline(local, Color(c.r, c.g, c.b, 0.9), 3.0)
		_overlay.draw_polyline(local, Color(1.0, 1.0, 1.0, 0.9), 1.0)
		Fx.draw_glow(_overlay, local[local.size() - 1], 8.0, Color(c.r, c.g, c.b, 0.9))


func is_rooted() -> bool:
	return root_time > 0.0


func is_slowed() -> bool:
	return slow_time > 0.0
