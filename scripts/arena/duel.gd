class_name Duel
extends Lab

## A duel: the person against one AI wizard in a small room about a screen wide, each with starting pages dealt as a match deals them (an attack, a way about and
## a defense, and the chants), dealt again every round. A round ends when one of them falls; the next begins a moment later. Every round is written down in detail by
## DuelLog (user://duel_logs/), so the way a person fights and dodges can be studied against the AI's.
## The AI plays at the level the waiting room's wall was last set to, or level 9 when it has not been set.

const CHUNKS := 5            # the room: 30 columns, a little over one screen
const START_IN := 8          # columns in from each wall where the two begin (about 450 px apart: within sight and reach)
const WAKE_AFTER_START := 2.0  # seconds before the AI moves: time to open the book
const NEXT_ROUND_IN := 3.0
const MENU := "res://scenes/menu.tscn"

static var wins := 0
static var losses := 0
static var round_number := 0

var rival: Wizard
var _log: DuelLog
var _over := false
var _wake := WAKE_AFTER_START


func _init() -> void:
	heals_wounds = false
	_set_width()


func _enter_tree() -> void:
	super()
	_set_width()


func _set_width() -> void:
	ArenaGen.chunk_count = CHUNKS
	ArenaGen.right_wall = ArenaGen.FIRST_COL + ArenaGen.CHUNK_WIDTH * CHUNKS


## Level ground from wall to wall.
## What each side is dealt: five attacks, two ways about and three defenses (ten spells, and the chants), none the same as the other side's (owner, 2026-11-22: not three).
const BOOK := [5, 2, 3, 0]


func _build_map() -> Variant:
	var heights := PackedFloat32Array()
	heights.resize(ArenaGen.right_wall - ArenaGen.FIRST_COL)
	return ArenaGen.build(_rng, heights)


func _begin_encounter(camera: Camera2D) -> void:
	round_number += 1
	var seed_value := randi()
	var dealt := Pages.deal(seed_value, 2, BOOK)
	var left := ArenaGen.FIRST_COL + START_IN
	var right := ArenaGen.right_wall - START_IN
	player.position = Vector2(ArenaGen.column_x(left), ArenaGen.surface_y(_cells, left))
	player.facing = 1.0
	camera.reset_smoothing()
	player.infinite_time = 0.0
	player.ledger = dealt[0]
	spellbook.refresh()
	rival = add_wizard(PartsLook.seeded_look(seed_value % 997 + 3), Vector2(ArenaGen.column_x(right), ArenaGen.surface_y(_cells, right)))
	rival.ledger = dealt[1]
	read_room(Vector2i(floori(rival.global_position.x / ArenaGen.TILE), floori(rival.global_position.y / ArenaGen.TILE) - 1))  # (the AI finds its way about the room as it does in the waiting room)
	rival.nav = nav
	rival.facing = -1.0
	var level := BrainLevel.match_level if BrainLevel.match_level > 0 else BrainLevel.LEVELS
	rival.brain.set_level(level)
	rival.brain.dormant = true
	rival.died.connect(_round_over.bind(true))
	add_child(Grade.new())
	hud.set_title("Duel\nWins: %d   Losses: %d" % [wins, losses])
	if round_number == 1:
		hud.show_message("Press Tab to see your spells", Color(0.9, 0.9, 1.0))
	_log = DuelLog.new()
	_log.begin(self, player, rival, round_number, seed_value, level)
	add_child(_log)


func _process(delta: float) -> void:
	super(delta)
	if _wake > 0.0:
		_wake -= delta
		if _wake <= 0.0 and is_instance_valid(rival):
			rival.brain.dormant = false


## The person fell: the round is lost.
func _on_player_died() -> void:
	_round_over(false)


func _round_over(won: bool) -> void:
	if _over:
		return
	_over = true
	if won:
		wins += 1
	else:
		losses += 1
	if _log != null:
		_log.finish("person" if won else "ai")
	hud.show_message("You win" if won else "You lose", Color(0.7, 1.0, 0.7) if won else Color(1.0, 0.6, 0.6))
	if is_instance_valid(rival):
		rival.brain.dormant = true
	get_tree().create_timer(NEXT_ROUND_IN).timeout.connect(func() -> void: get_tree().reload_current_scene())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ritual.visible:
		hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("start_ritual") and not ritual.visible and not hud.is_paused() and not player.dead:
		rituals.start()
