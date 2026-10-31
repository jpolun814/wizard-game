class_name CaveLife
extends Node2D

## What lives in the great cavern of the underground world: crystals growing out of the ground that glow and light the dark round them,
## water dripping from the roof, stalactites that shake loose and fall on whoever walks under them (and grow back), and now and then a
## cave-in, where the roof rumbles and sheds a heap of rock over a stretch of the floor. Where the roof is comes from the same rule the
## world's builder used (WorldBuilder.ROOF_AIR); the cave-ins follow the world's age.

const CRYSTALS := ["res://art/props/crystal_1.png", "res://art/props/crystal_2.png", "res://art/props/crystal_3.png"]
const STALACTITES_EVERY := 11   # columns of the cavern between one stalactite and the next, about
const SHAKE := 0.9             # seconds a stalactite trembles before it lets go
const REGROW := 28.0           # seconds before it is back
const TRIGGER_WIDTH := 44.0    # how near across a wizard must walk under it
const CAVE_IN_PERIOD := 50.0
const CAVE_IN_FIRST := 30.0
const CAVE_IN_WARNING := 2.6
const CAVE_IN_ROCKS := 9
const CAVE_IN_SPREAD := 190.0

var floors := PackedInt32Array()  # the first solid row of each column, over the whole world
var first_column := 0             # the column the first of those is (the whole world, so 0)
var seed_value := 0
var seconds := 0.0                # the world's age: the world sets it each frame
var player: Node2D

var _hangers: Array[Dictionary] = []  # {"sprite", "state": "hanging" | "shaking" | "gone", "wait", "home"}
var _slot := -1
var _spot := 0.0
var _dust := 0.0


## The y of the roof over a column, in pixels: where the rock's lower face is.
func roof_y(column: int) -> float:
	return (floors[clampi(column - first_column, 0, floors.size() - 1)] - WorldBuilder.ROOF_AIR - roundi(5.0 * sin(column / 17.0))) * float(ArenaGen.TILE)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tile := float(ArenaGen.TILE)
	var column := first_column + 8
	var last := first_column + floors.size() - 8
	while column < last:
		var x := (column + 0.5) * tile
		var ground := float(floors[column - first_column]) * tile
		var crystal := Sprite2D.new()
		crystal.texture = load(CRYSTALS[rng.randi() % CRYSTALS.size()])
		crystal.scale = Vector2(3.0, 3.0)
		crystal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crystal.offset = Vector2(0.0, -crystal.texture.get_height() * 0.5 + 2.0)
		crystal.flip_h = rng.randf() < 0.5
		crystal.position = Vector2(x, ground + 2.0)
		crystal.z_index = -1
		add_child(crystal)
		var light := PointLight2D.new()
		light.texture = Fx.tex("light_01")
		light.texture_scale = 300.0 / Fx.TEX_SIZE
		light.color = Color(0.45, 0.85, 1.0)
		light.energy = 0.9
		light.position = Vector2(x, ground - 24.0)
		light.shadow_enabled = false
		add_child(light)
		column += rng.randi_range(14, 28)
	column = first_column + 8
	while column < last:
		var x := (column + 0.5) * tile
		var top := roof_y(column)
		var hanging := Sprite2D.new()
		hanging.texture = load("res://art/props/rock_spike_%d.png" % rng.randi_range(1, 3))
		hanging.flip_v = true
		hanging.scale = Vector2(2.0, 2.0)
		hanging.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hanging.offset = Vector2(0.0, hanging.texture.get_height() * 0.5 - 4.0)
		hanging.position = Vector2(x, top)
		hanging.modulate = Color(0.62, 0.58, 0.7)
		hanging.z_index = 1
		add_child(hanging)
		_hangers.append({"sprite": hanging, "state": "hanging", "wait": 0.0, "home": hanging.position})
		if rng.randf() < 0.5:
			var drip := CPUParticles2D.new()  # water gathers at its tip and drops
			drip.position = Vector2(x, top + 16.0)
			drip.amount = 1
			drip.lifetime = 1.6
			drip.explosiveness = 0.0
			drip.direction = Vector2(0, 1)
			drip.spread = 0.0
			drip.initial_velocity_min = 0.0
			drip.initial_velocity_max = 0.0
			drip.gravity = Vector2(0, 700)
			drip.texture = Fx.tex("circle_05")
			drip.scale_amount_min = 3.0 / Fx.TEX_SIZE
			drip.scale_amount_max = 3.0 / Fx.TEX_SIZE
			drip.color = Color(0.7, 0.85, 1.0, 0.8)
			drip.local_coords = false
			drip.preprocess = rng.randf() * 1.6
			add_child(drip)
		column += maxi(4, STALACTITES_EVERY + rng.randi_range(-5, 5))


func _physics_process(delta: float) -> void:
	_watch_stalactites(delta)
	_cave_in(delta)


func _watch_stalactites(delta: float) -> void:
	var wizards := SpellTargets.wizards(get_tree())
	for hanger in _hangers:
		var sprite: Sprite2D = hanger["sprite"]
		match hanger["state"]:
			"hanging":
				for wizard: Node2D in wizards:
					var below := wizard.global_position - sprite.position
					if absf(below.x) < TRIGGER_WIDTH and below.y > 0.0 and below.y < 900.0:
						hanger["state"] = "shaking"
						hanger["wait"] = SHAKE
						break
			"shaking":
				hanger["wait"] -= delta
				sprite.position = hanger["home"] + Vector2(randf_range(-2.0, 2.0), 0.0)
				if hanger["wait"] <= 0.0:
					hanger["state"] = "gone"
					hanger["wait"] = REGROW
					sprite.visible = false
					var rock := FallingRock.new()
					rock.position = hanger["home"] + Vector2(0.0, 20.0)  # (set before it is added: it looks for the ground below when it arrives)
					get_parent().add_child(rock)
			"gone":
				hanger["wait"] -= delta
				if hanger["wait"] <= 0.0:
					hanger["state"] = "hanging"
					sprite.position = hanger["home"]
					sprite.visible = true


## The roof gives way over a stretch near the player this machine plays: it rumbles and sheds dust, and then the rocks come down.
func _cave_in(delta: float) -> void:
	if seconds < CAVE_IN_FIRST or player == null:
		return
	var slot := int((seconds - CAVE_IN_FIRST) / CAVE_IN_PERIOD)
	var into := seconds - CAVE_IN_FIRST - slot * CAVE_IN_PERIOD
	if slot != _slot:
		_slot = slot
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + slot * 7717
		_spot = player.global_position.x + rng.randf_range(-420.0, 420.0)
		_rocks_left = CAVE_IN_ROCKS
	var column := int(_spot / float(ArenaGen.TILE))
	if into < CAVE_IN_WARNING:
		_dust -= delta
		if _dust <= 0.0:
			_dust = 0.2
			Fx.smoke(get_parent(), Vector2(_spot + randf_range(-CAVE_IN_SPREAD, CAVE_IN_SPREAD), roof_y(column) + 20.0), Color(0.5, 0.47, 0.45, 0.6), 2, 40.0, -20.0)
		return
	if _rocks_left > 0 and into >= CAVE_IN_WARNING + (CAVE_IN_ROCKS - _rocks_left) * 0.16:
		_rocks_left -= 1
		var rock := FallingRock.new()
		rock.position = Vector2(_spot + randf_range(-CAVE_IN_SPREAD, CAVE_IN_SPREAD), roof_y(column) + 24.0)
		get_parent().add_child(rock)
		GameCamera.shake_scene(get_tree(), 0.15)


var _rocks_left := 0
