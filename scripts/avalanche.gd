class_name Avalanche
extends Node2D

## Now and then, high on a slope of the snowy peaks, the snow lets go. It rumbles and smokes at the place for a few seconds, then a wall of
## snow rolls down the slope and sweeps along every wizard in its way. It follows a timetable made from the world's seed and the world's age,
## so every machine of a match sees the same one at the same time. It hurts whoever is run down, and shoves them down the hill.

const PERIOD := 42.0   # seconds from one to the next
const FIRST := 12.0    # seconds into the world before the first
const WARNING := 3.5   # seconds of rumbling before the snow moves
const SPEED := 260.0   # pixels a second the front travels
const REACH := 70.0    # how far each way from the front it sweeps
const HEIGHT := 150.0  # how high above the slope it reaches
const PUSH := 300.0
const DAMAGE := 6
const MAX_RUN := 70    # columns it runs, at the most

var floors := PackedInt32Array()
var seed_value := 0
var seconds := 0.0  # the world's age: the world sets it each frame

var _slot := -1
var _from := 0         # the column it starts at
var _way := 1          # which way it runs: 1 east, -1 west
var _length := 0       # how many columns it runs
var _hit := {}         # the wizards already hurt by this one
var _smoke := 0.0


func _ready() -> void:
	add_to_group("danger")


## Works out where the avalanche of a slot of time begins and where it runs.
func _plan(slot: int) -> void:
	_slot = slot
	_hit = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + slot * 9176
	var best := SurfaceGen.MARGIN + 40
	var high := 1000000
	for k in 30:  # a high place, from a handful the seed tries
		var c := rng.randi_range(SurfaceGen.MARGIN + 40, floors.size() - SurfaceGen.MARGIN - 40)
		if floors[c] < high:
			high = floors[c]
			best = c
	_from = best
	_way = 1 if floors[mini(best + 20, floors.size() - 1)] > floors[maxi(best - 20, 0)] else -1  # runs downhill
	_length = 0
	var c := _from
	while _length < MAX_RUN and c + _way >= SurfaceGen.MARGIN and c + _way < floors.size() - SurfaceGen.MARGIN:
		c += _way
		_length += 1
		if floors[c] >= SurfaceGen.BASE_ROW - 1 and _length > 8:
			break


## Seconds since the one of the current slot began (before it, negative).
func _into() -> float:
	return seconds - FIRST - _slot * PERIOD


func _physics_process(delta: float) -> void:
	if seconds < FIRST:
		return
	var slot := int((seconds - FIRST) / PERIOD)
	if slot != _slot:
		_plan(slot)
	var into := _into()
	var tile := float(ArenaGen.TILE)
	var top := Vector2((_from + 0.5) * tile, floors[_from] * tile)
	_smoke -= delta
	if into < WARNING:  # the slope rumbles and smokes
		if _smoke <= 0.0:
			_smoke = 0.25
			Fx.smoke(get_parent(), top + Vector2(randf_range(-60.0, 60.0), -10.0), Color(0.95, 0.97, 1.0, 0.7), 2, 30.0, 30.0)
		return
	var travelled := (into - WARNING) * SPEED
	if travelled > _length * tile:
		return
	var column := clampi(_from + _way * int(travelled / tile), 0, floors.size() - 1)
	var front := Vector2(top.x + _way * travelled, floors[column] * tile)
	if _smoke <= 0.0:
		_smoke = 0.05
		Fx.smoke(get_parent(), front + Vector2(randf_range(-REACH, REACH), -randf_range(10.0, 90.0)), Color(0.96, 0.98, 1.0, 0.85), 4, 80.0, 30.0)
		Fx.burst(get_parent(), front + Vector2(0.0, -30.0), Color(0.95, 0.98, 1.0), 8, 220.0, 0.7, true)
	for wizard: Wizard in SpellTargets.wizards(get_tree()):
		var at := wizard.global_position
		if absf(at.x - front.x) < REACH and at.y < front.y + 20.0 and at.y > front.y - HEIGHT and not wizard.is_likeness():
			wizard.push(Vector2(_way * PUSH, 0.0))
			if not _hit.has(wizard):
				_hit[wizard] = true
				SpellTargets.hurt(wizard, DAMAGE, "Air")


## True over the slope while it rumbles, and along the front of the snow while it runs.
func danger_at(point: Vector2) -> bool:
	if seconds < FIRST or _length == 0:
		return false
	var start_x := (_from + 0.5) * float(ArenaGen.TILE)
	var into := _into()
	if into < WARNING:
		return absf(point.x - start_x) < 200.0
	var gone := (into - WARNING) * SPEED
	return gone <= _length * float(ArenaGen.TILE) and absf(point.x - (start_x + _way * gone)) < REACH + 60.0
