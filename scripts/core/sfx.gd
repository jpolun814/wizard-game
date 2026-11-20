extends Node

## Sound effects, available everywhere as Sfx. Sfx.play("cast_fire", where) plays a sound at a spot in the world,
## so it is louder on the side of the screen it happens on; leave out the spot for interface sounds.
## A name with numbered variants (mob_hurt_1, mob_hurt_2...) is one AudioStreamRandomizer: Godot picks a variant and
## varies the pitch each time, so repeated sounds don't all sound the same. Everything plays on the SFX bus
## (default_bus_layout.tres). M mutes and unmutes.

## Loudness of each sound in decibels, so quiet recordings and loud ones sit together. Anything not listed is 0.
const VOLUME := {
	"cast_fire": 4.0, "fire_hit": 6.0, "fire_wall": -6.0, "fire_breath": -5.0, "volcano": -6.0,
	"cast_ice": -6.0, "ice_shatter": -10.0, "freeze": -6.0, "snow": -10.0,
	"barrier": -8.0, "push": -4.0, "gravity": 4.0,
	"spark": -2.0, "eldritch": -4.0, "quicksand": -4.0, "thunder": -8.0, "tornado": -1.0, "blink": -8.0,
	"stones": -4.0, "quake": -4.0, "explosion": -6.0,
	"misfire": -6.0, "mob_hurt": -12.0, "mob_die": -10.0, "mob_shoot": -12.0,
	"player_hurt": -4.0, "jump_voice_1": -14.0, "jump_voice_3": -14.0, "jump_voice_4": -14.0, "jump_voice_5": -14.0,
	"hurt_voice_1": -4.0, "hurt_voice_3": -4.0, "hurt_voice_4": -4.0, "hurt_voice_5": -4.0,
	"step_dirt": -26.0, "step_snow": -26.0, "step_leaves": -26.0, "step_gravel": -26.0, "step_tile": -26.0, "step_rock": -26.0, "step_grass": -26.0, "step_wood": -26.0, 
	"portal_open": -6.0, "portal_enter": -2.0, "ritual_ok": -4.0, 
	"book_open": -8.0, "book_close": -8.0, "page": -8.0, "pickup": -8.0,
	"blood_cast": -6.0, "heartbeat": -2.0, "surf": -3.0, "glass": -8.0, "faint": -4.0, "jaw_snap": -4.0, "chomp": -8.0, "game_over": -6.0, "summon": -4.0, "water_jet": -6.0, "geyser": -6.0, "ui_click": -10.0,
}
const MAX_DISTANCE := 1400.0  # world sounds farther than this from the camera are not heard
const POLYPHONY := 24         # how many sounds can play at once; the oldest are cut off beyond that
const BUS := &"SFX"

var muted := false
var _files := {}      # name -> Array of file paths, one per variant
var _sounds := {}     # name -> AudioStreamRandomizer, built the first time the sound plays
var _live := 0
var _voices := {}     # instance id of a speaker -> the voice sound it is making now


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # interface sounds still play while the game is paused
	GameSettings.load_saved()
	for file in ResourceLoader.list_directory("res://audio"):
		var base := file.get_basename()
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var key := base
		var tail := base.get_slice("_", base.get_slice_count("_") - 1)
		if tail.is_valid_int():
			key = base.substr(0, base.length() - tail.length() - 1)
		if not _files.has(key):
			_files[key] = []
		# Only the paths are kept: a sound is loaded the first time it plays, because loading every sound at launch
		# made the game take most of a minute to open.
		_files[key].append("res://audio/" + file)


## True when there is a sound of this name.
func has_sound(sound: String) -> bool:
	return _files.has(sound)


## Plays a sound. at is a world position, or leave it out for a sound that is not in the world.
## pitch_spread varies the pitch a little each time, so repeats sound alive; pitch plays it lower (under 1) or higher (over 1) than it was recorded.
func play(sound: String, at: Variant = null, volume_db := 0.0, pitch_spread := 0.08, pitch := 1.0) -> Node:
	if muted or not _files.has(sound) or _live >= POLYPHONY:
		return null
	var stream := _stream(sound, pitch_spread)
	var player: Node
	if at == null:
		player = AudioStreamPlayer.new()
	else:
		player = AudioStreamPlayer2D.new()
		player.max_distance = MAX_DISTANCE
		player.attenuation = 0.6
		player.global_position = at
	player.stream = stream
	player.bus = BUS
	player.pitch_scale = pitch
	player.volume_db = VOLUME.get(sound, 0.0) + volume_db
	player.finished.connect(_done.bind(player))
	_live += 1
	add_child(player)
	player.play()
	return player


## A voice: the cry or grunt of a wizard. One voice never speaks over itself: while a sound is sounding, the same sound asked for again is let go,
## and a different one (a cry in the middle of a jump's grunt) takes its place.
func speak(speaker: Node, sound: String, at: Vector2) -> void:
	var id := speaker.get_instance_id()
	var old: Node = _voices.get(id)
	if is_instance_valid(old) and old.playing:
		if old.get_meta("sound") == sound:
			return
		old.stop()  # (a stopped player does not announce that it finished)
		_done(old)
	var player := play(sound, at)
	if player != null:
		player.set_meta("speaker", id)
		player.set_meta("sound", sound)
		_voices[id] = player


func _done(player: Node) -> void:
	_live -= 1
	if player.has_meta("speaker") and _voices.get(player.get_meta("speaker")) == player:
		_voices.erase(player.get_meta("speaker"))
	player.queue_free()


func _stream(sound: String, pitch_spread: float) -> AudioStreamRandomizer:
	if not _sounds.has(sound):
		var randomizer := AudioStreamRandomizer.new()
		for path: String in _files[sound]:
			randomizer.add_stream(-1, load(path))
		_sounds[sound] = randomizer
	var randomizer: AudioStreamRandomizer = _sounds[sound]
	randomizer.random_pitch = 1.0 + pitch_spread
	return randomizer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
