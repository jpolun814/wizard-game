class_name OilSlick
extends Node2D

## Oil Slick: a drop and a line drawn along the ground. A pool of oil spreads where the line was: whoever crosses it slips (cannot stop or turn quickly, as on ice) and is left oiled. It does no harm, until
## a fire touches it: then the whole slick goes up at once, in patches of burning ground, and whoever is in it burns (and an oiled wizard burns twice as long).
## Water (a Water Jet) washes it away.

const LIFE := 60.0
const MIN_WIDTH := 70.0
const MAX_WIDTH := 300.0
const DEPTH := 18.0      # how far above the surface feet can be and still be in it
const SAMPLES := 17
const SINK_DEPTH := 8.0  # how thick the pool is drawn
const SAND := preload("res://art/props/quicksand.png")
const PATCH := 40.0      # the width of each burning patch of ground when it goes up
const BURN_LIFE := 4.5   # how long the ground burns

var width := 140.0
var caster: Wizard
var _age := 0.0
var _left := 0.0   # where the pool begins and ends, across it (it stops at a wall and at the edge of a drop, and does not hang past them)
var _right := 0.0
var _surface := PackedFloat32Array()  # the ground's height under the pool, sampled across it, relative to its middle
var _lit := false


func _ready() -> void:
	width = clampf(width, MIN_WIDTH, MAX_WIDTH)
	global_position = SpellTargets.surface_over(get_world_2d(), global_position)
	_lay_on_ground()
	add_to_group("lasting")
	add_to_group("oil_slicks")
	z_index = 1
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	Sfx.cue("Oil Slick", "mud", global_position, -6.0)
	Fx.burst(get_parent(), global_position, Color(0.1, 0.08, 0.12, 0.9), 8, 90.0, 0.5, false)


## Reads the ground the pool lies on and trims the pool to the part of it that is ground: see SpellTargets.ground_run.
func _lay_on_ground() -> void:
	var run := SpellTargets.ground_run(get_world_2d(), global_position, width, SAMPLES)
	var first := SAMPLES / 2
	var last := SAMPLES / 2
	for i in SAMPLES:
		if not is_nan(run[i]):
			first = mini(first, i)
			last = maxi(last, i)
	_surface.resize(SAMPLES)
	for i in SAMPLES:
		_surface[i] = run[clampi(i, first, last)]  # what lies past either end is the end's height, so the pool's edge is level
	_left = lerpf(-width * 0.5, width * 0.5, float(first) / (SAMPLES - 1))
	_right = lerpf(-width * 0.5, width * 0.5, float(last) / (SAMPLES - 1))
	if _right - _left < 24.0:  # nowhere to lie: a small patch where it was cast
		_left = -12.0
		_right = 12.0


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if SpellTargets.fire_touching(get_tree(), Rect2(global_position + Vector2(_left, -DEPTH * 2.0 + _surface_at(0.0)), Vector2(_right - _left, DEPTH * 3.0))):
		_go_up()
		return
	for body in SpellTargets.all(get_tree()):
		if not _caught(body):
			continue
		if body is Wizard:
			body.coat.oil()  # (and it is slippery under foot: see OilSlick.under)
	if _age >= LIFE:
		queue_free()


## True for anyone standing in the slick.
func _caught(body: Node2D) -> bool:
	var feet := body.global_position
	var local_x := feet.x - global_position.x
	if local_x < _left or local_x > _right:
		return false
	var surface := global_position.y + _surface_at(local_x)
	return feet.y >= surface - DEPTH and feet.y <= surface + 6.0


func _surface_at(local_x: float) -> float:
	var t := clampf((local_x + width * 0.5) / width, 0.0, 1.0) * (SAMPLES - 1)
	var i := mini(int(t), SAMPLES - 2)
	return lerpf(_surface[i], _surface[i + 1], t - i)


## A fire has touched it: the whole slick burns at once, and whoever is in it is set alight.
func _go_up() -> void:
	if _lit:
		return
	_lit = true
	Sfx.cue("Oil Slick", "fire", global_position, -2.0)
	var count := maxi(2, int(ceilf(width / PATCH)))
	for k in count:
		var x := lerpf(-width * 0.5 + PATCH * 0.5, width * 0.5 - PATCH * 0.5, float(k) / maxf(count - 1, 1))
		Hazard.place(get_parent(), global_position + Vector2(x, _surface_at(x)), PATCH + 6.0, BURN_LIFE)
	for body in SpellTargets.all(get_tree()):
		if _caught(body) and body is Wizard:
			body.coat.ignite(Coating.BURN_SECONDS, caster)
	queue_free()


## True when a point is on any slick of oil: over it, and at the height of the ground it lies on (not on a floor above it or below it).
static func under(tree: SceneTree, point: Vector2) -> bool:
	for slick: OilSlick in tree.get_nodes_in_group("oil_slicks"):
		var local_x := point.x - slick.global_position.x
		if local_x >= slick._left and local_x <= slick._right and absf(point.y - (slick.global_position.y + slick._surface_at(local_x))) < DEPTH:
			return true
	return false


## Water washes oil away: any slick the stream reaches is gone.
static func wash(tree: SceneTree, point: Vector2, reach: float) -> void:
	for slick: OilSlick in tree.get_nodes_in_group("oil_slicks"):
		if absf(point.x - slick.global_position.x) < slick.width * 0.5 + reach and absf(point.y - slick.global_position.y) < 60.0 + reach:
			Fx.burst(slick.get_parent(), slick.global_position, Color(0.5, 0.5, 0.55, 0.7), 8, 80.0, 0.5, false)
			slick.queue_free()


## The pool: the quicksand's art made black, drawn as a band that follows the ground, with a pale sheen along its top.
func _draw() -> void:
	if _surface.is_empty():
		return
	var grow := clampf(_age / 0.4, 0.0, 1.0)
	var fade := clampf((LIFE - _age) / 1.0, 0.0, 1.0)
	var scroll := fmod(_age * 2.0, SAND.get_width())
	var top := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in SAMPLES:
		var x := lerpf(_left * grow, _right * grow, float(i) / (SAMPLES - 1))
		top.append(Vector2(x, _surface_at(x) - 1.0))
		uvs.append(Vector2((x + scroll) / SAND.get_width(), 0.0))
	var bottom := PackedVector2Array()
	var bottom_uvs := PackedVector2Array()
	for i in range(SAMPLES - 1, -1, -1):
		bottom.append(top[i] + Vector2(0, SINK_DEPTH))
		bottom_uvs.append(Vector2(uvs[i].x, minf(SINK_DEPTH, SAND.get_height()) / SAND.get_height()))
	var shade := PackedColorArray()
	for i in SAMPLES * 2:
		shade.append(Color(0.1, 0.09, 0.13, 0.95 * fade))
	draw_polygon(top + bottom, shade, uvs + bottom_uvs, SAND)
	for i in SAMPLES - 1:
		draw_line(top[i] + Vector2(0, 1.0), top[i + 1] + Vector2(0, 1.0), Color(0.55, 0.5, 0.75, 0.55 * fade), 1.0)  # the sheen
