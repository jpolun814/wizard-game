extends Node

## Sound effects, available everywhere as Sfx. Sfx.play("cast_fire", where) plays a sound at a spot in the world,
## so it is louder on the side of the screen it happens on; leave out the spot for interface sounds.
## A name with numbered variants (mob_hurt_1, mob_hurt_2...) is one AudioStreamRandomizer: Godot picks a variant and
## varies the pitch each time, so repeated sounds don't all sound the same. Everything plays on the SFX bus
## (default_bus_layout.tres). M mutes and unmutes.

## Loudness of the sounds that are played by name (the wizard's steps, landings and voices), in decibels. Everything else is asked for by owner and event, and its loudness is in data/sound_levels.json. Anything not listed is 0.
const VOLUME := {
	"jump_voice_1": -14.0, "jump_voice_3": -14.0, "jump_voice_4": -14.0, "jump_voice_5": -14.0, "hurt_voice_1": -13.5, "hurt_voice_3": -15.0, "hurt_voice_4": -15.0, "hurt_voice_5": -15.0, 
}
## Who owns which sounds. Every sound in the game belongs to exactly one owner (a spell, a kind of creature, the wizard's body, a piece of scenery, a screen) and is
## asked for by that owner and the event it stands for: Sfx.cue("Ignite", "cast", where). A spell's own list is `sounds` in its data file; everyone else's is in
## data/sounds.json. The file behind an event is the owner's alone (audio/<owner>__<event>_N), even when it is a copy of another's, so changing one never changes
## another. data/sound_levels.json holds how loud each file is.
const REGISTRY := "res://data/sounds.json"
const LEVELS := "res://data/sound_levels.json"
const MAX_DISTANCE := 1400.0  # world sounds farther than this from the camera are not heard
const POLYPHONY := 24         # how many sounds can play at once; the oldest are cut off beyond that
const BUS := &"SFX"

var muted := false
var _files := {}      # name -> Array of file paths, one per variant
var _sounds := {}     # name -> AudioStreamRandomizer, built the first time the sound plays
var recording := false  # a check turns this on to see which sounds the game asks for, and when
var heard: Array[String] = []  # the sound names asked for while recording, in order
var _live := 0
var _owned := {}      # owner -> {event: sound name}, for everything that is not a spell
var _levels := {}     # sound name -> loudness in decibels
var _hush := 0.0      # 1 while the listener stands inside a Silence: the world makes no sound there, the listener's own steps and cries included
var _hush_check := 0.0
var _hushed := false  # whether the listener was found in a Silence at the last look
var _voices := {}     # instance id of a speaker -> the voice sound it is making now


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # interface sounds still play while the game is paused
	GameSettings.load_saved()
	_owned = _read(REGISTRY)
	_levels = _read(LEVELS)
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


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The sound an owner makes for an event, or "" when it has none.
func sound_of(owner: String, event: String) -> String:
	var spell: Spell = SpellData.SPELLS.get(owner)
	if spell != null:
		return spell.sounds.get(event, "")
	return _owned.get(owner, {}).get(event, "")


## The first file of an owner's event, for a sound that is not played through Sfx (a loop that lasts as long as the spell does).
func path_of(owner: String, event: String) -> String:
	return _files[sound_of(owner, event)][0]


func level_of(sound: String) -> float:
	return _levels.get(sound, VOLUME.get(sound, 0.0))


## Plays the sound an owner makes for an event (see REGISTRY). Same arguments as play.
func cue(owner: String, event: String, at: Variant = null, volume_db := 0.0, pitch_spread := 0.08, pitch := 1.0) -> Node:
	var sound := sound_of(owner, event)
	if sound == "":
		push_warning("Sfx.cue: %s has no sound for %s" % [owner, event])
		return null
	return play(sound, at, volume_db, pitch_spread, pitch)


## True when there is a sound of this name.
func has_sound(sound: String) -> bool:
	return _files.has(sound)


## Plays a sound. at is a world position, or leave it out for a sound that is not in the world.
## pitch_spread varies the pitch a little each time, so repeats sound alive; pitch plays it lower (under 1) or higher (over 1) than it was recorded.
func play(sound: String, at: Variant = null, volume_db := 0.0, pitch_spread := 0.08, pitch := 1.0) -> Node:
	if recording:
		heard.append(sound)
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
	player.volume_db = _levels.get(sound, VOLUME.get(sound, 0.0)) + volume_db
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


## Inside a ring of Silence nothing is heard: the sound bus is closed while the view's middle (the wizard) is in one, and opens again when they step out.
func _process(delta: float) -> void:
	_hush_check -= delta
	if _hush_check <= 0.0:
		_hush_check = 0.1
		var listener := get_tree().get_first_node_in_group("player") as Node2D  # the wizard the screen is of (the view's middle sits above them)
		_hushed = listener != null and Silence.covers(get_tree(), listener.global_position + Vector2(0.0, -40.0))
	var goal := 1.0 if _hushed else 0.0
	_hush = move_toward(_hush, goal, delta * 8.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), -80.0 * _hush)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
