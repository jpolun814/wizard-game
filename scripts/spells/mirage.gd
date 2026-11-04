class_name Mirage
extends PagePickup

## Mirage: a page that is not there. It floats and glows like the real thing, in the colour of some school, and wavers faintly. Every wizard
## believes it is one they have not read. It fades the moment anyone comes near (the one who made it too) and leaves nothing behind. A wizard
## run by a brain that has watched one fade learns to see the waver, and stops going for them.

const NEAR := 96.0          # how close anyone must come for it to fade: right up to it
const WITNESS := 700.0      # a brain this close when one fades learns from it
const FADE := 1.4           # seconds it takes to go, shimmering
const APPEAR := 1.5         # seconds it takes to come, shimmering

enum {COMING, STEADY, GOING, HIDDEN, ENDING}

const LIFE := 30.0          # seconds before it shimmers away for good

var _state := COMING
var _vis := 0.0             # how much of it is there, 0 to 1
var _age := 0.0
var _fading := false        # not there to be had: going, gone from sight, or ending


## What the spell makes: a mirage of a page of some spell, floating over the ground at a point.
static func conjure(parent: Node, feet: Vector2) -> Mirage:
	var mirage := Mirage.new()
	var names: Array = SpellData.SPELLS.keys()
	mirage.page = names[randi() % names.size()]  # the dice are the same on every machine of a match, so it looks the same on each
	mirage.position = feet
	parent.add_child(mirage)
	return mirage


## Wanted by everyone, whatever they hold.
func gives(_ledger: Ledger) -> bool:
	return not _fading


func new_pages(_ledger: Ledger) -> Array[String]:
	return [] if _fading else [page]


## There is nothing to read: whoever reaches it finds it gone.
func take(_ledger: Ledger) -> String:
	_fade()
	return ""


## True once it has shimmered in and stands steady.
func is_solid() -> bool:
	return _state == STEADY


func _someone_near() -> bool:
	var heart := global_position + Vector2(0.0, -FLOAT)
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		if SpellTargets.center_of(wizard).distance_to(heart) < NEAR:
			return true
	return false


## It shimmers in and then stands steady. Someone coming near makes it shimmer out; when they have left it shimmers back in. After LIFE seconds it shimmers out for good.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_age += delta
	var near := _someone_near()
	if _age >= LIFE and _state != ENDING:
		_state = ENDING
		_fading = true
		remove_from_group("pages")
	match _state:
		COMING:
			_vis += delta / APPEAR
			if near:
				_fade()
			elif _vis >= 1.0:
				_vis = 1.0
				_state = STEADY
		STEADY:
			if near:
				_fade()
		GOING:
			_vis -= delta / FADE
			if _vis <= 0.0:
				_vis = 0.0
				_state = HIDDEN
		HIDDEN:
			if not near:
				_state = COMING
				_fading = false
				add_to_group("pages")
		ENDING:
			_vis -= delta / FADE
			if _vis <= 0.0:
				queue_free()
	# Only while it comes or goes does it ripple; steady, it simply stands there.
	modulate.a = 0.85 if _state == STEADY else clampf(_vis, 0.0, 1.0) * (0.6 + 0.25 * sin(_t * 9.0))


## It goes: brains that were watching take note.
func _fade() -> void:
	if _fading:
		return
	_fading = true
	_state = GOING
	var heart := global_position + Vector2(0.0, -FLOAT)
	Fx.burst(get_parent(), heart, _color, 12, 90.0, 0.6, true)
	Fx.smoke(get_parent(), heart, Color(0.3, 0.2, 0.4, 0.5), 3, 20.0)
	Sfx.play("glass", heart, -10.0)
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		if wizard.brain != null and SpellTargets.center_of(wizard).distance_to(heart) < WITNESS:
			wizard.brain.saw_a_mirage_fade()
	remove_from_group("pages")
