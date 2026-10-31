class_name CritterFlock
extends Node2D

## Small living things that only add life to a biome: bats crossing the sky of the graveyard, and birds perched in the tops of the jungle's
## trees, which burst into the air when a wizard comes near and settle again a while later. They hurt no one and nothing hurts them.

const BAT := ["res://art/props/bat_0.png", "res://art/props/bat_1.png"]
const BIRD := ["res://art/props/bird_0.png", "res://art/props/bird_1.png"]
const SCARE_DISTANCE := 150.0
const RETURN_SECONDS := 9.0

var bats := false           # flying over the whole world, rather than perched
var perches: Array[Vector2] = []  # for birds: the places they sit
var span := Vector2.ZERO    # for bats: the world's left and right edges in pixels
var sky := 0.0              # for bats: the height of the ground they fly above
var seed_value := 0

var _critters: Array[Dictionary] = []  # {"sprite", "home", "state": "perched" | "fleeing" | "away", "wait", "vel", "phase"}
var _frames: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for path in (BAT if bats else BIRD):
		_frames.append(load(path))
	var homes: Array[Vector2] = []
	if bats:
		var count := int((span.y - span.x) / 420.0)
		for k in count:
			homes.append(Vector2(rng.randf_range(span.x, span.y), sky - rng.randf_range(150.0, 330.0)))
	else:
		homes = perches
	for home in homes:
		var sprite := Sprite2D.new()
		sprite.texture = _frames[0]
		sprite.scale = Vector2(2.0, 2.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = home
		sprite.z_index = -2 if bats else 2
		add_child(sprite)
		var heading := -1.0 if rng.randf() < 0.5 else 1.0
		_critters.append({"sprite": sprite, "home": home, "state": "flying" if bats else "perched", "wait": 0.0, "vel": Vector2(heading * rng.randf_range(40.0, 80.0), 0.0), "phase": rng.randf() * TAU})


func _process(delta: float) -> void:
	_t += delta
	var wizards := SpellTargets.wizards(get_tree())
	for critter in _critters:
		var sprite: Sprite2D = critter["sprite"]
		match critter["state"]:
			"flying":  # a bat drifts one way, bobbing, and comes round at the world's end
				sprite.position += critter["vel"] * delta
				sprite.position.y = critter["home"].y + sin(_t * 1.3 + critter["phase"]) * 26.0
				sprite.flip_h = critter["vel"].x < 0.0
				if sprite.position.x < span.x or sprite.position.x > span.y:
					critter["vel"].x = -critter["vel"].x
				sprite.texture = _frames[int(_t * 7.0 + critter["phase"]) % 2]
			"perched":
				sprite.texture = _frames[0]
				for wizard: Node2D in wizards:
					if wizard.global_position.distance_to(sprite.position) < SCARE_DISTANCE:
						var away := signf(sprite.position.x - wizard.global_position.x)
						critter["state"] = "fleeing"
						critter["wait"] = 3.0
						critter["vel"] = Vector2((away if away != 0.0 else 1.0) * 150.0, -170.0)
						break
			"fleeing":
				critter["wait"] -= delta
				sprite.position += critter["vel"] * delta
				sprite.flip_h = critter["vel"].x < 0.0
				sprite.texture = _frames[int(_t * 12.0) % 2]
				sprite.modulate.a = clampf(critter["wait"], 0.0, 1.0)
				if critter["wait"] <= 0.0:
					critter["state"] = "away"
					critter["wait"] = RETURN_SECONDS
					sprite.visible = false
			"away":
				critter["wait"] -= delta
				if critter["wait"] <= 0.0:
					sprite.position = critter["home"]
					sprite.modulate.a = 1.0
					sprite.visible = true
					critter["state"] = "perched"
