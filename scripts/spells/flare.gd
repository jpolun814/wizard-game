class_name Flare
extends Node2D

## Flare: a small harmless flame that hovers in front of the caster, where they face, and follows them, lighting the dark until you die or cast another.
## It cuts through an eclipse, and burns nothing: it is a light, not a fire.

const LIGHT_RADIUS := 380.0
const FOLLOW := 16.0  # how quickly it catches up with the caster: quick enough to keep in front at a run
const GRAB := 40.0  # how near a click or a gust has to be to reach it

var caster: Wizard  # set by the arena before the flare enters the tree
## A flare nobody sees: the light of the Chant of Darkvision, which lights the dark for its speaker as a flare would, with no flame to hold. Nothing puts it out.
var unseen := false
var _age := 0.0
var _flame: AnimatedSprite2D
var _sight_light: PointLight2D


func _ready() -> void:
	for other in get_tree().get_nodes_in_group("flares"):
		if other != self and other.caster == caster and other.unseen == unseen:
			other.queue_free()  # one flare each (and one darkvision): a new one replaces the old
	add_to_group("flares")
	add_to_group("lasting")
	z_index = 4
	global_position = _rest_spot()
	if not unseen:
		_flame = PixelFx.sprite("fire_puff", 12.0, true, 1)
		_flame.offset = Vector2(0, -PixelArt.FX["fire_puff"]["size"].y * 0.5)
		_flame.scale = Vector2.ONE * 0.8
		add_child(_flame)
	# In a dark place the flare is a real light. Elsewhere only its glow shows. Darkvision lights only its speaker's own screen, and shows no light of its own.
	if get_tree().get_first_node_in_group("darkness") != null and (not unseen or (is_instance_valid(caster) and caster.brain == null)):
		var light := PointLight2D.new()
		Fx.lamp(light)
		light.texture_scale = LIGHT_RADIUS * 2.0 / Fx.TEX_SIZE
		light.color = Color(1.0, 0.7, 0.4)
		light.energy = 1.3
		if unseen:  # sight is not a glow (owner: "I just want to see in the dark normally"): a flat white light that brings the dark back to just its normal brightness, with no bright heart and no tint
			light.texture = _sight_texture()
			light.texture_scale = LIGHT_RADIUS * 2.0 / float(SIGHT_TEXTURE)
			light.color = Color.WHITE
			_sight_light = light
			_match_dark()
		light.shadow_enabled = false
		add_child(light)
	if not unseen:
		Sfx.cue("Flare", "fire", global_position, -8.0)
		Fx.burst(get_parent(), global_position, Color("#ff9a40"), 6, 60.0, 0.4, true)


const SIGHT_TEXTURE := 256
const SIGHT_FLAT := 0.7  # the share of the radius that is lit evenly, before the edge fades
static var _sight: Texture2D


## The light of sight: the same brightness across most of its radius, fading only at the edge, so what it shows looks as it would in daylight and the wizard does not shine.
static func _sight_texture() -> Texture2D:
	if _sight == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, SIGHT_FLAT, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = SIGHT_TEXTURE
		texture.height = SIGHT_TEXTURE
		_sight = texture
	return _sight


## The light of sight is exactly what the dark takes away, so it brings the world back to normal brightness (the dark's color changes with depth, so this is kept up).
func _match_dark() -> void:
	var dark := get_tree().get_first_node_in_group("darkness") as CanvasModulate
	var shade: Color = dark.color if dark != null else Color.BLACK
	_sight_light.color = Color(1.0 - shade.r, 1.0 - shade.g, 1.0 - shade.b)  # exactly what the dark takes away, in each color, so what it lights looks as it does by day
	_sight_light.energy = 1.0


## In front of the caster, where they face, bobbing a little.
func _rest_spot() -> Vector2:
	if not is_instance_valid(caster):
		return global_position
	if unseen:
		return SpellTargets.center_of(caster)
	var bob := sin(_age * 3.0) * 4.0
	var lead: float = caster.velocity.x * 0.12  # a little ahead of a runner, so it is not left behind
	return SpellTargets.center_of(caster) + Vector2(34.0 * caster.facing + lead, -30.0 + bob)


func _physics_process(delta: float) -> void:
	_age += delta
	if _sight_light != null:
		_match_dark()
	global_position = global_position.lerp(_rest_spot(), clampf(FOLLOW * delta, 0.0, 1.0))
	if not unseen:
		queue_redraw()
	if is_instance_valid(caster) and caster.dead:
		queue_free()


## The light it throws, a soft glow in the air round the flame.
func _draw() -> void:
	if unseen:
		return  # (a canvas item is drawn once whether or not it asks: nothing may be drawn for a light nobody sees)
	var flicker := 1.0 + 0.08 * sin(_age * 17.0)
	Fx.draw_glow(self, Vector2(0, -14), LIGHT_RADIUS * 0.4 * flicker, Color(1.0, 0.55, 0.2, 0.22))


## Puts the flame out, as anything is put out.
func snuff() -> void:
	if not unseen:
		Elements.put_out(self, global_position)


## False for the unseen light a chant gives: it is no flame, so nothing puts it out and nothing hisses.
func is_flame() -> bool:
	return not unseen


## It goes out (Elements: water puts it out, whatever the water is; wind does by `snuff`).
func quench() -> void:
	if not unseen:
		queue_free()


## Snuffs every flare within reach of a point. True if any went out.
static func snuff_near(tree: SceneTree, point: Vector2, reach: float) -> bool:
	var out := false
	for flare: Flare in tree.get_nodes_in_group("flares"):
		if flare.global_position.distance_to(point) <= reach + GRAB:
			flare.snuff()
			out = true
	return out
