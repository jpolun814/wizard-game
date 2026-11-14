class_name Lungs
extends RefCounted

## A wizard's air, and the water around it: whether the head is under the surface, how long the breath lasts, and what happens when it is gone. Reached as
## `wizard.lungs`.

const BREATH := 8.0  # seconds under water before the wizard starts to drown
const DEEP_BREATH := 45.0  # seconds the Blessing of the Deep Breath holds the wizard's breath: it counts down from the chant
const DROWN_RATE := 3.0  # most stamina lost per second while out of breath, and it does not come back by itself
const HEAD_BELOW := 10.0  # the head is under when the surface is this far above the top of the hood

var wizard: Wizard
var air := BREATH  # seconds of air left while the breath is held without the Blessing of the Deep Breath
var smothered := false  # the air is drawn out of the wizard's lungs (Vacuum sets and clears this)
var _tint := Color.WHITE  # the colour of the water or lava the wizard stands in
var _time := 0.0
var _surface := INF  # the height of the surface of that liquid
var _lava := false


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## Standing in water or lava: the part of the wizard below the surface takes its colour for a moment after each call, so leaving it fades back at once.
func soak(tint: Color, surface_y := INF, lava := false) -> void:
	_tint = tint
	_surface = surface_y
	_lava = lava
	_time = 0.15


## The wet part of the body fades as the moments pass; the shader is told where the surface is.
func dry(delta: float) -> void:
	_time = maxf(_time - delta, 0.0)


func is_wet() -> bool:
	return _time > 0.0


func tint() -> Color:
	return _tint


## The height of the surface of the liquid the wizard is in (water or lava), for the colour of its lower body; far below the world when in none.
func liquid_surface() -> float:
	return _surface if _time > 0.0 else 1000000.0


## The height of the surface of the water the wizard is in, or INF when it is in none.
func surface() -> float:
	return _surface if _time > 0.0 and not _lava else INF


## True when the wizard's head is under the surface of water.
func submerged() -> bool:
	return _time > 0.0 and not _lava and wizard.global_position.y - Wizard.BODY_HEIGHT + HEAD_BELOW > _surface


## True while the wizard holds their breath, for any reason: under water, in the Blessing of the Deep Breath, in a block of ice, or with the air drawn out of
## them. Gas does no harm to anyone holding their breath, and nobody can chant.
func holding() -> bool:
	return submerged() or smothered or wizard.deep_breath_time > 0.0 or wizard.is_frozen()


## The air is drawn out of the wizard's lungs, or let back in. They hold their breath as they do under water, with what air they have.
func smother(on: bool) -> void:
	smothered = on


## The chant cannot be said under water, so the lungs are full when it takes hold, and breathing starts again, full, when it ends.
func grant_deep(seconds: float) -> void:
	wizard.deep_breath_time = seconds
	air = BREATH


## While the breath is held (under water, or with the air drawn out) the air runs down, and once it is gone the most stamina does too, until the wizard breathes
## again. That loss is only made good the usual ways. The Blessing of the Deep Breath holds the breath without using the air.
func tick(delta: float) -> void:
	if wizard.dead:
		return
	if wizard.deep_breath_time > 0.0:
		air = BREATH
	elif submerged() or smothered or wizard.is_frozen():  # (in a block of ice there is no breathing either)
		if air > 0.0:
			air = maxf(air - delta, 0.0)
		else:
			wizard.drown(DROWN_RATE * delta)
	else:
		air = minf(air + delta * BREATH * 2.0, BREATH)


## Air under water: a row of bubbles over the head, one for each second left, drawn on the wizard's own canvas.
func draw_bubbles() -> void:
	if wizard.dead or wizard.is_likeness():
		return
	if not holding() and air >= BREATH:
		return  # the bar shows while the breath is held, under water, and while the lungs fill again
	var bubble := Fx.tex("circle_05")
	var left := wizard.deep_breath_time if wizard.deep_breath_time > 0.0 else air  # the chant's held breath, when there is one, in place of the air
	var count := ceili(maxf(left, 0.0))
	var width := minf(14.0, 160.0 / maxf(count, 1.0))
	var size := minf(10.0, width - 1.0)
	for i in count:
		var at := Vector2((i - (count - 1) * 0.5) * width, -Wizard.BODY_HEIGHT - 20.0)
		wizard.draw_texture_rect(bubble, Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), false, Color(0.75, 0.92, 1.0, 0.9))
	if left <= 0.0:
		wizard.draw_texture_rect(bubble, Rect2(Vector2(-6, -Wizard.BODY_HEIGHT - 14.0), Vector2(12, 12)), false, Color(1.0, 0.4, 0.4, 0.9))
