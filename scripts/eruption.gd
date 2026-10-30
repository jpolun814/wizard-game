class_name Eruption
extends Node2D

## The crater of a volcano of the ashlands (not a spell: the mountain is the world's own ground). It sleeps for a while, rumbles and
## smokes, then erupts for a few seconds, throwing balls of lava (LavaBall) that burn where they land. In a network match the host
## decides when it wakes, and tells the others with a seed, so every machine sees the same eruption and the same balls thrown.

const SLEEP_MIN := 14.0
const SLEEP_MAX := 34.0
const RUMBLE := 2.5       # seconds of smoke and shaking before it erupts
const ERUPT_SECONDS := 4.0
const THROW_INTERVAL := 0.55

var _phase := 0.0  # seconds left in the sleep, the rumble or the eruption
var _rng := RandomNumberGenerator.new()  # seeded the same on every machine when the volcano wakes
var _state := "sleeping"
var _throw := 0.0
var _age := 0.0
var _vent: AnimatedSprite2D
var _glow: Node2D


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
			if fmod(_age, 0.4) < delta:
				Fx.smoke(get_parent(), global_position + Vector2(0, -16), Color(0.2, 0.17, 0.17, 0.6), 1, 24.0, 40.0)
			if _phase <= 0.0:
				_state = "erupting"
				_phase = ERUPT_SECONDS
				_vent.visible = true
				Sfx.play("volcano", global_position)
				GameCamera.shake_scene(get_tree(), 0.3)
		"erupting":
			_throw -= delta
			if _throw <= 0.0:
				_throw = THROW_INTERVAL
				LavaBall.throw(get_parent(), global_position + Vector2(0, -24), Vector2(_rng.randf_range(-240.0, 240.0), _rng.randf_range(-560.0, -420.0)))
				Fx.smoke(get_parent(), global_position + Vector2(0, -40), Color(0.2, 0.17, 0.17, 0.6), 2, 26.0, 60.0)
			if _phase <= 0.0:
				_state = "sleeping"
				_phase = randf_range(SLEEP_MIN, SLEEP_MAX)
				_vent.visible = false
	_glow.queue_redraw()


## The volcano wakes: it rumbles, then erupts.
@rpc("authority", "call_remote", "reliable")
func _wake(seed_value: int) -> void:
	_rng.seed = seed_value
	_state = "rumbling"
	_phase = RUMBLE


## True while it is erupting.
func is_erupting() -> bool:
	return _state == "erupting"


## True over the crater while it erupts, and while it is about to.
func danger_at(point: Vector2) -> bool:
	return _state != "sleeping" and absf(point.x - global_position.x) < 140.0 and point.y > global_position.y - 260.0 and point.y < global_position.y + 40.0


func _draw_glow() -> void:
	if _state != "sleeping":
		_glow.draw_circle(Vector2(0, -20), 36.0 + 5.0 * sin(_age * 6.0), Color(1.0, 0.45, 0.15, 0.14))
