class_name WizardRoute
extends RefCounted

## A wizard's way along a path of tiles from WorldNav: which way to walk, how fast, and when to jump, each frame. A tile in the path is a
## place to stand; the move between two of them is a walk (to the next column, level or a tile up), a fall off an edge, or a jump (up a wall,
## or across a gap), as Walkways describes them. A jump is made from the middle of the tile it starts from, at the speed that lands it on the middle of
## the next. When the wizard stops making headway the route says so, and the one who owns it finds another.

const TILE := float(ArenaGen.TILE)
const WALK := 170.0         # a wizard's walking speed
const JUMP_SPEED := 520.0   # how fast a jump leaves the ground, the same as the player's
const FALL_SPEED := 60.0   # how fast to drift across while falling
const MAX_AIR_SPEED := 330.0
const LEAN := 10.0          # pixels past the middle of a tile that a jump aims at
const ARRIVE_X := 18.0      # how close to the middle of a tile counts as being at it
const ARRIVE_Y := 28.0
const STUCK_AFTER := 2.0    # seconds without getting closer before the route gives up
const CLIMB_ROWS := 8        # a move up this many rows is a ladder
const HOP_GAP := 0.6        # seconds between hops over a step that blocks the way

var _path: Array[Vector2i] = []
var _next := 0
var _stuck := 0.0
var _best := INF
var _air_speed := WALK
var _jumped := false  # this move's jump has been made, and the wizard is not down yet
var _hop := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


## Sets out along a path (its first tile is where the wizard stands).
func set_path(path: Array[Vector2i]) -> void:
	_path = path
	_next = 1
	_stuck = 0.0
	_best = INF
	_jumped = false


func clear() -> void:
	_path = []
	_next = 0


## The tile a number of moves on from the one it is going to (0 is that one), or (-1, -1) when the path is not so long.
func ahead(moves: int) -> Vector2i:
	return _path[_next + moves] if _next + moves < _path.size() else Vector2i(-1, -1)


## True when there is no path, or the wizard has come to the end of it.
func done() -> bool:
	return _next >= _path.size()


## Where the route is now, for a report: the tile it is going to, and how many tiles it has left.
func status() -> String:
	if done():
		return "no route"
	return "from %s to %s, %d left, stuck %.1fs" % [str(_path[_next - 1]), str(_path[_next]), _path.size() - _next, _stuck]


## The tile the path ends at, or (-1, -1) with no path.
func goal() -> Vector2i:
	return _path[_path.size() - 1] if not _path.is_empty() else Vector2i(-1, -1)


## What the body should do this frame: {"dir": -1, 0 or 1, "speed", "jump": leave the ground now, "replan": it is getting nowhere}.
func steer(body: CharacterBody2D, delta: float) -> Dictionary:
	var out := {"dir": 0.0, "speed": WALK, "jump": false, "replan": false, "climb": false, "let_go": false}
	_hop = maxf(_hop - delta, 0.0)
	var feet := body.global_position
	var grounded := body.is_on_floor()
	while _next < _path.size() and (grounded or not _jumped) and _reached(feet, _path[_next]):  # after a jump, it has to be down
		_next += 1
		_stuck = 0.0
		_best = INF
		_jumped = false
	if _next >= _path.size():
		return out
	var goal_tile := _path[_next]
	var from := _path[_next - 1]
	var across := absi(goal_tile.x - from.x)
	var down := goal_tile.y - from.y
	if -down >= CLIMB_ROWS and across <= 2:
		_climb(feet, grounded, from, goal_tile, out)
		return _track(out, feet, goal_tile, delta)
	var leaps := across >= 2 or down <= -2  # not a step, a slope or a fall
	var goal_x := (goal_tile.x + 0.5) * TILE
	if leaps:
		goal_x += signf(goal_tile.x - from.x) * LEAN  # the edge of a ledge is rounded off: land a little way in
	var gap := goal_x - feet.x
	out["dir"] = 0.0 if absf(gap) < 4.0 else signf(gap)
	if grounded and leaps and not _jumped:
		out["jump"] = true
		out["speed"] = _air_speed_for(absf(gap), float(from.y - goal_tile.y) * TILE)
		_air_speed = out["speed"]
		_jumped = true
	elif not grounded and _jumped:
		out["speed"] = _air_speed
	elif not grounded and body.velocity.y >= 0.0:
		out["speed"] = FALL_SPEED  # off an edge: drop beside it, not far out over what is below
	elif grounded and not leaps and body.is_on_wall() and down < 0 and _hop <= 0.0:
		out["jump"] = true  # a step up that is a little too sheer to walk
		_hop = HOP_GAP
	return _track(out, feet, goal_tile, delta)


## Up a rope ladder: walk to its foot, climb until the feet are near the floor above, then hop off onto it.
func _climb(feet: Vector2, grounded: bool, from: Vector2i, goal_tile: Vector2i, out: Dictionary) -> void:
	var ladder_x := float(from.x + (1 if goal_tile.x < from.x else 0)) * TILE
	var floor_y := float(goal_tile.y + 1) * TILE
	if feet.y <= floor_y + 12.0:  # near the top: a hop off the ladder, sideways onto the floor
		out["dir"] = signf((goal_tile.x + 0.5) * TILE - feet.x)
		out["let_go"] = not grounded
	elif grounded and absf(ladder_x - feet.x) > 8.0:
		out["dir"] = signf(ladder_x - feet.x)
	else:
		out["climb"] = true


## Notes whether the wizard is getting closer to the tile it is going to, and says so when it is not.
func _track(out: Dictionary, feet: Vector2, goal_tile: Vector2i, delta: float) -> Dictionary:
	var gap := (goal_tile.x + 0.5) * TILE - feet.x
	var progress := absf(gap) + absf(feet.y - (goal_tile.y + 1) * TILE) * 0.5
	if progress < _best - 3.0:
		_best = progress
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > STUCK_AFTER:
			out["replan"] = true
			_stuck = 0.0
	return out


func _reached(feet: Vector2, tile: Vector2i) -> bool:
	return absf(feet.x - (tile.x + 0.5) * TILE) < ARRIVE_X and absf(feet.y - (tile.y + 1) * TILE) < ARRIVE_Y


## How fast to go across so that a jump lands in the middle of its tile: the distance over the time in the air, which is up and down
## again to the height of the landing (rise is in pixels, positive when the landing is higher).
func _air_speed_for(distance: float, rise: float) -> float:
	var apex_room := JUMP_SPEED * JUMP_SPEED - 2.0 * _gravity * rise
	if apex_room <= 0.0:
		return WALK
	var seconds := (JUMP_SPEED + sqrt(apex_room)) / _gravity
	return clampf(distance / seconds * 1.05, WALK, MAX_AIR_SPEED)
