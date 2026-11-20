class_name Elements
extends Node

## The laws of the world, in one place, so that a thing does what it does because of WHAT it is and never because of which spell it came from.
## Water puts fire out, wherever the water came from (a pond, a jet, a geyser, a snowstorm, a wave, a splash of ice) and whatever the fire is (a fireball,
## a wall of flame, a breath, a rolling sphere, a bonfire, burning ground, a flare).
##
## How a thing takes part:
##   water   joins the group "waters" and answers `wets(point) -> bool`: is there water at this point now?
##   fire    joins the group "fires" and answers `quench()` (it goes out); a shot of fire has no `quench` and is simply ended.
##           `flame_points() -> PackedVector2Array` says where its flames are (the node's own position when it has none).
## The laws are worked here and only here (this node runs in every world), and what a person sees and hears of one (the steam, the hiss) is the same
## whoever is the cause. A spell that makes water makes it a source of water: it does not go looking for fires. One that happens at a single moment
## (a splash of ice, an eruption) calls `splash`.
## (The coating of a wizard's body is the same kind of law: `Coating`, `Wizard.wet_time`, `oiled_time`: the state decides, never the spell that gave it.)


func _physics_process(_delta: float) -> void:
	var tree := get_tree()
	_blow(tree)
	var sources := tree.get_nodes_in_group("waters")
	if sources.is_empty():
		return
	for fire: Node2D in burning(tree):
		for point in points_of(fire):
			if _wet(sources, point):
				put_out(fire, point)
				break
	for slick: OilSlick in tree.get_nodes_in_group("oil_slicks"):  # water washes oil away
		for point in slick.lies_at():
			if _wet(sources, point):
				slick.wash_away()
				break


## True when something that puts fire out is at this point: any source of water.
static func wet_at(tree: SceneTree, point: Vector2) -> bool:
	return _wet(tree.get_nodes_in_group("waters"), point)


## Moving air (the group "winds", each answering `blows_at(point)`) thins every cloud it passes through away (smoke, snow, spores, a storm: anything that
## answers `dissipate()`, and `extent()` (its rectangle) or `span()`) and puts a flare out.
func _blow(tree: SceneTree) -> void:
	var winds := tree.get_nodes_in_group("winds")
	if winds.is_empty():
		return
	for cloud: Node2D in tree.get_nodes_in_group("clouds"):
		if not is_instance_valid(cloud) or not cloud.has_method("dissipate"):
			continue
		if _cloud_blown(winds, cloud):
			cloud.dissipate()
	for flare: Node2D in tree.get_nodes_in_group("flares"):
		if is_instance_valid(flare) and _blown(winds, flare.global_position):
			put_out(flare, flare.global_position)


## Whether any wind blows at any part of a cloud. A cloud says where it is with `extent()` (a rectangle in the world); one that does not is taken to lie along
## its `span()` at the height of its own node.
static func _cloud_blown(winds: Array, cloud: Node2D) -> bool:
	var area := Rect2(cloud.global_position, Vector2.ZERO)
	if cloud.has_method("extent"):
		area = cloud.extent()
	elif cloud.has_method("span"):
		var edges: Vector2 = cloud.span()
		area = Rect2(edges.x, cloud.global_position.y, edges.y - edges.x, 0.0)
	var y := area.position.y
	while y <= area.end.y + 0.01:
		var x := area.position.x
		while x <= area.end.x + 40.0:
			if _blown(winds, Vector2(minf(x, area.end.x), y)):
				return true
			x += 40.0
		y += 40.0
		if area.size.y == 0.0:
			break
	return false


static func _blown(winds: Array, point: Vector2) -> bool:
	for wind: Node in winds:
		if is_instance_valid(wind) and wind.has_method("blows_at") and wind.blows_at(point):
			return true
	return false


## True when water that soaks a body is at this point: any liquid water. (Snow puts out a fire but does not soak a body: a source says so with `soaks`.)
static func soaked_at(tree: SceneTree, point: Vector2) -> bool:
	for source: Node in tree.get_nodes_in_group("waters"):
		if is_instance_valid(source) and source.wets(point) and (not source.has_method("soaks") or source.soaks()):
			return true
	return false


static func _wet(sources: Array, point: Vector2) -> bool:
	for source: Node in sources:
		if is_instance_valid(source) and source.wets(point):
			return true
	return false


## A burst of water or cold at one moment (ice shattering, an eruption): every fire with a flame within `radius` goes out. True if any did.
static func splash(tree: SceneTree, at: Vector2, radius: float) -> bool:
	var out := false
	for fire: Node2D in burning(tree):
		for point in points_of(fire):
			if point.distance_to(at) < radius:
				put_out(fire, point)
				out = true
				break
	return out


## Every flame in the world that can be put out: fires, and the small flames of flares (which light nothing, so they are not "fires").
static func burning(tree: SceneTree) -> Array[Node2D]:
	var all: Array[Node2D] = []
	for group in ["fires", "flares"]:
		for node: Node in tree.get_nodes_in_group(group):
			if is_instance_valid(node) and node is Node2D and can_go_out(node):
				all.append(node)
	return all


## A Barrier turns away every shot that meets it, whatever the shot is (anything in the group "shots"). The shot says how it is turned: it can `reflect(heading)`
## (sent off in a random direction) or be `deflected()` (stopped dead). True when the body had a shield and the shot was dealt with.
static func shield_turns(shot: Node, body: Node) -> bool:
	if not (body.is_in_group("wizards") and body.has_shield()):
		return false
	if shot.has_method("reflect"):
		shot.reflect(Vector2.from_angle(randf() * TAU))
	elif shot.has_method("deflected"):
		shot.deflected()
	else:
		shot.queue_free()
	return true


## Whether a fire can be put out at all: it knows how to go out, or it is a shot, which is simply ended.
static func can_go_out(fire: Node) -> bool:
	return fire.has_method("quench") or fire.is_in_group("shots")


static func points_of(fire: Node2D) -> PackedVector2Array:
	if fire.has_method("flame_points"):
		return fire.flame_points()
	return PackedVector2Array([fire.global_position])


## Puts a fire out where its flame is: the same steam and the same hiss whatever did it.
static func put_out(fire: Node2D, at: Vector2) -> void:
	Fx.smoke(fire.get_parent(), at, Color(0.88, 0.92, 0.96, 0.7), 5, 22.0, 50.0)
	Sfx.cue("quench", "steam", at)
	if fire.has_method("quench"):
		fire.quench()
	elif fire is SpellEffect:
		fire.end()
	else:
		fire.queue_free()
