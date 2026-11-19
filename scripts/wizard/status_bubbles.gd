class_name StatusBubbles
extends RefCounted

## The little bubbles that ring a wizard, one for each state it is in (frozen, wet, burning, hexed...), so everyone can see what is the matter with them. They go round
## the wizard clockwise from the top, in the order the states began. A state that wears off by the clock has a ring round its bubble that empties like a clock winding
## down. Holding the breath is one of them, and when its ring is empty it turns into choking. Reached as `wizard.bubbles`.
## A copy of a wizard on another machine can only show what the marks carry: frozen, slowed, veiled, wet, burning and oiled.

const ICONS := preload("res://art/fx/status_icons.png")
const ORDER := ["frozen", "slowed", "dazed", "hexed", "silenced", "holding", "choking", "confused", "fleeing", "bleeding", "veiled", "hasted", "adrenaline", "unlimited", "extra_jump", "wet", "burning", "oiled", "cross"]
const ICON := 9.0         # a picture is 9 pixels
const RADIUS := 5.5       # the bubble
const RING_COLOR := Color(0.92, 0.95, 1.0, 0.95)
const SPACING := 11.5     # the distance along the ring from one bubble to the next: they nearly touch
const PER_ROUND := 21     # bubbles in the first round about the wizard; the next round is wider
const ROUND_STEP := 11.0
const WIZARD_RX := 32.0   # the ring lies outside the body, so no bubble covers any of the wizard
const WIZARD_RY := 46.0
const NAMES := {"frozen": "Frozen", "slowed": "Slowed", "dazed": "Dazed", "hexed": "Hexed", "silenced": "Silenced", "holding": "Holding breath", "choking": "Choking", "confused": "Confused", "fleeing": "Fleeing", "bleeding": "Bleeding", "veiled": "Veiled", "hasted": "Hasted", "adrenaline": "Adrenaline", "unlimited": "Unlimited stamina", "extra_jump": "Extra jump", "wet": "Wet", "burning": "Burning", "oiled": "Oiled"}
const TIPS := {
	"wet": "Extinguishes flames\nTake increased damage from electricity\nFreeze faster and for longer",
	"burning": "Take fire damage over time\nIgnite anything else you touch",
	"oiled": "Burn for longer",
	"frozen": "Cannot move, act, or breathe",
	"slowed": "Move slower",
	"dazed": "Move slower\nCannot cast spells or chant incantations",
	"hexed": "Take increased damage\nCannot hide from whoever cast it",
	"silenced": "Cannot cast spells or chant incantations",
	"holding": "Cannot inhale, exhale, or speak",
	"choking": "Out of air\nTake damage over time",
	"confused": "Cast random spells",
	"fleeing": "Cannot move toward whoever cast it",
	"bleeding": "Take damage over time\nMove slower and casting is shakier",
	"veiled": "Negates the next few attacks",
	"hasted": "Run faster",
	"adrenaline": "Run faster\nTake less damage\nDeal more damage",
	"unlimited": "Spells cost no stamina",
	"extra_jump": "Jump again in mid-air",
}  # what each state does to whoever is in it, as the spellbook says when the mouse rests on its picture
const MIDDLE := Vector2(0.0, -34.0)

var wizard: Wizard
var _active: Array[String] = []   # in the order they began
var _left := {}                   # name -> seconds left now, or -1 when there is no clock to it
var _most := {}                   # name -> the most seconds seen left, the whole of the ring
var _layer: BubbleLayer


func _init(owner_wizard: Wizard) -> void:
	wizard = owner_wizard


## Looks at what the wizard is in, notes what began and what ended, and asks for a redraw while there is anything to show.
func tick() -> void:
	var now := _states()
	var had := not _active.is_empty()
	for name: String in _active.duplicate():
		if not now.has(name):
			_active.erase(name)
			_most.erase(name)
	for name: String in ORDER:
		if now.has(name) and not _active.has(name):
			_active.append(name)
		if now.has(name):
			var seconds: float = now[name]
			if seconds > 1.0e8:
				seconds = -1.0
			_left[name] = seconds
			if seconds > 0.0:
				_most[name] = maxf(_most.get(name, 0.0), seconds)
	if had or not _active.is_empty():  # (once more after the last one ends, so the layer is cleared)
		_layer.queue_redraw()


