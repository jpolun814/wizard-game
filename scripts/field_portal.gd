class_name FieldPortal
extends Portal

## One of the portal world's portals. It tells the field when someone steps in. It opens the way the sheet's closing frames run backwards, and
## closes with them over its last moments.

signal entered(portal: FieldPortal, body: Node2D)

const CLOSE_SECONDS := 8.0 / 12.0  # the closing frames, at twelve a second

var tint := Color.WHITE
var lifetime := 30.0
var age := 0.0  # seconds since it opened: the field sets it each frame
var _closing := false


func _ready() -> void:
	super()
	collision_mask = 6  # the player and the foes
	_ring.modulate = ring_colour(tint)
	body_entered.connect(func(body: Node2D) -> void: entered.emit(self, body))
	add_to_group("field_portals")


## It opens from nothing, unless it was already open when this machine first saw it.
func open() -> void:
	_ring.play("appearing" if age < 0.5 else "open")


func _process(delta: float) -> void:
	super(delta)
	if not _closing and age >= lifetime - CLOSE_SECONDS:
		_closing = true
		_ring.play("closing")


## True once it has begun to close, so nobody is sent to come out of it.
func is_closing() -> bool:
	return _closing


## Seconds it has left open.
func remaining() -> float:
	return lifetime - age


## The ring's picture is violet, so a colour laid over it is evened out first: green would otherwise come out brown, and red the same as orange.
static func ring_colour(wanted: Color) -> Color:
	return Color(wanted.r / 0.55, wanted.g / 0.4, wanted.b / 0.85) * 0.9
