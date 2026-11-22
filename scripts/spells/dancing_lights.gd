class_name DancingLights
extends Node2D

## Dancing Lights: colorful lights that pop up and fade close around the caster, one place after another, for as long as the spell lasts. Each light is itself
## what shines (a light in the dark, see `Mote`), so the dark is lit where they are and nowhere else. They are lights and nothing more: they burn nothing, and
## water and wind do not put them out. One set each: a new cast replaces the old. They go when the caster falls.

const SECONDS := 25.0
const SPAWN_EVERY := 0.2    # seconds between one light appearing and the next
const NEAR := 24.0          # how close to the caster a light may appear, and how far
const FAR := 90.0
const COLORS := [Color("#ff6fae"), Color("#6fd8ff"), Color("#ffe36f"), Color("#8fff8f"), Color("#c18fff"), Color("#ff9a5a")]

var caster: Wizard  # set by the arena before it enters the tree
var _age := 0.0
var _next := 0.0


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("dancing_lights"):
		if other != self and other.caster == caster:
			other.queue_free()  # one set each: a new one replaces the old
	add_to_group("dancing_lights")
	add_to_group("lasting")
	global_position = SpellTargets.center_of(caster) if is_instance_valid(caster) else global_position


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= SECONDS or (is_instance_valid(caster) and caster.dead):
		queue_free()
		return
	if is_instance_valid(caster):
		global_position = SpellTargets.center_of(caster)
	_next -= delta
	if _next <= 0.0:
		_next = SPAWN_EVERY
		_appear()


## Somewhere close round the caster, a light comes up and goes out again.
func _appear() -> void:
	var mote := Mote.new()
	mote.color = COLORS[randi() % COLORS.size()]
	mote.own = not is_instance_valid(caster) or caster.brain == null
	get_parent().add_child(mote)
	mote.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(NEAR, FAR) * Vector2(1.0, 0.8) + Vector2(0.0, -10.0)
	Sfx.cue("Dancing Lights", "twinkle", mote.global_position, -5.0, 0.12)  # every light that pops up twinkles, each a little differently


## One of the lights: it swells and fades, and the glow it gives is the light it throws (in a dark place a real light, and for the Eclipse and for sight in the dark
## a light as a Glowcap is). It drifts up a little as it goes.
class Mote extends Node2D:
	const LIFE := 1.6
	const LIGHT_RADIUS := 150.0  # how far one light shows what is hidden in the dark
	const GLOW := 64.0           # the size of the glow you see: it is the light

	var color := Color.WHITE
	var own := true       # shines on this screen (a rival's lights do not light the screen of someone watching: the dark is theirs)
	var light_radius := LIGHT_RADIUS
	var _age := 0.0
	var _light: PointLight2D

	func _ready() -> void:
		add_to_group("lights")
		z_index = 5
		material = Fx.additive()
		if own and get_tree().get_first_node_in_group("darkness") != null:
			_light = PointLight2D.new()
			_light.texture = Fx.tex("light_01")
			_light.texture_scale = LIGHT_RADIUS * 2.0 / Fx.TEX_SIZE
			_light.color = color
			_light.energy = 0.0
			_light.shadow_enabled = false
			add_child(_light)

	func _physics_process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		global_position.y -= 6.0 * delta
		queue_redraw()
		if _light != null:
			_light.energy = 1.2 * _shine()

	## 0 to 1 and back: up fast, away slowly.
	func _shine() -> float:
		var t := _age / LIFE
		return minf(t / 0.2, 1.0) * (1.0 - t) if t > 0.2 else t / 0.2

	func _draw() -> void:
		var shine := _shine()
		Fx.draw_glow(self, Vector2.ZERO, GLOW * (0.6 + 0.4 * shine), Color(color.r, color.g, color.b, 0.55 * shine))
		Fx.draw_glow(self, Vector2.ZERO, GLOW * 0.3 * (0.6 + 0.4 * shine), Color(1.0, 1.0, 1.0, 0.9 * shine))
		Fx.draw_glow(self, Vector2.ZERO, GLOW * 0.7, Color(color.r, color.g, color.b, 0.35 * shine), "flare_01")
