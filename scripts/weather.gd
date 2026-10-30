class_name Weather
extends CPUParticles2D

## What hangs in the air of a biome on the surface: snow and a blizzard on the peaks, ash and embers in the ashlands, spores over the
## jungle, rain and a low fog in the graveyard. It rides on the camera and fills the view. It fades out when the wizard goes under the ground
## or into another biome, and the new weather fades in.

const KINDS := {
	"snow": {"amount": 160, "life": 8.0, "box": Vector2(720, 6), "at": Vector2(0, -400), "dir": Vector2(0.15, 1), "spread": 12.0, "speed": Vector2(40, 80),
		"gravity": Vector2(6, 12), "texture": "circle_05", "size": Vector2(7, 13), "colour": Color(1, 1, 1, 0.9)},
	"blizzard": {"amount": 280, "life": 5.0, "box": Vector2(900, 6), "at": Vector2(300, -400), "dir": Vector2(-0.7, 1), "spread": 10.0, "speed": Vector2(160, 240),
		"gravity": Vector2(-60, 20), "texture": "circle_05", "size": Vector2(6, 11), "colour": Color(0.95, 0.98, 1, 0.9)},
	"ash": {"amount": 120, "life": 9.0, "box": Vector2(720, 6), "at": Vector2(0, -400), "dir": Vector2(0.2, 1), "spread": 20.0, "speed": Vector2(20, 45),
		"gravity": Vector2(10, 4), "texture": "circle_02", "size": Vector2(6, 11), "colour": Color(0.7, 0.64, 0.62, 0.8)},
	"embers": {"amount": 60, "life": 5.0, "box": Vector2(720, 6), "at": Vector2(0, 380), "dir": Vector2(0.1, -1), "spread": 25.0, "speed": Vector2(40, 90),
		"gravity": Vector2(8, -10), "texture": "circle_05", "size": Vector2(5, 9), "colour": Color(1.0, 0.6, 0.25, 1.0), "glow": true},
	"rain": {"amount": 240, "life": 1.3, "box": Vector2(780, 6), "at": Vector2(80, -400), "dir": Vector2(-0.22, 1), "spread": 2.0, "speed": Vector2(560, 660),
		"gravity": Vector2.ZERO, "texture": "rain_streak", "size": Vector2(55, 85), "colour": Color(0.72, 0.82, 1.0, 0.6), "align": true},
	"gale_east": {"amount": 90, "life": 1.0, "box": Vector2(8, 380), "at": Vector2(-560, 0), "dir": Vector2(1, 0.05), "spread": 3.0, "speed": Vector2(620, 800),
		"gravity": Vector2.ZERO, "texture": "rain_streak", "size": Vector2(70, 120), "colour": Color(0.92, 0.96, 1.0, 0.55), "align": true},
	"gale_west": {"amount": 90, "life": 1.0, "box": Vector2(8, 380), "at": Vector2(560, 0), "dir": Vector2(-1, 0.05), "spread": 3.0, "speed": Vector2(620, 800),
		"gravity": Vector2.ZERO, "texture": "rain_streak", "size": Vector2(70, 120), "colour": Color(0.92, 0.96, 1.0, 0.55), "align": true},
	"fog": {"amount": 70, "life": 14.0, "box": Vector2(780, 240), "at": Vector2(0, 20), "dir": Vector2(1, 0), "spread": 15.0, "speed": Vector2(8, 18),
		"gravity": Vector2.ZERO, "texture": "smoke_01", "size": Vector2(300, 520), "colour": Color(0.78, 0.8, 0.85, 0.34)},
	"spores": {"amount": 46, "life": 10.0, "box": Vector2(680, 360), "at": Vector2.ZERO, "dir": Vector2(0, -1), "spread": 180.0, "speed": Vector2(5, 16),
		"gravity": Vector2(0, -2), "texture": "light_01", "size": Vector2(10, 20), "colour": Color(0.7, 1.0, 0.5, 0.5), "glow": true},
}

var want_kind := ""      # the weather the biome has, "" for none
var want_strength := 1.0  # how much of it: less near the ground's edge
var _kind := ""
var _strength := 0.0


func _ready() -> void:
	local_coords = false  # a flake stays where the wind left it when the camera moves on
	z_index = 4
	emitting = false


func _process(delta: float) -> void:
	if _kind != want_kind:
		_strength = move_toward(_strength, 0.0, delta * 0.8)
		if _strength <= 0.0:
			_apply(want_kind)
	else:
		_strength = move_toward(_strength, want_strength if _kind != "" else 0.0, delta * 0.8)
	modulate.a = clampf(_strength, 0.0, 1.0)
	emitting = _strength > 0.01


func _apply(kind: String) -> void:
	_kind = kind
	if kind == "":
		emitting = false
		return
	var look: Dictionary = KINDS[kind]
	amount = look["amount"]
	lifetime = look["life"]
	preprocess = look["life"]
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = look["box"]
	position = look["at"]
	direction = look["dir"]
	spread = look["spread"]
	initial_velocity_min = look["speed"].x
	initial_velocity_max = look["speed"].y
	gravity = look["gravity"]
	particle_flag_align_y = look.get("align", false)  # a streak of rain points the way it falls
	texture = Fx.tex(look["texture"])
	scale_amount_min = look["size"].x / Fx.TEX_SIZE
	scale_amount_max = look["size"].y / Fx.TEX_SIZE
	var colour: Color = look["colour"]
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(colour, 0.0), colour, colour, Color(colour, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.8, 1.0])
	color_ramp = ramp
	material = Fx.additive() if look.get("glow", false) else null
	restart()
