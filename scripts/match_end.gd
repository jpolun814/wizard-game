class_name MatchEnd
extends RefCounted

## How a match ends for the person at this machine: falling out of it (and watching the others), winning it, the stats that come up, and the epilogue or
## the way back to the waiting room.

const EPILOGUE_AFTER := 4.0  # seconds after a match is won, in a game on this machine alone, before the winner is shown putting the book back (when the person won, after they have put their stats away)
const STATS_AFTER := 3.0  # seconds after the person wins before their stats come up on their own
const BACK_TO_ROOM := 10.0  # seconds after a network match is won before everyone is back in the waiting room

var _since_count := 0.0
var won := false
var win_stats_due := false  # the person has won and their stats have not come up yet
var _watched := 0  # while out of the match: which of the other wizards the camera follows
var spectating := false
var stats: StatsScreen  # what is shown when the person falls

var world: World


func _init(owner: World) -> void:
	world = owner


## Out of the match: while other wizards still live the match goes on, and the camera follows one of them. Otherwise the run is over.
func on_player_died() -> void:
	if Net.dedicated:
		return  # nobody is here to watch the others, or to see the stats: the match goes on for the people on other machines
	PlayRecorder.finish(world.get_tree())  # (in a network match the person's play is sent to the machine that keeps the game)
	_record_match(world.living().size() + 1)
	_show_stats()
	if world.living().is_empty():
		world.end_run()
		return
	world.caster.set_casting_enabled(false)
	world.ritual.cancel()
	Sfx.play("game_over")
	spectating = true
	world.player.collision_layer = 0
	world.player.collision_mask = 0
	world.player.hide()
	world.hud.banner("", "Click to watch another wizard")


## The match goes into the Chronicle, once: where the person came, and what they did.
func _record_match(place: int) -> void:
	if MatchStats.recorded:
		return
	MatchStats.recorded = true
	Library.record_match_end(MatchStats.summary(place, world.rivals.size() + 1))
	Library.flush()


## The story of the match so far, over the screen: where the person came, and charts of what they did.
func _show_stats() -> void:
	if is_instance_valid(stats):
		return
	stats = StatsScreen.new()
	world.hud.add_child(stats)
	world.hud.offer_stats()
	if not world.hud.stats_requested.is_connected(_look_at_stats):
		world.hud.stats_requested.connect(_look_at_stats)
	stats.show_stats(world.living().size() + 1, world.rivals.size() + 1, not world.living().is_empty())


## A few seconds after the person wins, their stats come up on their own, and the ending waits for them to be put away. (The crystal ball on the screen is
## only for one who has fallen and wants to look again while the match goes on.)
func _show_win_stats() -> void:
	win_stats_due = false
	if world.leaving:
		return
	if not is_instance_valid(stats):
		stats = StatsScreen.new()
		world.hud.add_child(stats)
	world.hud.move_child(stats, -1)
	stats.show_stats(1, world.rivals.size() + 1, false)


## The F1 panel's way to a won match: every other wizard falls, and the match ends as it does when the last of them is beaten.
func debug_win() -> void:
	for rival in world.living():
		rival.take_damage(100000)


## The F1 panel's way to a lost match: the person falls, as when beaten.
func debug_lose() -> void:
	if not world.player.dead:
		world.player.take_damage(100000)


## The person asks to see their stats again, once the match is over for them.
func _look_at_stats() -> void:
	if not is_instance_valid(stats):
		stats = StatsScreen.new()
		world.hud.add_child(stats)
	world.hud.move_child(stats, -1)  # over everything else on the layer
	stats.show_stats(world.living().size() + 1, world.rivals.size() + 1, not world.living().is_empty())


## The camera goes where the watched wizard is: the body of the world.player, hidden, is moved there.
func follow_watched() -> void:
	if not spectating:
		return
	var living := world.living()
	if living.is_empty():
		spectating = false
		world.end_run()  # the last of the world.rivals fell too: nobody is left to watch
		return
	_watched = _watched % living.size()
	world.player.global_position = living[_watched].global_position
	world.player.velocity = Vector2.ZERO


func count_wizards(delta: float) -> void:
	_since_count += delta
	if _since_count < 0.5 or won:
		return
	_since_count = 0.0
	var standing := SpellTargets.wizards(world.get_tree())
	if standing.size() == 1 and standing[0] == world.player and not Net.dedicated:
		won = true
		world.hud.banner("Last wizard standing", "You win")
		Library.record_win(world.player.ledger.pages.keys())
		MatchStats.finish()  # the clock stops where the match was won
		PlayRecorder.finish(world.get_tree())
		_record_match(1)
		win_stats_due = true
		world.get_tree().create_timer(STATS_AFTER).timeout.connect(_show_win_stats)
		Library.flush()
		Sfx.play("ritual_ok", world.player.center())
	if standing.size() == 1 and Library.real_match() and (Net.is_host() or not Net.online()):
		won = true
		var champion: Wizard = standing[0]
		world.get_tree().create_timer(EPILOGUE_AFTER).timeout.connect(epilogue_when_stats_are_away.bind(champion.look, champion.palette))  # the winner is shown putting the book back, on every machine
	elif standing.size() <= 1 and Net.online() and Net.is_host():
		won = true
		world.get_tree().create_timer(BACK_TO_ROOM).timeout.connect(back_to_room)  # no winner, or a test: everyone just goes back to the waiting room


## The ending waits while the person is reading their stats, so it never cuts in on them.
func epilogue_when_stats_are_away(look: String, palette: int) -> void:
	if win_stats_due or (is_instance_valid(stats) and stats.visible):
		world.get_tree().create_timer(0.5).timeout.connect(epilogue_when_stats_are_away.bind(look, palette))
		return
	end_with_epilogue(look, palette)


## The match is won: on the host and then on every other machine, the winner is shown putting the book back.
func end_with_epilogue(look: String, palette: int) -> void:
	if not world.is_inside_tree():
		return
	if Net.is_host():
		Net.send(world, &"_end_with_epilogue", [look, palette])
	if GameSettings.skip_ending():
		_fade_to_room()  # this machine's world.player would rather not watch it
		return
	_roll_the_epilogue(look, palette)


## The F1 panel's way to the ending: the world.player's own wizard has won.
func go_to_epilogue() -> void:
	if world.leaving:
		return
	_roll_the_epilogue(world.player.look, world.player.palette)


## The screen goes black, and the epilogue plays in the waiting room's place.
func _roll_the_epilogue(look: String, palette: int) -> void:
	world.leaving = true
	world.leave_network_scene()
	Epilogue.winner_look = look
	Epilogue.winner_palette = palette
	World.next_seed = -1
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	world.add_child(layer)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.8)
	tween.tween_callback(world.get_tree().change_scene_to_file.bind("res://scenes/epilogue.tscn"))


## The end of a network match: everyone is back in the waiting room, for the next one.
func back_to_room() -> void:
	if not world.is_inside_tree():
		return
	if Net.is_host():
		Net.send(world, &"_back_to_room")
	_fade_to_room()


## The screen goes black, and then it is the waiting room again.
func _fade_to_room() -> void:
	world.leave_network_scene()
	World.next_seed = -1
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	world.add_child(layer)
	var tween := black.create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.8)
	tween.tween_callback(world.get_tree().change_scene_to_file.bind("res://scenes/lab.tscn"))


func input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if spectating and click and click.pressed:
		_watched += 1  # the next one
