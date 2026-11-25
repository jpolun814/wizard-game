extends Node

## The music, available everywhere as Music. Each place has a track of its own: the first screen, the waiting room, and each biome a world can be.
## A screen says where the player now is (Music.play_for("menu")) and the track there fades in as the last one fades out; a place with no track
## fades to quiet. A screen that does not say (the Library, the loading screen, the cut-scenes) leaves the track that was playing.
## Music is this machine's alone: in a network game each person hears the place they are in. It plays on the Music bus, which the
## settings' Music slider and M (mute, on the master bus) both reach.

## Place -> track (a file in res://music, made by tools/make_music.py) and how loud it plays, in decibels, so every track sits at about the
## same loudness. Which place plays which track is the owner's choice (2026-11-20). Places not here are quiet: the biomes the owner has not
## chosen a track for yet. The tutorial plays the waiting room's (it is a Lab).
const TRACKS := {
	"menu": {"file": "invincibility", "db": 5.6},
	"waiting_room": {"file": "intro_adventurous", "db": -1.5},
	"portals": {"file": "intro_adventurous", "db": -1.5},
	"ashlands": {"file": "boss", "db": 0.0},
	"sky": {"file": "battle_track", "db": -2.7},
	"jungle": {"file": "beyond_mist", "db": -0.7},
	"graveyard": {"file": "shadowforge_convergence", "db": -1.0},
	"castle": {"file": "dread_march", "db": 2.5},
	"ocean": {"file": "veil_of_eternal_nightfall", "db": 0.6},
}
## Whether the music plays at all. Off while it is not ready (owner, 2026-11-20): the tracks and this script stay, but nothing is heard and builds leave the tracks out
## (`export_presets.cfg`). Which track goes where is written down in docs/music_plan.md. A test turns it on for itself.
var in_the_game := false
const LEVEL := -10.0  # every track is played this far under the sound effects, so a spell is never lost under the music
const FADE := 1.5     # seconds a track takes to fade in or out
const SILENT := -60.0
const BUS := &"Music"

var place := ""  # where the music is for now
var _now: AudioStreamPlayer  # the track playing, or fading in
var _streams := {}  # file -> AudioStream, loaded the first time it is wanted


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the music goes on while the game is paused


func _exit_tree() -> void:
	_streams.clear()  # let the tracks go when the game closes, or Godot reports them as still in use
	for player: AudioStreamPlayer in get_children():
		player.stop()
		player.stream = null
		player.free()
	_now = null


## The player is now in this place: its track fades in, unless it is the one already playing (the waiting room and the portal fields share
## one, and a track goes on, rather than starting again, from one to the other).
func play_for(where: String) -> void:
	place = where
	if not in_the_game:
		return
	var wanted: Dictionary = TRACKS.get(where, {})
	if _now != null and not wanted.is_empty() and _now.get_meta("file") == wanted["file"]:
		_fade(_now, LEVEL + float(wanted["db"]))
		return
	if _now != null:
		_fade(_now, SILENT, true)
		_now = null
	if wanted.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.stream = _stream(wanted["file"])
	player.volume_db = SILENT
	player.set_meta("file", wanted["file"])
	add_child(player)
	if not SteadyRun.on:
		player.play()
	_fade(player, LEVEL + float(wanted["db"]))
	_now = player


## The track playing now ("" when none), for a check.
func playing() -> String:
	return "" if _now == null else String(_now.get_meta("file"))


func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var stream := load("res://music/%s.ogg" % file) as AudioStreamOggVorbis
		stream.loop = true  # each file is a seamless loop
		_streams[file] = stream
	return _streams[file]


func _fade(player: AudioStreamPlayer, to_db: float, then_stop := false) -> void:
	if player.has_meta("tween"):
		(player.get_meta("tween") as Tween).kill()  # a fade begun before (a track fading out that is wanted again) gives way to this one
	var tween := player.create_tween()
	player.set_meta("tween", tween)
	tween.tween_property(player, "volume_db", to_db, FADE)
	if then_stop:
		tween.tween_callback(player.queue_free)