## Every state the wizard is in now, with the seconds it has left (-1 when it is not on a clock).
func _states() -> Dictionary:
	var states := {}
	if wizard.dead:
		return states
	if wizard.is_likeness():
		var marks := wizard.marks
		if marks & Wizard.FROZEN:
			states["frozen"] = -1.0
		if marks & Wizard.SLOWED:
			states["slowed"] = -1.0
		if marks & Wizard.VEILED:
			states["veiled"] = -1.0
		if marks & Wizard.WET:
			states["wet"] = -1.0
		if marks & Wizard.BURNING:
			states["burning"] = -1.0
		if marks & Wizard.OILED:
			states["oiled"] = -1.0
		return states
	var tree := wizard.get_tree()
	if wizard.is_frozen():
		states["frozen"] = wizard.frozen_left()
	if wizard.is_slowed():
		states["slowed"] = wizard.slow_time if wizard.slow_time > 0.0 else -1.0
	var hex := Hex.on(tree, wizard)
	if hex != null:
		states["hexed"] = hex.left()
	if Silence.covers(tree, wizard.center()):
		states["silenced"] = -1.0
	if wizard.lungs.holding() and not wizard.is_frozen():
		var air := wizard.deep_breath_time / Lungs.DEEP_BREATH if wizard.deep_breath_time > 0.0 else wizard.lungs.air / Lungs.BREATH
		if wizard.golem.on:
			air = wizard.golem.time_left() / GolemForm.DURATION  # the stone holds its breath for as long as it lasts
		if air > 0.0:
			states["holding"] = air * 100.0   # a count of its own: 100 is a full breath
		else:
			states["choking"] = -1.0
	if wizard.daze_time > 0.0:
		states["dazed"] = wizard.daze_time
	if wizard.rage_time > 0.0:
		states["confused"] = wizard.rage_time
	if wizard.fear_time > 0.0:
		states["fleeing"] = wizard.fear_time
	var bleed := Hemorrhage.on(tree, wizard)
	if bleed != null:
		states["bleeding"] = bleed.left()
	if wizard.veil > 0:
		states["veiled"] = -1.0
	if wizard.haste_time > 0.0:
		states["hasted"] = wizard.haste_time
	if wizard.adrenaline_time > 0.0:
		states["adrenaline"] = wizard.adrenaline_time
	if wizard.infinite_time > 0.0 and wizard.infinite_time < 1.0e6:  # (the waiting room's endless stamina is no state to show)
		states["unlimited"] = wizard.infinite_time
	if wizard.air_jump_time > 0.0:
		states["extra_jump"] = wizard.air_jump_time
	if wizard.wet_time > 0.0:
		states["wet"] = wizard.wet_time
	if wizard.burning_time > 0.0:
		states["burning"] = wizard.burning_time
	if wizard.oiled_time > 0.0:
		states["oiled"] = wizard.oiled_time
	return states


## How full the clock ring of a state is: 1 just begun, 0 run out. -1 for a state with no clock.
func ring_of(name: String) -> float:
	var seconds: float = _left.get(name, -1.0)
	if seconds < 0.0:
		return -1.0
	if name == "holding":
		return clampf(seconds / 100.0, 0.0, 1.0)
	return clampf(seconds / maxf(_most.get(name, seconds), 0.001), 0.0, 1.0)


func names() -> Array[String]:
	return _active


## The node the bubbles are drawn on: a child of the wizard, in front of its body.
func layer() -> Node2D:
	_layer = BubbleLayer.new()
	_layer.bubbles = self
	_layer.z_index = 5
	_layer.visibility_layer = 4  # its own layer, which the waiting room's mirror leaves out
	return _layer


## Where the bubble that is the k-th to have begun sits: places go clockwise from the top, each the same short way along the ring from the last, and a second round lies
## outside the first. A bubble always takes the next place, so where to look never changes with how many there are.
func place_of(k: int) -> Vector2:
	var round_index := k / PER_ROUND
	var rx := WIZARD_RX + round_index * ROUND_STEP
	var ry := WIZARD_RY + round_index * ROUND_STEP
	var want := SPACING * (float(k % PER_ROUND) + 0.5 * round_index)
	var angle := 0.0
	var walked := 0.0
	var last := Vector2(0.0, -ry)
	while walked < want and angle < TAU:
		angle += 0.01
		var here := Vector2(sin(angle) * rx, -cos(angle) * ry)  # from the top, going clockwise
		walked += here.distance_to(last)
		last = here
	return MIDDLE + last


## The name of the state whose bubble is under a point on the layer, or "".
func name_at(point: Vector2) -> String:
	for k in _active.size():
		if place_of(k).distance_to(point) <= RADIUS + 2.0:
			return _active[k]
	return ""


## Draws the bubbles on the layer, and the name of the one the mouse is over.
func draw(canvas: CanvasItem) -> void:
	if _active.is_empty() or wizard.dead:
		return
	for k in _active.size():
		_draw_one(canvas, _active[k], place_of(k))
	var hovered := name_at(_layer.get_local_mouse_position())
	if hovered != "":
		var font := ThemeDB.fallback_font
		var text: String = NAMES[hovered]
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var at := _layer.get_local_mouse_position() + Vector2(10.0, -8.0)
		canvas.draw_rect(Rect2(at - Vector2(3.0, size.y - 1.0), size + Vector2(6.0, 4.0)), Color(0.05, 0.04, 0.09, 0.92))
		canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 1.0))


func _draw_one(canvas: CanvasItem, name: String, at: Vector2) -> void:
	canvas.draw_circle(at, RADIUS, Color(0.06, 0.05, 0.1, 0.8))
	var index := ORDER.find(name)
	canvas.draw_texture_rect_region(ICONS, Rect2(at - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), Rect2(index * ICON, 0.0, ICON, ICON))
	var ring := ring_of(name)
	if ring >= 0.0:
		canvas.draw_arc(at, RADIUS + 0.5, -PI * 0.5, -PI * 0.5 + TAU * ring, 24, RING_COLOR, 1.0)  # what is left of the time, from the top, clockwise
	else:
		canvas.draw_arc(at, RADIUS + 0.5, 0.0, TAU, 24, Color(RING_COLOR, 0.3), 1.0)
	if name == "veiled" and wizard.veil > 0:  # how many blows it will still turn away, in the corner of its bubble
		var font := ThemeDB.fallback_font
		var corner := at + Vector2(3.0, 9.0)
		canvas.draw_string_outline(font, corner, str(wizard.veil), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.04, 0.09))
		canvas.draw_string(font, corner, str(wizard.veil), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 1.0, 1.0))


## The layer itself: it does nothing but ask the bubbles to draw on it.
class BubbleLayer extends Node2D:
	var bubbles: StatusBubbles

	func _draw() -> void:
		bubbles.draw(self)
