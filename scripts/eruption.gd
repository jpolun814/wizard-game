class_name Eruption
extends Node2D

## The crater of a volcano of the ashlands (not a spell: the mountain is the world's own ground). It sleeps for a long while, then
## rumbles and shakes the world as a great plume of smoke (SmokePlume) rises, then erupts: it throws balls of lava (LavaBall) and pours
## lava over the rim, which runs down the mountain's real slopes and, once the eruption is over, cools to a crust and goes. In a network
## match the host decides when it wakes, and tells the others with a seed, so every machine sees the same eruption and the same balls thrown.

const SLEEP_MIN := 40.0
const SLEEP_MAX := 80.0
const RUMBLE := 4.0       # seconds of smoke and shaking before it erupts
const ERUPT_SECONDS := 8.0
const THROW_INTERVAL := 0.55
const POUR_INTERVAL := 0.25  # seconds between spoonfuls of lava over the rim, while it erupts
const POUR_AMOUNT := 1.0     # how much lava wells up at each of the places along the crater, in cells of liquid, every time
const POUR_SPOTS := 5        # places across the crater it wells up, so the bowl fills evenly and then spills over its rim
const BOWL_FLOOR := 28.0  # how far below the rim the bowl in the top of the mountain lies
const CRATER_SPAN := 16.0 * 32.0  # how wide the bowl in the top of the mountain is (SurfaceGen.CRATER_WIDTH tiles)
const SHAKE_REACH := 2400.0  # how far off the ground still shakes under a wizard

var _phase := 0.0  # seconds left in the sleep, the rumble or the eruption
var _rng := RandomNumberGenerator.new()  # seeded the same on every machine when the volcano wakes
var _state := "sleeping"
var _throw := 0.0
var _age := 0.0
var _vent: AnimatedSprite2D
var _glow: Node2D
var ground: Terrain  # the world's ground, which the lava runs over
var _plume: SmokePlume
var _pour := 0.0


func _ready() -> void:
	add_to_group("danger")
	_phase = randf_range(SLEEP_MIN * 0.3, SLEEP_MAX)  # the volcanoes of a world do not wake together (only the host's is used)
	_vent = PixelFx.sprite("fire_puff", 14.0, true, 1)
	_vent.scale = Vector2.ONE * 2.0
	_vent.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
	_vent.z_index = 1
	_vent.visible = false
	add_child(_vent)
	_glow = Node2D.new()
	_glow.material = Fx.additive()
	add_child(_glow)
	_glow.draw.connect(_draw_glow)


func _physics_process(delta: float) -> void:
	_age += delta
	if _state != "sleeping" or Net.is_host():  # asleep, only the host counts down: the others wait to be told
		_phase -= delta
	match _state:
		"sleeping":
			if _phase <= 0.0:
				var seed_value := randi()
				Net.send(self, &"_wake", [seed_value])
				_wake(seed_value)
		"rumbling":
			_shake(0.04)
			if fmod(_age, 0.4) < delta:
				Fx.smoke(get_parent(), global_position + Vector2(0, -16), Color(0.2, 0.17, 0.17, 0.6), 1, 24.0, 40.0)
				LavaBall.throw(get_parent(), global_position + Vector2(0, -24), Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-300.0, -220.0)))  # spits before it blows
			if _phase <= 0.0:
				_state = "erupting"
				_phase = ERUPT_SECONDS
				_vent.visible = true
				Sfx.play("volcano", global_position)
				GameCamera.shake_scene(get_tree(), 0.3)
		"erupting":
			_shake(0.09)
			_pour -= delta
			if _pour <= 0.0:
				_pour = POUR_INTERVAL
				_pour_lava()
			_throw -= delta
			if _throw <= 0.0:
				_throw = THROW_INTERVAL
				LavaBall.throw(get_parent(), global_position + Vector2(0, -24), Vector2(_rng.randf_range(-240.0, 240.0), _rng.randf_range(-560.0, -420.0)))
				Fx.smoke(get_parent(), global_position + Vector2(0, -40), Color(0.2, 0.17, 0.17, 0.6), 2, 26.0, 60.0)
			if _phase <= 0.0:
				_state = "sleeping"
				_phase = randf_range(SLEEP_MIN, SLEEP_MAX)
				_vent.visible = false
				if _plume != null:
					_plume.release()
					_plume = null
	_glow.queue_redraw()


## The volcano wakes: it rumbles, then erupts.
@rpc("authority", "call_remote", "reliable")
func _wake(seed_value: int) -> void:
	_rng.seed = seed_value
	_state = "rumbling"
	_phase = RUMBLE
	_plume = SmokePlume.new()
	_plume.position = global_position + Vector2(0.0, BOWL_FLOOR)  # the smoke starts in the hole
	get_parent().add_child(_plume)


## The ground shakes the camera of anyone near enough: the more the closer.
func _shake(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		GameCamera.shake_scene(get_tree(), amount * clampf(1.0 - player.global_position.distance_to(global_position) / SHAKE_REACH, 0.0, 1.0))


## Lava wells over the rim and runs down the mountain; the pool it makes cools once the eruption is over.
func _pour_lava() -> void:
	if ground == null:
		return
	for k in POUR_SPOTS:
		var across := (float(k) / (POUR_SPOTS - 1) - 0.5) * (CRATER_SPAN - 64.0)
		var pool := Pond.spill(get_parent(), ground, global_position + Vector2(across, BOWL_FLOOR - 4.0), POUR_AMOUNT, true)  # welling up from the floor of the bowl, so it rises instead of falling in
		pool.cools = true


## True while it is erupting.
func is_erupting() -> bool:
	return _state == "erupting"


## True over the crater while it erupts, and while it is about to.
func danger_at(point: Vector2) -> bool:
	return _state != "sleeping" and absf(point.x - global_position.x) < 140.0 and point.y > global_position.y - 260.0 and point.y < global_position.y + 40.0


func _draw_glow() -> void:
	if _state != "sleeping":
		Fx.draw_glow(_glow, Vector2(0, -20), 36.0 + 5.0 * sin(_age * 6.0), Color(1.0, 0.45, 0.15, 0.14))
