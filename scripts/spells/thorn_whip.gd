class_name ThornWhip
extends SpellEffect

## Thorn Whip: a long lash of thorny vine that hits the first thing along the drawn line and drags it toward the caster. It drags a wizard or an
## enemy, and a loose page. Heavy things (a giant, anything in a block of ice) resist it. A flame along the way burns the whip to its end there, and
## solid ground or a stone wall stops it. It is not a shot, so a Barrier does not turn it.

const REACH := 380.0
const REACH_SHORT := 60.0     # it lets go this far short of the one it holds: close enough to be struck, not to stand inside
const COAST := 1000.0         # how fast a dragged body slows once let go, in pixels a second each second (about what a wizard and an enemy do)
const PAGE_HALF_WIDTH := 32.0 # half the width a page takes up, and how far over its floating height
const LASH := 0.12            # seconds the whip takes to reach its end
const HOLD := 0.7             # the longest it drags for
const DRAG := 2600.0          # the pull on a wizard or an enemy, in pixels a second each second
const PAGE_SPEED := 420.0     # how fast a page is dragged
const LINK := 50.0            # each piece of vine is this long
const VINE := preload("res://art/props/dusk_vine.png")
const BURN_REACH := 20.0
const HARM := 8               # the thorns bite whoever the lash takes hold of

var _from := Vector2.ZERO
var _dir := Vector2.RIGHT
var _length := 0.0            # how far the whip reaches in all
var _held: Node2D             # what it has hold of, if anything
var _last_at := Vector2.ZERO  # where the held body was a frame ago, to know how fast it is being dragged
var _holds_page := false
var _burnt := false
var _bitten := false


func _begin(origin: Vector2, aim_angle: float) -> void:
	_dir = Vector2.from_angle(aim_angle)
	_from = caster.center() if caster != null and caster.has_method("center") else origin
	global_position = _from
	_life = HOLD
	Sfx.play("push", _from, -6.0)
	var reach := _first_thing()
	_length = reach["length"]
	var hit: Node2D = reach["thing"]
	if _flame_along(_length):
		return
	if hit != null:
		_grab(hit)


## What the whip meets first along its line: {"length", "thing"}. Ground and walls end it; a wizard, an enemy or a page along the way is held.
func _first_thing() -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(_from, _from + _dir * REACH)
	query.collision_mask = 1 | 2 | 4
	if caster is CollisionObject2D:
		query.exclude = [(caster as CollisionObject2D).get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var length := REACH
	var thing: Node2D = null
	if not hit.is_empty():
		length = _from.distance_to(hit["position"])
		var body: Node = hit["collider"]
		if body is Node2D and SpellTargets.affects(body):
			thing = body
	# A page along the way is taken if nothing is nearer. A page fills the space from the floor up past where it floats.
	for page: Node2D in get_tree().get_nodes_in_group("pages"):
		var space := Rect2(page.global_position + Vector2(-PAGE_HALF_WIDTH, -PagePickup.FLOAT - PAGE_HALF_WIDTH), Vector2(PAGE_HALF_WIDTH * 2.0, PagePickup.FLOAT + PAGE_HALF_WIDTH + 8.0))
		var along := 20.0
		while along < length:
			if space.has_point(_from + _dir * along):
				length = along
				thing = page
				break
			along += 8.0
	return {"length": length, "thing": thing}


## True when a flame lies on the whip's line: it burns away to there, and takes hold of nothing.
func _flame_along(length: float) -> bool:
	for fire: Dictionary in SpellTargets.fire_points(get_tree()):
		var at: Vector2 = fire["at"]
		var along := (at - _from).dot(_dir)
		if along < 0.0 or along > length:
			continue
		if absf((at - _from).cross(_dir)) < BURN_REACH + maxf(float(fire["size"]), 0.0):
			_length = along
			_burnt = true
			Fx.burst(get_parent(), _from + _dir * along, Color("#ff9a40"), 8, 80.0, 0.4, true)
			_life = LASH + 0.25
			return true
	return false


func _grab(thing: Node2D) -> void:
	_holds_page = thing.is_in_group("pages")
	if not _holds_page and thing.is_in_group("mobs"):
		if thing.is_frozen() or thing.KINDS[thing.kind].effect == "smash":
			FloatText.spawn(get_parent(), SpellTargets.center_of(thing) + Vector2(0, -30), "Too heavy", Color(0.85, 0.9, 0.7), 0.8)
			_length = _from.distance_to(SpellTargets.center_of(thing))
			return  # a giant, or a block of ice, is not moved
	_held = thing


func _act(delta: float) -> void:
	if _held == null or not is_instance_valid(_held) or _burnt:
		return
	if _age < LASH:
		return  # the lash has not reached it yet
	if not _bitten and not _holds_page:
		_bitten = true
		SpellTargets.hurt(_held, HARM, "Flora", false, false, self)
		Fx.burst(get_parent(), SpellTargets.center_of(_held), Color("#8fd35a"), 6, 70.0, 0.3, false)
	var home: Vector2 = caster.global_position + Vector2(0.0, -20.0) if caster != null and is_instance_valid(caster) else _from
	if _holds_page:
		var to_home := home - _held.global_position
		if to_home.length() < 40.0:
			_held = null
			_life = _age + 0.15
			return
		_held.global_position += to_home.normalized() * minf(PAGE_SPEED * delta, to_home.length())
		_length = _from.distance_to(_held.global_position)
		return
	var at := SpellTargets.center_of(_held)
	var to_me := home - at
	var speed := at.distance_to(_last_at) / maxf(delta, 0.001) if _last_at != Vector2.ZERO else 0.0
	_last_at = at
	# It lets go early enough that the body, still moving, comes to rest short of the caster.
	if to_me.length() < REACH_SHORT + speed * speed / (2.0 * COAST):
		_held = null
		_life = _age + 0.15
		return
	_held.pull(to_me.normalized() * DRAG, delta)
	_length = _from.distance_to(at)
	_dir = (at - _from).normalized()


func _draw() -> void:
	var shown := _length * clampf(_age / LASH, 0.0, 1.0)
	var fade := clampf((_life - _age) / 0.2, 0.0, 1.0)
	var count := maxi(1, ceili(shown / LINK))
	var local_dir := to_local(_from + _dir) - to_local(_from)
	for i in count:
		var piece_at := local_dir * (i * LINK + LINK * 0.5)
		if (i * LINK) > shown:
			break
		draw_set_transform(piece_at, local_dir.angle(), Vector2(1.0, -1.0 if i % 2 == 1 else 1.0))
		draw_texture(VINE, -VINE.get_size() * 0.5, Color(0.72, 0.95, 0.55, fade))
	draw_set_transform(Vector2.ZERO)
