extends Node

## Sound effects, available everywhere as Sfx. Sfx.play("cast_fire", where) plays a sound at a spot in the world,
## so it is louder on the side of the screen it happens on; leave out the spot for interface sounds.
## A name with numbered variants (mob_hurt_1, mob_hurt_2...) is played as just "mob_hurt", and a variant is picked
## at random, so repeated sounds don't all sound the same. M mutes and unmutes.

## Loudness of each sound in decibels, so quiet recordings and loud ones sit together. Anything not listed is 0.
const VOLUME := {
	"cast_fire": -6.0, "fire_hit": -8.0, "fire_wall": -6.0, "fire_breath": -5.0, "volcano": -6.0,
	"cast_ice": -6.0, "ice_shatter": -10.0, "freeze": -6.0, "snow": -10.0,
	"force": -10.0, "barrier": -8.0, "push": -4.0, "gravity": -6.0,
	"spark": -5.0, "quicksand": -4.0, "thunder": -8.0, "tornado": -1.0, "blink": -8.0,
	"earth": -6.0, "stones": -4.0, "quake": -4.0, "explosion": -6.0,
	"misfire": -6.0, "mob_hurt": -12.0, "mob_die": -10.0, "mob_shoot": -12.0,
	"player_hurt": -4.0, "jump": -14.0, "step": -26.0, "type": -22.0,
	"portal_open": -6.0, "portal_enter": -4.0, "ritual_ok": -4.0, "heal": -8.0,
	"book_open": -8.0, "book_close": -8.0, "page": -8.0, "pickup": -8.0,
	"wizard_cast": -8.0, "game_over": -6.0, "summon": -12.0, "ui_click": -10.0,
}
const MAX_DISTANCE := 1400.0  # world sounds farther than this from the camera are not heard
const POOL := 24              # how many sounds can play at once

var muted := false
var _streams := {}  # name -> Array of file paths, one per variant
var _loaded := {}   # path -> AudioStream, filled in the first time a sound plays
var _players: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # interface sounds still play while the game is paused
	for file in ResourceLoader.list_directory("res://audio"):
		var base := file.get_basename()
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var key := base
		var tail := base.get_slice("_", base.get_slice_count("_") - 1)
		if tail.is_valid_int():
			key = base.substr(0, base.length() - tail.length() - 1)
		if not _streams.has(key):
			_streams[key] = []
		# The path is kept, and the file is only loaded the first time the sound plays: loading every sound at launch
		# made the game take most of a minute to open.
		_streams[key].append("res://audio/" + file)
	for i in POOL:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = MAX_DISTANCE
		p.attenuation = 0.6
		add_child(p)
		_players.append(p)
	for i in 6:
		var flat := AudioStreamPlayer.new()
		add_child(flat)
		_flat.append(flat)


## Plays a sound. at is a world position, or leave it out for a sound that is not in the world.
## pitch_spread varies the pitch a little each time, so repeats sound alive.
func play(sound: String, at: Variant = null, volume_db := 0.0, pitch_spread := 0.08) -> void:
	if muted or not _streams.has(sound):
		return
	var variants: Array = _streams[sound]
	var path: String = variants[randi() % variants.size()]
	if not _loaded.has(path):
		_loaded[path] = load(path)
	var stream: AudioStream = _loaded[path]
	var loudness: float = VOLUME.get(sound, 0.0) + volume_db
	var pitch := 1.0 + randf_range(-pitch_spread, pitch_spread)
	if at == null:
		for flat in _flat:
			if not flat.playing:
				flat.stream = stream
				flat.volume_db = loudness
				flat.pitch_scale = pitch
				flat.play()
				return
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.global_position = at
	player.volume_db = loudness
	player.pitch_scale = pitch
	player.play()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
