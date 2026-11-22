class_name InvincibleSnail
extends CharacterBody2D

## Invincible Snail: a ring with a level line out of it, drawn over someone. A snail crawls after them, very slowly, and never stops. Whatever it touches dies at once, and
## nothing harms it. It is stopped only by the world: a wall in its way, a pit it falls into, a gap it cannot cross, or the one it hunts falling, which makes it fade away.
## It goes with its quarry from world to world (see `carry_on` and `arrive`), appearing in the exact middle of the new one.

const SPEED := 50.0  # a sixth of a wizard's walking pace (300)
const KILL_REACH := Vector2(14.0, 48.0)  # how near, across and up, the middle of a wizard must be to the snail's middle to be touched
const REACH := 70.0  # how close to the ring's middle someone must be to be the one hunted
const DANGER := 48.0
const FRAMES := [preload("res://art/mobs/snail/frame_0.png"), preload("res://art/mobs/snail/frame_1.png"), preload("res://art/mobs/snail/frame_2.png"), preload("res://art/mobs/snail/frame_3.png")]
const SLIME := Color("#9ab4a6")

var caster: Wizard
var target: Wizard  # the one it hunts
var flies := false  # in a world with no ground it drifts through the air toward them
var _sprite: AnimatedSprite2D
var _fading := false


## Whoever is under the ring: the wizard nearest its middle, if near enough (a snail hunts wizards, not creatures, and never the one who conjures it: it is
## drawn over someone else).
static func nearest_under(tree: SceneTree, point: Vector2, radius := 0.0, caster: Wizard = null) -> Wizard:
	var others := SpellTargets.wizards(tree).filter(func(w: Node) -> bool: return w != caster)
	return SpellTargets.nearest_to(others, point, maxf(REACH, radius * 1.2)) as Wizard


## Puts a snail on the ground at a place, hunting a wizard. A caster has one at a time: a new one replaces the old.
static func conjure(parent: Node, at: Vector2, hunted: Wizard, by: Wizard, quiet := false) -> InvincibleSnail:
	if by != null:
		for old: InvincibleSnail in parent.get_tree().get_nodes_in_group("snails"):
			if old.caster == by:
				old.queue_free()
	var snail := InvincibleSnail.new()
	snail.caster = by
	snail.target = hunted
	snail.flies = MatchState.plan()["biome"] == "sky"
	snail.position = at
	parent.add_child(snail)
	if not quiet:
		Sfx.cue("Invincible Snail", "summon", at, -4.0)
	Fx.burst(parent, at, SpellData.SCHOOL_COLORS["Blood"], 10, 80.0, 0.5, true)
	return snail


## What is carried on when a world gives way: each snail's quarry, by seat.
static func carry_on(world: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for snail: InvincibleSnail in world.get_tree().get_nodes_in_group("snails"):
		var seat := world.seats.find(snail.target)
		if seat >= 0 and SpellTargets.affects(snail.target):
			out.append({"seat": seat})
	return out


## In the new world of a match: every snail that was crawling arrives in the exact middle of it.
static func arrive(world: World) -> void:
	var tile := float(World.TILE)
	var column := int(ArenaGen.world_size.x * 0.5)
	var floors: PackedInt32Array = world.graph.surface["floor"]
	var sky: bool = MatchState.plan()["biome"] == "sky"
	for each: Dictionary in MatchState.snails:
		var hunted: Wizard = world.seats[each["seat"]] if each["seat"] < world.seats.size() else null
		if hunted == null or not SpellTargets.affects(hunted):
			continue
		var y := hunted.global_position.y if sky else float(floors[clampi(column, 0, floors.size() - 1)]) * tile - 24.0
		conjure(world, Vector2((column + 0.5) * tile, y), hunted, null, true)
	MatchState.snails = []


func _ready() -> void:
	add_to_group("snails")
	add_to_group("danger")
	z_index = 8
	collision_layer = 0
	collision_mask = 1 | 16
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 14.0
	shape.shape = capsule
	add_child(shape)
	var frames := SpriteFrames.new()
	frames.add_animation("crawl")
	frames.set_animation_speed("crawl", 3.0)
	for texture: Texture2D in FRAMES:
		frames.add_frame("crawl", texture)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play("crawl")
	add_child(_sprite)


## The AI wizards keep clear of it.
func danger_at(point: Vector2) -> bool:
	return point.distance_to(global_position) < DANGER


func _physics_process(delta: float) -> void:
	if _fading:
		return
	if not is_instance_valid(target) or not SpellTargets.affects(target):
		_vanish()
		return
	var goal := SpellTargets.center_of(target)
	var toward := signf(goal.x - global_position.x)
	if toward != 0.0:
		_sprite.flip_h = toward < 0.0  # the picture faces right
	if flies:
		velocity = (goal - global_position).limit_length(SPEED)
	else:
		velocity.x = toward * SPEED if absf(goal.x - global_position.x) > 4.0 else 0.0
		velocity.y += float(ProjectSettings.get_setting("physics/2d/default_gravity")) * delta
	move_and_slide()
	for wizard: Wizard in SpellTargets.wizards(get_tree()):  # a touch is the end of anyone, whoever conjured it too; only a veil that is still up negates it, for a moment
		var gap := SpellTargets.center_of(wizard) - global_position
		if absf(gap.x) < KILL_REACH.x and absf(gap.y) < KILL_REACH.y:
			wizard.take_damage(99999, true)


## It loses the one it was after (they have washed it away) and fades.
func lose_scent() -> void:
	if not _fading:
		_vanish()


func _vanish() -> void:
	_fading = true
	Fx.burst(get_parent(), global_position, SLIME, 8, 60.0, 0.5, false)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.6)
	fade.tween_callback(queue_free)
